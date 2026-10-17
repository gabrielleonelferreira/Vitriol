class_name Experiment
extends RefCounted
## Experimentação: misturar materiais numa estação sem saber a receita.
##
## Acertar o conjunto de materiais e a estação revela a receita (inclusive as secretas) e faz uma
## unidade. Errar gasta 1 de cada material, dá 1 XP e devolve uma pista sobre o quanto chegou perto.
## Usado pelo servidor (que decide) e pelos testes; o cliente só monta a mistura.

## Até quantos materiais diferentes cabem numa mistura.
const MAX_PARTS := 4
## Área de maestria que ganha XP num experimento errado, por estação.
const STATION_AREA := {
	"mao": "construcao",
	"bancada": "construcao",
	"fogueira": "quimica",
	"fornalha": "metalurgia",
	"forno": "quimica",
	"forno_de_vidro": "vidraria",
}

const HINTS := {
	"proporcao": "Quase! São esses materiais, mas a proporção não fechou.",
	"estacao": "Esses materiais não reagem aqui. Talvez em outra estação.",
	"falta": "Algo começou a reagir... parece faltar um ingrediente.",
	"demais": "Reagiu, mas algo atrapalhou: tem material demais na mistura.",
	"nada": "Nada reagiu.",
}
## Ordem das pistas: a mais próxima do acerto vence.
const HINT_ORDER := ["proporcao", "estacao", "falta", "demais", "nada"]


## Resultado da mistura `mix` ({material: qtd}) na estação `station`:
## {"tipo": "receita", "receita": id, "nova": bool} — acertou (nova = era secreta e não conhecida);
## {"tipo": "bloqueada", "receita": id, "motivo": String} — existe, mas falta nível ou condição;
## {"tipo": "falhou", "pista": chave de HINTS, "texto": String};
## {"tipo": "invalida", "texto": String} — mistura vazia, grande demais ou com não-materiais.
static func evaluate(
	data: DataStore, mix: Dictionary, station: String, mastery: Dictionary, known: Dictionary
) -> Dictionary:
	if mix.is_empty() or mix.size() > MAX_PARTS:
		return {"tipo": "invalida", "texto": "Escolha de 1 a %d materiais." % MAX_PARTS}
	for id in mix:
		if not data.materials.has(id) or int(mix[id]) <= 0:
			return {"tipo": "invalida", "texto": "Só materiais entram na mistura."}
	var mix_ids := _ids_of_mix(mix)
	var best := "nada"
	for recipe_id in data.recipes:
		var recipe: Dictionary = data.recipes[recipe_id]
		var ids := _ids_of_parts(recipe["entradas"])
		var same_station: bool = recipe["estacao"] == station
		if ids == mix_ids and same_station:
			if not _enough(recipe, mix):
				best = _closer(best, "proporcao")
				continue
			if not recipe["requer"].is_empty():
				return {
					"tipo": "bloqueada",
					"receita": recipe_id,
					"motivo": "Precisa de " + Crafting._requirement_text(recipe["requer"]),
				}
			var secret: bool = recipe["desbloqueio"] == "experimentacao"
			if secret or Crafting.is_unlocked(recipe, mastery, known):
				return {
					"tipo": "receita",
					"receita": recipe_id,
					"nova": secret and not known.has(recipe_id)
				}
			return {
				"tipo": "bloqueada",
				"receita": recipe_id,
				"motivo":
				(
					"%s nível %d"
					% [Mastery.display_name(recipe["maestria"]), int(recipe["nivel_maestria"])]
				),
			}
		# Pistas só apontam para receitas secretas que o jogador ainda não achou.
		if recipe["desbloqueio"] != "experimentacao" or known.has(recipe_id):
			continue
		if ids == mix_ids:
			best = _closer(best, "estacao")
		elif same_station and _subset(mix_ids, ids):
			best = _closer(best, "falta")
		elif same_station and _subset(ids, mix_ids):
			best = _closer(best, "demais")
	return {"tipo": "falhou", "pista": best, "texto": HINTS[best]}


## Receitas secretas reveladas ao descobrir `material`: as que o usam e cujos outros materiais raros
## (ou de tier maior) já foram descobertos. Comuns não travam a cascata.
static func cascade(
	data: DataStore, material: String, discoveries: Dictionary, known: Dictionary
) -> Array[String]:
	var revealed: Array[String] = []
	if data.get_material(material).get("tier", "comum") == "comum":
		return revealed
	for recipe_id in data.recipes:
		var recipe: Dictionary = data.recipes[recipe_id]
		if recipe["desbloqueio"] != "experimentacao" or known.has(recipe_id):
			continue
		var ids := _ids_of_parts(recipe["entradas"])
		if not material in ids:
			continue
		var blocked := false
		for other in ids:
			if other == material:
				continue
			var tier: String = data.get_material(other).get("tier", "comum")
			if tier != "comum" and not discoveries.has(other):
				blocked = true
		if not blocked:
			revealed.append(recipe_id)
	revealed.sort()
	return revealed


static func _closer(current: String, candidate: String) -> String:
	return candidate if HINT_ORDER.find(candidate) < HINT_ORDER.find(current) else current


static func _enough(recipe: Dictionary, mix: Dictionary) -> bool:
	for part in recipe["entradas"]:
		if int(mix.get(part["id"], 0)) < int(part["qtd"]):
			return false
	return true


static func _ids_of_mix(mix: Dictionary) -> Array:
	var ids: Array = mix.keys()
	ids.sort()
	return ids


static func _ids_of_parts(parts: Array) -> Array:
	var ids: Array = []
	for part in parts:
		ids.append(part["id"])
	ids.sort()
	return ids


## Todos os elementos de `small` estão em `big` (e `big` tem mais)?
static func _subset(small: Array, big: Array) -> bool:
	if small.size() >= big.size():
		return false
	for id in small:
		if not id in big:
			return false
	return true

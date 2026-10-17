class_name Crafting
extends RefCounted
## Regras de fabricação: quais receitas o jogador pode fazer agora e por quê não.
## Usado pelo servidor (que decide) e pelo cliente (que mostra o painel).

## Distância máxima (em tiles) do centro do corpo até uma estação para usar as receitas dela.
const STATION_RANGE := 6
## Máximo de trabalhos na fila de cada jogador.
const MAX_QUEUE := 20


## Estações (ids) a até STATION_RANGE tiles do corpo. "mao" sempre conta.
static func stations_near(grid: WorldGrid, data: DataStore, feet: Vector2) -> Dictionary:
	var found := {"mao": true}
	var center := WorldGrid.to_tile(MiningRules.body_center(feet))
	for dy in range(-STATION_RANGE, STATION_RANGE + 1):
		for dx in range(-STATION_RANGE, STATION_RANGE + 1):
			var id := grid.get_tile(center.x + dx, center.y + dy)
			if id <= 0:
				continue
			var name := grid.registry.name_of(id)
			if data.items.get(name, {}).get("tipo") == "estacao":
				found[name] = true
	return found


## A receita está liberada para este jogador (nível de maestria ou descoberta)?
static func is_unlocked(recipe: Dictionary, mastery: Dictionary, known: Dictionary) -> bool:
	match recipe["desbloqueio"]:
		"inicial":
			return true
		"xp":
			var xp := int(mastery.get(recipe["maestria"], 0))
			return Mastery.level_for(xp) >= int(recipe.get("nivel_maestria", 1))
		_:
			return known.has(recipe["id"])


## Situação da receita para o painel e para o servidor:
## {"ok": bool, "motivo": String, "faltando": {id: qtd}}. Ordem de checagem: liberada,
## condição especial, estação, materiais.
static func status(
	recipe: Dictionary,
	data: DataStore,
	inventory: Inventory,
	mastery: Dictionary,
	known: Dictionary,
	stations: Dictionary
) -> Dictionary:
	if not is_unlocked(recipe, mastery, known):
		if recipe["desbloqueio"] == "xp":
			return _fail(
				(
					"%s nível %d"
					% [Mastery.display_name(recipe["maestria"]), int(recipe["nivel_maestria"])]
				)
			)
		return _fail("Receita secreta: descubra experimentando")
	if not recipe["requer"].is_empty():
		return _fail(_requirement_text(recipe["requer"]))
	var station: String = recipe["estacao"]
	if data.items.get(station, {}).get("tipo") == "fenomeno":
		return _fail("Acontece no mundo: %s" % data.display_name(station))
	if not stations.has(station):
		return _fail("Precisa de %s por perto" % data.display_name(station))
	var missing := {}
	for part in recipe["entradas"]:
		var have := inventory.count(part["id"])
		if have < int(part["qtd"]):
			missing[part["id"]] = int(part["qtd"]) - have
	if not missing.is_empty():
		return {"ok": false, "motivo": "Faltam materiais", "faltando": missing}
	return {"ok": true, "motivo": "", "faltando": {}}


static func _requirement_text(alternatives: Array) -> String:
	var parts: PackedStringArray = []
	for alt in alternatives:
		if alt["tipo"] == "magia":
			parts.append("magia %s" % Mastery.display_name(alt["id"]).capitalize())
		else:
			parts.append("evento: %s" % str(alt["id"]).replace("_", " "))
	return "Requer " + " ou ".join(parts)


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "motivo": reason, "faltando": {}}

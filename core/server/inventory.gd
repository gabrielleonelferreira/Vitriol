class_name Inventory
extends RefCounted
## Inventário de um jogador: 40 espaços, os 10 primeiros são a barra de atalhos.
##
## Cada espaço é vazio ({}) ou {"id": String, "qtd": int}. Ferramentas não empilham e
## guardam a durabilidade restante: {"id", "qtd": 1, "durabilidade": int}.

const SIZE := 40
const HOTBAR := 10
const MAX_STACK := 99

var slots: Array[Dictionary] = []
var _data: DataStore


func _init(data: DataStore) -> void:
	_data = data
	for i in SIZE:
		slots.append({})


## Quantos itens deste tipo cabem numa pilha.
func stack_limit(id: String) -> int:
	return 1 if _is_tool(id) else MAX_STACK


## Adiciona e devolve quantos NÃO couberam (0 = tudo guardado).
## Completa pilhas existentes primeiro, depois ocupa espaços vazios (barra antes da mochila).
func add(id: String, qtd: int) -> int:
	if qtd <= 0 or id.is_empty():
		return 0
	var left := qtd
	var limit := stack_limit(id)
	if limit > 1:
		for slot in slots:
			if left == 0:
				break
			if slot.get("id") == id and slot["qtd"] < limit:
				var put := mini(limit - slot["qtd"], left)
				slot["qtd"] += put
				left -= put
	for i in SIZE:
		if left == 0:
			break
		if slots[i].is_empty():
			var put := mini(limit, left)
			slots[i] = {"id": id, "qtd": put}
			if _is_tool(id):
				slots[i]["durabilidade"] = _max_durability(id)
			left -= put
	return left


## Cabe tudo? (sem alterar nada)
func can_add(id: String, qtd: int) -> bool:
	var room := 0
	var limit := stack_limit(id)
	for slot in slots:
		if slot.is_empty():
			room += limit
		elif slot["id"] == id and limit > 1:
			room += limit - slot["qtd"]
		if room >= qtd:
			return true
	return room >= qtd


func count(id: String) -> int:
	var total := 0
	for slot in slots:
		if slot.get("id") == id:
			total += slot["qtd"]
	return total


## Retira itens (das últimas pilhas para as primeiras). Devolve false sem mexer em nada se
## não houver o suficiente.
func remove(id: String, qtd: int) -> bool:
	if count(id) < qtd:
		return false
	var left := qtd
	for i in range(SIZE - 1, -1, -1):
		if left == 0:
			break
		if slots[i].get("id") == id:
			var take := mini(slots[i]["qtd"], left)
			slots[i]["qtd"] -= take
			left -= take
			if slots[i]["qtd"] == 0:
				slots[i] = {}
	return true


## Tira um item de um espaço específico (ex.: a tocha colocada no mundo).
func take_from(index: int, qtd: int = 1) -> bool:
	if index < 0 or index >= SIZE or slots[index].is_empty() or slots[index]["qtd"] < qtd:
		return false
	slots[index]["qtd"] -= qtd
	if slots[index]["qtd"] == 0:
		slots[index] = {}
	return true


func swap(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= SIZE or b >= SIZE or a == b:
		return false
	# Mesmo item empilhável: junta no destino o quanto couber.
	var from := slots[a]
	var to := slots[b]
	if (
		not from.is_empty()
		and not to.is_empty()
		and from["id"] == to["id"]
		and stack_limit(from["id"]) > 1
	):
		var put := mini(stack_limit(to["id"]) - to["qtd"], from["qtd"])
		if put > 0:
			to["qtd"] += put
			from["qtd"] -= put
			if from["qtd"] == 0:
				slots[a] = {}
			return true
	slots[a] = to
	slots[b] = from
	return true


func get_slot(index: int) -> Dictionary:
	return slots[index] if index >= 0 and index < SIZE else {}


## Gasta 1 de durabilidade da ferramenta no espaço. Devolve true se ela quebrou.
func wear(index: int) -> bool:
	var slot := get_slot(index)
	if slot.is_empty() or not slot.has("durabilidade"):
		return false
	slot["durabilidade"] -= 1
	if slot["durabilidade"] <= 0:
		slots[index] = {}
		return true
	return false


func to_array() -> Array:
	var out: Array = []
	for slot in slots:
		out.append(slot.duplicate())
	return out


## Carrega de um save. Itens que não existem mais nos dados são descartados.
func load_array(saved: Array) -> PackedStringArray:
	var dropped := PackedStringArray()
	for i in SIZE:
		slots[i] = {}
		if i >= saved.size() or typeof(saved[i]) != TYPE_DICTIONARY or saved[i].is_empty():
			continue
		var id := str(saved[i].get("id", ""))
		if not _data.has_id(id):
			dropped.append(id)
			continue
		var slot := {"id": id, "qtd": clampi(int(saved[i].get("qtd", 1)), 1, stack_limit(id))}
		if _is_tool(id):
			slot["durabilidade"] = int(saved[i].get("durabilidade", _max_durability(id)))
		slots[i] = slot
	return dropped


func _is_tool(id: String) -> bool:
	return _data.items.has(id) and _data.items[id]["tipo"] == "ferramenta"


func _max_durability(id: String) -> int:
	var value: Variant = _data.items.get(id, {}).get("durabilidade")
	return int(value) if value != null else 1

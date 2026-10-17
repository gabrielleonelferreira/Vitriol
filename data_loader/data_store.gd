class_name DataStore
extends Node
## Dados de jogo carregados de data/generated/*.json (autoload "GameData").
##
## O conteúdo é editado nos CSV de data/content/ e convertido por tools/build_data.py.
## Este carregador confere de novo o essencial, para que um JSON corrompido ou
## desatualizado falhe na hora com uma mensagem clara, e não no meio do jogo.

const DATA_VERSION := 1
const DEFAULT_PATH := "res://data/generated"

var materials: Dictionary = {}
var items: Dictionary = {}
var recipes: Dictionary = {}
var generation: Array[Dictionary] = []
var errors: PackedStringArray = []
var loaded: bool = false

var _recipes_by_station: Dictionary = {}
var _recipes_by_output: Dictionary = {}
var _recipes_by_input: Dictionary = {}


func _ready() -> void:
	if not load_all():
		for message in errors:
			push_error("GameData: " + message)


## Carrega tudo. Devolve false e preenche `errors` se algo estiver errado.
func load_all(base_path: String = DEFAULT_PATH) -> bool:
	_clear()
	var material_rows := _read_list(base_path, "materiais")
	var item_rows := _read_list(base_path, "itens")
	var recipe_rows := _read_list(base_path, "receitas")
	var generation_rows := _read_list(base_path, "geracao")
	if not errors.is_empty():
		return false

	_index(material_rows, materials, "material")
	_index(item_rows, items, "item")
	_index(recipe_rows, recipes, "receita")
	for row in generation_rows:
		generation.append(row)
	for id in items:
		if materials.has(id):
			errors.append("id repetido entre materiais e itens: '%s'" % id)

	_check_references()
	_build_lookups()
	loaded = errors.is_empty()
	return loaded


func has_id(id: String) -> bool:
	return materials.has(id) or items.has(id)


func get_material(id: String) -> Dictionary:
	return materials.get(id, {})


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func get_recipe(id: String) -> Dictionary:
	return recipes.get(id, {})


## Nome exibido de um material ou item.
func display_name(id: String) -> String:
	if materials.has(id):
		return materials[id]["nome"]
	if items.has(id):
		return items[id]["nome"]
	return id


## Material que existe como bloco no mundo (pode ser minerado).
func is_block(id: String) -> bool:
	return materials.has(id) and materials[id]["dureza_bloco"] != null


func recipes_for_station(station_id: String) -> Array:
	return _recipes_by_station.get(station_id, [])


func recipes_producing(id: String) -> Array:
	return _recipes_by_output.get(id, [])


func recipes_using(id: String) -> Array:
	return _recipes_by_input.get(id, [])


## Regras de geração de uma camada (sem a rocha principal).
func generation_for_layer(layer: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row in generation:
		if int(row["camada"]) == layer and row["forma"] != "rocha":
			rows.append(row)
	return rows


## Rocha principal de cada camada, na ordem: [camada 1, camada 2, ...].
func layer_rocks() -> PackedStringArray:
	var by_layer := {}
	for row in generation:
		if row["forma"] == "rocha":
			by_layer[int(row["camada"])] = row["material"]
	var result := PackedStringArray()
	var layer := 1
	while by_layer.has(layer):
		result.append(by_layer[layer])
		layer += 1
	return result


func _clear() -> void:
	materials.clear()
	items.clear()
	recipes.clear()
	generation.clear()
	errors.clear()
	loaded = false
	_recipes_by_station.clear()
	_recipes_by_output.clear()
	_recipes_by_input.clear()


func _read_list(base_path: String, name: String) -> Array:
	var path := "%s/%s.json" % [base_path, name]
	if not FileAccess.file_exists(path):
		errors.append("arquivo não encontrado: %s (rode tools/build_data.py)" % path)
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("%s não é um JSON válido" % path)
		return []
	if int(parsed.get("versao", -1)) != DATA_VERSION:
		errors.append(
			"%s tem versão %s, o jogo espera %d" % [path, str(parsed.get("versao")), DATA_VERSION]
		)
		return []
	var rows: Variant = parsed.get(name)
	if typeof(rows) != TYPE_ARRAY:
		errors.append("%s não tem a lista '%s'" % [path, name])
		return []
	return rows


func _index(rows: Array, target: Dictionary, kind: String) -> void:
	for row in rows:
		var id := str(row.get("id", ""))
		if id.is_empty():
			errors.append("%s sem id" % kind)
		elif target.has(id):
			errors.append("%s repetido: '%s'" % [kind, id])
		else:
			target[id] = row


func _check_references() -> void:
	for recipe_id in recipes:
		var recipe: Dictionary = recipes[recipe_id]
		if not items.has(recipe["estacao"]):
			errors.append("receita '%s': estação '%s' não existe" % [recipe_id, recipe["estacao"]])
		for part in recipe["entradas"] + recipe["saidas"]:
			if not has_id(part["id"]):
				errors.append("receita '%s': '%s' não existe" % [recipe_id, part["id"]])
	for row in generation:
		if not is_block(row["material"]) and row["material"] != "agua":
			errors.append("geração: '%s' não é um bloco" % row["material"])
	if layer_rocks().is_empty():
		errors.append("geração: nenhuma camada tem rocha principal")


func _build_lookups() -> void:
	for recipe_id in recipes:
		var recipe: Dictionary = recipes[recipe_id]
		_append(_recipes_by_station, recipe["estacao"], recipe_id)
		for part in recipe["saidas"]:
			_append(_recipes_by_output, part["id"], recipe_id)
		for part in recipe["entradas"]:
			_append(_recipes_by_input, part["id"], recipe_id)


func _append(target: Dictionary, key: String, value: String) -> void:
	if not target.has(key):
		target[key] = []
	target[key].append(value)

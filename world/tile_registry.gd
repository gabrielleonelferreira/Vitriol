class_name TileRegistry
extends RefCounted
## Tipos de tile do mundo e suas propriedades.
##
## A maioria dos tiles é um material de bloco dos dados de jogo (calcário, malaquita...).
## Alguns são só do mundo e não existem como material: ar, grama, tronco, folhas e a
## rocha da base. O índice de cada tipo na paleta é o número guardado na grade.

const AIR := "ar"
const GRASS := "grama"
const TRUNK := "tronco"
const LEAVES := "folhas"
const WATER := "agua"
const BEDROCK := "rocha_base"

## Tiles que não são materiais: [nome, sólido, quebra em, dureza].
const WORLD_TILES := [
	[AIR, false, "", 0.0],
	[GRASS, true, "terra", 1.0],
	[TRUNK, false, "madeira", 1.0],
	[LEAVES, false, "", 0.5],
	[BEDROCK, true, "", INF],
]

var names: PackedStringArray = []
var solid: PackedByteArray = []
var liquid: PackedByteArray = []
var hardness: PackedFloat32Array = []
var drops: PackedStringArray = []
## Luz emitida pelo tile (tochas): alcance em tiles (0 = não emite) e cor.
var light_radius: PackedFloat32Array = []
var light_color: Array[Color] = []
## Sólido mas deixa ver e passar luz (vidro).
var transparent: PackedByteArray = []
var _ids: Dictionary = {}


## Monta a paleta a partir dos dados de jogo: primeiro os tiles do mundo, depois cada
## material de bloco, e por fim a água. A ordem é estável enquanto os dados não mudarem.
static func from_data(data: DataStore) -> TileRegistry:
	var registry := TileRegistry.new()
	for entry in WORLD_TILES:
		registry._add(entry[0], entry[1], false, entry[3], entry[2])
	var block_ids: Array = []
	for id in data.materials:
		if data.is_block(id):
			block_ids.append(id)
	block_ids.sort()
	for id in block_ids:
		registry._add(id, true, false, float(data.materials[id]["dureza_bloco"]), id)
		if data.materials[id]["categoria"] == "vidro":
			registry.transparent[registry.size() - 1] = 1
	registry._add(WATER, false, true, 0.0, "")
	# Objetos colocáveis (tochas) e estações (bancada, fornalha...): não sólidos, quebram rápido e
	# devolvem o próprio item.
	var object_ids: Array = []
	for id in data.items:
		var kind: String = data.items[id]["tipo"]
		if kind == "objeto" or (kind == "estacao" and id != "mao"):
			object_ids.append(id)
	object_ids.sort()
	for id in object_ids:
		var hard := 0.1 if data.items[id]["tipo"] == "objeto" else 0.8
		registry._add(id, false, false, hard, id)
	for id in registry.names.size():
		var item: Dictionary = data.items.get(registry.names[id], {})
		if item.get("luz_raio") != null and item.get("luz_cor") != null:
			registry.light_radius[id] = float(item["luz_raio"])
			registry.light_color[id] = Color(str(item["luz_cor"]))
	return registry


## Recria a paleta a partir dos nomes (usado pelo cliente ao receber o mundo).
static func from_names(tile_names: PackedStringArray, data: DataStore) -> TileRegistry:
	var reference := TileRegistry.from_data(data)
	var registry := TileRegistry.new()
	for name in tile_names:
		var source := reference.id_of(name)
		if source < 0:
			registry._add(name, true, false, 1.0, "")
		else:
			registry._add(
				name,
				reference.solid[source] == 1,
				reference.liquid[source] == 1,
				reference.hardness[source],
				reference.drops[source]
			)
			registry.light_radius[registry.size() - 1] = reference.light_radius[source]
			registry.transparent[registry.size() - 1] = reference.transparent[source]
			registry.light_color[registry.size() - 1] = reference.light_color[source]
	return registry


func id_of(name: String) -> int:
	return _ids.get(name, -1)


func name_of(id: int) -> String:
	return names[id] if id >= 0 and id < names.size() else AIR


func is_solid(id: int) -> bool:
	return id >= 0 and id < solid.size() and solid[id] == 1


## Bloqueia a visão e a luz (sólido e não transparente).
func is_opaque(id: int) -> bool:
	return is_solid(id) and transparent[id] == 0


func is_liquid(id: int) -> bool:
	return id >= 0 and id < liquid.size() and liquid[id] == 1


func size() -> int:
	return names.size()


func _add(
	name: String, is_solid_tile: bool, is_liquid_tile: bool, hard: float, drop: String
) -> void:
	_ids[name] = names.size()
	names.append(name)
	solid.append(1 if is_solid_tile else 0)
	liquid.append(1 if is_liquid_tile else 0)
	hardness.append(hard)
	drops.append(drop)
	light_radius.append(0.0)
	transparent.append(0)
	light_color.append(Color.WHITE)

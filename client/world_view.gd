class_name WorldView
extends Node2D
## Desenha a grade do mundo em quatro camadas de tiles:
##   paredes (fundo escurecido) → sombras nas paredes → blocos → minérios (sobre a rocha).
##
## Cada bloco tem 16 versões (máscara de 4 bits: topo, direita, baixo, esquerda expostos), com
## contorno, brilho e cantos arredondados só nos lados expostos. O TileSet é montado em código a
## partir de art/tiles/tiles.json (gerado por tools/art/gerar_arte.py).

const TILES_PATH := "res://art/tiles/tiles.png"
const ORES_PATH := "res://art/tiles/minerios.png"
const WALLS_PATH := "res://art/tiles/paredes.png"
const SHADOWS_PATH := "res://art/tiles/sombras.png"
const META_PATH := "res://art/tiles/tiles.json"
const OBJECTS_PATH := "res://art/tiles/objetos.png"
const OBJECTS_META := "res://art/tiles/objetos.json"

const SOURCE_TILES := 0
const SOURCE_ORES := 1
const SOURCE_WALLS := 2
const SOURCE_SHADOWS := 3
const SOURCE_OBJECTS := 4

const TOP := 1
const RIGHT := 2
const BOTTOM := 4
const LEFT := 8

var grid: WorldGrid
var _variants: int = 4
var _rows: Dictionary = {}
var _wall_rows: Dictionary = {}
var _ore_rows: Dictionary = {}
var _layer_rock_names: PackedStringArray = []
## Por id de tile: linha no atlas (-1 = sem arte própria), linha de minério, linha de parede.
var _row_by_id: PackedInt32Array = []
var _ore_row_by_id: PackedInt32Array = []
var _wall_row_by_id: PackedInt32Array = []
var _leaves_id: int = -1
var _trunk_id: int = -1
var _water_id: int = -1

var _walls: TileMapLayer
var _shadows: TileMapLayer
var _tiles: TileMapLayer
var _ores: TileMapLayer
var _objects: TileMapLayer
## Por id de tile: linha em objetos.png (-1 = não é objeto).
var _object_row_by_id: PackedInt32Array = []
var _object_rows: Dictionary = {}


func build(new_grid: WorldGrid, data: DataStore) -> void:
	grid = new_grid
	_layer_rock_names = data.layer_rocks()
	_load_meta()
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(WorldGrid.TILE_SIZE, WorldGrid.TILE_SIZE)
	_add_source(tile_set, SOURCE_TILES, TILES_PATH)
	_add_source(tile_set, SOURCE_ORES, ORES_PATH)
	_add_source(tile_set, SOURCE_WALLS, WALLS_PATH)
	_add_source(tile_set, SOURCE_SHADOWS, SHADOWS_PATH)
	_add_objects(tile_set)
	_walls = _make_layer("Paredes", tile_set, -3)
	_shadows = _make_layer("Sombras", tile_set, -2)
	_tiles = _make_layer("Blocos", tile_set, 0)
	_ores = _make_layer("Minerios", tile_set, 1)
	_objects = _make_layer("Objetos", tile_set, 2)
	_index_tiles()
	var started := Time.get_ticks_msec()
	for y in grid.height:
		for x in grid.width:
			_draw_cell(x, y)
	print(
		(
			"WorldView: %d tiles desenhados em %d ms"
			% [grid.width * grid.height, Time.get_ticks_msec() - started]
		)
	)


## Redesenha um tile e os vizinhos (as bordas dependem deles). Usado ao minerar (Onda 3).
func refresh(x: int, y: int) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if grid.in_bounds(x + dx, y + dy):
				_draw_cell(x + dx, y + dy)


func _load_meta() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("WorldView: não consegui ler %s" % META_PATH)
		return
	_variants = int(parsed.get("variacoes", 4))
	for name in parsed["tiles"]:
		_rows[name] = int(parsed["tiles"][name]["linha"])
	for name in parsed["paredes"]:
		_wall_rows[name] = int(parsed["paredes"][name]["linha"])
	for name in parsed["minerios"]:
		_ore_rows[name] = int(parsed["minerios"][name]["linha"])


func _add_source(tile_set: TileSet, id: int, path: String) -> void:
	var texture: Texture2D = load(path)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(WorldGrid.TILE_SIZE, WorldGrid.TILE_SIZE)
	for row in texture.get_height() / WorldGrid.TILE_SIZE:
		for column in texture.get_width() / WorldGrid.TILE_SIZE:
			source.create_tile(Vector2i(column, row))
	tile_set.add_source(source, id)


## Objetos animados (tocha): cada linha é um objeto, as colunas são os quadros.
func _add_objects(tile_set: TileSet) -> void:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(OBJECTS_META))
	if typeof(meta) != TYPE_DICTIONARY:
		return
	var source := TileSetAtlasSource.new()
	source.texture = load(OBJECTS_PATH)
	source.texture_region_size = Vector2i(WorldGrid.TILE_SIZE, WorldGrid.TILE_SIZE)
	for name in meta["objetos"]:
		var info: Dictionary = meta["objetos"][name]
		var coords := Vector2i(0, int(info["linha"]))
		source.create_tile(coords)
		source.set_tile_animation_frames_count(coords, int(info["quadros"]))
		source.set_tile_animation_speed(coords, float(info["fps"]))
		_object_rows[name] = int(info["linha"])
	tile_set.add_source(source, SOURCE_OBJECTS)


func _make_layer(layer_name: String, tile_set: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.z_index = z
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(layer)
	return layer


func _index_tiles() -> void:
	var count := grid.registry.size()
	_row_by_id.resize(count)
	_ore_row_by_id.resize(count)
	_wall_row_by_id.resize(count)
	_object_row_by_id.resize(count)
	var missing: PackedStringArray = []
	for id in count:
		var name := grid.registry.name_of(id)
		_row_by_id[id] = _rows.get(name, -1)
		_ore_row_by_id[id] = _ore_rows.get(name, -1)
		_wall_row_by_id[id] = _wall_rows.get(name, -1)
		_object_row_by_id[id] = _object_rows.get(name, -1)
		var has_art := _row_by_id[id] >= 0 or _ore_row_by_id[id] >= 0 or _object_row_by_id[id] >= 0
		if not has_art and name != TileRegistry.AIR:
			missing.append(name)
	_leaves_id = grid.registry.id_of(TileRegistry.LEAVES)
	_trunk_id = grid.registry.id_of(TileRegistry.TRUNK)
	_water_id = grid.registry.id_of(TileRegistry.WATER)
	if not missing.is_empty():
		print("WorldView: ainda sem arte (aparecem como a rocha da camada): ", ", ".join(missing))


func _variant(x: int, y: int) -> int:
	return ((x * 73856093) ^ (y * 19349663)) & (_variants - 1)


func _column(mask: int, variant: int) -> int:
	return mask * _variants + variant


## Lados que encostam em algo que não é sólido.
func _exposed_mask(x: int, y: int) -> int:
	var mask := 0
	if not grid.is_solid(x, y - 1):
		mask |= TOP
	if not grid.is_solid(x + 1, y):
		mask |= RIGHT
	if not grid.is_solid(x, y + 1):
		mask |= BOTTOM
	if not grid.is_solid(x - 1, y):
		mask |= LEFT
	return mask


## Lados da copa que não encostam em outras folhas (nem no tronco).
func _leaves_mask(x: int, y: int) -> int:
	var mask := 0
	var offsets := [[0, -1, TOP], [1, 0, RIGHT], [0, 1, BOTTOM], [-1, 0, LEFT]]
	for entry in offsets:
		var neighbor := grid.get_tile(x + entry[0], y + entry[1])
		if neighbor != _leaves_id and neighbor != _trunk_id:
			mask |= entry[2]
	return mask


## Lados de uma parede que têm um bloco sólido na frente, ao lado: recebem sombra.
func _shadow_mask(x: int, y: int) -> int:
	var mask := 0
	if grid.is_solid(x, y - 1):
		mask |= TOP
	if grid.is_solid(x + 1, y):
		mask |= RIGHT
	if grid.is_solid(x, y + 1):
		mask |= BOTTOM
	if grid.is_solid(x - 1, y):
		mask |= LEFT
	return mask


func _draw_cell(x: int, y: int) -> void:
	var cell := Vector2i(x, y)
	var id := grid.get_tile(x, y)
	var wall := grid.get_wall(x, y)
	var variant := _variant(x, y)
	var solid := grid.registry.is_solid(id)

	# Parede e sombra: só onde o bloco da frente deixa ver o fundo.
	if wall != 0 and not solid and _wall_row_by_id[wall] >= 0:
		_walls.set_cell(cell, SOURCE_WALLS, Vector2i(variant, _wall_row_by_id[wall]))
		var shadow := _shadow_mask(x, y)
		if shadow != 0:
			_shadows.set_cell(cell, SOURCE_SHADOWS, Vector2i(shadow, 0))
		else:
			_shadows.erase_cell(cell)
	else:
		_walls.erase_cell(cell)
		_shadows.erase_cell(cell)

	if id == 0 or _object_row_by_id[id] >= 0:
		_tiles.erase_cell(cell)
		_ores.erase_cell(cell)
		if id != 0:
			_objects.set_cell(cell, SOURCE_OBJECTS, Vector2i(0, _object_row_by_id[id]))
		else:
			_objects.erase_cell(cell)
		return
	_objects.erase_cell(cell)

	var row := _row_by_id[id]
	var ore_row := _ore_row_by_id[id]
	var mask := 0
	if solid:
		mask = _exposed_mask(x, y)
		# Minério (ou bloco ainda sem arte): desenha a rocha da camada por baixo.
		if ore_row >= 0 or row < 0:
			row = _row_by_id[_host_rock(x, y, wall)]
	elif id == _leaves_id:
		mask = _leaves_mask(x, y)
	elif id == _trunk_id and grid.is_solid(x, y + 1):
		row = _rows.get("tronco_base", row)
	elif id == _water_id and grid.get_tile(x, y - 1) == 0:
		row = _rows.get("agua_topo", row)

	if row < 0:
		_tiles.erase_cell(cell)
	else:
		_tiles.set_cell(cell, SOURCE_TILES, Vector2i(_column(mask, variant), row))
	if ore_row >= 0:
		_ores.set_cell(cell, SOURCE_ORES, Vector2i(_column(mask, variant), ore_row))
	else:
		_ores.erase_cell(cell)


## Rocha que fica atrás de um minério: a parede, ou a rocha da camada na superfície.
func _host_rock(x: int, y: int, wall: int) -> int:
	if wall != 0 and _row_by_id[wall] >= 0:
		return wall
	var layer := clampi(grid.layer_at(x, y), 1, _layer_rock_names.size())
	return grid.registry.id_of(_layer_rock_names[layer - 1])

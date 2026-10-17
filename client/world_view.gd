class_name WorldView
extends Node2D
## Desenha a grade do mundo com quatro camadas de tiles:
##   paredes (fundo escurecido) → blocos → minérios (sobre a rocha) → bordas.
## O TileSet é montado em código a partir de art/tiles/tiles.json.

const ATLAS_PATH := "res://art/tiles/tiles.png"
const ORES_PATH := "res://art/tiles/minerios.png"
const EDGES_PATH := "res://art/tiles/bordas.png"
const META_PATH := "res://art/tiles/tiles.json"

const SOURCE_TILES := 0
const SOURCE_ORES := 1
const SOURCE_EDGES := 2

var grid: WorldGrid
var _meta: Dictionary = {}
var _variants: int = 4
var _wall_column: int = 4
var _rows: Dictionary = {}
var _ore_rows: Dictionary = {}
var _layer_rock_names: PackedStringArray = []
## Por id de tile: linha no atlas (-1 = não desenha), linha de minério (-1 = não é minério).
var _row_by_id: PackedInt32Array = []
var _ore_row_by_id: PackedInt32Array = []
var _see_through: PackedByteArray = []

var _walls: TileMapLayer
var _tiles: TileMapLayer
var _ores: TileMapLayer
var _edges: TileMapLayer


func build(new_grid: WorldGrid, data: DataStore) -> void:
	grid = new_grid
	_layer_rock_names = data.layer_rocks()
	_load_meta()
	var tile_set := _make_tile_set()
	_walls = _make_layer("Paredes", tile_set, -2)
	_tiles = _make_layer("Blocos", tile_set, 0)
	_ores = _make_layer("Minerios", tile_set, 1)
	_edges = _make_layer("Bordas", tile_set, 2)
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
	_meta = parsed
	_variants = int(_meta.get("variacoes", 4))
	_wall_column = int(_meta.get("coluna_parede", 4))
	for name in _meta["tiles"]:
		_rows[name] = int(_meta["tiles"][name]["linha"])
	for name in _meta["minerios"]:
		_ore_rows[name] = int(_meta["minerios"][name]["linha"])


func _make_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(WorldGrid.TILE_SIZE, WorldGrid.TILE_SIZE)
	_add_source(tile_set, SOURCE_TILES, ATLAS_PATH)
	_add_source(tile_set, SOURCE_ORES, ORES_PATH)
	_add_source(tile_set, SOURCE_EDGES, EDGES_PATH)
	return tile_set


func _add_source(tile_set: TileSet, id: int, path: String) -> void:
	var texture: Texture2D = load(path)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(WorldGrid.TILE_SIZE, WorldGrid.TILE_SIZE)
	var columns := texture.get_width() / WorldGrid.TILE_SIZE
	var rows := texture.get_height() / WorldGrid.TILE_SIZE
	for row in rows:
		for column in columns:
			source.create_tile(Vector2i(column, row))
	tile_set.add_source(source, id)


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
	_see_through.resize(count)
	var missing: PackedStringArray = []
	for id in count:
		var name := grid.registry.name_of(id)
		_row_by_id[id] = _rows.get(name, -1)
		_ore_row_by_id[id] = _ore_rows.get(name, -1)
		var solid := grid.registry.is_solid(id)
		_see_through[id] = 0 if solid else 1
		if _row_by_id[id] < 0 and _ore_row_by_id[id] < 0 and name != TileRegistry.AIR:
			missing.append(name)
	if not missing.is_empty():
		print("WorldView: ainda sem arte (aparecem como a rocha da camada): ", ", ".join(missing))


func _variant(x: int, y: int) -> int:
	return ((x * 73856093) ^ (y * 19349663)) & (_variants - 1)


func _draw_cell(x: int, y: int) -> void:
	var cell := Vector2i(x, y)
	var id := grid.get_tile(x, y)
	var wall := grid.get_wall(x, y)
	var variant := _variant(x, y)

	# Parede: só aparece onde o bloco da frente deixa ver o fundo.
	if wall != 0 and _see_through[id] == 1 and _row_by_id[wall] >= 0:
		_walls.set_cell(cell, SOURCE_TILES, Vector2i(_wall_column + variant, _row_by_id[wall]))
	else:
		_walls.erase_cell(cell)

	# Bloco da frente. Minério: desenha a rocha da camada e o minério por cima.
	var row := _row_by_id[id]
	var ore_row := _ore_row_by_id[id]
	if ore_row >= 0 or (row < 0 and id != 0):
		row = _row_by_id[_host_rock(x, y, wall)]
	elif grid.registry.name_of(id) == TileRegistry.WATER and grid.get_tile(x, y - 1) == 0:
		row = _rows.get("agua_topo", row)
	if id == 0 or row < 0:
		_tiles.erase_cell(cell)
	else:
		_tiles.set_cell(cell, SOURCE_TILES, Vector2i(variant, row))
	if ore_row >= 0:
		_ores.set_cell(cell, SOURCE_ORES, Vector2i(variant, ore_row))
	else:
		_ores.erase_cell(cell)

	# Bordas: lados de um bloco sólido que encostam em algo não sólido.
	if grid.registry.is_solid(id):
		var mask := 0
		if not grid.is_solid(x, y - 1):
			mask |= 1
		if not grid.is_solid(x + 1, y):
			mask |= 2
		if not grid.is_solid(x, y + 1):
			mask |= 4
		if not grid.is_solid(x - 1, y):
			mask |= 8
		if mask != 0:
			_edges.set_cell(cell, SOURCE_EDGES, Vector2i(mask, 0))
		else:
			_edges.erase_cell(cell)
	else:
		_edges.erase_cell(cell)


## Rocha que fica atrás de um minério: a parede, ou a rocha da camada na superfície.
func _host_rock(x: int, y: int, wall: int) -> int:
	if wall != 0:
		return wall
	var layer := clampi(grid.layer_at(x, y), 1, _layer_rock_names.size())
	return grid.registry.id_of(_layer_rock_names[layer - 1])

class_name WorldGrid
extends RefCounted
## Grade de tiles do mundo: tiles da frente (o que bloqueia e é minerado) e paredes de
## fundo (o que aparece atrás quando um bloco é escavado).
##
## Coordenadas em tiles; x cresce para a direita, y cresce para baixo. Fora da grade:
## as laterais e o fundo são sólidos (paredes do mundo) e acima do topo é ar.

const TILE_SIZE := 16

var width: int = 0
var height: int = 0
var tiles: PackedInt32Array = []
var walls: PackedInt32Array = []
## Linha (y) do primeiro tile da superfície em cada coluna.
var surface: PackedInt32Array = []
## Para cada camada, a linha (y) onde ela começa em cada coluna.
var layer_tops: Array[PackedInt32Array] = []
var spawn_tile: Vector2i = Vector2i.ZERO
var registry: TileRegistry


func _init(new_width: int = 0, new_height: int = 0, new_registry: TileRegistry = null) -> void:
	width = new_width
	height = new_height
	registry = new_registry
	tiles.resize(width * height)
	walls.resize(width * height)
	surface.resize(width)


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func get_tile(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return -1
	return tiles[y * width + x]


func set_tile(x: int, y: int, id: int) -> void:
	if in_bounds(x, y):
		tiles[y * width + x] = id


func get_wall(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return 0
	return walls[y * width + x]


func set_wall(x: int, y: int, id: int) -> void:
	if in_bounds(x, y):
		walls[y * width + x] = id


func tile_name(x: int, y: int) -> String:
	return registry.name_of(get_tile(x, y))


## Sólido para colisão. Fora da grade: laterais e fundo são sólidos, o céu não.
func is_solid(x: int, y: int) -> bool:
	if y < 0:
		return false
	if not in_bounds(x, y):
		return true
	return registry.is_solid(tiles[y * width + x])


## Camada (1, 2, 3...) de uma posição. 0 = acima da superfície.
func layer_at(x: int, y: int) -> int:
	x = clampi(x, 0, width - 1)
	if y < surface[x]:
		return 0
	var layer := 1
	for index in range(1, layer_tops.size()):
		if y >= layer_tops[index][x]:
			layer = index + 1
	return layer


## Ponto de nascimento em pixels: pés do personagem sobre o chão, no centro do tile.
func spawn_position() -> Vector2:
	return Vector2((spawn_tile.x + 0.5) * TILE_SIZE, spawn_tile.y * TILE_SIZE)


## Pixel → tile.
static func to_tile(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / TILE_SIZE), floori(position.y / TILE_SIZE))


## Conta tiles por nome. Útil em testes e para depurar a geração.
func count_by_name() -> Dictionary:
	var counts := {}
	for id in tiles:
		var name := registry.name_of(id)
		counts[name] = counts.get(name, 0) + 1
	return counts


## Cópia serializável para enviar ao cliente.
func to_snapshot() -> Dictionary:
	var tops: Array = []
	for row in layer_tops:
		tops.append(row.duplicate())
	return {
		"width": width,
		"height": height,
		"tiles": tiles.duplicate(),
		"walls": walls.duplicate(),
		"surface": surface.duplicate(),
		"layer_tops": tops,
		"spawn": [spawn_tile.x, spawn_tile.y],
		"palette": registry.names.duplicate(),
	}


static func from_snapshot(snapshot: Dictionary, data: DataStore) -> WorldGrid:
	var registry := TileRegistry.from_names(snapshot["palette"], data)
	var grid := WorldGrid.new(snapshot["width"], snapshot["height"], registry)
	grid.tiles = PackedInt32Array(snapshot["tiles"])
	grid.walls = PackedInt32Array(snapshot["walls"])
	grid.surface = PackedInt32Array(snapshot["surface"])
	for row in snapshot["layer_tops"]:
		grid.layer_tops.append(PackedInt32Array(row))
	grid.spawn_tile = Vector2i(snapshot["spawn"][0], snapshot["spawn"][1])
	return grid

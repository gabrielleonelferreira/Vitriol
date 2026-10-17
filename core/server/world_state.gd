class_name WorldState
extends RefCounted
## Estado autoritativo do mundo. Só o GameServer altera este objeto.

## Duração de um dia no jogo, em segundos reais.
const DAY_SECONDS := 1200.0
## O jogo começa de manhã.
const START_TIME := 0.3

var world_seed: int = 0
var grid: WorldGrid
## Hora do dia de 0 a 1 (0 = meia-noite, 0,5 = meio-dia).
var time_of_day: float = START_TIME
## Tiles alterados desde a geração, índice -> nome. Serve para depurar e para o multiplayer
## mandar só as mudanças; o save guarda a grade inteira.
var changes: Dictionary = {}


func _init(new_seed: int = 0) -> void:
	world_seed = new_seed


## Gera o mundo. `width` e `height` menores servem para testes rápidos.
func generate(
	data: DataStore,
	width: int = WorldGenerator.DEFAULT_WIDTH,
	height: int = WorldGenerator.DEFAULT_HEIGHT
) -> void:
	grid = WorldGenerator.new().generate(world_seed, data, width, height)


func is_ready() -> bool:
	return grid != null


## Avança a simulação do mundo em um tick do servidor.
func step(delta: float) -> void:
	time_of_day = fposmod(time_of_day + delta / DAY_SECONDS, 1.0)


## Troca um tile e registra a mudança. Devolve [x, y, nome] para avisar os clientes.
func set_tile(x: int, y: int, id: int) -> Array:
	grid.set_tile(x, y, id)
	changes[y * grid.width + x] = grid.registry.name_of(id)
	return [x, y, grid.registry.name_of(id)]


## Árvore derrubada pela base: o tronco conectado acima e a copa presa a ele.
## Devolve as posições, troncos primeiro.
func tree_from(x: int, y: int) -> Array[Vector2i]:
	var trunk := grid.registry.id_of(TileRegistry.TRUNK)
	var leaves := grid.registry.id_of(TileRegistry.LEAVES)
	var trunks: Array[Vector2i] = []
	var ty := y
	while grid.get_tile(x, ty) == trunk:
		trunks.append(Vector2i(x, ty))
		ty -= 1
	var crown: Array[Vector2i] = []
	var seen := {}
	var frontier: Array[Vector2i] = [Vector2i(x, ty)]
	while not frontier.is_empty() and crown.size() < 60:
		var cell: Vector2i = frontier.pop_back()
		if seen.has(cell) or grid.get_tile(cell.x, cell.y) != leaves:
			continue
		if absi(cell.x - x) > 4 or cell.y > y:
			continue
		seen[cell] = true
		crown.append(cell)
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			frontier.append(cell + offset)
	return trunks + crown


## Luz do sol de 0 (noite) a 1 (meio-dia), com transições no amanhecer e no anoitecer.
static func daylight(time: float) -> float:
	var sun := -cos(time * TAU)  # 1 ao meio-dia, -1 à meia-noite
	return clampf(0.5 + sun * 0.9, 0.0, 1.0)


func to_save() -> Dictionary:
	var tops: Array = []
	for row in grid.layer_tops:
		tops.append(Marshalls.raw_to_base64(row.to_byte_array()))
	return {
		"semente": world_seed,
		"hora": time_of_day,
		"largura": grid.width,
		"altura": grid.height,
		"paleta": grid.registry.names,
		"tiles": _pack(grid.tiles),
		"paredes": _pack(grid.walls),
		"superficie": Marshalls.raw_to_base64(grid.surface.to_byte_array()),
		"camadas": tops,
		"nascimento": [grid.spawn_tile.x, grid.spawn_tile.y],
	}


## Recria o mundo de um save. Tiles cujo nome não existe mais nos dados viram ar.
static func from_save(saved: Dictionary, data: DataStore) -> WorldState:
	var state := WorldState.new(int(saved["semente"]))
	state.time_of_day = float(saved.get("hora", START_TIME))
	var registry := TileRegistry.from_data(data)
	var width := int(saved["largura"])
	var height := int(saved["altura"])
	var grid := WorldGrid.new(width, height, registry)
	var remap := PackedInt32Array()
	for name in saved["paleta"]:
		remap.append(maxi(registry.id_of(name), 0))
	grid.tiles = _unpack(saved["tiles"], width * height, remap)
	grid.walls = _unpack(saved["paredes"], width * height, remap)
	grid.surface = Marshalls.base64_to_raw(saved["superficie"]).to_int32_array()
	for row in saved["camadas"]:
		grid.layer_tops.append(Marshalls.base64_to_raw(row).to_int32_array())
	grid.spawn_tile = Vector2i(int(saved["nascimento"][0]), int(saved["nascimento"][1]))
	state.grid = grid
	return state


static func _pack(values: PackedInt32Array) -> String:
	return Marshalls.raw_to_base64(values.to_byte_array().compress(FileAccess.COMPRESSION_ZSTD))


static func _unpack(text: String, count: int, remap: PackedInt32Array) -> PackedInt32Array:
	var raw := Marshalls.base64_to_raw(text).decompress(count * 4, FileAccess.COMPRESSION_ZSTD)
	var values := raw.to_int32_array()
	for i in values.size():
		var old := values[i]
		values[i] = remap[old] if old >= 0 and old < remap.size() else 0
	return values

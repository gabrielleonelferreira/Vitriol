extends TestCase
## Geração do mundo.

const W := 400
const H := WorldGenerator.DEFAULT_HEIGHT

var _data: DataStore


func _init() -> void:
	_data = DataStore.new()
	_data.load_all()


func cleanup() -> void:
	_data.free()


func _gen(world_seed: int, width: int = W) -> WorldGrid:
	return WorldGenerator.new().generate(world_seed, _data, width, H)


func test_mesma_semente_mesmo_mundo() -> void:
	var a := _gen(42)
	var b := _gen(42)
	var c := _gen(43)
	check(a.tiles == b.tiles, "mesma semente gera os mesmos tiles")
	check(a.walls == b.walls, "mesma semente gera as mesmas paredes")
	check(a.tiles != c.tiles, "semente diferente gera outro mundo")


func test_camadas_em_ordem() -> void:
	var grid := _gen(7)
	check_eq(grid.layer_tops.size(), 3, "três camadas no MVP")
	var ok := true
	for x in grid.width:
		var solo := grid.surface[x]
		var sed: int = grid.layer_tops[1][x]
		var meta: int = grid.layer_tops[2][x]
		if not (solo + WorldGenerator.MIN_SOLO_DEPTH <= sed and sed < meta and meta < H - 10):
			ok = false
	check(ok, "Solo < Sedimentar < Metamórfica < base, em todas as colunas")
	check_eq(grid.layer_at(grid.spawn_tile.x, grid.spawn_tile.y - 3), 0, "acima do chão é céu")
	check_eq(grid.layer_at(grid.spawn_tile.x, grid.spawn_tile.y + 2), 1, "logo abaixo é Solo")


func test_rocha_principal_por_camada() -> void:
	var grid := _gen(11)
	var rock_ids := [
		grid.registry.id_of("terra"), grid.registry.id_of("calcario"), grid.registry.id_of("xisto")
	]
	for layer in 3:
		var x := grid.width / 3
		var y: int = grid.layer_tops[layer][x] + 5
		check_eq(
			grid.get_wall(x, y), rock_ids[layer], "parede da camada %d é a rocha dela" % (layer + 1)
		)


func test_minerios_nas_camadas_certas() -> void:
	var grid := _gen(5)
	var found := {}
	for y in grid.height:
		for x in grid.width:
			var name := grid.tile_name(x, y)
			if name in ["malaquita", "carvao_mineral", "hematita", "quartzo", "acantita", "silex"]:
				var layer := grid.layer_at(x, y)
				if not found.has(name):
					found[name] = {}
				found[name][layer] = true
	for name in ["carvao_mineral", "hematita", "quartzo", "silex", "malaquita"]:
		check(found.has(name), "%s aparece no mundo" % name)
	check(found.get("hematita", {}).keys() == [3], "hematita só na Metamórfica")
	check(found.get("carvao_mineral", {}).keys() == [2], "carvão só na Sedimentar")
	check(not found.get("quartzo", {}).has(1), "quartzo nunca no Solo")


func test_superficie_tem_lagos_arvores_e_grama() -> void:
	var grid := _gen(3, 800)
	var counts := grid.count_by_name()
	check(counts.get("agua", 0) > 20, "há lagos com água")
	check(counts.get("cascalho", 0) > 5, "lagos têm leito de cascalho")
	check(counts.get("tronco", 0) > 20, "há árvores")
	check(counts.get("grama", 0) > grid.width / 2, "a superfície é gramada")
	check(counts.get("ar", 0) > grid.width * 40, "há céu e cavernas")


func test_nascimento_seguro() -> void:
	for world_seed in [1, 2, 3, 99]:
		var grid := _gen(world_seed)
		var s := grid.spawn_tile
		check(grid.is_solid(s.x, s.y), "semente %d: chão sólido sob o nascimento" % world_seed)
		check(
			not grid.is_solid(s.x, s.y - 1) and not grid.is_solid(s.x, s.y - 2),
			"semente %d: espaço livre para o corpo (2 tiles)" % world_seed
		)


func test_base_indestrutivel() -> void:
	var grid := _gen(8)
	var bedrock := grid.registry.id_of(TileRegistry.BEDROCK)
	var ok := true
	for x in grid.width:
		if grid.get_tile(x, H - 1) != bedrock:
			ok = false
	check(ok, "última linha é rocha da base em todas as colunas")
	check(grid.registry.hardness[bedrock] == INF, "rocha da base não pode ser minerada")


func test_snapshot_ida_e_volta() -> void:
	var grid := _gen(21)
	var copy := WorldGrid.from_snapshot(grid.to_snapshot(), _data)
	check(copy.tiles == grid.tiles, "tiles iguais após snapshot")
	check(copy.walls == grid.walls, "paredes iguais após snapshot")
	check_eq(copy.spawn_tile, grid.spawn_tile, "nascimento igual")
	check_eq(copy.registry.names, grid.registry.names, "paleta igual")
	check_eq(copy.layer_at(10, 200), grid.layer_at(10, 200), "camadas iguais")


func test_tempo_de_geracao() -> void:
	var started := Time.get_ticks_msec()
	_gen(1, WorldGenerator.DEFAULT_WIDTH)
	var elapsed := Time.get_ticks_msec() - started
	print("        mundo %dx%d em %d ms" % [WorldGenerator.DEFAULT_WIDTH, H, elapsed])
	check(elapsed < 8000, "mundo completo gera em menos de 8 s (%d ms)" % elapsed)

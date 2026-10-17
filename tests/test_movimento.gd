extends TestCase
## Onda 5D: portas, plataformas, escada de mão e corda (física e regras de construção).

const DT := 1.0 / 60.0
const GameServerScript := preload("res://core/server/game_server.gd")

var _data: DataStore
var _reg: TileRegistry


func _init() -> void:
	_data = DataStore.new()
	_data.load_all()
	_reg = TileRegistry.from_data(_data)


func cleanup() -> void:
	_data.free()


## Grade 40x30 com chão sólido a partir da linha 25.
func _flat() -> WorldGrid:
	var grid := WorldGrid.new(40, 30, _reg)
	for x in 40:
		for y in range(25, 30):
			grid.set_tile(x, y, _reg.id_of("calcario"))
	return grid


func _motor_at(tile_x: int, tile_y: int) -> PlayerMotor:
	var motor := PlayerMotor.new()
	motor.position = Vector2((tile_x + 0.5) * 16, tile_y * 16)
	return motor


func _run(
	motor: PlayerMotor, grid: WorldGrid, seconds: float, move: float, up: bool, down: bool
) -> void:
	for i in int(seconds / DT):
		motor.step(move, up and i == 0, up, DT, grid, down)


func test_sobe_e_desce_a_escada() -> void:
	var grid := _flat()
	for y in range(15, 25):
		grid.set_tile(10, y, _reg.id_of("escada"))
	var motor := _motor_at(10, 25)
	_run(motor, grid, 0.2, 0.0, false, false)
	check(motor.on_floor, "começa no chão, ao pé da escada")
	_run(motor, grid, 3.0, 0.0, true, false)
	check_eq(motor.position.y, 15.0 * 16, "subiu até o topo e ficou em pé no último degrau")
	check(motor.on_floor and not motor.climbing, "no topo, apoiado como numa plataforma")
	_run(motor, grid, 0.5, 0.0, false, false)
	check_eq(motor.position.y, 15.0 * 16, "parado no topo, não cai")
	_run(motor, grid, 0.4, 0.0, false, true)
	check(motor.climbing, "apertar para baixo no topo volta para a escada")
	check(motor.position.y > 15.0 * 16 + 20, "e desce")
	_run(motor, grid, 0.3, 0.0, false, false)
	var hanging := motor.position.y
	_run(motor, grid, 0.5, 0.0, false, false)
	check_eq(motor.position.y, hanging, "pendurado sem apertar nada, fica parado")
	_run(motor, grid, 0.6, 1.0, false, false)
	check(not motor.climbing, "andando para o lado, sai da escada")


func test_plataforma_de_mao_unica() -> void:
	var grid := _flat()
	for x in range(5, 15):
		grid.set_tile(x, 23, _reg.id_of("plataforma"))
	var motor := _motor_at(10, 25)
	_run(motor, grid, 0.6, 0.0, true, false)
	_run(motor, grid, 0.8, 0.0, false, false)
	check_eq(motor.position.y, 23.0 * 16, "pulou através por baixo e ficou em cima")
	check(motor.on_floor, "a plataforma segura")
	_run(motor, grid, 0.05, 0.0, false, true)
	_run(motor, grid, 0.8, 0.0, false, false)
	check_eq(motor.position.y, 25.0 * 16, "apertar para baixo atravessa e cai no chão")
	check(not PlayerMotor.overlaps_solid(grid, motor.position), "plataforma não conta como sólido")


func test_porta_deixa_passar_e_segura_a_luz() -> void:
	var grid := _flat()
	for y in range(20, 25):
		grid.set_tile(12, y, _reg.id_of("tijolo"))
	grid.set_tile(12, 24, _reg.id_of("porta"))
	grid.set_tile(12, 23, _reg.id_of(TileRegistry.DOOR_TOP))
	var motor := _motor_at(9, 25)
	_run(motor, grid, 1.2, 1.0, false, false)
	check(motor.position.x > 13 * 16, "atravessou a parede pela porta")
	check(_reg.is_opaque(_reg.id_of("porta")), "porta fechada segura a luz")


func _server(received: Array[Dictionary]) -> Array:
	var server = GameServerScript.new()
	server.start(7, _data, 200, WorldGenerator.DEFAULT_HEIGHT)
	var transport := LocalTransport.new(server)
	transport.event_received.connect(func(event: Dictionary) -> void: received.append(event))
	transport.open()
	transport.send({"type": Commands.JOIN, "name": "Teste"})
	server.step_once()
	var player: PlayerState = server.players[transport.peer_id]
	for i in Inventory.SIZE:
		player.inventory.slots[i] = {}
	return [server, transport, player]


func _clear(grid: WorldGrid, x0: int, x1: int, y0: int, y1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			grid.set_tile(x, y, 0)


func test_colocar_porta_e_desmontar() -> void:
	var received: Array[Dictionary] = []
	var s := _server(received)
	var server = s[0]
	var player: PlayerState = s[2]
	var grid: WorldGrid = server.world.grid
	var spawn := grid.spawn_tile
	var spot := Vector2i(spawn.x + 2, spawn.y - 1)
	_clear(grid, spot.x, spot.x, spot.y - 2, spot.y)
	grid.set_tile(spot.x, spot.y + 1, _reg.id_of("terra"))
	player.inventory.add("porta", 1)
	player.selected = 0
	s[1].send({"type": Commands.PLACE, "x": spot.x, "y": spot.y})
	server.step_once()
	check_eq(grid.tile_name(spot.x, spot.y), "porta", "metade de baixo")
	check_eq(grid.tile_name(spot.x, spot.y - 1), TileRegistry.DOOR_TOP, "metade de cima")
	check_eq(player.inventory.count("porta"), 0, "gastou a porta")
	player.mining_target = spot - Vector2i(0, 1)
	player.mining_progress = 0.99
	player.mining_active = true
	s[1].send({"type": Commands.MINE, "x": spot.x, "y": spot.y - 1})
	for i in 4:
		server.step_once()
	check_eq(grid.tile_name(spot.x, spot.y), "ar", "quebrar a metade de cima tira a porta inteira")
	check_eq(player.inventory.count("porta"), 1, "devolve 1 porta")
	s[1].close()
	server.free()


func test_corda_desenrola_ate_o_fundo() -> void:
	var received: Array[Dictionary] = []
	var s := _server(received)
	var server = s[0]
	var player: PlayerState = s[2]
	var grid: WorldGrid = server.world.grid
	var spawn := grid.spawn_tile
	var x := spawn.x + 2
	var top := spawn.y
	# Poço de 12 blocos ao lado do jogador, com chão no fundo.
	_clear(grid, x, x, top, top + 11)
	grid.set_tile(x, top + 12, _reg.id_of("calcario"))
	grid.set_tile(x, top - 1, _reg.id_of("calcario"))
	player.inventory.add("corda", 2)
	player.selected = 0
	s[1].send({"type": Commands.PLACE, "x": x, "y": top})
	server.step_once()
	var length := 0
	for y in range(top, top + 13):
		if grid.tile_name(x, y) == "corda":
			length += 1
	check_eq(length, 12, "desenrolou até o fundo do poço")
	check_eq(player.inventory.count("corda"), 1, "um rolo por corda")
	player.mining_target = Vector2i(x, top + 2)
	player.mining_progress = 0.99
	player.mining_active = true
	s[1].send({"type": Commands.MINE, "x": x, "y": top + 2})
	for i in 4:
		server.step_once()
	check_eq(grid.tile_name(x, top), "ar", "quebrar no meio recolhe a corda inteira")
	check_eq(player.inventory.count("corda"), 2, "o rolo volta")
	s[1].close()
	server.free()


func test_regras_de_apoio() -> void:
	var grid := _flat()
	var feet: Array[Vector2] = []
	check(
		not Building.placement_problem(grid, Vector2i(10, 10), Building.ROPE, feet).is_empty(),
		"corda solta no ar não pega"
	)
	check(
		Building.placement_problem(grid, Vector2i(10, 24), Building.LADDER, feet).is_empty(),
		"escada no chão pega"
	)
	grid.set_tile(10, 24, _reg.id_of("escada"))
	check(
		Building.placement_problem(grid, Vector2i(10, 23), Building.LADDER, feet).is_empty(),
		"escada em cima de escada pega (dá para subir colocando)"
	)
	check(
		not Building.placement_problem(grid, Vector2i(20, 10), Building.PLATFORM, feet).is_empty(),
		"plataforma solta no ar não pega"
	)
	grid.set_tile(19, 24, _reg.id_of("calcario"))
	check(
		Building.placement_problem(grid, Vector2i(25, 24), Building.DOOR, feet).is_empty(),
		"porta no chão com 2 de altura livre pega"
	)
	grid.set_tile(25, 23, _reg.id_of("calcario"))
	check(
		not Building.placement_problem(grid, Vector2i(25, 24), Building.DOOR, feet).is_empty(),
		"porta sem espaço em cima não pega"
	)
	check_eq(Building.kind_for(_data, "escada"), Building.LADDER, "escada é escada")
	check_eq(Building.kind_for(_data, "tocha"), Building.OBJECT, "tocha continua objeto comum")


func test_folhas_dao_fibra_e_corda() -> void:
	check(_data.recipes.has("torcer_corda"), "receita da corda")
	check_eq(_data.get_recipe("torcer_corda")["entradas"][0]["id"], "fibra", "corda de fibra")
	check(_data.materials.has("fibra"), "fibra vegetal existe")

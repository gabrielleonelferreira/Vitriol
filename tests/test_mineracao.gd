extends TestCase
## Mineração, colocação de tochas e descobertas (pelo servidor).

const GameServerScript := preload("res://core/server/game_server.gd")

var _data: DataStore


func _init() -> void:
	_data = DataStore.new()
	_data.load_all()


func cleanup() -> void:
	_data.free()


## Servidor com um mundo pequeno e um jogador conectado.
func _setup(received: Array[Dictionary]) -> Array:
	var server = GameServerScript.new()
	server.start(7, _data, 200, WorldGenerator.DEFAULT_HEIGHT)
	var transport := LocalTransport.new(server)
	transport.event_received.connect(func(event: Dictionary) -> void: received.append(event))
	transport.open()
	transport.send({"type": Commands.JOIN, "name": "Teste"})
	server.step_once()
	return [server, transport, server.players[transport.peer_id]]


func _hold(server: Node, transport: LocalTransport, tile: Vector2i, seconds: float) -> void:
	for i in int(seconds * GameServerScript.TICK_RATE):
		transport.send({"type": Commands.MINE, "x": tile.x, "y": tile.y})
		server.step_once()


func _events(received: Array[Dictionary], type: String) -> Array:
	return received.filter(func(event: Dictionary) -> bool: return event["type"] == type)


func test_tempo_de_quebra() -> void:
	check_eq(MiningRules.break_time(3, 1, true), INF, "mão não quebra calcário")
	check_eq(MiningRules.break_time(INF, 10, false), INF, "nada quebra a rocha da base")
	var hand_dirt := MiningRules.break_time(1, 1, true)
	check(hand_dirt > 0.8 and hand_dirt < 1.0, "terra na mão leva ~0,9 s (%.2f)" % hand_dirt)
	check(
		MiningRules.break_time(3, 7.5, false) < MiningRules.break_time(3, 4, false),
		"picareta mais forte quebra mais rápido"
	)


func test_minerar_terra_com_a_mao() -> void:
	var received: Array[Dictionary] = []
	var setup := _setup(received)
	var server = setup[0]
	var player: PlayerState = setup[2]
	var spawn: Vector2i = server.world.grid.spawn_tile
	var below := Vector2i(spawn.x + 1, spawn.y)
	var before: String = server.world.grid.tile_name(below.x, below.y)
	check(before in ["grama", "terra"], "ao lado do pé há grama ou terra (%s)" % before)
	_hold(server, setup[1], below, 0.5)
	check_eq(
		server.world.grid.tile_name(below.x, below.y),
		before,
		"na metade do tempo ainda não quebrou"
	)
	_hold(server, setup[1], below, 0.6)
	check_eq(server.world.grid.tile_name(below.x, below.y), "ar", "quebrou depois de ~1 s")
	check_eq(player.inventory.count("terra"), 1, "terra no inventário (grama rende terra)")
	check(not _events(received, Events.TILE_CHANGED).is_empty(), "avisou a mudança de tile")
	check(not _events(received, Events.DISCOVERED).is_empty(), "primeira terra é uma descoberta")
	check(player.discoveries.has("terra"), "descoberta registrada")
	setup[1].close()
	server.free()


func test_fora_do_alcance() -> void:
	var received: Array[Dictionary] = []
	var setup := _setup(received)
	var server = setup[0]
	var spawn: Vector2i = server.world.grid.spawn_tile
	var far := Vector2i(spawn.x + 9, spawn.y + 2)
	var before: int = server.world.grid.get_tile(far.x, far.y)
	_hold(server, setup[1], far, 2.0)
	check_eq(server.world.grid.get_tile(far.x, far.y), before, "longe demais não quebra")
	setup[1].close()
	server.free()


func test_duro_demais_avisa() -> void:
	var received: Array[Dictionary] = []
	var setup := _setup(received)
	var server = setup[0]
	var grid: WorldGrid = server.world.grid
	var spawn: Vector2i = grid.spawn_tile
	var target := Vector2i(spawn.x, spawn.y + 1)
	grid.set_tile(target.x, target.y, grid.registry.id_of("calcario"))
	_hold(server, setup[1], target, 2.0)
	check_eq(grid.tile_name(target.x, target.y), "calcario", "calcário não quebra na mão")
	var warnings := _events(received, Events.MESSAGE)
	check(
		not warnings.is_empty() and "força 3" in warnings.back()["text"], "avisa a força necessária"
	)
	setup[1].close()
	server.free()


func test_picareta_desgasta() -> void:
	var received: Array[Dictionary] = []
	var setup := _setup(received)
	var server = setup[0]
	var player: PlayerState = setup[2]
	var grid: WorldGrid = server.world.grid
	player.inventory.slots[0] = {}
	player.inventory.add("picareta_silex", 1)
	var slot := 0
	for i in Inventory.HOTBAR:
		if player.inventory.get_slot(i).get("id") == "picareta_silex":
			slot = i
	player.selected = slot
	var spawn: Vector2i = grid.spawn_tile
	var target := Vector2i(spawn.x, spawn.y + 1)
	grid.set_tile(target.x, target.y, grid.registry.id_of("calcario"))
	_hold(server, setup[1], target, 1.5)
	check_eq(grid.tile_name(target.x, target.y), "ar", "picareta de sílex quebra calcário")
	check_eq(player.inventory.get_slot(slot)["durabilidade"], 39, "gastou 1 de durabilidade")
	check_eq(player.inventory.count("calcario"), 1, "calcário no inventário")
	setup[1].close()
	server.free()


func test_derrubar_arvore() -> void:
	var received: Array[Dictionary] = []
	var setup := _setup(received)
	var server = setup[0]
	var player: PlayerState = setup[2]
	var grid: WorldGrid = server.world.grid
	var spawn: Vector2i = grid.spawn_tile
	var trunk := grid.registry.id_of(TileRegistry.TRUNK)
	var leaves := grid.registry.id_of(TileRegistry.LEAVES)
	var base := Vector2i(spawn.x + 2, spawn.y - 1)
	for h in 5:
		grid.set_tile(base.x, base.y - h, trunk)
	for dx in range(-1, 2):
		grid.set_tile(base.x + dx, base.y - 5, leaves)
	_hold(server, setup[1], base, 1.2)
	var left := 0
	for h in 6:
		for dx in range(-1, 2):
			if grid.get_tile(base.x + dx, base.y - h) in [trunk, leaves]:
				left += 1
	check_eq(left, 0, "a árvore inteira cai")
	check_eq(player.inventory.count("madeira"), 5, "5 troncos = 5 madeiras")
	setup[1].close()
	server.free()


func test_colocar_tocha() -> void:
	var received: Array[Dictionary] = []
	var setup := _setup(received)
	var server = setup[0]
	var player: PlayerState = setup[2]
	var grid: WorldGrid = server.world.grid
	check_eq(player.inventory.count("tocha"), 10, "kit inicial: 10 tochas")
	player.selected = 0
	var spawn: Vector2i = grid.spawn_tile
	var spot := Vector2i(spawn.x + 2, spawn.y - 1)
	grid.set_tile(spot.x, spot.y, 0)
	setup[1].send({"type": Commands.PLACE, "x": spot.x, "y": spot.y})
	server.step_once()
	check_eq(grid.tile_name(spot.x, spot.y), "tocha", "tocha colocada no chão")
	check_eq(player.inventory.count("tocha"), 9, "gastou uma tocha")
	check(grid.registry.light_radius[grid.get_tile(spot.x, spot.y)] > 0, "tocha emite luz")
	var floating := Vector2i(spawn.x + 2, spawn.y - 4)
	grid.set_tile(floating.x, floating.y, 0)
	setup[1].send({"type": Commands.PLACE, "x": floating.x, "y": floating.y})
	server.step_once()
	check_eq(grid.tile_name(floating.x, floating.y), "ar", "não flutua no céu sem apoio")
	_hold(server, setup[1], spot, 0.5)
	check_eq(player.inventory.count("tocha"), 10, "quebrar a tocha devolve o item")
	setup[1].close()
	server.free()


func test_inventario_cheio() -> void:
	var received: Array[Dictionary] = []
	var setup := _setup(received)
	var server = setup[0]
	var player: PlayerState = setup[2]
	var grid: WorldGrid = server.world.grid
	for i in Inventory.SIZE:
		player.inventory.slots[i] = {"id": "areia", "qtd": 99}
	var spawn: Vector2i = grid.spawn_tile
	var target := Vector2i(spawn.x + 1, spawn.y)
	var before: int = grid.get_tile(target.x, target.y)
	_hold(server, setup[1], target, 1.5)
	check_eq(grid.get_tile(target.x, target.y), before, "não quebra com o inventário cheio")
	check("cheio" in _events(received, Events.MESSAGE).back()["text"], "avisa que está cheio")
	setup[1].close()
	server.free()

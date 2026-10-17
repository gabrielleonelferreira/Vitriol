extends TestCase
## Onda 5B: tempestades, raio na areia, Pena de Ave-Trovão, Tempestária e vidro de tempestade.

const GameServerScript := preload("res://core/server/game_server.gd")

var _data: DataStore


func _init() -> void:
	_data = DataStore.new()
	_data.load_all()


func cleanup() -> void:
	_data.free()


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


func _events(received: Array[Dictionary], type: String) -> Array:
	return received.filter(func(event: Dictionary) -> bool: return event["type"] == type)


func test_clima_tem_tempestades_com_raios_e_uma_pena() -> void:
	var weather := Weather.new(42)
	var seen := {}
	var bolts := 0
	for i in int(3000.0 / 0.05):
		for happening in weather.step(0.05):
			seen[happening] = int(seen.get(happening, 0)) + 1
			if happening == Weather.BOLT:
				bolts += 1
	check(seen.get(Weather.START, 0) >= 2, "várias tempestades em 50 minutos")
	check_eq(seen.get(Weather.FEATHER, 0), seen.get(Weather.START, 0), "uma pena por tempestade")
	check(bolts > 20, "muitos raios (%d)" % bolts)


func test_raio_funde_areia_em_fulgurito() -> void:
	var received: Array[Dictionary] = []
	var s := _server(received)
	var server = s[0]
	var grid: WorldGrid = server.world.grid
	var x := grid.spawn_tile.x + 4
	var top := grid.surface[x]
	for y in range(top - 6, top):
		grid.set_tile(x, y, 0)
	for y in range(top, top + 4):
		grid.set_tile(x, y, grid.registry.id_of("areia"))
	server._strike(x, 0)
	check_eq(grid.tile_name(x, top), "fulgurito", "o raio virou a areia em fulgurito")
	check_eq(grid.tile_name(x, top + 2), "fulgurito", "o fulgurito desce até 3 blocos")
	check_eq(grid.tile_name(x, top + 3), "areia", "e para no terceiro")
	var bolt: Dictionary = _events(received, Events.LIGHTNING).back()
	check_eq(int(bolt["x"]), x, "clientes veem o raio")
	check(grid.registry.light_radius[grid.registry.id_of("fulgurito")] > 0.0, "fulgurito brilha")
	s[1].close()
	server.free()


func test_pena_desperta_a_tempestaria() -> void:
	var received: Array[Dictionary] = []
	var s := _server(received)
	var server = s[0]
	var player: PlayerState = s[2]
	server._drop_feather()
	var grid: WorldGrid = server.world.grid
	var feather := Vector2i(-1, -1)
	for change in _events(received, Events.TILE_CHANGED).back()["changes"]:
		if change[2] == TileRegistry.FEATHER:
			feather = Vector2i(change[0], change[1])
	check(feather.x >= 0, "a pena caiu no chão")
	check_eq(grid.tile_name(feather.x, feather.y), TileRegistry.FEATHER, "e está lá")
	player.position = Vector2((feather.x + 0.5) * 16, (feather.y + 1) * 16)
	player.mining_target = feather
	player.mining_progress = 0.99
	player.mining_active = true
	s[1].send({"type": Commands.MINE, "x": feather.x, "y": feather.y})
	for i in 4:
		server.step_once()
	check_eq(player.inventory.count("pena_ave_trovao"), 1, "pegou a pena")
	check(player.schools.has("tempestaria"), "Tempestária despertou")
	check("tempestaria" in _events(received, Events.MASTERY).back()["escolas"], "o cliente sabe")
	check(player.to_save()["escolas"].has("tempestaria"), "fica salvo")
	s[1].close()
	server.free()


func test_invocar_raio_com_espera() -> void:
	var received: Array[Dictionary] = []
	var s := _server(received)
	var server = s[0]
	var player: PlayerState = s[2]
	var grid: WorldGrid = server.world.grid
	var x := grid.spawn_tile.x + 3
	var top := grid.surface[x]
	s[1].send({"type": Commands.CAST, "magia": "raio", "x": x, "y": top})
	server.step_once()
	check(_events(received, Events.LIGHTNING).is_empty(), "sem a escola, nada")
	player.schools["tempestaria"] = true
	for y in range(top - 6, top):
		grid.set_tile(x, y, 0)
	grid.set_tile(x, top, grid.registry.id_of("areia"))
	s[1].send({"type": Commands.CAST, "magia": "raio", "x": x, "y": top})
	server.step_once()
	check_eq(grid.tile_name(x, top), "fulgurito", "raio invocado funde a areia")
	grid.set_tile(x + 1, top, grid.registry.id_of("areia"))
	s[1].send({"type": Commands.CAST, "magia": "raio", "x": x + 1, "y": top})
	server.step_once()
	check_eq(grid.tile_name(x + 1, top), "areia", "logo em seguida, ainda carregando")
	for i in int(GameServerScript.CAST_COOLDOWN * GameServerScript.TICK_RATE):
		server.step_once()
	s[1].send({"type": Commands.CAST, "magia": "raio", "x": x + 1, "y": top})
	server.step_once()
	check_eq(grid.tile_name(x + 1, top), "fulgurito", "depois da espera, funciona de novo")
	s[1].close()
	server.free()


func test_vidro_de_tempestade_pede_a_escola() -> void:
	var recipe := _data.get_recipe("refinar_vidro_de_tempestade")
	var inv := Inventory.new(_data)
	inv.add("fulgurito", 1)
	inv.add("vidro", 2)
	var stations := {"mao": true, "forno_de_vidro": true}
	var without := Crafting.status(recipe, _data, inv, {}, {}, stations, {})
	check(not without["ok"], "sem Tempestária não dá")
	check("Tempestária" in without["motivo"], "diz o porquê")
	var with_school := Crafting.status(
		recipe, _data, inv, {}, {}, stations, {"escolas": {"tempestaria": true}}
	)
	check(with_school["ok"], "com a escola, dá")


func test_salto_do_vento() -> void:
	var reg := TileRegistry.from_data(_data)
	var grid := WorldGrid.new(40, 30, reg)
	for x in 40:
		for y in range(25, 30):
			grid.set_tile(x, y, reg.id_of("calcario"))
	var heights: Array[float] = []
	for jumps in [0, 1]:
		var motor := PlayerMotor.new()
		motor.position = Vector2(10.5 * 16, 25 * 16)
		motor.air_jumps = jumps
		var highest := motor.position.y
		for i in 90:
			var press := i == 0 or i == 20
			motor.step(0.0, press, i < 40, 1.0 / 60.0, grid)
			highest = minf(highest, motor.position.y)
		heights.append(25 * 16 - highest)
	check(heights[1] > heights[0] + 20, "com salto do vento sobe bem mais (%s)" % str(heights))

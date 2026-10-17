extends TestCase
## Fabricação, estações, maestria e construção (pelo servidor).

const GameServerScript := preload("res://core/server/game_server.gd")

var _data: DataStore


func _init() -> void:
	_data = DataStore.new()
	_data.load_all()


func cleanup() -> void:
	_data.free()


func _setup(received: Array[Dictionary]) -> Array:
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


func _ticks(server: Node, seconds: float) -> void:
	for i in int(ceil(seconds * GameServerScript.TICK_RATE)) + 1:
		server.step_once()


func _place_station(server: Node, player: PlayerState, station: String, dx: int) -> void:
	var grid: WorldGrid = server.world.grid
	var spot := Vector2i(grid.spawn_tile.x + dx, grid.spawn_tile.y - 1)
	grid.set_tile(spot.x, spot.y, grid.registry.id_of(station))


func _events(received: Array[Dictionary], type: String) -> Array:
	return received.filter(func(event: Dictionary) -> bool: return event["type"] == type)


func test_receita_na_mao() -> void:
	var received: Array[Dictionary] = []
	var s := _setup(received)
	var player: PlayerState = s[2]
	player.inventory.add("madeira", 4)
	s[1].send({"type": Commands.CRAFT, "receita": "fazer_bancada", "qtd": 1})
	s[0].step_once()
	check_eq(player.inventory.count("madeira"), 0, "madeira consumida ao começar")
	check_eq(player.craft_queue.size(), 1, "trabalho na fila")
	check_eq(player.inventory.count("bancada"), 0, "ainda não ficou pronta")
	_ticks(s[0], 4.0)
	check_eq(player.inventory.count("bancada"), 1, "bancada pronta depois de 4 s")
	check(player.craft_queue.is_empty(), "fila vazia")
	check_eq(int(player.mastery.get("construcao", 0)), 1, "ganhou 1 XP de construção")
	s[1].close()
	s[0].free()


func test_precisa_da_estacao_por_perto() -> void:
	var received: Array[Dictionary] = []
	var s := _setup(received)
	var player: PlayerState = s[2]
	player.inventory.add("malaquita", 2)
	player.inventory.add("carvao_vegetal", 1)
	s[1].send({"type": Commands.CRAFT, "receita": "fundir_cobre", "qtd": 1})
	s[0].step_once()
	check(player.craft_queue.is_empty(), "sem fornalha não funde")
	check("Fornalha" in _events(received, Events.MESSAGE).back()["text"], "avisa que falta a fornalha")
	check_eq(player.inventory.count("malaquita"), 2, "não gastou nada")
	_place_station(s[0], player, "fornalha", 2)
	s[1].send({"type": Commands.CRAFT, "receita": "fundir_cobre", "qtd": 1})
	s[0].step_once()
	_ticks(s[0], 8.0)
	check_eq(player.inventory.count("lingote_cobre"), 1, "com a fornalha perto, funde cobre")
	check(player.discoveries.has("lingote_cobre"), "lingote é descoberta")
	check(int(player.mastery.get("metalurgia", 0)) >= 15, "XP de metalurgia: receita + descoberta")
	s[1].close()
	s[0].free()


func test_fila_de_varias_unidades() -> void:
	var received: Array[Dictionary] = []
	var s := _setup(received)
	var player: PlayerState = s[2]
	player.inventory.add("madeira", 5)
	s[1].send({"type": Commands.CRAFT, "receita": "fazer_tocha_galho", "qtd": 5})
	s[0].step_once()
	check_eq(player.craft_queue.size(), 2, "só cabem 2 (5 madeiras, 2 por tocha)")
	check_eq(player.inventory.count("madeira"), 1, "sobrou 1 madeira")
	_ticks(s[0], 4.0)
	check_eq(player.inventory.count("tocha"), 2, "2 tochas prontas em sequência")
	s[1].close()
	s[0].free()


func test_cancelar_devolve_materiais() -> void:
	var received: Array[Dictionary] = []
	var s := _setup(received)
	var player: PlayerState = s[2]
	player.inventory.add("madeira", 4)
	s[1].send({"type": Commands.CRAFT, "receita": "fazer_bancada", "qtd": 1})
	s[0].step_once()
	s[1].send({"type": Commands.CRAFT_CANCEL, "index": 0})
	s[0].step_once()
	check(player.craft_queue.is_empty(), "fila vazia")
	check_eq(player.inventory.count("madeira"), 4, "madeira devolvida")
	s[1].close()
	s[0].free()


func test_nivel_de_maestria_libera_receita() -> void:
	var received: Array[Dictionary] = []
	var s := _setup(received)
	var player: PlayerState = s[2]
	_place_station(s[0], player, "fornalha", 2)
	player.inventory.add("cassiterita", 2)
	player.inventory.add("carvao_vegetal", 1)
	s[1].send({"type": Commands.CRAFT, "receita": "reduzir_estanho", "qtd": 1})
	s[0].step_once()
	check(player.craft_queue.is_empty(), "estanho bloqueado no nível 1")
	check("nível 2" in _events(received, Events.MESSAGE).back()["text"], "avisa o nível necessário")
	player.mastery["metalurgia"] = Mastery.LEVEL_XP[1]
	s[1].send({"type": Commands.CRAFT, "receita": "reduzir_estanho", "qtd": 1})
	s[0].step_once()
	check_eq(player.craft_queue.size(), 1, "no nível 2 libera")
	s[1].close()
	s[0].free()


func test_receita_secreta_fica_oculta() -> void:
	var stations := {"mao": true, "fornalha": true}
	var inv := Inventory.new(_data)
	inv.add("lingote_cobre", 3)
	inv.add("lingote_estanho", 1)
	var check_result := Crafting.status(
		_data.get_recipe("ligar_bronze"), _data, inv, {"metalurgia": 999}, {}, stations
	)
	check(not check_result["ok"], "bronze é secreto mesmo com XP alto")
	check("secreta" in check_result["motivo"], "motivo: receita secreta")
	var known := Crafting.status(
		_data.get_recipe("ligar_bronze"), _data, inv, {}, {"ligar_bronze": true}, stations
	)
	check(known["ok"], "depois de descoberto, pode fazer")


func test_subir_de_nivel_avisa() -> void:
	var received: Array[Dictionary] = []
	var s := _setup(received)
	var player: PlayerState = s[2]
	player.mastery["construcao"] = 19
	player.inventory.add("madeira", 3)
	s[1].send({"type": Commands.CRAFT, "receita": "fazer_fogueira", "qtd": 1})
	s[0].step_once()
	_ticks(s[0], 3.0)
	var texts := _events(received, Events.MESSAGE).map(func(e: Dictionary) -> String: return e["text"])
	check(texts.any(func(t: String) -> bool: return "nível 2" in t), "avisa que subiu de nível")
	s[1].close()
	s[0].free()


func test_colocar_bloco_e_estacao() -> void:
	var received: Array[Dictionary] = []
	var s := _setup(received)
	var server = s[0]
	var player: PlayerState = s[2]
	var grid: WorldGrid = server.world.grid
	player.inventory.add("tijolo", 3)
	player.selected = 0
	var spawn := grid.spawn_tile
	var on_ground := Vector2i(spawn.x + 2, spawn.y - 1)
	grid.set_tile(on_ground.x, on_ground.y, 0)
	s[1].send({"type": Commands.PLACE, "x": on_ground.x, "y": on_ground.y})
	server.step_once()
	check_eq(grid.tile_name(on_ground.x, on_ground.y), "tijolo", "tijolo colocado no chão")
	check(grid.is_solid(on_ground.x, on_ground.y), "bloco colocado é sólido")
	var floating := Vector2i(spawn.x - 3, spawn.y - 4)
	s[1].send({"type": Commands.PLACE, "x": floating.x, "y": floating.y})
	server.step_once()
	check_eq(grid.tile_name(floating.x, floating.y), "ar", "não flutua no ar")
	var on_player := Vector2i(spawn.x, spawn.y - 1)
	s[1].send({"type": Commands.PLACE, "x": on_player.x, "y": on_player.y})
	server.step_once()
	check_eq(grid.tile_name(on_player.x, on_player.y), "ar", "não prende o jogador")
	check_eq(player.inventory.count("tijolo"), 2, "gastou só 1 tijolo")
	player.inventory.slots[0] = {"id": "fornalha", "qtd": 1}
	var spot := Vector2i(spawn.x - 2, spawn.y - 1)
	grid.set_tile(spot.x, spot.y, 0)
	s[1].send({"type": Commands.PLACE, "x": spot.x, "y": spot.y})
	server.step_once()
	check_eq(grid.tile_name(spot.x, spot.y), "fornalha", "fornalha colocada")
	check(not grid.is_solid(spot.x, spot.y), "estação não bloqueia a passagem")
	check(Crafting.stations_near(grid, _data, player.position).has("fornalha"), "conta como estação por perto")
	s[1].close()
	server.free()


func test_vidro_e_transparente() -> void:
	var reg := TileRegistry.from_data(_data)
	var glass := reg.id_of("vidro")
	check(reg.is_solid(glass), "vidro é sólido")
	check(not reg.is_opaque(glass), "mas não é opaco")
	check(reg.is_opaque(reg.id_of("tijolo")), "tijolo é opaco")

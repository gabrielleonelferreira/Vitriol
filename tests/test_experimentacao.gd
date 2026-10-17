extends TestCase
## Onda 5A: experimentação, pistas, cascata de descobertas e bônus de maestria.

const GameServerScript := preload("res://core/server/game_server.gd")

var _data: DataStore


func _init() -> void:
	_data = DataStore.new()
	_data.load_all()


func cleanup() -> void:
	_data.free()


func test_acertar_a_mistura_revela_o_bronze() -> void:
	var result := Experiment.evaluate(
		_data, {"lingote_cobre": 3, "lingote_estanho": 1}, "fornalha", {}, {}
	)
	check_eq(result["tipo"], "receita", "cobre + estanho na fornalha acerta")
	check_eq(result["receita"], "ligar_bronze", "é o bronze")
	check(result["nova"], "era secreta")
	var again := Experiment.evaluate(
		_data, {"lingote_cobre": 3, "lingote_estanho": 1}, "fornalha", {}, {"ligar_bronze": true}
	)
	check(not again["nova"], "segunda vez já não é descoberta")


func test_pistas() -> void:
	var cases := [
		[{"lingote_cobre": 1, "lingote_estanho": 1}, "fornalha", "proporcao"],
		[{"lingote_cobre": 3, "lingote_estanho": 1}, "bancada", "estacao"],
		[{"lingote_cobre": 3}, "fornalha", "falta"],
		[{"lingote_cobre": 3, "lingote_estanho": 1, "areia": 1}, "fornalha", "demais"],
		[{"argila": 1, "madeira": 1}, "bancada", "nada"],
	]
	for case in cases:
		var result := Experiment.evaluate(_data, case[0], case[1], {}, {})
		check_eq(result["tipo"], "falhou", "%s em %s falha" % [str(case[0].keys()), case[1]])
		check_eq(result.get("pista"), case[2], "pista '%s'" % case[2])


func test_mistura_de_receita_comum_e_de_nivel() -> void:
	var common := Experiment.evaluate(_data, {"argila": 2}, "fornalha", {}, {})
	check_eq(common["receita"], "cozer_tijolo", "acertar uma receita comum também faz")
	var locked := Experiment.evaluate(
		_data, {"cassiterita": 2, "carvao_vegetal": 1}, "fornalha", {}, {}
	)
	check_eq(locked["tipo"], "bloqueada", "estanho no nível 1 é bloqueado")
	check("nível 2" in locked["motivo"], "diz o nível")
	var bad := Experiment.evaluate(_data, {"picareta_cobre": 1}, "bancada", {}, {})
	check_eq(bad["tipo"], "invalida", "ferramenta não entra na mistura")


func test_cascata_espera_os_dois_raros() -> void:
	var found := {"lingote_prata": true}
	var first := Experiment.cascade(_data, "lingote_prata", found, {})
	check(not "ligar_electro" in first, "só a prata não revela o electro (falta o ouro, raro)")
	found["lingote_ouro"] = true
	var second := Experiment.cascade(_data, "lingote_ouro", found, {})
	check("ligar_electro" in second, "com ouro e prata descobertos, o electro aparece")
	check(
		Experiment.cascade(_data, "lingote_cobre", {}, {}).is_empty(),
		"material comum não cascateia"
	)


func test_maestria_acelera_e_reforca() -> void:
	check_eq(Mastery.craft_seconds(10.0, 0), 10.0, "nível 1: tempo base")
	var level5 := Mastery.LEVEL_XP[4]
	check(
		absf(Mastery.craft_seconds(10.0, level5) - 10.0 / 1.24) < 0.001, "nível 5: 24% mais rápido"
	)
	check_eq(Mastery.durability_for(300, level5), 360, "nível 5: picareta 20% mais durável")


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
	var grid: WorldGrid = server.world.grid
	var spot := Vector2i(grid.spawn_tile.x + 2, grid.spawn_tile.y - 1)
	grid.set_tile(spot.x, spot.y, grid.registry.id_of("fornalha"))
	return [server, transport, player]


func _events(received: Array[Dictionary], type: String) -> Array:
	return received.filter(func(event: Dictionary) -> bool: return event["type"] == type)


func test_experimento_no_servidor() -> void:
	var received: Array[Dictionary] = []
	var s := _server(received)
	var server = s[0]
	var player: PlayerState = s[2]
	player.inventory.add("lingote_cobre", 5)
	player.inventory.add("lingote_estanho", 2)
	s[1].send({"type": Commands.EXPERIMENT, "estacao": "fornalha", "itens": {"lingote_cobre": 3}})
	server.step_once()
	var last: Dictionary = _events(received, Events.EXPERIMENT_RESULT).back()
	check(not last["ok"], "só cobre falha")
	check("falta" in last["texto"], "pista de que falta algo")
	check_eq(player.inventory.count("lingote_cobre"), 4, "gastou 1 cobre na tentativa")
	(
		s[1]
		. send(
			{
				"type": Commands.EXPERIMENT,
				"estacao": "fornalha",
				"itens": {"lingote_cobre": 3, "lingote_estanho": 1},
			}
		)
	)
	server.step_once()
	check(player.known_recipes.has("ligar_bronze"), "bronze descoberto")
	check_eq(player.craft_queue.size(), 1, "e já está fundindo")
	var mastery: Dictionary = _events(received, Events.MASTERY).back()
	check("ligar_bronze" in mastery["receitas"], "o cliente fica sabendo da receita")
	for i in 260:
		server.step_once()
	check_eq(player.inventory.count("bronze"), 4, "4 bronzes prontos")
	s[1].close()
	server.free()


func test_cascata_no_servidor_e_picareta_reforcada() -> void:
	var received: Array[Dictionary] = []
	var s := _server(received)
	var server = s[0]
	var player: PlayerState = s[2]
	server._give(player, "lingote_prata", 1)
	check(not player.known_recipes.has("ligar_electro"), "ainda não")
	server._give(player, "lingote_ouro", 1)
	check(player.known_recipes.has("ligar_electro"), "cascata revelou o electro")
	var texts := _events(received, Events.MESSAGE).map(
		func(e: Dictionary) -> String: return e["text"]
	)
	check(texts.any(func(t: String) -> bool: return "Cascata" in t), "avisou a cascata")
	player.mastery["metalurgia"] = Mastery.LEVEL_XP[4]
	var bench := Vector2i(server.world.grid.spawn_tile.x - 2, server.world.grid.spawn_tile.y - 1)
	server.world.grid.set_tile(bench.x, bench.y, server.world.grid.registry.id_of("bancada"))
	player.inventory.add("lingote_cobre", 3)
	player.inventory.add("madeira", 2)
	s[1].send({"type": Commands.CRAFT, "receita": "fazer_picareta_cobre", "qtd": 1})
	server.step_once()
	check(player.craft_queue[0]["total"] < 5.0, "nível 5 de metalurgia: mais rápido que 5 s")
	for i in 120:
		server.step_once()
	var slot := {}
	for candidate in player.inventory.slots:
		if candidate.get("id") == "picareta_cobre":
			slot = candidate
	check_eq(int(slot.get("durabilidade", 0)), 180, "picareta de cobre com 20% a mais (150 → 180)")
	check_eq(int(slot.get("durabilidade_max", 0)), 180, "o máximo também sobe")
	s[1].close()
	server.free()

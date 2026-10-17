extends TestCase
## Arquitetura cliente/servidor: conexão, comandos e eventos.

const GameServerScript := preload("res://core/server/game_server.gd")

var _data: DataStore


func _init() -> void:
	_data = DataStore.new()
	_data.load_all()


func cleanup() -> void:
	_data.free()


func _server() -> Node:
	var server = GameServerScript.new()
	server.start(7, _data, 200, WorldGenerator.DEFAULT_HEIGHT)
	return server


func test_join_e_ping() -> void:
	var server := _server()
	var transport := LocalTransport.new(server)
	var received: Array[Dictionary] = []
	transport.event_received.connect(func(event: Dictionary) -> void: received.append(event))
	transport.open()

	transport.send({"type": Commands.JOIN, "name": "Teste"})
	server.step_once()
	check(received.size() >= 2, "join devolve eventos")
	check_eq(received[0].get("type"), Events.WORLD_SNAPSHOT, "primeiro vem o mundo")
	check_eq(received[1].get("type"), Events.JOINED, "depois o joined")
	check(server.players.has(transport.peer_id), "servidor registra o jogador")
	var grid := WorldGrid.from_snapshot(received[0]["grid"], _data)
	var pos: Array = received[1]["player"]["position"]
	check_eq(Vector2(pos[0], pos[1]), grid.spawn_position(), "jogador nasce no ponto de nascimento")

	transport.send({"type": Commands.PING})
	server.step_once()
	check_eq(received.back().get("type"), Events.PONG, "ping devolve pong")

	transport.close()
	server.free()


func test_sair_remove_jogador() -> void:
	var server := _server()
	var transport := LocalTransport.new(server)
	transport.open()
	transport.send({"type": Commands.JOIN, "name": "Teste"})
	server.step_once()
	transport.close()
	check(server.players.is_empty(), "fechar a conexão remove o jogador")
	server.free()


func test_comando_desconhecido() -> void:
	var server := _server()
	var transport := LocalTransport.new(server)
	var received: Array[Dictionary] = []
	transport.event_received.connect(func(event: Dictionary) -> void: received.append(event))
	transport.open()
	transport.send({"type": "voar_sem_magia"})
	server.step_once()
	check_eq(received.back().get("type"), Events.ERROR, "comando desconhecido devolve erro")
	transport.close()
	server.free()


func _joined(server: Node, received: Array[Dictionary]) -> LocalTransport:
	var transport := LocalTransport.new(server)
	transport.event_received.connect(func(event: Dictionary) -> void: received.append(event))
	transport.open()
	transport.send({"type": Commands.JOIN, "name": "Teste"})
	server.step_once()
	return transport


func test_movimento_valido_e_aceito() -> void:
	var server := _server()
	var received: Array[Dictionary] = []
	var transport := _joined(server, received)
	var spawn: Vector2 = server.world.grid.spawn_position()
	var target := spawn + Vector2(12, 0)
	transport.send({"type": Commands.MOVE, "position": [target.x, target.y], "facing": 1})
	server.step_once()
	check_eq(server.players[transport.peer_id].position, target, "servidor aceita passo curto")
	check_eq(received.back().get("type"), Events.PLAYER_MOVED, "avisa os outros do movimento")
	transport.close()
	server.free()


func test_teleporte_e_corrigido() -> void:
	var server := _server()
	var received: Array[Dictionary] = []
	var transport := _joined(server, received)
	var spawn: Vector2 = server.world.grid.spawn_position()
	var far := spawn + Vector2(900, -200)
	transport.send({"type": Commands.MOVE, "position": [far.x, far.y]})
	server.step_once()
	check_eq(server.players[transport.peer_id].position, spawn, "posição continua a anterior")
	check_eq(received.back().get("type"), Events.CORRECTION, "manda correção")
	transport.close()
	server.free()


func test_dentro_da_rocha_e_corrigido() -> void:
	var server := _server()
	var received: Array[Dictionary] = []
	var transport := _joined(server, received)
	var spawn: Vector2 = server.world.grid.spawn_position()
	var inside := spawn + Vector2(0, 20)
	transport.send({"type": Commands.MOVE, "position": [inside.x, inside.y]})
	server.step_once()
	check_eq(received.back().get("type"), Events.CORRECTION, "não aceita o corpo dentro do chão")
	transport.close()
	server.free()

extends TestCase
## Arquitetura cliente/servidor: conexão, comandos e eventos.

const GameServerScript := preload("res://core/server/game_server.gd")


func test_join_e_ping() -> void:
	var server = GameServerScript.new()
	var transport := LocalTransport.new(server)
	var received: Array[Dictionary] = []
	transport.event_received.connect(func(event: Dictionary) -> void: received.append(event))
	transport.open()

	transport.send({"type": Commands.JOIN, "name": "Teste"})
	server.step_once()
	check(received.size() >= 1, "join devolve evento")
	check_eq(received[0].get("type"), Events.JOINED, "primeiro evento é joined")
	check(server.players.has(transport.peer_id), "servidor registra o jogador")

	transport.send({"type": Commands.PING})
	server.step_once()
	check_eq(received.back().get("type"), Events.PONG, "ping devolve pong")

	transport.close()
	server.free()


func test_sair_remove_jogador() -> void:
	var server = GameServerScript.new()
	var transport := LocalTransport.new(server)
	transport.open()
	transport.send({"type": Commands.JOIN, "name": "Teste"})
	server.step_once()
	transport.close()
	check(server.players.is_empty(), "fechar a conexão remove o jogador")
	server.free()


func test_comando_desconhecido() -> void:
	var server = GameServerScript.new()
	var transport := LocalTransport.new(server)
	var received: Array[Dictionary] = []
	transport.event_received.connect(func(event: Dictionary) -> void: received.append(event))
	transport.open()
	transport.send({"type": "voar_sem_magia"})
	server.step_once()
	check_eq(received.back().get("type"), Events.ERROR, "comando desconhecido devolve erro")
	transport.close()
	server.free()

extends SceneTree
## Testes de fumaça da arquitetura base.
## Rodar no terminal: godot --headless --path . -s res://tests/run_tests.gd

const GameServerScript := preload("res://core/server/game_server.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_join_and_ping()
	_test_leave()
	if _failures == 0:
		print("OK: todos os testes passaram")
	quit(1 if _failures > 0 else 0)


func _test_join_and_ping() -> void:
	var server = GameServerScript.new()
	var transport := LocalTransport.new(server)
	var received: Array[Dictionary] = []
	transport.event_received.connect(func(event: Dictionary) -> void: received.append(event))
	transport.open()

	transport.send({"type": Commands.JOIN, "name": "Teste"})
	server.step_once()
	_check(received.size() == 1, "join devolve um evento")
	_check(received[0].get("type") == Events.JOINED, "evento é joined")
	_check(server.players.has(transport.peer_id), "servidor registra o jogador")

	transport.send({"type": Commands.PING})
	server.step_once()
	_check(received.back().get("type") == Events.PONG, "ping devolve pong")

	transport.close()
	server.free()


func _test_leave() -> void:
	var server = GameServerScript.new()
	var transport := LocalTransport.new(server)
	transport.open()
	transport.send({"type": Commands.JOIN, "name": "Teste"})
	server.step_once()
	transport.close()
	_check(server.players.is_empty(), "fechar a conexão remove o jogador")
	server.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FALHA ", label)

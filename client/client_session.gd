class_name ClientSession
extends Node
## Sessão do cliente: envia comandos pelo Transport e repassa os eventos à interface.

signal event_received(event: Dictionary)

var transport: Transport
var player_id: int = 0


func connect_to(new_transport: Transport) -> void:
	transport = new_transport
	transport.event_received.connect(_on_event)
	transport.open()


func join(display_name: String) -> void:
	transport.send({"type": Commands.JOIN, "name": display_name})


func ping() -> void:
	transport.send({"type": Commands.PING})


func _on_event(event: Dictionary) -> void:
	if event.get("type", "") == Events.JOINED:
		player_id = int(event["player_id"])
	event_received.emit(event)


func _exit_tree() -> void:
	if transport:
		transport.close()
		transport = null

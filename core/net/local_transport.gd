class_name LocalTransport
extends Transport
## Transporte do modo solo: fala com o GameServer no mesmo processo, sem rede.
## Um transporte de rede (ENet) entra na Onda 10, com a mesma interface.

var peer_id: int = 0

## Instância do GameServer. Sem tipo estático porque o servidor é um autoload.
var _server


func _init(server) -> void:
	_server = server


func open() -> void:
	peer_id = _server.connect_peer()
	_server.event_emitted.connect(_on_server_event)


func send(command: Dictionary) -> void:
	_server.submit(peer_id, command)


func close() -> void:
	if _server.event_emitted.is_connected(_on_server_event):
		_server.event_emitted.disconnect(_on_server_event)
	_server.disconnect_peer(peer_id)


func _on_server_event(target_peer: int, event: Dictionary) -> void:
	if target_peer == peer_id or target_peer == Events.BROADCAST:
		event_received.emit(event)

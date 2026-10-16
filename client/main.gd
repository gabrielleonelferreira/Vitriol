extends Node2D
## Ponto de entrada do cliente.
## Abre uma sessão com o servidor local e mostra o estado da conexão.
## O mundo (2A) e o personagem (2B) entram aqui na Onda 2.

var _session: ClientSession

@onready var _status: Label = $Status


func _ready() -> void:
	_session = ClientSession.new()
	_session.name = "ClientSession"
	add_child(_session)
	_session.event_received.connect(_on_event)
	_session.connect_to(LocalTransport.new(GameServer))
	_session.join("Alquimista")


func _on_event(event: Dictionary) -> void:
	match event.get("type", ""):
		Events.JOINED:
			_status.text = "Vitriol — servidor local conectado (jogador %d)" % event["player_id"]
		Events.ERROR:
			_status.text = "Erro: %s" % event.get("reason", "?")

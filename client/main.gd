extends Node2D
## Ponto de entrada do cliente.
## Abre uma sessão com o servidor local, desenha o mundo recebido e coloca o personagem.

var _session: ClientSession
var _grid: WorldGrid
var _world_view: WorldView
var _local: Player
var _remotes: Dictionary = {}

@onready var _hud: Label = $HUD/Info


func _ready() -> void:
	_session = ClientSession.new()
	_session.name = "ClientSession"
	add_child(_session)
	_session.event_received.connect(_on_event)
	_session.connect_to(LocalTransport.new(GameServer))
	_session.join("Alquimista")


func _on_event(event: Dictionary) -> void:
	match event.get("type", ""):
		Events.WORLD_SNAPSHOT:
			_build_world(event["grid"])
		Events.JOINED:
			_spawn_local(event["player"])
		Events.PLAYER_MOVED:
			_on_player_moved(event)
		Events.PLAYER_LEFT:
			_remove_remote(int(event["player_id"]))
		Events.CORRECTION:
			if _local:
				_local.apply_correction(_vec(event["position"]))
		Events.ERROR:
			_hud.text = "Erro do servidor: %s" % event.get("reason", "?")


func _build_world(snapshot: Dictionary) -> void:
	_grid = WorldGrid.from_snapshot(snapshot, GameData)
	_world_view = WorldView.new()
	_world_view.name = "Mundo"
	add_child(_world_view)
	move_child(_world_view, 0)
	_world_view.build(_grid, GameData)


func _spawn_local(info: Dictionary) -> void:
	_local = Player.new()
	_local.name = "Jogador"
	add_child(_local)
	_local.setup(_grid, _vec(info["position"]), true)
	_local.moved.connect(_on_local_moved)


func _on_local_moved(position: Vector2, velocity: Vector2, facing: int) -> void:
	_session.move(position, velocity, facing)


func _on_player_moved(event: Dictionary) -> void:
	var id := int(event["player_id"])
	if id == _session.player_id:
		return
	if not _remotes.has(id):
		var remote := Player.new()
		remote.name = "Jogador_%d" % id
		add_child(remote)
		remote.setup(_grid, _vec(event["position"]), false)
		_remotes[id] = remote
	_remotes[id].apply_remote(
		_vec(event["position"]), _vec(event["velocity"]), int(event["facing"])
	)


func _remove_remote(id: int) -> void:
	if _remotes.has(id):
		_remotes[id].queue_free()
		_remotes.erase(id)


func _process(_delta: float) -> void:
	if _local == null or _grid == null:
		return
	var tile := WorldGrid.to_tile(_local.position)
	var layer_names := ["Planícies", "Solo", "Rocha Sedimentar", "Rocha Metamórfica"]
	var layer := clampi(_grid.layer_at(tile.x, tile.y - 1), 0, layer_names.size() - 1)
	_hud.text = (
		"Vitriol — %s   ·   tile %d, %d   ·   %d FPS   ·   A/D anda, Espaço pula"
		% [layer_names[layer], tile.x, tile.y, Engine.get_frames_per_second()]
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("depurar"):
		_hud.visible = not _hud.visible


static func _vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

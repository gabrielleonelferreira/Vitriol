extends Node2D
## Ponto de entrada do cliente.
## Abre uma sessão com o servidor local, desenha o mundo recebido, coloca o personagem e
## traduz mouse e teclado em comandos (minerar, colocar, escolher item).

## Envios de "continuar minerando" por segundo enquanto o botão está apertado.
const MINE_RATE := 20.0
const LAYER_NAMES := ["Planícies", "Solo", "Rocha Sedimentar", "Rocha Metamórfica"]

var _session: ClientSession
var _grid: WorldGrid
var _background: Background
var _world_view: WorldView
var _lighting: Lighting
var _mining_view: MiningView
var _hud: Hud
var _local: Player
var _remotes: Dictionary = {}
var _mining_tile := Vector2i(-1, -1)
var _mine_timer: float = 0.0
var _time_of_day: float = WorldState.START_TIME
var _station_timer: float = 0.0
var _ladder_timer: float = 0.0

@onready var _info: Label = $HUD/Info


func _ready() -> void:
	_hud = Hud.new()
	_hud.name = "Interface"
	add_child(_hud)
	_hud.setup(GameData)
	_hud.slot_selected.connect(func(index: int) -> void: _session.select_slot(index))
	_hud.slots_swapped.connect(func(a: int, b: int) -> void: _session.swap_slots(a, b))
	_hud.craft_requested.connect(func(id: String, qtd: int) -> void: _session.craft(id, qtd))
	_hud.craft_cancel_requested.connect(func(i: int) -> void: _session.craft_cancel(i))
	_hud.experiment_requested.connect(
		func(station: String, mix: Dictionary) -> void: _session.experiment(station, mix)
	)
	_session = ClientSession.new()
	_session.name = "ClientSession"
	add_child(_session)
	_session.event_received.connect(_on_event)
	_session.connect_to(LocalTransport.new(GameServer))
	_session.join("Alquimista")


func _on_event(event: Dictionary) -> void:
	match event.get("type", ""):
		Events.WORLD_SNAPSHOT:
			_time_of_day = float(event.get("time", _time_of_day))
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
		Events.TILE_CHANGED:
			_apply_changes(event["changes"])
		Events.INVENTORY:
			_hud.set_inventory(event["slots"], int(event["selected"]))
		Events.MINE_PROGRESS:
			_mining_view.show_progress(
				Vector2i(int(event["x"]), int(event["y"])), float(event["progress"])
			)
		Events.MESSAGE:
			_hud.toast(event["text"], event.get("kind", "info"))
		Events.DISCOVERED:
			var xp := int(event.get("xp", 0))
			var suffix := "  +%d XP" % xp if xp > 0 else ""
			_hud.toast("Descoberta: %s%s" % [event["nome"], suffix], "descoberta")
		Events.MASTERY:
			_hud.set_mastery(event["xp"], event.get("receitas", []))
		Events.EXPERIMENT_RESULT:
			_hud.crafting.show_result(bool(event["ok"]), str(event["texto"]))
			if not _hud.crafting_open():
				_hud.toast(str(event["texto"]), "descoberta" if event["ok"] else "aviso")
		Events.CRAFT_QUEUE:
			_hud.set_queue(event["jobs"])
		Events.TIME:
			_time_of_day = float(event["time"])
		Events.ERROR:
			_info.text = "Erro do servidor: %s" % event.get("reason", "?")


func _build_world(snapshot: Dictionary) -> void:
	_grid = WorldGrid.from_snapshot(snapshot, GameData)
	_background = Background.new()
	_background.name = "Fundo"
	add_child(_background)
	move_child(_background, 0)
	_background.build(_grid)
	_world_view = WorldView.new()
	_world_view.name = "Mundo"
	add_child(_world_view)
	move_child(_world_view, 1)
	_world_view.build(_grid, GameData)
	_mining_view = MiningView.new()
	_mining_view.name = "Mineracao"
	add_child(_mining_view)
	_lighting = Lighting.new()
	_lighting.name = "Luz"
	add_child(_lighting)
	_lighting.setup(_grid)


func _apply_changes(changes: Array) -> void:
	for change in changes:
		var x := int(change[0])
		var y := int(change[1])
		_grid.set_tile(x, y, maxi(_grid.registry.id_of(str(change[2])), 0))
		_world_view.refresh(x, y)
		_lighting.tile_changed(x, y)


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


func _process(delta: float) -> void:
	if _local == null or _grid == null:
		return
	_update_pointer(delta)
	_update_light()
	_auto_ladder(delta)
	var feet: Array[Vector2] = [_local.position]
	for remote in _remotes.values():
		feet.append(remote.position)
	_world_view.update_doors(feet)
	_station_timer -= delta
	if _station_timer <= 0.0:
		_station_timer = 0.25
		_hud.set_stations(Crafting.stations_near(_grid, GameData, _local.position))
	var tile := WorldGrid.to_tile(_local.position)
	var layer := clampi(_grid.layer_at(tile.x, tile.y - 1), 0, LAYER_NAMES.size() - 1)
	var hour := int(_time_of_day * 24.0)
	var minute := int(fposmod(_time_of_day * 24.0 * 60.0, 60.0))
	_info.text = (
		"%s   ·   %02d:%02d   ·   tile %d, %d   ·   %d FPS"
		% [LAYER_NAMES[layer], hour, minute, tile.x, tile.y, Engine.get_frames_per_second()]
	)


func _update_light() -> void:
	var daylight := WorldState.daylight(_time_of_day)
	_lighting.set_daylight(daylight)
	_background.set_daylight(daylight)
	var held: Dictionary = GameData.get_item(_hud.selected_item().get("id", ""))
	var body := WorldGrid.to_tile(MiningRules.body_center(_local.position))
	if held.get("luz_raio") != null:
		_lighting.set_held_light(body, float(held["luz_raio"]) * 0.8, Color(str(held["luz_cor"])))
	else:
		_lighting.set_held_light(body, 0.0, Color.WHITE)
	var view := Vector2i(ceili(640.0 / WorldGrid.TILE_SIZE), ceili(360.0 / WorldGrid.TILE_SIZE))
	_lighting.update_view(
		WorldGrid.to_tile(get_viewport().get_camera_2d().get_screen_center_position()), view
	)


## Moldura sob o mouse, minerar segurando o botão esquerdo, colocar com o direito.
func _update_pointer(delta: float) -> void:
	if _hud.inventory_open() or _over_crafting():
		_mining_view.hide_cursor()
		_stop_mining()
		return
	var tile := WorldGrid.to_tile(get_global_mouse_position())
	var in_reach := MiningRules.in_reach(_local.position, tile) and _grid.in_bounds(tile.x, tile.y)
	var id := _grid.get_tile(tile.x, tile.y)
	var held_id: String = _hud.selected_item().get("id", "")
	var kind := Building.kind_for(GameData, held_id)
	var can_mine: bool = id > 0 and not _grid.registry.is_liquid(id) and _breakable(id, held_id)
	var can_place := false
	if not kind.is_empty() and (id == 0 or _grid.registry.is_liquid(id)):
		var feet: Array[Vector2] = [_local.position]
		for remote in _remotes.values():
			feet.append(remote.position)
		can_place = Building.placement_problem(_grid, tile, kind, feet).is_empty()
	_mining_view.show_cursor(tile, in_reach and (can_mine or can_place))

	if Input.is_action_pressed("minerar") and in_reach and id > 0:
		if tile != _mining_tile:
			_mining_tile = tile
			_mine_timer = 0.0
		_mine_timer -= delta
		if _mine_timer <= 0.0:
			_mine_timer = 1.0 / MINE_RATE
			_session.mine(tile)
	elif _mining_tile.x >= 0:
		_stop_mining()


## Com a escada na mão e o botão de subir apertado, coloca o próximo degrau acima do corpo.
func _auto_ladder(delta: float) -> void:
	_ladder_timer -= delta
	if _ladder_timer > 0.0 or _hud.inventory_open():
		return
	if _hud.selected_item().get("id", "") != "escada" or not Input.is_action_pressed("pular"):
		return
	var feet := _local.position
	var column := floori(feet.x / WorldGrid.TILE_SIZE)
	var bottom := floori((feet.y - 0.001) / WorldGrid.TILE_SIZE)
	var top := floori((feet.y - PlayerMotor.HITBOX.y) / WorldGrid.TILE_SIZE) - 1
	for row in range(bottom, top - 1, -1):
		var id := _grid.get_tile(column, row)
		if _grid.registry.is_climbable(id):
			continue
		if id != 0 and not _grid.registry.is_liquid(id):
			return
		_session.place(Vector2i(column, row), true)
		_ladder_timer = 0.12
		return


func _breakable(id: int, held_id: String) -> bool:
	var power: Variant = GameData.get_item(held_id).get("poder_mineracao")
	var tool_power := float(power) if power != null else MiningRules.HAND_POWER
	return _grid.registry.hardness[id] <= tool_power


func _stop_mining() -> void:
	if _mining_tile.x >= 0:
		_mining_tile = Vector2i(-1, -1)
		_session.mine_stop()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("depurar"):
		_info.visible = not _info.visible
	elif event.is_action_pressed("inventario"):
		_hud.toggle_inventory()
	elif event.is_action_pressed("fabricar"):
		_hud.toggle_crafting()
	elif event.is_action_pressed("kit_teste"):
		_session.debug_kit()
	elif (
		event.is_action_pressed("colocar")
		and _local
		and not _hud.inventory_open()
		and not _over_crafting()
	):
		_session.place(WorldGrid.to_tile(get_global_mouse_position()))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_session.select_slot((_hud.selected + 1) % Inventory.HOTBAR)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_session.select_slot((_hud.selected + Inventory.HOTBAR - 1) % Inventory.HOTBAR)
	else:
		for i in Inventory.HOTBAR:
			if event.is_action_pressed("slot_%d" % (i + 1)):
				_session.select_slot(i)


func _over_crafting() -> bool:
	var panel := _hud.crafting
	return (
		panel.visible
		and Rect2(panel.global_position, panel.size).has_point(
			_hud.get_viewport().get_mouse_position()
		)
	)


static func _vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

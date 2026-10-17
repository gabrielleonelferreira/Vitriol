extends SceneTree
## Roda o jogo, simula mouse e teclado e salva prints. Precisa de tela (não use --headless).
## Uso: godot --path . -s res://tests/captura.gd -- <pasta_saida> --novo
##
## Roteiro: dia na superfície → minera a grama ao lado → cava um buraco → caverna escura →
## coloca tochas → noite na superfície com tocha na mão → inventário aberto → confere o save.

var _out := "user://capturas"
var _frame := 0
var _main: Node
var _server: Node
var _steps: Array[Dictionary] = []
var _wait := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			_out = arg
	DirAccess.make_dir_recursive_absolute(_out)
	_main = load("res://client/main.tscn").instantiate()
	root.add_child(_main)
	_server = root.get_node("GameServer")
	_steps = [
		{"wait": 90, "do": _shot.bind("1_dia_superficie")},
		{"wait": 1, "do": _press_on_tile.bind(Vector2i(2, 0))},
		{"wait": 12, "do": _shot.bind("2_minerando")},
		{"wait": 30, "do": _release},
		{"wait": 2, "do": _debug_kit},
		{"wait": 10, "do": _select.bind(1)},
		{"wait": 2, "do": _dig_down.bind(6)},
		{"wait": 2, "do": _shot.bind("3_buraco")},
		{"wait": 2, "do": _go_to_cave.bind(2)},
		{"wait": 30, "do": _shot.bind("4_caverna_escura")},
		{"wait": 2, "do": _select.bind(0)},
		{"wait": 4, "do": _place_torches},
		{"wait": 20, "do": _shot.bind("5_caverna_com_tochas")},
		{"wait": 2, "do": _night_on_surface},
		{"wait": 40, "do": _shot.bind("6_noite_tocha_na_mao")},
		{"wait": 2, "do": _toggle_inventory},
		{"wait": 6, "do": _shot.bind("7_inventario")},
		{"wait": 2, "do": _check_save},
		{"wait": 2, "do": quit},
	]


func _process(_delta: float) -> bool:
	_frame += 1
	if _steps.is_empty():
		return false
	_wait += 1
	if _wait >= _steps[0]["wait"]:
		_wait = 0
		var step: Dictionary = _steps.pop_front()
		step["do"].call()
	return false


func _player() -> Node2D:
	return _main.get_node("Jogador")


func _player_tile() -> Vector2i:
	return WorldGrid.to_tile(_player().position)


func _screen_of_tile(tile: Vector2i) -> Vector2:
	var world := (Vector2(tile) + Vector2(0.5, 0.5)) * WorldGrid.TILE_SIZE
	return _main.get_viewport().get_canvas_transform() * world


## Aponta o mouse para um tile relativo aos pés do jogador e aperta o botão de minerar.
func _press_on_tile(offset: Vector2i) -> void:
	_main.get_viewport().warp_mouse(_screen_of_tile(_player_tile() + offset))
	Input.action_press("minerar")


func _release() -> void:
	Input.action_release("minerar")


func _debug_kit() -> void:
	_main._session.debug_kit()


func _select(index: int) -> void:
	_main._session.select_slot(index)


## Cava direto para baixo usando o servidor (rápido, para montar a cena).
func _dig_down(depth: int) -> void:
	var tile := _player_tile()
	var player: PlayerState = _server.players.values()[0]
	for d in depth:
		for dx in [0, 1]:
			var target := Vector2i(tile.x + dx, tile.y + d)
			player.position = Vector2((tile.x + 0.5) * 16, (tile.y + d) * 16)
			player.mining_target = target
			player.mining_progress = 0.99
			player.mining_active = true
			_server.step_once()
	player.mining_active = false
	_main.get_node("Jogador").apply_correction(Vector2((tile.x + 0.5) * 16, tile.y * 16))


func _go_to_cave(layer: int) -> void:
	var grid: WorldGrid = _server.world.grid
	for x in range(grid.width / 2 + 40, grid.width - 20):
		for y in range(grid.height - 10, grid.surface[x], -1):
			if grid.layer_at(x, y) != layer:
				continue
			var feet := Vector2((x + 0.5) * 16, y * 16)
			if not grid.is_solid(x, y) or PlayerMotor.overlaps_solid(grid, feet):
				continue
			var open := 0
			for dx in range(-6, 7):
				if not grid.is_solid(x + dx, y - 1) and grid.is_solid(x + dx, y):
					open += 1
			if open < 9:
				continue
			for player in _server.players.values():
				player.position = feet
			_player().apply_correction(feet)
			return


func _place_torches() -> void:
	var player: PlayerState = _server.players.values()[0]
	var base := _player_tile()
	for dx in [-4, 0, 4]:
		var spot := Vector2i(base.x + dx, base.y - 1)
		_server._place(player, spot)


func _night_on_surface() -> void:
	_server.world.time_of_day = 0.02
	var grid: WorldGrid = _server.world.grid
	var feet := grid.spawn_position()
	for player in _server.players.values():
		player.position = feet
	_player().apply_correction(feet)
	_main._time_of_day = 0.02


func _toggle_inventory() -> void:
	_main._hud.toggle_inventory()


func _check_save() -> void:
	var result: Error = _server.save_now()
	var path: String = SaveGame.path_for(_server.save_name)
	var size := FileAccess.get_file_as_bytes(path).size() if FileAccess.file_exists(path) else 0
	print("save: %s (%s, %d KB)" % [path, error_string(result), size / 1024])


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	image.save_png(path)
	print("print: ", path)

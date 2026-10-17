extends SceneTree
## Roda o jogo, simula mouse e teclado e salva prints. Precisa de tela (não use --headless).
## Uso: godot --path . -s res://tests/captura.gd -- <pasta_saida> --novo
##
## Roteiro: dia na superfície → minera a grama → painel de fabricação → bancada e fornalha
## colocadas → fundindo cobre → casinha de tijolo e vidro → noite com as estações acesas →
## caverna com tochas → inventário aberto → confere o save.

var _out := "user://capturas"
var _frame := 0
var _main: Node
var _server: Node
var _steps: Array[Dictionary] = []
var _wait := 0
var _hut_left := 0


func _initialize() -> void:
	var script := "producao"
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			_out = arg
		elif arg.begins_with("--roteiro="):
			script = arg.trim_prefix("--roteiro=")
	DirAccess.make_dir_recursive_absolute(_out)
	_main = load("res://client/main.tscn").instantiate()
	root.add_child(_main)
	_server = root.get_node("GameServer")
	_steps = [
		{"wait": 90, "do": _shot.bind("1_dia_superficie")},
		{"wait": 1, "do": _press_on_tile.bind(Vector2i(2, 0))},
		{"wait": 12, "do": _shot.bind("2_minerando")},
		{"wait": 30, "do": _release},
		{"wait": 2, "do": _go_to_flat},
		{"wait": 4, "do": _give_materials},
		{"wait": 4, "do": _toggle_crafting},
		{"wait": 8, "do": _shot.bind("3_painel_fabricacao")},
		{"wait": 2, "do": _craft_and_place_stations},
		{"wait": 6, "do": _start_smelting},
		{"wait": 50, "do": _shot.bind("4_fila_de_producao")},
		{"wait": 2, "do": _toggle_crafting},
		{"wait": 8, "do": _shot.bind("5_fundindo_na_fornalha")},
		{"wait": 2, "do": _finish_queue},
		{"wait": 2, "do": _build_hut},
		{"wait": 20, "do": _shot.bind("6_construcao_tijolo_vidro")},
		{"wait": 2, "do": _night_on_surface},
		{"wait": 40, "do": _shot.bind("7_noite_estacoes_acesas")},
		{"wait": 2, "do": _debug_kit},
		{"wait": 6, "do": _select.bind(1)},
		{"wait": 2, "do": _dig_down.bind(6)},
		{"wait": 2, "do": _go_to_cave.bind(2)},
		{"wait": 2, "do": _select.bind(0)},
		{"wait": 4, "do": _place_torches},
		{"wait": 20, "do": _shot.bind("8_caverna_com_tochas")},
		{"wait": 2, "do": _toggle_inventory},
		{"wait": 6, "do": _shot.bind("9_inventario")},
		{"wait": 2, "do": _check_save},
		{"wait": 2, "do": quit},
	]
	if script == "tempestade":
		_steps = [
			{"wait": 90, "do": _go_to_flat},
			{"wait": 2, "do": _sand_patch},
			{"wait": 4, "do": _storm_start},
			{"wait": 240, "do": _shot.bind("30_tempestade_chegando")},
			{"wait": 1, "do": _bolt_on_sand.bind(0)},
			{"wait": 3, "do": _shot.bind("31_raio_na_areia")},
			{"wait": 40, "do": _shot.bind("32_fulgurito_brilhando")},
			{"wait": 2, "do": _feather},
			{"wait": 30, "do": _shot.bind("33_pena_caida")},
			{"wait": 2, "do": _awaken},
			{"wait": 10, "do": _shot.bind("34_tempestaria_desperta")},
			{"wait": 2, "do": _cast_on_sand},
			{"wait": 3, "do": _shot.bind("35_raio_invocado")},
			{"wait": 2, "do": _night_on_surface},
			{"wait": 2, "do": _bolt_on_sand.bind(4)},
			{"wait": 3, "do": _shot.bind("36_raio_a_noite")},
			{"wait": 60, "do": _shot.bind("37_noite_tempestade")},
			{"wait": 2, "do": quit},
		]
	if script == "experimento":
		_steps = [
			{"wait": 90, "do": _go_to_flat},
			{"wait": 2, "do": _lab_setup},
			{"wait": 4, "do": _toggle_crafting},
			{"wait": 2, "do": _lab_tab.bind(1)},
			{"wait": 4, "do": _lab_mix.bind({"lingote_cobre": 3})},
			{"wait": 6, "do": _shot.bind("20_experimentar_mistura")},
			{"wait": 2, "do": _lab_go},
			{"wait": 8, "do": _shot.bind("21_pista_falta_algo")},
			{"wait": 2, "do": _lab_mix.bind({"lingote_cobre": 3, "lingote_estanho": 1})},
			{"wait": 2, "do": _lab_go},
			{"wait": 8, "do": _shot.bind("22_descobriu_bronze")},
			{"wait": 2, "do": _lab_tab.bind(0)},
			{"wait": 6, "do": _shot.bind("23_receita_revelada")},
			{"wait": 2, "do": quit},
		]
	if script == "movimento":
		_steps = [
			{"wait": 90, "do": _go_to_flat},
			{"wait": 4, "do": _build_movement_scene},
			{"wait": 30, "do": _shot.bind("10_casa_portas_poco")},
			{"wait": 2, "do": _stand.bind(8, 0, false)},
			{"wait": 12, "do": _shot.bind("11_porta_aberta")},
			{"wait": 2, "do": _stand.bind(6, -3, false)},
			{"wait": 12, "do": _shot.bind("12_em_cima_da_plataforma")},
			{"wait": 2, "do": _stand.bind(13, 6, true)},
			{"wait": 12, "do": _shot.bind("13_escada_no_poco")},
			{"wait": 2, "do": _ladder_trial_start},
			{"wait": 75, "do": _shot.bind("15_escada_se_colocando")},
			{"wait": 150, "do": _ladder_trial_check},
			{"wait": 2, "do": _night_on_surface},
			{"wait": 30, "do": _shot.bind("14_noite_casa")},
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


func _state() -> PlayerState:
	return _server.players.values()[0]


func _give_materials() -> void:
	var inv := _state().inventory
	for i in Inventory.SIZE:
		inv.slots[i] = {}
	for pair in [
		["madeira", 14], ["argila", 10], ["calcario", 3], ["malaquita", 4], ["carvao_vegetal", 3]
	]:
		inv.add(pair[0], pair[1])
	_server._send_inventory(_state())


func _toggle_crafting() -> void:
	_main._hud.toggle_crafting()


## Fabrica bancada e fornalha pelo servidor (sem esperar) e coloca as duas ao lado do jogador.
func _craft_and_place_stations() -> void:
	for pair in [["bancada", [3, 4, 5, 2, 6]], ["fornalha", [-3, -4, -2, -5, -6]]]:
		_main._session.craft("fazer_" + pair[0], 1)
		_server.step_once()
		_finish_queue()
		_place_near(pair[0], pair[1])


func _start_smelting() -> void:
	_main._session.craft("fundir_cobre", 2)


func _finish_queue() -> void:
	var player := _state()
	for i in 2000:
		if player.craft_queue.is_empty():
			break
		_server.step_once()


## Coloca um item do inventário no primeiro lugar válido entre as distâncias dadas.
func _place_near(item: String, offsets: Array) -> void:
	var player := _state()
	var grid: WorldGrid = _server.world.grid
	var base := _player_tile()
	for dx in offsets:
		var x: int = base.x + dx
		for y in range(base.y - 3, base.y + 3):
			if grid.get_tile(x, y) != 0 or not grid.is_solid(x, y + 1):
				continue
			_put_in_hand(item)
			_server._place(player, Vector2i(x, y))
			if grid.tile_name(x, y) == item:
				return


func _put_in_hand(item: String) -> void:
	var player := _state()
	for i in Inventory.SIZE:
		if player.inventory.slots[i].get("id") == item:
			player.inventory.swap(i, 0)
			break
	if player.inventory.slots[0].get("id") != item:
		# Só para montar a cena da construção (tijolo, vidro, terra): o resto vem da fabricação.
		var scenery := [
			"tijolo", "vidro", "tocha", "porta", "plataforma", "escada", "corda", "fornalha"
		]
		assert(item in scenery, "faltou fabricar: " + item)
		player.inventory.slots[0] = {"id": item, "qtd": 20}
	player.selected = 0


## Leva o jogador a um trecho plano e sem árvores: casinha à esquerda, estações dos lados.
func _go_to_flat() -> void:
	var grid: WorldGrid = _server.world.grid
	var start := grid.spawn_tile.x
	for distance in range(0, 300):
		for left in [start - distance, start + distance]:
			if _flat_clear(grid, left, 17):
				_hut_left = left
				var feet := Vector2((left + 11.5) * 16, grid.surface[left] * 16)
				for player in _server.players.values():
					player.position = feet
				_player().apply_correction(feet)
				print("trecho plano em x=%d" % left)
				return


## Casinha de tijolo com janelas de vidro e uma tocha dentro.
func _build_hut() -> void:
	var player := _state()
	var grid: WorldGrid = _server.world.grid
	var left := _hut_left
	var floor_y: int = grid.surface[left]
	var keep := player.position
	var stand := Vector2i(left + 3, floor_y)
	for h in range(1, 5):
		for x in [left, left + 6]:
			_place_as(
				player, "vidro" if h == 2 or h == 3 else "tijolo", Vector2i(x, floor_y - h), stand
			)
	for x in range(left, left + 7):
		_place_as(player, "tijolo", Vector2i(x, floor_y - 5), stand)
	for x in range(left + 1, left + 6):
		_place_as(player, "tijolo", Vector2i(x, floor_y - 6), stand)
	_place_as(player, "vidro", Vector2i(left + 3, floor_y - 7), stand)
	_place_as(player, "tocha", Vector2i(left + 1, floor_y - 1), stand)
	player.position = keep


## Colunas na mesma altura, com chão firme e ar livre por cima (sem árvore no caminho).
func _flat_clear(grid: WorldGrid, left: int, width: int) -> bool:
	if left < 2 or left + width >= grid.width - 2:
		return false
	var floor_y: int = grid.surface[left]
	for x in range(left, left + width):
		if grid.surface[x] != floor_y or not grid.is_solid(x, floor_y):
			return false
		for y in range(floor_y - 8, floor_y):
			if grid.get_tile(x, y) != 0:
				return false
	return true


func _place_as(player: PlayerState, item: String, tile: Vector2i, stand: Vector2i) -> void:
	_put_in_hand(item)
	player.position = Vector2((stand.x + 0.5) * 16, stand.y * 16)
	if not MiningRules.in_reach(player.position, tile):
		player.position = Vector2((tile.x + 3.5) * 16, (tile.y + 2) * 16)
	_server._place(player, tile)
	var grid: WorldGrid = _server.world.grid
	if grid.tile_name(tile.x, tile.y) != item:
		var problem := Building.placement_problem(grid, tile, Building.BLOCK, [player.position])
		print(
			(
				"casa: não coube %s em %s (%s, alcance %s, havia %s)"
				% [
					item,
					tile,
					problem,
					MiningRules.in_reach(player.position, tile),
					grid.tile_name(tile.x, tile.y)
				]
			)
		)


## Faixa de areia no chão, à esquerda do jogador.
func _sand_patch() -> void:
	var grid: WorldGrid = _server.world.grid
	var changes: Array = []
	var sand := grid.registry.id_of("areia")
	for x in range(_hut_left + 1, _hut_left + 9):
		for y in range(grid.surface[x], grid.surface[x] + 3):
			changes.append(_server.world.set_tile(x, y, sand))
	_server._emit(Events.BROADCAST, {"type": Events.TILE_CHANGED, "changes": changes})


func _storm_start() -> void:
	_server.weather.start_storm()
	_server._on_storm_start()


func _bolt_on_sand(dx: int) -> void:
	_server._strike(_hut_left + 3 + dx, 0)


func _feather() -> void:
	_server._drop_feather()


func _awaken() -> void:
	_server._give(_state(), "pena_ave_trovao", 1)
	_server._send_inventory(_state())


func _cast_on_sand() -> void:
	var grid: WorldGrid = _server.world.grid
	var x := _hut_left + 7
	_main._session.cast("raio", Vector2i(x, grid.surface[x]))


func _lab_setup() -> void:
	var inv := _state().inventory
	for i in Inventory.SIZE:
		inv.slots[i] = {}
	for pair in [
		["lingote_cobre", 7], ["lingote_estanho", 3], ["argila", 6], ["areia", 4], ["madeira", 8]
	]:
		inv.add(pair[0], pair[1])
	inv.add("fornalha", 1)
	_place_near("fornalha", [-3, -4, -2, 3, 4])
	_server._send_inventory(_state())


func _lab_tab(index: int) -> void:
	_main._hud.crafting._show_tab(index)


func _lab_mix(mix: Dictionary) -> void:
	var panel = _main._hud.crafting
	panel._mix = mix.duplicate()
	panel._lab_signature = ""
	panel._refresh_lab()


func _lab_go() -> void:
	var panel = _main._hud.crafting
	panel.experiment_requested.emit(panel._station, panel._mix.duplicate())


## Casinha com porta dos dois lados e um andar de plataforma; poço com escada e corda ao lado.
func _build_movement_scene() -> void:
	var player := _state()
	var grid: WorldGrid = _server.world.grid
	var left := _hut_left
	var floor_y: int = grid.surface[left]
	var keep := player.position
	var inside := Vector2i(left + 5, floor_y)
	for x in [left + 2, left + 8]:
		_place_as(player, "porta", Vector2i(x, floor_y - 1), inside)
		for h in range(3, 6):
			_place_as(player, "tijolo", Vector2i(x, floor_y - h), inside)
	for x in range(left + 2, left + 9):
		_place_as(player, "tijolo", Vector2i(x, floor_y - 6), inside)
	for h in range(1, 4):
		_place_as(player, "escada", Vector2i(left + 4, floor_y - h), inside)
	for x in range(left + 3, left + 8):
		if x != left + 4:
			_place_as(player, "plataforma", Vector2i(x, floor_y - 3), inside)
	_place_as(player, "tocha", Vector2i(left + 7, floor_y - 4), inside)
	# Poço de 2 de largura e 9 de fundo, à direita da casa.
	var changes: Array = []
	for y in range(floor_y, floor_y + 9):
		for x in [left + 13, left + 14]:
			changes.append(_server.world.set_tile(x, y, 0))
	_server._emit(Events.BROADCAST, {"type": Events.TILE_CHANGED, "changes": changes})
	var shaft_stand := Vector2i(left + 11, floor_y)
	for y in range(floor_y + 8, floor_y - 1, -1):
		_place_as(player, "escada", Vector2i(left + 13, y), Vector2i(left + 13, y + 1))
	_place_as(player, "corda", Vector2i(left + 14, floor_y), shaft_stand)
	player.position = keep


## Tira a escada do poço, põe o jogador no fundo com escadas na mão e segura "pular".
func _ladder_trial_start() -> void:
	var grid: WorldGrid = _server.world.grid
	var floor_y: int = grid.surface[_hut_left]
	var changes: Array = []
	for y in range(floor_y, floor_y + 9):
		changes.append(_server.world.set_tile(_hut_left + 13, y, 0))
	_server._emit(Events.BROADCAST, {"type": Events.TILE_CHANGED, "changes": changes})
	_put_in_hand("escada")
	_server._send_inventory(_state())
	_main._session.select_slot(0)
	_stand(13, 9, false)
	Input.action_press("pular")


func _ladder_trial_check() -> void:
	Input.action_release("pular")
	var grid: WorldGrid = _server.world.grid
	var floor_y: int = grid.surface[_hut_left]
	var rungs := 0
	for y in range(floor_y - 3, floor_y + 9):
		if grid.tile_name(_hut_left + 13, y) == "escada":
			rungs += 1
	var feet_row := int(_player().position.y / 16)
	print(
		(
			"escada automática: %d degraus, pés na linha %d (superfície %d)"
			% [rungs, feet_row, floor_y]
		)
	)
	_shot("16_saiu_do_poco")


## Põe o jogador em (dx, dy) tiles do começo do trecho plano; `climb` = pendurado na escada.
func _stand(dx: int, dy: int, climb: bool) -> void:
	var grid: WorldGrid = _server.world.grid
	var feet := Vector2((_hut_left + dx + 0.5) * 16, (grid.surface[_hut_left] + dy) * 16)
	for player in _server.players.values():
		player.position = feet
	_player().apply_correction(feet)
	_player().motor.climbing = climb
	_player().motor.on_floor = not climb


func _night_on_surface() -> void:
	_server.world.time_of_day = 0.02
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

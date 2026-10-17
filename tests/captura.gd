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
		assert(item in ["tijolo", "vidro", "tocha"], "faltou fabricar: " + item)
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

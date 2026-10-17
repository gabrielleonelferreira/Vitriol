extends SceneTree
## Maratona do portão da Onda 5: um robô joga do primeiro bloco ao primeiro raio num mundo de
## tamanho real, em velocidade acelerada (só o servidor), e anota o que deu errado.
## Uso: godot --headless --path . -s res://tests/maratona.gd -- [minutos=45]
##
## O robô não anda de verdade: ele se posiciona perto do alvo (o servidor só confere o alcance) e
## manda os mesmos comandos que o jogo manda. Serve para achar travamentos, erros e buracos na
## progressão; a sensação de jogar fica para o teste com gente.

const TICK := 1.0 / 20.0

var _server
var _transport: LocalTransport
var _player: PlayerState
var _events: Array[Dictionary] = []
var _log: PackedStringArray = []
var _bugs: PackedStringArray = []
var _counts: Dictionary = {}
var _slowest_tick_ms: float = 0.0
var _target := Vector2i(-1, -1)
var _wait_ticks := 0
## Onde ficaram as estações colocadas (para voltar até elas antes de fabricar).
var _stations: Dictionary = {}


func _initialize() -> void:
	var minutes := 45.0
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_float():
			minutes = float(arg)
	var data := DataStore.new()
	data.load_all()
	var started := Time.get_ticks_msec()
	# Carregado aqui (não com preload): o servidor usa o autoload GameData, que só existe agora.
	var server_script: GDScript = load("res://core/server/game_server.gd")
	_server = server_script.new()
	_server.start(server_script.DEFAULT_SEED, data)
	_connect()
	_note("mundo %dx%d pronto" % [_server.world.grid.width, _server.world.grid.height])
	var plan: Array[Callable] = [
		_gather.bind("madeira", TileRegistry.TRUNK, 6),
		_gather.bind("silex", "silex", 2),
		_craft.bind("fazer_picareta_silex", 1, "picareta_silex"),
		_hold.bind("picareta_silex"),
		_craft.bind("fazer_bancada", 1, "bancada"),
		_place_station.bind("bancada"),
		_gather.bind("argila", "argila", 8),
		_gather.bind("calcario", "calcario", 2),
		_craft.bind("fazer_fornalha", 1, "fornalha"),
		_place_station.bind("fornalha"),
		_gather.bind("madeira", TileRegistry.TRUNK, 6),
		_craft.bind("carvoaria", 2, "carvao_vegetal"),
		_gather.bind("malaquita", "malaquita", 2),
		_craft.bind("fundir_cobre", 1, "lingote_cobre"),
		_craft.bind("cozer_tijolo", 1, "tijolo"),
		_craft.bind("fazer_escada", 2, "escada"),
		_save_and_reload,
		_wait_storm,
		_take_feather,
		_cast_bolt,
	]
	var step := 0
	var ticks := int(minutes * 60.0 / TICK)
	for i in ticks:
		var t0 := Time.get_ticks_usec()
		_server.step_once()
		_slowest_tick_ms = maxf(_slowest_tick_ms, (Time.get_ticks_usec() - t0) / 1000.0)
		_drain()
		if step < plan.size() and i % 4 == 0:
			if plan[step].call():
				_note("passo %d feito aos %s" % [step + 1, _clock(i)])
				step += 1
	if step < plan.size():
		_bug("parou no passo %d de %d" % [step + 1, plan.size()])
	_note(
		(
			"%s simulados em %.1f s reais; tick mais lento %.1f ms"
			% [_clock(ticks), (Time.get_ticks_msec() - started) / 1000.0, _slowest_tick_ms]
		)
	)
	_note("eventos: %s" % str(_counts))
	print("\n".join(_log))
	print("BUGS: %d" % _bugs.size())
	for bug in _bugs:
		print("  - " + bug)
	_transport.close()
	_server.free()
	data.free()
	quit(1 if not _bugs.is_empty() else 0)


func _connect() -> void:
	_transport = LocalTransport.new(_server)
	_transport.event_received.connect(func(event: Dictionary) -> void: _events.append(event))
	_transport.open()
	_transport.send({"type": Commands.JOIN, "name": "Robô"})
	_server.step_once()
	_player = _server.players[_transport.peer_id]


func _drain() -> void:
	for event in _events:
		var type: String = event["type"]
		_counts[type] = int(_counts.get(type, 0)) + 1
		if type == Events.ERROR:
			_bug("erro do servidor: %s" % str(event))
		if type == Events.MESSAGE:
			_counts["ultima_mensagem"] = event["text"]
	_events.clear()


# ---------------------------------------------------------------- passos do plano


## Junta `count` do item `item` minerando tiles chamados `tile`.
func _gather(item: String, tile: String, count: int) -> bool:
	if _player.inventory.count(item) >= count:
		_target = Vector2i(-1, -1)
		return true
	var grid: WorldGrid = _server.world.grid
	if _target.x < 0 or grid.tile_name(_target.x, _target.y) != tile:
		_target = _nearest(tile)
		if _target.x < 0:
			_bug("não achei '%s' no mundo" % tile)
			return true
		_stand_near(_target)
	_transport.send({"type": Commands.MINE, "x": _target.x, "y": _target.y})
	return false


func _craft(recipe: String, qtd: int, output: String) -> bool:
	if _player.craft_queue.is_empty() and _wait_ticks > 0 and _player.inventory.count(output) > 0:
		_wait_ticks = 0
		return true
	if _wait_ticks == 0:
		_wait_ticks = 1
		var station: String = _server.data.get_recipe(recipe)["estacao"]
		if _stations.has(station):
			_stand_near(_stations[station] + Vector2i(1, 0))
		_transport.send({"type": Commands.CRAFT, "receita": recipe, "qtd": qtd})
		return false
	_wait_ticks += 1
	if _wait_ticks > 2000:
		_bug("receita '%s' não terminou (fila: %s)" % [recipe, str(_player.craft_queue)])
		_wait_ticks = 0
		return true
	if _wait_ticks == 3 and _player.craft_queue.is_empty() and _player.inventory.count(output) == 0:
		_bug("receita '%s' recusada: %s" % [recipe, _last_message()])
		_wait_ticks = 0
		return true
	return false


func _hold(item: String) -> bool:
	for i in Inventory.SIZE:
		if _player.inventory.slots[i].get("id") == item:
			if i >= Inventory.HOTBAR:
				_transport.send({"type": Commands.SWAP_SLOTS, "a": i, "b": 0})
				return false
			_transport.send({"type": Commands.SELECT_SLOT, "index": i})
			return true
	_bug("sem '%s' para segurar" % item)
	return true


## Coloca a estação no chão a 2 tiles do jogador (procura um lugar que sirva).
func _place_station(item: String) -> bool:
	var grid: WorldGrid = _server.world.grid
	if _stations.has("bancada"):
		_stand_on_ground(_stations["bancada"])
	var feet := WorldGrid.to_tile(_player.position)
	for dx in [2, -2, 3, -3, 1, -1, 4, -4]:
		for dy in range(-3, 4):
			var spot := Vector2i(feet.x + dx, feet.y + dy - 1)
			var free := grid.get_tile(spot.x, spot.y) == 0
			if free and Building.placement_problem(grid, spot, Building.STATION, []).is_empty():
				for i in Inventory.HOTBAR:
					if _player.inventory.slots[i].get("id") == item:
						_player.selected = i
				_transport.send({"type": Commands.PLACE, "x": spot.x, "y": spot.y})
				_server.step_once()
				_hold("picareta_silex")
				if grid.tile_name(spot.x, spot.y) == item:
					_stations[item] = spot
					return true
	_bug("não consegui colocar '%s' perto de %s: %s" % [item, str(feet), _last_message()])
	return true


func _save_and_reload() -> bool:
	var before := _player.to_save()
	if _server.save_name.is_empty():
		_server.save_name = "maratona"
	var result: Error = _server.save_now()
	if result != OK:
		_bug("save falhou: %s" % error_string(result))
	_transport.close()
	_server.step_once()
	_connect()
	var after := _player.to_save()
	if before["inventario"] != after["inventario"]:
		_bug("inventário mudou ao sair e voltar")
	return true


func _wait_storm() -> bool:
	return _server.weather.storm and _counts.get(Events.LIGHTNING, 0) > 0


func _take_feather() -> bool:
	if _player.schools.has("tempestaria"):
		return true
	var feather := _nearest(TileRegistry.FEATHER)
	if feather.x < 0:
		if not _server.weather.storm:
			_bug("a tempestade acabou sem pena perto")
			return true
		return false
	_stand_near(feather)
	_transport.send({"type": Commands.MINE, "x": feather.x, "y": feather.y})
	return false


func _cast_bolt() -> bool:
	var feet := WorldGrid.to_tile(_player.position)
	var grid: WorldGrid = _server.world.grid
	var x := feet.x + 3
	var sand := grid.registry.id_of("areia")
	var top: int = grid.surface[x]
	_server.world.set_tile(x, top, sand)
	_player.cast_ready_tick = 0
	_transport.send({"type": Commands.CAST, "magia": "raio", "x": x, "y": top})
	_server.step_once()
	if grid.tile_name(x, top) != "fulgurito":
		_bug("raio invocado não fundiu a areia: %s" % _last_message())
	return true


# ---------------------------------------------------------------- ajudas


func _nearest(tile: String) -> Vector2i:
	var grid: WorldGrid = _server.world.grid
	var id := grid.registry.id_of(tile)
	var origin := WorldGrid.to_tile(_player.position)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in grid.height:
		for x in grid.width:
			if grid.get_tile(x, y) != id:
				continue
			var d := Vector2(x - origin.x, (y - origin.y) * 1.5).length()
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best


## Põe o jogador a 2 tiles do alvo (o servidor só confere o alcance para minerar).
func _stand_near(cell: Vector2i) -> void:
	_player.position = Vector2((cell.x - 1.5) * 16, (cell.y + 1) * 16)


## Volta para o chão firme ao lado de uma estação (onde dá para pôr outra).
func _stand_on_ground(cell: Vector2i) -> void:
	_player.position = Vector2((cell.x + 0.5) * 16, (cell.y + 1) * 16)


func _last_message() -> String:
	return str(_counts.get("ultima_mensagem", "?"))


func _clock(ticks: int) -> String:
	var seconds := int(ticks * TICK)
	return "%d min %02d s" % [seconds / 60, seconds % 60]


func _note(text: String) -> void:
	_log.append(text)


func _bug(text: String) -> void:
	_bugs.append(text)
	push_warning("maratona: " + text)

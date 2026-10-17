extends Node
## Servidor autoritativo do jogo (autoload "GameServer").
##
## No solo, roda no mesmo processo do cliente (servidor local). No multiplayer,
## o mesmo código roda num servidor dedicado. Regras:
##   1. Só o servidor altera o estado (mundo, jogadores, inventários).
##   2. Clientes enviam comandos (Commands) por um Transport.
##   3. O servidor responde com eventos (Events) pelo sinal event_emitted.
##   4. Comandos são processados em ticks fixos, na ordem em que chegaram.

signal event_emitted(peer_id: int, event: Dictionary)

const TICK_RATE := 20
const TICK_INTERVAL := 1.0 / TICK_RATE
## Semente usada quando nenhuma é passada (--semente=N na linha de comando).
const DEFAULT_SEED := 20261016
const DEFAULT_WORLD := "mundo_1"
## Validação de movimento: velocidade máxima aceita (px/s) e folga (px) para atrasos.
const MAX_MOVE_SPEED := 620.0
const MOVE_SLACK := 24.0
## Tolerância (px) ao conferir se o personagem está dentro de um bloco.
const SOLID_TOLERANCE := 2.0
const AUTOSAVE_SECONDS := 60.0
## Chance de uma folha render fibra vegetal (para corda).
const LEAF_FIBER_CHANCE := 0.34
## Itens com que todo jogador novo começa.
const STARTER_KIT := [["tocha", 10]]
## Tempestária: espera entre raios invocados (s) e alcance (tiles do corpo até o alvo).
const CAST_COOLDOWN := 5.0
const CAST_RANGE := 12.0
## Raios naturais caem perto de um jogador, até esta distância (tiles), preferindo areia.
const BOLT_SPREAD := 28
const BOLT_SAND_WEIGHT := 6.0
const DEBUG_KIT_ITEMS := [
	["picareta_silex", 1], ["picareta_bronze", 1], ["picareta_aco", 1], ["bateia", 1], ["tocha", 40]
]

var world: WorldState = WorldState.new()
var weather: Weather = Weather.new()
var data: DataStore
var players: Dictionary = {}
var tick: int = 0
## Nome do mundo salvo. Vazio = não salva (testes).
var save_name: String = ""
## Jogadores que já estiveram no mundo, por nome (posição, inventário, descobertas).
var saved_players: Dictionary = {}

var _pending: Array[Dictionary] = []
var _accumulator: float = 0.0
var _next_peer_id: int = 1
var _connected_peers: Dictionary = {}
var _autosave_timer: float = 0.0
var _dirty: bool = false


func _ready() -> void:
	var options := _command_line()
	if options.has("novo"):
		SaveGame.delete(options.get("mundo", DEFAULT_WORLD))
	start(
		int(options.get("semente", DEFAULT_SEED)),
		GameData,
		WorldGenerator.DEFAULT_WIDTH,
		WorldGenerator.DEFAULT_HEIGHT,
		options.get("mundo", DEFAULT_WORLD)
	)


## Carrega o mundo salvo (se houver) ou gera um novo, e deixa o servidor pronto.
func start(
	world_seed: int,
	game_data: DataStore,
	width: int = WorldGenerator.DEFAULT_WIDTH,
	height: int = WorldGenerator.DEFAULT_HEIGHT,
	world_name: String = ""
) -> void:
	data = game_data
	save_name = world_name
	saved_players.clear()
	if not data.loaded:
		push_error("GameServer: dados de jogo não carregados; o mundo não foi gerado.")
		world = WorldState.new(world_seed)
		return
	var started := Time.get_ticks_msec()
	var saved := SaveGame.read(save_name) if not save_name.is_empty() else {}
	if not saved.is_empty():
		world = WorldState.from_save(saved["mundo"], data)
		saved_players = saved.get("jogadores", {})
		print(
			(
				"GameServer: mundo '%s' carregado em %d ms"
				% [save_name, Time.get_ticks_msec() - started]
			)
		)
	else:
		world = WorldState.new(world_seed)
		world.generate(data, width, height)
		print(
			(
				"GameServer: mundo %dx%d gerado em %d ms (semente %d)"
				% [width, height, Time.get_ticks_msec() - started, world_seed]
			)
		)
	weather = Weather.new(world.world_seed)


## Grava o mundo e todos os jogadores. Devolve OK ou o erro.
func save_now() -> Error:
	if save_name.is_empty() or not world.is_ready():
		return ERR_UNCONFIGURED
	for player in players.values():
		saved_players[player.display_name] = player.to_save()
	var result := SaveGame.write(save_name, world, saved_players)
	_dirty = false
	_autosave_timer = 0.0
	if result != OK:
		push_error("GameServer: não consegui salvar (%s)" % error_string(result))
	return result


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if not save_name.is_empty():
			save_now()


## Registra uma nova conexão e devolve o id dela.
func connect_peer() -> int:
	var peer_id := _next_peer_id
	_next_peer_id += 1
	_connected_peers[peer_id] = true
	return peer_id


## Encerra uma conexão e remove o jogador dela, se houver.
func disconnect_peer(peer_id: int) -> void:
	_connected_peers.erase(peer_id)
	if players.has(peer_id):
		var player: PlayerState = players[peer_id]
		saved_players[player.display_name] = player.to_save()
		players.erase(peer_id)
		_dirty = true
		_emit(Events.BROADCAST, {"type": Events.PLAYER_LEFT, "player_id": peer_id})


## Enfileira um comando. Ele é processado no próximo tick.
func submit(peer_id: int, command: Dictionary) -> void:
	if not _connected_peers.has(peer_id):
		push_warning("Comando de conexão desconhecida: %d" % peer_id)
		return
	_pending.append({"peer_id": peer_id, "command": command})


## Processa um tick imediatamente. Usado pelo loop e pelos testes.
func step_once() -> void:
	tick += 1
	var batch: Array[Dictionary] = _pending
	_pending = []
	for entry in batch:
		_handle(entry["peer_id"], entry["command"])
	for player in players.values():
		if player.mining_active:
			_advance_mining(player)
		if not player.craft_queue.is_empty():
			_advance_crafting(player)
	if world.is_ready():
		world.step(TICK_INTERVAL)
		_step_weather()
		if tick % TICK_RATE == 0:
			_emit(Events.BROADCAST, {"type": Events.TIME, "time": world.time_of_day})
	if not save_name.is_empty():
		_autosave_timer += TICK_INTERVAL
		if _autosave_timer >= AUTOSAVE_SECONDS and (_dirty or not players.is_empty()):
			save_now()


func _physics_process(delta: float) -> void:
	_accumulator += delta
	while _accumulator >= TICK_INTERVAL:
		_accumulator -= TICK_INTERVAL
		step_once()


func _handle(peer_id: int, command: Dictionary) -> void:
	var player: PlayerState = players.get(peer_id)
	match command.get("type", ""):
		Commands.JOIN:
			_join(peer_id, str(command.get("name", "Alquimista")))
		Commands.LEAVE:
			disconnect_peer(peer_id)
		Commands.PING:
			_emit(peer_id, {"type": Events.PONG, "tick": tick})
		Commands.MOVE:
			_move(peer_id, command)
		Commands.MINE:
			if player:
				_start_mining(
					player, Vector2i(int(command.get("x", -1)), int(command.get("y", -1)))
				)
		Commands.MINE_STOP:
			if player:
				_stop_mining(player)
		Commands.PLACE:
			if player:
				var spot := Vector2i(int(command.get("x", -1)), int(command.get("y", -1)))
				_place(player, spot, bool(command.get("auto", false)))
		Commands.SELECT_SLOT:
			if player:
				player.selected = clampi(int(command.get("index", 0)), 0, Inventory.HOTBAR - 1)
				_send_inventory(player)
		Commands.SWAP_SLOTS:
			if (
				player
				and player.inventory.swap(int(command.get("a", -1)), int(command.get("b", -1)))
			):
				_send_inventory(player)
		Commands.CRAFT:
			if player:
				_craft(player, str(command.get("receita", "")), int(command.get("qtd", 1)))
		Commands.EXPERIMENT:
			if player:
				_experiment(player, command)
		Commands.CAST:
			if player:
				_cast(player, command)
		Commands.DEBUG_STORM:
			if OS.is_debug_build() and not weather.storm:
				weather.start_storm()
				_on_storm_start()
		Commands.CRAFT_CANCEL:
			if player:
				_cancel_craft(player, int(command.get("index", -1)))
		Commands.DEBUG_KIT:
			if player and OS.is_debug_build():
				for entry in DEBUG_KIT_ITEMS:
					_give(player, entry[0], entry[1])
				_send_inventory(player)
				_message(player, "Kit de teste recebido.", "info")
		_:
			_emit(peer_id, {"type": Events.ERROR, "reason": "comando desconhecido"})


# ---------------------------------------------------------------- entrada e movimento


func _join(peer_id: int, display_name: String) -> void:
	if players.has(peer_id):
		_emit(peer_id, {"type": Events.ERROR, "reason": "jogador já conectado"})
		return
	if not world.is_ready():
		_emit(peer_id, {"type": Events.ERROR, "reason": "mundo não está pronto"})
		return
	var player := PlayerState.new(peer_id, display_name, data)
	player.position = world.grid.spawn_position()
	if saved_players.has(display_name):
		player.load_save(saved_players[display_name])
		if PlayerMotor.overlaps_solid(world.grid, player.position, SOLID_TOLERANCE):
			player.position = world.grid.spawn_position()
	else:
		for entry in STARTER_KIT:
			player.inventory.add(entry[0], entry[1])
			player.discoveries[entry[0]] = true
	player.last_move_tick = tick
	players[peer_id] = player
	var snapshot := world.grid.to_snapshot()
	_emit(peer_id, {"type": Events.WORLD_SNAPSHOT, "grid": snapshot, "time": world.time_of_day})
	_emit(
		peer_id,
		{
			"type": Events.JOINED,
			"player_id": peer_id,
			"player": player.to_dict(),
			"world": {"seed": world.world_seed},
			"tick": tick,
		}
	)
	_send_inventory(player)
	_send_mastery(player)
	_emit(peer_id, {"type": Events.WEATHER, "tempestade": weather.storm})
	_send_queue(player)


## Aceita a posição enviada pelo cliente se ela for possível; se não, corrige.
func _move(peer_id: int, command: Dictionary) -> void:
	var player: PlayerState = players.get(peer_id)
	if player == null:
		return
	var raw: Variant = command.get("position")
	if typeof(raw) != TYPE_ARRAY or raw.size() != 2:
		return
	var target := Vector2(float(raw[0]), float(raw[1]))
	var elapsed := maxf(1.0, tick - player.last_move_tick) * TICK_INTERVAL
	var too_fast := target.distance_to(player.position) > MAX_MOVE_SPEED * elapsed + MOVE_SLACK
	var grid := world.grid
	var outside := (
		target.x < 0
		or target.y < PlayerMotor.HITBOX.y
		or target.x > grid.width * WorldGrid.TILE_SIZE
		or target.y > grid.height * WorldGrid.TILE_SIZE
	)
	if too_fast or outside or PlayerMotor.overlaps_solid(grid, target, SOLID_TOLERANCE):
		_emit(
			peer_id, {"type": Events.CORRECTION, "position": [player.position.x, player.position.y]}
		)
		return
	player.position = target
	var vel: Variant = command.get("velocity", [0, 0])
	if typeof(vel) == TYPE_ARRAY and vel.size() == 2:
		player.velocity = Vector2(float(vel[0]), float(vel[1]))
	player.facing = 1 if int(command.get("facing", 1)) >= 0 else -1
	player.last_move_tick = tick
	var moved := player.to_dict()
	moved["type"] = Events.PLAYER_MOVED
	_emit(Events.BROADCAST, moved)


# ---------------------------------------------------------------- mineração


func _start_mining(player: PlayerState, target: Vector2i) -> void:
	if target != player.mining_target:
		player.mining_target = target
		player.mining_progress = 0.0
	player.mining_active = true


func _stop_mining(player: PlayerState) -> void:
	player.mining_active = false
	player.mining_progress = 0.0
	_emit(player.player_id, {"type": Events.MINE_PROGRESS, "x": -1, "y": -1, "progress": -1.0})


## Força e se é mão, a partir do item selecionado.
func _tool_power(player: PlayerState) -> Array:
	var held: Dictionary = player.selected_item()
	var item: Dictionary = data.items.get(held.get("id", ""), {})
	var power: Variant = item.get("poder_mineracao")
	if power != null:
		return [float(power), false]
	return [MiningRules.HAND_POWER, true]


func _advance_mining(player: PlayerState) -> void:
	var grid := world.grid
	var target := player.mining_target
	var id := grid.get_tile(target.x, target.y)
	if id <= 0 or grid.registry.is_liquid(id):
		_stop_mining(player)
		return
	if not MiningRules.in_reach(player.position, target):
		_stop_mining(player)
		return
	var hardness: float = grid.registry.hardness[id]
	var tool := _tool_power(player)
	var seconds := MiningRules.break_time(hardness, tool[0], tool[1])
	if seconds == INF:
		_stop_mining(player)
		if hardness == INF:
			_message(player, "Esta rocha é indestrutível.", "aviso")
		else:
			_message(
				player,
				(
					"Muito duro para %s: precisa de força %s."
					% [_tool_name(player, tool[1]), _fmt(hardness)]
				),
				"aviso"
			)
		return
	player.mining_progress += TICK_INTERVAL / seconds
	if player.mining_progress < 1.0:
		_emit(
			player.player_id,
			{
				"type": Events.MINE_PROGRESS,
				"x": target.x,
				"y": target.y,
				"progress": player.mining_progress
			}
		)
		return
	_break_block(player, target, id, tool[1])


func _break_block(player: PlayerState, target: Vector2i, id: int, is_hand: bool) -> void:
	var grid := world.grid
	var cells: Array[Vector2i] = [target]
	var drops := {}
	var shape := grid.registry.shape_of(id)
	if grid.registry.name_of(id) == TileRegistry.TRUNK:
		cells = world.tree_from(target.x, target.y)
	elif shape == TileRegistry.SHAPE_DOOR or grid.registry.name_of(id) == "corda":
		cells = Building.piece_from(grid, target)
		drops = Building.refund_for(grid, cells)
	if drops.is_empty():
		for cell in cells:
			var drop := _drop_for(player, grid.get_tile(cell.x, cell.y))
			if not drop.is_empty():
				drops[drop] = drops.get(drop, 0) + 1
	for drop in drops:
		if not player.inventory.can_add(drop, drops[drop]):
			_stop_mining(player)
			_message(player, "Inventário cheio.", "aviso")
			return
	var changes: Array = []
	for cell in cells:
		changes.append(world.set_tile(cell.x, cell.y, 0))
	_dirty = true
	_emit(Events.BROADCAST, {"type": Events.TILE_CHANGED, "changes": changes})
	for drop in drops:
		_give(player, drop, drops[drop])
	if not is_hand and player.inventory.wear(player.selected):
		_message(player, "Sua ferramenta quebrou.", "aviso")
	player.mining_progress = 0.0
	_emit(player.player_id, {"type": Events.MINE_PROGRESS, "x": -1, "y": -1, "progress": -1.0})
	_send_inventory(player)


## O que um tile rende ao quebrar. Cascalho com bateia vira garimpo.
func _drop_for(player: PlayerState, id: int) -> String:
	var name := world.grid.registry.name_of(id)
	if name == TileRegistry.LEAVES:
		return "fibra" if randf() < LEAF_FIBER_CHANCE else ""
	if name == "cascalho" and player.selected_item().get("id") == "bateia":
		var roll := randf()
		for entry in MiningRules.PANNING:
			if roll <= entry[1]:
				return entry[0]
	return world.grid.registry.drops[id]


func _tool_name(player: PlayerState, is_hand: bool) -> String:
	if is_hand:
		return "as mãos"
	return data.display_name(player.selected_item().get("id", ""))


# ---------------------------------------------------------------- colocar objetos


## Coloca no mundo o item selecionado: objeto (tocha), estação (bancada, fornalha...) ou bloco.
## `quiet`: colocação automática (escada subindo) não manda aviso quando não dá.
func _place(player: PlayerState, target: Vector2i, quiet: bool = false) -> void:
	var held: Dictionary = player.selected_item()
	var item_id: String = held.get("id", "")
	var kind := Building.kind_for(data, item_id)
	if kind.is_empty():
		return
	var grid := world.grid
	var tile_id := grid.registry.id_of(item_id)
	if tile_id < 0 or not grid.in_bounds(target.x, target.y):
		return
	var current := grid.get_tile(target.x, target.y)
	if current != 0 and not grid.registry.is_liquid(current):
		return
	if not MiningRules.in_reach(player.position, target):
		return
	var problem := Building.placement_problem(grid, target, kind, _player_positions())
	if not problem.is_empty():
		if not quiet:
			_message(player, problem, "aviso")
		return
	if not player.inventory.take_from(player.selected):
		return
	var changes: Array = []
	var door_top := grid.registry.id_of(TileRegistry.DOOR_TOP)
	for cell in Building.cells_for(grid, target, kind):
		var id := door_top if kind == Building.DOOR and cell != target else tile_id
		changes.append(world.set_tile(cell.x, cell.y, id))
	_dirty = true
	_emit(Events.BROADCAST, {"type": Events.TILE_CHANGED, "changes": changes})
	_send_inventory(player)


# ---------------------------------------------------------------- inventário e avisos


func _player_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for player in players.values():
		out.append(player.position)
	return out


func _give(player: PlayerState, id: String, qtd: int, durability: int = -1) -> void:
	player.inventory.add(id, qtd, durability)
	if not player.discoveries.has(id):
		player.discoveries[id] = true
		var material := data.get_material(id)
		var xp := int(material.get("xp_descoberta", 0))
		_emit(
			player.player_id,
			{"type": Events.DISCOVERED, "id": id, "nome": data.display_name(id), "xp": xp}
		)
		if xp > 0:
			_add_xp(player, str(material.get("maestria", "")), xp)
		# Material mítico desperta a escola ligada a ele (Pena de Ave-Trovão → Tempestária).
		var school := str(material.get("escola_afim", ""))
		if material.get("tier") == "mitico" and not school.is_empty():
			_awaken(player, school)
		# Cascata: um material raro revela as receitas secretas que dependem só dele.
		var revealed := Experiment.cascade(data, id, player.discoveries, player.known_recipes)
		for recipe_id in revealed:
			player.known_recipes[recipe_id] = true
			_message(
				player,
				(
					"Cascata: %s revelou a receita %s."
					% [data.display_name(id), data.get_recipe(recipe_id)["nome"]]
				),
				"descoberta"
			)
		if not revealed.is_empty():
			_send_mastery(player)


# ---------------------------------------------------------------- fabricação e maestria


func _craft(player: PlayerState, recipe_id: String, qtd: int) -> void:
	var recipe := data.get_recipe(recipe_id)
	if recipe.is_empty():
		return
	var stations := Crafting.stations_near(world.grid, data, player.position)
	var made := 0
	for n in clampi(qtd, 1, Crafting.MAX_QUEUE):
		if player.craft_queue.size() >= Crafting.MAX_QUEUE:
			_message(player, "A fila de produção está cheia.", "aviso")
			break
		var check := Crafting.status(
			recipe,
			data,
			player.inventory,
			player.mastery,
			player.known_recipes,
			stations,
			_context(player)
		)
		if not check["ok"]:
			if made == 0:
				_message(player, "%s: %s." % [recipe["nome"], check["motivo"]], "aviso")
			break
		for part in recipe["entradas"]:
			player.inventory.remove(part["id"], int(part["qtd"]))
		var area_xp := int(player.mastery.get(recipe["maestria"], 0))
		var seconds := Mastery.craft_seconds(float(recipe["tempo_s"]), area_xp)
		player.craft_queue.append(
			{"receita": recipe_id, "restante": seconds, "total": seconds, "avisado": false}
		)
		made += 1
	if made > 0:
		_dirty = true
		_send_inventory(player)
		_send_queue(player)


func _cancel_craft(player: PlayerState, index: int) -> void:
	if index < 0 or index >= player.craft_queue.size():
		return
	var job: Dictionary = player.craft_queue[index]
	var recipe := data.get_recipe(job["receita"])
	for part in recipe.get("entradas", []):
		var left := player.inventory.add(part["id"], int(part["qtd"]))
		if left > 0:
			_message(
				player,
				"Sem espaço: %d %s perdidos." % [left, data.display_name(part["id"])],
				"aviso"
			)
	player.craft_queue.remove_at(index)
	_send_inventory(player)
	_send_queue(player)


func _advance_crafting(player: PlayerState) -> void:
	var job: Dictionary = player.craft_queue[0]
	job["restante"] = maxf(float(job["restante"]) - TICK_INTERVAL, 0.0)
	if job["restante"] > 0.0:
		if tick % 5 == 0:
			_send_queue(player)
		return
	var recipe := data.get_recipe(job["receita"])
	for part in recipe["saidas"]:
		if not player.inventory.can_add(part["id"], int(part["qtd"])):
			if not job["avisado"]:
				job["avisado"] = true
				_message(
					player,
					"Inventário cheio: libere espaço para pegar %s." % recipe["nome"],
					"aviso"
				)
			return
	player.craft_queue.pop_front()
	var area_xp := int(player.mastery.get(recipe["maestria"], 0))
	for part in recipe["saidas"]:
		var durability := -1
		var base: Variant = data.get_item(part["id"]).get("durabilidade")
		if base != null:
			durability = Mastery.durability_for(int(base), area_xp)
		_give(player, part["id"], int(part["qtd"]), durability)
	_add_xp(player, recipe["maestria"], int(recipe["xp"]))
	_message(player, "Pronto: %s." % recipe["nome"], "pronto")
	_dirty = true
	_send_inventory(player)
	_send_queue(player)


func _add_xp(player: PlayerState, area: String, amount: int) -> void:
	if amount <= 0 or not area in Mastery.AREAS:
		return
	var before := int(player.mastery.get(area, 0))
	player.mastery[area] = before + amount
	var old_level := Mastery.level_for(before)
	var new_level := Mastery.level_for(before + amount)
	if new_level > old_level:
		_message(
			player, "%s subiu para o nível %d!" % [Mastery.display_name(area), new_level], "nivel"
		)
	_send_mastery(player)


func _send_mastery(player: PlayerState) -> void:
	_emit(
		player.player_id,
		{
			"type": Events.MASTERY,
			"xp": player.mastery.duplicate(),
			"receitas": player.known_recipes.keys(),
			"escolas": player.schools.keys(),
		}
	)


## Contexto para receitas com condição (`requer`): escolas do jogador e eventos ativos.
func _context(player: PlayerState) -> Dictionary:
	var events := {}
	if weather.storm:
		events["tempestade"] = true
	return {"escolas": player.schools, "eventos": events}


# ---------------------------------------------------------------- clima e Tempestária


func _step_weather() -> void:
	for happening in weather.step(TICK_INTERVAL):
		match happening:
			Weather.START:
				_on_storm_start()
			Weather.END:
				_emit(Events.BROADCAST, {"type": Events.WEATHER, "tempestade": false})
				_broadcast_message("A tempestade passou.", "info")
			Weather.BOLT:
				var column := _bolt_column()
				if column >= 0:
					_strike(column, 0)
			Weather.FEATHER:
				_drop_feather()


func _on_storm_start() -> void:
	_emit(Events.BROADCAST, {"type": Events.WEATHER, "tempestade": true})
	_broadcast_message("Uma tempestade se aproxima. Raios fundem a areia!", "aviso")


## Coluna para um raio natural: perto de um jogador, com preferência pela areia exposta.
func _bolt_column() -> int:
	if players.is_empty():
		return -1
	var grid := world.grid
	var list: Array = players.values()
	var center := WorldGrid.to_tile(list[weather.randi_range(0, list.size() - 1)].position)
	var best := -1
	var best_score := -1.0
	for i in 8:
		var x := clampi(
			center.x + weather.randi_range(-BOLT_SPREAD, BOLT_SPREAD), 1, grid.width - 2
		)
		var hit := _first_hit(x, 0)
		if hit < 0:
			continue
		var weight := BOLT_SAND_WEIGHT if grid.tile_name(x, hit) == "areia" else 1.0
		var score: float = weight * weather.randf()
		if score > best_score:
			best_score = score
			best = x
	return best


## Primeiro tile que não é ar nem água, descendo a partir de `from_y` na coluna x (-1 = nenhum).
func _first_hit(x: int, from_y: int) -> int:
	var grid := world.grid
	for y in range(maxi(from_y, 0), grid.height):
		var id := grid.get_tile(x, y)
		if id != 0 and not grid.registry.is_liquid(id):
			return y
	return -1


## Raio na coluna x a partir de from_y: funde areia em fulgurito (até 3 blocos para baixo).
func _strike(x: int, from_y: int) -> void:
	var grid := world.grid
	var hit := _first_hit(x, from_y)
	if hit < 0:
		return
	var changes: Array = []
	var fulgurite := grid.registry.id_of("fulgurito")
	var y := hit
	while y < hit + 3 and grid.tile_name(x, y) == "areia" and fulgurite >= 0:
		changes.append(world.set_tile(x, y, fulgurite))
		y += 1
	_emit(Events.BROADCAST, {"type": Events.LIGHTNING, "x": x, "y": hit, "de": from_y})
	if not changes.is_empty():
		_dirty = true
		_emit(Events.BROADCAST, {"type": Events.TILE_CHANGED, "changes": changes})


## Cai uma Pena de Ave-Trovão no chão, a alguns blocos de um jogador.
func _drop_feather() -> void:
	if players.is_empty():
		return
	var grid := world.grid
	var feather := grid.registry.id_of(TileRegistry.FEATHER)
	var list: Array = players.values()
	var center := WorldGrid.to_tile(list[weather.randi_range(0, list.size() - 1)].position)
	for i in 30:
		var side := 1 if weather.randf() < 0.5 else -1
		var x := clampi(center.x + side * weather.randi_range(5, 14), 1, grid.width - 2)
		var hit := _first_hit(x, 0)
		if hit <= 0 or not grid.is_solid(x, hit) or grid.get_tile(x, hit - 1) != 0:
			continue
		var change := world.set_tile(x, hit - 1, feather)
		_dirty = true
		_emit(Events.BROADCAST, {"type": Events.TILE_CHANGED, "changes": [change]})
		_emit(Events.BROADCAST, {"type": Events.LIGHTNING, "x": x, "y": hit - 1, "de": 0})
		_broadcast_message("Uma pena brilhante caiu do céu junto com um raio!", "descoberta")
		return


func _awaken(player: PlayerState, school: String) -> void:
	if player.schools.has(school):
		return
	player.schools[school] = true
	_dirty = true
	var name := Mastery.display_name(school)
	_message(player, "A %s despertou em você!" % name, "descoberta")
	if school == "tempestaria":
		_message(
			player,
			"Q invoca um raio onde você aponta. No ar, pule de novo: salto do vento.",
			"info"
		)
	_send_mastery(player)


## Magia: {"magia": "raio", "x", "y"}. Só quem despertou a Tempestária.
func _cast(player: PlayerState, command: Dictionary) -> void:
	if str(command.get("magia", "")) != "raio":
		return
	if not player.schools.has("tempestaria"):
		_message(player, "Você ainda não despertou a Tempestária.", "aviso")
		return
	if tick < player.cast_ready_tick:
		var wait := (player.cast_ready_tick - tick) * TICK_INTERVAL
		_message(player, "O raio ainda está carregando (%.1f s)." % wait, "aviso")
		return
	var target := Vector2i(int(command.get("x", -1)), int(command.get("y", -1)))
	if not world.grid.in_bounds(target.x, target.y):
		return
	var body := MiningRules.body_center(player.position)
	var aim := (Vector2(target) + Vector2(0.5, 0.5)) * WorldGrid.TILE_SIZE
	if body.distance_to(aim) > CAST_RANGE * WorldGrid.TILE_SIZE:
		_message(player, "Longe demais para o raio.", "aviso")
		return
	player.cast_ready_tick = tick + int(CAST_COOLDOWN * TICK_RATE)
	_strike(target.x, maxi(target.y - 1, 0))
	_add_xp(player, "arcano", 1)
	_emit(player.player_id, {"type": Events.CAST_COOLDOWN, "segundos": CAST_COOLDOWN})


func _broadcast_message(text: String, kind: String) -> void:
	_emit(Events.BROADCAST, {"type": Events.MESSAGE, "text": text, "kind": kind})


## Mistura sem receita: acerta (revela e faz 1), quase acerta (pista) ou erra (gasta 1 de cada).
func _experiment(player: PlayerState, command: Dictionary) -> void:
	var station := str(command.get("estacao", ""))
	var raw: Variant = command.get("itens", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var mix := {}
	for id in raw:
		mix[str(id)] = int(raw[id])
	var stations := Crafting.stations_near(world.grid, data, player.position)
	if not stations.has(station):
		_experiment_result(player, false, "Precisa de %s por perto." % data.display_name(station))
		return
	for id in mix:
		if player.inventory.count(id) < mix[id]:
			_experiment_result(player, false, "Você não tem %s suficiente." % data.display_name(id))
			return
	var result := Experiment.evaluate(
		data, mix, station, player.mastery, player.known_recipes, _context(player)
	)
	match result["tipo"]:
		"invalida":
			_experiment_result(player, false, result["texto"])
		"bloqueada":
			var name: String = data.get_recipe(result["receita"])["nome"]
			_experiment_result(
				player, false, "Existe uma receita aqui (%s), mas: %s." % [name, result["motivo"]]
			)
		"receita":
			var recipe_id: String = result["receita"]
			var recipe := data.get_recipe(recipe_id)
			if result["nova"]:
				player.known_recipes[recipe_id] = true
				_dirty = true
				_message(player, "Descoberta por experimento: %s!" % recipe["nome"], "descoberta")
				_add_xp(player, recipe["maestria"], int(recipe["xp"]) * 2)
				_send_mastery(player)
			_experiment_result(player, true, "Funcionou: %s." % recipe["nome"], recipe_id)
			_craft(player, recipe_id, 1)
		"falhou":
			for id in mix:
				player.inventory.remove(id, 1)
			_add_xp(player, Experiment.STATION_AREA.get(station, "quimica"), 1)
			_dirty = true
			_send_inventory(player)
			_experiment_result(player, false, result["texto"] + " (gastou 1 de cada material)")


func _experiment_result(player: PlayerState, ok: bool, text: String, recipe_id := "") -> void:
	var event := {"type": Events.EXPERIMENT_RESULT, "ok": ok, "texto": text}
	if not recipe_id.is_empty():
		event["receita"] = recipe_id
	_emit(player.player_id, event)


func _send_queue(player: PlayerState) -> void:
	var jobs: Array = []
	for job in player.craft_queue:
		jobs.append({"receita": job["receita"], "restante": job["restante"], "total": job["total"]})
	_emit(player.player_id, {"type": Events.CRAFT_QUEUE, "jobs": jobs})


func _send_inventory(player: PlayerState) -> void:
	_emit(
		player.player_id,
		{
			"type": Events.INVENTORY,
			"slots": player.inventory.to_array(),
			"selected": player.selected,
		}
	)


func _message(player: PlayerState, text: String, kind: String) -> void:
	_emit(player.player_id, {"type": Events.MESSAGE, "text": text, "kind": kind})


func _emit(peer_id: int, event: Dictionary) -> void:
	event_emitted.emit(peer_id, event)


static func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


## Opções da linha de comando: --mundo=nome, --semente=N, --novo.
static func _command_line() -> Dictionary:
	var options := {}
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if not arg.begins_with("--"):
			continue
		var parts := arg.trim_prefix("--").split("=", true, 1)
		if parts[0] in ["mundo", "semente", "novo"]:
			options[parts[0]] = parts[1] if parts.size() > 1 else true
	return options

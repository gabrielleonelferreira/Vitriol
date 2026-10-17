extends Node
## Servidor autoritativo do jogo (autoload "GameServer").
##
## No solo, roda no mesmo processo do cliente (servidor local). No multiplayer,
## o mesmo código roda num servidor dedicado. Regras:
##   1. Só o servidor altera o estado (mundo e jogadores).
##   2. Clientes enviam comandos (Commands) por um Transport.
##   3. O servidor responde com eventos (Events) pelo sinal event_emitted.
##   4. Comandos são processados em ticks fixos, na ordem em que chegaram.

signal event_emitted(peer_id: int, event: Dictionary)

const TICK_RATE := 20
const TICK_INTERVAL := 1.0 / TICK_RATE
## Semente do mundo solo até existir o menu de novo mundo (Onda 3, salvar/carregar).
const DEFAULT_SEED := 20261016
## Validação de movimento: velocidade máxima aceita (px/s) e folga (px) para atrasos.
const MAX_MOVE_SPEED := 620.0
const MOVE_SLACK := 24.0
## Tolerância (px) ao conferir se o personagem está dentro de um bloco.
const SOLID_TOLERANCE := 2.0

var world: WorldState = WorldState.new()
var data: DataStore
var players: Dictionary = {}
var tick: int = 0

var _pending: Array[Dictionary] = []
var _accumulator: float = 0.0
var _next_peer_id: int = 1
var _connected_peers: Dictionary = {}


func _ready() -> void:
	start(DEFAULT_SEED, GameData)


## Gera o mundo e deixa o servidor pronto para receber jogadores.
func start(
	world_seed: int,
	game_data: DataStore,
	width: int = WorldGenerator.DEFAULT_WIDTH,
	height: int = WorldGenerator.DEFAULT_HEIGHT
) -> void:
	data = game_data
	world = WorldState.new(world_seed)
	if not data.loaded:
		push_error("GameServer: dados de jogo não carregados; o mundo não foi gerado.")
		return
	var started := Time.get_ticks_msec()
	world.generate(data, width, height)
	print(
		(
			"GameServer: mundo %dx%d gerado em %d ms (semente %d)"
			% [width, height, Time.get_ticks_msec() - started, world_seed]
		)
	)


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
		players.erase(peer_id)
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
	world.step(tick)


func _physics_process(delta: float) -> void:
	_accumulator += delta
	while _accumulator >= TICK_INTERVAL:
		_accumulator -= TICK_INTERVAL
		step_once()


func _handle(peer_id: int, command: Dictionary) -> void:
	match command.get("type", ""):
		Commands.JOIN:
			_join(peer_id, str(command.get("name", "Alquimista")))
		Commands.LEAVE:
			disconnect_peer(peer_id)
		Commands.PING:
			_emit(peer_id, {"type": Events.PONG, "tick": tick})
		Commands.MOVE:
			_move(peer_id, command)
		_:
			_emit(peer_id, {"type": Events.ERROR, "reason": "comando desconhecido"})


func _join(peer_id: int, display_name: String) -> void:
	if players.has(peer_id):
		_emit(peer_id, {"type": Events.ERROR, "reason": "jogador já conectado"})
		return
	if not world.is_ready():
		_emit(peer_id, {"type": Events.ERROR, "reason": "mundo não está pronto"})
		return
	var player := PlayerState.new(peer_id, display_name)
	player.position = world.grid.spawn_position()
	player.last_move_tick = tick
	players[peer_id] = player
	_emit(peer_id, {"type": Events.WORLD_SNAPSHOT, "grid": world.grid.to_snapshot()})
	_emit(
		peer_id,
		{
			"type": Events.JOINED,
			"player_id": peer_id,
			"player": player.to_dict(),
			"world": world.to_dict(),
			"tick": tick,
		}
	)


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


func _emit(peer_id: int, event: Dictionary) -> void:
	event_emitted.emit(peer_id, event)

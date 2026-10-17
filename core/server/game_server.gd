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


func _emit(peer_id: int, event: Dictionary) -> void:
	event_emitted.emit(peer_id, event)

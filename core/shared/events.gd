class_name Events
extends RefCounted
## Eventos que o servidor envia aos clientes.

const JOINED := "joined"
const WORLD_SNAPSHOT := "world_snapshot"
const PLAYER_LEFT := "player_left"
## Outro jogador se moveu: {"player_id", "position", "velocity", "facing", "held"}
const PLAYER_MOVED := "player_moved"
## O servidor recusou a posição enviada e manda a última válida: {"position": [x, y]}
const CORRECTION := "correction"
const PONG := "pong"
const ERROR := "error"
## Tiles mudaram: {"changes": [[x, y, nome_do_tile], ...]}
const TILE_CHANGED := "tile_changed"
## Inventário do próprio jogador: {"slots": [...], "selected": int}
const INVENTORY := "inventory"
## Progresso da mineração do próprio jogador: {"x", "y", "progress": 0..1} (-1 = parou)
const MINE_PROGRESS := "mine_progress"
## Aviso para mostrar na tela: {"text", "kind": "info" | "aviso" | "descoberta"}
const MESSAGE := "message"
## Material ou item descoberto pela primeira vez: {"id", "nome", "xp"}
const DISCOVERED := "discovered"
## Hora do dia: {"time": 0..1}
const TIME := "time"

## peer_id usado para enviar um evento a todos os clientes conectados.
const BROADCAST := 0

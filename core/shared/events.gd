class_name Events
extends RefCounted
## Eventos que o servidor envia aos clientes.

const JOINED := "joined"
const WORLD_SNAPSHOT := "world_snapshot"
const PLAYER_LEFT := "player_left"
## Outro jogador se moveu: {"player_id", "position", "velocity", "facing"}
const PLAYER_MOVED := "player_moved"
## O servidor recusou a posição enviada e manda a última válida: {"position": [x, y]}
const CORRECTION := "correction"
const PONG := "pong"
const ERROR := "error"

## peer_id usado para enviar um evento a todos os clientes conectados.
const BROADCAST := 0

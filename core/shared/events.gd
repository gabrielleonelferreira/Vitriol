class_name Events
extends RefCounted
## Eventos que o servidor envia aos clientes.

const JOINED := "joined"
const WORLD_SNAPSHOT := "world_snapshot"
const PLAYER_LEFT := "player_left"
const PONG := "pong"
const ERROR := "error"

## peer_id usado para enviar um evento a todos os clientes conectados.
const BROADCAST := 0

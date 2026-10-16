class_name Commands
extends RefCounted
## Comandos que um cliente pode enviar ao servidor.
## O cliente nunca altera o estado do jogo: ele pede, e o servidor decide.

const JOIN := "join"
const LEAVE := "leave"
const PING := "ping"

class_name Commands
extends RefCounted
## Comandos que um cliente pode enviar ao servidor.
## O cliente nunca altera o estado do jogo: ele pede, e o servidor decide.

const JOIN := "join"
const LEAVE := "leave"
const PING := "ping"
## Posição do próprio personagem: {"position": [x, y], "velocity": [x, y], "facing": 1}
const MOVE := "move"
## Começa ou continua a minerar um tile: {"x", "y"}. Repetir enquanto o botão estiver apertado.
const MINE := "mine"
## Soltou o botão de minerar.
const MINE_STOP := "mine_stop"
## Coloca o item selecionado num tile: {"x", "y"}
const PLACE := "place"
## Escolhe o espaço da barra de atalhos: {"index": 0..9}
const SELECT_SLOT := "select_slot"
## Troca dois espaços do inventário: {"a", "b"}
const SWAP_SLOTS := "swap_slots"
## Fabrica uma receita: {"receita": id, "qtd": 1..20}. Entra na fila de produção.
const CRAFT := "craft"
## Cancela um trabalho da fila e devolve os materiais: {"index": int}
const CRAFT_CANCEL := "craft_cancel"
## Só em versão de desenvolvimento: dá um kit de teste (picaretas e tochas).
const DEBUG_KIT := "debug_kit"

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
## Aviso para mostrar na tela: {"text", "kind"}.
## kind: "info" | "aviso" | "descoberta" | "nivel" (subiu de nível) | "pronto" (fabricação)
const MESSAGE := "message"
## Material ou item descoberto pela primeira vez: {"id", "nome", "xp"}
const DISCOVERED := "discovered"
## Fila de fabricação do próprio jogador: {"jobs": [{"receita", "restante", "total"}]}
const CRAFT_QUEUE := "craft_queue"
## XP de maestria, receitas descobertas e escolas despertas do próprio jogador:
## {"xp": {area: int}, "receitas": [id], "escolas": [id]}
const MASTERY := "mastery"
## Resultado de um experimento: {"ok": bool, "texto": String, "receita"?: id}
const EXPERIMENT_RESULT := "experiment_result"
## Clima: {"tempestade": bool}
const WEATHER := "weather"
## Raio caiu: {"x", "y" (tile atingido), "de" (linha de onde saiu; 0 = céu)}
const LIGHTNING := "lightning"
## Magia usada; espera até a próxima: {"segundos": float}
const CAST_COOLDOWN := "cast_cooldown"
## Hora do dia: {"time": 0..1}
const TIME := "time"

## peer_id usado para enviar um evento a todos os clientes conectados.
const BROADCAST := 0

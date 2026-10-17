class_name PlayerState
extends RefCounted
## Estado autoritativo de um jogador conectado. Posição em pixels (pés do personagem).

var player_id: int = 0
var display_name: String = ""
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var facing: int = 1
## Tick do servidor em que a posição foi aceita pela última vez.
var last_move_tick: int = 0
var inventory: Inventory
## Espaço da barra de atalhos em uso (0 a 9).
var selected: int = 0
## Materiais e itens já descobertos (id -> true).
var discoveries: Dictionary = {}
## XP por área de maestria (metalurgia, química...).
var mastery: Dictionary = {}
## Receitas secretas já descobertas (id -> true). Preenchido na Onda 5 (tentativa e erro).
var known_recipes: Dictionary = {}
## Fila de fabricação: [{"receita": id, "restante": s, "total": s, "avisado": bool}]
var craft_queue: Array[Dictionary] = []
## Mineração em andamento.
var mining_active: bool = false
var mining_target: Vector2i = Vector2i(-1, -1)
var mining_progress: float = 0.0


func _init(new_id: int, new_name: String, data: DataStore = null) -> void:
	player_id = new_id
	display_name = new_name
	if data != null:
		inventory = Inventory.new(data)


func selected_item() -> Dictionary:
	return inventory.get_slot(selected) if inventory else {}


## Dados públicos, repassados aos outros jogadores.
func to_dict() -> Dictionary:
	var held: Dictionary = selected_item()
	return {
		"player_id": player_id,
		"display_name": display_name,
		"position": [position.x, position.y],
		"velocity": [velocity.x, velocity.y],
		"facing": facing,
		"held": held.get("id", ""),
	}


func to_save() -> Dictionary:
	return {
		"nome": display_name,
		"posicao": [position.x, position.y],
		"inventario": inventory.to_array(),
		"selecionado": selected,
		"descobertas": discoveries.keys(),
		"maestria": mastery.duplicate(),
		"receitas_conhecidas": known_recipes.keys(),
		"fila": _queue_for_save(),
	}


func _queue_for_save() -> Array:
	var out: Array = []
	for job in craft_queue:
		out.append({"receita": job["receita"], "restante": job["restante"], "total": job["total"]})
	return out


func load_save(saved: Dictionary) -> void:
	var pos: Array = saved.get("posicao", [position.x, position.y])
	position = Vector2(float(pos[0]), float(pos[1]))
	inventory.load_array(saved.get("inventario", []))
	selected = clampi(int(saved.get("selecionado", 0)), 0, Inventory.HOTBAR - 1)
	discoveries.clear()
	for id in saved.get("descobertas", []):
		discoveries[str(id)] = true
	mastery.clear()
	var saved_mastery: Dictionary = saved.get("maestria", {})
	for area in saved_mastery:
		mastery[str(area)] = int(saved_mastery[area])
	known_recipes.clear()
	for id in saved.get("receitas_conhecidas", []):
		known_recipes[str(id)] = true
	craft_queue.clear()
	for job in saved.get("fila", []):
		(
			craft_queue
			. append(
				{
					"receita": str(job["receita"]),
					"restante": float(job["restante"]),
					"total": float(job["total"]),
					"avisado": false,
				}
			)
		)

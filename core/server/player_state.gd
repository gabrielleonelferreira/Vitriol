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
	}


func load_save(saved: Dictionary) -> void:
	var pos: Array = saved.get("posicao", [position.x, position.y])
	position = Vector2(float(pos[0]), float(pos[1]))
	inventory.load_array(saved.get("inventario", []))
	selected = clampi(int(saved.get("selecionado", 0)), 0, Inventory.HOTBAR - 1)
	discoveries.clear()
	for id in saved.get("descobertas", []):
		discoveries[str(id)] = true

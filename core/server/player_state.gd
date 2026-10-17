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


func _init(new_id: int, new_name: String) -> void:
	player_id = new_id
	display_name = new_name


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"position": [position.x, position.y],
		"velocity": [velocity.x, velocity.y],
		"facing": facing,
	}

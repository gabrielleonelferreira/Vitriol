class_name PlayerState
extends RefCounted
## Estado autoritativo de um jogador conectado.

var player_id: int = 0
var display_name: String = ""
var tile_position: Vector2i = Vector2i.ZERO


func _init(new_id: int, new_name: String) -> void:
	player_id = new_id
	display_name = new_name


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"tile_position": [tile_position.x, tile_position.y],
	}

class_name WorldState
extends RefCounted
## Estado autoritativo do mundo. Só o GameServer altera este objeto.
## A geração do mundo em tiles chega na Onda 2 (tarefa 2A, pasta world/).

var world_seed: int = 0


func _init(new_seed: int = 0) -> void:
	world_seed = new_seed


## Avança a simulação do mundo em um tick do servidor.
func step(_tick: int) -> void:
	pass


## Estado serializável, usado por salvar/carregar (Onda 3, tarefa 3D).
func to_dict() -> Dictionary:
	return {"world_seed": world_seed}

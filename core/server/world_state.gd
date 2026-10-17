class_name WorldState
extends RefCounted
## Estado autoritativo do mundo. Só o GameServer altera este objeto.

var world_seed: int = 0
var grid: WorldGrid


func _init(new_seed: int = 0) -> void:
	world_seed = new_seed


## Gera o mundo. `width` e `height` menores servem para testes rápidos.
func generate(
	data: DataStore,
	width: int = WorldGenerator.DEFAULT_WIDTH,
	height: int = WorldGenerator.DEFAULT_HEIGHT
) -> void:
	grid = WorldGenerator.new().generate(world_seed, data, width, height)


func is_ready() -> bool:
	return grid != null


## Avança a simulação do mundo em um tick do servidor.
func step(_tick: int) -> void:
	pass


## Estado serializável, usado por salvar/carregar (Onda 3, tarefa 3D).
func to_dict() -> Dictionary:
	return {"world_seed": world_seed}

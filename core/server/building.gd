class_name Building
extends RefCounted
## Regras de construção: onde um bloco, objeto ou estação pode ser colocado.

const BLOCK := "bloco"
const OBJECT := "objeto"
const STATION := "estacao"


## "" se pode colocar; senão, o motivo (para mostrar ao jogador).
static func placement_problem(
	grid: WorldGrid, target: Vector2i, kind: String, player_feet: Array[Vector2]
) -> String:
	var x := target.x
	var y := target.y
	match kind:
		STATION:
			if not grid.is_solid(x, y + 1):
				return "Estações precisam de chão firme embaixo."
		OBJECT:
			var held := (
				grid.is_solid(x, y + 1)
				or grid.is_solid(x - 1, y)
				or grid.is_solid(x + 1, y)
				or grid.get_wall(x, y) != 0
			)
			if not held:
				return "Precisa de um apoio: chão, parede ou bloco ao lado."
		BLOCK:
			var attached := (
				grid.is_solid(x, y + 1)
				or grid.is_solid(x, y - 1)
				or grid.is_solid(x - 1, y)
				or grid.is_solid(x + 1, y)
				or grid.get_wall(x, y) != 0
			)
			if not attached:
				return "Blocos precisam encostar em outro bloco ou numa parede."
			for feet in player_feet:
				if _overlaps(feet, target):
					return "Tem alguém nesse lugar."
	return ""


## A caixa de colisão de um jogador ocupa este tile?
static func _overlaps(feet: Vector2, tile: Vector2i) -> bool:
	var half := PlayerMotor.HITBOX.x / 2.0
	var body := Rect2(feet.x - half, feet.y - PlayerMotor.HITBOX.y, PlayerMotor.HITBOX.x, PlayerMotor.HITBOX.y)
	var cell := Rect2(Vector2(tile * WorldGrid.TILE_SIZE), Vector2.ONE * WorldGrid.TILE_SIZE)
	return body.intersects(cell)

class_name Building
extends RefCounted
## Regras de construção: onde um bloco, objeto ou estação pode ser colocado.

const BLOCK := "bloco"
const OBJECT := "objeto"
const STATION := "estacao"
const DOOR := "porta"
const PLATFORM := "plataforma"
const LADDER := "escada"
const ROPE := "corda"
## Quantos blocos um rolo de corda desenrola para baixo.
const ROPE_LENGTH := 20


## Que tipo de coisa este item vira quando colocado no mundo ("" = não se coloca).
static func kind_for(data: DataStore, item_id: String) -> String:
	var item: Dictionary = data.items.get(item_id, {})
	if item.get("tipo") == "objeto":
		var form: Variant = item.get("forma")
		return str(form) if form != null else OBJECT
	if item.get("tipo") == "estacao" and item_id != "mao":
		return STATION
	if data.is_block(item_id):
		return BLOCK
	return ""


## "" se pode colocar; senão, o motivo (para mostrar ao jogador).
static func placement_problem(
	grid: WorldGrid, target: Vector2i, kind: String, player_feet: Array[Vector2]
) -> String:
	var x := target.x
	var y := target.y
	var reg := grid.registry
	match kind:
		STATION:
			if not grid.is_solid(x, y + 1):
				return "Estações precisam de chão firme embaixo."
		OBJECT:
			var held := (
				grid.is_solid(x, y + 1)
				or _anchor(grid, x - 1, y)
				or _anchor(grid, x + 1, y)
				or grid.get_wall(x, y) != 0
			)
			if not held:
				return "Precisa de um apoio: chão, parede ou bloco ao lado."
		DOOR:
			if not grid.is_solid(x, y + 1):
				return "A porta precisa de chão firme embaixo."
			if not _free(grid, x, y - 1):
				return "A porta tem 2 blocos de altura: falta espaço em cima."
		PLATFORM:
			var held := (
				_anchor(grid, x - 1, y)
				or _anchor(grid, x + 1, y)
				or reg.is_platform(grid.get_tile(x - 1, y))
				or reg.is_platform(grid.get_tile(x + 1, y))
				or reg.is_climbable(grid.get_tile(x - 1, y))
				or reg.is_climbable(grid.get_tile(x + 1, y))
				or _anchor(grid, x, y + 1)
				or grid.get_wall(x, y) != 0
			)
			if not held:
				return "Plataformas precisam encostar num bloco, parede ou outra plataforma."
		LADDER:
			var held := (
				_anchor(grid, x, y + 1)
				or _anchor(grid, x, y - 1)
				or _anchor(grid, x - 1, y)
				or _anchor(grid, x + 1, y)
				or reg.is_climbable(grid.get_tile(x, y + 1))
				or reg.is_climbable(grid.get_tile(x, y - 1))
				or grid.get_wall(x, y) != 0
			)
			if not held:
				return "A escada precisa de apoio: chão, parede, bloco ou outra escada."
		ROPE:
			var hung := (
				_anchor(grid, x, y - 1)
				or reg.is_climbable(grid.get_tile(x, y - 1))
				or reg.is_platform(grid.get_tile(x, y - 1))
				or _anchor(grid, x - 1, y)
				or _anchor(grid, x + 1, y)
			)
			if not hung:
				return "Prenda a corda no teto, numa beirada ou no fim de outra corda."
		BLOCK:
			var attached := (
				_anchor(grid, x, y + 1)
				or _anchor(grid, x, y - 1)
				or _anchor(grid, x - 1, y)
				or _anchor(grid, x + 1, y)
				or grid.get_wall(x, y) != 0
			)
			if not attached:
				return "Blocos precisam encostar em outro bloco ou numa parede."
			for feet in player_feet:
				if _overlaps(feet, target):
					return "Tem alguém nesse lugar."
	return ""


## Tiles que a peça ocupa ao ser colocada em `target` (porta: 2; corda: até o chão).
static func cells_for(grid: WorldGrid, target: Vector2i, kind: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [target]
	if kind == DOOR:
		cells.append(target + Vector2i(0, -1))
	elif kind == ROPE:
		var y := target.y + 1
		while cells.size() < ROPE_LENGTH and _free(grid, target.x, y):
			cells.append(Vector2i(target.x, y))
			y += 1
	return cells


## Peça inteira a que este tile pertence (as duas metades da porta, a corda inteira).
static func piece_from(grid: WorldGrid, cell: Vector2i) -> Array[Vector2i]:
	var reg := grid.registry
	var id := grid.get_tile(cell.x, cell.y)
	var name := reg.name_of(id)
	var cells: Array[Vector2i] = [cell]
	if name == "porta":
		if reg.name_of(grid.get_tile(cell.x, cell.y - 1)) == TileRegistry.DOOR_TOP:
			cells.append(cell + Vector2i(0, -1))
	elif name == TileRegistry.DOOR_TOP:
		if reg.name_of(grid.get_tile(cell.x, cell.y + 1)) == "porta":
			cells.append(cell + Vector2i(0, 1))
	elif name == "corda":
		var y := cell.y - 1
		while reg.name_of(grid.get_tile(cell.x, y)) == "corda":
			cells.append(Vector2i(cell.x, y))
			y -= 1
		y = cell.y + 1
		while reg.name_of(grid.get_tile(cell.x, y)) == "corda":
			cells.append(Vector2i(cell.x, y))
			y += 1
	return cells


## Quantos itens a peça devolve ao ser desmontada.
static func refund_for(grid: WorldGrid, cells: Array[Vector2i]) -> Dictionary:
	if cells.is_empty():
		return {}
	var name := grid.registry.name_of(grid.get_tile(cells[0].x, cells[0].y))
	if name == "porta" or name == TileRegistry.DOOR_TOP:
		return {"porta": 1}
	if name == "corda":
		return {"corda": ceili(cells.size() / float(ROPE_LENGTH))}
	return {}


static func _free(grid: WorldGrid, x: int, y: int) -> bool:
	if not grid.in_bounds(x, y):
		return false
	var id := grid.get_tile(x, y)
	return id == 0 or grid.registry.is_liquid(id)


## Segura uma peça ao lado: bloco sólido ou porta (dá para fazer parede em volta da porta).
static func _anchor(grid: WorldGrid, x: int, y: int) -> bool:
	return grid.is_solid(x, y) or grid.registry.is_door(grid.get_tile(x, y))


## A caixa de colisão de um jogador ocupa este tile?
static func _overlaps(feet: Vector2, tile: Vector2i) -> bool:
	var half := PlayerMotor.HITBOX.x / 2.0
	var body := Rect2(
		feet.x - half, feet.y - PlayerMotor.HITBOX.y, PlayerMotor.HITBOX.x, PlayerMotor.HITBOX.y
	)
	var cell := Rect2(Vector2(tile * WorldGrid.TILE_SIZE), Vector2.ONE * WorldGrid.TILE_SIZE)
	return body.intersects(cell)

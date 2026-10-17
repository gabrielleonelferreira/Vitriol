class_name PlayerMotor
extends RefCounted
## Física do personagem contra a grade de tiles, sem depender de cena ou de tela.
## O cliente usa para mover o jogador; o servidor usa para validar posições.
##
## `position` é o ponto dos pés: centro da base da caixa de colisão, em pixels.

const TILE := WorldGrid.TILE_SIZE
## Caixa de colisão (largura, altura) em pixels. Cabe num túnel de 2 tiles.
const HITBOX := Vector2(10, 28)

const RUN_SPEED := 96.0
const GROUND_ACCEL := 1100.0
const AIR_ACCEL := 700.0
const GROUND_FRICTION := 1400.0
const GRAVITY := 980.0
## Gravidade extra quando o botão de pulo é solto na subida (pulo mais baixo).
const RELEASE_GRAVITY_SCALE := 2.4
const JUMP_SPEED := 310.0
const MAX_FALL := 560.0
## Tempo para ainda pular depois de sair da beirada, e para guardar um pulo apertado cedo.
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
## Na água: gravidade menor, queda lenta e braçadas para cima.
const WATER_GRAVITY_SCALE := 0.3
const WATER_MAX_FALL := 70.0
const WATER_SPEED_SCALE := 0.6
const SWIM_SPEED := 150.0
## Maior deslocamento por sub-passo, para nunca atravessar um tile.
const MAX_SUBSTEP := 6.0
## Escada e corda: velocidade de subida/descida e de lado enquanto pendurado.
const CLIMB_SPEED := 90.0
const CLIMB_SIDE_SPEED := 45.0
## Tempo ignorando plataformas depois de apertar para baixo (para cair através delas).
const DROP_TIME := 0.22
## Força do salto do vento em relação ao pulo normal.
const AIR_JUMP_SCALE := 0.85

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var on_floor: bool = false
var in_water: bool = false
var facing: int = 1
var climbing: bool = false
## Pulos extras no ar (salto do vento da Tempestária = 1).
var air_jumps: int = 0
## Acabou de dar um salto no ar (para o personagem mostrar o vento).
var air_jumped: bool = false

var _coyote: float = 0.0
var _buffer: float = 0.0
var _drop: float = 0.0
var _air_left: int = 0


## Avança a física. `move` vai de -1 (esquerda) a 1 (direita); pular também sobe escadas e
## `down_held` (S ou ↓) desce escadas e atravessa plataformas.
func step(
	move: float,
	jump_pressed: bool,
	jump_held: bool,
	delta: float,
	grid: WorldGrid,
	down_held: bool = false
) -> void:
	in_water = _overlaps_liquid(grid)
	if jump_pressed:
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(_buffer - delta, 0.0)
	_coyote = COYOTE_TIME if on_floor else maxf(_coyote - delta, 0.0)
	_drop = maxf(_drop - delta, 0.0)
	air_jumped = false
	if on_floor or climbing or in_water:
		_air_left = air_jumps

	var on_climbable := overlaps_climbable(grid, position)
	if climbing and not on_climbable:
		climbing = false
	if not climbing and on_climbable and (jump_held or down_held):
		climbing = true
		_buffer = 0.0
	if down_held and on_floor and not climbing:
		if _standing_on_climb_top(grid):
			climbing = true
			position.y += 1.0
		elif _standing_on_one_way(grid):
			_drop = DROP_TIME
			on_floor = false

	if climbing:
		velocity.x = clampf(move, -1.0, 1.0) * CLIMB_SIDE_SPEED
		if absf(move) > 0.01:
			facing = 1 if move > 0 else -1
		velocity.y = -CLIMB_SPEED if jump_held else (CLIMB_SPEED if down_held else 0.0)
	else:
		_horizontal(move, delta)
		_vertical(jump_held, delta)

	var motion := velocity * delta
	var steps := maxi(1, ceili(motion.length() / MAX_SUBSTEP))
	var part := motion / steps
	for i in steps:
		_move_x(part.x, grid)
		_move_y(part.y, grid)
	on_floor = _touching_floor(grid)


func _horizontal(move: float, delta: float) -> void:
	var top_speed := RUN_SPEED * (WATER_SPEED_SCALE if in_water else 1.0)
	var target := clampf(move, -1.0, 1.0) * top_speed
	if absf(move) > 0.01:
		facing = 1 if move > 0 else -1
		var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
		velocity.x = move_toward(velocity.x, target, accel * delta)
	else:
		var friction := GROUND_FRICTION if on_floor else AIR_ACCEL * 0.5
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _vertical(jump_held: bool, delta: float) -> void:
	if in_water:
		velocity.y += GRAVITY * WATER_GRAVITY_SCALE * delta
		if _buffer > 0.0 or jump_held:
			velocity.y = minf(velocity.y, -SWIM_SPEED * (1.0 if _buffer > 0.0 else 0.6))
			_buffer = 0.0
		velocity.y = minf(velocity.y, WATER_MAX_FALL)
		return
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -JUMP_SPEED
		_buffer = 0.0
		_coyote = 0.0
		on_floor = false
	elif _buffer > 0.0 and _air_left > 0 and not on_floor:
		velocity.y = -JUMP_SPEED * AIR_JUMP_SCALE
		_buffer = 0.0
		_air_left -= 1
		air_jumped = true
	var gravity := GRAVITY
	if velocity.y < 0.0 and not jump_held:
		gravity *= RELEASE_GRAVITY_SCALE
	velocity.y = minf(velocity.y + gravity * delta, MAX_FALL)


func _move_x(dx: float, grid: WorldGrid) -> void:
	if dx == 0.0:
		return
	position.x += dx
	if not overlaps_solid(grid, position):
		return
	# Degrau de 1 tile: sobe se houver espaço logo acima.
	if on_floor:
		var lifted := Vector2(position.x, floorf((position.y - 1.0) / TILE) * TILE)
		if position.y - lifted.y <= TILE and not overlaps_solid(grid, lifted):
			position = lifted
			return
	var half := HITBOX.x / 2.0
	if dx > 0.0:
		var column := floori((position.x + half - 0.001) / TILE)
		position.x = column * TILE - half
	else:
		var column := floori((position.x - half) / TILE)
		position.x = (column + 1) * TILE + half
	velocity.x = 0.0


func _move_y(dy: float, grid: WorldGrid) -> void:
	if dy == 0.0:
		return
	var before := position.y
	position.y += dy
	if not overlaps_solid(grid, position):
		# Plataforma e topo de escada seguram só quem cai de cima.
		if dy > 0.0 and not climbing and _drop <= 0.0:
			var row := floori((position.y - 0.001) / TILE)
			if before <= row * TILE + 0.001 and _one_way_under(grid, position.x, row):
				position.y = row * TILE
				on_floor = true
				velocity.y = 0.0
		return
	if dy > 0.0:
		var row := floori((position.y - 0.001) / TILE)
		position.y = row * TILE
		on_floor = true
	else:
		var row := floori((position.y - HITBOX.y) / TILE)
		position.y = (row + 1) * TILE + HITBOX.y
	velocity.y = 0.0


func _touching_floor(grid: WorldGrid) -> bool:
	if climbing:
		return false
	if overlaps_solid(grid, position + Vector2(0, 1)):
		return true
	return _drop <= 0.0 and _standing_on_one_way(grid)


## Os pés estão exatamente no topo de uma plataforma (ou do topo de uma escada)?
func _standing_on_one_way(grid: WorldGrid) -> bool:
	var row := roundi(position.y / TILE)
	if absf(position.y - row * TILE) > 0.01:
		return false
	return _one_way_under(grid, position.x, row)


func _standing_on_climb_top(grid: WorldGrid) -> bool:
	var row := roundi(position.y / TILE)
	if absf(position.y - row * TILE) > 0.01:
		return false
	return grid.registry.is_climbable(grid.get_tile(floori(position.x / TILE), row))


## Algum tile embaixo dos pés, na linha `row`, segura por cima?
static func _one_way_under(grid: WorldGrid, feet_x: float, row: int) -> bool:
	var half := HITBOX.x / 2.0
	var left := floori((feet_x - half) / TILE)
	var right := floori((feet_x + half - 0.001) / TILE)
	for tx in range(left, right + 1):
		if is_one_way(grid, tx, row):
			return true
	return false


## Plataforma, ou o degrau mais alto de uma escada/corda (o que tem algo não escalável em cima).
static func is_one_way(grid: WorldGrid, x: int, y: int) -> bool:
	var id := grid.get_tile(x, y)
	if grid.registry.is_platform(id):
		return true
	return (
		grid.registry.is_climbable(id) and not grid.registry.is_climbable(grid.get_tile(x, y - 1))
	)


## O meio do corpo encosta numa escada ou corda?
static func overlaps_climbable(grid: WorldGrid, feet: Vector2) -> bool:
	var column := floori(feet.x / TILE)
	var top := floori((feet.y - HITBOX.y + 2.0) / TILE)
	var bottom := floori((feet.y - 0.001) / TILE)
	for ty in range(top, bottom + 1):
		if grid.registry.is_climbable(grid.get_tile(column, ty)):
			return true
	return false


func _overlaps_liquid(grid: WorldGrid) -> bool:
	var center := WorldGrid.to_tile(position - Vector2(0, HITBOX.y * 0.5))
	return grid.registry.is_liquid(grid.get_tile(center.x, center.y))


## A caixa de colisão com os pés em `feet` encosta em algum tile sólido?
## `shrink` reduz a caixa (tolerância usada pelo servidor).
static func overlaps_solid(grid: WorldGrid, feet: Vector2, shrink: float = 0.0) -> bool:
	var half := HITBOX.x / 2.0 - shrink
	var left := floori((feet.x - half) / TILE)
	var right := floori((feet.x + half - 0.001) / TILE)
	var top := floori((feet.y - HITBOX.y + shrink) / TILE)
	var bottom := floori((feet.y - shrink - 0.001) / TILE)
	for ty in range(top, bottom + 1):
		for tx in range(left, right + 1):
			if grid.is_solid(tx, ty):
				return true
	return false

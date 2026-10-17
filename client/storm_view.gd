class_name StormView
extends Node2D
## Tempestade na tela: chuva em volta da câmera, raios desenhados do céu até o chão e o clarão.
## Só aparência; quem decide onde o raio cai é o servidor.

## Quanto o céu escurece com a tempestade (0 a 1).
const DARKEN := 0.45
## Duração do raio na tela e do clarão (s).
const BOLT_TIME := 0.22
const FLASH_TIME := 0.35
const BOLT_COLOR := Color("c8f0ff")
const BOLT_CORE := Color("f7f6f0")

## 0 = céu limpo, 1 = tempestade plena (sobe e desce devagar).
var amount: float = 0.0
## Clarão atual (0 a 1), somado à luz do dia pelo cliente.
var flash: float = 0.0
var _target: float = 0.0
var _rain := CPUParticles2D.new()
var _bolts: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# A chuva passa atrás dos blocos (some ao bater no chão) e por baixo da luz (escurece à noite).
	z_index = -1
	var drop := Image.create(1, 5, false, Image.FORMAT_RGBA8)
	for y in 5:
		drop.set_pixel(0, y, Color(0.62, 0.83, 0.94, 0.25 + 0.15 * y))
	_rain.texture = ImageTexture.create_from_image(drop)
	_rain.amount = 360
	_rain.lifetime = 0.9
	_rain.preprocess = 0.9
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(380, 4)
	_rain.direction = Vector2(-0.18, 1.0)
	_rain.spread = 2.0
	_rain.gravity = Vector2(0, 260)
	_rain.initial_velocity_min = 380.0
	_rain.initial_velocity_max = 460.0
	_rain.emitting = false
	_rain.local_coords = false
	_rain.name = "Chuva"
	add_child(_rain)


func set_storm(on: bool) -> void:
	_target = 1.0 if on else 0.0


## Um raio do céu (from_y em pixels) até o tile atingido.
func bolt(x_tile: int, hit_tile_y: int, from_y: float) -> void:
	var bottom := Vector2((x_tile + 0.5) * WorldGrid.TILE_SIZE, hit_tile_y * WorldGrid.TILE_SIZE)
	var points := PackedVector2Array()
	var y := from_y
	var x := bottom.x + _rng.randf_range(-40.0, 40.0)
	while y < bottom.y:
		points.append(Vector2(x, y))
		y += _rng.randf_range(10.0, 22.0)
		var pull := (bottom.x - x) * 0.25
		x += pull + _rng.randf_range(-9.0, 9.0)
	points.append(bottom)
	var outer := Line2D.new()
	outer.points = points
	outer.width = 3.0
	outer.default_color = BOLT_COLOR
	outer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	outer.z_as_relative = false
	outer.z_index = 60
	add_child(outer)
	var inner := Line2D.new()
	inner.points = points
	inner.width = 1.0
	inner.default_color = BOLT_CORE
	inner.z_as_relative = false
	inner.z_index = 61
	add_child(inner)
	_bolts.append({"lines": [outer, inner], "time": BOLT_TIME})
	flash = 1.0


## Chamado todo quadro: segue a câmera e esconde a chuva no subsolo.
func update(delta: float, camera_center: Vector2, underground: bool) -> void:
	amount = move_toward(amount, _target, delta / 4.0)
	flash = maxf(flash - delta / FLASH_TIME, 0.0)
	_rain.position = camera_center + Vector2(40, -210)
	_rain.emitting = amount > 0.3 and not underground
	_rain.modulate.a = clampf(amount, 0.0, 1.0)
	for i in range(_bolts.size() - 1, -1, -1):
		var entry: Dictionary = _bolts[i]
		entry["time"] -= delta
		var fade := clampf(entry["time"] / BOLT_TIME, 0.0, 1.0)
		for line in entry["lines"]:
			line.modulate.a = fade
		if entry["time"] <= 0.0:
			for line in entry["lines"]:
				line.queue_free()
			_bolts.remove_at(i)


## Luz do dia ajustada pela tempestade e pelo clarão.
func adjust_daylight(daylight: float) -> float:
	return clampf(daylight * (1.0 - DARKEN * amount) + flash * 0.6, 0.0, 1.0)

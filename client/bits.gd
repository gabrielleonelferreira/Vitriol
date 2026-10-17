class_name Bits
extends Node2D
## Partículas pequenas do mundo: lascas ao minerar, poeira ao quebrar, faíscas do raio e a fumaça
## e as brasas das estações acesas. Tudo em pixels de 1 a 2 px, nas cores da paleta.

## Cor das lascas por família de material (ver Sfx.family).
const CHIPS := {
	"terra": [Color("94744f"), Color("57432f")],
	"pedra": [Color("949ca3"), Color("6b737c")],
	"madeira": [Color("b8956a"), Color("74593d")],
	"folhas": [Color("4f8a4a"), Color("86b85a")],
}
## Estações que soltam fumaça (fornos) ou brasas (fogueira).
const SMOKY := ["fornalha", "forno", "forno_de_vidro"]
const SPARKY := ["fogueira", "fornalha"]
const POOL := 16

var _pool: Array[CPUParticles2D] = []
var _next: int = 0
var _dot: ImageTexture
var _station_fx: Dictionary = {}


func _ready() -> void:
	z_index = 40
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_dot = ImageTexture.create_from_image(image)
	for i in POOL:
		var p := _emitter()
		p.one_shot = true
		p.explosiveness = 1.0
		p.emitting = false
		add_child(p)
		_pool.append(p)


## Estouro de partículas em `at` (px). `big` = quebra do bloco; senão, uma batida da picareta.
func burst(at: Vector2, family: String, big: bool = false) -> void:
	var colors: Array = CHIPS.get(family, CHIPS["pedra"])
	_fire(at, colors, 16 if big else 6, 80.0 if big else 55.0, 0.5 if big else 0.32)


func sparks(at: Vector2) -> void:
	_fire(at, [Color("c8f0ff"), Color("7ad8ff"), Color("f7f6f0")], 22, 120.0, 0.4)


## Mantém fumaça/brasa nas estações acesas que estão na tela. `cells`: {Vector2i: nome}.
func set_stations(cells: Dictionary) -> void:
	for cell in _station_fx.keys():
		if not cells.has(cell):
			for node in _station_fx[cell]:
				node.queue_free()
			_station_fx.erase(cell)
	for cell in cells:
		if _station_fx.has(cell):
			continue
		var name: String = cells[cell]
		var top := Vector2((cell.x + 0.5) * WorldGrid.TILE_SIZE, cell.y * WorldGrid.TILE_SIZE + 2.0)
		var nodes: Array = []
		if name in SMOKY:
			var smoke := _emitter()
			smoke.position = top
			smoke.amount = 10
			smoke.lifetime = 2.4
			smoke.direction = Vector2(0.15, -1.0)
			smoke.spread = 12.0
			smoke.gravity = Vector2(4, -6)
			smoke.initial_velocity_min = 6.0
			smoke.initial_velocity_max = 12.0
			smoke.scale_amount_min = 1.0
			smoke.scale_amount_max = 2.0
			smoke.color_ramp = _ramp([Color(0.58, 0.61, 0.64, 0.55), Color(0.29, 0.31, 0.35, 0.0)])
			add_child(smoke)
			nodes.append(smoke)
		if name in SPARKY:
			var embers := _emitter()
			embers.position = top + Vector2(0, 4)
			embers.amount = 5
			embers.lifetime = 0.9
			embers.direction = Vector2(0, -1)
			embers.spread = 25.0
			embers.gravity = Vector2(0, -10)
			embers.initial_velocity_min = 14.0
			embers.initial_velocity_max = 26.0
			embers.color_ramp = _ramp([Color("f2d36b"), Color(0.88, 0.31, 0.23, 0.0)])
			add_child(embers)
			nodes.append(embers)
		_station_fx[cell] = nodes


func _fire(at: Vector2, colors: Array, count: int, speed: float, life: float) -> void:
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.position = at
	p.amount = count
	p.lifetime = life
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.gravity = Vector2(0, 320)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.color_ramp = _ramp([colors[0], colors[colors.size() - 1]])
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.restart()


func _emitter() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _dot
	p.local_coords = false
	p.emitting = true
	return p


static func _ramp(colors: Array) -> Gradient:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	return gradient

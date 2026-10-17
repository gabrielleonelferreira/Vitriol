class_name Lighting
extends Node2D
## Iluminação por tile, colorida, desenhada por cima do mundo (multiplica as cores).
##
## Fontes: o céu (colunas abertas para cima, com dia e noite), objetos que emitem luz (tochas)
## e a luz que o jogador segura. A luz se espalha pelo ar perdendo 1/9 por tile e entra pouco
## na rocha (perde 1/3 por tile). Cada camada tem uma luz mínima (ambiente), mais escura quanto
## mais fundo. Só a região em volta da câmera é calculada.

## Perda de luz por tile no ar e dentro de blocos sólidos.
const AIR_DECAY := 1.0 / 9.0
const SOLID_DECAY := 1.0 / 3.0
## Luz mínima por camada (0 = superfície, 1 Solo, 2 Sedimentar, 3 Metamórfica...).
const LAYER_AMBIENT := [0.0, 0.24, 0.13, 0.06]
## Cor do céu à noite e de dia.
const NIGHT_SKY := Color(0.16, 0.2, 0.36)
const DAY_SKY := Color(1.0, 1.0, 1.0)
## Margem (tiles) além da tela: luz que vem de fora também entra.
const MARGIN := 12
## Recalcula quando a câmera anda tantos tiles.
const MOVE_THRESHOLD := 3

var grid: WorldGrid
var daylight: float = 1.0
var _sky_top: PackedInt32Array = []
var _sprite := Sprite2D.new()
var _image: Image
var _texture: ImageTexture
var _origin := Vector2i(-9999, -9999)
var _size := Vector2i.ZERO
var _last_center := Vector2i(-9999, -9999)
var _held_tile := Vector2i(-9999, -9999)
var _held_intensity: float = 0.0
var _held_color: Color = Color.WHITE
var _dirty: bool = true
var _last_daylight: float = -1.0


func setup(new_grid: WorldGrid) -> void:
	grid = new_grid
	_sky_top.resize(grid.width)
	for x in grid.width:
		_update_sky_column(x)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_sprite.material = material
	_sprite.centered = false
	_sprite.scale = Vector2(WorldGrid.TILE_SIZE, WorldGrid.TILE_SIZE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.z_index = 50
	_sprite.name = "MapaDeLuz"
	add_child(_sprite)


## Um tile mudou: recalcula a coluna do céu e a luz.
func tile_changed(x: int, _y: int) -> void:
	if x >= 0 and x < grid.width:
		_update_sky_column(x)
	_dirty = true


## Luz que o jogador segura (tocha na mão). intensidade 0 = nenhuma.
func set_held_light(tile: Vector2i, radius: float, color: Color) -> void:
	var intensity := radius * AIR_DECAY
	if (
		tile != _held_tile
		or not is_equal_approx(intensity, _held_intensity)
		or color != _held_color
	):
		_held_tile = tile
		_held_intensity = intensity
		_held_color = color
		_dirty = true


func set_daylight(value: float) -> void:
	daylight = value
	if absf(daylight - _last_daylight) > 0.02:
		_dirty = true


## Chamado todo quadro com o tile no centro da câmera e o tamanho da tela em tiles.
func update_view(center: Vector2i, view_tiles: Vector2i) -> void:
	if grid == null:
		return
	if (
		not _dirty
		and absi(center.x - _last_center.x) < MOVE_THRESHOLD
		and absi(center.y - _last_center.y) < MOVE_THRESHOLD
	):
		return
	_last_center = center
	_dirty = false
	_last_daylight = daylight
	var half := view_tiles / 2 + Vector2i(MARGIN, MARGIN)
	var x0 := clampi(center.x - half.x, 0, grid.width - 1)
	var y0 := clampi(center.y - half.y, 0, grid.height - 1)
	var x1 := clampi(center.x + half.x, 1, grid.width)
	var y1 := clampi(center.y + half.y, 1, grid.height)
	_compute(Vector2i(x0, y0), Vector2i(x1 - x0, y1 - y0))


func _update_sky_column(x: int) -> void:
	var y := 0
	while y < grid.height and not grid.is_solid(x, y):
		y += 1
	_sky_top[x] = y


func _compute(origin: Vector2i, size: Vector2i) -> void:
	var count := size.x * size.y
	var r := PackedFloat32Array()
	var g := PackedFloat32Array()
	var b := PackedFloat32Array()
	r.resize(count)
	g.resize(count)
	b.resize(count)
	var solid := PackedByteArray()
	solid.resize(count)
	var queue := PackedInt32Array()
	var sky := NIGHT_SKY.lerp(DAY_SKY, daylight)

	for ly in size.y:
		var y := origin.y + ly
		for lx in size.x:
			var x := origin.x + lx
			var i := ly * size.x + lx
			var id := grid.get_tile(x, y)
			solid[i] = 1 if grid.registry.is_solid(id) else 0
			var lit := false
			if y < _sky_top[x] and solid[i] == 0:
				r[i] = sky.r
				g[i] = sky.g
				b[i] = sky.b
				lit = true
			var radius := grid.registry.light_radius[id] if id >= 0 else 0.0
			if radius > 0.0:
				var color: Color = grid.registry.light_color[id]
				var power := radius * AIR_DECAY
				r[i] = maxf(r[i], color.r * power)
				g[i] = maxf(g[i], color.g * power)
				b[i] = maxf(b[i], color.b * power)
				lit = true
			if Vector2i(x, y) == _held_tile and _held_intensity > 0.0:
				r[i] = maxf(r[i], _held_color.r * _held_intensity)
				g[i] = maxf(g[i], _held_color.g * _held_intensity)
				b[i] = maxf(b[i], _held_color.b * _held_intensity)
				lit = true
			if lit:
				queue.append(i)

	# Espalha a luz (cada tile fica com o máximo que chega dos vizinhos).
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var lx := i % size.x
		var ly := i / size.x
		for n in 4:
			var nx := lx + (1 if n == 0 else -1 if n == 1 else 0)
			var ny := ly + (1 if n == 2 else -1 if n == 3 else 0)
			if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
				continue
			var j := ny * size.x + nx
			var decay := SOLID_DECAY if solid[j] == 1 else AIR_DECAY
			var nr := r[i] - decay
			var ng := g[i] - decay
			var nb := b[i] - decay
			if nr > r[j] + 0.01 or ng > g[j] + 0.01 or nb > b[j] + 0.01:
				r[j] = maxf(r[j], nr)
				g[j] = maxf(g[j], ng)
				b[j] = maxf(b[j], nb)
				queue.append(j)

	if _image == null or _size != size:
		_image = Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	for ly in size.y:
		for lx in size.x:
			var i := ly * size.x + lx
			var layer := clampi(
				grid.layer_at(origin.x + lx, origin.y + ly), 0, LAYER_AMBIENT.size() - 1
			)
			var ambient: float = LAYER_AMBIENT[layer]
			_image.set_pixel(
				lx,
				ly,
				Color(
					clampf(maxf(r[i], ambient), 0.0, 1.0),
					clampf(maxf(g[i], ambient), 0.0, 1.0),
					clampf(maxf(b[i], ambient * 1.05), 0.0, 1.0)
				)
			)
	if _texture == null or _size != size:
		_texture = ImageTexture.create_from_image(_image)
		_sprite.texture = _texture
	else:
		_texture.update(_image)
	_origin = origin
	_size = size
	_sprite.position = Vector2(origin * WorldGrid.TILE_SIZE)


## Luz calculada num tile (0 a 1 por canal). Para testes e para a interface.
func light_at(x: int, y: int) -> Color:
	if _image == null:
		return Color.WHITE
	var local := Vector2i(x, y) - _origin
	if local.x < 0 or local.y < 0 or local.x >= _size.x or local.y >= _size.y:
		return Color.BLACK
	return _image.get_pixel(local.x, local.y)

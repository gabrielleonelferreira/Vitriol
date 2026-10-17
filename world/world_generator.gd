class_name WorldGenerator
extends RefCounted
## Gera o mundo das Planícies a partir de uma semente. Mesma semente = mesmo mundo.
##
## Etapas, nesta ordem:
##   1. relevo da superfície e limites das camadas
##   2. preenchimento com a rocha principal de cada camada (dos dados de geração)
##   3. lagos, com leito e margens
##   4. minérios e bolsões (regras de data/content/geracao.csv)
##   5. cavernas, que cortam os veios e os deixam à mostra
##   6. grama, árvores, base indestrutível e ponto de nascimento

const DEFAULT_WIDTH := 1200
const DEFAULT_HEIGHT := 260

## Altura média da superfície (linha) e quanto o relevo varia.
const SURFACE_BASE := 64
const SURFACE_HILLS := 14
const SURFACE_DETAIL := 4
## Onde começam as camadas 2 e 3 (linha média) e quanto as fronteiras ondulam.
const LAYER_TOP_BASE := [0, 100, 165]
const LAYER_WOBBLE := 5
const MIN_SOLO_DEPTH := 14
## Linhas de rocha indestrutível no fundo.
const BEDROCK_ROWS := 4
## Raio da área plana e sem árvores em volta do nascimento.
const SPAWN_FLAT := 8

var _rng := RandomNumberGenerator.new()
var _noise_terrain := FastNoiseLite.new()
var _noise_detail := FastNoiseLite.new()
var _noise_layers := FastNoiseLite.new()
var _noise_caves := FastNoiseLite.new()
var _noise_caverns := FastNoiseLite.new()
var _noise_cave_zones := FastNoiseLite.new()
var _grid: WorldGrid
var _reg: TileRegistry
var _data: DataStore
var _rocks: PackedInt32Array = []
var _lakes: Array[Dictionary] = []


func generate(
	world_seed: int, data: DataStore, width: int = DEFAULT_WIDTH, height: int = DEFAULT_HEIGHT
) -> WorldGrid:
	_data = data
	_reg = TileRegistry.from_data(data)
	_grid = WorldGrid.new(width, height, _reg)
	_lakes.clear()
	_seed_all(world_seed)
	_rocks.clear()
	for rock in data.layer_rocks():
		_rocks.append(_reg.id_of(rock))

	_shape_surface()
	_shape_layers()
	_fill_layers()
	_carve_lakes()
	_place_ores()
	_carve_caves()
	_finish_surface()
	_place_trees()
	_place_bedrock()
	return _grid


func _seed_all(world_seed: int) -> void:
	_rng.seed = world_seed
	var noises := [
		_noise_terrain,
		_noise_detail,
		_noise_layers,
		_noise_caves,
		_noise_caverns,
		_noise_cave_zones
	]
	for index in noises.size():
		var noise: FastNoiseLite = noises[index]
		noise.seed = world_seed + index * 1013
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_terrain.frequency = 0.006
	_noise_detail.frequency = 0.05
	_noise_layers.frequency = 0.02
	_noise_caves.frequency = 0.016
	_noise_caverns.frequency = 0.018
	_noise_cave_zones.frequency = 0.007


# ---------- 1. relevo ----------


func _shape_surface() -> void:
	var center := _grid.width / 2
	for x in _grid.width:
		var y := (
			SURFACE_BASE
			+ _noise_terrain.get_noise_1d(x) * SURFACE_HILLS
			+ _noise_detail.get_noise_1d(x) * SURFACE_DETAIL
		)
		_grid.surface[x] = int(round(y))
	# Área plana no nascimento, com transição suave para o relevo.
	var flat_y := _grid.surface[center]
	for dx in range(-SPAWN_FLAT * 2, SPAWN_FLAT * 2 + 1):
		var x := center + dx
		if x < 0 or x >= _grid.width:
			continue
		var weight := clampf((absi(dx) - SPAWN_FLAT) / float(SPAWN_FLAT), 0.0, 1.0)
		_grid.surface[x] = int(round(lerpf(flat_y, _grid.surface[x], weight)))
	_grid.spawn_tile = Vector2i(center, flat_y)


func _shape_layers() -> void:
	_grid.layer_tops.clear()
	for layer in _rocks.size():
		var row := PackedInt32Array()
		row.resize(_grid.width)
		for x in _grid.width:
			if layer == 0:
				row[x] = _grid.surface[x]
			else:
				var base: int = LAYER_TOP_BASE[min(layer, LAYER_TOP_BASE.size() - 1)]
				var wobble := _noise_layers.get_noise_2d(x, layer * 100) * LAYER_WOBBLE
				var top := int(round(base + wobble))
				if layer == 1:
					top = maxi(top, _grid.surface[x] + MIN_SOLO_DEPTH)
				row[x] = top
		_grid.layer_tops.append(row)


func _fill_layers() -> void:
	for x in _grid.width:
		for y in _grid.height:
			if y < _grid.surface[x]:
				continue
			var rock := _rocks[_fill_layer_index(x, y)]
			_grid.set_tile(x, y, rock)
			_grid.set_wall(x, y, rock)


## Como _layer_index, mas com a fronteira serrilhada (até 2 tiles) para a transição entre
## camadas não ficar uma linha reta.
func _fill_layer_index(x: int, y: int) -> int:
	var jitter := int(round(_noise_detail.get_noise_2d(x * 4.0, y * 4.0) * 2.0))
	return _layer_index(x, y + jitter)


func _layer_index(x: int, y: int) -> int:
	var index := 0
	for layer in range(1, _grid.layer_tops.size()):
		if y >= _grid.layer_tops[layer][x]:
			index = layer
	return index


# ---------- 3. lagos ----------


func _carve_lakes() -> void:
	var water := _reg.id_of(TileRegistry.WATER)
	var bed_ids := _ids_for_form(1, "leito")
	var count := maxi(1, _grid.width / 160)
	var center := _grid.width / 2
	for attempt in count * 3:
		if _lakes.size() >= count:
			break
		var half := _rng.randi_range(7, 15)
		var cx := _rng.randi_range(half + 4, _grid.width - half - 5)
		if absi(cx - center) < SPAWN_FLAT * 2 + half:
			continue
		if _lakes.any(
			func(l: Dictionary) -> bool: return absi(l["x"] - cx) < l["half"] + half + 12
		):
			continue
		var level: int = mini(_grid.surface[cx - half], _grid.surface[cx + half])
		var depth := _rng.randi_range(3, 6)
		for dx in range(-half, half + 1):
			var x := cx + dx
			var bowl := int(round(depth * (1.0 - pow(float(dx) / half, 2))))
			# Nivela as bordas no nível da água.
			for y in range(_grid.surface[x], level):
				_grid.set_tile(x, y, 0)
				_grid.set_wall(x, y, 0)
			for y in range(level, _grid.surface[x]):
				_grid.set_tile(x, y, _rocks[0])
				_grid.set_wall(x, y, _rocks[0])
			_grid.surface[x] = level
			for y in range(level, level + bowl):
				_grid.set_tile(x, y, water)
			if bowl > 0 and not bed_ids.is_empty():
				_grid.set_tile(x, level + bowl, bed_ids[0])
		_lakes.append({"x": cx, "half": half, "level": level, "depth": depth})
	_place_margins()


func _place_margins() -> void:
	for rule in _data.generation_for_layer(1):
		if rule["forma"] != "margem":
			continue
		var id := _reg.id_of(rule["material"])
		for lake in _lakes:
			for n in int(rule["frequencia"]):
				var side := -1 if _rng.randf() < 0.5 else 1
				var x: int = lake["x"] + side * (lake["half"] + _rng.randi_range(-2, 3))
				var y: int = lake["level"] + _rng.randi_range(0, 2)
				_blob(x, y, _rng.randi_range(rule["tamanho_min"], rule["tamanho_max"]), id, true)


# ---------- 4. minérios ----------


func _place_ores() -> void:
	for layer in range(1, _rocks.size() + 1):
		for rule in _data.generation_for_layer(layer):
			var id := _reg.id_of(rule["material"])
			var count := int(round(float(rule["frequencia"]) * _grid.width / 100.0))
			match rule["forma"]:
				"veio":
					for n in count:
						var spot := _random_spot_in_layer(layer)
						_vein(
							spot,
							_rng.randi_range(rule["tamanho_min"], rule["tamanho_max"]),
							id,
							layer
						)
				"bolsao":
					for n in count:
						var spot := _random_spot_in_layer(layer)
						var radius := _rng.randi_range(rule["tamanho_min"], rule["tamanho_max"])
						_blob(spot.x, spot.y, radius, id, false, layer)
				"superficie":
					for n in count:
						var x := _rng.randi_range(0, _grid.width - 1)
						if _near_spawn(x) or _in_lake(x):
							continue
						var radius := _rng.randi_range(rule["tamanho_min"], rule["tamanho_max"]) / 2
						_blob(x, _grid.surface[x] + radius - 1, maxi(radius, 1), id, true)


func _random_spot_in_layer(layer: int) -> Vector2i:
	var x := _rng.randi_range(0, _grid.width - 1)
	var top: int = _grid.layer_tops[layer - 1][x]
	var bottom: int = (
		_grid.layer_tops[layer][x]
		if layer < _grid.layer_tops.size()
		else _grid.height - BEDROCK_ROWS
	)
	if layer == 1:
		top += 3
	return Vector2i(x, _rng.randi_range(top, maxi(top, bottom - 1)))


func _vein(start: Vector2i, length: int, id: int, layer: int) -> void:
	var position := Vector2(start)
	var angle := _rng.randf() * TAU
	var thick := length >= 6
	for step in length:
		var tx := int(position.x)
		var ty := int(position.y)
		_replace_rock(tx, ty, id, layer)
		if thick or step % 2 == 0:
			_replace_rock(tx + 1, ty, id, layer)
		if thick and _rng.randf() < 0.6:
			_replace_rock(tx, ty + 1, id, layer)
		angle += _rng.randf_range(-0.7, 0.7)
		position += Vector2.from_angle(angle)


## Mancha arredondada. Com `surface_ok`, também substitui grama e terra da superfície.
## `layer` limita a mancha a uma camada (0 = qualquer uma).
func _blob(cx: int, cy: int, radius: int, id: int, surface_ok: bool, layer: int = 0) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var jitter := _rng.randf_range(-0.6, 0.4)
			if dx * dx + dy * dy > (radius + jitter) * (radius + jitter):
				continue
			var x := cx + dx
			var y := cy + dy
			if surface_ok and _grid.in_bounds(x, y) and y >= _grid.surface[x]:
				var current := _grid.get_tile(x, y)
				if current == _rocks[0] or current == _reg.id_of(TileRegistry.GRASS):
					_grid.set_tile(x, y, id)
			else:
				_replace_rock(x, y, id, layer)


## Só troca a rocha principal da camada (não sobrescreve outro minério, água ou ar).
## Com `layer` > 0, só age dentro dessa camada: um veio nunca vaza para a vizinha.
func _replace_rock(x: int, y: int, id: int, layer: int = 0) -> void:
	if not _grid.in_bounds(x, y) or y < _grid.surface[x] + 1:
		return
	var index := _layer_index(x, y)
	if layer > 0 and index != layer - 1:
		return
	var current := _grid.get_tile(x, y)
	if current == _rocks[index]:
		_grid.set_tile(x, y, id)


# ---------- 5. cavernas ----------


func _carve_caves() -> void:
	var bottom := _grid.height - BEDROCK_ROWS
	for x in _grid.width:
		var top := _grid.surface[x] + 7
		for y in range(top, bottom):
			var depth := float(y - _grid.surface[x])
			# Túneis: onde o ruído cruza o zero. Só em algumas regiões (zonas de caverna),
			# para sobrar rocha maciça para minerar; ficam mais largos com a profundidade.
			var zone := _noise_cave_zones.get_noise_2d(x, y)
			var tunnel := absf(_noise_caves.get_noise_2d(x, y * 1.5))
			var tunnel_width := (
				clampf(0.035 + depth * 0.0005, 0.0, 0.085) * clampf(zone + 0.6, 0.0, 1.0)
			)
			# Salões: manchas grandes, só nas camadas mais fundas.
			var cavern := _noise_caverns.get_noise_2d(x, y) > 0.6 - clampf(depth * 0.002, 0.0, 0.16)
			if tunnel < tunnel_width or (depth > 40 and cavern):
				# Cava também o tile de baixo: túnel com no mínimo 2 de altura, para o
				# personagem (2 tiles) conseguir passar.
				for ty in [y, y + 1]:
					if ty < bottom and _grid.get_tile(x, ty) != _reg.id_of(TileRegistry.WATER):
						_grid.set_tile(x, ty, 0)
	_carve_entrances()


func _carve_entrances() -> void:
	var count := maxi(1, _grid.width / 220)
	for n in count:
		var x := _rng.randi_range(10, _grid.width - 11)
		if _near_spawn(x) or _in_lake(x):
			continue
		var position := Vector2(x, _grid.surface[x])
		var angle := PI / 2 + _rng.randf_range(-0.5, 0.5)
		for step in _rng.randi_range(25, 45):
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var tx := int(position.x) + dx
					var ty := int(position.y) + dy
					if _grid.in_bounds(tx, ty) and ty < _grid.height - BEDROCK_ROWS:
						_grid.set_tile(tx, ty, 0)
			angle = clampf(angle + _rng.randf_range(-0.4, 0.4), 0.3, PI - 0.3)
			position += Vector2.from_angle(angle)


# ---------- 6. acabamento ----------


func _finish_surface() -> void:
	var grass := _reg.id_of(TileRegistry.GRASS)
	for x in _grid.width:
		var y := _grid.surface[x]
		if _grid.get_tile(x, y) == _rocks[0] and _grid.get_tile(x, y - 1) == 0:
			_grid.set_tile(x, y, grass)
		# Na superfície não há parede de fundo: o céu aparece atrás.
		_grid.set_wall(x, y, 0)


func _place_trees() -> void:
	var grass := _reg.id_of(TileRegistry.GRASS)
	var trunk := _reg.id_of(TileRegistry.TRUNK)
	var leaves := _reg.id_of(TileRegistry.LEAVES)
	var last_tree := -100
	for x in range(3, _grid.width - 3):
		if x - last_tree < 5 or _near_spawn(x) or _in_lake(x):
			continue
		var ground := _grid.surface[x]
		if _grid.get_tile(x, ground) != grass or _rng.randf() > 0.22:
			continue
		var tall := _rng.randi_range(4, 7)
		for h in range(1, tall + 1):
			_grid.set_tile(x, ground - h, trunk)
		var crown := ground - tall
		for dy in range(-3, 2):
			for dx in range(-2, 3):
				if absi(dx) == 2 and (dy == -3 or dy == 1):
					continue
				var tx := x + dx
				var ty := crown + dy
				if _grid.get_tile(tx, ty) == 0:
					_grid.set_tile(tx, ty, leaves)
		last_tree = x


func _place_bedrock() -> void:
	var bedrock := _reg.id_of(TileRegistry.BEDROCK)
	for x in _grid.width:
		var rows := BEDROCK_ROWS + (1 if _noise_detail.get_noise_2d(x, 999) > 0.2 else 0)
		for y in range(_grid.height - rows, _grid.height):
			_grid.set_tile(x, y, bedrock)
			_grid.set_wall(x, y, bedrock)


func _near_spawn(x: int) -> bool:
	return absi(x - _grid.spawn_tile.x) <= SPAWN_FLAT + 2


func _in_lake(x: int) -> bool:
	for lake in _lakes:
		if absi(x - lake["x"]) <= lake["half"] + 2:
			return true
	return false


func _ids_for_form(layer: int, form: String) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for rule in _data.generation_for_layer(layer):
		if rule["forma"] == form:
			ids.append(_reg.id_of(rule["material"]))
	return ids

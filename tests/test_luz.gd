extends TestCase
## Iluminação por tile.

var _data: DataStore
var _reg: TileRegistry


func _init() -> void:
	_data = DataStore.new()
	_data.load_all()
	_reg = TileRegistry.from_data(_data)


func cleanup() -> void:
	_data.free()


## Grade 60x60: céu até a linha 10, rocha embaixo, com uma caverna fechada em (30, 40).
func _world() -> WorldGrid:
	var grid := WorldGrid.new(60, 60, _reg)
	var rock := _reg.id_of("calcario")
	for x in 60:
		grid.surface[x] = 10
		for y in range(10, 60):
			grid.set_tile(x, y, rock)
	grid.layer_tops = [PackedInt32Array(), PackedInt32Array()]
	for row in grid.layer_tops:
		row.resize(60)
	for x in 60:
		grid.layer_tops[0][x] = 10
		grid.layer_tops[1][x] = 25
	for x in range(26, 35):
		for y in range(38, 42):
			grid.set_tile(x, y, 0)
	return grid


func _light(grid: WorldGrid, daylight: float = 1.0) -> Lighting:
	var light := Lighting.new()
	light.setup(grid)
	light.set_daylight(daylight)
	light.update_view(Vector2i(30, 30), Vector2i(40, 40))
	return light


func test_ceu_ilumina_a_superficie() -> void:
	var light := _light(_world())
	check(light.light_at(30, 5).r > 0.95, "o céu de dia é claro")
	check(light.light_at(30, 10).r > 0.6, "o primeiro bloco do chão recebe luz")
	check(light.light_at(30, 14).r < 0.3, "alguns blocos abaixo já está escuro")
	light.free()


func test_caverna_fechada_fica_escura() -> void:
	var light := _light(_world())
	var cave := light.light_at(30, 40)
	check(
		cave.r <= Lighting.LAYER_AMBIENT[2] + 0.01, "caverna fechada só tem a luz mínima da camada"
	)
	light.free()


func test_tocha_ilumina_em_volta() -> void:
	var grid := _world()
	grid.set_tile(30, 41, _reg.id_of("tocha"))
	var light := _light(grid)
	var near := light.light_at(31, 41)
	var far := light.light_at(34, 39)
	check(near.r > 0.7, "do lado da tocha é claro (%.2f)" % near.r)
	check(near.r > near.b, "luz da tocha é quente (mais vermelho que azul)")
	check(far.r < near.r, "a luz diminui com a distância")
	check(light.light_at(30, 46).r < 0.2, "a rocha abafa a luz")
	light.free()


func test_noite_escurece() -> void:
	var day := _light(_world(), 1.0)
	var night := _light(_world(), 0.0)
	check(night.light_at(30, 5).r < day.light_at(30, 5).r * 0.4, "à noite o céu é bem mais escuro")
	check(night.light_at(30, 5).b > night.light_at(30, 5).r, "a noite é azulada")
	day.free()
	night.free()


func test_minerar_abre_caminho_para_a_luz() -> void:
	var grid := _world()
	var light := _light(grid)
	var before := light.light_at(30, 12).r
	for y in range(10, 13):
		grid.set_tile(30, y, 0)
		light.tile_changed(30, y)
	light.update_view(Vector2i(30, 30), Vector2i(40, 40))
	check(light.light_at(30, 12).r > before + 0.3, "um poço aberto deixa o céu entrar")
	light.free()

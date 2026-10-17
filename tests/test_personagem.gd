extends TestCase
## Física do personagem contra uma grade montada à mão.

const DT := 1.0 / 60.0

var _data: DataStore
var _reg: TileRegistry


func _init() -> void:
	_data = DataStore.new()
	_data.load_all()
	_reg = TileRegistry.from_data(_data)


func cleanup() -> void:
	_data.free()


## Grade 40x20 com chão sólido a partir da linha 15.
func _flat(width: int = 40) -> WorldGrid:
	var grid := WorldGrid.new(width, 20, _reg)
	for x in width:
		for y in range(15, 20):
			grid.set_tile(x, y, _reg.id_of("calcario"))
	return grid


func _motor_at(tile_x: int, tile_y: int) -> PlayerMotor:
	var motor := PlayerMotor.new()
	motor.position = Vector2((tile_x + 0.5) * 16, tile_y * 16)
	return motor


func _run(motor: PlayerMotor, grid: WorldGrid, seconds: float, move: float, jump := false) -> float:
	var highest := motor.position.y
	var frames := int(seconds / DT)
	for i in frames:
		motor.step(move, jump and i == 0, jump, DT, grid)
		highest = minf(highest, motor.position.y)
	return highest


func test_cai_e_para_no_chao() -> void:
	var grid := _flat()
	var motor := _motor_at(10, 5)
	_run(motor, grid, 2.0, 0.0)
	check_eq(motor.position.y, 15.0 * 16, "pés param no topo do chão")
	check(motor.on_floor, "fica no chão")
	check_eq(motor.velocity.y, 0.0, "sem velocidade vertical parado")


func test_anda_e_vira() -> void:
	var grid := _flat()
	var motor := _motor_at(10, 15)
	_run(motor, grid, 0.2, 0.0)
	var start := motor.position.x
	_run(motor, grid, 1.0, 1.0)
	check(motor.position.x > start + 60, "anda para a direita")
	check(absf(motor.velocity.x - PlayerMotor.RUN_SPEED) < 1.0, "chega na velocidade máxima")
	check_eq(motor.facing, 1, "virado para a direita")
	_run(motor, grid, 0.5, -1.0)
	check_eq(motor.facing, -1, "vira para a esquerda")


func test_pulo_alcanca_tres_tiles() -> void:
	var grid := _flat()
	var motor := _motor_at(10, 15)
	_run(motor, grid, 0.1, 0.0)
	var ground := motor.position.y
	var highest := _run(motor, grid, 1.0, 0.0, true)
	var height_tiles := (ground - highest) / 16.0
	check(
		height_tiles > 2.6 and height_tiles < 3.5, "pulo cheio sobe ~3 tiles (%.2f)" % height_tiles
	)
	check(motor.on_floor, "volta ao chão")


func test_soltar_cedo_pula_menos() -> void:
	var grid := _flat()
	var full := _motor_at(10, 15)
	var tap := _motor_at(20, 15)
	_run(full, grid, 0.1, 0.0)
	_run(tap, grid, 0.1, 0.0)
	var ground := full.position.y
	var high_full := _run(full, grid, 1.0, 0.0, true)
	tap.step(0.0, true, true, DT, grid)
	var high_tap := _run(tap, grid, 1.0, 0.0, false)
	check(ground - high_tap < (ground - high_full) * 0.7, "toque curto pula bem menos")


func test_parede_bloqueia() -> void:
	var grid := _flat()
	for y in range(10, 15):
		grid.set_tile(15, y, _reg.id_of("calcario"))
	var motor := _motor_at(12, 15)
	_run(motor, grid, 2.0, 1.0)
	var wall_left := 15.0 * 16
	check(motor.position.x + PlayerMotor.HITBOX.x / 2 <= wall_left + 0.01, "não atravessa a parede")
	check(motor.position.x > wall_left - 8, "encosta na parede")


func test_sobe_degrau_de_um_tile() -> void:
	var grid := _flat()
	for x in range(15, 40):
		grid.set_tile(x, 14, _reg.id_of("calcario"))
	var motor := _motor_at(12, 15)
	_run(motor, grid, 1.5, 1.0)
	check(motor.position.x > 16 * 17, "passou do degrau sem pular")
	check_eq(motor.position.y, 14.0 * 16, "está no nível de cima")


func test_nao_sobe_degrau_de_dois_tiles() -> void:
	var grid := _flat()
	for x in range(15, 40):
		grid.set_tile(x, 14, _reg.id_of("calcario"))
		grid.set_tile(x, 13, _reg.id_of("calcario"))
	var motor := _motor_at(12, 15)
	_run(motor, grid, 1.5, 1.0)
	check(motor.position.x < 16 * 15, "parou antes de um degrau de 2 tiles")


func test_teto_corta_o_pulo() -> void:
	var grid := _flat()
	for x in range(5, 15):
		grid.set_tile(x, 12, _reg.id_of("calcario"))
	var motor := _motor_at(10, 15)
	_run(motor, grid, 0.1, 0.0)
	var highest := _run(motor, grid, 1.0, 0.0, true)
	check(highest - PlayerMotor.HITBOX.y >= 13.0 * 16 - 0.01, "a cabeça não entra no teto")


func test_coyote_time() -> void:
	var grid := _flat()
	for x in range(12, 40):
		for y in range(15, 20):
			grid.set_tile(x, y, 0)
	var motor := _motor_at(10, 15)
	_run(motor, grid, 0.1, 0.0)
	# Corre para fora da beirada e pula alguns quadros depois de perder o chão.
	var frames := 0
	while motor.on_floor and frames < 200:
		motor.step(1.0, false, false, DT, grid)
		frames += 1
	motor.step(1.0, false, false, DT, grid)
	motor.step(1.0, false, false, DT, grid)
	motor.step(1.0, true, true, DT, grid)
	check(motor.velocity.y < -200, "ainda pula logo depois de sair da beirada")


func test_tunel_de_dois_tiles() -> void:
	var grid := _flat()
	for x in 40:
		for y in range(0, 13):
			grid.set_tile(x, y, _reg.id_of("calcario"))
	var motor := _motor_at(5, 15)
	_run(motor, grid, 2.0, 1.0)
	check(motor.position.x > 16 * 15, "anda por um túnel de 2 tiles de altura")


func test_agua_freia_a_queda() -> void:
	var grid := _flat()
	for x in 40:
		for y in range(5, 15):
			grid.set_tile(x, y, _reg.id_of("agua"))
	var motor := _motor_at(10, 6)
	_run(motor, grid, 0.6, 0.0)
	check(motor.in_water, "detecta a água")
	check(motor.velocity.y <= PlayerMotor.WATER_MAX_FALL + 0.01, "cai devagar na água")
	var before := motor.position.y
	_run(motor, grid, 0.4, 0.0, true)
	check(motor.position.y < before, "nada para cima segurando pulo")


func test_mundo_gerado_nascimento() -> void:
	var grid := WorldGenerator.new().generate(5, _data, 300)
	var motor := PlayerMotor.new()
	motor.position = grid.spawn_position()
	check(not PlayerMotor.overlaps_solid(grid, motor.position), "nasce fora da rocha")
	_run(motor, grid, 1.0, 0.0)
	check(motor.on_floor, "fica de pé no chão do mundo gerado")
	_run(motor, grid, 3.0, 1.0)
	check(not PlayerMotor.overlaps_solid(grid, motor.position), "andando nunca entra na rocha")

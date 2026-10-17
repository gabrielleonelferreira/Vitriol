extends SceneTree
## Roda a cena principal, simula teclas e salva prints. Precisa de tela (não use --headless).
## Uso: godot --path . -s res://tests/captura.gd -- <pasta_saida>
##
## Roteiro: espera o mundo, print parado; anda para a direita e pula; print; vai para a
## esquerda; print.

var _out := "user://capturas"
var _frame := 0
var _main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_main = load("res://client/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		90:
			_shot("1_nascimento")
			Input.action_press("mover_direita")
		150:
			Input.action_press("pular")
		165:
			_shot("2_pulando")
		170:
			Input.action_release("pular")
		330:
			Input.action_release("mover_direita")
			_shot("3_andou")
			Input.action_press("mover_esquerda")
		520:
			Input.action_release("mover_esquerda")
			_shot("4_esquerda")
			_teleport_to_cave(2)
		600:
			_shot("5_caverna_sedimentar")
			_teleport_to_cave(3)
		680:
			_shot("6_caverna_metamorfica")
		700:
			return true
	return false


## Leva o jogador para uma caverna da camada pedida (só para os prints).
func _teleport_to_cave(layer: int) -> void:
	var server := root.get_node("GameServer")
	var grid: WorldGrid = server.world.grid
	for x in range(grid.width / 2, grid.width):
		for y in range(grid.height - 10, grid.surface[x], -1):
			if grid.layer_at(x, y) != layer:
				continue
			var feet := Vector2((x + 0.5) * 16, y * 16)
			if grid.is_solid(x, y) and not PlayerMotor.overlaps_solid(grid, feet):
				var hits := 0
				for dx in range(-8, 9):
					if grid.get_tile(x + dx, y - 6) != 0:
						hits += 1
				if hits < 8:
					continue
				for player in server.players.values():
					player.position = feet
				_main.get_node("Jogador").apply_correction(feet)
				return


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	image.save_png(path)
	print("print: ", path)

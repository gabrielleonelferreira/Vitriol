extends SceneTree
## Grava os comandos de teclado padrão em project.godot.
## Uso: godot --headless --path . -s res://player/setup_input.gd

const ACTIONS := {
	"mover_esquerda": [KEY_A, KEY_LEFT],
	"mover_direita": [KEY_D, KEY_RIGHT],
	"pular": [KEY_SPACE, KEY_W, KEY_UP],
	"depurar": [KEY_F3],
}


func _initialize() -> void:
	for action in ACTIONS:
		var events: Array = []
		for key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.device = -1
			event.physical_keycode = key
			events.append(event)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	ProjectSettings.set_setting(
		"rendering/environment/defaults/default_clear_color", Color("9fd3f0")
	)
	var error := ProjectSettings.save()
	print("comandos gravados" if error == OK else "erro ao gravar: %d" % error)
	quit(error)

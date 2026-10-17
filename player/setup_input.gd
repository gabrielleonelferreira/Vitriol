extends SceneTree
## Grava os comandos de teclado e mouse padrão (e alguns ajustes do projeto) em project.godot.
## Uso: godot --headless --path . -s res://player/setup_input.gd

const ACTIONS := {
	"mover_esquerda": [KEY_A, KEY_LEFT],
	"mover_direita": [KEY_D, KEY_RIGHT],
	"pular": [KEY_SPACE, KEY_W, KEY_UP],
	"depurar": [KEY_F3],
	"kit_teste": [KEY_F4],
	"inventario": [KEY_E, KEY_I],
	"fabricar": [KEY_C],
	"slot_1": [KEY_1],
	"slot_2": [KEY_2],
	"slot_3": [KEY_3],
	"slot_4": [KEY_4],
	"slot_5": [KEY_5],
	"slot_6": [KEY_6],
	"slot_7": [KEY_7],
	"slot_8": [KEY_8],
	"slot_9": [KEY_9],
	"slot_10": [KEY_0],
}
const MOUSE_ACTIONS := {
	"minerar": MOUSE_BUTTON_LEFT,
	"colocar": MOUSE_BUTTON_RIGHT,
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
	for action in MOUSE_ACTIONS:
		var click := InputEventMouseButton.new()
		click.device = -1
		click.button_index = MOUSE_ACTIONS[action]
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": [click]})
	ProjectSettings.set_setting(
		"rendering/environment/defaults/default_clear_color", Color("9fd3f0")
	)
	# Texto nítido em pixel art (sem suavização) e pasta própria para os saves.
	ProjectSettings.set_setting("gui/theme/default_font_antialiasing", 0)
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "Vitriol")
	var error := ProjectSettings.save()
	print("comandos gravados" if error == OK else "erro ao gravar: %d" % error)
	quit(error)

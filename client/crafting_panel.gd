class_name CraftingPanel
extends Control
## Painel de fabricação (tecla C): receitas agrupadas por estação, com o que falta e o porquê.
## Clique em "Fazer" para 1 unidade; com Shift, 5.

signal craft_requested(recipe_id: String, qtd: int)
signal cancel_requested(index: int)

const WIDTH := 336.0
const HEIGHT := 256.0
const ROW_H := 28.0
const STATION_ORDER := ["mao", "bancada", "fogueira", "fornalha", "forno", "forno_de_vidro", "raio"]
const RED := Color("e0503a")
const ORANGE := Color("f28a5c")
const QUIET := Color("bfc5c9")

var data: DataStore
var hud: Hud
var _rows: Array[Dictionary] = []
var _mastery_label: Label
var _queue_label: Label
var _cancel_button: PixelButton
var _list: VBoxContainer


func setup(game_data: DataStore, owner_hud: Hud) -> void:
	data = game_data
	hud = owner_hud
	position = Vector2(6, 20)
	size = Vector2(WIDTH, HEIGHT)
	var back := ColorRect.new()
	back.color = Color(0.105882, 0.0901961, 0.0784314, 0.9)
	back.size = size
	add_child(back)
	var title := hud.make_label("Fabricação  ·  C fecha  ·  Shift+clique faz 5", 8)
	title.position = Vector2(6, 2)
	add_child(title)
	_mastery_label = hud.make_label("", 8)
	_mastery_label.position = Vector2(6, 13)
	_mastery_label.add_theme_color_override("font_color", Color("f2d36b"))
	add_child(_mastery_label)
	_queue_label = hud.make_label("", 8)
	_queue_label.position = Vector2(6, 24)
	add_child(_queue_label)
	_cancel_button = _button("Cancelar", Vector2(WIDTH - 56, 23), Vector2(50, 13))
	_cancel_button.pressed.connect(func() -> void: cancel_requested.emit(0))
	_cancel_button.visible = false
	add_child(_cancel_button)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(4, 38)
	scroll.size = Vector2(WIDTH - 8, HEIGHT - 42)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_list.custom_minimum_size = Vector2(WIDTH - 20, 0)
	scroll.add_child(_list)
	for recipe_id in _ordered_recipes():
		_rows.append(_make_row(recipe_id))


## Atualiza com o estado atual: espaços do inventário, XP, estações por perto e fila.
func refresh(slots: Array, mastery: Dictionary, stations: Dictionary, queue: Array) -> void:
	var inventory := Inventory.new(data)
	inventory.load_array(slots)
	var levels: PackedStringArray = []
	for area in Mastery.AREAS:
		var xp := int(mastery.get(area, 0))
		levels.append("%s %d" % [Mastery.display_name(area), Mastery.level_for(xp)])
	_mastery_label.text = "Maestria: " + "  ·  ".join(levels)
	if queue.is_empty():
		_queue_label.text = "Fila vazia"
		_cancel_button.visible = false
	else:
		var job: Dictionary = queue[0]
		var waiting := " (+%d na fila)" % (queue.size() - 1) if queue.size() > 1 else ""
		_queue_label.text = (
			"Produzindo: %s  %ds%s"
			% [data.get_recipe(job["receita"])["nome"], ceili(job["restante"]), waiting]
		)
		_cancel_button.visible = true
	for row in _rows:
		_paint_row(row, inventory, mastery, stations)


func _ordered_recipes() -> Array:
	var ids: Array = data.recipes.keys()
	ids.sort_custom(
		func(a: String, b: String) -> bool:
			var ra: Dictionary = data.recipes[a]
			var rb: Dictionary = data.recipes[b]
			var sa := STATION_ORDER.find(ra["estacao"])
			var sb := STATION_ORDER.find(rb["estacao"])
			if sa != sb:
				return sa < sb
			return ra["nome"] < rb["nome"]
	)
	return ids


func _make_row(recipe_id: String) -> Dictionary:
	var recipe: Dictionary = data.recipes[recipe_id]
	var row := Control.new()
	row.custom_minimum_size = Vector2(WIDTH - 20, ROW_H)
	var stripe := ColorRect.new()
	stripe.color = Color(0.24, 0.19, 0.16, 0.5)
	stripe.size = Vector2(WIDTH - 20, ROW_H - 1)
	row.add_child(stripe)
	var output: Dictionary = recipe["saidas"][0]
	var icon := TextureRect.new()
	icon.position = Vector2(3, 5)
	icon.size = Vector2(16, 16)
	icon.texture = hud.icon_for(output["id"])
	row.add_child(icon)
	var name := hud.make_label("", 8)
	name.position = Vector2(23, 0)
	row.add_child(name)
	var station_icon := TextureRect.new()
	station_icon.position = Vector2(WIDTH - 104, 2)
	station_icon.size = Vector2(16, 16)
	station_icon.texture = hud.icon_for(recipe["estacao"])
	row.add_child(station_icon)
	var time := hud.make_label("%ss" % _fmt(float(recipe["tempo_s"])), 8)
	time.position = Vector2(WIDTH - 86, 4)
	time.add_theme_color_override("font_color", QUIET)
	row.add_child(time)
	var button := _button("Fazer", Vector2(WIDTH - 62, 7), Vector2(38, 13))
	button.pressed.connect(
		func() -> void: craft_requested.emit(recipe_id, 5 if Input.is_key_pressed(KEY_SHIFT) else 1)
	)
	row.add_child(button)
	var detail := HBoxContainer.new()
	detail.position = Vector2(23, 13)
	detail.add_theme_constant_override("separation", 3)
	row.add_child(detail)
	var parts: Array[Dictionary] = []
	for part in recipe["entradas"]:
		var part_icon := TextureRect.new()
		part_icon.custom_minimum_size = Vector2(12, 12)
		part_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		part_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		part_icon.texture = hud.icon_for(part["id"])
		part_icon.tooltip_text = data.display_name(part["id"])
		detail.add_child(part_icon)
		var count := hud.make_label(str(part["qtd"]), 8)
		detail.add_child(count)
		parts.append({"id": part["id"], "qtd": int(part["qtd"]), "icon": part_icon, "count": count})
	var reason := hud.make_label("", 8)
	reason.add_theme_color_override("font_color", ORANGE)
	detail.add_child(reason)
	_list.add_child(row)
	return {
		"id": recipe_id,
		"root": row,
		"icon": icon,
		"name": name,
		"button": button,
		"parts": parts,
		"reason": reason,
	}


func _paint_row(
	row: Dictionary, inventory: Inventory, mastery: Dictionary, stations: Dictionary
) -> void:
	var recipe: Dictionary = data.recipes[row["id"]]
	var status := Crafting.status(recipe, data, inventory, mastery, {}, stations)
	var secret: bool = recipe["desbloqueio"] == "experimentacao"
	var output: Dictionary = recipe["saidas"][0]
	if secret and not status["ok"]:
		row["name"].text = "???"
		row["icon"].modulate = Color(0, 0, 0, 0.8)
		for part in row["parts"]:
			part["icon"].visible = false
			part["count"].visible = false
	else:
		var amount := " ×%d" % int(output["qtd"]) if int(output["qtd"]) > 1 else ""
		row["name"].text = recipe["nome"] + amount
		row["icon"].modulate = Color.WHITE
		for part in row["parts"]:
			part["icon"].visible = true
			part["count"].visible = true
			var have := inventory.count(part["id"])
			part["count"].text = "%d/%d" % [mini(have, part["qtd"]), part["qtd"]]
			part["count"].add_theme_color_override(
				"font_color", Color.WHITE if have >= part["qtd"] else RED
			)
	var blocked: bool = not status["ok"] and status["faltando"].is_empty()
	row["reason"].text = status["motivo"] if blocked else ""
	row["root"].modulate.a = 0.55 if blocked else 1.0
	row["button"].disabled = not status["ok"]


func _button(text: String, pos: Vector2, button_size: Vector2) -> PixelButton:
	var button := PixelButton.new()
	button.position = pos
	button.setup(text, button_size, hud.make_label(text, 8))
	return button


## Botão desenhado em pixels exatos (o Button padrão cresce com a margem do tema).
class PixelButton:
	extends ColorRect

	signal pressed

	const LOOKS := {
		"normal": [Color("5a4636"), Color("8a6a4a"), Color("f4ead8")],
		"hover": [Color("6e5640"), Color("e2b33c"), Color("fff6e0")],
		"disabled": [Color("2c2420"), Color("3e3430"), Color("7a6e66")],
	}

	var disabled := false:
		set(value):
			disabled = value
			_paint()
	var _hover := false
	var _label: Label
	var _border: ReferenceRect

	func setup(text: String, button_size: Vector2, label: Label) -> void:
		size = button_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		_border = ReferenceRect.new()
		_border.size = button_size
		_border.editor_only = false
		_border.border_width = 1
		_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_border)
		_label = label
		_label.text = text
		_label.size = button_size
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
		mouse_entered.connect(
			func() -> void:
				_hover = true
				_paint()
		)
		mouse_exited.connect(
			func() -> void:
				_hover = false
				_paint()
		)
		gui_input.connect(_on_input)
		_paint()

	func _on_input(event: InputEvent) -> void:
		if disabled:
			return
		if (
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
		):
			pressed.emit()
			accept_event()

	func _paint() -> void:
		if _label == null:
			return
		var look: Array = LOOKS["disabled" if disabled else ("hover" if _hover else "normal")]
		color = look[0]
		_border.border_color = look[1]
		_label.add_theme_color_override("font_color", look[2])


static func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

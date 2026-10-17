class_name CraftingPanel
extends Control
## Painel de fabricação (tecla C): receitas agrupadas por estação, com o que falta e o porquê.
## Clique em "Fazer" para 1 unidade; com Shift, 5. A aba Experimentar mistura materiais sem receita.

signal craft_requested(recipe_id: String, qtd: int)
signal cancel_requested(index: int)
signal experiment_requested(station: String, mix: Dictionary)

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
var _scroll: ScrollContainer
var _tabs: Array[PixelButton] = []
var _lab: Control
var _lab_stations: HBoxContainer
var _lab_mix: HBoxContainer
var _lab_materials: GridContainer
var _lab_result: Label
var _lab_go: PixelButton
var _lab_signature := ""
var _station := ""
## O jogador escolheu a estação à mão (senão, segue a melhor que estiver por perto).
var _station_chosen := false
var _mix: Dictionary = {}
var _have: Dictionary = {}
var _known: Dictionary = {}
var _context: Dictionary = {}
var _schools_label: Label


func setup(game_data: DataStore, owner_hud: Hud) -> void:
	data = game_data
	hud = owner_hud
	position = Vector2(6, 20)
	size = Vector2(WIDTH, HEIGHT)
	var back := ColorRect.new()
	back.color = Color(0.105882, 0.0901961, 0.0784314, 0.9)
	back.size = size
	add_child(back)
	var title := hud.make_label("Fabricação  ·  C fecha", 8)
	title.position = Vector2(6, 2)
	add_child(title)
	for i in 2:
		var tab_x: float = [WIDTH - 136, WIDTH - 82][i]
		var tab_w: float = [52, 76][i]
		var tab := _button(["Receitas", "Experimentar"][i], Vector2(tab_x, 0), Vector2(tab_w, 14))
		tab.pressed.connect(_show_tab.bind(i))
		add_child(tab)
		_tabs.append(tab)
	_schools_label = hud.make_label("", 8)
	_schools_label.position = Vector2(100, 2)
	_schools_label.add_theme_color_override("font_color", Color("7ad8ff"))
	add_child(_schools_label)
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

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(4, 38)
	_scroll.size = Vector2(WIDTH - 8, HEIGHT - 42)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_list.custom_minimum_size = Vector2(WIDTH - 20, 0)
	_scroll.add_child(_list)
	for recipe_id in _ordered_recipes():
		_rows.append(_make_row(recipe_id))
	_build_lab()
	_show_tab(0)


## Resultado do último experimento (vindo do servidor).
func show_result(ok: bool, text: String) -> void:
	_lab_result.text = text
	_lab_result.add_theme_color_override("font_color", Color("86b85a") if ok else ORANGE)
	if ok:
		_mix.clear()
		_lab_signature = ""


func _show_tab(index: int) -> void:
	_scroll.visible = index == 0
	_lab.visible = index == 1
	for i in _tabs.size():
		_tabs[i].selected = i == index


# ---------------------------------------------------------------- experimentar


func _build_lab() -> void:
	_lab = Control.new()
	_lab.position = Vector2(4, 38)
	_lab.size = Vector2(WIDTH - 8, HEIGHT - 42)
	add_child(_lab)
	var help := hud.make_label(
		"Misture materiais numa estação. Errar gasta 1 de cada, mas dá pista.", 8
	)
	help.position = Vector2(2, 0)
	help.add_theme_color_override("font_color", QUIET)
	_lab.add_child(help)
	var station_label := hud.make_label("Estação:", 8)
	station_label.position = Vector2(2, 15)
	_lab.add_child(station_label)
	_lab_stations = HBoxContainer.new()
	_lab_stations.position = Vector2(48, 12)
	_lab_stations.add_theme_constant_override("separation", 2)
	_lab.add_child(_lab_stations)
	var mix_label := hud.make_label("Mistura:", 8)
	mix_label.position = Vector2(2, 41)
	_lab.add_child(mix_label)
	_lab_mix = HBoxContainer.new()
	_lab_mix.position = Vector2(48, 36)
	_lab_mix.add_theme_constant_override("separation", 2)
	_lab.add_child(_lab_mix)
	_lab_go = _button("Misturar", Vector2(WIDTH - 118, 38), Vector2(56, 16))
	_lab_go.pressed.connect(
		func() -> void:
			if not _mix.is_empty() and not _station.is_empty():
				experiment_requested.emit(_station, _mix.duplicate())
	)
	_lab.add_child(_lab_go)
	var clear := _button("Limpar", Vector2(WIDTH - 58, 38), Vector2(46, 16))
	clear.pressed.connect(
		func() -> void:
			_mix.clear()
			_lab_signature = ""
			_refresh_lab()
	)
	_lab.add_child(clear)
	_lab_result = hud.make_label("", 8)
	_lab_result.position = Vector2(2, 60)
	_lab_result.size = Vector2(WIDTH - 16, 24)
	_lab_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lab.add_child(_lab_result)
	var have_label := hud.make_label(
		"Seus materiais (clique: +1, Shift: +5; clique na mistura tira)", 8
	)
	have_label.position = Vector2(2, 86)
	have_label.add_theme_color_override("font_color", QUIET)
	_lab.add_child(have_label)
	_lab_materials = GridContainer.new()
	_lab_materials.position = Vector2(2, 98)
	_lab_materials.columns = 14
	_lab_materials.add_theme_constant_override("h_separation", 2)
	_lab_materials.add_theme_constant_override("v_separation", 2)
	_lab.add_child(_lab_materials)


func _refresh_lab(stations: Dictionary = {}) -> void:
	if not stations.is_empty():
		var usable: Array = []
		for id in STATION_ORDER:
			if stations.has(id) and Experiment.STATION_AREA.has(id):
				usable.append(id)
		if not _station in usable or not _station_chosen:
			_station = usable.back() if not usable.is_empty() else "mao"
			_station_chosen = false
		_lab.set_meta("stations", usable)
	for id in _mix.keys():
		_mix[id] = mini(_mix[id], int(_have.get(id, 0)))
		if _mix[id] <= 0:
			_mix.erase(id)
	var usable_now: Array = _lab.get_meta("stations", ["mao"])
	var signature := "%s|%s|%s|%s" % [str(usable_now), _station, str(_mix), str(_have)]
	if signature == _lab_signature:
		return
	_lab_signature = signature
	_clear(_lab_stations)
	for id in usable_now:
		var chip := _chip(id, "", id == _station)
		chip.tooltip_text = data.display_name(id)
		chip.pressed.connect(
			func() -> void:
				_station = id
				_station_chosen = true
				_lab_signature = ""
				_refresh_lab()
		)
		_lab_stations.add_child(chip)
	_clear(_lab_mix)
	for i in Experiment.MAX_PARTS:
		var ids: Array = _mix.keys()
		if i < ids.size():
			var id: String = ids[i]
			var chip := _chip(id, str(_mix[id]), false)
			chip.tooltip_text = data.display_name(id)
			chip.pressed.connect(
				func() -> void:
					_mix[id] -= 1
					if _mix[id] <= 0:
						_mix.erase(id)
					_lab_signature = ""
					_refresh_lab()
			)
			_lab_mix.add_child(chip)
		else:
			_lab_mix.add_child(_chip("", "", false))
	_lab_go.disabled = _mix.is_empty()
	_clear(_lab_materials)
	var ids: Array = _have.keys()
	ids.sort_custom(
		func(a: String, b: String) -> bool: return data.display_name(a) < data.display_name(b)
	)
	for id in ids:
		var chip := _chip(id, str(_have[id]), _mix.has(id))
		chip.tooltip_text = data.display_name(id)
		chip.pressed.connect(
			func() -> void:
				if not _mix.has(id) and _mix.size() >= Experiment.MAX_PARTS:
					show_result(false, "Cabem até %d materiais na mistura." % Experiment.MAX_PARTS)
					return
				var step := 5 if Input.is_key_pressed(KEY_SHIFT) else 1
				_mix[id] = mini(int(_mix.get(id, 0)) + step, int(_have[id]))
				_lab_signature = ""
				_refresh_lab()
		)
		_lab_materials.add_child(chip)


func _chip(id: String, count: String, selected: bool) -> IconChip:
	var chip := IconChip.new()
	chip.setup(
		hud.icon_for(id) if not id.is_empty() else null, count, selected, hud.make_label("", 8)
	)
	return chip


static func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


## Atualiza com o estado atual: espaços do inventário, XP, estações por perto e fila.
func refresh(
	slots: Array,
	mastery: Dictionary,
	stations: Dictionary,
	queue: Array,
	known: Dictionary = {},
	schools: Dictionary = {}
) -> void:
	_known = known
	_context = {"escolas": schools}
	var inventory := Inventory.new(data)
	inventory.load_array(slots)
	_have.clear()
	for slot in slots:
		if not slot.is_empty() and data.materials.has(slot["id"]):
			_have[slot["id"]] = int(_have.get(slot["id"], 0)) + int(slot["qtd"])
	var levels: PackedStringArray = []
	for area in Mastery.AREAS:
		var xp := int(mastery.get(area, 0))
		levels.append("%s %d" % [Mastery.display_name(area), Mastery.level_for(xp)])
	_mastery_label.text = "Maestria: " + "  ·  ".join(levels)
	var awake: PackedStringArray = []
	for school in schools:
		awake.append(Mastery.display_name(school))
	_schools_label.text = "Escola: " + ", ".join(awake) if not awake.is_empty() else ""
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
	_refresh_lab(stations)


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
		"time": time,
	}


func _paint_row(
	row: Dictionary, inventory: Inventory, mastery: Dictionary, stations: Dictionary
) -> void:
	var recipe: Dictionary = data.recipes[row["id"]]
	var status := Crafting.status(recipe, data, inventory, mastery, _known, stations, _context)
	var xp := int(mastery.get(recipe["maestria"], 0))
	row["time"].text = "%ss" % _fmt(Mastery.craft_seconds(float(recipe["tempo_s"]), xp))
	var secret: bool = recipe["desbloqueio"] == "experimentacao"
	var output: Dictionary = recipe["saidas"][0]
	if secret and not _known.has(row["id"]):
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
		"selected": [Color("8a6a4a"), Color("f2d36b"), Color("fff6e0")],
	}

	var selected := false:
		set(value):
			selected = value
			_paint()

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
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
		# Ocupa exatamente o botão (o tamanho do Label sozinho cresce com a fonte padrão).
		_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		var state := "hover" if _hover else "normal"
		if selected:
			state = "selected"
		elif disabled:
			state = "disabled"
		var look: Array = LOOKS[state]
		color = look[0]
		_border.border_color = look[1]
		_label.add_theme_color_override("font_color", look[2])


## Quadrado com ícone e contagem (estação, material, espaço da mistura).
class IconChip:
	extends ColorRect

	signal pressed

	func setup(texture: Texture2D, count: String, selected: bool, label: Label) -> void:
		custom_minimum_size = Vector2(20, 20)
		size = custom_minimum_size
		color = Color("8a6a4a") if selected else Color("2c2420")
		mouse_filter = Control.MOUSE_FILTER_STOP
		var border := ReferenceRect.new()
		border.size = size
		border.editor_only = false
		border.border_width = 1
		border.border_color = Color("f2d36b") if selected else Color("57432f")
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(border)
		if texture != null:
			var icon := TextureRect.new()
			icon.texture = texture
			icon.position = Vector2(2, 2)
			icon.size = Vector2(16, 16)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(icon)
		if not count.is_empty():
			label.text = count
			label.position = Vector2(0, 9)
			label.size = Vector2(19, 10)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			add_child(label)
		gui_input.connect(
			func(event: InputEvent) -> void:
				if (
					event is InputEventMouseButton
					and event.pressed
					and event.button_index == MOUSE_BUTTON_LEFT
				):
					pressed.emit()
					accept_event()
		)


static func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

class_name Hud
extends CanvasLayer
## Interface na tela: barra de atalhos (10 espaços), inventário (E), avisos e o nome do item.

signal slot_selected(index: int)
signal slots_swapped(a: int, b: int)

const ICONS_PATH := "res://art/itens/icones.png"
const ICONS_META := "res://art/itens/icones.json"
const SLOT_PATH := "res://art/ui/espaco.png"
const SLOT := 20
const GAP := 2
const COLUMNS := 10
const TOAST_SECONDS := 3.5
const COLORS := {
	"info": Color("f7f6f0"),
	"aviso": Color("f28a5c"),
	"descoberta": Color("f2d36b"),
}

var slots: Array = []
var selected: int = 0
var data: DataStore

var _icon_texture: Texture2D
var _slot_texture: Texture2D
var _icon_index: Dictionary = {}
var _icon_columns: int = 16
var _hotbar := Control.new()
var _panel := Control.new()
var _hotbar_cells: Array[Dictionary] = []
var _panel_cells: Array[Dictionary] = []
var _toasts := VBoxContainer.new()
var _item_label := Label.new()
var _item_label_timer: float = 0.0
var _picked: int = -1


func setup(game_data: DataStore) -> void:
	data = game_data
	layer = 10
	_icon_texture = load(ICONS_PATH)
	_slot_texture = load(SLOT_PATH)
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(ICONS_META))
	if typeof(meta) == TYPE_DICTIONARY:
		_icon_index = meta["icones"]
		_icon_columns = int(meta["colunas"])

	var width := COLUMNS * SLOT + (COLUMNS - 1) * GAP
	_hotbar.position = Vector2((640 - width) / 2.0, 360 - SLOT - 6)
	add_child(_hotbar)
	for i in COLUMNS:
		_hotbar_cells.append(_make_cell(_hotbar, Vector2(i * (SLOT + GAP), 0), i, true))

	_panel.visible = false
	var rows := Inventory.SIZE / COLUMNS
	var panel_h := rows * SLOT + (rows - 1) * GAP + 22
	_panel.position = Vector2((640 - width) / 2.0 - 6, 360 - SLOT - 14 - panel_h)
	add_child(_panel)
	var back := ColorRect.new()
	back.color = Color(0.105882, 0.0901961, 0.0784314, 0.86)
	back.size = Vector2(width + 12, panel_h)
	_panel.add_child(back)
	var title := _label("Inventário  ·  clique em dois espaços para trocar", 8)
	title.position = Vector2(6, 2)
	_panel.add_child(title)
	for i in Inventory.SIZE:
		var pos := Vector2(6 + (i % COLUMNS) * (SLOT + GAP), 16 + (i / COLUMNS) * (SLOT + GAP))
		_panel_cells.append(_make_cell(_panel, pos, i, false))

	_item_label.add_theme_font_size_override("font_size", 8)
	_style(_item_label)
	_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_label.size = Vector2(240, 12)
	_item_label.position = Vector2(200, 360 - SLOT - 20)
	add_child(_item_label)

	_toasts.position = Vector2(6, 236)
	_toasts.size = Vector2(300, 100)
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	add_child(_toasts)


func set_inventory(new_slots: Array, new_selected: int) -> void:
	var changed_selection := new_selected != selected
	slots = new_slots
	selected = new_selected
	for i in _hotbar_cells.size():
		_paint(_hotbar_cells[i], _slot(i), i == selected)
	for i in _panel_cells.size():
		_paint(_panel_cells[i], _slot(i), i == _picked)
	if changed_selection:
		show_item_name()


func selected_item() -> Dictionary:
	return _slot(selected)


func toggle_inventory() -> void:
	_panel.visible = not _panel.visible
	_picked = -1
	set_inventory(slots, selected)


func inventory_open() -> bool:
	return _panel.visible


func toast(text: String, kind: String = "info") -> void:
	var label := _label(text, 8)
	label.add_theme_color_override("font_color", COLORS.get(kind, COLORS["info"]))
	_toasts.add_child(label)
	while _toasts.get_child_count() > 5:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	var tween := create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func show_item_name() -> void:
	var slot := _slot(selected)
	if slot.is_empty():
		_item_label.text = ""
		return
	var text := data.display_name(slot["id"])
	if slot.has("durabilidade"):
		var item: Dictionary = data.get_item(slot["id"])
		text += "  (%d/%d)" % [slot["durabilidade"], int(item.get("durabilidade", 1))]
	elif slot["qtd"] > 1:
		text += "  ×%d" % slot["qtd"]
	_item_label.text = text
	_item_label.modulate.a = 1.0
	_item_label_timer = 2.5


func _process(delta: float) -> void:
	if _item_label_timer > 0.0:
		_item_label_timer -= delta
		if _item_label_timer <= 0.6:
			_item_label.modulate.a = maxf(_item_label_timer / 0.6, 0.0)


func _slot(index: int) -> Dictionary:
	return slots[index] if index >= 0 and index < slots.size() else {}


func _make_cell(parent: Control, pos: Vector2, index: int, hotbar: bool) -> Dictionary:
	var frame := TextureRect.new()
	frame.texture = _region(_slot_texture, Rect2(0, 0, SLOT, SLOT))
	frame.position = pos
	frame.size = Vector2(SLOT, SLOT)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(_on_cell_input.bind(index, hotbar))
	parent.add_child(frame)
	var icon := TextureRect.new()
	icon.position = Vector2(2, 2)
	icon.size = Vector2(16, 16)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	var count := _label("", 8)
	count.position = Vector2(1, 9)
	count.size = Vector2(18, 10)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	frame.add_child(count)
	var wear := ColorRect.new()
	wear.position = Vector2(3, 16)
	wear.size = Vector2(14, 1)
	wear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(wear)
	if hotbar:
		var number := _label(str((index + 1) % 10), 8)
		number.position = Vector2(2, -2)
		number.modulate = Color(1, 1, 1, 0.55)
		frame.add_child(number)
	return {"frame": frame, "icon": icon, "count": count, "wear": wear}


func _paint(cell: Dictionary, slot: Dictionary, highlighted: bool) -> void:
	cell["frame"].texture = _region(_slot_texture, Rect2(SLOT if highlighted else 0, 0, SLOT, SLOT))
	if slot.is_empty():
		cell["icon"].texture = null
		cell["count"].text = ""
		cell["wear"].visible = false
		return
	cell["icon"].texture = _icon(slot["id"])
	cell["count"].text = str(slot["qtd"]) if slot["qtd"] > 1 else ""
	cell["wear"].visible = slot.has("durabilidade")
	if slot.has("durabilidade"):
		var full := float(data.get_item(slot["id"]).get("durabilidade", 1))
		var ratio := clampf(slot["durabilidade"] / full, 0.0, 1.0)
		cell["wear"].size.x = maxf(1.0, 14.0 * ratio)
		cell["wear"].color = (
			Color("86b85a") if ratio > 0.5 else Color("e2b33c") if ratio > 0.2 else Color("e0503a")
		)


func _icon(id: String) -> Texture2D:
	if not _icon_index.has(id):
		return null
	var index := int(_icon_index[id])
	return _region(
		_icon_texture, Rect2((index % _icon_columns) * 16, (index / _icon_columns) * 16, 16, 16)
	)


func _on_cell_input(event: InputEvent, index: int, hotbar: bool) -> void:
	if not (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		return
	get_viewport().set_input_as_handled()
	if hotbar and not _panel.visible:
		slot_selected.emit(index)
		return
	if _picked < 0:
		if not _slot(index).is_empty():
			_picked = index
			set_inventory(slots, selected)
	else:
		if _picked != index:
			slots_swapped.emit(_picked, index)
		_picked = -1
		set_inventory(slots, selected)


static func _region(texture: Texture2D, rect: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = rect
	return atlas


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	_style(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _style(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color("1b1714"))
	label.add_theme_constant_override("outline_size", 4)

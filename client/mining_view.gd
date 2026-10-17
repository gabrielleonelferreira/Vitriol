class_name MiningView
extends Node2D
## Moldura no tile sob o mouse (branca = dá para minerar ou colocar, vermelha = não) e as
## rachaduras do bloco que está sendo minerado.

const CURSOR_PATH := "res://art/ui/cursor.png"
const CRACKS_PATH := "res://art/tiles/rachaduras.png"
const STAGES := 4

var _cursor := Sprite2D.new()
var _crack := Sprite2D.new()
var _cursor_texture: Texture2D
var _crack_texture: Texture2D


func _ready() -> void:
	z_index = 30
	_cursor_texture = load(CURSOR_PATH)
	_crack_texture = load(CRACKS_PATH)
	for sprite in [_crack, _cursor]:
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.region_enabled = true
		sprite.visible = false
		add_child(sprite)
	_cursor.texture = _cursor_texture
	_crack.texture = _crack_texture
	_crack.z_index = -1


func show_cursor(tile: Vector2i, allowed: bool) -> void:
	var size := WorldGrid.TILE_SIZE + 2
	_cursor.region_rect = Rect2(0 if allowed else size, 0, size, size)
	_cursor.position = Vector2(tile * WorldGrid.TILE_SIZE) - Vector2(1, 1)
	_cursor.visible = true


func hide_cursor() -> void:
	_cursor.visible = false


## progress de 0 a 1; negativo esconde.
func show_progress(tile: Vector2i, progress: float) -> void:
	if progress < 0.0:
		_crack.visible = false
		return
	var stage := clampi(int(progress * STAGES), 0, STAGES - 1)
	_crack.region_rect = Rect2(
		stage * WorldGrid.TILE_SIZE, 0, WorldGrid.TILE_SIZE, WorldGrid.TILE_SIZE
	)
	_crack.position = Vector2(tile * WorldGrid.TILE_SIZE)
	_crack.visible = true

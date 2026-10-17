class_name Background
extends Node2D
## Fundo da superfície: céu fixo e três planos com paralaxe (montanhas, colinas, nuvens).
## Os planos acompanham o mundo na vertical, para o horizonte ficar na altura do chão, e
## andam mais devagar na horizontal quanto mais longe estão.

const SKY_PATH := "res://art/fundo/ceu.png"
## [arquivo, quanto acompanha a câmera na horizontal, altura (px) do topo da imagem acima da
## superfície média do mundo]. As colinas descem bem abaixo do chão para nunca deixar vão.
const PLANES := [
	["res://art/fundo/nuvens.png", 0.08, 215],
	["res://art/fundo/montanhas.png", 0.15, 175],
	["res://art/fundo/colinas.png", 0.35, 95],
]

var _sky_layer := CanvasLayer.new()
var _sky: TextureRect


func build(_grid: WorldGrid) -> void:
	_sky_layer.layer = -10
	_sky_layer.name = "Ceu"
	add_child(_sky_layer)
	var sky := TextureRect.new()
	_sky = sky
	sky.texture = load(SKY_PATH)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sky_layer.add_child(sky)

	for plane in PLANES:
		var texture: Texture2D = load(plane[0])
		var parallax := Parallax2D.new()
		parallax.name = plane[0].get_file().get_basename()
		parallax.scroll_scale = Vector2(plane[1], 1.0)
		parallax.repeat_size = Vector2(texture.get_width(), 0)
		parallax.repeat_times = 3
		parallax.z_index = -20
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var surface_y := WorldGenerator.SURFACE_BASE * WorldGrid.TILE_SIZE
		sprite.position = Vector2(0, surface_y - plane[2])
		parallax.add_child(sprite)
		add_child(parallax)


## Escurece o céu à noite (0 = noite, 1 = dia). Os planos de paralaxe já escurecem com a luz.
func set_daylight(value: float) -> void:
	if _sky:
		_sky.modulate = Color(0.2, 0.24, 0.42).lerp(Color.WHITE, value)

extends SceneTree
## Exporta o mapa do mundo gerado como imagem (1 pixel por tile), para conferir a geração.
## Uso: godot --headless --path . -s res://world/export_map.gd -- <semente> <saida.png>

const COLORS := {
	"ar": Color("9fd3f0"),
	"grama": Color("4f8a4a"),
	"tronco": Color("57432f"),
	"folhas": Color("2f5a3a"),
	"agua": Color("2d4f80"),
	"rocha_base": Color("0f0d0c"),
	"terra": Color("74593d"),
	"argila": Color("b8801a"),
	"areia": Color("f2d36b"),
	"cascalho": Color("949ca3"),
	"silex": Color("3d3128"),
	"calcario": Color("bfc5c9"),
	"carvao_mineral": Color("1b1714"),
	"malaquita": Color("86b85a"),
	"limonita": Color("8a5a12"),
	"xisto": Color("6b737c"),
	"hematita": Color("8a2224"),
	"quartzo": Color("f7f6f0"),
	"acantita": Color("4f86c0"),
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var world_seed := int(args[0]) if args.size() > 0 else 20261016
	var output := args[1] if args.size() > 1 else "user://mapa.png"
	var data := DataStore.new()
	if not data.load_all():
		printerr(", ".join(data.errors))
		quit(1)
		return
	var grid := WorldGenerator.new().generate(world_seed, data)
	var image := Image.create(grid.width, grid.height, false, Image.FORMAT_RGB8)
	for y in grid.height:
		for x in grid.width:
			var name := grid.tile_name(x, y)
			var color: Color = COLORS.get(name, Color.MAGENTA)
			if name == "ar" and grid.get_wall(x, y) != 0:
				color = Color("2b231d")
			image.set_pixel(x, y, color)
	image.save_png(output)
	print("mapa salvo em ", ProjectSettings.globalize_path(output))
	data.free()
	quit()

extends TestCase
## Onda 5C: os sons gerados existem, carregam e cobrem tudo que o jogo toca.

## Sons que o cliente pede por nome (main.gd, player.gd, world_view.gd).
const USED := [
	"minerar_pedra",
	"minerar_terra",
	"minerar_madeira",
	"minerar_folhas",
	"quebrar_pedra",
	"quebrar_terra",
	"quebrar_madeira",
	"colocar",
	"passo_grama",
	"passo_pedra",
	"passo_madeira",
	"pulo",
	"salto_vento",
	"trovao",
	"raio_invocado",
	"chuva",
	"fogo",
	"pronto",
	"descoberta",
	"nivel",
	"clique",
	"porta_abre",
	"porta_fecha",
	"falhou",
	"escada",
]


func test_todos_os_sons_carregam() -> void:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(Sfx.MANIFEST))
	check(typeof(meta) == TYPE_DICTIONARY, "audio/sons.json existe")
	var sounds: Dictionary = meta["sons"]
	for name in USED:
		check(sounds.has(name), "som '%s' existe" % name)
	var broken: PackedStringArray = []
	for name in sounds:
		for file in sounds[name]["arquivos"]:
			var stream: Variant = load("res://audio/" + str(file))
			if not stream is AudioStream:
				broken.append(str(file))
	check(broken.is_empty(), "todos carregam (%s)" % ", ".join(broken))
	check(sounds["chuva"]["loop"] and sounds["fogo"]["loop"], "chuva e fogo são contínuos")


func test_familias_de_material() -> void:
	check_eq(Sfx.family("grama"), "terra", "grama soa como terra")
	check_eq(Sfx.family("tronco"), "madeira", "tronco soa como madeira")
	check_eq(Sfx.family("malaquita"), "pedra", "minério soa como pedra")
	check_eq(Sfx.family("folhas"), "folhas", "folhas farfalham")

class_name Sfx
extends Node
## Sons do jogo: efeitos curtos (com variação de tom e posição no mundo) e sons contínuos
## (chuva, fogo) com volume que sobe e desce suave. Arquivos gerados por tools/audio/gerar_sons.py.

const MANIFEST := "res://audio/sons.json"
const WORLD_VOICES := 10
const UI_VOICES := 4
## Volume de cada som em dB (0 = como foi gerado).
const VOLUME := {
	"passo_grama": -10.0,
	"passo_pedra": -10.0,
	"passo_madeira": -10.0,
	"pulo": -8.0,
	"escada": -10.0,
	"minerar_folhas": -6.0,
	"clique": -8.0,
	"trovao": -2.0,
}
## Alcance (px) dos sons no mundo.
const RANGE := 520.0

var enabled: bool = true
var _streams: Dictionary = {}
var _loops_info: Dictionary = {}
var _world: Array[AudioStreamPlayer2D] = []
var _ui: Array[AudioStreamPlayer] = []
var _next_world: int = 0
var _next_ui: int = 0
var _loops: Dictionary = {}
var _loop_target: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if typeof(meta) != TYPE_DICTIONARY:
		push_warning("Sfx: sem audio/sons.json; o jogo fica mudo.")
		return
	for name in meta["sons"]:
		var info: Dictionary = meta["sons"][name]
		var list: Array[AudioStream] = []
		for file in info["arquivos"]:
			var stream: AudioStream = load("res://audio/" + str(file))
			if stream != null:
				list.append(stream)
		_streams[name] = list
		_loops_info[name] = bool(info.get("loop", false))
	for i in WORLD_VOICES:
		var voice := AudioStreamPlayer2D.new()
		voice.max_distance = RANGE
		voice.attenuation = 1.6
		add_child(voice)
		_world.append(voice)
	for i in UI_VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_ui.append(voice)


func has_sound(name: String) -> bool:
	return _streams.has(name) and not _streams[name].is_empty()


## Toca um efeito. Com `at` (posição no mundo, px) o som vem daquele lugar.
func play(
	name: String, at: Variant = null, volume_db: float = 0.0, pitch_spread: float = 0.08
) -> void:
	if not enabled or not has_sound(name):
		return
	var list: Array = _streams[name]
	var stream: AudioStream = list[_rng.randi_range(0, list.size() - 1)]
	var pitch := 1.0 + _rng.randf_range(-pitch_spread, pitch_spread)
	var db: float = volume_db + float(VOLUME.get(name, 0.0))
	if at is Vector2:
		var voice := _world[_next_world]
		_next_world = (_next_world + 1) % _world.size()
		voice.stream = stream
		voice.global_position = at
		voice.pitch_scale = pitch
		voice.volume_db = db
		voice.play()
	else:
		var voice := _ui[_next_ui]
		_next_ui = (_next_ui + 1) % _ui.size()
		voice.stream = stream
		voice.pitch_scale = pitch
		voice.volume_db = db
		voice.play()


## Som contínuo: `level` de 0 (mudo) a 1 (volume cheio). O volume chega lá aos poucos.
func set_loop(name: String, level: float) -> void:
	if not has_sound(name):
		return
	if not _loops.has(name):
		var voice := AudioStreamPlayer.new()
		var stream: AudioStream = _streams[name][0]
		if stream is AudioStreamWAV:
			var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = wav.data.size() / 2
			stream = wav
		voice.stream = stream
		voice.volume_db = -60.0
		add_child(voice)
		_loops[name] = voice
	_loop_target[name] = clampf(level, 0.0, 1.0) if enabled else 0.0


func _process(delta: float) -> void:
	for name in _loops:
		var voice: AudioStreamPlayer = _loops[name]
		var target: float = _loop_target.get(name, 0.0)
		var current := db_to_linear(voice.volume_db) if voice.playing else 0.0
		current = move_toward(current, target, delta * 0.8)
		if current <= 0.001:
			if voice.playing:
				voice.stop()
			voice.volume_db = -60.0
			continue
		voice.volume_db = linear_to_db(current)
		if not voice.playing:
			voice.play()


## Família de som de um tile (para minerar, quebrar e pisar).
static func family(tile_name: String) -> String:
	match tile_name:
		"terra", "grama", "areia", "argila", "cascalho":
			return "terra"
		"tronco", "madeira", "bancada", "porta", "porta_alto", "plataforma", "escada":
			return "madeira"
		"folhas", "fibra", "corda", "pena_caida", "tocha":
			return "folhas"
		_:
			return "pedra"

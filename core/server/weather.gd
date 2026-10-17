class_name Weather
extends RefCounted
## Clima do mundo: tempestades que chegam de tempos em tempos, com raios e, uma vez por
## tempestade, a queda de uma Pena de Ave-Trovão (fonte provisória do MVP).
##
## Só decide QUANDO as coisas acontecem; o GameServer decide ONDE e aplica no mundo.

## Intervalo entre tempestades e duração, em segundos reais (o dia tem 20 min).
const GAP_MIN := 540.0
const GAP_MAX := 1080.0
const FIRST_GAP_MIN := 300.0
const FIRST_GAP_MAX := 480.0
const STORM_MIN := 150.0
const STORM_MAX := 240.0
## Intervalo entre raios durante a tempestade.
const BOLT_MIN := 2.5
const BOLT_MAX := 7.0
## Em que fração da tempestade a pena cai.
const FEATHER_AT := 0.4

const START := "inicio"
const END := "fim"
const BOLT := "raio"
const FEATHER := "pena"

var storm: bool = false
## Segundos até a próxima mudança (início ou fim da tempestade).
var timer: float = 0.0
var storm_length: float = 0.0
var feather_dropped: bool = false
var _bolt_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value * 7919 + 13
	timer = _rng.randf_range(FIRST_GAP_MIN, FIRST_GAP_MAX)


## Avança o clima. Devolve o que aconteceu neste passo (START, END, BOLT, FEATHER).
func step(delta: float) -> Array[String]:
	var happened: Array[String] = []
	timer -= delta
	if not storm:
		if timer <= 0.0:
			start_storm()
			happened.append(START)
		return happened
	if timer <= 0.0:
		storm = false
		timer = _rng.randf_range(GAP_MIN, GAP_MAX)
		happened.append(END)
		return happened
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = _rng.randf_range(BOLT_MIN, BOLT_MAX)
		happened.append(BOLT)
	if not feather_dropped and timer <= storm_length * (1.0 - FEATHER_AT):
		feather_dropped = true
		happened.append(FEATHER)
	return happened


## Começa uma tempestade agora (também usado pelo atalho de teste F7).
func start_storm() -> void:
	storm = true
	storm_length = _rng.randf_range(STORM_MIN, STORM_MAX)
	timer = storm_length
	feather_dropped = false
	_bolt_timer = _rng.randf_range(1.0, 3.0)


## 0 a 1: quanto falta da tempestade (para o cliente escurecer o céu suavemente).
func intensity() -> float:
	return 1.0 if storm else 0.0


func randi_range(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func randf() -> float:
	return _rng.randf()

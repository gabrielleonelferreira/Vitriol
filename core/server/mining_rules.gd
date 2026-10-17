class_name MiningRules
extends RefCounted
## Regras de mineração: alcance, força da ferramenta e tempo para quebrar.

## Alcance em pixels, do centro do corpo ao centro do tile.
const REACH := 5.5 * WorldGrid.TILE_SIZE
## Força das mãos (minera blocos de dureza até 1) e quanto elas são mais lentas.
const HAND_POWER := 1.0
const HAND_SPEED := 0.6
## Tempo-base em segundos: 0,2 s + 0,35 s por ponto de dureza.
const BASE_TIME := 0.2
const TIME_PER_HARDNESS := 0.35
## Cada ponto de força acima do necessário deixa 25% mais rápido.
const BONUS_PER_POWER := 0.25

## Garimpo com bateia no cascalho: [item, chance acumulada].
const PANNING := [["cassiterita", 0.6], ["ouro_aluvial", 0.75], ["cascalho", 1.0]]


## Segundos para quebrar um bloco desta dureza com esta força. INF = não dá.
static func break_time(hardness: float, power: float, is_hand: bool) -> float:
	if hardness == INF or hardness > power:
		return INF
	var speed := HAND_SPEED if is_hand else 1.0 + maxf(0.0, power - hardness) * BONUS_PER_POWER
	return (BASE_TIME + hardness * TIME_PER_HARDNESS) / speed


## Centro do corpo a partir dos pés.
static func body_center(feet: Vector2) -> Vector2:
	return feet - Vector2(0, PlayerMotor.HITBOX.y * 0.5)


static func in_reach(feet: Vector2, tile: Vector2i) -> bool:
	var center := (Vector2(tile) + Vector2(0.5, 0.5)) * WorldGrid.TILE_SIZE
	return body_center(feet).distance_to(center) <= REACH

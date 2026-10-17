class_name Mastery
extends RefCounted
## Maestria por área: XP de descobertas e de receitas feitas, e níveis que liberam receitas.
## Cada nível acima do 1 deixa as receitas da área 6% mais rápidas e as ferramentas feitas nela 5%
## mais duráveis (nível 10: 54% mais rápido, 45% mais durável).

const AREAS := ["metalurgia", "quimica", "vidraria", "construcao", "arcano"]
const NAMES := {
	"metalurgia": "Metalurgia",
	"quimica": "Química",
	"vidraria": "Vidraria",
	"construcao": "Construção",
	"arcano": "Arcano",
}
## XP total para chegar a cada nível: nível 1 = 0, nível 2 = 20, nível 3 = 60...
const LEVEL_XP := [0, 20, 60, 130, 240, 400, 620, 900, 1250, 1700]
const SPEED_PER_LEVEL := 0.06
const DURABILITY_PER_LEVEL := 0.05


static func level_for(xp: int) -> int:
	var level := 1
	for i in LEVEL_XP.size():
		if xp >= LEVEL_XP[i]:
			level = i + 1
	return level


## XP que falta para o próximo nível (0 no nível máximo).
static func xp_to_next(xp: int) -> int:
	var level := level_for(xp)
	if level >= LEVEL_XP.size():
		return 0
	return LEVEL_XP[level] - xp


## Quantas vezes mais rápido que a receita base, para quem tem `xp` na área.
static func speed_factor(xp: int) -> float:
	return 1.0 + SPEED_PER_LEVEL * (level_for(xp) - 1)


## Tempo real de uma receita de `base_seconds` para quem tem `xp` na área.
static func craft_seconds(base_seconds: float, xp: int) -> float:
	return base_seconds / speed_factor(xp)


## Durabilidade de uma ferramenta feita por quem tem `xp` na área.
static func durability_for(base: int, xp: int) -> int:
	return roundi(base * (1.0 + DURABILITY_PER_LEVEL * (level_for(xp) - 1)))


static func display_name(area: String) -> String:
	return NAMES.get(area, area.capitalize())

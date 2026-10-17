class_name Mastery
extends RefCounted
## Maestria por área: XP de descobertas e de receitas feitas, e níveis que liberam receitas.
## (O bônus de velocidade e resistência por nível entra na Onda 5.)

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


static func display_name(area: String) -> String:
	return NAMES.get(area, area.capitalize())

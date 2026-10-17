class_name SaveGame
extends RefCounted
## Grava e lê o mundo e os jogadores em user://mundos/<nome>/mundo.json.
##
## A gravação é segura: escreve num arquivo temporário e só depois troca pelo atual, mantendo
## a versão anterior como .bak. Se o jogo fechar no meio, o save antigo continua inteiro.

const VERSION := 1
const ROOT := "user://mundos"


static func path_for(world_name: String) -> String:
	return "%s/%s/mundo.json" % [ROOT, world_name]


static func exists(world_name: String) -> bool:
	return FileAccess.file_exists(path_for(world_name))


static func write(world_name: String, world: WorldState, players: Dictionary) -> Error:
	var path := path_for(world_name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var payload := {
		"versao": VERSION,
		"salvo_em": Time.get_datetime_string_from_system(),
		"mundo": world.to_save(),
		"jogadores": players,
	}
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path)


## Lê o save. Devolve {} se não existir ou estiver ilegível (tenta o .bak nesse caso).
static func read(world_name: String) -> Dictionary:
	var path := path_for(world_name)
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if typeof(parsed) == TYPE_DICTIONARY and int(parsed.get("versao", 0)) == VERSION:
			return parsed
		push_warning("SaveGame: %s ilegível ou de outra versão" % candidate)
	return {}


static func delete(world_name: String) -> void:
	var path := path_for(world_name)
	for candidate in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)

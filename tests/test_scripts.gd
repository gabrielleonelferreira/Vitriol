extends TestCase
## Todo script do jogo compila (pega erros em scripts que nenhum outro teste carrega).

const SKIP := ["res://.godot", "res://tests"]


func test_todos_os_scripts_compilam() -> void:
	var broken: PackedStringArray = []
	var total := 0
	for path in _scripts("res://"):
		total += 1
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			broken.append(path)
	check(total > 15, "encontrou os scripts (%d)" % total)
	check(broken.is_empty(), "scripts com erro: %s" % ", ".join(broken))


func _scripts(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for skip in SKIP:
		if dir.begins_with(skip):
			return found
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		if FileAccess.file_exists(dir.path_join(sub).path_join(".gdignore")):
			continue
		found.append_array(_scripts(dir.path_join(sub)))
	return found

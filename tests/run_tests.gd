extends SceneTree
## Executa todos os testes de res://tests/test_*.gd.
## Rodar: godot --headless --path . -s res://tests/run_tests.gd
## Filtrar: godot --headless --path . -s res://tests/run_tests.gd -- mundo

const TEST_DIR := "res://tests"


func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		filter = args[0]

	var total_failures := 0
	var total_tests := 0
	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		if file == "test_case.gd":
			continue
		var script: GDScript = load("%s/%s" % [TEST_DIR, file])
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			if not filter.is_empty() and not (file + ":" + name).contains(filter):
				continue
			var case: TestCase = script.new()
			var started := Time.get_ticks_msec()
			case.call(name)
			var elapsed := Time.get_ticks_msec() - started
			total_tests += 1
			if case.failures.is_empty():
				print("  ok    %s:%s (%d verificações, %d ms)" % [file, name, case.checks, elapsed])
			else:
				total_failures += 1
				printerr("  FALHA %s:%s" % [file, name])
				for failure in case.failures:
					printerr("        - " + failure)
			if case.has_method("cleanup"):
				case.call("cleanup")

	if total_failures == 0:
		print("OK: %d testes passaram" % total_tests)
	else:
		printerr("%d de %d testes falharam" % [total_failures, total_tests])
	quit(1 if total_failures > 0 else 0)

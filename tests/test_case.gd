class_name TestCase
extends RefCounted
## Base dos testes. Cada método que começa com "test_" é um teste.

var failures: PackedStringArray = []
var checks: int = 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func check_eq(actual: Variant, expected: Variant, label: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("%s (esperado %s, veio %s)" % [label, str(expected), str(actual)])

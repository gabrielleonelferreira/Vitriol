extends TestCase
## Inventário.

var _data: DataStore


func _init() -> void:
	_data = DataStore.new()
	_data.load_all()


func cleanup() -> void:
	_data.free()


func test_empilha_ate_99() -> void:
	var inv := Inventory.new(_data)
	check_eq(inv.add("terra", 150), 0, "150 terras cabem")
	check_eq(inv.get_slot(0)["qtd"], 99, "primeira pilha cheia")
	check_eq(inv.get_slot(1)["qtd"], 51, "resto na segunda")
	check_eq(inv.count("terra"), 150, "conta tudo")
	inv.add("terra", 10)
	check_eq(inv.get_slot(1)["qtd"], 61, "completa a pilha existente antes de abrir outra")


func test_ferramenta_nao_empilha() -> void:
	var inv := Inventory.new(_data)
	inv.add("picareta_silex", 2)
	check_eq(inv.get_slot(0)["qtd"], 1, "uma picareta por espaço")
	check_eq(inv.get_slot(1)["id"], "picareta_silex", "a segunda vai para outro espaço")
	check_eq(inv.get_slot(0)["durabilidade"], 40, "nasce com a durabilidade cheia")


func test_desgaste_quebra_ferramenta() -> void:
	var inv := Inventory.new(_data)
	inv.add("picareta_silex", 1)
	var broke := false
	for i in 40:
		broke = inv.wear(0)
	check(broke, "quebra no último uso")
	check(inv.get_slot(0).is_empty(), "o espaço fica vazio")


func test_cheio_devolve_sobra() -> void:
	var inv := Inventory.new(_data)
	for i in Inventory.SIZE:
		inv.add("picareta_silex", 1)
	check(not inv.can_add("terra", 1), "inventário cheio")
	check_eq(inv.add("terra", 5), 5, "nada coube")


func test_remover() -> void:
	var inv := Inventory.new(_data)
	inv.add("areia", 120)
	check(not inv.remove("areia", 200), "não remove mais do que tem")
	check_eq(inv.count("areia"), 120, "e não mexe em nada")
	check(inv.remove("areia", 100), "remove 100")
	check_eq(inv.count("areia"), 20, "sobram 20")


func test_trocar_e_juntar() -> void:
	var inv := Inventory.new(_data)
	inv.add("argila", 10)
	inv.add("picareta_silex", 1)
	inv.swap(0, 1)
	check_eq(inv.get_slot(0)["id"], "picareta_silex", "trocou de lugar")
	inv.slots[5] = {"id": "argila", "qtd": 95}
	inv.swap(1, 5)
	check_eq(inv.get_slot(5)["qtd"], 99, "juntou na pilha de destino até 99")
	check_eq(inv.get_slot(1)["qtd"], 6, "o resto ficou na origem")


func test_salvar_e_carregar() -> void:
	var inv := Inventory.new(_data)
	inv.add("tocha", 7)
	inv.add("picareta_cobre", 1)
	inv.wear(1)
	var saved := inv.to_array()
	saved[2] = {"id": "item_que_nao_existe_mais", "qtd": 3}
	var copy := Inventory.new(_data)
	var dropped := copy.load_array(saved)
	check_eq(copy.count("tocha"), 7, "tochas voltam")
	check_eq(copy.get_slot(1)["durabilidade"], 149, "durabilidade volta")
	check_eq(
		dropped,
		PackedStringArray(["item_que_nao_existe_mais"]),
		"item removido dos dados é descartado"
	)

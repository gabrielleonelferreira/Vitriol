extends TestCase
## Carregador de dados (GameData).

const TMP := "user://teste_dados"


func _store() -> DataStore:
	var store := DataStore.new()
	store.load_all()
	return store


func test_carrega_dados_reais() -> void:
	var store := _store()
	check(store.loaded, "dados carregam: %s" % ", ".join(store.errors))
	check(store.materials.size() >= 30, "pelo menos 30 materiais")
	check(store.items.has("fornalha"), "fornalha existe")
	check(store.recipes.has("fundir_cobre"), "receita fundir_cobre existe")
	check_eq(store.display_name("malaquita"), "Malaquita", "nome exibido")
	store.free()


func test_consultas() -> void:
	var store := _store()
	check(store.is_block("calcario"), "calcário é bloco")
	check(not store.is_block("lingote_cobre"), "lingote não é bloco")
	check("fundir_cobre" in store.recipes_for_station("fornalha"), "fornalha funde cobre")
	check("fundir_cobre" in store.recipes_producing("lingote_cobre"), "quem produz cobre")
	check("ligar_bronze" in store.recipes_using("lingote_estanho"), "estanho entra no bronze")
	check_eq(store.layer_rocks(), PackedStringArray(["terra", "calcario", "xisto"]), "rochas")
	var layer3 := store.generation_for_layer(3)
	var ids := layer3.map(func(row: Dictionary) -> String: return row["material"])
	check("hematita" in ids and "quartzo" in ids, "camada 3 tem hematita e quartzo")
	check(not ("xisto" in ids), "rocha principal não entra nas regras de veio")
	store.free()


func test_arquivo_faltando() -> void:
	_write("materiais", {"versao": 1, "materiais": []})
	var store := DataStore.new()
	check(not store.load_all(TMP), "falha sem os outros arquivos")
	check(store.errors.size() >= 1 and "não encontrado" in store.errors[0], "diz o que falta")
	store.free()


func test_versao_errada() -> void:
	for name in ["materiais", "itens", "receitas", "geracao"]:
		_write(name, {"versao": 99, name: []})
	var store := DataStore.new()
	check(not store.load_all(TMP), "falha com versão errada")
	check("versão" in store.errors[0], "mensagem cita a versão")
	store.free()


func test_referencia_quebrada() -> void:
	var mat := {
		"id": "minerio_x",
		"nome": "X",
		"dureza_bloco": 2,
	}
	var item := {"id": "forno_x", "nome": "Forno"}
	var rec := {
		"id": "r",
		"estacao": "forno_x",
		"entradas": [{"id": "nao_existe", "qtd": 1}],
		"saidas": [{"id": "minerio_x", "qtd": 1}],
	}
	var gen := {"material": "minerio_x", "camada": 1, "forma": "rocha"}
	_write("materiais", {"versao": 1, "materiais": [mat]})
	_write("itens", {"versao": 1, "itens": [item]})
	_write("receitas", {"versao": 1, "receitas": [rec]})
	_write("geracao", {"versao": 1, "geracao": [gen]})
	var store := DataStore.new()
	check(not store.load_all(TMP), "falha com referência quebrada")
	check("nao_existe" in " ".join(store.errors), "aponta o id que falta")
	store.free()


func cleanup() -> void:
	if DirAccess.dir_exists_absolute(TMP):
		for file in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP + "/" + file)


func _write(name: String, payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	var file := FileAccess.open("%s/%s.json" % [TMP, name], FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()

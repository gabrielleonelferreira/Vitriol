extends TestCase
## Salvar e carregar o mundo e os jogadores.

const GameServerScript := preload("res://core/server/game_server.gd")
const WORLD := "teste_salvar"

var _data: DataStore


func _init() -> void:
	_data = DataStore.new()
	_data.load_all()
	SaveGame.delete(WORLD)


func cleanup() -> void:
	SaveGame.delete(WORLD)
	_data.free()


func _server() -> Node:
	var server = GameServerScript.new()
	server.start(11, _data, 200, WorldGenerator.DEFAULT_HEIGHT, WORLD)
	return server


func _join(server: Node, name: String) -> LocalTransport:
	var transport := LocalTransport.new(server)
	transport.open()
	transport.send({"type": Commands.JOIN, "name": name})
	server.step_once()
	return transport


func test_mundo_e_jogador_voltam_iguais() -> void:
	var server := _server()
	var transport := _join(server, "Gabriel")
	var grid: WorldGrid = server.world.grid
	var player: PlayerState = server.players[transport.peer_id]
	var spot := Vector2i(grid.spawn_tile.x + 3, grid.spawn_tile.y + 2)
	server.world.set_tile(spot.x, spot.y, 0)
	player.inventory.add("malaquita", 12)
	player.position += Vector2(16, 0)
	player.discoveries["malaquita"] = true
	server.world.time_of_day = 0.8
	var tiles_before := grid.tiles.duplicate()
	check_eq(server.save_now(), OK, "salvou sem erro")
	transport.close()
	server.free()

	var loaded := _server()
	check(loaded.world.grid.tiles == tiles_before, "a grade inteira volta igual")
	check_eq(loaded.world.grid.tile_name(spot.x, spot.y), "ar", "o buraco cavado continua lá")
	check(absf(loaded.world.time_of_day - 0.8) < 0.01, "a hora do dia volta")
	var back := _join(loaded, "Gabriel")
	var again: PlayerState = loaded.players[back.peer_id]
	check_eq(again.inventory.count("malaquita"), 12, "o inventário volta")
	check_eq(again.inventory.count("tocha"), 10, "sem ganhar o kit inicial de novo")
	check(again.discoveries.has("malaquita"), "as descobertas voltam")
	check_eq(again.position, player.position, "a posição volta")
	back.close()
	loaded.free()


func test_jogador_novo_ganha_kit() -> void:
	var server := _server()
	var transport := _join(server, "Novato")
	var player: PlayerState = server.players[transport.peer_id]
	check_eq(player.inventory.count("tocha"), 10, "jogador novo ganha 10 tochas")
	check_eq(player.position, server.world.grid.spawn_position(), "nasce no ponto de nascimento")
	transport.close()
	server.free()


func test_save_corrompido_usa_backup() -> void:
	var server := _server()
	var transport := _join(server, "Gabriel")
	server.save_now()
	server.world.set_tile(server.world.grid.spawn_tile.x, 5, 0)
	server.save_now()
	transport.close()
	server.free()
	var file := FileAccess.open(SaveGame.path_for(WORLD), FileAccess.WRITE)
	file.store_string("{ isto não é json")
	file.close()
	var restored := SaveGame.read(WORLD)
	check(not restored.is_empty(), "lê o .bak quando o principal está corrompido")


func test_paleta_diferente_remapeia() -> void:
	var server := _server()
	var saved: Dictionary = server.world.to_save()
	server.free()
	# Simula dados de outra versão: a paleta salva tem os nomes em outra ordem.
	var names: Array = saved["paleta"].duplicate()
	var reversed := names.duplicate()
	reversed.reverse()
	var state := WorldState.from_save(saved, _data)
	saved["paleta"] = reversed
	var shuffled := WorldState.from_save(saved, _data)
	var x := state.grid.spawn_tile.x
	var y := state.grid.spawn_tile.y + 3
	var original_name := state.grid.tile_name(x, y)
	var remapped_name := shuffled.grid.registry.name_of(shuffled.grid.get_tile(x, y))
	var expected: String = reversed[names.find(original_name)]
	check_eq(remapped_name, expected, "ids são lidos pelo nome da paleta salva")

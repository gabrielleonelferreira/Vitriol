class_name ClientSession
extends Node
## Sessão do cliente: envia comandos pelo Transport e repassa os eventos à interface.

signal event_received(event: Dictionary)

var transport: Transport
var player_id: int = 0


func connect_to(new_transport: Transport) -> void:
	transport = new_transport
	transport.event_received.connect(_on_event)
	transport.open()


func join(display_name: String) -> void:
	transport.send({"type": Commands.JOIN, "name": display_name})


func ping() -> void:
	transport.send({"type": Commands.PING})


func move(position: Vector2, velocity: Vector2, facing: int) -> void:
	(
		transport
		. send(
			{
				"type": Commands.MOVE,
				"position": [position.x, position.y],
				"velocity": [velocity.x, velocity.y],
				"facing": facing,
			}
		)
	)


func mine(tile: Vector2i) -> void:
	transport.send({"type": Commands.MINE, "x": tile.x, "y": tile.y})


func mine_stop() -> void:
	transport.send({"type": Commands.MINE_STOP})


func cast(spell: String, tile: Vector2i) -> void:
	transport.send({"type": Commands.CAST, "magia": spell, "x": tile.x, "y": tile.y})


func debug_storm() -> void:
	transport.send({"type": Commands.DEBUG_STORM})


func experiment(station: String, mix: Dictionary) -> void:
	transport.send({"type": Commands.EXPERIMENT, "estacao": station, "itens": mix})


## `auto`: colocação automática (escada subindo); o servidor não avisa quando não dá.
func place(tile: Vector2i, auto: bool = false) -> void:
	transport.send({"type": Commands.PLACE, "x": tile.x, "y": tile.y, "auto": auto})


func select_slot(index: int) -> void:
	transport.send({"type": Commands.SELECT_SLOT, "index": index})


func swap_slots(a: int, b: int) -> void:
	transport.send({"type": Commands.SWAP_SLOTS, "a": a, "b": b})


func craft(recipe_id: String, qtd: int = 1) -> void:
	transport.send({"type": Commands.CRAFT, "receita": recipe_id, "qtd": qtd})


func craft_cancel(index: int) -> void:
	transport.send({"type": Commands.CRAFT_CANCEL, "index": index})


func debug_kit() -> void:
	transport.send({"type": Commands.DEBUG_KIT})


func _on_event(event: Dictionary) -> void:
	if event.get("type", "") == Events.JOINED:
		player_id = int(event["player_id"])
	event_received.emit(event)


func _exit_tree() -> void:
	if transport:
		transport.close()
		transport = null

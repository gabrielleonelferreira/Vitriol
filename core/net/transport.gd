class_name Transport
extends RefCounted
## Canal entre um cliente e o servidor.
## Trocar o transporte (local no solo, rede no multiplayer) não muda o resto do jogo.

signal event_received(event: Dictionary)


func open() -> void:
	pass


func send(_command: Dictionary) -> void:
	push_error("Transport.send() precisa ser implementado pela subclasse.")


func close() -> void:
	pass

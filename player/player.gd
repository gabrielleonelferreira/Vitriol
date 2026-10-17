class_name Player
extends Node2D
## Personagem na tela: partes do corpo empilhadas, animação e câmera.
##
## Local (is_local = true): lê o teclado, move com o PlayerMotor e envia a posição ao
## servidor. Remoto: só mostra a posição que o servidor repassa, suavizada.

## Para os sons: pisou (a cada passo), pulou do chão, subiu/desceu um degrau.
signal stepped(feet: Vector2)
signal jumped(air: bool)
signal climbed(feet: Vector2)

signal moved(position: Vector2, velocity: Vector2, facing: int)

const ART_DIR := "res://art/personagem"
const META_PATH := "res://art/personagem/personagem.json"
## Envios de posição por segundo (o servidor processa 20 ticks por segundo).
const SEND_RATE := 20.0
const REMOTE_SMOOTHING := 14.0

var is_local: bool = true
var motor := PlayerMotor.new()
var grid: WorldGrid

var _body := Node2D.new()
var _parts: Array[Sprite2D] = []
var _meta: Dictionary = {}
var _anim: String = "parado"
var _frame_time: float = 0.0
var _frame: int = 0
var _send_timer: float = 0.0
var _remote_target: Vector2 = Vector2.ZERO
var _camera: Camera2D
## Lufada de vento do salto da Tempestária.
var _wind := CPUParticles2D.new()
var _walked: float = 0.0
var _climbed: float = 0.0


func _make_wind() -> void:
	var dot := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	dot.fill(Color("c8f0ff"))
	_wind.texture = ImageTexture.create_from_image(dot)
	_wind.one_shot = true
	_wind.emitting = false
	_wind.amount = 14
	_wind.lifetime = 0.35
	_wind.explosiveness = 0.9
	_wind.direction = Vector2(0, 1)
	_wind.spread = 70.0
	_wind.initial_velocity_min = 30.0
	_wind.initial_velocity_max = 70.0
	_wind.gravity = Vector2.ZERO
	_wind.local_coords = false
	_wind.z_index = 5
	add_child(_wind)


func setup(new_grid: WorldGrid, start: Vector2, local: bool) -> void:
	_make_wind()
	grid = new_grid
	is_local = local
	motor.position = start
	_remote_target = start
	position = start
	_build_sprites()
	if is_local:
		_make_camera()


func _build_sprites() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	_meta = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	var frame_size: Array = _meta.get("quadro", [16, 32])
	var columns := int(_meta.get("colunas", 8))
	var rows := int(_meta.get("animacoes", {}).size())
	_body.name = "Corpo"
	add_child(_body)
	for part in _meta.get("partes", []):
		var sprite := Sprite2D.new()
		sprite.name = part
		sprite.texture = load("%s/%s.png" % [ART_DIR, part])
		sprite.hframes = columns
		sprite.vframes = rows
		sprite.centered = false
		# Pés na origem: a folha tem 16 px de largura e 32 de altura.
		sprite.offset = Vector2(-frame_size[0] / 2.0, -frame_size[1])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_body.add_child(sprite)
		_parts.append(sprite)
	z_index = 5


func _make_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.position = Vector2(0, -16)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 9.0
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = grid.width * WorldGrid.TILE_SIZE
	_camera.limit_bottom = grid.height * WorldGrid.TILE_SIZE
	add_child(_camera)
	_camera.make_current()


func _physics_process(delta: float) -> void:
	if grid == null:
		return
	if is_local:
		var move := Input.get_axis("mover_esquerda", "mover_direita")
		var was_on_floor := motor.on_floor
		var before := motor.position
		motor.step(
			move,
			Input.is_action_just_pressed("pular"),
			Input.is_action_pressed("pular"),
			delta,
			grid,
			Input.is_action_pressed("descer")
		)
		position = motor.position
		if motor.air_jumped:
			_wind.restart()
			jumped.emit(true)
		elif was_on_floor and motor.velocity.y < -200.0 and not motor.climbing:
			jumped.emit(false)
		if motor.on_floor:
			_walked += absf(motor.position.x - before.x)
			if _walked >= 18.0:
				_walked = 0.0
				stepped.emit(motor.position)
		if motor.climbing:
			_climbed += absf(motor.position.y - before.y)
			if _climbed >= 12.0:
				_climbed = 0.0
				climbed.emit(motor.position)
		_send_timer -= delta
		if _send_timer <= 0.0:
			_send_timer = 1.0 / SEND_RATE
			moved.emit(motor.position, motor.velocity, motor.facing)
	else:
		position = position.lerp(_remote_target, clampf(REMOTE_SMOOTHING * delta, 0.0, 1.0))


func _process(delta: float) -> void:
	_update_animation(delta)


## Servidor recusou a posição: volta para a última válida.
func apply_correction(server_position: Vector2) -> void:
	motor.position = server_position
	motor.velocity = Vector2.ZERO
	position = server_position


## Jogador remoto: nova posição vinda do servidor.
func apply_remote(server_position: Vector2, velocity: Vector2, facing: int) -> void:
	_remote_target = server_position
	motor.velocity = velocity
	motor.facing = facing
	motor.on_floor = absf(velocity.y) < 1.0


func _update_animation(delta: float) -> void:
	if _parts.is_empty():
		return
	var anim := "parado"
	var fps := 4.0
	if motor.climbing:
		anim = "pular"
	elif not motor.on_floor and not motor.in_water:
		anim = "pular"
	elif absf(motor.velocity.x) > 8.0:
		anim = "andar"
		fps = 6.0 + absf(motor.velocity.x) / PlayerMotor.RUN_SPEED * 8.0
	if anim != _anim:
		_anim = anim
		_frame = 0
		_frame_time = 0.0
	var info: Dictionary = _meta["animacoes"][_anim]
	if motor.climbing:
		# Pendurado: alterna os dois quadros do pulo enquanto sobe ou desce.
		if absf(motor.velocity.y) > 1.0:
			_frame_time += delta
			if _frame_time >= 0.16:
				_frame_time = 0.0
				_frame = 1 - _frame
	elif _anim == "pular":
		_frame = 0 if motor.velocity.y < 0.0 else 1
	else:
		_frame_time += delta
		if _frame_time >= 1.0 / fps:
			_frame_time = 0.0
			_frame = (_frame + 1) % int(info["quadros"])
	var columns := int(_meta["colunas"])
	var index := int(info["linha"]) * columns + _frame
	for sprite in _parts:
		sprite.frame = index
	_body.scale.x = motor.facing

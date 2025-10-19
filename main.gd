extends Node2D

@export_category("Script Exports")
@export_group("Time and Movement")
@export var pause_time : bool = true		# Para pausar o jogo
@export var move_cooldown : float = 0.3		# Cooldown para cada movimento (0.3 segundos para cada nova ação)
@export_group("Scenes")

var input_direction : Vector2				# Direção de movimento do jogador
var move_cooldown_timer : float = 0.0		# Timer para realizar o cooldown de movimento
var awaiting_done_confirmation = 0
var action_points : int = 0
var player_action_queue = []
var world_moving : bool = false

var current_scene = null

func _ready() -> void:
	world_moving = false
	current_scene = $Level
	pause_processing() # Pausa o jogo no início e a cada ação do jogador, para imitar o Nethack

# Ativa movimentos pelo input, que funciona por eventos de botões pressionados
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if Input.is_action_pressed("reset"):
				call_deferred("goto_scene", "res://level.tscn")
				world_moving = false
				resume_processing()
			if (pause_time):
				resume_processing() # Despausa em cada botão pressionado, caso necessário

			# Direção do movimento
			# Só funciona quando acabar o cooldown E o mundo estiver parado
			if (!world_moving and move_cooldown_timer <= 0):
				action_points += 1

				input_direction = Vector2.ZERO
				if Input.is_action_pressed("player_move_up"):
					input_direction = Vector2(0,-1)
				elif Input.is_action_pressed("player_move_down"):
					input_direction = Vector2(0,1)
				elif Input.is_action_pressed("player_move_left"):
					input_direction = Vector2(-1,0)
				elif Input.is_action_pressed("player_move_right"):
					input_direction = Vector2(1,0)

				if (input_direction != Vector2.ZERO):
					player_action_queue.push_back(input_direction)

# Utilizado para movimentação também
# (física roda diferente e de forma mais consistente que process, utilizar quando utilizar delta)
func _physics_process(delta) -> void:
	if move_cooldown_timer > 0:
		move_cooldown_timer -= 1*delta

	if (action_points > 0 and !world_moving):
		world_moving = true
		action_points -= 1
		move_cooldown_timer = move_cooldown
		move_world()

	if (awaiting_done_confirmation <= 0 and world_moving):
		world_moving = false
		if (GlobalVariables.DEBUG): print("All Characters/Objects moved and confirmed")
		stop_world()

# Nodo Game está setado pra nunca pausar e sempre rodará esta função (e de física) em loop
func _process(_delta) -> void:
	pass

# Pausa todos outros nodos
func pause_processing():
	pause_time = true
	if (GlobalVariables.DEBUG): print("Time Paused")
	OS.low_processor_usage_mode = true
	get_tree().paused = true

# Despausa
func resume_processing():
	pause_time = false
	if (GlobalVariables.DEBUG): ("Time Resumed")
	OS.low_processor_usage_mode = false
	get_tree().paused = false

# Recebe confirmação dos nodos Movable (individualmente) quando pararem
func child_done_confirmation() -> void:
	awaiting_done_confirmation -= 1

# Função para parar todos movimentos (é chamada quando recebe confirmação de todos filhos que pararam as ações)
func stop_world():
	# Fazer algo mais?
	pause_processing()

# Função para chamar todos filhos Movable para executarem um movimento
func move_world():
	awaiting_done_confirmation = get_tree().get_nodes_in_group("Npc").size()
	awaiting_done_confirmation += 1 # player
	get_tree().call_group("Player", "receive_action", player_action_queue.pop_front())
	get_tree().call_group("Npc", "receive_points")
	
func goto_scene(path: String):
	current_scene.queue_free()
	var new_scene : PackedScene = ResourceLoader.load(path)
	current_scene = new_scene.instantiate()
	#scene_limit = null # indica a troca de cena
	add_child(current_scene)  
	

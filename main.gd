extends Node2D

@export var tile_size : int = 128		# Tamanho de tile que os personagens acessam em seu script (provavelmente mudaremos depois)
@export var pause_time : bool = true	# (WIP) Para pausar o jogo

var action_points : int = 0
# Cada ação do jogador, adiciona um action point
# Cada action point, faz os NPCs realizaram uma ação

# FUNÇÃO DE PAUSE ESTÁ EM WIP!

func _ready() -> void:
	pause_time = true # (WIP) Pausa o jogo no início e a cada ação do jogador, para imitar o Nethack
	pause_processing()
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			action_points += 1
			pause_time = false
			resume_processing() # Despausa em cada botão pressionado
			move_world()

# Ainda não utilizado
func _physics_process(_delta) -> void:
	pass

# Nodo Main está setado pra nunca pausar e sempre rodará esta função em loop
func _process(_delta) -> void:
	pass
	# Pausa se o flag estiver setado
	#if (pause_time):
		#OS.low_processor_usage_mode = true	# baixa o uso de CPU
		#get_tree().paused = true			# pausa o jogo
	#move_world()

# Não sei se é viável
func pause_processing():
	pause_time = true
	print("time paused")
	OS.low_processor_usage_mode = true
	get_tree().paused = true

# Despausa
func resume_processing():
	pause_time = false
	print("time resumed")
	OS.low_processor_usage_mode = false
	get_tree().paused = false

func move_world():
	# Enviar action points? Ou gerenciar todos os personagens?
	while(action_points > 0):
		action_points -= 1
		#await get_tree().create_timer(1).timeout
	
	# Problema do pause_processing é aqui:
	# Quando pausa? Precisaria esperar todos terminarem o movimento
	#pause_processing()
	
	# Chamar cada jogador/NPC?
	# Pausar depois de rodar uma vez?

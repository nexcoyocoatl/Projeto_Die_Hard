extends Node2D

@export var tile_size : int = 128		# Tamanho de tile que os personagens acessam em seu script (provavelmente mudaremos depois)
@export var pause_time : bool = true	# (WIP) Para pausar o jogo
#@export var max_fps : int = 0			# Possível variável para setar o FPS ao normal após pause

# FUNÇÃO DE PAUSE ESTÁ EM WIP!

func _ready() -> void:
	pause_time = true # (WIP) Pausa o jogo no início e a cada ação do jogador, para imitar o Nethack
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			pause_time = false
			resume_processing() # Despausa em cada botão pressionado

# Ainda não utilizado (Linguagens pythonescas não permitem o desenvolvedor deixar uma função vazia)
#func _physics_process(_delta) -> void:

# Nodo Main está setado pra nunca pausar e sempre rodará esta função em loop
func _process(_delta) -> void:
	# Pausa se o flag estiver setado
	if (pause_time):
		Engine.max_fps = 1 					# baixa FPS pra um
		OS.low_processor_usage_mode = true	# baixa o uso de CPU
		get_tree().paused = true			# pausa o jogo
	#move_world()

# Despausa
func resume_processing():
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	get_tree().paused = false

#func move_world():
	# Chamar cada jogador/NPC?
	# Pausar depois de rodar uma vez?

extends CharacterBody2D

@export var tween_speed : float = 0.2		# Velocidade da animação de translação (maior é mais devagar)

var tile_size : int = 0						# Inicializa em 0, mas recebe do Main ao iniciar o jogo
var input_direction : Vector2 = Vector2.ZERO				# Direção de movimento do jogador
var moving : bool = false					# Se está movendo ou não

# Action queue e points do jogador
var action_queue = []
var action_points = 0

func _ready() -> void:
	tile_size = get_parent().tile_size		# Recebe do Main

func _physics_process(delta: float) -> void:
	# Se não está movendo e tem action points para usar, executa um por um
	if (moving == false and action_points):
		moving = true
		input_direction = action_queue.pop_front()
		move()

func receive_action(action):
	print("player received action")
	action_points += 1
	
	# Por enquanto só pra movimento, se usar outra ação ou botão, quebra a execução
	action_queue.push_back(action)

# Movimenta o jogador
func move():
	var tween = create_tween()
	tween.tween_property(self, "position", position + (input_direction * tile_size), tween_speed).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(move_false)

# Função que desativa o movimento após uma ação
func move_false():
	moving = false
	print("Move false")
	
	# Diminui os action points, e se acaba todos, avisa a cena Game (Main) que terminou
	action_points -= 1
	if action_points <= 0:
		print("player stops moving")
		get_tree().call_group("Game", "child_done_confirmation")

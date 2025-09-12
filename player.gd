extends CharacterBody2D

@export var tween_speed : float = 0.2		# Velocidade da animação de translação (maior é mais devagar)
@export var move_cooldown : float = 0.3		# Cooldown para cada movimento (0.3 segundos para cada nova ação)

var tile_size : int = 0						# Inicializa em 0, mas recebe do Main ao iniciar o jogo
var input_direction : Vector2						# Direção de movimento do jogador
var moving : bool = false					# Se está movendo ou não
var move_cooldown_timer : float = 0.0		# Timer para realizar o cooldown de movimento

func _ready() -> void:
	tile_size = get_parent().tile_size		# Recebe do Main

func _physics_process(delta: float) -> void:
	# Cooldown timer para cada ação
	if move_cooldown_timer > 0:
		move_cooldown_timer -= 1*delta
		print("Cooldown timer: ", move_cooldown_timer)
	
	# Direção do movimento
	input_direction = Vector2.ZERO
	if Input.is_action_pressed("player_move_up"):
		input_direction = Vector2(0,-1)
		move()
	elif Input.is_action_pressed("player_move_down"):
		input_direction = Vector2(0,1)
		move()
	elif Input.is_action_pressed("player_move_left"):
		input_direction = Vector2(-1,0)
		move()
	elif Input.is_action_pressed("player_move_right"):
		input_direction = Vector2(1,0)
		move()

# Movimenta o jogador
func move():
	if input_direction:
		if moving == false and move_cooldown_timer <= 0:
			moving = true
			var tween = create_tween()
			tween.tween_property(self, "position", position + (input_direction * tile_size), tween_speed)
			tween.tween_callback(move_false)

# Função que desativa o movimento após uma ação
# Como também liga o cooldown
# (chamará o pause_time no futuro?)
func move_false():
	moving = false
	move_cooldown_timer = move_cooldown

extends CharacterBody2D

@export var tween_speed : float = 0.2		# Velocidade da animação de translação (maior é mais devagar)
@export var tilemap_layer : TileMapLayer

var input_direction : Vector2 = Vector2.ZERO				# Direção de movimento do jogador
var moving : bool = false					# Se está movendo ou não

# Action queue e points do jogador
var action_queue = []
var action_points = 0

func _ready() -> void:
	# Prende jogador ao centro do tile mais próximo (TODO: talvez mudar depois que o player puder receber o tilemap)
	self.position = Vector2i(self.position/GlobalVariables.TILE_SIZE)*GlobalVariables.TILE_SIZE + Vector2i(GlobalVariables.TILE_SIZE/2.0, GlobalVariables.TILE_SIZE/2.0)
	
func _physics_process(_delta: float) -> void:
	# Se não está movendo e tem action points para usar, executa um por um
	if (moving == false and action_points):
		moving = true
		if (action_queue.front() == null):
			action_queue.pop_front()
			move_false()
			return
		input_direction = action_queue.pop_front()
		move()
		
func receive_action(action):
	if (GlobalVariables.DEBUG): print("player received action")
	action_points += 1
	
	# Por enquanto só pra movimento, se usar outra ação ou botão, quebra a execução
	action_queue.push_back(action)

# Movimenta o jogador
func move():
	var cell : Vector2i = Vector2i(position/GlobalVariables.TILE_SIZE + input_direction)
	print(cell)
	var tween = create_tween()
	
	# TODO: muito ineficiente e contém bug na parte superior e a esquerda do mapa (avança um tile a mais)
	if (cell not in tilemap_layer.get_used_cells()) \
	or (tilemap_layer.get_cell_tile_data(cell).get_collision_polygons_count(0) > 0):
	#or cell not in tilemap_layer.get_used_cells():
		tween.tween_property(self, "position", position + (input_direction * (GlobalVariables.TILE_SIZE/4.0)), tween_speed/2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "position", position, tween_speed/2).set_trans(Tween.TRANS_BOUNCE)
	else:
		tween.tween_property(self, "position", position + (input_direction * GlobalVariables.TILE_SIZE), tween_speed).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(move_false)

# Função que desativa o movimento após uma ação
func move_false():
	moving = false
	if (GlobalVariables.DEBUG): print("Move false")
	
	# Diminui os action points, e se acaba todos, avisa a cena Game (Main) que terminou
	action_points -= 1
	if action_points <= 0:
		if (GlobalVariables.DEBUG): print("player stops moving")
		get_tree().call_group("Game", "child_done_confirmation")

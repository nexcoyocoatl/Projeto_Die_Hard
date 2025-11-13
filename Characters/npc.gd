extends CharacterBody2D
class_name Npc

enum NpcType{
	SHOOTER, 
	FIGHTER, 
	DOG
}

enum Mode {
	PATROL,
	FOLLOW,
	AIMING,
	ATTACKING, 
	ALERTED
}

enum Direction {
	UP,
	DOWN,
	LEFT,
	RIGHT
}

var tilemap_layer : TileMapLayer = null
var player : CharacterBody2D = null

# Pathfinding
@export_category("Script Exports")
@export_group("Pathfinding")
@export var line_path : Line2D = null
@export var path : Path2D = null
@export var mode : Mode = Mode.FOLLOW
var pathfinding_grid : AStarGrid2D
var patrol_path : Array[Vector2i] = []
var current_patrol_index : int = -1
var last_player_position : Vector2i
var last_player_global_position : Vector2i

#Behavior 
@export_group("Behavior") 
@export var npc_type : NpcType #Aqui se escolhe o tipo do NPC

#Combat
@export_group("Combat")
@export_subgroup("Shooter")
# TODO: Trocar pra 3 quando estiver consertado o delay do tiro
@export var time_to_shoot : int = 3 + 1 # Turnos que o shooter leva para atirar
@export_subgroup("Fighter")
@export var attack_range_melee : float = 1.5 # Distância que o fighter ataca (adjacentes)
var distance_to_player : float
var aiming_timer : int = 0
@onready var feedback_label = get_node_or_null("Label") 

# Movement
@export_group("Animation and Movement")
@export var tween_speed : float = 0.2
var moving = false
var past_position : Vector2 = Vector2(0,0)
var direction_set : bool = false
var direction : Direction
var cooldown : int = 0

# Vision Cone
@export_group("Vision Cone")
@export var cone_ray_dist : int = 7
@export var cone_ray_dist_alert : int = 10
@export_range(10,90) var cone_ray_angle_normal : int = 40
@export_range(10,90) var cone_ray_angle_alert : int = 30
var cone_ray_angle : int = cone_ray_angle_normal
var alert : bool = false
var player_found : bool = false
# TODO: Adicionar uma outra variável que verifica se o NPC tem como atirar?
# Do jeito que tá, ele pode atirar quando uma mínima parte do cone encosta no jogador
var is_shooting : bool = false	# Quando atira (cone fica vermelho)
var cone_ray : RayCast2D
var cone_polygon : PackedVector2Array = []

# --- ADIÇÕES PARA O DOG ---
# Conecta o script aos nós de Area2D
@onready var detection_circle = get_node_or_null("DetectionCircle")
@onready var bark_alert = get_node_or_null("BarkAlert")

# Variáveis para a mecânica de movimento duplo
var moves_per_turn : int  #O valor será definido no _ready()
var moves_remaining : int = 0

func _ready() -> void:
	last_player_global_position = player.global_position
	player_found = false
	
	# TODO: Temporário? (ver outra forma, talvez?)
	if (path.name.contains("Shooter")):
		npc_type = NpcType.SHOOTER
		moves_per_turn = 1 # <-- Movimento definido como 1
		$Sprite2D.modulate = Color(1.0, 0.47, 0.47, 1.0)
		
	elif (path.name.contains("Fighter")):
		npc_type = NpcType.FIGHTER
		moves_per_turn = 1 # <-- Movimento definido como 1
		$Sprite2D.modulate = Color(0.85, 1.0, 0.47, 1.0)
		
	elif (path.name.contains("Dog")):
		npc_type = NpcType.DOG
		moves_per_turn = 2 # <-- Movimento definido como 2
		$Sprite2D.modulate = Color(0.514, 0.322, 0.05, 1.0) 
	
	#Configuração Específica por TIPO 
		#Configuração Específica do DOG
	if npc_type == NpcType.DOG:
		# --- Configuração Específica do DOG ---
		detection_circle = get_node_or_null("DetectionCircle")
		bark_alert = get_node_or_null("BarkAlert")
		
		if detection_circle:
			detection_circle.body_entered.connect(_on_DetectionCircle_body_entered)
			detection_circle.body_exited.connect(_on_DetectionCircle_body_exited)
		
		if bark_alert:
			bark_alert.body_entered.connect(_on_BarkAlert_body_entered)
			
	#Configuração Padrão (SHOOTER / FIGHTER)
	# Vision Cone
	cone_ray = $ConeRay
	if cone_ray:
		cone_ray_dist_alert *= GlobalVariables.TILE_SIZE
		cone_ray_dist = cone_ray_dist * GlobalVariables.TILE_SIZE # variável de alcance em tiles
		cone_ray.target_position = Vector2(cone_ray_dist,0)
		cone_ray.collide_with_areas = true # Colide com areas2d também
		
	feedback_label = $Label
	if feedback_label:
		feedback_label.visible = false
	
func _draw() -> void:
	# Desenha polígono do cone de visão
	if (cone_polygon.size() > 3): # Só tenta desenhar se tem um polígono
		if (is_shooting):
			draw_polygon(cone_polygon, [Color(1.0, 0.0, 0.0, 0.2)])
		elif (alert):
			draw_polygon(cone_polygon, [Color(1.0, 0.7, 0.0, 0.2)])
		elif (cone_ray.target_position == Vector2(cone_ray_dist_alert,0)):
			draw_polygon(cone_polygon, [Color(1.0, 1.0, 0.0, 0.2)])
		else:
			draw_polygon(cone_polygon, [Color(1.0, 1.0, 1.0, 0.2)])
	
func _process(_delta) -> void:
	if (player_found):
		player_found = false
		alert = true
		detect_player()
		cone_ray_angle = cone_ray_angle_alert
	
	if (moving):
		if (alert):
			aiming_timer = 0
			feedback_label.visible = false
			
			distance_to_player = global_position.distance_to(player.global_position) / GlobalVariables.TILE_SIZE
			
			if npc_type == NpcType.FIGHTER: # Se for Lutador, verifique se está perto o suficiente para atacar.
				if distance_to_player <= attack_range_melee:
					mode = Mode.ATTACKING
			
			elif npc_type == NpcType.DOG:
				if distance_to_player <= attack_range_melee:
					mode = Mode.ATTACKING
			
			if (mode == Mode.PATROL or mode == Mode.FOLLOW):
				if (npc_type == NpcType.SHOOTER):
					mode = Mode.AIMING
				else:
					mode = Mode.FOLLOW
			
		else:
			match direction:
				Direction.UP:
					cone_ray.rotation_degrees = 270
				Direction.DOWN:
					cone_ray.rotation_degrees = 90
				Direction.LEFT:
					cone_ray.rotation_degrees = 180
				Direction.RIGHT:
					cone_ray.rotation_degrees = 0
				
			if (mode == Mode.FOLLOW):
				cone_ray.look_at(last_player_global_position)
					
# O DOG não usa cone de visão, só os outros
	if npc_type != NpcType.DOG:
		create_cone()

# Cria polígono do cone de visão
func create_cone():
	cone_polygon.clear()
	cone_polygon.append(cone_ray.position) # Posição do NPC
	var original_rotation = cone_ray.rotation_degrees
	
	# Raycaster do ângulo de visão
	for i in range(-cone_ray_angle, cone_ray_angle+1):
		cone_ray.rotation_degrees = original_rotation + i
		cone_ray.force_raycast_update()
		if (cone_ray.is_colliding()):
			var colliding_object = cone_ray.get_collider()
			
			# TODO: Temporário pra evitar o LevelEnd e Checkpoint como obstáculo de visão
			if (colliding_object.name.contains("LevelEnd") or colliding_object.name.contains("Checkpoint")):
				cone_ray.add_exception(colliding_object)
			
			if (!player_found and colliding_object == player):
				player_found = true
				
				cone_ray.add_exception(player)
				cone_ray.force_raycast_update()
				if (cone_ray.is_colliding()):
					cone_polygon.append(cone_ray.get_collision_point() - cone_ray.to_global(Vector2.ZERO))
				else:
					cone_polygon.append(cone_ray.to_global(cone_ray.target_position) - cone_ray.to_global(Vector2.ZERO))
				continue
			cone_polygon.append(cone_ray.get_collision_point() - cone_ray.to_global(Vector2.ZERO))
			continue
		cone_polygon.append(cone_ray.to_global(cone_ray.target_position) - cone_ray.to_global(Vector2.ZERO))
	
	if (player_found):
		cone_ray.remove_exception(player)
	else:
		alert = false
		cone_ray_angle = cone_ray_angle_normal
		
	cone_ray.rotation_degrees = original_rotation
	queue_redraw()

func _generate_patrol_path() -> void:
	patrol_path.clear()
	var length: float = path.curve.get_baked_length()
	var dist: float = 0.0

	while dist < length:
		var local_point: Vector2 = path.curve.sample_baked(dist)
		var global_point: Vector2 = path.to_global(local_point)
		var cell: Vector2i = (global_point / GlobalVariables.TILE_SIZE).floor() 
		patrol_path.append(cell)
		dist += GlobalVariables.TILE_SIZE

	# garante que o último ponto seja o final da curva
	if dist < length + GlobalVariables.TILE_SIZE:
		var local_point: Vector2 = path.curve.sample_baked(dist)
		var global_point: Vector2 = path.to_global(local_point)
		var cell: Vector2i = (global_point / GlobalVariables.TILE_SIZE).floor()
		patrol_path.append(cell)

func receive_points():
	moving = true

#LÓGICA DO LATIDO (DOG)
	if npc_type == NpcType.DOG and bark_alert:
		if mode == Mode.FOLLOW or mode == Mode.ATTACKING:
			bark_alert.monitoring = true # Começa a latir
		else:
			bark_alert.monitoring = false # Para de latir

	#MODIFICAÇÃO: LÓGICA DE MÚLTIPLOS MOVIMENTOS
	moves_remaining = moves_per_turn #Define quantos movimentos fazer (1 para outros, 2 para o Dog)

	match mode:
		Mode.FOLLOW:
			cone_ray.target_position = Vector2(cone_ray_dist_alert,0)
			current_patrol_index = -1
			follow_player()
		Mode.PATROL:
			cone_ray.target_position = Vector2(cone_ray_dist,0)
			if patrol_path.is_empty():
				_generate_patrol_path()
			if current_patrol_index == -1:
				var current_position: Vector2i = (global_position / GlobalVariables.TILE_SIZE).floor()
				current_patrol_index = find_closest_path_point(current_position)
			patrol()
		Mode.AIMING:
			cone_ray.target_position = Vector2(cone_ray_dist_alert,0)
			aim_gun()
		Mode.ATTACKING:
			attack_melee() 
		Mode.ALERTED: 
			alert_investigate() # Vai para o local do som

func find_closest_path_point(given_position : Vector2i) -> int:
	var closest_index: int = 0
	var min_dist: float = INF
	for i in range(patrol_path.size()):
		var dist = given_position.distance_to(Vector2(patrol_path[i]))
		if dist < min_dist:
			min_dist = dist
			closest_index = i
	return closest_index

func patrol() -> void:
	if patrol_path.is_empty():
		move_finished()
		return
	var current_position: Vector2i = (global_position / GlobalVariables.TILE_SIZE).floor()
	# se npc ainda não está no caminho de patrulha, vai até ele
	if !patrol_path.has(current_position):
		current_patrol_index = find_closest_path_point(current_position)
		go_towards_position(current_position, patrol_path[current_patrol_index])
		return
	# chegou no caminho de patrulha, segue de onde está
	if current_patrol_index == patrol_path.size() - 1: current_patrol_index = 1
	else: current_patrol_index = (current_patrol_index + 1) % patrol_path.size()
	var target: Vector2 = Vector2(patrol_path[current_patrol_index]) * GlobalVariables.TILE_SIZE + Vector2(GlobalVariables.TILE_SIZE/2.0, GlobalVariables.TILE_SIZE/2.0)
	var tween = create_tween()
	
	# Facing direction
	change_direction((target - global_position).normalized())
	
	tween.tween_property(self, "global_position", target, tween_speed).set_trans(Tween.TRANS_SINE)
	await tween.finished
	queue_redraw()
	move_finished()

func follow_player():
	var current_position : Vector2i = (global_position / GlobalVariables.TILE_SIZE).floor()
	if current_position == last_player_position:
		mode = Mode.PATROL
	# se player estiver fora do tilemap
	if not pathfinding_grid.region.has_point(Vector2i(last_player_position)):
		move_finished()
		return
	go_towards_position(current_position, last_player_position)

func go_towards_position(from_position: Vector2i, to_position : Vector2i) -> void:
	var path_to_position = pathfinding_grid.get_point_path(from_position, to_position)
	var tween = create_tween()
	
	if path_to_position.size() <= 1: # vazio ou só tem o tile do proprio npc
		tween.tween_interval(tween_speed) # cria delay para dar tempo do process desenhar conde de visão
		tween.tween_callback(move_finished)
		return
		
	var next_position : Vector2 = path_to_position[1] + Vector2(GlobalVariables.TILE_SIZE/2.0, GlobalVariables.TILE_SIZE/2.0)
	
	# Facing direction
	change_direction((next_position - global_position).normalized())
	
	tween.tween_property(self, "global_position", next_position, tween_speed).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(move_finished)
	line_path.points = path_to_position

func change_direction(move_direction: Vector2) -> void:
	if (move_direction.x < 0.):
		direction = Direction.LEFT
	if (move_direction.x > 0.):
		direction = Direction.RIGHT
	if (move_direction.y < 0.):
		direction = Direction.UP
	if (move_direction.y > 0.):
		direction = Direction.DOWN

func move_finished() -> void:
	moving = false
	moves_remaining -= 1 # Subtrai um movimento

	if moves_remaining > 0:
		# Se ainda tem movimentos (ex: DOG), execute o turno de novo
		moving = true

		#RE-EXECUTA A LÓGICA DE AÇÃO
		match mode:
			Mode.FOLLOW:
				cone_ray.target_position = Vector2(cone_ray_dist_alert,0)
				current_patrol_index = -1
				follow_player()
			Mode.PATROL:
				cone_ray.target_position = Vector2(cone_ray_dist,0)
				if patrol_path.is_empty():
					_generate_patrol_path()
				if current_patrol_index == -1:
					var current_position: Vector2i = (global_position / GlobalVariables.TILE_SIZE).floor()
					current_patrol_index = find_closest_path_point(current_position)
				patrol()
			Mode.AIMING:
				cone_ray.target_position = Vector2(cone_ray_dist_alert,0)
				aim_gun()
			Mode.ATTACKING:
				attack_melee() 
			Mode.ALERTED: 
				alert_investigate()
	else:
		# Se acabaram os movimentos, termine o turno
		if (GlobalVariables.DEBUG): print(self.name, " stops moving")
		get_tree().call_group("Game", "child_done_confirmation")
	
func aim_gun():
	if (alert):
		aiming_timer += 1
	
		feedback_label.text = str(time_to_shoot - aiming_timer)
		feedback_label.visible = true
		
		if aiming_timer > time_to_shoot:
			shoot() # Atira
			return
			
	else:
		aiming_timer = 0
		feedback_label.visible = false
		mode = Mode.FOLLOW
	
	moves_remaining = 0 # Mira consome o turno inteiro

	var tween = create_tween()
	tween.tween_interval(tween_speed) # Apenas espera
	tween.tween_callback(move_finished)

func shoot():
	if(GlobalVariables.DEBUG): print("NPC SHOOTER: FIRE!")
	feedback_label.visible = false
	is_shooting = true # Ativa o cone vermelho
	
	player.die()
	
	moves_remaining = 0 # Tiro consome o turno inteiro

	var tween = create_tween()
	tween.tween_interval(tween_speed) # Apenas espera
	tween.tween_callback(move_finished)

func attack_melee():
	if(GlobalVariables.DEBUG): print("NPC FIGHTER ou DOG: ATTACK!")
	
	player.die()
	
	moves_remaining = 0 #Ação de ataque deve consumir todos os movimentos restantes do turno
	
	var tween = create_tween()
	tween.tween_interval(tween_speed) # Apenas espera
	tween.tween_callback(move_finished)
	
## faz npc olhar para o player
func detect_player():
	cone_ray.look_at(player.global_position)
	last_player_global_position = player.global_position
	last_player_position = (player.global_position / GlobalVariables.TILE_SIZE).floor()
	if !alert:
		mode = Mode.FOLLOW 

#Funções Detecção do DOG
func _on_DetectionCircle_body_entered(body):
	if body is Player:
		alert = true # O cachorro viu/cheirou o jogador 
		mode = Mode.FOLLOW # Começa a perseguir

func _on_DetectionCircle_body_exited(body):
	if body is Player:
		alert = false # O jogador saiu do alcance 
	
func hear_sound(sound_position_global): #Chamada quando o som do player toca o círculo de detecção do dog
	if npc_type == Npc.NpcType.DOG and mode == Mode.PATROL: #Só reage ao som se for um DOG e estiver patrulhando
		print("DOG ouviu um som!")
		mode = Mode.ALERTED 
		last_player_position = (sound_position_global / GlobalVariables.TILE_SIZE).floor()#Salva a localização do som para investigar
		moves_remaining = 0  #Para o DOG por um turno para "escutar"
		move_finished()

func alert_investigate():#Ação do modo 'ALERTED'
	# Move-se em direção ao local do som
	var current_position = (global_position / GlobalVariables.TILE_SIZE).floor()
	go_towards_position(current_position, last_player_position)
	
	# Se o DOG chegou ao local do som e não viu o player, ele volta a patrulhar.
	if current_position == last_player_position and not alert:
		mode = Mode.PATROL

# --- Funções Latido do DOG
func _on_BarkAlert_body_entered(body):
	# Se o latido tocou outro NPC (que não seja o próprio dog)
	if body is Npc and body != self:
		# Se o outro NPC está patrulhando
		if body.mode == Mode.PATROL:
			if(GlobalVariables.DEBUG): print(body.name, " ouviu o latido do ", self.name)
			# Diga ao outro NPC para ir até a posição do cachorro
			body.alert_by_dog(global_position)

func alert_by_dog(dog_position_global):
	# Esta função é chamada em OUTROS NPCs
	if mode == Mode.PATROL:
		mode = Mode.FOLLOW
		# O NPC vai investigar o local do latido (posição do cachorro)
		last_player_position = (dog_position_global / GlobalVariables.TILE_SIZE).floor()

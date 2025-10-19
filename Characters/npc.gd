extends CharacterBody2D
class_name Npc

enum NpcType{
	SHOOTER, 
	FIGHTER	
}

enum Mode {
	PATROL,
	FOLLOW,
	AIMING,
	ATTACKING
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

#Behavior 
@export_group("Behavior") 
@export var npc_type : NpcType = NpcType.SHOOTER #Aqui se escolhe o tipo do NPC

#Combat
@export_group("Combat")
@export_subgroup("Shooter")
# TODO: Trocar pra 3 quando estiver consertado o delay do tiro
@export var time_to_shoot : int = 3 + 1 # Turnos que o shooter leva para atirar
@export_subgroup("Fighter")
@export var attack_range_melee : float = 1.5 # Distância que o fighter ataca (adjacentes)
var distance_to_player
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
var is_shooting : bool = false	# Quando atira (cone fica vermelho)
var cone_ray : RayCast2D
var cone_polygon : PackedVector2Array = []

func _ready() -> void:
	# Vision Cone
	cone_ray = $ConeRay
	feedback_label = $Label
	cone_ray_dist_alert *= GlobalVariables.TILE_SIZE
	cone_ray_dist = cone_ray_dist * GlobalVariables.TILE_SIZE # variável de alcance em tiles
	cone_ray.target_position = Vector2(0,cone_ray_dist)
	cone_ray.collide_with_areas = true # Colide com areas2d também
	if feedback_label:
		feedback_label.visible = false
	
func _draw() -> void:
	# Desenha polígono do cone de visão
	if (cone_polygon.size() > 3): # Só tenta desenhar se tem um polígono
		if (alert):
			draw_polygon(cone_polygon, [Color(1.0, 0.7, 0.0, 0.2)])
		elif (mode == Mode.FOLLOW):
			draw_polygon(cone_polygon, [Color(1.0, 1.0, 0.0, 0.2)])
		elif (is_shooting):
			draw_polygon(cone_polygon, [Color(1.0, 0.0, 0.0, 0.2)])
		else:
			draw_polygon(cone_polygon, [Color(1.0, 1.0, 1.0, 0.2)])
	
func _process(_delta) -> void:
	# TODO: Alerta de quando player chega perto (do lado ou atrás) também?
	# Ou talvez por "som"?
	print(is_shooting)
	if (moving):				
		if (alert):
			cone_ray.look_at(player.position)
			
			# Pra ajustar o look_at que fica "torto" 90 graus
			# (TODO: não é necessário, mas talvez ver como arrumar)
			cone_ray.rotation_degrees -= 90
			distance_to_player = global_position.distance_to(player.global_position) / GlobalVariables.TILE_SIZE
			
			if npc_type == NpcType.FIGHTER: # Se for Lutador, verifique se está perto o suficiente para atacar.
				if distance_to_player <= attack_range_melee:
					mode = Mode.ATTACKING
			
			if (mode == Mode.PATROL or mode == Mode.FOLLOW):
				if (npc_type == NpcType.SHOOTER):
					mode = Mode.AIMING
				else:
					mode = Mode.FOLLOW
				
			last_player_position = (player.global_position / GlobalVariables.TILE_SIZE).floor()
			
		else:
			match direction:
				Direction.UP:
					cone_ray.rotation_degrees = 180
				Direction.DOWN:
					cone_ray.rotation_degrees = 0
				Direction.LEFT:
					cone_ray.rotation_degrees = 90
				Direction.RIGHT:
					cone_ray.rotation_degrees = 270
					
		create_cone()

# Cria polígono do cone de visão
func create_cone():
	cone_polygon.clear()
	cone_polygon.append(cone_ray.position) # Posição do NPC
	var original_rotation = cone_ray.rotation_degrees
	var player_found : bool = false
	
	# Raycaster do ângulo de visão
	for i in range(-cone_ray_angle, cone_ray_angle+1):
		cone_ray.rotation_degrees = original_rotation + i
		cone_ray.force_raycast_update()
		if (cone_ray.is_colliding()):
			var colliding_object = cone_ray.get_collider()
			
			if (!player_found and colliding_object == player):
				player_found = true
				
				# TODO: fazer alerta no _process, talvez com outro raycast para parar o alerta
				# antes de contar +1 no tempo
				alert = true
				cone_ray_angle = cone_ray_angle_alert
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
	create_cone() # Para ter certeza que o player não está mais na visão TODO: Fazer de outra forma?
	
	match mode:
		Mode.FOLLOW:
			cone_ray.target_position = Vector2(0,cone_ray_dist_alert)
			current_patrol_index = -1
			follow_player()
		Mode.PATROL:
			cone_ray.target_position = Vector2(0,cone_ray_dist)
			if patrol_path.is_empty():
				_generate_patrol_path()
			if current_patrol_index == -1:
				var current_position: Vector2i = (global_position / GlobalVariables.TILE_SIZE).floor()
				current_patrol_index = find_closest_path_point(current_position)
			patrol()
		Mode.AIMING:
			cone_ray.target_position = Vector2(0,cone_ray_dist_alert)
			aim_gun()
		Mode.ATTACKING:
			attack_melee()

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
	tween.tween_callback(move_finished)

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
	move_direction = move_direction
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
	if (GlobalVariables.DEBUG): print(self.name, " stops moving")
	get_tree().call_group("Game", "child_done_confirmation")
	
func aim_gun():
	if (alert):
		aiming_timer += 1
	
		feedback_label.text = str(time_to_shoot - aiming_timer)
		feedback_label.visible = true
		
		if aiming_timer > time_to_shoot:
			shoot() # Atira
			
	else:
		aiming_timer = 0
		feedback_label.visible = false
		mode = Mode.FOLLOW
	
	# TODO: Tapa-buraco (trocar para uma forma de chamar direto o move_finished sem necessidade de delay?)
	var tween = create_tween()
	tween.tween_callback(move_finished)

func shoot():
	if(GlobalVariables.DEBUG): print("NPC SHOOTER: FIRE!")
	feedback_label.visible = false
	is_shooting = true # Ativa o cone vermelho (TODO: não funciona)
	
	player.die()

func attack_melee():
	if(GlobalVariables.DEBUG): print("NPC FIGHTER: ATTACK!")
	
	player.die()
		
	move_finished()

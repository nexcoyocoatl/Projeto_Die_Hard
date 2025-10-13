extends CharacterBody2D

enum Mode {
	PATROL,
	FOLLOW
}

enum Direction {
	UP,
	DOWN,
	LEFT,
	RIGHT
}

@export var tilemap_layer : TileMapLayer = null
@export var player : CharacterBody2D = null

# Pathfinding
@export var line_path : Line2D = null
@export var path : Path2D = null
@export var mode : Mode = Mode.FOLLOW
var pathfinding_grid : AStarGrid2D = AStarGrid2D.new()
var patrol_path : Array = []
var current_index : int

# Movement
@export var tween_speed : float = 0.2
var moving = false
var past_position : Vector2 = Vector2(0,0)
var direction : Direction
var cooldown : int = 0

# Vision Cone
@export var cone_ray_dist : int = 7
@export var cone_ray_angle : int = 40
var alert : bool = false
var cone_ray : RayCast2D
var cone_polygon : PackedVector2Array = []

func _draw() -> void:
	# Desenha polígono do cone de visão
	if (cone_polygon.size() > 3): # Só tenta desenhar se tem um polígono
		if (alert):
			draw_polygon(cone_polygon, [Color(130.0, 0.0, 0.0, 0.2)])
		else:
			draw_polygon(cone_polygon, [Color(130.0, 130.0, 0.0, 0.2)])
	
func _process(_delta) -> void:
	if (moving):
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
	
func _ready() -> void:
	# Vision Cone
	cone_ray = $ConeRay
	cone_ray_dist *= GlobalVariables.TILE_SIZE
	cone_ray.target_position = Vector2(0,cone_ray_dist)
	cone_ray.collide_with_areas = true # Colide com areas2d também
	
	#create_cone() # Cria cone pela primeira vez (desnecessário)
	
	# Pathfinding
	# TODO: Mudar para o Game(main.gd) maior parte da lógica
	line_path.global_position = Vector2(GlobalVariables.TILE_SIZE/2.0, GlobalVariables.TILE_SIZE/2.0)
	pathfinding_grid.region = tilemap_layer.get_used_rect()
	pathfinding_grid.cell_size = Vector2(GlobalVariables.TILE_SIZE, GlobalVariables.TILE_SIZE)
	pathfinding_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	pathfinding_grid.update()
	if mode == Mode.PATROL: 
		_generate_patrol_path()
		var current_position: Vector2i = (global_position / GlobalVariables.TILE_SIZE).floor()
		current_index = find_closest_path_point(current_position)
	
	var used_cells : Dictionary[Vector2i, bool] = {}
	for cell in tilemap_layer.get_used_cells():
		used_cells[cell] = true

	var region : Rect2i = pathfinding_grid.region
	for y in range(region.position.y, region.position.y + region.size.y):
		for x in range(region.position.x, region.position.x + region.size.x):
			var cell : Vector2i = Vector2i(x, y)
			if !used_cells.has(cell):
					pathfinding_grid.set_point_solid(cell, true)
	
	# Forma anterior
	#for cell in tilemap_layer.get_used_cells():
		#var is_solid : bool = tilemap_layer.get_cell_tile_data(cell).get_collision_polygons_count(0) > 0
		#pathfinding_grid.set_point_solid(cell, is_solid)

# Cria polígono do cone de visão
func create_cone():
	alert = 0
	cone_polygon.clear()
	cone_polygon.append(cone_ray.position) # Posição do NPC
	var original_rotation = cone_ray.rotation_degrees
	
	# Raycaster do ângulo de visão
	for i in range(-cone_ray_angle, cone_ray_angle+1):
		cone_ray.rotation_degrees = original_rotation + i
		cone_ray.force_raycast_update()
		if (cone_ray.is_colliding()):
			# Dá pra fazer por aqui direto ou pelo collision shape
			if (cone_ray.get_collider() == get_tree().get_nodes_in_group("Player")[0]):
				cone_polygon.append(cone_ray.to_global(cone_ray.target_position) - cone_ray.to_global(Vector2.ZERO))
				if (!alert):
					alert = 1
			else:
				cone_polygon.append(cone_ray.get_collision_point() - cone_ray.to_global(Vector2.ZERO))
				continue
		cone_polygon.append(cone_ray.to_global(cone_ray.target_position) - cone_ray.to_global(Vector2.ZERO))
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
	if mode == Mode.FOLLOW: 
		follow_player()
	elif mode == Mode.PATROL:
		if patrol_path.is_empty(): _generate_patrol_path()
		var current_position: Vector2i = (global_position / GlobalVariables.TILE_SIZE).floor()
		current_index = find_closest_path_point(current_position)
		patrol()

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
	if patrol_path.count(current_position) == 0:
		current_index = find_closest_path_point(current_position)
		go_towards_position(current_position, patrol_path[current_index])
		return
	# chegou no caminho de patrulha, segue de onde está
	if current_index == patrol_path.size() - 1: current_index = 1
	else: current_index = (current_index + 1) % patrol_path.size()
	var target: Vector2 = Vector2(patrol_path[current_index]) * GlobalVariables.TILE_SIZE + Vector2(GlobalVariables.TILE_SIZE/2.0, GlobalVariables.TILE_SIZE/2.0)
	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position", target, tween_speed).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(move_finished)

func follow_player():
	var current_position : Vector2i = (global_position / GlobalVariables.TILE_SIZE).floor()
	var player_position : Vector2i = (player.global_position / GlobalVariables.TILE_SIZE).floor()
	# se player estiver fora do tilemap
	if not pathfinding_grid.region.has_point(Vector2i(player_position)):
		move_finished()
		return
	go_towards_position(current_position, player_position)

func go_towards_position(from_position: Vector2i, to_position : Vector2i) -> void:
	var path_to_position = pathfinding_grid.get_point_path(from_position, to_position)
	line_path.points = path_to_position
	if path_to_position.size() <= 1: # vazio ou só tem o tile do proprio npc
		move_finished() 
		return
	path_to_position.remove_at(0)
	var next_position : Vector2 = path_to_position[0] + Vector2(GlobalVariables.TILE_SIZE/2.0, GlobalVariables.TILE_SIZE/2.0)
	var tween = create_tween()
	tween.tween_property(self, "global_position", next_position, tween_speed).set_trans(Tween.TRANS_SINE)
	line_path.points = path_to_position
	tween.tween_callback(move_finished)

func move_finished() -> void:
	moving = false
	get_tree().call_group("Game", "child_done_confirmation")
	

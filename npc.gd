extends CharacterBody2D

enum Mode {
	PATROL,
	FOLLOW
}

@export var tilemap_layer : TileMapLayer = null
@export var player : CharacterBody2D = null
@export var line_path : Line2D = null
@export var tween_speed : float = 0.2
@export var path : Path2D = null
@export var mode : Mode = Mode.FOLLOW

var pathfinding_grid : AStarGrid2D = AStarGrid2D.new()
var patrol_path : Array = []
var current_index : int

func _ready() -> void:
	# TODO: definir tiles navegaveis ao inves dos tiles sólidos
	line_path.global_position = Vector2(GlobalVariables.TILE_SIZE/2.0, GlobalVariables.TILE_SIZE/2.0)
	pathfinding_grid.region = tilemap_layer.get_used_rect()
	pathfinding_grid.cell_size = Vector2(GlobalVariables.TILE_SIZE, GlobalVariables.TILE_SIZE)
	pathfinding_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	pathfinding_grid.update()
	if mode == Mode.PATROL: 
		_generate_patrol_path()
		var current_position: Vector2i = (global_position / GlobalVariables.TILE_SIZE).floor()
		current_index = find_closest_path_point(current_position)
	
	for y in pathfinding_grid.region.size.y:
		for x in pathfinding_grid.region.size.x:
			var cell : Vector2i = Vector2i(x,y)
			if !tilemap_layer.get_used_cells().has(cell):
				pathfinding_grid.set_point_solid(cell, true)
	
	# Forma anterior
	#for cell in tilemap_layer.get_used_cells():
		#var is_solid : bool = tilemap_layer.get_cell_tile_data(cell).get_collision_polygons_count(0) > 0
		#pathfinding_grid.set_point_solid(cell, is_solid)

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
	get_tree().call_group("Game", "child_done_confirmation")
	

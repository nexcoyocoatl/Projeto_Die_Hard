extends CharacterBody2D

enum Mode {
	PATROL,
	FOLLOW
}

@export var _tilemap_layer : TileMapLayer = null
@export var _player : CharacterBody2D = null
@export var _line_path : Line2D = null
@export var _tween_speed : float = 0.2
@export var _path : Path2D = null
@export var _mode : Mode = Mode.FOLLOW

var _pathfinding_grid : AStarGrid2D = AStarGrid2D.new()
var _patrol_path : Array[Vector2i] = []
var _target_point : int = -1

func _ready() -> void:
	_line_path.global_position = Vector2(GlobalVariables.TILE_SIZE/2.0, GlobalVariables.TILE_SIZE/2.0)
	_pathfinding_grid.region = _tilemap_layer.get_used_rect()
	_pathfinding_grid.cell_size = Vector2(GlobalVariables.TILE_SIZE, GlobalVariables.TILE_SIZE)
	_pathfinding_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_pathfinding_grid.update()
	
	for cell in _tilemap_layer.get_used_cells():
		var is_solid : bool = _tilemap_layer.get_cell_tile_data(cell).get_collision_polygons_count(0) > 0
		_pathfinding_grid.set_point_solid(cell, is_solid)

func _generate_patrol_path(path : Path2D) -> Array[Vector2i]:
	var patrol_path : Array[Vector2i] = []
	for idx in range(path.curve.point_count):
		var global_point : Vector2 = path.curve.get_point_position(idx)
		var logical_point : Vector2i = (global_point / GlobalVariables.TILE_SIZE).floor()
		patrol_path.append(logical_point)
	if patrol_path[0] == patrol_path[patrol_path.size() - 1]: # remove ponto repetido do final
		patrol_path.pop_back()
	return patrol_path

func receive_points():
	if _mode == Mode.FOLLOW: 
		_target_point = -1
		follow_player()
	elif _mode == Mode.PATROL:
		if _patrol_path.is_empty(): 
			_patrol_path = _generate_patrol_path(_path)
		patrol()

func find_closest_path_point(given_position : Vector2i, patrol_path : Array[Vector2i]) -> int:
	var closest_index: int = 0
	var min_dist: float = INF
	for i in range(patrol_path.size()):
		var dist = given_position.distance_to(patrol_path[i])
		if dist < min_dist:
			min_dist = dist
			closest_index = i
	return closest_index

func patrol() -> void:
	if _patrol_path.is_empty():
		move_finished()
		return
		
	var current_position : Vector2i = (global_position / GlobalVariables.TILE_SIZE).floor()
	var has_target : bool = _target_point != -1
	if has_target:
		if current_position ==  _patrol_path[_target_point]: # se tem target e está nele, pega o próximo
			_target_point = (_target_point + 1) % _patrol_path.size()
		go_towards_position(current_position, _patrol_path[_target_point])
		return
		
	# senão, busca target e vai até ele
	var closest_point_idx : int = find_closest_path_point(current_position, _patrol_path)
	var after_closest_point_idx : int = (closest_point_idx + 1) % _patrol_path.size()
	var closest_point : Vector2i = _patrol_path[closest_point_idx]
	var after_closest_point : Vector2i = _patrol_path[after_closest_point_idx]
	
	var is_between_x : bool = (
		(current_position.x > closest_point.x and current_position.x < after_closest_point.x) 
		or 
		(current_position.x < closest_point.x and current_position.x > after_closest_point.x)
	)
	
	var is_between_y : bool = (
		(current_position.y > closest_point.y and current_position.y < after_closest_point.y) 
		or 
		(current_position.y < closest_point.y and current_position.y > after_closest_point.y)
	)
	
	if is_between_x or is_between_y or current_position == closest_point: _target_point = after_closest_point_idx
	else: _target_point = closest_point_idx
	
	go_towards_position(current_position, _patrol_path[_target_point])

func follow_player() -> void:
	var current_position : Vector2i = (global_position / GlobalVariables.TILE_SIZE).floor()
	var player_position : Vector2i = (_player.global_position / GlobalVariables.TILE_SIZE).floor()
	# se _player estiver fora do tilemap
	if not _pathfinding_grid.region.has_point(Vector2i(player_position)):
		move_finished()
		return
	go_towards_position(current_position, player_position)

func go_towards_position(from_position: Vector2i, to_position : Vector2i) -> void:
	var path_to_position : PackedVector2Array = _pathfinding_grid.get_point_path(from_position, to_position)
	_line_path.points = path_to_position
	if path_to_position.size() <= 1: # vazio ou só tem o tile do proprio npc
		move_finished() 
		return
	path_to_position.remove_at(0)
	var next_position : Vector2 = path_to_position[0] + Vector2(GlobalVariables.TILE_SIZE/2.0, GlobalVariables.TILE_SIZE/2.0)
	var tween = create_tween()
	tween.tween_property(self, "global_position", next_position, _tween_speed).set_trans(Tween.TRANS_SINE)
	_line_path.points = path_to_position
	tween.tween_callback(move_finished)

func move_finished() -> void:
	assert(get_tree().has_group("Game"))
	get_tree().call_group("Game", "child_done_confirmation")

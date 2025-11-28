extends Node
class_name Level

var logical_tilemap : TileMapLayer
var pathfinding_grid : AStarGrid2D = AStarGrid2D.new()
var player : Player
var hostage_scene : PackedScene = preload("res://hostage.tscn")
var hostages_rescued : int = 0
var total_hostages : int = 0
@onready var hostage_label = $HUD/HostageLabel

func init_pathgrid():
	# Pathfinding
	pathfinding_grid.region = logical_tilemap.get_used_rect()
	pathfinding_grid.cell_size = Vector2(GlobalVariables.TILE_SIZE, GlobalVariables.TILE_SIZE)
	pathfinding_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	pathfinding_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	pathfinding_grid.update()

	var used_cells : Dictionary = {}
	for cell in logical_tilemap.get_used_cells():
		used_cells[cell] = true
		# Se tile tem colisão
		if (logical_tilemap.get_cell_tile_data(cell).get_collision_polygons_count(0) > 0):
			# Esconde tile
			logical_tilemap.get_cell_tile_data(cell).modulate.a = 0.0
			# Põe no pathfinding grid como sólido
			pathfinding_grid.set_point_solid(cell, true)

	var region : Rect2i = pathfinding_grid.region
	for y in range(region.position.y, region.position.y + region.size.y):
		for x in range(region.position.x, region.position.x + region.size.x):
			var cell : Vector2i = Vector2i(x, y)
			if !used_cells.has(cell):
				pathfinding_grid.set_point_solid(cell, true)

func _ready() -> void:
	logical_tilemap = $Level1_LogicalTileMap
	init_pathgrid()
	var npcScene = preload("res://Characters/npc.tscn")
	player = get_tree().get_nodes_in_group("Player")[0]
	player.tilemap_layer = logical_tilemap
	# Cria npcs no inicio dos paths
	for path : Path2D in get_tree().get_nodes_in_group("Paths"):
		var line_path = Line2D.new()
		line_path.default_color = Color.RED
		line_path.width = 1
		line_path.position = Vector2(GlobalVariables.TILE_SIZE/2.0, GlobalVariables.TILE_SIZE/2.0)
		if (!GlobalVariables.DEBUG): line_path.modulate.a = 0.0
		add_child(line_path)
		
		var npc: Npc = npcScene.instantiate()
		npc.add_to_group("Npcs")
		npc.line_path = line_path
		npc.path = path
		npc.player = player
		npc.tilemap_layer = logical_tilemap
		npc.pathfinding_grid = pathfinding_grid
		npc.defaul_look_rotation = rad_to_deg( ( npc.path.curve.get_point_position(1) - npc.path.curve.get_point_position(0) ).angle() )
		npc.position = npc.path.curve.get_point_position(0)
		add_child(npc)
	
	# Tosqueira pra desenhar as partes do foreground em cima de tudo
	var foregroundNode = $Foreground
	remove_child(foregroundNode)
	add_child(foregroundNode)
	
	call_deferred("count_hostages")

		
func load_checkpoint() -> bool:
	if player in CheckpointManager.player_checkpoint_positions:
		player.visible = true
		player.set_physics_process(true)
		var player_data = CheckpointManager.player_checkpoint_positions[player]
		var half_tile = Vector2(GlobalVariables.TILE_SIZE / 2.0, GlobalVariables.TILE_SIZE / 2.0)
		
		if player_data.has("respawn"):
			player.global_position = player_data["respawn"] * GlobalVariables.TILE_SIZE + half_tile
		if player_data.has("is_dead"):
			player.is_dead = player_data["is_dead"]
		
		for npc: Npc in get_tree().get_nodes_in_group("Npcs"):
			if npc in CheckpointManager.npc_checkpoint_data:
				var data = CheckpointManager.npc_checkpoint_data[npc]
				npc.global_position = data["global_position"] * GlobalVariables.TILE_SIZE + half_tile
				if data.has("mode"):
					npc.mode = data["mode"]
				if data.has("alert"):
					npc.alert = data["alert"]
				if data.has("current_patrol_index"):
					npc.current_patrol_index = data["current_patrol_index"]
				if data.has("is_shooting"):
					npc.is_shooting = data["is_shooting"]
				if data.has("direction"):
					npc.direction = data["direction"]
				if data.has("cone_ray_angle"):
					npc.cone_ray_angle = data["cone_ray_angle"]
				if data.has("aiming_timer"):
					npc.aiming_timer = data["aiming_timer"]
				if data.has("cone_ray_target_pos"):
					npc.cone_ray.target_position = data["cone_ray_target_pos"]
				if data.has("cone_ray_rotation"):
					npc.cone_ray.rotation_degrees = data["cone_ray_rotation"]
				if data.has("player_found"):
					npc.player_found = data["player_found"]
				if data.has("last_player_position"):
					npc.last_player_position = data["last_player_position"]
				if data.has("feedback_label_visible"):
					npc.feedback_label.visible = data["feedback_label_visible"]
		
		for h : Hostage in get_tree().get_nodes_in_group("Hostages"):
			h.queue_free()
			await get_tree().process_frame 
		hostages_rescued = CheckpointManager.hostages_rescued
		if hostages_rescued == 0:
			for hostage_position in CheckpointManager.hostage_positions.keys():
				var hostage : Hostage = hostage_scene.instantiate()
				hostage.add_to_group("Hostages")
				hostage.position = hostage_position
				add_child(hostage)
		var hostages = get_tree().get_nodes_in_group("Hostages")
		for h in hostages:
			if not h.rescued.is_connected(_on_hostage_rescued):
				h.rescued.connect(_on_hostage_rescued)
		
		update_hostage_ui()

		return true
	return false
	
func count_hostages():
	var hostages = get_tree().get_nodes_in_group("Hostages")
	for h in hostages:
		h.rescued.connect(_on_hostage_rescued)
	total_hostages = hostages.size()
	hostages_rescued = 0
	update_hostage_ui()

func _on_hostage_rescued():
	hostages_rescued += 1
	update_hostage_ui()
	
	if (GlobalVariables.DEBUG): print("Hostage saved! Total: ", hostages_rescued)

func update_hostage_ui():
	if hostage_label:
		hostage_label.text = "Hostages: " + str(hostages_rescued) + "/" + str(total_hostages)

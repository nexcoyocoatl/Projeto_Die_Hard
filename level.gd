extends Node

var logical_tilemap : TileMapLayer
var pathfinding_grid : AStarGrid2D = AStarGrid2D.new()

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
	var player : Player = get_tree().get_nodes_in_group("Player")[0]
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
		npc.line_path = line_path
		npc.path = path
		npc.player = player
		npc.tilemap_layer = logical_tilemap
		npc.pathfinding_grid = pathfinding_grid
		add_child(npc)
		npc.position = npc.path.curve.get_point_position(0)

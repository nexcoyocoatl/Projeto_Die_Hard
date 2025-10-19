extends Node

var logical_tilemap : TileMapLayer
var pathfinding_grid : AStarGrid2D = AStarGrid2D.new()

func create_pathgrid():
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
	create_pathgrid()
	get_tree().call_group("Player", "receive_tilemap", logical_tilemap, pathfinding_grid)
	get_tree().call_group("Npc", "receive_tilemap", logical_tilemap, pathfinding_grid)
	# Passa referencia do player para os npcs. Analisar se pode passar só a posição
	get_tree().call_group("Npc", "receive_player_reference", get_tree().get_nodes_in_group("Player")[0])

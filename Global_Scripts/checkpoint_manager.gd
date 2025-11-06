extends Node

var player_checkpoint_positions : Dictionary = {}
var npc_checkpoint_data : Dictionary = {}

func save(body : Player, respawn : Vector2):
	player_checkpoint_positions[body] = (respawn / GlobalVariables.TILE_SIZE).floor()
	for npc : Npc in get_tree().get_nodes_in_group("Npcs"):
		print(npc.alert)
		npc_checkpoint_data[npc] = {
			"mode" : npc.mode,
			"alert" : npc.alert,
			"current_patrol_index" : npc.current_patrol_index,
			"global_position" : (npc.global_position / GlobalVariables.TILE_SIZE).floor(),
			"is_shooting" : npc.is_shooting,
			"direction" : npc.direction,
			"cone_ray_angle" : npc.cone_ray_angle,
			"aiming_timer" : npc.aiming_timer,
			"cone_ray_target_pos" : npc.cone_ray.target_position,
			"last_player_position" : npc.last_player_position
		}
	print("Saved")

func load_checkpoint():
	get_tree().get_first_node_in_group("Game").current_scene.load_checkpoint()

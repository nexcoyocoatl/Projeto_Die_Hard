extends Node

var player_checkpoint_positions : Dictionary = {}
var npc_checkpoint_data : Dictionary = {}
var hostage_positions : Dictionary = {}
var hostages_rescued : int = 0

func clear():
	player_checkpoint_positions.clear()
	npc_checkpoint_data.clear()
	hostage_positions.clear()

func save(body : Player, respawn : Vector2) -> bool:
	for npc : Npc in get_tree().get_nodes_in_group("Npcs"):
		if npc.mode == npc.Mode.FOLLOW or npc.alert:
			return false

	player_checkpoint_positions[body] = {
		"respawn" : (respawn / GlobalVariables.TILE_SIZE).floor(),
		"is_dead" : body.is_dead
	}
	
	for npc : Npc in get_tree().get_nodes_in_group("Npcs"):
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
			"cone_ray_rotation" : npc.cone_ray.rotation_degrees,
			"player_found" : npc.player_found,
			"last_player_position" : npc.last_player_position,
			"feedback_label_visible" : npc.feedback_label.visible
		}
		
	for hostage : Hostage in get_tree().get_nodes_in_group("Hostages"):
		if hostage == null: continue
		hostage_positions[hostage.position] = hostage.position
		hostages_rescued = get_tree().get_first_node_in_group("Game").current_scene.hostages_rescued
	print("Saved")
	return true
	
func load_checkpoint():
	get_tree().get_first_node_in_group("Game").current_scene.load_checkpoint()

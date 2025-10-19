extends Node

var logical_tilemap : TileMapLayer

func _ready() -> void:
	logical_tilemap = $Level1_LogicalTileMap

	get_tree().call_group("Player", "receive_tilemap", logical_tilemap)
	get_tree().call_group("Npc", "receive_tilemap", logical_tilemap)
	# Passa referencia do player para os npcs. Analisar se pode passar só a posição
	get_tree().call_group("Npc", "receive_player_reference", get_tree().get_nodes_in_group("Player")[0])

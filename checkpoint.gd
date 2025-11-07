extends Area2D

@onready var respawn : Vector2 = $Respawn.global_position

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		CheckpointManager.save(body, respawn)

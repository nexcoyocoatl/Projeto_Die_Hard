extends Area2D

@onready var respawn : Vector2 = $Respawn.global_position
var has_been_saved : bool = false

func _ready() -> void:
	if ($CheckpointSprite):
		$CheckpointSprite.modulate.a = 0.0

func _on_body_entered(body: Node2D) -> void:
	if !has_been_saved and body is Player:
		if ($AnimationPlayer):
			$AnimationPlayer.play("spawn_checkpoint_sprite")
		has_been_saved = CheckpointManager.save(body, respawn)
		

extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		AudioManager.play_sfx("final_screen")
		get_tree().root.add_child.call_deferred(preload("res://Screens/final_screen.tscn").instantiate())

extends CanvasLayer

func _ready():
	pass

func _process(_delta):
	pass

func _on_next_level_btn_pressed() -> void:
	var game = get_tree().root.get_node("Game")
	game.call_deferred("change_level", "res://Levels/level_2.tscn")
	self.queue_free()

func _on_quit_btn_pressed() -> void:
	get_tree().quit()

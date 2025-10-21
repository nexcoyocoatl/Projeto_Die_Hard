extends CanvasLayer

func _ready():
	pass
	
func  _process(_delta):
	pass

func _on_next_level_btn_pressed():
	get_tree().change_scene_to_file.call_deferred("res://game.tscn")
	self.queue_free() # a propria cena se mata

func _on_quit_btn_pressed():
	get_tree().quit()

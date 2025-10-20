extends Control

func _ready():
	pass
	
func _process(_delta):
	pass

func _on_restart_btn_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred("res://game.tscn")

func _on_quit_btn_pressed() -> void:
	get_tree().quit()

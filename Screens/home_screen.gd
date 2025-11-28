extends Control

func _ready():
	pass

func _process(_delta):
	pass

func _on_play_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://game.tscn")

func _on_exit_btn_pressed() -> void:
	get_tree().quit()

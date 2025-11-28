extends Area2D
class_name Hostage

signal rescued

var is_rescued : bool = false
var moving = false

func _ready():
	$HelpSpeechBaloon.modulate.a = 0.0
	body_entered.connect(_on_body_entered) 
	AudioManager.play_sfx("hostage")

func _on_body_entered(body):
	if !is_rescued && body is Player: 
		rescue()
		
func _process(_delta) -> void:
	if (moving && !is_rescued):
		move()
	if (is_rescued && !$AnimationPlayer.is_playing()):
		queue_free()

func receive_points():
	moving = true

func move():
	$AnimationPlayer.play("jump")
	move_finished()
	
func move_finished() -> void:
	moving = false
	if (GlobalVariables.DEBUG): print(self.name, " stops moving")
	get_tree().call_group("Game", "child_done_confirmation")

func rescue():
	if is_rescued: return
	is_rescued = true
	if(GlobalVariables.DEBUG): print("Hostage saved!")
	$AnimationPlayer.play("saved")
	emit_signal("rescued")
	$HelpSpeechBaloon.modulate.a = 0.0
	AudioManager.play_sfx("rescue")

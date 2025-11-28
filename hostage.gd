extends Area2D
class_name Hostage

signal rescued

var is_rescued : bool = false
var moving = false
var player

func _ready():
	$HelpSpeechBaloon.modulate.a = 0.0
	player = get_tree().get_nodes_in_group("Player")[0]
	body_entered.connect(_on_body_entered)

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
	
	if (self.global_position.distance_to(player.global_position) > 128) and (!$HostageCall.playing):
		$HostageCall.play()
	move_finished()
	
func move_finished() -> void:
	moving = false
	if (GlobalVariables.DEBUG): print(self.name, " stops moving")
	get_tree().call_group("Game", "child_done_confirmation")

func rescue():
	if(GlobalVariables.DEBUG): print("Hostage saved!")
	is_rescued = true
	$AnimationPlayer.play("saved")
	emit_signal("rescued")
	$HelpSpeechBaloon.modulate.a = 0.0
	AudioManager.play_sfx("rescue")

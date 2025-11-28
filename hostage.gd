extends Area2D
class_name Hostage

signal rescued

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is Player: 
		rescue() 

func rescue():
	if(GlobalVariables.DEBUG): print("Refém resgatado!")
	emit_signal("rescued")
	queue_free()

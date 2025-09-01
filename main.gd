extends Node2D

var count : float = 0

func _ready() -> void:
	update_count(count)
	
func _process(delta: float) -> void:
	print(delta)
	count += delta
	update_count(count)
	
func update_count(current_count: float) -> void:
	$Score.text = str(current_count)

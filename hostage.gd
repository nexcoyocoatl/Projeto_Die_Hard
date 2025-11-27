extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)# Conecta o sinal 'body_entered'(avisa quando um corpo físico entrar nesta área).

func _on_body_entered(body):
	if body is Player: 
		rescue() # Se for o jogador, chama a função de resgate!

func rescue():
	if(GlobalVariables.DEBUG): print("Refém resgatado!")
	get_tree().call_group("Game", "hostage_rescued") # Avisa o grupo "Game" que um resgate aconteceu.
	queue_free() # O refém já foi salvo, então ele desaparece do mapa.

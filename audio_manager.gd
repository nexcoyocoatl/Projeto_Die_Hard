# audio_manager.gd
extends Node

# Referência ao player de efeitos
@onready var sfx_player = $SFXPlayer

# --- Biblioteca de Sons ---
var sounds = {
	"player_step": [
		preload("res://SFX/player_step1.wav"), 
		preload("res://SFX/player_step2.wav")
	],
	"npc_step": [
		preload("res://SFX/npc_step1.wav"), 
		preload("res://SFX/npc_step2.wav") 
	],
	"hostage": [
		preload("res://SFX/hostage_call1.wav"), 
		preload("res://SFX/hostage_call2.wav"), 
		preload("res://SFX/hostage_call3.wav"), 
		preload("res://SFX/hostage_call4.wav"), 
		preload("res://SFX/hostage_call5.wav"), 
		preload("res://SFX/hostage_call6.wav"), 
		preload("res://SFX/hostage_call7.wav") 
	], 
	"boss": [
		preload("res://SFX/boss_intro.wav"), 
		preload("res://SFX/boss_call.wav")
	],
	"shoot": preload("res://SFX/weapon_fire.wav"),
	"attack": preload("res://SFX/melee_attack.wav"),
	"alert": preload("res://SFX/alert.wav"),
	"rescue": preload("res://SFX/hostage_rescued.wav"), 
	"pass_time": preload("res://SFX/pass_time.wav"),
}

func _ready():
	# Configura volume inicial (opcional)
	sfx_player.volume_db = -5.0

# --- Função de Tocar Som ---
func play_sfx(sound_name: String):
	if sounds.has(sound_name):
		var audio_resource = sounds[sound_name]
		
		# A CORREÇÃO ESTÁ AQUI:
		# Verifica se o que pegamos é uma LISTA (Array) com vários sons
		if audio_resource is Array:
			# Se for lista, sorteia um aleatório
			audio_resource = audio_resource.pick_random()
		
		# Agora 'audio_resource' é garantidamente um único som, não uma lista.
		_play_polyphonic(audio_resource)
	else:
		if(GlobalVariables.DEBUG): print("Som não encontrado: " + sound_name)
		
func _play_polyphonic(stream):
	var p = AudioStreamPlayer.new()
	add_child(p)
	p.stream = stream
	p.volume_db = -5.0
	p.finished.connect(p.queue_free) # Se deleta quando acaba
	p.play()

extends NPCBase

func _ready():
	super._ready()
	DialogueManager.dialogue_started.connect(talk_anim)
	DialogueManager.dialogue_ended.connect(idle_anim)
	match Stats.named_npcs["elena"]["met"]:
		0:
			DialogueModule.next_diag("meeting")

func _on_map_state_change(_statee:String):
	pass

func talk_anim(_x):
	_play_animation("Talking")
	
func idle_anim(_x):
	_play_animation("Idle")

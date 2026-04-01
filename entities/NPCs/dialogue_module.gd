extends Node3D

var npc: CharacterBody3D
var data: NPCData
var dialogue: DialogueResource

@onready var icon: Marker3D = $dialogue_indicator
@onready var player = get_tree().get_first_node_in_group('player')
@onready var area = $Area3D
@onready var collision_shape = $Area3D/CollisionShape3D
var player_near: bool= false
var talking:bool = false
var which_dialogue: String = "start"

func initialize(parent_npc: CharacterBody3D, npc_data: NPCData):
	npc = parent_npc
	data = npc_data
	dialogue = data.dialogue_ressource

func _ready() -> void:
	icon.set_deferred('visible', false)
	DialogueManager.dialogue_ended.connect(_dialogue_finished)
	DialogueManager.dialogue_started.connect(_dialogue_started)

func _physics_process(_delta: float) -> void:
	if data.talk_mode and player_near and Input.is_action_just_pressed("interact") and talking == false:
		DialogueManager.show_dialogue_balloon(dialogue, which_dialogue)
		
func next_diag(state:String):
	which_dialogue = state

func activate():
	data.talk_mode = true
	collision_shape.set_deferred("disabled", false)

	
func deactivate():
	data.talk_mode = false
	collision_shape.set_deferred("disabled", true)
	icon.set_deferred("visible", false)

func _dialogue_finished(_x):
	# This function is called when the dialogue ends
	talking = false
	# npc.transition_to(npc.NPCState.IDLE)

func _dialogue_started(_x):
	talking = true
	npc.transition_to(npc.NPCState.TALKING)
	
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body == player:
		player_near = true
		icon.set_deferred("visible", true)


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body == player:
		player_near = false
		icon.set_deferred("visible", false)

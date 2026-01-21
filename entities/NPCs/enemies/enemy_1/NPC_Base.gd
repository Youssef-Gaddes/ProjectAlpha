extends CharacterBody3D

@export var NPC_Data: NPCData


@export var Combat_Module_scene:PackedScene
@export var DialogueModule_scene:PackedScene

@export var Combat_Module:Node3D
@export var DialogueModule:Node3D

enum NPCState {
	IDLE,        # Just exists in world
	TALKING,     # Dialogue available     
	COMBAT,      # Fighting
	FLEEING,     # Exits Map
	DEAD
}
var state: NPCState = NPCState.IDLE
var health:int = 1
var target: CharacterBody3D
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree: AnimationTree = $AnimationTree if has_node("AnimationTree") else null
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback") if anim_tree else null
@export var mesh: MeshInstance3D

func _ready():
	if not NPC_Data:
		push_error("NPC has no data resource assigned!")
		return
	if NPC_Data.is_hostile:
		add_to_group('enemy')
	else:
		add_to_group('ally')
	_setup_modules()
	

func _on_attack_start():
	Combat_Module._on_attack_start()
func _on_windup_complete():
	Combat_Module._on_windup_complete()
func _on_hitbox_start():
	Combat_Module._on_hitbox_start()
func _on_hitbox_end():
	Combat_Module._on_hitbox_end()
func _on_lunge_end():
	Combat_Module._on_lunge_end()
func _on_attack_complete():
	Combat_Module._on_attack_complete()

func _select_target():
	if NPC_Data.fight_mode == false:
		pass
	if NPC_Data.is_hostile:
		if randf() <0.8:
			target = player
		else:
			if get_parent().allies.is_empty():
				target = player
			else:
				var x: CharacterBody3D = null
				for i in get_parent().allies:
					if x == null:
						x = i
					elif global_position.distance_to(x.global_position) > global_position.distance_to(i.global_position):
						x = i
				target = x
	elif NPC_Data.is_hostile == false:
		var x: CharacterBody3D = null
		for i in get_parent().enemies:
			if x == null:
				x = i
			elif global_position.distance_to(x.global_position) > global_position.distance_to(i.global_position):
				x = i
		target = x
	await get_tree().create_timer(2).timeout
	_select_target()


func _setup_modules():
	# Load combat module if needed
	if NPC_Data.can_fight:

		Combat_Module_scene = load("res://entities/NPCs/combat_module.tscn")
		Combat_Module = Combat_Module_scene.instantiate()
		add_child(Combat_Module)
		Combat_Module.initialize(self, NPC_Data)
		if get_parent().is_in_combat():
			Combat_Module.activate()
		else:
			Combat_Module.deactivate()
	
	# Load dialogue module if needed
	if NPC_Data.can_talk:
		DialogueModule = load("res://modules/dialogue_module.gd").new()
		add_child(DialogueModule)
		DialogueModule.initialize(self, NPC_Data)

func _physics_process(delta: float):
	if state == NPCState.DEAD or state == NPCState.COMBAT:
		return
	velocity.y = -9.8
	
	# Update state machine
	_update_state(delta)
	
	move_and_slide()

func _update_state(delta: float):
	match state:
		NPCState.IDLE:
			_state_idle(delta)
		
		NPCState.TALKING:
			pass
		
		NPCState.COMBAT:
			_state_combat(delta)
		
		NPCState.FLEEING:
			pass
		
		NPCState.DEAD:
			pass  # Nothing to do

func _state_idle(_delta: float):
	# Just stand there and idle
	velocity.x = 0
	velocity.z = 0
	
	_play_animation("Idle")
	
	# Check for state transitions
	if NPC_Data.can_fight  and target and NPC_Data.fight_mode:
		var distance = global_position.distance_to(target.global_position)
		if distance <= NPC_Data.detection_range:
			transition_to(NPCState.COMBAT)

func transition_to(new_state: NPCState):
	# Exit current state
	match state:
		NPCState.COMBAT:
			if Combat_Module and new_state!=NPCState.COMBAT:
				NPC_Data.fight_mode = false
				Combat_Module.deactivate()
				print("Help")
	
	# Enter new state
	state = new_state
	
	match new_state:
		NPCState.IDLE:
			_play_animation("Idle")
		
		NPCState.TALKING:
			if DialogueModule:
				DialogueModule.start_dialogue()
		
		NPCState.COMBAT:
			NPC_Data.fight_mode = true
			
		NPCState.FLEEING:
			_play_animation("Run")
		
		NPCState.DEAD:
			pass

func _state_combat(_delta: float):
	health = Combat_Module.health

func _play_animation(anim_name: String):
	if anim_state and anim_state.get_current_node() != anim_name:
		anim_state.travel(anim_name)

func force_enter_combat():
	"""External call to make NPC hostile"""
	if NPC_Data.can_fight and state == NPCState.IDLE:
		transition_to(NPCState.COMBAT)
		_select_target()
		Combat_Module.activate()

func force_exit_combat():
	if NPC_Data.can_fight and state == NPCState.COMBAT:
		transition_to(NPCState.IDLE)
		Combat_Module.deactivate()

func is_in_combat() -> bool:
	"""Check if NPC is currently in combat state"""
	return state == NPCState.COMBAT

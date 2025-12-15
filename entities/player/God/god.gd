extends CharacterBody3D

# === EXPORTS ===
@export_group("Movement")
@export var speed: float = 15
@export var idle_threshold: float = 0.1
@export var rotation_speed: float = 10.0
var can_move:bool = true

# === NODES ===
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var ui: CanvasLayer

# === STATE MACHINE ===
enum PlayerState { IDLE, WALK, SIT }
var current_state: PlayerState = PlayerState.IDLE
var talking:bool = false

# === INITIALIZATION ===
func _ready():
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_finished)
	ui = get_tree().get_first_node_in_group('UI')
	add_to_group("player")
	anim_state.travel("Idle")
	
func _physics_process(delta):
	if can_move == false:
		_play_animation("Idle")
		return
	if talking:
		return
	velocity.y = -5  # Gravity
	_update_state_machine(delta)
	# Movement
	move_and_slide()

func _on_dialogue_started(_x):
	talking = true # Disable player movement

func _on_dialogue_finished(_x):
	set_deferred('talking', false) # Re-enable player movement

func _update_state_machine(delta: float):
	match current_state:
		PlayerState.IDLE:
			_state_idle(delta)
		PlayerState.WALK:
			_state_walk(delta)
		PlayerState.SIT:
			_state_sit(delta)

func _state_idle(delta: float):
	_apply_friction(delta)
	
	var input = _get_movement_input()
	if input.length() > idle_threshold:
		_change_state(PlayerState.WALK)

func _state_walk(delta: float):
	var input = _get_movement_input()
	if input.length() < idle_threshold:
		_change_state(PlayerState.IDLE)
		return
	_move_with_input(input, speed, delta)

func _state_sit(_delta: float):
	pass

func _change_state(new_state: PlayerState):
	# Exit current state
	current_state = new_state
	
	match new_state:
		PlayerState.IDLE:
			_play_animation("Idle")
		
		PlayerState.WALK:
			_play_animation("Walk")
		
		PlayerState.SIT:
			_play_animation("StandToSit")
			
# === MOVEMENT HELPERS ===
func _get_movement_input() -> Vector2:
	return Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	
func _move_with_input(input: Vector2, move_speed: float, delta: float, allow_rotation: bool = true):
	var dir = Vector3(input.x, 0, input.y).normalized()
	
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	
	# Only rotate if allowed (disabled during attacks)
	if allow_rotation:
		smooth_rotate_toward(-dir, delta)
		rotation.x = 0
		rotation.z = 0
		
func _apply_friction(delta: float):
	velocity.x = move_toward(velocity.x, 0, 80 * delta)
	velocity.z = move_toward(velocity.z, 0, 80 * delta)

func smooth_rotate_toward(direction: Vector3, delta: float):
	var current_dir = -global_transform.basis.z.normalized()
	var smoothed_dir = current_dir.slerp(direction, rotation_speed * delta)
	look_at(global_position + smoothed_dir, Vector3.UP)

func get_mouse_position() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to,2)
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	else:
		return Vector3.ZERO

func _play_animation(anim_name: String):
	# Always travel to the requested node so animation notifies always run
	# (previous guard skipped travel when the current node was identical, causing notifies to not fire)
	anim_state.travel(anim_name)

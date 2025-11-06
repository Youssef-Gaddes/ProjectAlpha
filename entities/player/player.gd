# Player.gd
extends CharacterBody3D

@export var speed: float = 6.0
@export var turn_speed: float = 10.0
@export var idle_threshold: float = 0.1
@export var rotation_speed: float = 10

# Attack settings
@export var attack_speed_multiplier: float = 0.2 # slows player during attack
@export var attack_duration: float = 0.83333/2.5        # duration of attack animation

# Animation
@onready var anim_player: AnimationPlayer = $RootScene/AnimationPlayer

# Internal state
var is_attacking: bool = false
var attack_timer: float = 0.0

func _ready():
	# Fallback paths for AnimationPlayer
	if anim_player == null:
		anim_player = $AnimationPlayer if has_node("AnimationPlayer") else null
		if anim_player == null and has_node("ModelRoot/AnimationPlayer"):
			anim_player = $ModelRoot/AnimationPlayer

func _physics_process(delta):
	# Handle attack input
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_start_attack()

	# Update attack timer
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			_end_attack()

	# Get movement input
	var input_vec = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	# Stop if input too small
	if input_vec.length() < idle_threshold:
		_stop(delta)
		return

	# Convert 2D input to 3D direction
	var dir_3d = Vector3(input_vec.x, 0, input_vec.y)
	if dir_3d.length() > 0:
		dir_3d = dir_3d.normalized()

		# Adjust speed during attack
		var current_speed = speed
		if is_attacking:
			current_speed *= attack_speed_multiplier

		velocity.x = dir_3d.x * current_speed
		velocity.z = dir_3d.z * current_speed

		# Rotate smoothly toward movement direction
		smooth_rotate_toward(-dir_3d, delta)
		rotation.x = 0
		rotation.z = 0

		# Play walk animation if not attacking
		if anim_player != null and not is_attacking:
			if not anim_player.is_playing() or anim_player.current_animation != "CharacterArmature|Run":
				if anim_player.has_animation("CharacterArmature|Run"):
					anim_player.play("CharacterArmature|Run")

	move_and_slide()

func smooth_rotate_toward(direction: Vector3, delta: float) -> void:
	var current_dir = -global_transform.basis.z.normalized()
	var smoothed_dir = current_dir.slerp(direction, rotation_speed * delta)
	look_at(global_position + smoothed_dir, Vector3.UP)

func _stop(delta):
	# Smooth deceleration
	velocity.x = move_toward(velocity.x, 0, 20 * delta)
	velocity.z = move_toward(velocity.z, 0, 20 * delta)
	velocity.y = 0
	move_and_slide()
	if anim_player != null and not is_attacking:
		if anim_player.has_animation("CharacterArmature|Idle"):
			anim_player.play("CharacterArmature|Idle")

func _start_attack():
	is_attacking = true
	attack_timer = attack_duration
	if anim_player != null:
		if anim_player.has_animation("CharacterArmature|Punch_Right"):
			anim_player.speed_scale = 2.5 
			anim_player.play("CharacterArmature|Punch_Right")

func _end_attack():
	is_attacking = false
	anim_player.speed_scale = 1
	# Return to idle if no input
	if anim_player != null:
		if velocity.length() < idle_threshold:
			if anim_player.has_animation("CharacterArmature|Idle"):
				anim_player.play("CharacterArmature|Idle")

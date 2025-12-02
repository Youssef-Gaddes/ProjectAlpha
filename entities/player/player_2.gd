# Player.gd
extends CharacterBody3D

# === EXPORTS ===
@export_group("Movement")
@export var speed: float = 3.0
@export var running_speed: float = 9.0
@export var dodging_speed: float = 10.0
@export var rotation_speed: float = 10.0
@export var idle_threshold: float = 0.1

@export_group("Combat")
@export var attack_damage: Array[float] = [10.0, 15.0, 25.0]
@export var attack_duration: Array[float] = [0.8667, 1.0, 1.5333]
@export var attack_speed: float = 2
@export var attack_speed_multiplier: float = 0.4
@export var max_combo: int = 3
@export var combo_window: float = 0.25
@export var hitbox_activation_delay: float = 0.21 / 1.5
@export var hitbox_active_duration: float = (0.7 - 0.21) / 1.5

@export_group("Dodge")
@export var dodge_duration: float = 1.4667 / 3.5

@export_group("Health")
@export var max_health: float = 200.0
@export var invulnerability_duration: float = 0.5

@export_group("Visual Effects")
@export var hit_particle_scene: PackedScene
@export var swing_particle_scene: PackedScene

# === NODES ===
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var hitbox: Area3D = $Hitbox
@onready var hitbox_collision: CollisionShape3D = $Hitbox/AttackHitbox

# === STATE MACHINE ===
enum PlayerState { IDLE, WALK, RUN, ATTACK, DODGE, HIT, DEAD }
var current_state: PlayerState = PlayerState.IDLE

# === COMBAT STATE ===
var attack_index: int = 0
var combo_queued: bool = false
var attack_timer: float = 0.0
var attack_dir: Vector3 = Vector3.ZERO
var hit_enemies: Array = []
var hitbox_timer: float = 0.0
var hitbox_active: bool = false

# === DODGE STATE ===
var dodge_dir: Vector3 = Vector3.ZERO
var dodge_timer: float = 0.0

# === HEALTH STATE ===
var current_health: float
var is_invulnerable: bool = false

# === INITIALIZATION ===
func _ready():
	add_to_group("player")
	current_health = max_health
	anim_state.travel("Idle")
	_setup_hitbox()
	attack_duration[0] = attack_duration[0]/attack_speed
	attack_duration[1] = attack_duration[1]/attack_speed
	attack_duration[2] = attack_duration[2]/attack_speed

func _setup_hitbox():
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		hitbox_collision.disabled = true

# === MAIN LOOP ===
func _physics_process(delta):
	velocity.y = -5  # Gravity
	
	# Update systems
	_update_hitbox(delta)
	_update_state_machine(delta)
	
	# Movement
	move_and_slide()

# === STATE MACHINE ===
func _update_state_machine(delta: float):
	match current_state:
		PlayerState.IDLE:
			_state_idle(delta)
		PlayerState.WALK:
			_state_walk(delta)
		PlayerState.RUN:
			_state_run(delta)
		PlayerState.ATTACK:
			_state_attack(delta)
		PlayerState.DODGE:
			_state_dodge(delta)
		PlayerState.HIT:
			_state_hit(delta)
		PlayerState.DEAD:
			_state_dead(delta)

func _state_idle(delta: float):
	_apply_friction(delta)
	
	# Transitions
	if Input.is_action_just_pressed("attack"):
		_change_state(PlayerState.ATTACK)
		return
	
	var input = _get_movement_input()
	if input.length() > idle_threshold:
		if Input.is_action_just_pressed("dodge"):
			_change_state(PlayerState.DODGE)
		elif Input.is_action_pressed("dash"):
			_change_state(PlayerState.RUN)
		else:
			_change_state(PlayerState.WALK)

func _state_walk(delta: float):
	var input = _get_movement_input()
	
	# Transitions
	if Input.is_action_just_pressed("attack"):
		_change_state(PlayerState.ATTACK)
		return
	
	if input.length() < idle_threshold:
		_change_state(PlayerState.IDLE)
		return
	
	if Input.is_action_just_pressed("dodge"):
		_change_state(PlayerState.DODGE)
		return
	
	if Input.is_action_pressed("dash"):
		_change_state(PlayerState.RUN)
		return
	
	# Movement
	_move_with_input(input, speed, delta)

func _state_run(delta: float):
	var input = _get_movement_input()
	
	# Transitions
	if Input.is_action_just_pressed("attack"):
		_change_state(PlayerState.ATTACK)
		return
	
	if input.length() < idle_threshold:
		_change_state(PlayerState.IDLE)
		return
	
	if Input.is_action_just_pressed("dodge"):
		_change_state(PlayerState.DODGE)
		return
	
	if not Input.is_action_pressed("dash"):
		_change_state(PlayerState.WALK)
		return
	
	# Movement
	_move_with_input(input, running_speed, delta)

func _state_attack(delta: float):
	attack_timer -= delta
	
	# LOCK rotation towards attack direction (no movement input influence)
	look_at(global_position - attack_dir, Vector3.UP)
	rotation.x = 0
	rotation.z = 0
	
	# Check for dodge interrupt
	if Input.is_action_just_pressed("dodge"):
		_interrupt_attack()
		_change_state(PlayerState.DODGE)
		return

	if attack_timer >= attack_duration[attack_index-1]-0.08:
		velocity.x = attack_dir.x * 6
		velocity.z = attack_dir.z * 6
	else:
		velocity.x = attack_dir.x * 0.6
		velocity.z = attack_dir.z * 0.6
		
	
	# Queue combo
	if attack_timer <= combo_window and Input.is_action_just_pressed("attack"):
		combo_queued = true
	
	# End attack
	if attack_timer <= 0:
		if combo_queued:
			_continue_combo()  # Always continue if queued (loops back to attack 1)
		else:
			_end_attack()

func _state_dodge(delta: float):
	dodge_timer -= delta
	
	# Locked movement during dodge
	velocity.x = dodge_dir.x * dodging_speed
	velocity.z = dodge_dir.z * dodging_speed
	
	if dodge_timer <= 0:
		_end_dodge()

func _state_hit(delta: float):
	# Slow movement during hitstun
	var input = _get_movement_input()
	if input.length() > idle_threshold:
		_move_with_input(input, speed * 0.1, delta)
	else:
		_apply_friction(delta)

func _state_dead(_delta: float):
	velocity = Vector3.ZERO

# === STATE TRANSITIONS ===
func _change_state(new_state: PlayerState):
	# Exit current state
	match current_state:
		PlayerState.DODGE:
			# Re-enable collisions when leaving dodge
			set_collision_mask_value(3, true)
			if has_node("Hurtbox"):
				$Hurtbox.set_collision_layer_value(6, true)
		
		PlayerState.ATTACK:
			# Clean up attack state if interrupted
			if new_state != PlayerState.ATTACK:
				_deactivate_hitbox()
	
	# Enter new state
	current_state = new_state
	
	match new_state:
		PlayerState.IDLE:
			_play_animation("Idle")
		
		PlayerState.WALK:
			_play_animation("Walk")
		
		PlayerState.RUN:
			_play_animation("Run")
		
		PlayerState.ATTACK:
			_start_attack()
		
		PlayerState.DODGE:
			_start_dodge()
		
		PlayerState.HIT:
			_play_animation("Hit")
		
		PlayerState.DEAD:
			_play_animation("Die")

# === COMBAT SYSTEM ===
func _start_attack():
	attack_index = 1 if attack_index == 0 else attack_index
	attack_timer = attack_duration[attack_index-1]
	combo_queued = false
	
	# Lock attack direction
	attack_dir = get_mouse_direction()
	if attack_dir == Vector3.ZERO:
		attack_dir = -global_transform.basis.z
	
	# Instantly face attack direction
	look_at(global_position - attack_dir, Vector3.UP)
	rotation.x = 0
	rotation.z = 0
	
	# Play animation and activate hitbox
	_play_animation("Punch" + str(attack_index))
	hitbox_timer = attack_duration[attack_index-1]
	_spawn_swing_particle()

func _continue_combo():
	if attack_index == max_combo:
		attack_index =1
		attack_dir = get_mouse_direction()
		if attack_dir == Vector3.ZERO:
			attack_dir = -global_transform.basis.z
		look_at(global_position - attack_dir, Vector3.UP)
		rotation.x = 0
		rotation.z = 0
	else:
		attack_index += 1
	attack_timer = attack_duration[attack_index-1]
	combo_queued = false
	
	_play_animation("Punch" + str(attack_index))
	hitbox_timer = attack_duration[attack_index-1]-0.2
	_spawn_swing_particle()

func _interrupt_attack():
	# Reset combo when attack is interrupted
	attack_index = 0
	combo_queued = false
	attack_timer = 0
	_deactivate_hitbox()
	hitbox_timer = 0
	print("Attack interrupted!")

func _end_attack():
	attack_index = 0
	combo_queued = false
	_deactivate_hitbox()
	hitbox_timer = 0
	
	# Return to movement state
	var input = _get_movement_input()
	if input.length() < idle_threshold:
		_change_state(PlayerState.IDLE)
	elif Input.is_action_pressed("dash"):
		_change_state(PlayerState.RUN)
	else:
		_change_state(PlayerState.WALK)

# === DODGE SYSTEM ===
func _start_dodge():
	var input = _get_movement_input()
	
	# Set dodge direction
	if input.length() > 0:
		dodge_dir = Vector3(input.x, 0, input.y).normalized()
	else:
		dodge_dir = -global_transform.basis.z
	
	# Face dodge direction
	look_at(global_position - dodge_dir, Vector3.UP)
	rotation.x = 0
	rotation.z = 0
	
	dodge_timer = dodge_duration
	
	# Disable collisions during dodge (i-frames)
	set_collision_mask_value(3, false)  # Enemy bodies (layer 3)
	$Hurtbox.set_collision_layer_value(6, false)  # Player hurtbox (layer 6) - can't be hit
	
	_play_animation("Roll")

func _end_dodge():
	# Re-enable collisions
	set_collision_mask_value(3, true)
	$Hurtbox.set_collision_layer_value(6, true)
	
	velocity = Vector3.ZERO
	_change_state(PlayerState.IDLE)

# === HITBOX SYSTEM ===
func _update_hitbox(delta: float):
	if hitbox_timer > 0:
		hitbox_timer -= delta
		
		if not hitbox_active and hitbox_timer <= hitbox_active_duration:
			_activate_hitbox()
		
		if hitbox_timer <= 0:
			_deactivate_hitbox()

func _activate_hitbox():
	hitbox_active = true
	hitbox_collision.set_deferred('disabled', false)
	hit_enemies.clear()

func _deactivate_hitbox():
	hitbox_active = false
	hitbox_collision.set_deferred('disabled', true)

func _on_hitbox_area_entered(area: Area3D):
	if not area.is_in_group("enemy_hurtbox"):
		return
	
	var enemy = area.get_parent()
	if not enemy.has_method("take_damage") or enemy in hit_enemies:
		return
	
	hit_enemies.append(enemy)
	
	var damage = attack_damage[attack_index - 1] if attack_index <= attack_damage.size() else 10.0
	var knockback_dir = (enemy.global_position - global_position).normalized()
	
	enemy.take_damage(damage, knockback_dir)
	_spawn_hit_particle(area.global_position)

# === HEALTH SYSTEM ===
func take_damage(damage: float, knockback_dir: Vector3):
	if is_invulnerable or current_state == PlayerState.DODGE:
		return
	
	current_health -= damage
	print("Player took ", damage, " damage! Health: ", current_health)
	
	velocity = knockback_dir * 5.0
	velocity.y = 2.0
	
	_change_state(PlayerState.HIT)
	
	# Hitstun
	await get_tree().create_timer(0.2).timeout
	if current_state == PlayerState.HIT:
		_change_state(PlayerState.IDLE)
	
	# I-frames
	is_invulnerable = true
	await get_tree().create_timer(invulnerability_duration).timeout
	is_invulnerable = false
	
	if current_health <= 0:
		die()

func die():
	_change_state(PlayerState.DEAD)
	print("Player died!")

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
	velocity.x = move_toward(velocity.x, 0, 40 * delta)
	velocity.z = move_toward(velocity.z, 0, 40 * delta)

func smooth_rotate_toward(direction: Vector3, delta: float):
	var current_dir = -global_transform.basis.z.normalized()
	var smoothed_dir = current_dir.slerp(direction, rotation_speed * delta)
	look_at(global_position + smoothed_dir, Vector3.UP)

func get_mouse_direction() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var dir = (result.position - global_position)
		dir.y = 0
		return dir.normalized()
	
	return Vector3.ZERO

# === VISUAL EFFECTS ===
func _play_animation(anim_name: String):
	if anim_state.get_current_node() != anim_name:
		anim_state.travel(anim_name)

func _spawn_hit_particle(hit_position: Vector3):
	if not hit_particle_scene:
		return
	
	var particle = hit_particle_scene.instantiate()
	get_tree().root.add_child(particle)
	particle.global_position = hit_position
	particle.look_at(global_position)
	
	if particle is GPUParticles3D:
		particle.emitting = true
		particle.finished.connect(particle.queue_free)
		await get_tree().create_timer(particle.lifetime + 0.5).timeout
		if is_instance_valid(particle):
			particle.queue_free()
	elif particle is CPUParticles3D:
		particle.emitting = true
		await get_tree().create_timer(particle.lifetime + 0.5).timeout
		if is_instance_valid(particle):
			particle.queue_free()

func _spawn_swing_particle():
	if not swing_particle_scene:
		return
	
	var particle = swing_particle_scene.instantiate()
	add_child(particle)
	particle.position = Vector3(0, 1, 1)
	
	await get_tree().create_timer(attack_duration[attack_index-1]).timeout
	if is_instance_valid(particle):
		particle.queue_free()

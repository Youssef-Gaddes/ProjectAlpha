extends CharacterBody3D

# === COMBAT STATS ===
@export_group("Combat")
@export var max_health: float = 200.0
@export var defense: float = 0.0

# === MOVEMENT ===
@export_group("Movement")
@export var run_speed: float = 6.0
@export var walk_speed: float = 3.0
@export var rotation_speed: float = 8

# === AI RANGES ===
@export_group("Detection")
@export var detection_range: float = 15.0
@export var walk_range: float = 6.0
@export var stop_distance: float = 2.0

# === ATTACK SYSTEM ===
@export_group("Attacks")
@export var quick_jab_range: float = 2.0
@export var heavy_swing_range: float = 4
@export var lunge_strike_range: float = 9

@export var quick_jab_damage: float = 10.0
@export var heavy_swing_damage: float = 20.0
@export var lunge_strike_damage: float = 30.0
@export var lunging:bool = false

@export var quick_jab_hitbox_size: Vector3 = Vector3(2.44, 1.77, 1.27)      # Small, close-range jab
@export var quick_jab_hitbox_pos: Vector3 = Vector3(0.01, 0.88, 1.43) 
@export var heavy_swing_hitbox_size: Vector3 = Vector3(2.82, 1.77, 1.94)       # Wide arc swing
@export var heavy_swing_hitbox_pos: Vector3 = Vector3(0.01, 0.88, 1.95) 
@export var lunge_strike_hitbox_size: Vector3 = Vector3(2.12, 1.77, 1.28)    # Long forward reac
@export var lunge_strike_hitbox_pos: Vector3 = Vector3(0.01, 0.88, 1.44) 


@export var attack_cooldown: float = 0.5

# === KNOCKBACK ===
@export_group("Knockback")
@export var knockback_strength: float = 10.0
@export var knockback_duration: float = 0.4
@export var hit_stun_duration: float = 1.0

# === NAVIGATION ===
@export_group("Navigation")
@export var path_update_rate: float = 0.2
@export var avoidance_enabled: bool = true
@export var avoidance_radius: float = 0.4
@export var arc_strength: float = 0.2

# === NODES ===
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree: AnimationTree = $AnimationTree if has_node("AnimationTree") else null
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback") if anim_tree else null
@onready var hitbox_area: Area3D = $Hitbox if has_node("Hitbox") else null
@onready var hitbox_shape: CollisionShape3D = $Hitbox/CollisionShape3D if has_node("Hitbox/CollisionShape3D") else null
@onready var health_bar: Sprite3D = $Sprite3D if has_node("Sprite3D") else null
@onready var dmg_label: Sprite3D = $damage_number if has_node("damage_number") else null
@onready var mesh: MeshInstance3D = $enemy/Armature/Skeleton3D/Ch25 if has_node("enemy/Armature/Skeleton3D/Ch25") else null

# === STATE MACHINE ===
enum State { IDLE, CHASE, WALK, WINDUP, ATTACKING, RECOVERY, HURT, DEAD }
var state: State = State.IDLE

# === ATTACK STATE ===
enum AttackType { QUICK_JAB, HEAVY_SWING, LUNGE_STRIKE }
var current_attack: AttackType = AttackType.QUICK_JAB
var attack_cooldown_timer: float = 0.0
var locked_rotation: float = 0.0
var hit_player_this_attack: bool = false

# === FLASH STATE ===
var flash_tween: Tween
var flash_original_color: Color = Color.WHITE
var flash_material: StandardMaterial3D
var is_flashing: bool = false

# === KNOCKBACK STATE ===
var knockback_timer: float = 0.0
var knockback_velocity: Vector3 = Vector3.ZERO
var hit_stun_timer: float = 0.0

# === NAVIGATION ===
var path_update_timer: float = 0.0
var arc_direction: int = 1

# === HEALTH ===
var health: float

# =====================================================================
# INITIALIZATION
# =====================================================================

func _ready() -> void:
	health = max_health
	arc_direction = 1 if randf() < 0.5 else -1
	add_to_group("enemies")
	
	_setup_navigation()
	_setup_hitbox()
	_setup_material()
	
	if not player:
		push_error("No player in scene! Add player to 'player' group")
	
	call_deferred("_post_ready")

func _post_ready() -> void:
	await get_tree().physics_frame
	if player:
		nav_agent.target_position = player.global_position

func _setup_navigation() -> void:
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.1
	nav_agent.max_speed = run_speed
	nav_agent.path_max_distance = 3.0
	
	if avoidance_enabled:
		nav_agent.avoidance_enabled = true
		nav_agent.radius = avoidance_radius
		nav_agent.neighbor_distance = 1.3
		nav_agent.max_neighbors = 10
		nav_agent.time_horizon_agents = 1.0
		nav_agent.avoidance_layers = 1
		nav_agent.avoidance_mask = 1
	
	nav_agent.velocity_computed.connect(_on_velocity_computed)

func _setup_hitbox() -> void:
	if hitbox_shape:
		hitbox_shape.set_deferred('disabled', true)
	if hitbox_area:
		hitbox_area.area_entered.connect(_on_hitbox_entered)

func _setup_material() -> void:
	if not mesh:
		return
	
	var mat: StandardMaterial3D = mesh.get_active_material(0)
	if mat:
		mat = mat.duplicate()
		mesh.set_surface_override_material(0, mat)
		flash_material = mat
		flash_original_color = mat.albedo_color

# =====================================================================
# MAIN LOOP
# =====================================================================

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	
	velocity.y = -9.8
	
	_update_timers(delta)
	_update_ai(delta)
	
	move_and_slide()

# =====================================================================
# TIMER UPDATES
# =====================================================================

func _update_timers(delta: float) -> void:
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	
	if knockback_timer > 0:
		knockback_timer -= delta
		if knockback_timer <= 0:
			knockback_velocity = Vector3.ZERO
	
	if hit_stun_timer > 0:
		hit_stun_timer -= delta

# =====================================================================
# AI STATE MACHINE
# =====================================================================

func _update_ai(delta: float) -> void:
	if not player:
		return
	
	var distance: float = global_position.distance_to(player.global_position)
	
	path_update_timer -= delta
	if path_update_timer <= 0:
		path_update_timer = path_update_rate
		if state in [State.CHASE, State.WALK]:
			nav_agent.target_position = player.global_position
	
	match state:
		State.IDLE:
			_state_idle(distance)
		State.CHASE:
			_state_chase(distance, delta)
		State.WALK:
			_state_walk(distance, delta)
		State.WINDUP:
			_state_windup(delta)
		State.ATTACKING:
			_state_attacking(delta)
		State.RECOVERY:
			_state_recovery(delta)
		State.HURT:
			_state_hurt(delta)

# === STATE: IDLE ===
func _state_idle(distance: float) -> void:
	velocity.x = 0
	velocity.z = 0
	
	if distance <= detection_range and player.current_health > 0:
		_transition_to(State.CHASE)
	else:
		_play_animation("Idle")

# === STATE: CHASE ===
func _state_chase(distance: float, delta: float) -> void:
	if _can_attack() and distance <= lunge_strike_range and player.current_health > 0:
		_choose_attack(distance)
		_transition_to(State.WINDUP)
		return
	
	if distance <= walk_range and player.current_health > 0:
		_transition_to(State.WALK)
		return
	
	if distance > detection_range:
		_transition_to(State.IDLE)
		return
	
	_follow_path(run_speed, delta)
	_play_animation("Run")

# === STATE: WALK ===
func _state_walk(distance: float, delta: float) -> void:
	if _can_attack() and distance <= lunge_strike_range and player.current_health > 0:
		_choose_attack(distance)
		_transition_to(State.WINDUP)
		return
	
	if distance > walk_range and player.current_health > 0:
		_transition_to(State.CHASE)
		return
	
	if distance <= stop_distance:
		velocity.x = 0
		velocity.z = 0
		_rotate_towards_player(delta)
		_play_animation("Idle")
	else:
		_follow_path(walk_speed, delta)
		_play_animation("Walk")

# === STATE: WINDUP ===
func _state_windup(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	nav_agent.velocity = Vector3.ZERO
	
	
	rotation.y = locked_rotation
	rotation.x = 0
	rotation.z = 0
	
	# Animation calls _on_windup_complete() to transition

# === STATE: ATTACKING ===
func _state_attacking(_delta: float) -> void:
	nav_agent.velocity = Vector3.ZERO
	
	rotation.y = locked_rotation
	rotation.x = 0
	rotation.z = 0
	
	# Lunge movement (will be stopped by _on_lunge_end() callback)
	if current_attack == AttackType.LUNGE_STRIKE and lunging == true:
		var forward: Vector3 = -global_basis.z
		velocity.x = forward.x * -8.0
		velocity.z = forward.z * -8.0
		set_collision_mask_value(3, false)  # Disable enemy collision during lunge
	else:
		velocity.x = 0
		velocity.z = 0
	
	# Animation calls  to stop lunge
	# Animation calls _on_attack_complete() to transition

# === STATE: RECOVERY ===
func _state_recovery(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	nav_agent.velocity = Vector3.ZERO
	
	# This state is just waiting - animation calls _on_attack_complete()

# === STATE: HURT ===
func _state_hurt(delta: float) -> void:
	velocity.x = knockback_velocity.x
	velocity.z = knockback_velocity.z
	
	knockback_velocity.x = move_toward(knockback_velocity.x, 0, 20.0 * delta)
	knockback_velocity.z = move_toward(knockback_velocity.z, 0, 20.0 * delta)
	
	if hit_stun_timer <= 0:
		if player:
			var distance: float = global_position.distance_to(player.global_position)
			if distance <= walk_range:
				_transition_to(State.WALK)
			else:
				_transition_to(State.CHASE)
		else:
			_transition_to(State.IDLE)

# =====================================================================
# STATE TRANSITIONS
# =====================================================================

func _transition_to(new_state: State) -> void:
	# Always disable hitbox when leaving attack states
	if state in [State.WINDUP, State.ATTACKING, State.RECOVERY]:
		_disable_hitbox()
	
	# Re-enable collision mask if leaving lunge attack
	if state == State.ATTACKING and current_attack == AttackType.LUNGE_STRIKE:
		set_collision_mask_value(3, true)
	
	state = new_state
	
	match new_state:
		State.IDLE:
			_play_animation("Idle")
		
		State.CHASE:
			_play_animation("Run")
		
		State.WALK:
			_play_animation("Walk")
		
		State.WINDUP:
			hit_player_this_attack = false
			_disable_hitbox()
			_rotate_towards_player(0.016)
			locked_rotation = rotation.y
			_play_animation(_get_attack_animation())
		
		State.ATTACKING:
			pass  # No animation change - continue from windup
		
		State.RECOVERY:
			_disable_hitbox()
			attack_cooldown_timer = attack_cooldown
		
		State.HURT:
			_stop_flash()
			_disable_hitbox()
			_play_animation("Hit")
		
		State.DEAD:
			_stop_flash()
			_disable_hitbox()
			_play_animation("Die")
			_die()
	

# =====================================================================
# ANIMATION CALLBACKS
# =====================================================================

func act_die():
	take_damage(max_health, Vector3.ZERO)
	

func _on_attack_start() -> void:
	_rotate_towards_player(0.16)
	"""Called at frame 0 of attack animation"""
	_start_flash()

func _on_windup_complete() -> void:
	"""Called when windup ends - transition to attacking"""
	_stop_flash()
	if state == State.WINDUP:
		state = State.ATTACKING  # Direct state change, no animation change


func _on_hitbox_start() -> void:
	"""Called when damage frames begin"""
	_enable_hitbox()

func _on_hitbox_end() -> void:
	"""Called when damage frames end"""
	_disable_hitbox()

func _on_lunge_end() -> void:
	"""Called when lunge movement should stop (only for lunge attack)"""
	lunging = false
	velocity.x = 0
	velocity.z = 0
	set_collision_mask_value(3, true)  # Re-enable enemy collision


func _on_attack_complete() -> void:
	"""Called when attack animation ends - return to movement"""
	_disable_hitbox()
	
	# Re-enable collision if was lunging
	if current_attack == AttackType.LUNGE_STRIKE:
		set_collision_mask_value(3, true)
	
	# Start cooldown
	attack_cooldown_timer = attack_cooldown
	
	# Return to movement
	if state in [State.ATTACKING, State.RECOVERY, State.WINDUP]:
		if player:
			var distance: float = global_position.distance_to(player.global_position)
			if distance <= walk_range:
				_transition_to(State.WALK)
			else:
				_transition_to(State.CHASE)
		else:
			_transition_to(State.IDLE)

# =====================================================================
# ATTACK SYSTEM
# =====================================================================

func _can_attack() -> bool:
	return attack_cooldown_timer <= 0 and state not in [State.WINDUP, State.ATTACKING, State.RECOVERY, State.HURT]

func _choose_attack(distance: float) -> void:
	if distance <= quick_jab_range:
		current_attack = AttackType.QUICK_JAB
		$Hitbox/CollisionShape3D.shape.size = quick_jab_hitbox_size
		$Hitbox/CollisionShape3D.position = quick_jab_hitbox_pos
	elif distance <= heavy_swing_range and distance >= quick_jab_range:
		current_attack = AttackType.HEAVY_SWING
		$Hitbox/CollisionShape3D.shape.size = heavy_swing_hitbox_size
		$Hitbox/CollisionShape3D.position = heavy_swing_hitbox_pos
	elif distance <= lunge_strike_range and distance >= heavy_swing_range:
		current_attack = AttackType.LUNGE_STRIKE
		$Hitbox/CollisionShape3D.shape.size = lunge_strike_hitbox_size
		$Hitbox/CollisionShape3D.position = lunge_strike_hitbox_pos
		lunging = true
	


func _get_attack_animation() -> String:
	match current_attack:
		AttackType.QUICK_JAB:
			return "Attack1"
		AttackType.HEAVY_SWING:
			return "Attack2"
		AttackType.LUNGE_STRIKE:
			return "Attack3"
	return "Attack1"

func _get_attack_damage() -> float:
	match current_attack:
		AttackType.QUICK_JAB:
			return quick_jab_damage
		AttackType.HEAVY_SWING:
			return heavy_swing_damage
		AttackType.LUNGE_STRIKE:
			return lunge_strike_damage
	return 10.0

# =====================================================================
# HITBOX
# =====================================================================

func _enable_hitbox() -> void:
	if hitbox_shape:
		hitbox_shape.set_deferred('disabled', false)

func _disable_hitbox() -> void:
	if hitbox_shape:
		hitbox_shape.set_deferred('disabled', true)

func _on_hitbox_entered(area: Area3D) -> void:
	if hit_player_this_attack:
		return
	
	if not area.is_in_group("player_hurtbox"):
		return
	
	var player_node: Node = area.get_parent()
	if not player_node.has_method("take_damage"):
		return
	
	hit_player_this_attack = true
	
	var knockback: Vector3 = (player_node.global_position - global_position).normalized()
	player_node.take_damage(_get_attack_damage(), knockback)
	
	print("Enemy hit player for ", _get_attack_damage(), " damage!")

# =====================================================================
# NAVIGATION
# =====================================================================

func _follow_path(speed: float, delta: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		return
	
	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var to_nav: Vector3 = next_pos - global_position
	to_nav.y = 0
	var nav_dir: Vector3 = to_nav.normalized()
	
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0
	var player_dir: Vector3 = to_player.normalized()
	
	var angle_offset: float = deg_to_rad(30) * arc_strength * arc_direction
	var curved_dir: Vector3 = player_dir.rotated(Vector3.UP, angle_offset)
	
	var final_dir: Vector3 = (nav_dir * 0.6 + curved_dir * 0.4).normalized()
	
	var distance: float = global_position.distance_to(player.global_position)
	if distance < 3.0 and distance > lunge_strike_range:
		var orbit_dir: Vector3 = (global_position - player.global_position).normalized().rotated(Vector3.UP, deg_to_rad(90) * arc_direction)
		final_dir = (final_dir * 0.3 + orbit_dir * 0.7).normalized()
	
	var desired_velocity: Vector3 = final_dir * speed
	
	if avoidance_enabled:
		nav_agent.velocity = desired_velocity
	else:
		velocity.x = desired_velocity.x
		velocity.z = desired_velocity.z
		_rotate_towards_direction(final_dir, delta)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if state in [State.WINDUP, State.ATTACKING, State.RECOVERY, State.HURT, State.DEAD]:
		return
	
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	
	if safe_velocity.length() > 0.1:
		_rotate_towards_direction(safe_velocity.normalized(), get_physics_process_delta_time())

# =====================================================================
# ROTATION
# =====================================================================

func _rotate_towards_direction(direction: Vector3, delta: float) -> void:
	
	if state in [State.WINDUP]:
		var target_angle: float = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta * 3.5)
		rotation.x = 0
		rotation.z = 0
	else:
		var target_angle: float = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
		rotation.x = 0
		rotation.z = 0

func _rotate_towards_player(delta: float) -> void:
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0
	_rotate_towards_direction(to_player.normalized(), delta)

# =====================================================================
# VISUAL EFFECTS
# =====================================================================
func _start_flash_exec() -> void:
	if not flash_material:
		return
	flash_material.albedo_color = Color(0.0, 11.27, 19.093, 1.0) 

func _start_flash() -> void:
	if not flash_material or is_flashing:
		return
	
	is_flashing = true
	
	if flash_tween:
		flash_tween.kill()
	
	flash_tween = create_tween().set_loops()
	
	flash_tween.tween_property(
		flash_material,
		"albedo_color",
		Color(20.0, 0.1, 0.1, 1.0),
		0.2
	)
	
	flash_tween.tween_property(
		flash_material,
		"albedo_color",
		Color(0.8, 0.1, 0.1, 1.0),
		0.2
	)

func _stop_flash() -> void:
	if not is_flashing:
		return
	
	is_flashing = false
	
	if flash_tween:
		flash_tween.kill()
		flash_tween = null
	
	if flash_material:
		flash_material.albedo_color = flash_original_color

# =====================================================================
# COMBAT
# =====================================================================

func take_damage(damage: float, knockback_dir: Vector3) -> void:
	if state == State.DEAD:
		return
	
	health -= damage
	print("Enemy took ", damage, " damage! Health: ", health, "/", max_health)
	
	if health_bar:
		health_bar.set_health(damage)
	if dmg_label:
		dmg_label.display_dmg(damage)
	
	knockback_velocity = knockback_dir.normalized() * knockback_strength
	knockback_velocity.y = 0
	velocity.y = 2.0
	knockback_timer = knockback_duration
	hit_stun_timer = hit_stun_duration
	
	if state in [State.WINDUP, State.ATTACKING]:
		_disable_hitbox()
	
	_transition_to(State.HURT)
	
	if health <= 0:
		_transition_to(State.DEAD)

func _die() -> void:
	collision_layer = 0
	collision_mask = 0
	nav_agent.avoidance_enabled = false
	
	await get_tree().create_timer(10.0).timeout
	queue_free()

# =====================================================================
# ANIMATION
# =====================================================================

func _play_animation(anim_name: String) -> void:
	if anim_state and anim_state.get_current_node() != anim_name:
		anim_state.travel(anim_name)

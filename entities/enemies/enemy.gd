# Enemy.gd
extends CharacterBody3D
# ---------------------------------------------------------------------
# ENEMY AI CONTROLLER
# Handles chasing, walking, attacking, taking damage, and dying.
# Uses NavigationAgent3D for pathfinding + arc movement to avoid linear paths.
# ---------------------------------------------------------------------


# ============================
# --- COMBAT STATS ---
# ============================
@export var max_health: float = 200.0           # Maximum health of the enemy
@export var knockback_strength: float = 5.0     # Strength of knockback when hit
@export var defense: float = 0.0                # Optional defense (currently unused)


# ============================
# --- MOVEMENT SETTINGS ---
# ============================
@export var run_speed: float = 6              # Speed while chasing
@export var walk_speed: float = 3             # Speed while close to the player
@export var rotation_speed: float = 8.0         # Smooth rotation interpolation speed


# ============================
# --- AI BEHAVIOR RANGES ---
# ============================
@export var detection_range: float = 15.0       # Range to detect player and start chasing
@export var walk_range: float = 5.0             # Range to slow down and walk
@export var attack_range: float = 1.8           # Distance required to trigger attack
@export var stop_distance: float = 1.8          # Distance at which enemy stops moving


# ============================
# --- NAVIGATION SETTINGS ---
# ============================
@export_group("Navigation")
@export var path_update_rate: float = 0.2       # How often to update navigation target (in seconds)
@export var avoidance_enabled: bool = true      # Enable navigation avoidance between enemies
@export var enemy_avoidance_radius: float = 0.4 # Radius used for avoidance to prevent clumping
@export var arc_strength: float = 0.2           # Controls curvature in path movement (0 = straight, 1 = strong arc)
@export var arc_direction: int = 1              # 1 = clockwise arc, -1 = counterclockwise arc


# ============================
# --- ATTACK SETTINGS ---
# ============================
@export var attack_damage: float = 10.0         # Damage dealt per attack
@export var attack_cooldown: float = 1.5        # Delay before enemy can attack again
@export var attack_duration: float = 0.8        # Duration of the attack animation
@export var attack_facing_angle: float = 25.0   # Degrees of tolerance to face the player before starting attack


# ============================
# --- REFERENCES ---
# ============================
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player") # Player reference
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D                      # Navigation agent
@onready var anim_tree: AnimationTree = $AnimationTree if has_node("AnimationTree") else null
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback") if anim_tree else null
@onready var attack_hitbox: Area3D = $Hitbox if has_node("Hitbox") else null
@onready var hitbox_collision: CollisionShape3D = $Hitbox/CollisionShape3D if has_node("Hitbox/CollisionShape3D") else null
@onready var health_bar: Sprite3D = $Sprite3D


# ============================
# --- STATE MANAGEMENT ---
# ============================
enum State { IDLE, CHASE, WALK, ATTACK, HURT, DEAD }
var current_state: State = State.IDLE           # Current behavior state
var attack_timer: float = 0.0                   # Cooldown between attacks
var is_attacking: bool = false                  # Whether currently performing an attack


# ============================
# --- NAVIGATION ---
# ============================
var path_update_timer: float = 0.0              # Timer controlling navigation updates


# ============================
# --- HEALTH ---
# ============================
var current_health: float                       # Current health of the enemy


# ---------------------------------------------------------------------
# READY / INITIALIZATION
# ---------------------------------------------------------------------
func _ready():
	arc_direction = 1 if randf() < 0.5 else -1   # Randomize arc direction (for natural variation)
	current_health = max_health
	add_to_group("enemies")

	_setup_navigation_agent()

	# Initialize attack hitbox
	if hitbox_collision:
		hitbox_collision.disabled = true
	if attack_hitbox:
		attack_hitbox.area_entered.connect(_on_attack_hit)

	# Ensure player exists
	if not player:
		push_error("No player found in scene! Add player to 'player' group")

	# Wait for NavigationServer setup
	call_deferred("_navigation_setup")


func _navigation_setup():
	# Ensures NavigationServer is initialized
	await get_tree().physics_frame
	if player:
		nav_agent.target_position = player.global_position


# ---------------------------------------------------------------------
# NAVIGATION AGENT CONFIGURATION
# ---------------------------------------------------------------------
func _setup_navigation_agent():
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.1
	nav_agent.max_speed = run_speed
	nav_agent.path_max_distance = 3.0

	if avoidance_enabled:
		nav_agent.avoidance_enabled = true
		nav_agent.radius = enemy_avoidance_radius
		nav_agent.neighbor_distance = 1.3
		nav_agent.max_neighbors = 10
		nav_agent.time_horizon_agents = 1.0
		nav_agent.time_horizon_obstacles = 0.5
		nav_agent.avoidance_layers = 1
		nav_agent.avoidance_mask = 1

	nav_agent.velocity_computed.connect(_on_velocity_computed)


# ---------------------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------------------
func _physics_process(delta):
	if current_state == State.DEAD:
		return

	velocity.y = -9.8 # Apply gravity

	_update_ai(delta)
	move_and_slide()


# ---------------------------------------------------------------------
# AI STATE MACHINE UPDATE
# ---------------------------------------------------------------------
func _update_ai(delta: float):
	if not player:
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	# Update attack cooldown
	if attack_timer > 0:
		attack_timer -= delta

	# Update navigation target periodically
	path_update_timer -= delta
	if path_update_timer <= 0:
		path_update_timer = path_update_rate
		_update_navigation_target(distance_to_player)

	# State control
	match current_state:
		State.IDLE: _state_idle(distance_to_player)
		State.CHASE: _state_chase(distance_to_player, delta)
		State.WALK: _state_walk(distance_to_player, delta)
		State.ATTACK: _state_attack(delta)
		State.HURT: _state_hurt(delta)


func _update_navigation_target(_distance_to_player: float):
	if current_state in [State.CHASE, State.WALK]:
		nav_agent.target_position = player.global_position


# ---------------------------------------------------------------------
# STATE: IDLE
# ---------------------------------------------------------------------
func _state_idle(distance: float):
	velocity.x = 0
	velocity.z = 0

	if distance <= detection_range and player.current_health > 0:
		_change_state(State.CHASE)
	else:
		_play_animation("Idle")


# ---------------------------------------------------------------------
# STATE: CHASE
# ---------------------------------------------------------------------
func _state_chase(distance: float, delta: float):
	if distance <= attack_range and attack_timer <= 0 and player.current_health > 0:
		_rotate_towards_player(delta)
		await get_tree().create_timer(0.1).timeout
		_change_state(State.ATTACK)
		return

	if distance <= walk_range and player.current_health > 0:
		_change_state(State.WALK)
		return

	if distance > detection_range:
		_change_state(State.IDLE)
		return

	_follow_navigation_path(run_speed, delta)
	_play_animation("Run")


# ---------------------------------------------------------------------
# STATE: WALK (when close)
# ---------------------------------------------------------------------
func _state_walk(distance: float, delta: float):
	if distance <= attack_range and attack_timer <= 0 and player.current_health > 0:
		_rotate_towards_player(delta)
		await get_tree().create_timer(0.1).timeout
		_change_state(State.ATTACK)
		return

	if distance > walk_range and player.current_health > 0:
		_change_state(State.CHASE)
		return

	if distance <= stop_distance:
		velocity.x = 0
		velocity.z = 0
		_rotate_towards_player(delta)
		_play_animation("Idle")
	else:
		_follow_navigation_path(walk_speed, delta)
		_play_animation("Walk")


# ---------------------------------------------------------------------
# FOLLOW NAVIGATION PATH
# ---------------------------------------------------------------------
func _follow_navigation_path(speed: float, delta: float):
	# Disable movement if busy or dead
	if current_state in [State.ATTACK, State.HURT, State.DEAD]:
		velocity.x = 0
		velocity.z = 0
		if avoidance_enabled:
			nav_agent.velocity = Vector3.ZERO
		return

	if nav_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		return

	# Base navigation direction
	var next_position = nav_agent.get_next_path_position()
	var to_nav = (next_position - global_position)
	to_nav.y = 0
	var nav_dir = to_nav.normalized()

	# Direct player direction
	var to_player = (player.global_position - global_position)
	to_player.y = 0
	var player_dir = to_player.normalized()

	# Arc offset (gives circular approach feel)
	var angle_offset = deg_to_rad(30) * arc_strength * arc_direction
	var curved_dir = player_dir.rotated(Vector3.UP, angle_offset)

	# Blend straight nav and curved motion
	var final_dir = (nav_dir * 0.6 + curved_dir * 0.4).normalized()

	# Optional: orbit player when close
	var distance = global_position.distance_to(player.global_position)
	if distance < 3.0:
		var orbit_dir = (global_position - player.global_position).normalized().rotated(Vector3.UP, deg_to_rad(90) * arc_direction)
		final_dir = (final_dir * 0.3 + orbit_dir * 0.7).normalized()

	# Apply velocity
	var desired_velocity = final_dir * speed
	if avoidance_enabled:
		nav_agent.velocity = desired_velocity
	else:
		velocity.x = desired_velocity.x
		velocity.z = desired_velocity.z
		_rotate_towards_direction(final_dir, delta)


# ---------------------------------------------------------------------
# NAVIGATION VELOCITY CALLBACK
# ---------------------------------------------------------------------
func _on_velocity_computed(safe_velocity: Vector3):
	if current_state in [State.ATTACK, State.HURT, State.DEAD]:
		if nav_agent:
			nav_agent.velocity = Vector3.ZERO
		return

	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z

	if safe_velocity.length() > 0.1:
		_rotate_towards_direction(safe_velocity.normalized(), get_physics_process_delta_time())


# ---------------------------------------------------------------------
# STATE: ATTACK
# ---------------------------------------------------------------------
func _state_attack(delta: float):
	velocity.x = 0
	velocity.z = 0
	if nav_agent:
		nav_agent.velocity = Vector3.ZERO

	if not is_attacking:
		is_attacking = true
		attack_timer = attack_cooldown

		# Face player once and lock rotation
		_rotate_towards_player(delta)
		var locked_rotation_y = rotation.y

		_play_animation("Attack")

		# Enable hitbox briefly at impact
		await get_tree().create_timer(0.2).timeout
		if hitbox_collision and current_state == State.ATTACK:
			hitbox_collision.disabled = false

		# Keep facing locked
		var elapsed_time := 0.0
		while elapsed_time < attack_duration and current_state == State.ATTACK:
			rotation.y = locked_rotation_y
			elapsed_time += get_physics_process_delta_time()
			await get_tree().physics_frame

		# Disable hitbox at end
		if hitbox_collision:
			hitbox_collision.disabled = true

		is_attacking = false

		# Resume movement
		if player:
			var distance = global_position.distance_to(player.global_position)
			if distance <= walk_range:
				_change_state(State.WALK)
			else:
				_change_state(State.CHASE)


# ---------------------------------------------------------------------
# STATE: HURT
# ---------------------------------------------------------------------
func _state_hurt(delta: float):
	velocity.x = move_toward(velocity.x, 0, 10 * delta)
	velocity.z = move_toward(velocity.z, 0, 10 * delta)

	await get_tree().create_timer(0.6).timeout
	if current_state == State.HURT and player:
		var distance = global_position.distance_to(player.global_position)
		if distance <= walk_range:
			_change_state(State.WALK)
		else:
			_change_state(State.CHASE)


# ---------------------------------------------------------------------
# ROTATION HELPERS
# ---------------------------------------------------------------------
func _rotate_towards_direction(direction: Vector3, delta: float):
	if direction.length() > 0.01:
		var target_angle = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
		rotation.x = 0
		rotation.z = 0


func _rotate_towards_player(delta: float):
	var target_dir = (player.global_position - global_position)
	target_dir.y = 0
	_rotate_towards_direction(target_dir.normalized(), delta)


func _is_facing_player() -> bool:
	if not player:
		return false
	var to_player = (player.global_position - global_position)
	to_player.y = 0
	if to_player.length() == 0:
		return true
	var forward = -global_transform.basis.z
	forward.y = 0
	var dot = clamp(forward.normalized().dot(to_player.normalized()), -1.0, 1.0)
	var angle_deg = rad_to_deg(acos(dot))
	return angle_deg <= attack_facing_angle


# ---------------------------------------------------------------------
# STATE MANAGEMENT
# ---------------------------------------------------------------------
func _change_state(new_state: State):
	current_state = new_state
	print("Enemy state: ", State.keys()[new_state])


func _play_animation(anim_name: String):
	if anim_state and anim_state.get_current_node() != anim_name:
		anim_state.travel(anim_name)


# ---------------------------------------------------------------------
# COMBAT HANDLING
# ---------------------------------------------------------------------
func take_damage(damage: float, knockback_dir: Vector3):
	if current_state == State.DEAD:
		return

	if is_attacking:
		is_attacking = false
		if hitbox_collision:
			hitbox_collision.set_deferred('enabled', true) 

	current_health -= damage
	health_bar.set_health(damage)
	print("Enemy took ", damage, " damage! Health: ", current_health, "/", max_health)

	velocity = knockback_dir.normalized() * knockback_strength
	velocity.y = 2.0

	if nav_agent:
		nav_agent.velocity = Vector3.ZERO

	_change_state(State.HURT)
	_play_animation("Hit")

	if current_health <= 0:
		die()


func die():
	current_state = State.DEAD
	_play_animation("Die")

	collision_layer = 0
	collision_mask = 0
	nav_agent.avoidance_enabled = false

	await get_tree().create_timer(10.0).timeout
	queue_free()


# ---------------------------------------------------------------------
# ATTACK HITBOX CALLBACK
# ---------------------------------------------------------------------
func _on_attack_hit(area: Area3D):
	if area.is_in_group("player_hurtbox"):
		var player_node = area.get_parent()
		if player_node.has_method("take_damage"):
			var knockback = (player_node.global_position - global_position).normalized()
			player_node.take_damage(attack_damage, knockback)
			print("Enemy hit player for ", attack_damage, " damage!")

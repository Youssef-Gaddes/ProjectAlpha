# Enemy.gd
extends CharacterBody3D

# --- Combat Stats ---
@export var max_health: float = 100.0
@export var knockback_strength: float = 5.0
@export var defense: float = 0.0

# --- Movement Settings ---
@export var run_speed: float = 4       # Speed when far from player
@export var walk_speed: float = 2      # Speed when close to player
@export var rotation_speed: float = 8.0  # How fast enemy rotates to face player

# --- AI Behavior Ranges ---
@export var detection_range: float = 15.0  # Start chasing player
@export var walk_range: float = 5.0        # Switch from run to walk
@export var attack_range: float = 2.5      # Start attacking
@export var stop_distance: float = 1.8     # Min distance to maintain

# --- Attack Settings ---
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5    # Time between attacks
@export var attack_duration: float = 0.8    # How long attack animation takes

# --- References ---
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var attack_hitbox: Area3D = $Hitbox
@onready var hitbox_collision: CollisionShape3D = $Hitbox/CollisionShape3D

# --- State Management ---
enum State { IDLE, CHASE, WALK, ATTACK, HURT, DEAD }
var current_state: State = State.IDLE
var attack_timer: float = 0.0
var is_attacking: bool = false
var wander_offset: Vector3 = Vector3.ZERO

# --- Health ---
var current_health: float

func _ready():
	wander_offset = Vector3(
		randf_range(-1.0, 1.0),
		0,
		randf_range(-1.0, 1.0)
	).normalized() * randf_range(0.3, 1.0)
	current_health = max_health
	add_to_group("enemies")
	
	# Setup hitbox
	if hitbox_collision:
		hitbox_collision.disabled = true
	if attack_hitbox:
		attack_hitbox.area_entered.connect(_on_attack_hit)
	
	# Ensure player reference exists
	if not player:
		push_error("No player found in scene! Add player to 'player' group")

func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	# Always apply gravity
	velocity.y = -9.8
	
	# Update AI behavior
	_update_ai(delta)
	
	# Move
	move_and_slide()

func _update_ai(delta: float):
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Update attack cooldown
	if attack_timer > 0:
		attack_timer -= delta
	
	# State machine
	match current_state:
		State.IDLE:
			_state_idle(distance_to_player)
		
		State.CHASE:
			_state_chase(distance_to_player, delta)
		
		State.WALK:
			_state_walk(distance_to_player, delta)
		
		State.ATTACK:
			_state_attack(delta)
		
		State.HURT:
			_state_hurt(delta)

# --- IDLE: Wait for player to get close ---
func _state_idle(distance: float):
	velocity.x = 0
	velocity.z = 0
	
	if distance <= detection_range and not player.current_health ==0:
		_change_state(State.CHASE)
	else:
		_play_animation("Idle")

# --- CHASE: Run towards player ---
func _state_chase(distance: float, delta: float):
	if distance <= attack_range and attack_timer <= 0 and not player.current_health ==0:
		_change_state(State.ATTACK)
		return
	
	if distance <= walk_range and not player.current_health ==0:
		_change_state(State.WALK)
		return
	
	if distance > detection_range:
		_change_state(State.IDLE)
		return
	
	# Move towards player
	_move_towards_player(run_speed, delta)
	_play_animation("Run")

# --- WALK: Walk slowly when close ---
func _state_walk(distance: float, delta: float):
	if distance <= attack_range and attack_timer <= 0 and not player.current_health ==0:
		_change_state(State.ATTACK)
		return
	
	if distance > walk_range and not player.current_health ==0:
		_change_state(State.CHASE)
		return
	
	# Stop if too close
	if distance <= stop_distance:
		velocity.x = 0
		velocity.z = 0
		_rotate_towards_player(delta)
		_play_animation("Idle")
	else:
		_move_towards_player(walk_speed, delta)
		_play_animation("Walk")

# --- ATTACK: Perform attack ---
func _state_attack(_delta: float):
	# Stop moving during attack
	velocity.x = 0
	velocity.z = 0
	
	if not is_attacking:
		is_attacking = true
		attack_timer = attack_cooldown
		_play_animation("Attack")
		
		# Activate hitbox after short delay (startup frames)
		await get_tree().create_timer(0.2).timeout
		if hitbox_collision and current_state == State.ATTACK:
			hitbox_collision.disabled = false
		
		# Deactivate hitbox after attack duration
		await get_tree().create_timer(attack_duration - 0.2).timeout
		if hitbox_collision:
			hitbox_collision.disabled = true
		
		is_attacking = false
		
		# Return to appropriate state
		var distance = global_position.distance_to(player.global_position)
		if distance <= walk_range:
			_change_state(State.WALK)
		else:
			_change_state(State.CHASE)

# --- HURT: Knockback state ---
func _state_hurt(delta: float):
	# Decelerate from knockback
	velocity.x = move_toward(velocity.x, 0, 10 * delta)
	velocity.z = move_toward(velocity.z, 0, 10 * delta)
	
	# Return to combat after short time
	await get_tree().create_timer(0.6).timeout
	if current_state == State.HURT:
		var distance = global_position.distance_to(player.global_position)
		if distance <= walk_range:
			_change_state(State.WALK)
		else:
			_change_state(State.CHASE)

# --- Movement Helpers ---
func _move_towards_player(speed: float, delta: float):
	var base_dir = (player.global_position - global_position).normalized()
	base_dir.y = 0

	# --- add a wandering offset that makes each enemy path unique ---
	var offset_strength =1 # how strong the deviation is
	var wander_dir = (base_dir + wander_offset * offset_strength).normalized()

	# --- optionally make it vary over time for more natural steering ---
	wander_offset.x = lerp(wander_offset.x, randf_range(-1.0, 1.0), delta * 0.5)
	wander_offset.z = lerp(wander_offset.z, randf_range(-1.0, 1.0), delta * 0.5)

	velocity.x = wander_dir.x * speed
	velocity.z = wander_dir.z * speed

	_rotate_towards_player(delta)

func _rotate_towards_player(delta: float):
	var target_dir = (player.global_position - global_position)
	target_dir.y = 0
	
	if target_dir.length() > 0.01:
		target_dir = target_dir.normalized()
		var target_angle = atan2(target_dir.x, target_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
		rotation.x = 0
		rotation.z = 0

# --- State Management ---
func _change_state(new_state: State):
	current_state = new_state
	print("Enemy state: ", State.keys()[new_state])

func _play_animation(anim_name: String):
	if anim_state and anim_state.get_current_node() != anim_name:
		anim_state.travel(anim_name)

# --- Combat ---
func take_damage(damage: float, knockback_dir: Vector3):
	if current_state == State.DEAD:
		return
	
	current_health -= damage
	print("Enemy took ", damage, " damage! Health: ", current_health, "/", max_health)
	
	# Apply knockback
	velocity = knockback_dir * knockback_strength
	velocity.y = 2.0
	
	# Enter hurt state
	_change_state(State.HURT)
	_play_animation("Hit")
	
	# Check death
	if current_health <= 0:
		die()

func die():
	current_state = State.DEAD
	_play_animation("Die")
	
	# Disable collision
	collision_layer = 0
	collision_mask = 0
	
	# Remove after death animation
	await get_tree().create_timer(2.0).timeout
	queue_free()

# --- Attack hitbox collision ---
func _on_attack_hit(area: Area3D):
	# Check if we hit the player
	if area.is_in_group("player_hurtbox"):
		var player_node = area.get_parent()
		if player_node.has_method("take_damage"):
			var knockback = (player_node.global_position - global_position).normalized()
			player_node.take_damage(attack_damage, knockback)
			print("Enemy hit player for ", attack_damage, " damage!")

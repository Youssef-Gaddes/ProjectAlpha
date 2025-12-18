extends BaseEnemy 
# === ATTACK SYSTEM === ONLY FOR MELEE


var current_attack: int





func _ready() -> void:
	super._ready()
	
func _post_ready() -> void:
	await get_tree().physics_frame
	if npc.player:
		npc.nav_agent.target_position = npc.player.global_position

func _setup_navigation() -> void:
	npc.nav_agent.path_desired_distance = 0.5
	npc.nav_agent.target_desired_distance = 0.1
	npc.nav_agent.max_speed = data.run_speed
	npc.nav_agent.path_max_distance = 3.0
	
	if data.avoidance_enabled:
		npc.nav_agent.avoidance_enabled = true
		npc.nav_agent.radius = data.avoidance_radius
		npc.nav_agent.neighbor_distance = 1.3
		npc.nav_agent.max_neighbors = 10
		npc.nav_agent.time_horizon_agents = 1.0
		npc.nav_agent.avoidance_layers = 1
		npc.nav_agent.avoidance_mask = 1
		
	npc.nav_agent.velocity_computed.connect(_on_velocity_computed)
	
func _setup_hitbox() -> void:
	if hitbox_shape:
		hitbox_shape.set_deferred('disabled', true)
	if hitbox_area:
		hitbox_area.area_entered.connect(_on_hitbox_entered)

	
func _physics_process(delta: float) -> void:
	super._physics_process(delta)

# === STATE: CHASE ===
func _state_chase(distance: float, delta: float) -> void:
	
	
	if distance <= data.walk_range and npc.player.current_health > 0:
		print("yemchi")
		_transition_to(State.WALK)
		return
	
	if distance > data.detection_range:
		_transition_to(State.IDLE)
		return
	
	_follow_path(data.run_speed, delta)
	_play_animation("Run")
	

# === STATE: WALK ===
func _state_walk(distance: float, delta: float) -> void:
	if _can_attack() and distance <= data.walk_range and npc.player.current_health > 0:
		_choose_attack(distance)
		_transition_to(State.WINDUP)
		return
	
	if distance > data.walk_range and npc.player.current_health > 0:
		_transition_to(State.CHASE)
		return
	
	if distance <= data.stop_distance:
		npc.velocity.x = 0
		npc.velocity.z = 0
		_rotate_towards_player(delta)
		_play_animation("Idle")
	else:
		_follow_path(data.walk_speed, delta)
		_play_animation("Walk")

func _state_windup(_delta: float) -> void:
	
	super._state_windup(_delta)
	
	if data.attacks[current_attack].attack_name == "Lunge Strike":
		_rotate_towards_player(0.16)       # Keep rotating to face player
		locked_rotation = npc.rotation.y         # Update locked rotation every frame
	else:
		npc.rotation.y = locked_rotation
	

# === STATE: ATTACKING ===
func _state_attacking(_delta: float) -> void:
	
	super._state_attacking(_delta)
	if data.attacks[current_attack].has_lunge == true and lunging:
		var forward: Vector3 = -npc.global_basis.z
		npc.velocity.x = forward.x * -8.0
		npc.velocity.z = forward.z * -8.0
		npc.set_collision_mask_value(3, false)  # Disable enemy collision during lunge
	else:
		npc.velocity.x = 0
		npc.velocity.z = 0
func _state_hurt(delta: float) -> void:
	super._state_hurt(delta)
	if hit_stun_timer <= 0:
		if npc.player:
			var distance: float = global_position.distance_to(npc.player.global_position)
			if distance <= data.walk_range:
				_transition_to(State.WALK)
			else:
				_transition_to(State.CHASE)
		else:
			_transition_to(State.IDLE)
func _choose_attack(distance: float) -> void:
	for i in data.attacks:
		print(i.attack_name)
		if i.min_range <= distance and distance <= i.max_range:
			current_attack = data.attacks.find(i)
			hitbox_shape.shape.size = data.attacks[current_attack].hitbox_size
			hitbox_shape.position = data.attacks[current_attack].hitbox_position
			if data.attacks[current_attack].has_lunge:
				lunging = true


func _get_attack_animation() -> String:
	if current_attack:
		return data.attacks[current_attack].animation_name
	else:
		return "Attack1"
func _get_attack_damage() -> float:
	return data.attacks[current_attack].damage


func _on_attack_complete() -> void:
	super._on_attack_complete()
	# Re-enable collision if was lunging
	if data.attacks[current_attack].has_lunge:
		npc.set_collision_mask_value(3, true)
	
	# Start cooldown
	attack_cooldown_timer = data.attacks[current_attack].attack_cooldown
	
	# Return to movement
	if state in [State.ATTACKING, State.RECOVERY, State.WINDUP]:
		if npc.player:
			var distance: float = npc.global_position.distance_to(npc.player.global_position)
			if distance <= data.walk_range:
				_transition_to(State.WALK)
			else:
				_transition_to(State.CHASE)
		else:
			_transition_to(State.IDLE)

extends CharacterBody3D

# === COMBAT STATS ===
@export_group("Combat")
@export var max_health: float 
@export var defense: float

# === MOVEMENT ===
@export_group("Movement")
@export var run_speed: float 
@export var walk_speed: float 
@export var rotation_speed: float 

# === AI RANGES ===
@export_group("Detection")
@export var detection_range: float 

# === ATTACK SYSTEM === 
@export_group("Attacks")
@export var attack_cooldown: float 

# === KNOCKBACK ===
@export_group("Knockback")
@export var knockback_strength: float 
@export var knockback_duration: float 
@export var hit_stun_duration: float 

# === NAVIGATION ===
@export_group("Navigation")
@export var path_update_rate: float 
@export var avoidance_enabled: bool 
@export var avoidance_radius: float 
@export var arc_strength: float 
# === NODES ===
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree: AnimationTree = $AnimationTree if has_node("AnimationTree") else null
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback") if anim_tree else null
@onready var hitbox_area: Area3D = $Hitbox if has_node("Hitbox") else null
@onready var hitbox_shape: CollisionShape3D = $Hitbox/CollisionShape3D if has_node("Hitbox/CollisionShape3D") else null
@onready var hurtbox_shape: CollisionShape3D = $Hurtbox/CollisionShape3D
@onready var health_bar: Sprite3D = $Sprite3D if has_node("Sprite3D") else null
@onready var dmg_label: Sprite3D = $damage_number if has_node("damage_number") else null
#INHERIT VALUE IN CHILD :
@onready var mesh: MeshInstance3D = $enemy/Armature/Skeleton3D/Ch25 if has_node("enemy/Armature/Skeleton3D/Ch25") else null 
@onready var effect_marker: Marker3D = $effect_marker
@onready var ui:CanvasLayer
@onready var verdict_indicator: MeshInstance3D = $verdict_indicator

# === DIALOGUE ===
@export_group("Dialogue")
@export var dialogue_array: Array[DialogueResource] = []
@export var chosen_dialogue: DialogueResource
@export var DIR_PATH: String  # Define in child

# === STATE MACHINE ===
enum State { IDLE, CHASE, WALK, WINDUP, ATTACKING, RECOVERY, HURT, DEAD, STUNNED, DOWNED, SPARED }
var state: State = State.IDLE 

# === ATTACK STATE === Values change in child

# enum AttackType { QUICK_JAB, HEAVY_SWING, LUNGE_STRIKE } declare in chils
# var current_attack: AttackType = AttackType.QUICK_JAB declare in child
var attack_cooldown_timer: float
var locked_rotation: float 
var hit_player_this_attack: bool 



# === FLASH STATE ===
var flash_tween: Tween
var flash_original_color: Color = Color.WHITE
var flash_material: StandardMaterial3D
var is_flashing: bool 

# === VISUAL EFFECTS ===
var exec_tween: Tween
var executable: bool 

# === KNOCKBACK STATE ===
var knockback_timer: float 
var knockback_velocity: Vector3 
var hit_stun_timer: float 
var stunned: bool 

# === NAVIGATION ===
var path_update_timer: float
var arc_direction: int 

# === HEALTH ===
var health: float


# =====================================================================
# INITIALIZATION
# =====================================================================


func _ready() -> void:
	if chosen_dialogue == null:
		load_resources_from_folder()
	ui=get_tree().get_first_node_in_group('UI')
	effect_marker.visible = false
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
	pass #define in child

func load_resources_from_folder():
	
	var dir = DirAccess.open(DIR_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# Skip hidden files and folders like .import, .gdignore, .DS_Store
			if file_name.begins_with("."):
				file_name = dir.get_next()
				continue
			# Skip import metadata files
			if file_name.ends_with(".import"):
				file_name = dir.get_next()
				continue
			# Only load real resource types
			var ext := file_name.get_extension().to_lower()
			if ext in ["dialogue", "tres", "res"]:
				var full_path = DIR_PATH + file_name
				var resource: DialogueResource = load(full_path)
				if resource:
					dialogue_array.append(resource)
			file_name = dir.get_next()
		dir.list_dir_end()
		chosen_dialogue = dialogue_array.pick_random()
	else:
		print("Could not open directory: ", DIR_PATH)	
		

func _setup_navigation() -> void:
	nav_agent.velocity_computed.connect(_on_velocity_computed)
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if state in [State.WINDUP, State.ATTACKING, State.RECOVERY, State.HURT, State.DEAD, State.DOWNED]:
		return
	
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	
	if safe_velocity.length() > 0.1:
		_rotate_towards_direction(safe_velocity.normalized(), get_physics_process_delta_time())

	

func _setup_hitbox() -> void:
	pass
func _setup_material() -> void:
	if not mesh:
		return
	
	var mat: StandardMaterial3D = mesh.get_active_material(0)
	if mat:
		mat = mat.duplicate()
		mesh.set_surface_override_material(0, mat)
		flash_material = mat
		flash_original_color = mat.albedo_color

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if state == State.DOWNED:
		if Input.is_action_just_pressed("interact") and player.current_verdict == self:
			print('yup')
			DialogueManager.show_dialogue_balloon(chosen_dialogue, "start")
		return
	if state == State.SPARED:
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
		State.STUNNED:
			_state_stunned()
			
func _state_idle(distance: float) -> void:
	velocity.x = 0
	velocity.z = 0
	
	if distance <= detection_range and player.current_health > 0:
		_transition_to(State.CHASE)
	else:
		_play_animation("Idle")
	

# === STATE: STUNNED ===
func _state_stunned():
	velocity.x = 0
	velocity.z = 0
	nav_agent.velocity = Vector3.ZERO
	if stunned == false:
		_transition_to(State.IDLE)

# === STATE: CHASE ===
func _state_chase(distance: float, delta: float) -> void:
	pass

# === STATE: WALK ===
func _state_walk(distance: float, delta: float) -> void:
	pass

# === STATE: WINDUP ===
func _state_windup(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	nav_agent.velocity = Vector3.ZERO
	
	
	
	# Animation calls _on_windup_complete() to transition

# === STATE: ATTACKING ===
func _state_attacking(_delta: float) -> void:
	nav_agent.velocity = Vector3.ZERO
	
	rotation.y = locked_rotation
	rotation.x = 0
	rotation.z = 0
	
	# Lunge movement (will be stopped by _on_lunge_end() callback)
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
	
	
# =====================================================================
# STATE TRANSITIONS
# =====================================================================

func _transition_to(new_state: State) -> void:
	# Always disable hitbox when leaving attack states
	if state in [State.WINDUP, State.ATTACKING, State.RECOVERY]:
		_disable_hitbox()
	if state in [State.HURT] and stunned == true:
		if new_state != State.DOWNED:
			new_state = State.STUNNED
		
	
	# Re-enable collision mask if leaving lunge attack
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
		State.STUNNED:
			_disable_hitbox()
			_stop_flash()
			_play_animation("Crawl")
		State.ATTACKING:
			pass  # No animation change - continue from windup
		
		State.RECOVERY:
			_disable_hitbox()
			attack_cooldown_timer = attack_cooldown
		
		State.HURT:
			_stop_flash()
			_disable_hitbox()
			_play_animation("Hit")
		
		State.DOWNED:
			if effect_marker.visible == true:
				_exec_done()
			_stop_flash()
			_disable_hitbox()
			_disable_hurtbox()
			_play_animation("Kneel")
			
		
		State.DEAD:
			_play_animation("Die")
			_die()
		
		State.SPARED:
			_play_animation("Idle")
			_spare()
signal downed


# =====================================================================
# ANIMATION CALLBACKS
# =====================================================================
func _exec_tween_done():
	effect_marker.visible = false
func _exec_done():
	exec_tween = create_tween().set_loops(1)
	exec_tween.tween_property(effect_marker,'position',Vector3(0.0,0.5,0.0), 0.2)
	exec_tween.finished.connect(_exec_tween_done)
func _exec_ready():
	effect_marker.visible = true
func exec_die():
	take_damage(max_health, Vector3.ZERO)
	_exec_done()
	
func _on_attack_start() -> void:
	print("Helloooo")
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
	
	velocity.x = 0
	velocity.z = 0
	set_collision_mask_value(3, true)  # Re-enable enemy collision

func _on_attack_complete() -> void:
	"""Called when attack animation ends - return to movement"""
	_disable_hitbox()
	
	

# =====================================================================
# ATTACK SYSTEM
# =====================================================================

func _can_attack() -> bool:
	return attack_cooldown_timer <= 0 and state not in [State.WINDUP, State.ATTACKING, State.RECOVERY, State.HURT]

func _choose_attack(distance: float) -> void:
	pass




func _get_attack_animation() -> String:
	return ""

func _get_attack_damage() -> float:
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

func _disable_hurtbox() -> void:
	if hurtbox_shape:
		hurtbox_shape.set_deferred('disabled', true)

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
	
	
	var desired_velocity: Vector3 = final_dir * speed
	
	if avoidance_enabled:
		nav_agent.velocity = desired_velocity
	else:
		velocity.x = desired_velocity.x
		velocity.z = desired_velocity.z
		_rotate_towards_direction(final_dir, delta)


# =====================================================================
# ROTATION
# =====================================================================

func _rotate_towards_direction(direction: Vector3, delta: float) -> void:
	
	if state in [State.WINDUP]:
		var target_angle: float = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta )
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
	if state == State.DEAD or state == State.DOWNED:
		return
	
	health -= damage
	
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
		_transition_to(State.DOWNED)
		downed.emit(self)

func _spare() -> void:
	get_parent()._on_enemy_spared(self)
	collision_layer = 0
	collision_mask = 0
	nav_agent.avoidance_enabled = false
	$Hurtbox/CollisionShape3D.set_deferred('disabled', true)



func _die() -> void:
	get_parent()._on_enemy_killed(self)
	collision_layer = 0
	collision_mask = 0
	nav_agent.avoidance_enabled = false
	$Hurtbox/CollisionShape3D.set_deferred('disabled', true)
	
	await get_tree().create_timer(10.0).timeout
	queue_free()

func _play_animation(anim_name: String) -> void:
	if anim_state and anim_state.get_current_node() != anim_name:
		anim_state.travel(anim_name)

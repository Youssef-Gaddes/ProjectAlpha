extends Node3D

# Packed Scenes
@onready var enemy: PackedScene = preload("res://entities/NPCs/enemies/enemy_1/enemy_1.tscn")

# Node References
@onready var spawn_points: Array[Marker3D]
@onready var tp: Node3D = $Tp
@onready var player: CharacterBody3D

# Entity Arrays
@onready var enemies: Array[CharacterBody3D] = []
@onready var allies: Array[CharacterBody3D] = []
@onready var downed: Array[CharacterBody3D] = []
@onready var dead_allies: Array[CharacterBody3D] = []

# Configuration
@export var enemy_number: int = 2
@export var has_intro: bool = false

# Combat Stats
@export var spared: int = 0
@export var killed: int = 0
@export var total: int = 0
@export var all: bool = false

# Signals
signal state_changed(new_state: MapState)
signal combat_started
signal combat_ended
signal map_completed

# State Machine
enum MapState {
	INTRO,
	EXPLORATION,
	COMBAT,
	DONE
}

var current_state: MapState = MapState.EXPLORATION

# ============================================
# INITIALIZATION
# ============================================

func _ready() -> void:
	_initialize_player()
	_initialize_stats()
	_initialize_allies()
	_initialize_state()
	
func _initialize_player() -> void:
	player = get_tree().get_first_node_in_group('player')
	if not player:
		push_error("Player not found in scene!")
		return
	
	# Set player health based on run state
	if not Stats.in_run:
		Stats.in_run = true
		Stats.player_health = player.max_health
	else:
		player.health = Stats.player_health

func _initialize_stats() -> void:
	spared = 0
	killed = 0
	total = 0
	all = false

func _initialize_allies() -> void:
	if get_tree().get_nodes_in_group('ally').is_empty() == false:
		for i in get_tree().get_nodes_in_group('ally'):
			allies.append(i)
			i.Combat_Module.dead.connect(_on_ally_killed)

func _initialize_state() -> void:
	if has_intro:
		_transition_to_state(MapState.INTRO)
	else:
		_transition_to_state(MapState.EXPLORATION)

# ============================================
# STATE MACHINE
# ============================================

func _transition_to_state(new_state: MapState) -> void:
	# Exit current state
	_exit_state(current_state)
	
	# Update state
	var old_state = current_state
	current_state = new_state
	
	# Enter new state
	_enter_state(new_state)
	
	# Emit signal
	state_changed.emit(new_state)
	print("Map state changed: %s -> %s" % [MapState.keys()[old_state], MapState.keys()[new_state]])

func _exit_state(state: MapState) -> void:
	match state:
		MapState.INTRO:
			pass # Cleanup intro effects, stop music, etc.
		MapState.EXPLORATION:
			pass # Disable free exploration
		MapState.COMBAT:
			_cleanup_combat()
		MapState.DONE:
			pass

func _enter_state(state: MapState) -> void:
	match state:
		MapState.INTRO:
			_start_intro()
		MapState.EXPLORATION:
			_start_exploration()
		MapState.COMBAT:
			_start_combat()
		MapState.DONE:
			_complete_map()

# ============================================
# STATE IMPLEMENTATIONS
# ============================================

func _start_intro() -> void:
	# Play intro cutscene/dialogue
	# Example: await play_intro_cutscene()
	print("Playing intro...")
	
	# After intro completes, transition to exploration
	# You can call this manually when intro finishes:
	# _transition_to_state(MapState.EXPLORATION)

func _start_exploration() -> void:
	print("Exploration mode active")
	# Enable player movement

	
	# Enable spawn area detection
	if has_node("EnemySpawnArea/EntryBox"):
		$EnemySpawnArea/EntryBox.set_deferred("disabled", false)

func _start_combat() -> void:
	print("Combat started!")
	combat_started.emit()
	
	# Spawn enemies if not already spawned
	if enemies.is_empty():
		enemy_spawn()
	
	
	for ally in allies:
		if ally and ally.has_method("force_enter_combat"):
			ally.force_enter_combat()

func _cleanup_combat() -> void:
	# Clear downed enemies
	downed.clear()

func _complete_map() -> void:
	print("Map completed!")
	combat_ended.emit()
	
	# Re-enable player movement
	if player and player.has_node("collision_shape_3d"):
		player.collision_shape_3d.set_deferred('disabled', false)
	
	# Save player health
	Stats.player_health = player.health
	
	# Activate teleporter to next node
	if tp:
		tp.activate()
	
	map_completed.emit()

# ============================================
# ENEMY SPAWNING
# ============================================

func _on_enemy_spawn_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and current_state == MapState.EXPLORATION:
		_transition_to_state(MapState.COMBAT)

func enemy_spawn() -> void:
	# Gather spawn points
	spawn_points.clear()
	if has_node("SpawPoints"):
		for child in $SpawPoints.get_children():
			if child is Marker3D:
				spawn_points.append(child)
	
	if spawn_points.is_empty():
		push_error("No spawn points found!")
		return
	
	# Spawn enemies
	for i in range(enemy_number):
		await get_tree().create_timer(0.1).timeout
		
		if spawn_points.is_empty():
			push_warning("Ran out of spawn points before spawning all enemies")
			break
		
		var picked_spawn = spawn_points.pick_random()
		var new_enemy = enemy.instantiate()
		new_enemy.position = picked_spawn.position
		add_child(new_enemy)
		enemies.append(new_enemy)
		new_enemy.force_enter_combat()
		
		new_enemy.Combat_Module.downed.connect(_on_enemy_downed)
		
		spawn_points.erase(picked_spawn)
	combat_started.emit()

# ============================================
# COMBAT EVENTS
# ============================================

func _on_enemy_downed(enemy_instance: CharacterBody3D) -> void:
	if not downed.has(enemy_instance):
		downed.append(enemy_instance)
	
	Stats.beaten_enemies += 1
	
	# Check if all enemies are downed
	if downed.size() == enemy_number:
		print("All enemies downed - entering verdict phase")
		if player and player.has_method("_verdict_start"):
			player._verdict_start()
		for i in allies:
			i.force_exit_combat()

func _on_ally_killed(ally_instance: CharacterBody3D):
	allies.erase(ally_instance)
	dead_allies.append(ally_instance)

func _on_enemy_killed(enemy_instance: CharacterBody3D) -> void:
	if not all:
		downed.erase(enemy_instance)
		killed += 1
		_add_total()
	Stats.advance_death()

func _on_enemy_spared(enemy_instance: CharacterBody3D) -> void:
	if not all:
		downed.erase(enemy_instance)
		spared += 1
		_add_total()
	Stats.advance_mercy()

func _add_total() -> void:
	total += 1
	print("Total resolved: %d/%d (Killed: %d, Spared: %d)" % [total, enemy_number, killed, spared])
	
	if total >= enemy_number:
		_transition_to_state(MapState.DONE)

# ============================================
# VERDICT ACTIONS
# ============================================

func _kill_all() -> void:
	all = true
	print("Executing all downed enemies...")

	for enemy_instance in downed:
		
		killed += 1
		_add_total()
		enemy_instance.Combat_Module._transition_to(enemy_instance.Combat_Module.State.DEAD)
	
	downed.clear()

func _spare_all() -> void:
	all = true
	print("Sparing all downed enemies...")
	
	for enemy_instance in downed:
		spared += 1
		_add_total()
		enemy_instance.Combat_Module._transition_to(enemy_instance.Combat_Module.State.SPARED)
	
	downed.clear()

# ============================================
# UTILITY FUNCTIONS
# ============================================

func get_current_state() -> MapState:
	return current_state

func is_in_combat() -> bool:
	return current_state == MapState.COMBAT

func is_exploration() -> bool:
	return current_state == MapState.EXPLORATION

func complete_intro() -> void:
	"""Call this when intro cutscene/dialogue finishes"""
	if current_state == MapState.INTRO:
		_transition_to_state(MapState.EXPLORATION)

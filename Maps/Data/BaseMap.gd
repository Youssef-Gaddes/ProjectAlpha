class_name BaseMap
extends Node3D

@export var map_data: MapData
@onready var player: CharacterBody3D
@onready var tp: Node3D = $Tp if has_node("Tp") else null

# Entity Arrays
var enemies: Array[CharacterBody3D] = []
var allies: Array[CharacterBody3D] = []
var downed: Array[CharacterBody3D] = []
var dead_allies: Array[CharacterBody3D] = []
var named_npcs: Dictionary = {}  # "elena" -> CharacterBody3D instance

# Stats tracking
@export var spared: int = 0
@export var killed: int = 0
@export var total: int = 0
@export var all: bool = false

# ============================================
# STATE MACHINE
# ============================================
enum MapState { INTRO, EXPLORATION, COMBAT, DONE }
var current_state: MapState = MapState.EXPLORATION

signal state_changed(new_state: String)
@warning_ignore("unused_signal")
signal combat_started
signal combat_ended
signal map_completed(consequences: Dictionary)

# ============================================
# INITIALIZATION
# ============================================
func _ready() -> void:
	
	if not map_data:
		map_data = get_meta("map_data")
	initialize()

func initialize() -> void:
	_initialize_player()
	_initialize_allies() 
	
	if map_data.has_intro:
		_transition_to_state(MapState.INTRO)
	else:
		_transition_to_state(MapState.EXPLORATION)
		
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

func _initialize_allies() -> void:
	# Find pre-placed allies in scene
	for child in get_children():
		if child.is_in_group("ally"):
			allies.append(child)
			combat_ended.connect(child.force_exit_combat)
			
# ============================================
# STATE MACHINE
# ============================================
func _transition_to_state(new_state: MapState) -> void:
	_exit_state(current_state)
	
	var old_state = current_state
	current_state = new_state
	
	_enter_state(new_state)
	
	state_changed.emit(MapState.keys()[new_state].to_lower())
	print(MapState.keys()[new_state].to_lower())
	print("Map state changed: %s -> %s" % [MapState.keys()[old_state], MapState.keys()[new_state]])

func _exit_state(state: MapState) -> void:
	match state:
		MapState.INTRO:
			pass  # Cleanup intro
		MapState.EXPLORATION:
			pass
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
			combat_started.emit()
			_start_combat()
		MapState.DONE:
			_complete_map()
			
# ============================================
# STATE IMPLEMENTATIONS (Override in children)
# ============================================
func _start_intro() -> void:
	# Override in child classes for intro cutscenes
	print("Playing intro...")
	# Auto-transition after intro for now
	_transition_to_state(MapState.EXPLORATION)


func _start_exploration() -> void:
	print("Exploration mode active")
	# Override in child classes

func _start_combat() -> void:
	print("Combat started!")
	
	for enemy in enemies:
		print(enemy,'entering combat')
		if enemy.has_method("force_enter_combat"):
			enemy.force_enter_combat()
	# Activate allies
	for ally in allies:

		if ally.has_method("force_enter_combat"):
			ally.force_enter_combat()

func _cleanup_combat() -> void:
	downed.clear()
	
func _complete_map() -> void:
	print("Map completed!")
	
	# Re-enable player collision
	if player and player.has_node("collision_shape_3d"):
		player.collision_shape_3d.set_deferred('disabled', false)
	
	# Save player health
	Stats.player_health = player.health
	var offer = UpgradeManager.generate_offer(map_data)
	UpgradeManager.current_offer = offer  # add this var to UpgradeManager

	# TP activates AFTER player picks upgrade — connect from UI
	# UI calls UpgradeManager.apply_upgrade(chosen) then tp.activate()
	_show_upgrade_ui(offer)
	
	# Build and report consequences
	var consequences = _build_consequences()
	print(consequences)
	map_completed.emit(consequences)

func _show_upgrade_ui(offer: Array[UpgradeData]) -> void:
	var ui = get_tree().get_first_node_in_group("UpgradeUI")
	if ui and ui.has_method("show_upgrade_offer"):
		ui.show_upgrade_offer(offer)
# ============================================
# VICTORY CONDITION (Override in children)
# ============================================
func check_victory() -> bool:
	# Override in child classes
	push_error("check_victory() not implemented in child class!")
	return false

# ============================================
# COMBAT TRACKING
# ============================================
func _on_enemy_downed(enemy_instance: CharacterBody3D) -> void:
	if not downed.has(enemy_instance):
		downed.append(enemy_instance)
	
	Stats.beaten_enemies += 1
	
	# Check victory condition
	if check_victory():
		combat_ended.emit()
		print('combat done !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
		_start_verdict_phase()

func _start_verdict_phase() -> void:
	if player and player.has_method("_verdict_start"):
		player._verdict_start()

func _on_enemy_killed(enemy_instance: CharacterBody3D) -> void:
	if not all:
		downed.erase(enemy_instance)
		
		killed += 1
		total += 1
		Stats.total_kills += 1
		
		# Check if all resolved
		_check_resolution_complete()

func _on_enemy_spared(enemy_instance: CharacterBody3D) -> void:
	if not all:
		downed.erase(enemy_instance)
		
		spared += 1
		total += 1
		Stats.total_spares += 1
		
		# Check if all resolved
		_check_resolution_complete()

func _check_resolution_complete() -> void:
	# Override in child classes if custom logic needed
	pass

func _kill_all() -> void:
	"""Kill all downed enemies at once"""
	all = true
	print("Executing all downed enemies...")
	for enemy_instance in downed:
		killed += 1
		total += 1
		Stats.total_kills += 1
		
		enemy_instance.Combat_Module._transition_to(enemy_instance.Combat_Module.State.DEAD)
	downed.clear()
	_check_resolution_complete()

func _spare_all() -> void:
	"""Spare all downed enemies at once"""
	all = true
	print("Sparing all downed enemies...")
	
	for enemy_instance in downed:
		spared += 1
		total += 1
		Stats.total_spares += 1
		
		if enemy_instance.has_node("CombatModule"):
			enemy_instance.Combat_Module._transition_to(enemy_instance.Combat_Module.State.SPARED)
	
	downed.clear()
	_check_resolution_complete()
# ============================================
# CONSEQUENCE BUILDING
# ============================================
func _build_consequences() -> Dictionary:
	var c = {}
	
	# Corruption cores (use enum values)
	c["cores"] = _get_cores_from_enum(map_data.corruption_cores)
	
	# Archetype shifts based on kill/spare ratio
	if map_data.archetype_impact.size() > 0:
		var magnitude = _get_magnitude_value(MapData.ArchetypeMagnitude.SMALL)
		
		if killed > spared:
			c["death_shift"] = magnitude * killed
			Stats.advance_death(c["death_shift"])
		elif spared > killed:
			c["mercy_shift"] = magnitude * spared
			Stats.advance_mercy(c["mercy_shift"])
	
	# Faction opinions (implement in child classes for specific logic)
	if map_data.faction_opinion_impact != MapData.FactionOpinionImpact.NONE:
		c["faction_opinions"] = _calculate_faction_opinions()
	
	# Relic fragment
	match map_data.relic_fragment:
		MapData.RelicFragment.GUARANTEED:
			c["relic_fragment"] = true
		MapData.RelicFragment.POSSIBLE:
			if randf() < 0.3:  # 30% chance
				c["relic_fragment"] = true
		MapData.RelicFragment.CONDITIONAL:
			# Implement condition in child class
			pass
	
	# Spirit boon
	c["spirit_boon"] = map_data.spirit_boon
	
	return c

func _calculate_faction_opinions() -> Dictionary:
	# Override in child classes for specific faction logic
	return {}

func _get_cores_from_enum(cores_enum: MapData.CorruptionCores) -> int:
	match cores_enum:
		MapData.CorruptionCores.NONE: return 0
		MapData.CorruptionCores.MINIMAL: return randi_range(10, 25)
		MapData.CorruptionCores.LOW: return randi_range(25, 40)
		MapData.CorruptionCores.MEDIUM: return randi_range(40, 70)
		MapData.CorruptionCores.HIGH: return randi_range(70, 100)
		MapData.CorruptionCores.VERY_HIGH: return randi_range(100, 150)
		MapData.CorruptionCores.MASSIVE: return randi_range(150, 200)
		MapData.CorruptionCores.JACKPOT: return randi_range(200, 500)
		_: return 0

func _get_magnitude_value(magnitude: MapData.ArchetypeMagnitude) -> int:
	match magnitude:
		MapData.ArchetypeMagnitude.TINY: return 2
		MapData.ArchetypeMagnitude.SMALL: return 5
		MapData.ArchetypeMagnitude.MEDIUM: return 10
		MapData.ArchetypeMagnitude.HIGH: return 20
		MapData.ArchetypeMagnitude.VERY_HIGH: return 30
		_: return 0

# ============================================
# UTILITY FUNCTIONS
# ============================================
func get_current_state() -> MapState:
	return current_state

func is_in_combat() -> bool:
	return current_state == MapState.COMBAT

func is_exploration() -> bool:
	return current_state == MapState.EXPLORATION

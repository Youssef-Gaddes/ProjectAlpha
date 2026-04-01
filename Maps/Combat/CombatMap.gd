# res://maps/combat/combat_map.gd
extends BaseMap

# Spawn Configuration
@onready var spawn_area: Area3D = $EnemySpawnArea if has_node("EnemySpawnArea") else null
@onready var spawn_points_container: Node3D = $EnemySpawnPoints if has_node("EnemySpawnPoints") else null
@onready var ally_spawn_points_container: Node3D = $NpcSpawnPoint if has_node("NpcSpawnPoint") else null
@export var enemy_scene: PackedScene = preload("res://entities/NPCs/enemies/enemy_1/enemy_1.tscn")
@export var ally_scene:PackedScene = preload("res://entities/NPCs/soldier/soldier.tscn")
@onready var entry_box: CollisionShape3D = $EnemySpawnArea/EntryBox

var spawn_points: Array[Marker3D] = []
var ally_spawn_points: Array[Marker3D] = []
var enemy_count: int = 5  # Will be set from map_data
var ally_count: int = 1 # hardcoded for now

# ============================================
# INITIALIZATION
# ============================================
func _ready() -> void:
	map_data = get_meta("map_data")
	if map_data.primary_category == map_data.PrimaryCategory.SINGLE_FACTION_IMPACT:
		entry_box.set_deferred("disabled", true)
		ally_spawn_points.clear()
		if ally_spawn_points_container:
			for child in ally_spawn_points_container.get_children():
				if child is Marker3D:
					ally_spawn_points.append(child)
		var picked_spawn = ally_spawn_points.pick_random()
		var new_ally = ally_scene.instantiate()
		new_ally.position = picked_spawn.position
		add_child(new_ally)
		new_ally.add_to_group("ally")
	super._ready()
	# Get enemy count from map data or use default
	if map_data:
		enemy_count = _get_enemy_count_from_data()

	
	# Setup spawn area
	if spawn_area:
		spawn_area.body_entered.connect(_on_spawn_area_entered)

func _get_ally_count_from_data() -> int:
	# Derive ally count from combat_intensity
	match map_data.combat_intensity:
		MapData.CombatIntensity.LOW: return 1
		MapData.CombatIntensity.MEDIUM: return 2
		MapData.CombatIntensity.HIGH: return 3
		MapData.CombatIntensity.EXTREME: return 4
		_: return 1

func _get_enemy_count_from_data() -> int:
	# Derive enemy count from combat_intensity
	match map_data.combat_intensity:
		MapData.CombatIntensity.LOW: return randi_range(2, 4)
		MapData.CombatIntensity.MEDIUM: return randi_range(5, 8)
		MapData.CombatIntensity.HIGH: return randi_range(8, 11)
		MapData.CombatIntensity.EXTREME: return randi_range(12, 15)
		_: return 5

# ============================================
# STATE IMPLEMENTATIONS
# ============================================
func _start_exploration() -> void:
	super._start_exploration()
	
	# Enable spawn area detection
	if spawn_area:
		spawn_area.monitoring = true
		if spawn_area.has_node("CollisionShape3D"):
			spawn_area.get_node("CollisionShape3D").set_deferred("disabled", false)

func _on_spawn_area_entered(body: Node3D) -> void:
	if body.is_in_group("player") and current_state == MapState.EXPLORATION:
		
		# Disable spawn area
		if spawn_area and spawn_area.has_node("CollisionShape3D"):
			spawn_area.get_node("CollisionShape3D").set_deferred("disabled", true)
		
		_transition_to_state(MapState.COMBAT)

func _start_combat() -> void:
	super._start_combat()
	
	# Spawn enemies if not already spawned
	if enemies.is_empty():
		_spawn_enemies()

# ============================================
# ENEMY SPAWNING
# ============================================
func _spawn_enemies() -> void:
	# Gather spawn points
	spawn_points.clear()
	if spawn_points_container:
		for child in spawn_points_container.get_children():
			if child is Marker3D:
				spawn_points.append(child)
	
	if spawn_points.is_empty():
		push_error("No spawn points found! Add Marker3D children to SpawnPoints node")
		return
	
	print("Spawning %d enemies from %d spawn points" % [enemy_count, spawn_points.size()])
	
	# Spawn enemies
	for i in range(enemy_count):
		await get_tree().create_timer(0.1).timeout
		
		if spawn_points.is_empty():
			push_warning("Ran out of spawn points before spawning all enemies")
			break
		
		var picked_spawn = spawn_points.pick_random()
		var new_enemy = enemy_scene.instantiate()
		new_enemy.position = picked_spawn.position
		add_child(new_enemy)
		enemies.append(new_enemy)
		
		
		# Connect signals from Combat_Module
		if new_enemy.has_node("CombatModule"):
			var combat_module = new_enemy.Combat_Module
			
			# Connect downed signal
			combat_module.downed.connect(_on_enemy_downed)
			
			# Connect kill/spare signals (via custom signals you'll add)
			if combat_module.has_signal("enemy_killed"):
				combat_module.enemy_killed.connect(_on_enemy_killed)
			if combat_module.has_signal("enemy_spared"):
				combat_module.enemy_spared.connect(_on_enemy_spared)
			new_enemy.force_enter_combat()
		
		spawn_points.erase(picked_spawn)
	
	combat_started.emit()

# ============================================
# VICTORY CONDITION
# ============================================
func check_victory() -> bool:
	# Victory = all enemies are downed
	return downed.size() >= enemy_count

func _check_resolution_complete() -> void:
	
	if total >= enemy_count:
		_transition_to_state(MapState.DONE)

# ============================================
# CONSEQUENCE BUILDING
# ============================================
func _calculate_faction_opinions() -> Dictionary:
	var opinions = {}
	
	# If allies are present, helping them grants opinion
	if not allies.is_empty():
		print('allies not empty')
		# Determine which faction the allies belong to
		var ally_faction = _determine_ally_faction()
		print('ally faction is', ally_faction)
		
		if ally_faction != "":
			# Opinion based on performance
			var opinion_gain = 5
			if spared > killed:
				opinion_gain += 5  # Bonus for mercy
			opinions[ally_faction] = opinion_gain
	
	return opinions

func _determine_ally_faction() -> String:
	# Check first ally for faction affiliation
	if allies.size() > 0:
		print('allies not empty and got data')
		var npc_data = allies[0].NPC_Data
		print('this is the data', npc_data)
		print(npc_data.faction)
		return str(npc_data.faction).to_lower()
	return ""

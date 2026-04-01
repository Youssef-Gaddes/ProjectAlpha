# res://autoload/run_manager.gd
extends Node

signal node_choice_ready(options: Array[MapData])
signal run_complete(victory: bool)

var all_maps: Array[MapData] = []
var current_map: BaseMap = null
var SCENE_POOL: Dictionary = {}

# ============================================
# INITIALIZATION
# ============================================
func _ready() -> void:
	SCENE_POOL = {
	MapData.ZoneCategory.FACTION_TERRITORY: [
        "res://Maps/tests/Blockout.tscn"
	],
	MapData.ZoneCategory.CONTESTED_TERRITORY: [
		"res://Maps/tests/Blockout.tscn",
	],
	MapData.ZoneCategory.CORRUPTED_TERRITORY: [
		"res://Maps/tests/Blockout.tscn",
	],
	}
	_load_all_map_data()

func _load_all_map_data() -> void:
	# Load all .tres MapData resources from res://maps/data/
	var dir = DirAccess.open("res://Maps/Res/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var map_data = load("res://Maps/Res/" + file_name) as MapData
				if map_data:
					all_maps.append(map_data)
			file_name = dir.get_next()
	
	print("Loaded %d map variants" % all_maps.size())

# ============================================
# RUN GENERATION
# ============================================
func start_new_run() -> void:
	Stats.start_new_run()
	
	# Generate 15-node run
	Stats.selected_nodes = _generate_run()
	Stats.current_node_index = 0 
	# Load first node immediately (or show choice)
	_load_node(0)

func _generate_run() -> Array[MapData]:
	var run: Array[MapData] = []
	var used_map_ids: Dictionary = {}

	for i in range(7):
		var options = _filter_maps(MapData.ZoneCategory.FACTION_TERRITORY, i, used_map_ids)
		var chosen = _select_map_weighted(options)
		run.append(chosen)
		_track_usage(chosen, used_map_ids, i)
	
	# CONTESTED TERRITORY (Nodes 7-12)
	#for i in range(7, 13):
		#Stats.current_node_index = i
		#var options = _filter_maps(MapData.ZoneCategory.CONTESTED_TERRITORY, i, used_map_ids)
		#var chosen = _select_map_weighted(options)
		#run.append(chosen)
		#_track_usage(chosen, used_map_ids)
	
	# CORRUPTION TERRITORY (Nodes 12-16)
	#for i in range(13, 17):
		#Stats.current_node_index = i
		#var options = _filter_maps(MapData.ZoneCategory.CORRUPTED_TERRITORY, i, used_map_ids)
		#var chosen = _select_map_weighted(options)
		#run.append(chosen)
		#_track_usage(chosen, used_map_ids)
	
	return run

func _filter_maps(zone: MapData.ZoneCategory, node_index: int, used: Dictionary) -> Array[MapData]:
	var valid: Array[MapData] = []
	
	for map_data in all_maps:
		# Check zone
		if not map_data.check_zone(zone):
			continue
		
		# Check node position
		if not map_data.can_appear_at_node(node_index):
			continue
		
		# Check reusability
		if map_data.max_per_run == 0 and used.has(map_data.map_id):
			continue  # once_per_run already used
		
		if map_data.max_per_run > 0 and used.get(map_data.map_id, 0) >= map_data.max_per_run:
			continue  # Max uses reached
		
		# Check min_nodes_between
		if _too_soon(map_data.map_id, node_index, used):
			continue
		
		# Check requirements (faction opinion, archetype, run count, NPC alive)
		if not map_data.meets_requirements():
			continue
		
		
		
		valid.append(map_data)
	
	return valid

func _too_soon(map_id: String, current_index: int, used: Dictionary) -> bool:
	# Check if map was used too recently
	if not used.has(map_id + "_last_index"):
		print(used)
		print(map_id)
		return false
	
	var last_index = used[map_id + "_last_index"]
	var map_data = _get_map_by_id(map_id)
	print(current_index - last_index, map_data.min_nodes_between)
	if current_index - last_index < map_data.min_nodes_between:
		return true
	
	return false

func _select_map_weighted(options: Array[MapData]) -> MapData:
	# Weight by emotional_weight and complexity
	# For now, just pick random
	return options.pick_random()

func _track_usage(map_data: MapData, used: Dictionary, node_index: int) -> void:
	used[map_data.map_id] = used.get(map_data.map_id, 0) + 1
	used[map_data.map_id + "_last_index"] = node_index

func _get_map_by_id(map_id: String) -> MapData:
	for m in all_maps:
		if m.map_id == map_id:
			return m
	return null

# ============================================
# NODE LOADING
# ============================================
signal load_scene(scene_path: String, script: Script, map_data: MapData)

func _load_node(node_index: int) -> void:

	var map_data: MapData = Stats.selected_nodes[node_index]

	if map_data.can_appear_in.is_empty():
		push_error("MapData %s has no zones in can_appear_in" % map_data.map_id)
		return

	var primary_zone = map_data.can_appear_in[0]

	# If ANY, derive zone from node position in the run
	if primary_zone == MapData.ZoneCategory.ANY:
		primary_zone = _get_zone_enum_for_node(node_index)

	var pool: Array = SCENE_POOL.get(primary_zone, [])
	if pool.is_empty():
		push_error("No scenes in pool for zone: %s" % primary_zone)
		return

	var scene_path: String = pool.pick_random()
	var script = load(map_data.script_path) if map_data.script_path != "" else null

	load_scene.emit(scene_path, script, map_data)

# Replace the old string version with this enum version
func _get_zone_enum_for_node(index: int) -> MapData.ZoneCategory:
	if index < 6:
		return MapData.ZoneCategory.FACTION_TERRITORY
	elif index < 12:
		return MapData.ZoneCategory.CONTESTED_TERRITORY
	else:
		return MapData.ZoneCategory.CORRUPTED_TERRITORY
func advance_node() -> void:
	_load_node(Stats.current_node_index)

func _on_map_completed(consequences: Dictionary) -> void:
	Stats.complete_node(consequences)


# ============================================
# NODE CHOICE SYSTEM
# ============================================
func _show_node_choice() -> void:
	var next_index = Stats.current_node_index
	var zone = _get_zone_for_node(next_index)
	
	# Get 2-3 valid options
	var options = _filter_maps(zone, next_index, {})
	
	# Pick 2-3 distinct category options
	var choices = _pick_diverse_options(options, 3)
	
	# Emit signal for UI
	node_choice_ready.emit(choices)

func _pick_diverse_options(options: Array[MapData], count: int) -> Array[MapData]:
	var chosen: Array[MapData] = []
	var used_categories: Array[String] = []
	
	# Shuffle for randomness
	options.shuffle()
	
	for map_data in options:
		if chosen.size() >= count:
			break
		
		# Prefer diverse categories
		if map_data.primary_category not in used_categories:
			chosen.append(map_data)
			used_categories.append(map_data.primary_category)
	
	# Fill remaining slots if needed
	while chosen.size() < count and options.size() > chosen.size():
		for map_data in options:
			if map_data not in chosen:
				chosen.append(map_data)
				break
	
	return chosen

func player_chose_node(_map_data: MapData) -> void:
	# Update selected_nodes if needed (for dynamic choice)
	# Or just load the chosen map
	_load_node(Stats.current_node_index)

func _get_zone_for_node(index: int) -> String:
	if index < 6:
		return "faction_territory"
	elif index < 12:
		return "contested_territory"
	else:
		return "corruption_territory"

# ============================================
# VICTORY / DEFEAT
# ============================================
func _check_victory() -> void:
	# Check if player completed archetype path
	var path = _determine_archetype_path()
	if path != "":
		run_complete.emit(true)
		# Load archetype-specific final node
	else:
		# Continue or fail
		pass
	

func _determine_archetype_path() -> String:
	if Stats.archetype.mercy >= 50:
		return "mercy"
	elif Stats.archetype.death >= 50:
		return "death"
	elif Stats.archetype.order >= 50:
		return "order"
	elif Stats.archetype.chaos >= 50:
		return "chaos"
	return ""

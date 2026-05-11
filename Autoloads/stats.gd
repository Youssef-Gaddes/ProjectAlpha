extends Node

# ============================================
# RUN STATE
# ============================================
var in_run: bool = false
var current_run: int = 0
var current_node_index: int = 0  # 0-14 (15 nodes total)
var selected_nodes: Array[MapData] = []  # The 15 chosen maps
var selected_avatar:String = 'judge'

# ============================================
# PLAYER STATE
# ============================================
var player_health: float = 100.0

# Archetype Axes (0 to +100)
var archetype: Dictionary = {
	"death": 0,
	"mercy": 0,
	"order": 0,
	"chaos": 0,
	"love": 0,
	"fear": 60,
	"apathy": 0
}

var archetype_declared: bool = false
var declared_path: String = ""  # "mercy", "death", "order", "chaos"

# ============================================
# FACTION STATE
# ============================================
var faction_opinions: Dictionary = {
	"scholars": 0,
	"warriors": 0,
	"exiles": 0,
	"merchants": 0,
	"knights": 60,
	"corrruption": -75
}

func update_opinion(which:String, x:int):
	faction_opinions.set(which,faction_opinions.get(which)+x)

var faction_traits: Dictionary = {
	"scholars": {"peaceful": 0, "militant": 0,
				 "isolationist": 0, "open": 0,
				 "independant": 0, "religious": 0,
				 "agressive": 0, "cooperative": 0},
	"warriors": {"peaceful": 0, "militant": 0,
				 "isolationist": 0, "open": 0,
				 "independant": 0, "religious": 0,
				 "agressive": 0, "cooperative": 0},
	"exiles": {"peaceful": 0, "militant": 0,
				 "isolationist": 0, "open": 0,
				 "independant": 0, "religious": 0,
				 "agressive": 0, "cooperative": 0},
	"merchants": {"peaceful": 0, "militant": 0,
				 "isolationist": 0, "open": 0,
				 "independant": 0, "religious": 0,
				 "agressive": 0, "cooperative": 0},
	"knights": {"peaceful": 0, "militant": 0,
				 "isolationist": 0, "open": 0,
				 "independant": 0, "religious": 0,
				 "agressive": 0, "cooperative": 0},
}

func apply_faction_trait_shift(faction: String, trait_name: String, direction: int) -> void:
	# direction: +1 = toward militant/aggressive, -1 = toward peaceful/open
	if not faction_traits.has(faction):
		faction_traits[faction] = {}
	var current = faction_traits[faction].get(trait_name, 0)
	faction_traits[faction][trait_name] = clamp(current + direction, -5, 5)
	print("Trait shift: %s %s → %d" % [faction, trait_name, faction_traits[faction][trait_name]])

# ============================================
# NPC PERSISTENCE
# ============================================
var named_npcs: Dictionary = {
	 "elena": {
		"alive": true,
		"corrupted": false,
		"saved_count": 0,
		"interactions": [],
		"opinion": 0,
		"met": 0
		
	 }
}

func register_npc(npc_id: String, data: Dictionary) -> void:
	if not named_npcs.has(npc_id):
		named_npcs[npc_id] = data

func get_npc(npc_id: String) -> Dictionary:
	return named_npcs.get(npc_id, {})

func kill_npc(npc_id: String) -> void:
	if named_npcs.has(npc_id):
		named_npcs[npc_id]["alive"] = false
		named_npcs[npc_id]["interactions"].append("died_node_%d" % current_node_index)

func save_npc(npc_id: String) -> void:
	if named_npcs.has(npc_id):
		named_npcs[npc_id]["saved_count"] += 1
		named_npcs[npc_id]["interactions"].append("saved_node_%d" % current_node_index)

# ============================================
# PROGRESSION
# ============================================
var corruption_cores: int = 0
var relic_fragments: int = 0
var relics_unlocked: Array[String] = []
var avatars_unlocked: Array[String] = ["the_judge"]  # Starting avatar

var spirit_bonds: Dictionary = {
	"warlord": 0,
	"martyr": 0,
	"chronicler": 0,
	"judge": 0,
	"merchant_prince": 0,
	"father_spirit": 0
}

# ============================================
# STATISTICS
# ============================================

var beaten_enemies:int = 0
var completed_runs:int = 0
var deaths:int = 0
var total_kills: int = 0
var total_spares: int = 0
var nodes_completed: int = 0

# Archetype advancement (for spirit bond checks)
func advance_death(x) -> void:
	match x:
		'tiny':
			archetype.death += 1
		'small':
			archetype.death += 2
		'medium':
			archetype.death += 4
		'big':
			archetype.death += 8
		'huge':
			archetype.death += 16
		'max':
			archetype.death += 32
	

func advance_mercy(x) -> void:
	match x:
		'tiny':
			archetype.mercy += 1
		'small':
			archetype.mercy += 2
		'medium':
			archetype.mercy += 4
		'big':
			archetype.mercy += 8
		'huge':
			archetype.mercy += 16
		'max':
			archetype.mercy += 32


func advance_order(x) -> void:
	match x:
		'tiny':
			archetype.order += 1
		'small':
			archetype.order += 2
		'medium':
			archetype.order += 4
		'big':
			archetype.order += 8
		'huge':
			archetype.order += 16
		'max':
			archetype.order += 32


func advance_chaos(x) -> void:
	match x:
		'tiny':
			archetype.chaos += 1
		'small':
			archetype.chaos += 2
		'medium':
			archetype.chaos += 4
		'big':
			archetype.chaos += 8
		'huge':
			archetype.chaos += 16
		'max':
			archetype.chaos += 32


func advance_love(x) -> void:
	match x:
		'tiny':
			archetype.love += 1
		'small':
			archetype.love += 2
		'medium':
			archetype.love += 4
		'big':
			archetype.love += 8
		'huge':
			archetype.love += 16
		'max':
			archetype.love += 32


func advance_fear(x) -> void:
	match x:
		'tiny':
			archetype.fear += 1
		'small':
			archetype.fear += 2
		'medium':
			archetype.fear += 4
		'big':
			archetype.fear += 8
		'huge':
			archetype.fear += 16
		'max':
			archetype.fear += 32

func start_new_run() -> void:
	in_run = true
	current_run += 1
	current_node_index = 0
	player_health = 200.0
	# Don't reset archetype/factions/npcs - they persist across runs

func complete_node(consequences: Dictionary) -> void:
	# Apply consequences from completed map
	_apply_consequences(consequences)
	current_node_index += 1
	nodes_completed += 1

func _apply_consequences(c: Dictionary) -> void:
	# Archetype shifts
	if c.has("death_shift"):
		archetype.death += c.death_shift
	if c.has("mercy_shift"):
		archetype.mercy += c.mercy_shift
	if c.has("order_shift"):
		archetype.order += c.order_shift
	
	# Faction opinions
	if c.has("faction_opinions"):
		for faction in c.faction_opinions:
			faction_opinions[faction] += c.faction_opinions[faction]
	
	# Cores & Fragments
	if c.has("cores"):
		corruption_cores += c.cores
	if c.has("relic_fragment"):
		relic_fragments += 1
	
	# NPC status
	if c.has("npc_killed"):
		kill_npc(c.npc_killed)
	if c.has("npc_saved"):
		save_npc(c.npc_saved)

func _map_trans_diag_done():
	get_tree().get_first_node_in_group('map')._transition_to_state(get_tree().get_first_node_in_group('map').MapState.DONE)

func _map_trans_diag_combat():
	print('AAAAAAAAAAAAAAAAAAAAAA')
	get_tree().get_first_node_in_group('map')._transition_to_state(get_tree().get_first_node_in_group('map').MapState.COMBAT)

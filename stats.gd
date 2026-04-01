extends Node

# ============================================
# RUN STATE
# ============================================
var in_run: bool = false
var current_run: int = 0
var current_node_index: int = 0  # 0-14 (15 nodes total)
var selected_nodes: Array[MapData] = []  # The 15 chosen maps

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
	"fear": 0,
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
	"knights": 30,
	"corrruption": -75
}

var faction_traits: Dictionary = {
	"scholars": {"peaceful": 0, "militant": 0},
	"warriors": {"peaceful": 0, "militant": 0},
	"exiles": {"peaceful": 0, "militant": 0},
	"merchants": {"peaceful": 0, "militant": 0},
	"knights": {"peaceful": 0, "militant": 0}
}

# ============================================
# NPC PERSISTENCE
# ============================================
var named_npcs: Dictionary = {
	 "elena": {
		 "alive": true,
		 "corrupted": false,
		 "saved_count": 2,
		 "interactions": ["saved_node_3", "saved_node_10"],
		 "opinion": 50
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
	"merchant_prince": 0
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
	archetype.death += x
	

func advance_mercy(x) -> void:
	archetype.mercy += x


func advance_order(x) -> void:
	archetype.order += x


func advance_chaos(x) -> void:
	archetype.chaos += x

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
	get_tree().get_first_node_in_group('map')._transition_to_state(get_tree().get_first_node_in_group('map').MapState.COMBAT)

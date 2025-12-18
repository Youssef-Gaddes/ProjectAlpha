class_name NPCData
extends Resource

# === IDENTITY ===
@export var npc_name: String = "Unknown"
@export var npc_id: String = ""  # Unique identifier for save/load systems
@export_enum("Scholars", "Warriors", "Exiles", "Merchants", "Knights", "Corruption", "None") var faction: String = "Scholars"
@export var can_talk: bool
@export var can_fight: bool 
@export var fight_mode: bool
@export var is_hostile: bool 

@export_group("Combat")
@export var max_health: float = 200.0

# === MOVEMENT ===
@export_group("Movement")
@export var run_speed: float = 6.0
@export var walk_speed: float = 3.0
@export var rotation_speed: float = 8.0

# === AI RANGES ===
@export_group("Detection")
@export var detection_range: float = 15.0
@export var walk_range: float = 6.0
@export var stop_distance: float = 2.0

# === ATTACK DEFINITIONS ===
@export_group("Attacks")
@export var attacks: Array[AttackData] = []  # Array of AttackData resources

func _choose_attack(x:float):
	for i in attacks:
		if i.min_range <= x and x <= i.max_range:
			return i

@export_group("Knockback")
@export var knockback_strength: float = 10.0
@export var knockback_duration: float = 0.4
@export var hit_stun_duration: float = 1.0

# === NAVIGATION ===
@export_group("Navigation")
@export var path_update_rate: float = 0.2
@export var avoidance_enabled: bool = true
@export var avoidance_radius: float = 0.4
@export var arc_strength: float = 0.2

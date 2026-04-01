class_name MapData
extends Resource

# ============================================
# IDENTITY
# ============================================
@export var map_id: String = "N-001"
@export var display_name: String = "Beast Nest"
@export var description: String = "Corrupted animals nest. Clear them out."
@export var scene_path: String = "res://Maps/Combat maps/test.tscn"
@export var script_path: String 
@export var has_intro: bool = false

enum PrimaryCategory {
	PURE_COMBAT,
	SINGLE_FACTION_IMPACT,
	MULTI_FACTION_IMPACT,
	CORRUPTED_MORTAL,
	RESPITE_SUPPORT,
	SPIRIT_IMPACT,
	ENVIRONMENTAL_CHALLENGE,
	SPECIAL }
enum VictoryType {
	KILL_ALL_ENEMIES,
	SURVIVE_TIMER,
	MAKE_CHOICE,
	COMPLETE_OBJECTIVE,
	BOSS_DEFEATED,
	PLAYER_LEAVES
}
enum ComplexityTier {
	SIMPLE,
	MODERATE,
	COMPLEX
}
enum EmotionalWeight {
	NONE,
	LOW,
	MEDIUM,
	HIGH,
	VERY_HIGH 
}
enum CombatType {
	NONE,
	OPTIONAL,
	GUARANTEED,
	WAVES,
	BOSS,
	SIEGE,
	SURVIVAL 
}
enum CombatIntensity {
	LOW,
	MEDIUM,
	HIGH,
	EXTREME
}
enum MoralChoice{
	NONE,
	LOW,
	MEDIUM,
	HIGH,
	VERY_HIGH
}
enum NPCPresence {
	NONE,
	BACKGROUND,
	ALLIED,
	HOSTILE,
	NEUTRAL,
	MIXED
}
enum NPCDeath {
	NO,
	YES_MINOR,
	YES_NAMED,
	MIXED
}
enum MapDuration {
	VERY_SHORT,
	SHORT,
	MEDIUM,
	LONG,
	VERY_LONG,
	EPIC
}
enum ArchetypeImpact {
	NONE,
	DEATH,
	MERCY,
	ORDER,
	CHAOS,
	LOVE,
	FEAR,
	APATHY
}
enum ArchetypeMagnitude {
	TINY,
	SMALL,
	MEDIUM,
	HIGH,
	VERY_HIGH
}
enum FactionAffected {
	NONE,
	SCHOLARS,
	WARRIORS,
	EXILES,
	MERCHANTS,
	KNIGHTS,
	CORRUPTION
}
enum FactionOpinionImpact {
	NONE,
	SINGLE,
	DUAL,
	MULTI,
	ALL
}
enum FactionOpinionMagnitude {
	TINY,
	SMALL,
	MODERATE,
	HIGH,
	VERY_HIGH
}
enum FactionTraitShift {
	PEACEFUL_MILITANT,
	ISOLATIONIST_OPEN,
	RELIGIOUS_INDEPENDENT,
	COOPERATIVE_AGRESSIVE,
	NONE
}
enum WorldStateChange {
	NONE,
	CORRUPTION_SPREAD,
	NPC_DEATH,
	FACTION_ALLIANCE,
	FACTION_WAR
}
enum SpiritImpact {
	NONE,
	SINGLE,
	MUTLI,
	NEUTRAL
}
enum ZoneCategory {
	ANY,
	FACTION_TERRITORY,
	CONTESTED_TERRITORY,
	CORRUPTED_TERRITORY
}
enum RequiredFactionOpinion {
	NONE,
	POSITIVE, #>0
	NEGATIVE, #<0
	FRIENDLY, #>25
	ALLIED, #>50
	REVERENT, #>75
	HOSTILE, #<-25
	HATED, #<-50
	NEMESIS #<-75
}
enum RequiredArchetype {
	NONE,
	DEATH_25,
	MERCY_25,
	ORDER_25,
	CHAOS_25,
	DEATH_50,
	MERCY_50,
	ORDER_50,
	CHAOS_50,
	DECLARED,
	UNDECLARED
}
enum CorruptionCores {
	NONE,
	MINIMAL,
	LOW,
	MEDIUM,
	HIGH,
	VERY_HIGH,
	MASSIVE,
	JACKPOT
}
enum SpiritBoon {
	NONE,
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}
enum RelicFragment {
	NONE,
	POSSIBLE,
	GUARANTEED,
	CONDITIONAL
}

# ============================================
# IDENTITY TAGS
# ============================================
@export_group("Identity Tags")
@export var primary_category: PrimaryCategory = PrimaryCategory.PURE_COMBAT
@export var complexity_tier: ComplexityTier = ComplexityTier.SIMPLE
@export var emotional_weight: EmotionalWeight = EmotionalWeight.NONE

# ============================================
# VICTORY & FAILURE
# ============================================

@export var victory_condition: VictoryType = VictoryType.KILL_ALL_ENEMIES
@export var has_timer: bool = false
@export var timer_duration: float = 60.0
@export var can_fail: bool = false

# ============================================
# MECHANICAL TAGS
# ============================================
@export_group("Mechanical Tags")
@export var combat_type: CombatType = CombatType.NONE
@export var combat_intensity: CombatIntensity = CombatIntensity.LOW
@export var moral_choice: MoralChoice = MoralChoice.NONE
@export var npc_presence: NPCPresence = NPCPresence.NONE
@export var npc_death: NPCDeath = NPCDeath.NO
@export var map_duration: MapDuration = MapDuration.VERY_SHORT

# ============================================
# CONSEQUENCE TAGS
# ============================================
@export_group("Consequence Tags")
@export var archetype_impact: Array[ArchetypeImpact] = [ArchetypeImpact.NONE]
@export var faction_affected:Array[FactionAffected] = [FactionAffected.NONE]
@export var faction_opinion_impact: FactionOpinionImpact = FactionOpinionImpact.NONE
@export var faction_opinion_magnitude: FactionOpinionMagnitude = FactionOpinionMagnitude.TINY
@export var faction_trait_shift: Dictionary[FactionAffected, FactionTraitShift] = {
	FactionAffected.NONE : FactionTraitShift.NONE }
@export var world_state_change: Array[WorldStateChange] = [WorldStateChange.NONE]
@export var spirit_impact: SpiritImpact = SpiritImpact.NONE

# ============================================
# CONDITION TAGS
# ============================================
@export_group("Condition Tags")
@export var can_appear_in: Array[ZoneCategory] = [ZoneCategory.ANY]
@export var earliest_node: int = 1
@export var latest_node: int = 18
@export var max_per_run: int = -1  # -1 = unlimited, 0 = once, 1+ = limited
@export var min_nodes_between: int = 3  # Can't appear within 3 nodes of itself
@export var required_run_count:int = 0
@export var required_faction: FactionAffected = FactionAffected.NONE
@export var required_faction_opinion: RequiredFactionOpinion = RequiredFactionOpinion.NONE
@export var required_archetype: RequiredArchetype = RequiredArchetype.NONE

# ============================================
# REWARD TAGS
# ============================================
@export_group("Reward Tags")
@export var corruption_cores: CorruptionCores = CorruptionCores.NONE
@export var spirit_boon: SpiritBoon = SpiritBoon.NONE
@export var relic_fragment: RelicFragment = RelicFragment.NONE

func can_appear_at_node(node_index: int) -> bool:
	return node_index >= earliest_node and node_index <= latest_node

func check_zone(zone: ZoneCategory):
	if can_appear_in.has(ZoneCategory.ANY):
		return true
	elif can_appear_in.has(zone):
		return true
	return false

func meets_requirements() -> bool:
	# Check faction opinion requirement
	if not get_faction_opinion_requirements():
		return false
	
	# Check archetype requirement
	if not get_archetype_requirement():
		return false
	
	# Check run count
	if Stats.current_run < required_run_count:
		return false
	
	
	return true

func get_faction_opinion_requirements():
	var faction = FactionAffected.keys()[required_faction].to_lower()
	print("here: ", faction)
	var opinion: int
	match required_faction_opinion:
		RequiredFactionOpinion.NONE: opinion = 0
		RequiredFactionOpinion.POSITIVE: opinion = 1
		RequiredFactionOpinion.NEGATIVE: opinion = -1
		RequiredFactionOpinion.FRIENDLY:opinion = 25
		RequiredFactionOpinion.ALLIED: opinion = 50
		RequiredFactionOpinion.REVERENT: opinion = 75
		RequiredFactionOpinion.HOSTILE: opinion = -25
		RequiredFactionOpinion.HATED: opinion = -50
		RequiredFactionOpinion.NEMESIS: opinion = -75
	var current_opinion = Stats.faction_opinions.get(faction)
	if faction == 'none' or opinion == 0:
		return true
	if opinion > 0:
		if current_opinion >= opinion:
			return true
	if opinion < 0:
		if current_opinion <= opinion:
			return true
	return false

func get_archetype_requirement():
	var archetype = ""
	var value = 0
	match required_archetype:
		RequiredArchetype.NONE:
			return true
		RequiredArchetype.DEATH_25:
			archetype = "death"
			value = 25
		RequiredArchetype.MERCY_25:
			archetype = "mercy"
			value = 25
		RequiredArchetype.ORDER_25:
			archetype = "order"
			value = 25
		RequiredArchetype.CHAOS_25:
			archetype = "chaos"
			value = 25
		RequiredArchetype.DEATH_50:
			archetype = "death"
			value = 50
		RequiredArchetype.MERCY_50:
			archetype = "mercy"
			value = 50
		RequiredArchetype.ORDER_50:
			archetype = "order"
			value = 50
		RequiredArchetype.CHAOS_50:
			archetype = "chaos"
			value = 50
		RequiredArchetype.DECLARED:
			if Stats.archetype_declared:
				return true
		RequiredArchetype.UNDECLARED:
			if not Stats.archetype_declared:
				return true
	if Stats.archetype.get(archetype) >= value:
		return true
	return false

func get_cores_reward() -> int:
	match corruption_cores:
		CorruptionCores.NONE: return 0
		CorruptionCores.MINIMAL: return randi_range(10, 25)
		CorruptionCores.LOW: return randi_range(25, 40)
		CorruptionCores.MEDIUM: return randi_range(40, 70)
		CorruptionCores.HIGH: return randi_range(70, 100)
		CorruptionCores.VERY_HIGH: return randi_range(100, 150)
		CorruptionCores.MASSIVE: return randi_range(150, 200)
		CorruptionCores.JACKPOT: return randi_range(200, 500)
		_: return 0

class_name UpgradeData
extends Resource

enum UpgradeType { COMMON, SPIRIT_BOON, AVATAR }
enum Tier { I, II, III, IV }
enum Spirit { NONE, FIRE, ICE, STORM, EARTH, SHADOW }

@export var upgrade_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var type: UpgradeType = UpgradeType.COMMON
@export var tier: Tier = Tier.I
@export var spirit: Spirit = Spirit.NONE       # for SPIRIT_BOON type
@export var avatar_id: String = ""             # for AVATAR type, e.g "the_judge"
@export var effects: Array[UpgradeEffect] = []
@export var can_stack: bool = false            # can it appear multiple times in a run
@export var max_stacks: int = 1               # if can_stack, how many times max

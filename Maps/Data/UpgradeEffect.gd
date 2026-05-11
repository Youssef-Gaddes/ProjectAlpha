class_name UpgradeEffect
extends Resource

enum EffectType {
	STAT_BOOST,        # flat or percent modifier on player stat
	ON_HIT_CHANCE,     # % chance to trigger on hit
	AOE_MODIFIER,      # hitbox size multiplier
	RESOURCE_GEN,      # bonus cores per map
	STATUS_ON_HIT,     # apply status effect on hit
	Q_MODIFIER,        # change execute threshold or cost
	E_MODIFIER         # change judgment generation rate
}

@export var effect_type: EffectType = EffectType.STAT_BOOST
@export var stat_target: String = ""   # "speed", "damage", "max_health", "attack_speed"
@export var value: float = 0.0         # 0.1 = 10%, flat value for non-percent
@export var is_percent: bool = true
@export var status_type: String = ""   # "burn", "slow", "stun" for STATUS_ON_HIT

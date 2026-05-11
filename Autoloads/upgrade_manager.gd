extends Node

var all_upgrades: Array[UpgradeData] = []
var active_upgrades: Array[UpgradeData] = []  # current run only
var upgrade_stack_counts: Dictionary = {}      # upgrade_id -> times taken
var current_offer: Array[UpgradeData] = []

const TIER_WEIGHTS: Dictionary = {
	UpgradeData.Tier.I:   60,
	UpgradeData.Tier.II:  25,
	UpgradeData.Tier.III: 12,
	UpgradeData.Tier.IV:  3,
}

# ============================================
# INITIALIZATION
# ============================================
func _ready() -> void:
	_load_all_upgrades()

func _load_all_upgrades() -> void:
	var dir = DirAccess.open("res://Maps/Data/Upgrades/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var upgrade = load("res://Maps/Data/Upgrades/" + file_name) as UpgradeData
				if upgrade:
					all_upgrades.append(upgrade)
			file_name = dir.get_next()
	print("Loaded %d upgrades" % all_upgrades.size())

func reset_run() -> void:
	active_upgrades.clear()
	upgrade_stack_counts.clear()

# ============================================
# OFFER GENERATION
# ============================================
func generate_offer(map_data: MapData) -> Array[UpgradeData]:
	var pool = _build_pool(map_data)
	if pool.is_empty():
		push_error("Upgrade pool is empty!")
		return []
	return _pick_offer(pool, 3)

func _build_pool(map_data: MapData) -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = []

	for upgrade in all_upgrades:
		match upgrade.type:
			UpgradeData.UpgradeType.COMMON:
				if _is_available(upgrade):
					pool.append(upgrade)

			UpgradeData.UpgradeType.SPIRIT_BOON:
				# Only on spirit maps with positive spirit opinion
				if map_data.spirit_impact != MapData.SpiritImpact.NONE:
					if _has_positive_spirit_opinion(upgrade.spirit):
						if _is_available(upgrade):
							pool.append(upgrade)

			UpgradeData.UpgradeType.AVATAR:
				# Only for current avatar
				if upgrade.avatar_id == Stats.selected_avatar:
					if _is_available(upgrade):
						pool.append(upgrade)

	return pool

func _is_available(upgrade: UpgradeData) -> bool:
	if not upgrade.can_stack:
		# Non-stackable: only offer if not already taken
		return not upgrade_stack_counts.has(upgrade.upgrade_id)
	else:
		# Stackable: offer if under max stacks
		var current = upgrade_stack_counts.get(upgrade.upgrade_id, 0)
		if upgrade.max_stacks == -1:
			return true
		else:
			return current < upgrade.max_stacks

func _has_positive_spirit_opinion(spirit: UpgradeData.Spirit) -> bool:
	var spirit_key = UpgradeData.Spirit.keys()[spirit].to_lower()
	return Stats.spirit_bonds.get(spirit_key, 0) > 0

func _pick_offer(pool: Array[UpgradeData], count: int) -> Array[UpgradeData]:
	var offer: Array[UpgradeData] = []
	var remaining = pool.duplicate()

	# Guarantee at least 1 common
	var commons = remaining.filter(func(u): return u.type == UpgradeData.UpgradeType.COMMON)
	if not commons.is_empty():
		var picked = _weighted_random(commons)
		offer.append(picked)
		remaining.erase(picked)

	# Fill remaining slots with weighted random from full pool
	while offer.size() < count and not remaining.is_empty():
		var picked = _weighted_random(remaining)
		if picked not in offer:
			offer.append(picked)
		remaining.erase(picked)

	return offer

func _weighted_random(pool: Array[UpgradeData]) -> UpgradeData:
	var total_weight = 0
	for upgrade in pool:
		total_weight += TIER_WEIGHTS.get(upgrade.tier, 1)

	var roll = randi_range(0, total_weight - 1)
	var cumulative = 0
	for upgrade in pool:
		cumulative += TIER_WEIGHTS.get(upgrade.tier, 1)
		if roll < cumulative:
			return upgrade

	return pool.back()

# ============================================
# APPLYING UPGRADES
# ============================================
func apply_upgrade(upgrade: UpgradeData) -> void:
	active_upgrades.append(upgrade)
	upgrade_stack_counts[upgrade.upgrade_id] = upgrade_stack_counts.get(upgrade.upgrade_id, 0) + 1

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("No player found to apply upgrade!")
		return

	for effect in upgrade.effects:
		_apply_effect(player, effect)

func _apply_effect(player: Node, effect: UpgradeEffect) -> void:
	match effect.effect_type:
		UpgradeEffect.EffectType.STAT_BOOST:
			_apply_stat_boost(player, effect)

		UpgradeEffect.EffectType.AOE_MODIFIER:
			var hitbox = player.get_node_or_null("Hitbox/AttackHitbox")
			if hitbox and hitbox.shape:
				hitbox.shape.size *= (1.0 + effect.value)

		UpgradeEffect.EffectType.RESOURCE_GEN:
			Stats.corruption_cores += int(effect.value)

		UpgradeEffect.EffectType.ON_HIT_CHANCE, \

		UpgradeEffect.EffectType.STATUS_ON_HIT:
			# These are checked at hit time — store on player
			player.active_on_hit_effects.append(effect)

func _apply_stat_boost(player: Node, effect: UpgradeEffect) -> void:
	match effect.stat_target:
		"damage":
			for i in player.attack_damage.size():
				if effect.is_percent:
					player.attack_damage[i] *= (1.0 + effect.value)
				else:
					player.attack_damage[i] += effect.value
		"speed":
			if effect.is_percent:
				player.speed *= (1.0 + effect.value)
				player.running_speed *= (1.0 + effect.value)
			else:
				player.speed += effect.value
				player.running_speed += effect.value
		"max_health":
			if effect.is_percent:
				var bonus = player.max_health * effect.value
				player.max_health += bonus
				player.health += bonus
			else:
				player.max_health += effect.value
				player.health += effect.value
		"attack_speed":
			if effect.is_percent:
				player.attack_speed *= (1.0 + effect.value)

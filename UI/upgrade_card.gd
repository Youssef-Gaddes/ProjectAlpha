# res://UI/UpgradeScreen/upgrade_card.gd
extends PanelContainer

signal selected

var upgrade: UpgradeData

@onready var type_label: Label = $VBox/Top/TypeLabel
@onready var tier_label: Label = $VBox/Top/TierLabel
@onready var name_label: Label = $VBox/Name
@onready var desc_label: Label = $VBox/Desc
@onready var effect_label: Label = $VBox/Effect
@onready var stack_label: Label = $VBox/Stacks

const TIER_NAMES = ["I", "II", "III", "IV"]

func setup(data: UpgradeData) -> void:
	upgrade = data
	type_label.text = UpgradeData.UpgradeType.keys()[data.type]
	tier_label.text = "Tier %s" % TIER_NAMES[data.tier]
	name_label.text = data.display_name
	desc_label.text = data.description
	effect_label.text = _build_effect_string(data)
	if data.can_stack:
		var current = UpgradeManager.upgrade_stack_counts.get(data.upgrade_id, 0)
		stack_label.text = "%d stacks remaining" % (data.max_stacks - current)
		stack_label.visible = true
	else:
		stack_label.visible = false

func _build_effect_string(data: UpgradeData) -> String:
	var parts = []
	for effect in data.effects:
		if effect.is_percent:
			parts.append("+%d%% %s" % [int(effect.value * 100), effect.stat_target])
		else:
			parts.append("+%s %s" % [effect.value, effect.stat_target])
	return ", ".join(parts)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		selected.emit()

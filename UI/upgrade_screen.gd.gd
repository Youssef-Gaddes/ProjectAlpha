extends VBoxContainer

@onready var card_container: HBoxContainer = $Cards
@onready var confirm_btn: Button = $Confirm
@onready var skip_btn: Button = $Skip

const CARD_SCENE = preload("res://UI/upgrade_card.tscn")

var current_offer: Array[UpgradeData] = []
var selected_upgrade: UpgradeData = null

func show_upgrade_offer(offer: Array[UpgradeData]) -> void:
	$"../../../..".lock_player.emit()
	current_offer = offer
	selected_upgrade = null
	confirm_btn.disabled = true
	visible = true

	for child in card_container.get_children():
		child.queue_free()

	for upgrade in offer:
		var card = CARD_SCENE.instantiate()
		card_container.add_child(card)
		card.setup(upgrade)
		card.selected.connect(_on_card_selected.bind(upgrade))

func _on_card_selected(upgrade: UpgradeData) -> void:
	selected_upgrade = upgrade
	confirm_btn.disabled = false


func _on_confirm_pressed() -> void:
	if not selected_upgrade:
		return
	UpgradeManager.apply_upgrade(selected_upgrade)
	visible = false
	# Tell the map to activate the TP
	get_tree().get_first_node_in_group("map").tp.activate()
	$"../../../..".unlock_player.emit()

func _on_skip_pressed() -> void:
	visible = false
	get_tree().get_first_node_in_group("map").tp.activate()
	$"../../../..".unlock_player.emit()

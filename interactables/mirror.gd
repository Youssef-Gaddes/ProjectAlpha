extends StaticBody3D

@onready var mirror_3d: Mirror3D = $Mirror/Mirror3D
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group('player')
var distance:float
var on: bool = false
@onready var stats_info_ui: CanvasLayer = $statsInfoUi

@onready var death_label: Label = $statsInfoUi/Control/MarginContainer/Panel/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/deathLabel
@onready var mercy_label: Label = $statsInfoUi/Control/MarginContainer/Panel/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/mercyLabel
@onready var order_label: Label = $statsInfoUi/Control/MarginContainer/Panel/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/orderLabel
@onready var kill_label: Label = $statsInfoUi/Control/MarginContainer/Panel/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/killLabel
@onready var complete_runs_label: Label = $statsInfoUi/Control/MarginContainer/Panel/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/completeRunsLabel
@onready var deahts_label: Label = $statsInfoUi/Control/MarginContainer/Panel/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/deahtsLabel
@onready var chaos_label: Label = $statsInfoUi/Control/MarginContainer/Panel/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/chaosLabel
@onready var corruption_cores: Label = $statsInfoUi/Control/MarginContainer/Panel/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/corruptionCores

func _ready() -> void:
	stats_info_ui.visible = false
	death_label.text = death_label.text + str(Stats.archetype.get('death'))
	mercy_label.text = mercy_label.text + str(Stats.archetype.get('mercy'))
	order_label.text = order_label.text + str(Stats.archetype.get('order'))
	chaos_label.text = chaos_label.text + str(Stats.archetype.get('chaos'))
	kill_label.text = kill_label.text + str(Stats.beaten_enemies)
	complete_runs_label.text = complete_runs_label.text + str(Stats.completed_runs)
	deahts_label.text = deahts_label.text + str(Stats.deaths)
	corruption_cores.text = corruption_cores.text + str(Stats.corruption_cores)
	
func _process(_delta: float) -> void:
	if on and Input.is_action_just_pressed('interact'):
		interact()
	get_distance_to_player()
	var disto:float = distance*11
	if disto<10:
		mirror_3d.distortion = 0.0
	elif disto > 100:
		mirror_3d.distortion = 100.0
	else:
		mirror_3d.distortion = disto

func interact():
	if stats_info_ui.visible == true:
		hide_ui()
		player.can_move = true
	elif stats_info_ui.visible == false:
		show_ui()
		player.can_move = false

func show_ui():
	stats_info_ui.visible = true

func hide_ui():
	stats_info_ui.visible = false

func get_distance_to_player():
	if player:
		distance = global_position.distance_to(player.global_position)
		


func _on_interaction_area_body_entered(body: Node3D) -> void:
	if body.is_in_group('player'):
		on = true

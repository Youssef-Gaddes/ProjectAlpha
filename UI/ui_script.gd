extends CanvasLayer
@onready var health_bar: ProgressBar =$Control/MarginContainer/VBoxContainer/ProgressBar
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
@onready var j_bar1: ProgressBar = $Control/MarginContainer/VBoxContainer/HBoxContainer/judgment_bar_1
@onready var j_bar2: ProgressBar = $Control/MarginContainer/VBoxContainer/HBoxContainer/judgment_bar_2
@onready var j_bar3: ProgressBar = $Control/MarginContainer/VBoxContainer/HBoxContainer/judgment_bar_3
@onready var j_bar4: ProgressBar = $Control/MarginContainer/VBoxContainer/HBoxContainer/judgment_bar_4
@onready var j_bar5: ProgressBar = $Control/MarginContainer/VBoxContainer/HBoxContainer/judgment_bar_5
@onready var bars:Array[ProgressBar] = [j_bar1,j_bar2,j_bar3,j_bar4,j_bar5]
@onready var kill_spare: MarginContainer = $Control/MarginContainer/VBoxContainer/KillSpare


func _ready() -> void:
	kill_spare.visible = false
	health_bar.max_value = player.max_health
	health_bar.value = player.current_health
	for i in range(bars.size()):
		bars[i].value = 0
		bars[i].max_value = player.max_judgment
func _process(_delta: float) -> void:
	health_bar.value = player.current_health

func show_verdict():
	kill_spare.visible = true

func hide_verdict():
	kill_spare.visible = false

func _update_judgment_bars():
	var p_judgment = player.judgment
	var p_current_judgment = player.hits_to_judgment
	for i in range(bars.size()):
		if i<p_judgment:
			bars[i].value = player.max_judgment
		elif i == p_judgment:
			bars.get(i).value = p_current_judgment
		elif i > p_judgment:
			bars[i].value = 0

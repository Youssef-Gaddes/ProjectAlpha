extends Node3D
@onready var tp: Node3D = $Tp


func _ready() -> void:
	tp.activate()
	Stats.in_run = false
	if Stats.player_health != null:
		Stats.completed_runs += 1
	

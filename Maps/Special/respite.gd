# respite_map.gd
extends BaseMap

@onready var fountain: Node3D = $"Static bodies/Fountain"

func _start_exploration() -> void:
	# Connect fountain signal to our handler
	fountain.respite_done.connect(_on_player_healed)

func _on_player_healed() -> void:
	_transition_to_state(MapState.DONE)

func check_victory() -> bool:
	# Respite maps don't have combat, so this should never be called
	# but we implement it to satisfy the base class requirement
	return false

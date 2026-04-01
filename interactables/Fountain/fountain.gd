extends StaticBody3D

@onready var player = get_tree().get_first_node_in_group("player")

@export var healing_ratio:float = 0.5

var used:bool = false
var player_close:bool = false

signal respite_done

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("interact") and player_close:
		use()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_close = true
		

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_close = false

func use():
	if not used:
		player.heal(player.max_health*healing_ratio)
		used = true
		respite_done.emit()

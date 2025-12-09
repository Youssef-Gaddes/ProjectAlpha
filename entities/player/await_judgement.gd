extends Node3D

@onready var timer = $Timer
@onready var stunned_enemies: Array[CharacterBody3D] = []
@onready var player: CharacterBody3D 

func _ready() -> void:
	player = get_tree().get_first_node_in_group('player')
	timer.wait_time = player.a_j_timer
	timer.start()
	player.awaiting_judgment = true
	

func _on_timer_timeout() -> void:
	for i in stunned_enemies:
		i.stunned = false
	player.awaiting_judgment = false
	queue_free()


func _on_area_3d_area_entered(area: Area3D) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return
	var enemy = area.get_parent()
	stunned_enemies.append(enemy)
	enemy.stunned = true
	enemy._transition_to(enemy.State.STUNNED)


func _on_area_3d_area_exited(area: Area3D) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return
	var enemy = area.get_parent()
	stunned_enemies.erase(enemy)
	enemy.stunned = false

extends Node3D

@onready var enemy: PackedScene = preload("res://entities/enemies/enemy_1/enemy_1.tscn")
@onready var spawn_points : Array[Marker3D]
@onready var enemies: Array[CharacterBody3D]
@onready var player: CharacterBody3D
@export var enemy_number: int = 5
@export var downed: Array[CharacterBody3D] = []
@export var spared:int = 0
@export var killed:int = 0
@export var all:bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group('player')
	
func _on_enemy_downed(x:CharacterBody3D):
	downed.append(x)
	if downed.size() == enemy_number:
		player._verdict_start()
func _on_enemy_killed(x:CharacterBody3D):
	if !all:
		downed.erase(x)
	killed += 1
func _on_enemy_spared(x:CharacterBody3D):
	if !all:
		downed.erase(x)
	spared += 1

func _kill_all():
	all = true
	for i in downed:
		killed += 1
		i._transition_to(i.State.DEAD)
	downed.clear()

func _spare_all():
	all = true
	for i in downed:
		spared += 1
		i._transition_to(i.State.SPARED)
	downed.clear()


func _on_enemy_spawn_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		enemy_spawn()
		$EnemySpawnArea/EntryBox.disabled = true 
			
func enemy_spawn():
	var sp = $SpawPoints.get_children()
	for i in sp:
		spawn_points.append(i)
	for i in range(enemy_number):
		await get_tree().create_timer(0.2).timeout
		if spawn_points.is_empty() == false:
			var picked_spawn =  spawn_points.pick_random()
			var pos = picked_spawn.position
			var new_instance = enemy.instantiate()
			new_instance.position = pos
			add_child(new_instance)
			enemies.append(new_instance)
			new_instance.downed.connect(_on_enemy_downed)
			spawn_points.erase(picked_spawn)
		else: 
			return
	

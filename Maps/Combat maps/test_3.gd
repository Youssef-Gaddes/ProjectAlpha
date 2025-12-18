extends Node3D

@onready var enemy: PackedScene = preload("res://entities/NPCs/enemies/enemy_1/enemy_1.tscn")
@onready var spawn_points : Array[Marker3D]
@onready var enemies: Array[CharacterBody3D] = []
@onready var player: CharacterBody3D
@export var enemy_number: int = 1
@onready var downed: Array[CharacterBody3D] = []
@export var spared:int = 0
@export var killed:int = 0
@export var total:int = 0
@export var all:bool = false
@onready var tp: Node3D = $Tp



signal done

func _ready() -> void:
	player = get_tree().get_first_node_in_group('player')
	if Stats.in_run == false:
		Stats.in_run = true
		Stats.player_health = player.max_health
	else:
		player.current_health = Stats.player_health
	spared = 0
	killed =0
	total =0
	done.connect(_verdict_done)
	

func _verdict_done():
	player.collision_shape_3d.set_deferred('disabled', false)
	tp.activate()
	Stats.player_health = player.current_health
	print('Verdict DONE')

func _add_total():
	total +=1
	if total == enemy_number:
		done.emit()


		

func _on_enemy_downed(x:CharacterBody3D):
	downed.append(x)
	Stats.beaten_enemies +=1
	if downed.size() == enemy_number:
		player._verdict_start()
func _on_enemy_killed(x:CharacterBody3D):
	if !all:
		downed.erase(x)
	killed += 1
	_add_total()
	Stats.advance_death()
func _on_enemy_spared(x:CharacterBody3D):
	if !all:
		downed.erase(x)
	spared += 1
	_add_total()
	Stats.advance_mercy()

func _kill_all():
	all = true
	for i in downed:
		killed += 1
		_add_total()
		i._transition_to(i.State.DEAD)
	downed.clear()

func _spare_all():
	all = true
	for i in downed:
		spared += 1
		_add_total()
		i._transition_to(i.State.SPARED)
	downed.clear()


func _on_enemy_spawn_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		enemy_spawn()
		$EnemySpawnArea/EntryBox.set_deferred("disabled", true)

			
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
			new_instance.scale=Vector3(3,3,3)
			new_instance.quick_jab_damage = 25.0
			new_instance.heavy_swing_damage = 35.0
			new_instance.lunge_strike_damage = 50.0
			new_instance.attack_cooldown = 3.0
			new_instance.max_health = 300.0
			add_child(new_instance)
			enemies.append(new_instance)
			new_instance.downed.connect(_on_enemy_downed)
			spawn_points.erase(picked_spawn)
		else: 
			return
	

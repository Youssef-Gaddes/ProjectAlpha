extends BaseMap

@onready var archer:PackedScene = preload("res://entities/NPCs/Background/Archer/background_archer.tscn")
@onready var training_archer:PackedScene = preload("res://entities/NPCs/Background/Archer/archer_bow.tscn")
@onready var soldier:PackedScene = preload("res://entities/NPCs/Background/Soldier/background_soldier.tscn")
@onready var hostile:PackedScene = preload("res://entities/NPCs/soldier/soldier.tscn")
@onready var elanna:PackedScene = preload('res://entities/NPCs/Main/Elena/elena.tscn')
@onready var warning_dialogue = preload("res://dialogues/Hostile/CampfireWarningKnights.dialogue")
@onready var deserter_dialogue = preload("res://dialogues/Allies/Deserter.dialogue")
func _ready() -> void:
	if not map_data:
		map_data = get_meta("map_data")
	if map_data.display_name == "Knight Campfire":
		CampfireFriendly()
	elif map_data.display_name == "Knight Campfire Hostile":
		CampfireHostile()
	elif map_data.display_name == "Deserter":
		deserter()
	super._ready()

func _check_resolution_complete() -> void:
	
	if total >= enemies.size():
		_transition_to_state(MapState.DONE)

func CampfireHostile():
	$DeserterArea/CollisionShape3D.disabled = true
	$WarningArea.body_entered.connect(_on_area_3d_body_entered)
	spawn_soldiers()
func spawn_soldiers():
	for i in $CampfireHostileSpawns.get_children():
		if i is Marker3D:
			print(i)
			var npc = hostile.instantiate()
			npc.position= i.position
			npc.rotation = i.rotation
			npc.NPC_Data.can_talk = false
			npc.NPC_Data.is_hostile = true
			enemies.append(npc)
			$CampfireHostileSpawns.add_child(npc)
			if npc.has_node("CombatModule"):
				print('YEEEEEEEEEEY')
				var combat_module = npc.Combat_Module
				# Connect downed signal
				combat_module.downed.connect(_on_enemy_downed)
				# Connect kill/spare signals (via custom signals you'll add)
				if combat_module.has_signal("enemy_killed"):
					combat_module.enemy_killed.connect(_on_enemy_killed)
				if combat_module.has_signal("enemy_spared"):
					combat_module.enemy_spared.connect(_on_enemy_spared)
			
func deserter():
	$WarningArea/CollisionShape3D.disabled = true
	$DeserterArea.body_entered.connect(_on_deserter_area_entered)
	spawn_deserter()
func spawn_deserter():
	for i in $DeserterSpawns.get_children():
		if i.get_class() == 'Marker3D':
			var anim = i.name.get_slice("_",0)
			print(anim)
			var which = i.name.get_slice("_",1)
			print(which)
			match which:
				"A":
					var npc = archer.instantiate()
					npc.position= i.position
					npc.rotation = i.rotation
					npc.scale = i.scale
					npc.idle_animation = anim
					$DeserterSpawns.add_child(npc)
				"K":
					var npc = hostile.instantiate()
					npc.position= i.position
					npc.rotation = i.rotation
					npc.scale = i.scale
					npc.idle_animation = anim
					$DeserterSpawns.add_child(npc)
				"BK":
					var npc = soldier.instantiate()
					npc.position= i.position
					npc.rotation = i.rotation
					npc.scale = i.scale
					npc.idle_animation = anim
					$DeserterSpawns.add_child(npc)
				"D":
					var npc = hostile.instantiate()
					npc.position= i.position
					npc.rotation = i.rotation
					npc.scale = i.scale
					npc.idle_animation = anim
					npc.get_node('soldier_Fight/Armature/Skeleton3D/Sword').visible = false
					npc.get_node('soldier_Fight/Armature/Skeleton3D/Shield').visible = false
					npc.get_node('soldier_Fight/Armature/Skeleton3D/Helmet').visible = false
					$DeserterSpawns.add_child(npc)

func CampfireFriendly():
	$WarningArea/CollisionShape3D.disabled = true
	$DeserterArea/CollisionShape3D.disabled = true
	spawn_friendlies()
func spawn_friendlies():
	var ellana_spawn = $EllanaSpawns.get_children().pick_random()
	var ellana_instance = elanna.instantiate()
	ellana_instance.position = ellana_spawn.position
	ellana_instance.rotation = ellana_spawn.rotation
	ellana_instance.scale = ellana_spawn.scale
	ellana_instance.idle_animation = 'Idle'
	add_child(ellana_instance)
	for i in $CampfireSpawns.get_children():
		if randf() < 0.4:
			continue 
		if i.get_class() == 'Marker3D':
			var anim = i.name.get_slice("_",0)
			print(anim)
			var which = i.name.get_slice("_",1)
			print(which)
			match which:
				"A":
					var npc = archer.instantiate()
					npc.position= i.position
					npc.rotation = i.rotation
					npc.scale = i.scale
					npc.idle_animation = anim
					$CampfireSpawns.add_child(npc)
				"AB":
					var npc = training_archer.instantiate()
					npc.position= i.position
					npc.rotation = i.rotation
					npc.scale = i.scale
					npc.idle_animation = anim
					$CampfireSpawns.add_child(npc)
				"S":
					var npc = soldier.instantiate()
					npc.position= i.position
					npc.rotation = i.rotation
					npc.scale = i.scale
					npc.idle_animation = anim
					$CampfireSpawns.add_child(npc)

func check_victory() -> bool:
	if map_data.display_name == "Knight Campfire Hostile":
		return downed.size() >= enemies.size()
	return false

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group('player'):
		DialogueManager.show_dialogue_balloon(warning_dialogue, "warning")
		$WarningArea/CollisionShape3D.disabled = true
		
func _on_deserter_area_entered(body: Node3D) -> void:
	if body.is_in_group('player'):
		DialogueManager.show_dialogue_balloon(deserter_dialogue, "start")
		$DeserterArea/CollisionShape3D.disabled = true

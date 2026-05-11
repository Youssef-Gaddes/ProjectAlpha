extends BaseMap

# ── Preloads ──────────────────────────────────────────────
@onready var preacher_scene: PackedScene = preload("res://entities/NPCs/Background/preaching_kight_priest.tscn")
@onready var knight_scene: PackedScene   = preload("res://entities/NPCs/soldier/soldier.tscn")
@onready var crowd1_scene: PackedScene   = preload("res://entities/NPCs/Background/cheeringGoofi/cheeringGoofus.tscn")
@onready var crowd2_scene: PackedScene   = preload("res://entities/NPCs/Background/cheeringGoofi/cheeringGoofus2.tscn")
@onready var execution_dialogue          = preload("res://dialogues/Allies/ExecutionKnights.dialogue")
var preacher:CharacterBody3D
# ── Node refs ─────────────────────────────────────────────
@onready var trigger: Area3D = $GallowsTrigger

# ── State ─────────────────────────────────────────────────
var preacher_instance: Node3D = null
var outcome: String = ""        # "watch" | "agree" | "convinced" | "fight"
var choice_made: bool = false
var preacher_downed: bool = false

# ── Init ──────────────────────────────────────────────────
func _ready() -> void:
	spawn_crowd()
	spawn_knights()
	spawn_preacher()
	super._ready()

func _start_exploration() -> void:
	trigger.body_entered.connect(_on_player_enters)

# ── Spawning ──────────────────────────────────────────────
func spawn_preacher() -> void:
	preacher_instance = preacher_scene.instantiate()
	preacher_instance.position = $PreacherSpawn.position
	preacher_instance.rotation = $PreacherSpawn.rotation
	preacher_instance.scale    = $PreacherSpawn.scale
	preacher_instance.idle_animation = "Preach"
	add_child(preacher_instance)
	preacher = preacher_instance

func spawn_knights() -> void:
	for marker in $SoldierSpawn.get_children():
		var npc = knight_scene.instantiate()
		npc.position            = marker.position
		npc.rotation            = marker.rotation
		npc.scale               = marker.scale
		npc.NPC_Data.can_talk   = false
		npc.idle_animation      = "Idle"
		$SoldierSpawn.add_child(npc)
		marker.queue_free()
		# Don't add to enemies yet — only if fight breaks out

func spawn_crowd() -> void:
	var anim1: Array[String] = ["Clap2", "Cheer", "Clap", "Cheer2"]
	var anim2: Array[String] = ["Clap2", "Cheer", "Clap"]
	for marker in $CrowdSpawn.get_children():
		var npc = (crowd1_scene if randf() > 0.5 else crowd2_scene).instantiate()
		npc.position           = marker.position
		npc.rotation           = marker.rotation
		npc.idle_animation     = (anim1 if npc.get_script().resource_path.contains("cheeringGoofus.tscn") else anim2).pick_random()
		$CrowdSpawn.add_child(npc)

# ── Trigger ───────────────────────────────────────────────
func _on_player_enters(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	trigger.body_entered.disconnect(_on_player_enters)
	DialogueManager.show_dialogue_balloon(execution_dialogue, "start", [self])
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

# ── Called by dialogue `do` commands ──────────────────────
func set_outcome(value: String) -> void:
	outcome = value

# ── After dialogue resolves ───────────────────────────────
func _on_dialogue_ended(_resource) -> void:
	match outcome:
		"watch", "agree":
			choice_made = true
			_transition_to_state(MapState.DONE)
		"convinced":
			choice_made = true
			_preacher_scared()
			_transition_to_state(MapState.DONE)
		"fight":
			_start_fight()

func _start_fight() -> void:
	# Clear the crowd
	for child in $CrowdSpawn.get_children():
		child.queue_free()

	# Preacher reacts
	_preacher_fall()

	# Activate soldiers as enemies
	for child in $SoldierSpawn.get_children():
		enemies.append(child)
		if child.has_node("CombatModule"):
				print('YEEEEEEEEEEY')
				var combat_module = child.Combat_Module
				combat_module.set_hostile(true)
				# Connect downed signal
				combat_module.downed.connect(_on_enemy_downed)
				# Connect kill/spare signals (via custom signals you'll add)
				if combat_module.has_signal("enemy_killed"):
					combat_module.enemy_killed.connect(_on_enemy_killed)
				if combat_module.has_signal("enemy_spared"):
					combat_module.enemy_spared.connect(_on_enemy_spared)
		child.force_enter_combat()

	_transition_to_state(MapState.COMBAT)

# ── Preacher animation helpers ────────────────────────────
func _preacher_fall() -> void:
	preacher._play_animation('Fall')
	await get_tree().create_timer(3.37).timeout
	preacher.position = preacher.position + Vector3(0,0,-2)

func _preacher_scared() -> void:
	if preacher_instance and preacher_instance.has_method("play_animation"):
		preacher_instance.play_animation("Scared")

# ── After combat: optionally kill preacher ────────────────
func _on_combat_done() -> void:
	# Expose preacher as a downable target
	if preacher_instance:
		_make_preacher_vulnerable()

func _make_preacher_vulnerable() -> void:
	# Add preacher to enemies so verdict system can target him
	if not preacher_downed:
		enemies.append(preacher_instance)
		preacher_instance.Combat_Module.downed.connect(_on_preacher_downed)
		# Force him into downed state immediately — player doesn't fight him, just judges him
		preacher_instance.Combat_Module._transition_to(preacher_instance.Combat_Module.State.DOWNED)

func _on_preacher_downed() -> void:
	preacher_downed = true
	downed.append(preacher_instance)

# ── Victory ───────────────────────────────────────────────
func check_victory() -> bool:
	if outcome == "fight":
		# Soldiers all downed — then preacher phase begins
		var soldiers_done = downed.size() + (killed + spared) >= enemies.size()
		return soldiers_done
	return choice_made

func _check_resolution_complete() -> void:
	# Called after each kill/spare
	# If preacher was made vulnerable, total includes him
	if total >= enemies.size():
		_transition_to_state(MapState.DONE)

# ── Consequences ──────────────────────────────────────────
func _calculate_faction_opinions() -> Dictionary:
	match outcome:
		"watch":    return {"knights": -5}
		"agree":    return {"knights": 15}
		"convinced": return {"knights": -20}
		"fight":
			return {"knights": -30 if killed > spared else -15}
	return {}

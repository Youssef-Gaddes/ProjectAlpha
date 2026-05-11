extends Node

func _ready() -> void:
	RunManager.load_scene.connect(_on_load_scene)

func _on_load_scene(scene_path: String, script: Script, map_data: MapData) -> void:
	# Defer everything since we're inside a physics/signal callback
	call_deferred("_do_load_scene", scene_path, script, map_data)

func _do_load_scene(scene_path: String, script: Script, map_data: MapData) -> void:
	if get_child_count() > 0:
		get_child(0).queue_free()
		await get_tree().process_frame  # wait for free to complete

	var map_scene = load(scene_path)
	var map_instance = map_scene.instantiate()

	if script:
		map_instance.set_script(script)

	# Set map_data BEFORE add_child so it's available in _ready()
	map_instance.set_meta("map_data", map_data)
	map_instance.map_data = map_data

	add_child(map_instance)
	map_instance.map_completed.connect(RunManager._on_map_completed)

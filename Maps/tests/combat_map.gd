extends Node

func _ready() -> void:
	# Skip start_new_run() to avoid scene loading
	Stats.start_new_run()
	var run = RunManager._generate_run()
	
	print("=== RUN LAYOUT ===")
	for i in range(run.size()):
		var m = run[i]
		print("[%02d] %s | zone: %s | weight: %s" % [i, m.map_id, m.primary_category, m.emotional_weight])
	
	# Validate no dupes exceed max_per_run
	var counts = {}
	for m in run:
		counts[m.map_id] = counts.get(m.map_id, 0) + 1
	for id in counts:
		var map = RunManager._get_map_by_id(id)
		if map.max_per_run > 0 and counts[id] > map.max_per_run:
			print("VIOLATION: %s appears %d times, max is %d" % [id, counts[id], map.max_per_run])

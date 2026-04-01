extends BaseMap
@onready var spirit_spawn: Marker3D = $SpiritSpawnPoint/Marker3D
@onready var spirit_scene: PackedScene = preload("res://entities/NPCs/Spirits/spirit.tscn")

func _ready() -> void:
	if not map_data:
		map_data = get_meta("map_data")
	var spirit = spirit_scene.instantiate()
	spirit.position = spirit_spawn.position
	add_child(spirit)
	super._ready()

func check_victory() -> bool:
	return false

extends Camera3D

@export var target: Node3D
@export var offset: Vector3 = Vector3(0, 7, 5)
@export var smooth_speed: float = 20

func _process(_delta):
	if target:
		var desired = target.global_position + offset
		global_position = desired
		look_at(target.global_position, Vector3.UP)

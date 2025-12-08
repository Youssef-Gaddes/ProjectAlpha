extends Camera3D

@export var target: Node3D
@export var offset: Vector3 = Vector3(0, 7, 5)
@export var smooth_speed: float = 20

@export var period = 0.025
@export var magnitude = 0.06

var shaking:bool = false

func _process(_delta):
	if target and !shaking:
		var desired = target.global_position + offset
		global_position = desired
		look_at(target.global_position, Vector3.UP)
		fov = 75
	if shaking:
		fov = 76
		
		
func _camera_shake():
	shaking = true
	var initial_transform = self.transform 
	var elapsed_time = 0.0

	while elapsed_time < period:
		var offfset = Vector3(
			randf_range(-magnitude, magnitude),
			randf_range(-magnitude, magnitude),
			0.0
		)

		self.transform.origin = initial_transform.origin + offfset
		elapsed_time += get_process_delta_time()
		await get_tree().process_frame
	shaking = false
	self.transform = initial_transform

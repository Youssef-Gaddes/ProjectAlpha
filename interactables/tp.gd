extends Node3D
@onready var tp_area: Area3D = $TpArea
@export var where: String

func _ready() -> void:
	$pasted__pCylinder1/polySurface1/polySurface1_lambert2_0.set_deferred("visible", false)
	$TpArea.set_deferred("monitoring", false)

func activate():
	$pasted__pCylinder1/polySurface1/polySurface1_lambert2_0.set_deferred("visible", true)
	$TpArea.set_deferred("monitoring", true)
	print('INDEED')




func _on_tp_area_body_entered(body: Node3D) -> void:
	if body.is_in_group('player'):
		match where:
			"new_run":
				RunManager.start_new_run()
			"next_node":
				print('lol')
				RunManager.advance_node()
			_:
				push_error("TP has no 'where' value set: " % name)

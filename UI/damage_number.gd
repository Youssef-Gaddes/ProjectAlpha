extends Sprite3D

@onready var entity: CharacterBody3D = get_parent()
@onready var label: Label = $SubViewport/Label
@export var time: float = 0.5
var total: int = 0
var active: bool = false

func _ready() -> void:
	visible = false
	label.text = ""
	active = false



func display_dmg(dmg: int):
	if dmg != total:
		if scale < Vector3(0.45,0.45,0.45):
			var tween = create_tween()
			tween.tween_property(self, "scale", Vector3(0.45,0.45,0.45).min(scale*1.1), 0.3)
		else:
			scale = Vector3(0.45,0.45,0.45)
	else:
		scale = Vector3(0.2,0.2,0.2)
	active = true
	total += dmg
	label.text = str(total)
	visible = true
	$Timer.start()
	
	
func _on_timer_timeout() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.05,0.05,0.05), 0.3)
	await get_tree().create_timer(0.4).timeout
	scale = Vector3(0.2,0.2,0.2)
	visible = false
	label.text = ""
	active = false
	total = 0

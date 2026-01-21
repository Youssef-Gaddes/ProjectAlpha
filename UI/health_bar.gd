extends Sprite3D

@onready var health_bar: ProgressBar = $SubViewport/healthBar
@onready var timer: Timer = $SubViewport/healthBar/Timer
@onready var damage_bar: ProgressBar = $SubViewport/healthBar/damageBar
@onready var entity: CharacterBody3D = get_parent().get_parent()
var dmg: int = 0

var health = 0

func _ready() -> void:
	if entity.NPC_Data.is_hostile == false:
		var new_stylebox_normal = health_bar.get_theme_stylebox("fill").duplicate()
		new_stylebox_normal.bg_color = Color.LIME_GREEN
		health_bar.add_theme_stylebox_override("fill", new_stylebox_normal)
	health = entity.NPC_Data.max_health
	health_bar.max_value = health
	health_bar.value = health
	damage_bar.max_value = health
	damage_bar.value = health
func set_health(amount):
	timer.start()
	health_bar.value -= amount
	dmg += amount
	if health_bar.value <= 0:
		await get_tree().create_timer(1).timeout
		queue_free()

func _on_timer_timeout() -> void:
	damage_bar.value -= dmg
	dmg = 0

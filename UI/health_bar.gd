extends Sprite3D

@onready var health_bar: ProgressBar = $SubViewport/healthBar
@onready var timer: Timer = $SubViewport/healthBar/Timer
@onready var damage_bar: ProgressBar = $SubViewport/healthBar/damageBar
@onready var entity: CharacterBody3D = get_parent()
var dmg: int = 0

var health = 0

func _ready() -> void:
	health = entity.max_health
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

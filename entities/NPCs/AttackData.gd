# attack_data.gd
class_name AttackData
extends Resource

@export var attack_name: String = "Quick Jab"
@export var animation_name: String = "Attack1"

@export_group("Range & Timing")
@export var min_range: float = 0.0
@export var max_range: float = 2.0
@export var attack_cooldown: float = 0.5

@export_group("Damage")
@export var damage: float = 10.0

@export_group("Hitbox")
@export var hitbox_size: Vector3 = Vector3(2.44, 1.77, 1.27)
@export var hitbox_position: Vector3 = Vector3(0.01, 0.88, 1.43)

@export_group("Movement")
@export var has_lunge: bool = false
@export var lunge_speed: float = 8.0

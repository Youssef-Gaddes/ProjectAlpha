extends CanvasLayer
@onready var health_bar: ProgressBar = $Control/MarginContainer/ProgressBar
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player")

func _ready() -> void:
	health_bar.max_value = player.max_health
	health_bar.value = player.current_health
func _process(_delta: float) -> void:
	health_bar.value = player.current_health
	

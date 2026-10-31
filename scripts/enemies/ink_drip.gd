class_name InkDrip
extends Hitbox
## A falling drop of runny ink (from the Sogg's creatures). Splashes on the ground.

@export var fall_speed := 520.0
@export var floor_y := 900.0


func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta
	if position.y >= floor_y:
		active = false
		set_physics_process(false)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2(1.8, 0.2), 0.12)
		tween.tween_property(self, "modulate:a", 0.0, 0.2)
		tween.tween_callback(queue_free)

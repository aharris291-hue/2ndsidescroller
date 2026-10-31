class_name SlamBreakable
extends StaticBody2D
## A block of ice paper that only a Pop-Up Slam can crack (Chapter 3). Works on standing
## and flat pages. Once broken it stays broken, even after loading a save.

@export var break_radius := 210.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group(&"slam_listeners")
	if GameState.is_collected(_unique_id()):
		queue_free()


func on_slam(at: Vector2, _view: PageView.Mode) -> void:
	if at.distance_to(global_position) <= break_radius:
		shatter()


func shatter() -> void:
	if not is_in_group(&"slam_listeners"):
		return
	remove_from_group(&"slam_listeners")
	GameState.mark_collected(_unique_id())
	AudioManager.play_sfx(&"enemy_pop", 1.4)
	for shape in get_children():
		if shape is CollisionShape2D:
			shape.set_deferred("disabled", true)
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "scale", _sprite.scale * Vector2(1.3, 0.2), 0.25)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)


func _unique_id() -> String:
	return "%s:%s" % [owner.scene_file_path if owner else "", get_path()]

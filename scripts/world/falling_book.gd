class_name FallingBook
extends Hitbox
## One falling book (see BookFall). Hurts while falling; lands on the first floor
## below it, settles and fades.

const BOOK := preload("res://assets/art/dark/props/book.png")

var _speed := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	damage = 2
	knockback = 380.0
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	_sprite = Sprite2D.new()
	_sprite.texture = BOOK
	_sprite.rotation = randf_range(-0.5, 0.5)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 44)
	shape.shape = rect
	add_child(shape)


func _physics_process(delta: float) -> void:
	_speed = minf(_speed + 2300.0 * delta, 1400.0)
	var step := _speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 26 + step), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit:
		global_position.y = hit.position.y - 24.0
		_land()
		return
	position.y += step
	_sprite.rotation += delta * 3.0


func _land() -> void:
	active = false
	set_physics_process(false)
	AudioManager.play_sfx(&"enemy_pop", randf_range(0.45, 0.6), -4.0)
	var tween := create_tween()
	tween.tween_property(_sprite, "rotation", 0.0, 0.08)
	tween.tween_interval(1.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)

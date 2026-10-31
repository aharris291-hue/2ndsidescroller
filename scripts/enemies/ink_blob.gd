class_name InkBlob
extends Hitbox
## A gob of ink thrown by an Ink Spitter. Flies in an arc (straight on a flat page),
## splats on walls, floors and Patch, and a swipe knocks it out of the air.

@export var fall_gravity := 1500.0
@export var life := 3.0

var velocity := Vector2.ZERO
var use_gravity := true
var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if use_gravity:
		velocity.y += fall_gravity * delta
	position += velocity * delta
	rotation = velocity.angle()
	life -= delta
	if life <= 0.0:
		_splat(0.0)


func _on_body_entered(body: Node2D) -> void:
	# Give Patch's hurtbox a moment to register the hit before the splat.
	_splat(0.06 if body is Patch else 0.0)


func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox and area.owner is Patch:
		AudioManager.play_sfx(&"enemy_pop", 1.4)
		active = false
		_splat(0.0)


func _splat(delay: float) -> void:
	if _done:
		return
	_done = true
	if delay > 0.0:
		await get_tree().create_timer(delay, false, true).timeout
	active = false
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.8, 0.3), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)

class_name BarkerCard
extends Node2D
## One of the Barker's playing cards (the Knife-Thrower act), thrown flat and straight.
## A red card can't be guarded: get out of its way. The white card can: parried, it
## spins back the way it came and cuts the Barker open (BossBarker.card_returned).
## The card holds its Hitbox, so a parry (Patch looks at the hitbox's owner) lands here.

var velocity := Vector2.ZERO
var parryable := false
var thrower: Node2D
var hitbox: Hitbox
var life := 2.6
var returning := false
var _face: Polygon2D


func _ready() -> void:
	add_to_group(&"barker_cards")
	var back := Polygon2D.new()
	back.polygon = PackedVector2Array([Vector2(-26, -36), Vector2(26, -36), Vector2(26, 36), Vector2(-26, 36)])
	back.color = Color(0.12, 0.09, 0.08)
	add_child(back)
	_face = Polygon2D.new()
	_face.polygon = PackedVector2Array([Vector2(-23, -33), Vector2(23, -33), Vector2(23, 33), Vector2(-23, 33)])
	_face.color = Color(0.93, 0.9, 0.82) if parryable else Color(0.62, 0.1, 0.09)
	add_child(_face)
	var pip := Polygon2D.new()
	pip.polygon = PackedVector2Array([Vector2(0, -14), Vector2(10, 0), Vector2(0, 14), Vector2(-10, 0)])
	pip.color = Color(0.62, 0.1, 0.09) if parryable else Color(0.93, 0.9, 0.82)
	add_child(pip)
	hitbox = Hitbox.new()
	hitbox.collision_layer = 16
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.damage = 1
	hitbox.knockback = 420.0
	hitbox.unblockable = not parryable
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56, 56)
	shape.shape = rect
	hitbox.add_child(shape)
	add_child(hitbox)
	hitbox.owner = self


func _physics_process(delta: float) -> void:
	if returning and is_instance_valid(thrower):
		var target := thrower.global_position + Vector2(0, -300)
		velocity = (target - global_position).normalized() * 1300.0
		if global_position.distance_to(target) < 70.0:
			if thrower.has_method("card_returned"):
				thrower.card_returned()
			queue_free()
			return
	global_position += velocity * delta
	rotation += (22.0 if returning else 14.0) * delta
	life -= delta
	if life <= 0.0:
		queue_free()


## Patch parried it: it goes back to the hand that threw it.
func on_parried(_by: Node) -> void:
	if returning:
		return
	returning = true
	life = 2.0
	hitbox.active = false
	_face.color = Color(0.75, 0.9, 1.3)

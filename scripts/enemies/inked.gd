class_name Inked
extends RefCounted
## Inked elites: any enemy with `inked = true` has soaked up the flood's ink. It's
## darker (a deep indigo stain over its painting), half again as tough, quicker to
## attack (every wind-up and cooldown is a quarter shorter), and when it dies it
## bursts into a pool of ink that hurts to stand in for a few seconds.

const TINT := Color(0.52, 0.48, 0.64)
const TOUGHER := 1.5
const QUICKER := 0.75
## Timing exports that get shorter, on whichever enemy has them.
const TIMINGS: Array[StringName] = [&"windup", &"windup_time", &"fire_interval",
	&"lunge_cooldown", &"dart_interval", &"dive_interval", &"hover_time"]
const POOL_TIME := 3.5


static func apply(enemy: Node2D) -> void:
	enemy.add_to_group(&"inked")
	var sprite := enemy.get_node_or_null(^"Sprite2D") as CanvasItem
	if sprite:
		# self_modulate, so the hit flashes (which tween modulate) don't wash it out.
		sprite.self_modulate = TINT
	var health := enemy.get(&"health") as HealthComponent
	if health:
		health.max_health = ceili(health.max_health * TOUGHER)
		health.current = health.max_health
	for timing in TIMINGS:
		var value: Variant = enemy.get(timing)
		if value is float:
			enemy.set(timing, value * QUICKER)
	if &"tempo" in enemy:
		enemy.set(&"tempo", QUICKER)
	_drips(enemy)


## A few slow black drops falling off it, so an elite reads at a glance.
static func _drips(enemy: Node2D) -> void:
	var drips := CPUParticles2D.new()
	drips.name = &"InkDrips"
	drips.amount = 6
	drips.lifetime = 0.9
	drips.position = Vector2(0, -40)
	drips.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drips.emission_rect_extents = Vector2(30, 20)
	drips.gravity = Vector2(0, 500)
	drips.initial_velocity_min = 0.0
	drips.initial_velocity_max = 10.0
	drips.scale_amount_min = 3.0
	drips.scale_amount_max = 5.0
	drips.color = Color(0.06, 0.05, 0.1, 0.9)
	drips.add_to_group(&"vfx")
	enemy.add_child(drips)


## Leaves a pool of ink where it died.
static func on_died(enemy: Node2D) -> void:
	var pool := Hitbox.new()
	pool.name = &"InkPool"
	pool.damage = 1
	pool.knockback = 300.0
	pool.collision_layer = 16
	pool.collision_mask = 0
	pool.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150, 24)
	shape.shape = rect
	shape.position = Vector2(0, -12)
	pool.add_child(shape)
	var look := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 16:
		var a := i * TAU / 16.0
		points.append(Vector2(cos(a) * 80.0, sin(a) * 12.0 - 4.0))
	look.polygon = points
	look.color = Color(0.05, 0.04, 0.09, 0.92)
	look.add_to_group(&"vfx")
	pool.add_child(look)
	pool.global_position = enemy.global_position
	pool.ready.connect(func() -> void:
		var tween := pool.create_tween()
		tween.tween_interval(POOL_TIME)
		tween.tween_callback(func() -> void: pool.active = false)
		tween.tween_property(look, "modulate:a", 0.0, 0.6)
		tween.tween_callback(pool.queue_free))
	enemy.get_parent().add_child.call_deferred(pool)

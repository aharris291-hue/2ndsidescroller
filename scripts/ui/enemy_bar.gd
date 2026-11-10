class_name EnemyBar
extends Node2D
## A small PaperBar over an ordinary enemy's head. Hidden until the enemy is first
## hurt, then fades out a few seconds after the last hit, and goes with it when it
## dies. Bosses use the big bar on the HUD instead (HealthComponent skips them).

const WIDTH := 112.0
const HEIGHT := 16.0
## Seconds the bar stays after a hit before it fades.
const LINGER := 3.0

var health: HealthComponent
var _bar: PaperBar
var _left := 0.0


## Puts a bar over `body`, just above the top of its first collision shape.
static func attach(body: Node2D, component: HealthComponent) -> EnemyBar:
	var bar := EnemyBar.new()
	bar.health = component
	bar.position = Vector2(0, _top_of(body) - 22.0)
	body.add_child.call_deferred(bar)
	return bar


static func _top_of(body: Node2D) -> float:
	for child in body.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape:
			var shape := child as CollisionShape2D
			return shape.position.y + shape.shape.get_rect().position.y * shape.scale.y
	return -110.0


func _ready() -> void:
	add_to_group(&"vfx")
	z_index = 20
	modulate.a = 0.0
	_bar = PaperBar.new()
	_bar.size = Vector2(WIDTH, HEIGHT)
	_bar.position = Vector2(-WIDTH / 2.0, -HEIGHT)
	_bar.rag = 2.0
	_bar.max_value = health.max_health
	_bar.segment = 1.0 if health.max_health <= 12 else 0.0
	_bar.set_value(health.current, true)
	add_child(_bar)
	health.changed.connect(_on_changed)
	health.died.connect(queue_free)


func _on_changed(current: int, maximum: int) -> void:
	_bar.max_value = maximum
	_bar.set_value(current)
	_left = LINGER
	modulate.a = 1.0


func _process(delta: float) -> void:
	# Stay upright and unmirrored when the enemy turns round.
	var parent_scale := (get_parent() as Node2D).global_scale if get_parent() is Node2D else Vector2.ONE
	scale = Vector2(signf(parent_scale.x), 1.0) if parent_scale.x != 0.0 else Vector2.ONE
	if _left > 0.0:
		_left -= delta
		if _left <= 0.6:
			modulate.a = maxf(_left / 0.6, 0.0)

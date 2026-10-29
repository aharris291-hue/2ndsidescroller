class_name RisingWater
extends Hitbox
## Floodwater that rises up the page (Prologue). It's a Hitbox, so Patch takes damage
## while he's in it; staying in too long tears him and sends him back to a bookmark.
## Its shape and art are sized from `width` in _ready.

@export var width := 1920.0
@export var rise_speed := 38.0
## The water stops rising here (page y coordinate).
@export var stop_y := 200.0
@export var start_delay := 2.5

var _delay_left := 0.0

@onready var surface: Sprite2D = $Surface
@onready var body: ColorRect = $Body
@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_delay_left = start_delay
	surface.region_enabled = true
	surface.region_rect = Rect2(0, 0, width, 128)
	surface.centered = false
	surface.position = Vector2(0, -40)
	body.position = Vector2(0, 80)
	body.size = Vector2(width, 2400)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 2400)
	shape.shape = rect
	shape.position = Vector2(width / 2.0, 1200 + 20)


func _physics_process(delta: float) -> void:
	# The flood politely waits while anyone is talking.
	if DialogueUI.is_active():
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	if position.y > stop_y:
		position.y = maxf(position.y - rise_speed * delta, stop_y)

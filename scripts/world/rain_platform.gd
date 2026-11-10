class_name RainPlatform
extends StaticBody2D
## A ledge the rain writes onto the blank paper of the Margins (a one-way board). Dry,
## it's only a faint grey outline, to read where it will be; as the shower gathers the
## outline darkens; while it pours the board is there in wet ink and holds Patch; it
## flickers when the rain is about to ease, and then it's gone.
##
## Its top is at its origin (like a plank on the row below the map cell it is drawn in).

const TEX := preload("res://assets/art/dark/props/rain_ledge.png")
## The board in the art is this wide, with its top this far down the image.
const ART_BOARD := 192.0
const ART_TOP := 10.0

@export var width := 192.0

var solid := false
var shower: RainShower
var _shape: CollisionShape2D
var _sprite: Sprite2D
var _outline: Line2D


func _ready() -> void:
	add_to_group(&"rain_platforms")
	# Never respawn Patch onto one: the rain may have stopped by then.
	add_to_group(&"unsafe_floor")
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 16)
	_shape.shape = rect
	_shape.position = Vector2(0, 8)
	_shape.one_way_collision = true
	_shape.disabled = true
	add_child(_shape)
	_outline = Line2D.new()
	_outline.width = 4.0
	_outline.default_color = Color(0.86, 0.88, 0.96, 0.45)
	var w := width / 2.0
	_outline.points = PackedVector2Array([Vector2(-w, 14), Vector2(-w, 0), Vector2(w, 0), Vector2(w, 14)])
	add_child(_outline)
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.scale = Vector2(width / ART_BOARD, 1.0)
	_sprite.position = Vector2(0, TEX.get_height() * 0.5 - ART_TOP)
	_sprite.modulate.a = 0.0
	add_child(_sprite)
	_find_shower.call_deferred()


func _find_shower() -> void:
	shower = get_tree().get_first_node_in_group(&"rain_showers") as RainShower
	if shower:
		shower.changed.connect(_on_changed)
		_on_changed(shower.state)


func _physics_process(_delta: float) -> void:
	if solid and shower and shower.easing:
		_sprite.modulate.a = 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.02))


func _on_changed(state: StringName) -> void:
	set_solid(state == &"pouring")
	_outline.default_color.a = 0.95 if state == &"gathering" else 0.45


func set_solid(on: bool) -> void:
	solid = on
	_shape.set_deferred("disabled", not on)
	var fade := create_tween()
	fade.tween_property(_sprite, "modulate:a", 1.0 if on else 0.0, 0.15 if on else 0.3)
	_outline.visible = not on

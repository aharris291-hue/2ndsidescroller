class_name PopGhoul
extends Node2D
## A ghost train scare (Gatefold Fair, 5-4): a paper ghoul on a spring, down under the
## rail in the dark. When something comes along the track it rattles and its eyes
## light (the tell), then it springs up across the rail, claws out, and sinks back. It
## can't be guarded or cut: jump it. Stands on the rail's line (where a rider's feet
## are); 'g' in a map, on the row above the ghost train's '_'.

const ART := preload("res://assets/art/dark/enemies/pop_ghoul.png")

@export var trigger_range := 330.0
@export var tell_time := 0.38
@export var up_time := 0.55
@export var cooldown := 1.4
## How far below the rail it hides.
@export var hide_depth := 250.0

enum State { DOWN, TELL, UP, SINKING }

var state := State.DOWN
var hitbox: Hitbox
var sprite: Sprite2D
var _left := 0.0
var _cool := 0.0
var _tween: Tween


func _ready() -> void:
	add_to_group(&"pop_ghouls")
	sprite = Sprite2D.new()
	sprite.texture = ART
	sprite.offset = Vector2(0, -ART.get_height() / 2.0)
	sprite.position = Vector2(0, hide_depth)
	sprite.modulate = Color(0.6, 0.6, 0.65, 0.0)
	add_child(sprite)
	hitbox = Hitbox.new()
	hitbox.collision_layer = 16
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.damage = 1
	hitbox.knockback = 520.0
	hitbox.unblockable = true
	hitbox.active = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(84, 84)
	shape.shape = rect
	shape.position = Vector2(-10, -42)
	hitbox.add_child(shape)
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	_cool -= delta
	_left -= delta
	match state:
		State.DOWN:
			if _cool <= 0.0 and _someone_coming():
				_tell()
		State.TELL:
			if _left <= 0.0:
				_spring()
		State.UP:
			if _left <= 0.0:
				_sink()


func _someone_coming() -> bool:
	var patch := get_tree().get_first_node_in_group(&"player") as Node2D
	if patch == null:
		return false
	var d := patch.global_position - global_position
	return absf(d.x) < trigger_range and d.y > -420.0 and d.y < 60.0


func _tell() -> void:
	state = State.TELL
	_left = tell_time
	AudioManager.play_sfx(&"tab_pull", 1.6, -6.0)
	_kill()
	_tween = create_tween()
	_tween.tween_property(sprite, "position:y", hide_depth * 0.55, tell_time).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(sprite, "modulate", Color(1.3, 0.55, 0.5, 0.8), tell_time)


func _spring() -> void:
	state = State.UP
	_left = up_time
	hitbox.active = true
	AudioManager.play_sfx(&"swipe", 0.6)
	_kill()
	_tween = create_tween()
	_tween.tween_property(sprite, "position:y", 20.0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(sprite, "modulate", Color(0.95, 0.9, 0.9, 1.0), 0.1)
	_tween.tween_property(sprite, "rotation", -0.08, up_time * 0.5)
	_tween.tween_property(sprite, "rotation", 0.04, up_time * 0.5)


func _sink() -> void:
	state = State.SINKING
	hitbox.active = false
	_kill()
	_tween = create_tween()
	_tween.tween_property(sprite, "position:y", hide_depth, 0.4).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(sprite, "modulate", Color(0.6, 0.6, 0.65, 0.0), 0.4)
	_tween.parallel().tween_property(sprite, "rotation", 0.0, 0.4)
	_tween.tween_callback(func() -> void:
		state = State.DOWN
		_cool = cooldown)


func _kill() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

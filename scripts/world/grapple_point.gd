class_name GrapplePoint
extends Node2D
## A brass ring the Tape Tail sticks to (Chapter 2 onward).
## ZIP rings reel Patch in: over gaps, across water, up to ledges.
## YANK rings are pulled instead: they slide a target (like a pull-tab Patch can't
## reach) and emit `yanked` for scripts such as the Blotch Kraken's blotters.

signal yanked

enum Mode { ZIP, YANK }

@export var mode := Mode.ZIP
## ZIP: where Patch ends up, relative to the ring.
@export var land_offset := Vector2(0, 40)
## YANK: the node slid by move_offset (optional).
@export var target: Node2D
@export var move_offset := Vector2(0, -320)
@export var duration := 0.7
## YANK: a used ring can't be yanked again until reset().
@export var one_shot := true
@export var enabled := true

var used := false
var highlighted := false

var _time := randf() * TAU
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	add_to_group(&"grapple_points")


func _process(delta: float) -> void:
	if sprite == null:
		return
	_time += delta * 6.0
	# A gentle pulse marks the ring the Tape Tail would hit.
	var pulse := 1.0 + (sin(_time) * 0.08 + 0.12 if highlighted else 0.0)
	sprite.scale = Vector2(pulse, pulse)
	sprite.modulate = Color(1.3, 1.25, 1.0) if highlighted else (Color(0.6, 0.6, 0.6, 0.7) if not can_grapple() else Color.WHITE)


func can_grapple() -> bool:
	return enabled and not (mode == Mode.YANK and one_shot and used)


func yank() -> void:
	used = true
	AudioManager.play_sfx(&"tab_pull", 1.25)
	if target:
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(target, "position", target.position + move_offset, duration)
	yanked.emit()


func reset() -> void:
	used = false

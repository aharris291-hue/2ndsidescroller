class_name FoldMark
extends Node2D
## A printed fold line on a standing page with a pop-up folded flat behind it (Chapter 3).
## A Pop-Up Slam close by springs the pop-up: a paper peak rises out of the ground,
## carrying anything standing on it. Peaks stay up, or fold away after stay_up_time.
##
## Expected children: "Peak", an AnimatableBody2D whose origin is its flat top, with a
## Sprite2D (region-enabled, so only the part above ground is drawn) and a collision
## shape hanging down from the top.

signal popped

@export var rise_height := 256.0
## How close (horizontally) a slam must land to spring this fold.
@export var trigger_radius := 220.0
## Seconds before the peak folds away again (0 = it stays up).
@export var stay_up_time := 0.0
@export var pop_time := 0.3
## Bindwell's pattern folds (4-3): a slam flips this fold (up folds down, down folds
## up) instead of only springing it, and flips every fold whose `tag` is in `chain`
## too. `start_up` has it standing when the page loads.
@export var toggle := false
@export var tag := ""
@export var chain: PackedStringArray = []
@export var start_up := false

var is_up := false
var _busy := false

@onready var peak: AnimatableBody2D = $Peak
@onready var _art: Sprite2D = $Peak/Sprite2D
@onready var _shape: CollisionShape2D = $Peak/CollisionShape2D


func _ready() -> void:
	add_to_group(&"slam_listeners")
	add_to_group(&"fold_marks")
	# The peak's collision hangs down from its top as deep as it rises.
	var rect := _shape.shape as RectangleShape2D
	if rect and not is_equal_approx(rect.size.y, rise_height):
		rect = rect.duplicate() as RectangleShape2D
		rect.size.y = rise_height
		_shape.shape = rect
		_shape.position.y = rise_height / 2.0
	# Taller peaks stretch the paper art so the whole pop-up shows.
	var art_h := _art.texture.get_height() * _art.scale.y
	if rise_height > art_h:
		_art.scale.y = rise_height / _art.texture.get_height()
	peak.position = Vector2.ZERO
	# Folded flat, the peak is nothing at all: it only becomes solid as it rises.
	_shape.disabled = true
	if start_up:
		peak.position.y = -rise_height
		_shape.disabled = false
		is_up = true
	_update_art()


func _process(_delta: float) -> void:
	_update_art()


func on_slam(at: Vector2, view: PageView.Mode) -> void:
	if view != PageView.Mode.SIDE:
		return
	if absf(at.x - global_position.x) <= trigger_radius and absf(at.y - global_position.y) <= 260.0:
		if not toggle:
			pop()
			return
		flip()
		for other in get_tree().get_nodes_in_group(&"fold_marks"):
			if other != self and other.tag != "" and chain.has(other.tag):
				other.flip()


## Up folds down, down folds up (pattern folds).
func flip() -> void:
	if is_up:
		fold_away()
	else:
		pop()


func pop() -> void:
	if is_up or _busy:
		return
	_busy = true
	_shape.disabled = false
	AudioManager.play_sfx(&"tab_pull", 0.8)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Physics-synced so Patch rides up on top of it.
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(peak, "position:y", -rise_height, pop_time)
	await tween.finished
	is_up = true
	_busy = false
	popped.emit()
	if stay_up_time > 0.0:
		await get_tree().create_timer(stay_up_time, false, true).timeout
		fold_away()


func fold_away() -> void:
	if not is_up or _busy:
		return
	_busy = true
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(peak, "position:y", 0.0, 0.5)
	await tween.finished
	_shape.disabled = true
	is_up = false
	_busy = false


func _update_art() -> void:
	# Only the part of the peak above the ground is drawn.
	var shown := maxf(-peak.position.y, 0.0) / maxf(_art.scale.y, 0.01)
	_art.visible = shown > 1.0
	_art.region_rect = Rect2(0, 0, _art.texture.get_width(), minf(shown, _art.texture.get_height()))

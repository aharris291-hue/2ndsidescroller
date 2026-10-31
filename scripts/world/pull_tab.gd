class_name PullTab
extends Interactable
## A pop-up book pull-tab. Pulling it slides a target node (usually an AnimatableBody2D
## platform) by move_offset; pulling again slides it back unless one_shot is set.
## A tab without a target just emits toggled, for scripts to react to (windmills, bosses).

signal toggled(is_pulled: bool)

@export var target: Node2D
@export var move_offset := Vector2(0, -320)
@export var duration := 0.9
@export var one_shot := false

var is_pulled := false
var _start_position := Vector2.ZERO
var _tab_start := Vector2.ZERO
var _busy := false

@onready var _tab_sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	prompt_text = "Pull"
	super._ready()
	_tab_start = _tab_sprite.position
	if target:
		_start_position = target.position


func can_interact() -> bool:
	return not _busy and not (one_shot and is_pulled)


func interact(_player: Patch) -> void:
	AudioManager.play_sfx(&"tab_pull", randf_range(0.9, 1.1))
	await _slide(not is_pulled)


## Slides the tab (and its target) back to the start, e.g. when a boss shakes them loose.
func reset() -> void:
	if is_pulled and not _busy:
		await _slide(false)


func _slide(pulled: bool) -> void:
	is_pulled = pulled
	_busy = true
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Physics-synced so anything standing on the platform rides along.
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_tab_sprite, "position", _tab_start + (Vector2(36, 0) if pulled else Vector2.ZERO), duration * 0.4)
	if target:
		tween.parallel().tween_property(target, "position", _start_position + (move_offset if pulled else Vector2.ZERO), duration)
	await tween.finished
	_busy = false
	toggled.emit(is_pulled)

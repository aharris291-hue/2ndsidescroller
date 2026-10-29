class_name PullTab
extends Interactable
## A pop-up book pull-tab. Pulling it slides a target node (usually an AnimatableBody2D
## platform) by move_offset; pulling again slides it back unless one_shot is set.

signal toggled(is_pulled: bool)

@export var target: Node2D
@export var move_offset := Vector2(0, -320)
@export var duration := 0.9
@export var one_shot := false

var is_pulled := false
var _start_position := Vector2.ZERO
var _busy := false

@onready var _tab_sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	prompt_text = "Pull"
	super._ready()
	if target:
		_start_position = target.position


func can_interact() -> bool:
	return target != null and not _busy and not (one_shot and is_pulled)


func interact(_player: Patch) -> void:
	is_pulled = not is_pulled
	_busy = true
	AudioManager.play_sfx(&"tab_pull", randf_range(0.9, 1.1))
	var destination := _start_position + (move_offset if is_pulled else Vector2.ZERO)
	var tab_shift := Vector2(36, 0) if is_pulled else Vector2.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Physics-synced so anything standing on the platform rides along.
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(target, "position", destination, duration)
	tween.parallel().tween_property(_tab_sprite, "position", tab_shift, duration * 0.4)
	await tween.finished
	_busy = false
	toggled.emit(is_pulled)

class_name HoldComponent
extends Node
## How well an enemy is holding together. Heavy hits, charged hits, Plunges and
## parries wear Hold down; when it breaks the enemy staggers and a frayed seam shows,
## and a heavy attack in that window Unstitches it (Patch's finisher).
## Hold refills on its own after a few seconds without being hit.

signal broken
signal recovered
signal changed(current: float, maximum: float)

@export var max_hold := 4.0
## Seconds the enemy stays staggered (open to an Unstitch) once Hold breaks.
@export var stagger_time := 2.0
## Hold starts refilling this long after the last hit, at regen_rate per second.
@export var regen_delay := 2.5
@export var regen_rate := 1.5

var current := 0.0
var _stagger_left := 0.0
var _since_hit := 0.0


func _ready() -> void:
	current = max_hold


func _physics_process(delta: float) -> void:
	if _stagger_left > 0.0:
		_stagger_left -= delta
		if _stagger_left <= 0.0:
			current = max_hold
			if owner:
				owner.remove_from_group(&"staggered")
			changed.emit(current, max_hold)
			recovered.emit()
		return
	_since_hit += delta
	if _since_hit > regen_delay and current < max_hold:
		current = minf(current + regen_rate * delta, max_hold)
		changed.emit(current, max_hold)


func is_broken() -> bool:
	return _stagger_left > 0.0


func take_hold(amount: float) -> void:
	if amount <= 0.0 or is_broken():
		return
	_since_hit = 0.0
	current = maxf(current - amount, 0.0)
	changed.emit(current, max_hold)
	if current <= 0.0:
		_stagger_left = stagger_time
		if owner:
			owner.add_to_group(&"staggered")
		broken.emit()


## Called when the enemy is finished off, so it stops counting as staggered.
func clear() -> void:
	_stagger_left = 0.0
	if owner:
		owner.remove_from_group(&"staggered")

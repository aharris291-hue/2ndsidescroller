extends Node
## Game-feel time effects: hitstop (a tiny freeze on impact) and slow motion
## (a perfect dodge). Both scale Engine.time_scale and always restore it.

var _slow_scale := 1.0
var _slow_left := 0.0
var _stop_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	# Runs on real time: delta here is already scaled, so undo the scale.
	var real := delta / maxf(Engine.time_scale, 0.0001)
	_stop_left = maxf(_stop_left - real, 0.0)
	_slow_left = maxf(_slow_left - real, 0.0)
	_apply()


## Freezes the action for a moment, in real seconds (0.06 to 0.15 feels right).
func hitstop(seconds: float) -> void:
	_stop_left = maxf(_stop_left, seconds)
	_apply()


func slow_motion(scale: float, seconds: float) -> void:
	_slow_scale = scale
	_slow_left = maxf(_slow_left, seconds)
	_apply()


func reset() -> void:
	_stop_left = 0.0
	_slow_left = 0.0
	_apply()


func _apply() -> void:
	if get_tree().paused:
		return
	if _stop_left > 0.0:
		Engine.time_scale = 0.05
	elif _slow_left > 0.0:
		Engine.time_scale = _slow_scale
	else:
		Engine.time_scale = 1.0

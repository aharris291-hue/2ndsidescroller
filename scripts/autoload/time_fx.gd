extends Node
## Game-feel time effects: hitstop (a tiny freeze on impact) and slow motion
## (a perfect dodge). Both scale Engine.time_scale while they run, then put back
## whatever it was before (so other code that changes time_scale is left alone).

var _slow_scale := 1.0
var _slow_left := 0.0
var _stop_left := 0.0
var _active := false
var _base_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_base_speed(Settings.game_speed)


## The game's normal speed (the "slower game" assist sets 0.8). Hitstop and slow
## motion scale from it and come back to it.
func set_base_speed(speed: float) -> void:
	if _active:
		_base_scale = speed
	else:
		Engine.time_scale = speed


func _process(delta: float) -> void:
	# Count down in game time without our own slowdown (delta here already has it).
	var real := delta / maxf(Engine.time_scale, 0.0001) * (_base_scale if _active else Engine.time_scale)
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
	var wanted := 0.0
	if _stop_left > 0.0:
		wanted = 0.05
	elif _slow_left > 0.0:
		wanted = _slow_scale
	if wanted > 0.0:
		if not _active:
			_active = true
			_base_scale = Engine.time_scale
		Engine.time_scale = _base_scale * wanted
	elif _active:
		_active = false
		Engine.time_scale = _base_scale

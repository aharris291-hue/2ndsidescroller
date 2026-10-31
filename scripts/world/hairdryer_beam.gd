class_name HairdryerBeam
extends Node2D
## Nell's hairdryer, reaching into the book from the Margin in the finale. A column of
## warm air comes down from the nozzle and follows Patch across the page, a little
## behind him: Nell is watching where he goes. Whatever wet thing it lands on dries.
##
## Expected children: "Nozzle" (Sprite2D, the hairdryer, at the top of the screen) and
## "Air" (Sprite2D, the warm column, drawn additively).

## How fast the warm air catches up with Patch, in pixels per second.
@export var follow_speed := 300.0
## Half the width of the column of warm air.
@export var half_width := 150.0
@export var left_limit := 0.0
@export var right_limit := 1920.0

var active := false

@onready var _nozzle: Sprite2D = $Nozzle
@onready var _air: Sprite2D = $Air
var _hum_left := 0.0


func _ready() -> void:
	visible = false


## The Margin lights up: the hairdryer pushes in over the page and switches on.
func switch_on() -> void:
	if active:
		return
	active = true
	visible = true
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		global_position.x = clampf(player.global_position.x, left_limit, right_limit)
	modulate.a = 0.0
	var nozzle_y := _nozzle.position.y
	_nozzle.position.y = nozzle_y - 400.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)
	tween.tween_property(_nozzle, "position:y", nozzle_y, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx(&"dryer")


func covers(x: float, extra := 0.0) -> bool:
	return active and absf(x - global_position.x) <= half_width + extra


func _process(delta: float) -> void:
	if not active:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var target := clampf(player.global_position.x, left_limit, right_limit)
		global_position.x = move_toward(global_position.x, target, follow_speed * delta)
	var t := Time.get_ticks_msec() * 0.001
	_air.scale.x = _air.scale.y * (1.0 + sin(t * 7.0) * 0.04)
	_air.modulate.a = 0.8 + sin(t * 11.0) * 0.1
	_nozzle.rotation = sin(t * 1.3) * 0.04
	_hum_left -= delta
	if _hum_left <= 0.0:
		_hum_left = 1.1
		AudioManager.play_sfx(&"dryer", randf_range(0.95, 1.05), -12.0)

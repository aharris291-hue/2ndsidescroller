class_name PaperBar
extends Control
## A health bar drawn as a strip of torn paper soaked through with ink-red, used for
## Patch (HUD), the bosses (HUD) and ordinary enemies (EnemyBar, over their heads).
##
## Damage drains in two stages: the red drops at once and a bone-white "tear" shows
## what was lost, then follows it down. Healing flashes the Mend green. Every
## `segment` points a stitch crosses the strip, so Patch's old tokens (2 health each)
## can still be counted. Low health makes the strip throb.

const INK := Color("17110f")
const SHADOW := Color(0, 0, 0, 0.55)
const EDGE := Color("3a2a22")
const BONE := Color("d8cdb6")
const RED := Color("8e1c17")
const RED_DEEP := Color("4a0d0b")
const MEND := Color("7fbf86")

@export var max_value := 10.0:
	set(v):
		max_value = maxf(v, 1.0)
		queue_redraw()
## Points between stitches (0 = none).
@export var segment := 0.0
## How ragged the torn edges are, in pixels.
@export var rag := 3.0
## Below this fraction the strip throbs.
@export var low_fraction := 0.25

var value := 10.0
## What the red shows (eases to `value`) and what the bone-white tear shows (waits, then follows).
var _shown := 10.0
var _tear := 10.0
var _tear_wait := 0.0
var _flash := 0.0
var _flash_colour := BONE
var _shake := 0.0
var _time := 0.0
var _top: PackedFloat32Array
var _bottom: PackedFloat32Array


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_tear_edges)
	_tear_edges()


## Sets the value. `instant` skips the drain (a new fight, a loaded save).
func set_value(v: float, instant := false) -> void:
	v = clampf(v, 0.0, max_value)
	if instant:
		value = v
		_shown = v
		_tear = v
		queue_redraw()
		return
	if v < value:
		_tear = maxf(_tear, _shown)
		_tear_wait = 0.45
		_flash = 1.0
		_flash_colour = BONE
		_shake = 1.0
	elif v > value:
		_flash = 1.0
		_flash_colour = MEND
		_tear = v
	value = v


func fraction() -> float:
	return value / max_value


func _process(delta: float) -> void:
	_time += delta
	_shown = move_toward(_shown, value, max_value * delta * 4.0) if _shown > value \
		else lerpf(_shown, value, minf(delta * 10.0, 1.0))
	if _tear_wait > 0.0:
		_tear_wait -= delta
	else:
		_tear = move_toward(_tear, _shown, max_value * delta * 0.9)
	_flash = maxf(_flash - delta * 3.0, 0.0)
	_shake = maxf(_shake - delta * 5.0, 0.0)
	queue_redraw()


## Fixed random rags along the top and bottom edges, so the strip doesn't shimmer.
func _tear_edges() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(size.x * 31.0 + size.y)
	var count := maxi(int(size.x / 9.0), 2) + 1
	_top = PackedFloat32Array()
	_bottom = PackedFloat32Array()
	for i in count:
		_top.append(rng.randf_range(0.0, rag))
		_bottom.append(rng.randf_range(0.0, rag))


func _strip(from_x: float, to_x: float, inset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	if to_x - from_x < 0.5:
		return points
	var count := _top.size()
	var step := size.x / float(count - 1)
	points.append(Vector2(from_x, inset + _rag_at(_top, from_x, step)))
	for i in count:
		var x := i * step
		if x > from_x and x < to_x:
			points.append(Vector2(x, inset + _top[i]))
	points.append(Vector2(to_x, inset + _rag_at(_top, to_x, step)))
	points.append(Vector2(to_x, size.y - inset - _rag_at(_bottom, to_x, step)))
	for i in range(count - 1, -1, -1):
		var x := i * step
		if x > from_x and x < to_x:
			points.append(Vector2(x, size.y - inset - _bottom[i]))
	points.append(Vector2(from_x, size.y - inset - _rag_at(_bottom, from_x, step)))
	return points


func _rag_at(edge: PackedFloat32Array, x: float, step: float) -> float:
	var f := clampf(x / step, 0.0, edge.size() - 1.001)
	var i := int(f)
	return lerpf(edge[i], edge[i + 1], f - i)


func _draw() -> void:
	if _top.is_empty():
		return
	var jolt := Vector2(sin(_time * 90.0), cos(_time * 70.0)) * 3.0 * _shake
	draw_set_transform(jolt)
	# The backing sheet: dark, with a lighter worn edge.
	var back := _strip(0.0, size.x, 0.0)
	var shadow := back.duplicate()
	for i in shadow.size():
		shadow[i] += Vector2(3, 4)
	draw_colored_polygon(shadow, SHADOW)
	draw_colored_polygon(back, INK)
	# Bare, stained paper where the ink has gone.
	draw_colored_polygon(_strip(3.0, size.x - 3.0, 4.0), Color("231a16"))
	var outline := back.duplicate()
	outline.append(back[0])
	draw_polyline(outline, EDGE, 2.0, true)
	var inner_w := size.x - 6.0
	# The tear: what was just lost, still showing as bare paper.
	var tear_x := 3.0 + inner_w * clampf(_tear / max_value, 0.0, 1.0)
	var red_x := 3.0 + inner_w * clampf(_shown / max_value, 0.0, 1.0)
	if tear_x > red_x + 0.5:
		draw_colored_polygon(_strip(red_x, tear_x, 4.0), BONE.darkened(0.15))
	# The ink: deep at the bottom, brighter along the top, throbbing when low.
	if red_x > 3.5:
		var red := RED
		if fraction() <= low_fraction and value > 0.0:
			red = RED.lerp(Color("c2302a"), 0.5 + 0.5 * sin(_time * 7.0))
		if _flash > 0.0:
			red = red.lerp(_flash_colour, _flash * 0.7)
		draw_colored_polygon(_strip(3.0, red_x, 4.0), RED_DEEP.lerp(red, 0.55))
		var sheen := _strip(3.0, red_x, 4.0)
		for i in sheen.size():
			sheen[i].y = minf(sheen[i].y, size.y * 0.5)
		draw_colored_polygon(sheen, red)
		# Fibres: a few faint strokes, so it reads as soaked paper, not a flat fill.
		for k in int(red_x / 23.0):
			var fx := 8.0 + k * 23.0 + fmod(k * 7.3, 9.0)
			draw_line(Vector2(fx, size.y * 0.3), Vector2(fx + 6.0, size.y * 0.62), Color(0, 0, 0, 0.18), 1.0)
	# Stitches every `segment` points: Gran's thread, crossing the strip.
	if segment > 0.0 and max_value / segment <= 40.0:
		var n := int(round(max_value / segment))
		for s in range(1, n):
			var x := 3.0 + inner_w * s / float(n)
			var c := Color(BONE, 0.75)
			draw_line(Vector2(x - 3.0, 2.0), Vector2(x + 3.0, size.y - 2.0), c, 2.0, true)
			draw_line(Vector2(x + 3.0, 2.0), Vector2(x - 3.0, size.y - 2.0), Color(c, 0.45), 1.5, true)
	draw_set_transform(Vector2.ZERO)

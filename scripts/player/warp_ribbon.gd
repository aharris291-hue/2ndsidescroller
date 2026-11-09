class_name WarpRibbon
extends Node2D
## Bookmark Warp (the Index): Gran's red ribbon bookmark. Gran never turned down the
## corner of a page; she kept her place with a ribbon. Patch lays it where he stands
## and, from anywhere on the same page, tears himself out of where he is and back to
## it (Patch.bookmark_warp). A thin red thread runs from him to it while it's down.
##
## It stays where it was laid: on ground, or riding whatever moving thing it was laid
## on (a drawer), and it goes when the page does. Silverfish eat it.

## Where Patch stands when he comes back (his origin, about 42 px over his feet).
const FEET := 42.0
const RED := Color(0.62, 0.08, 0.09)

var patch: Node2D
var _thread: Line2D
var _cloth: Polygon2D
var _t := 0.0


## Lays a ribbon at Patch's feet, on whatever he stands on.
static func lay(by: CharacterBody2D) -> WarpRibbon:
	var ribbon := WarpRibbon.new()
	ribbon.patch = by
	var holder: Node = by.get_parent()
	var below := by.move_and_collide(Vector2(0, 8), true)
	if below and below.get_collider() is AnimatableBody2D:
		holder = below.get_collider() as Node
	holder.add_child(ribbon)
	ribbon.global_position = by.global_position
	return ribbon


func _ready() -> void:
	add_to_group(&"warp_ribbons")
	z_index = 2
	_thread = Line2D.new()
	_thread.width = 3.0
	_thread.default_color = Color(0.8, 0.12, 0.12, 0.75)
	_thread.top_level = true
	_thread.z_index = 2
	add_child(_thread)
	# The ribbon itself: tucked into the page at the ground, its forked tail lifting.
	_cloth = Polygon2D.new()
	_cloth.color = RED
	_cloth.polygon = PackedVector2Array([
		Vector2(-8, FEET), Vector2(8, FEET), Vector2(12, FEET - 66), Vector2(3, FEET - 54),
		Vector2(-6, FEET - 72), Vector2(-9, FEET - 4)])
	add_child(_cloth)
	var shade := Polygon2D.new()
	shade.color = Color(0.3, 0.03, 0.04)
	shade.polygon = PackedVector2Array([Vector2(-8, FEET), Vector2(-1, FEET), Vector2(-4, FEET - 64), Vector2(-9, FEET - 4)])
	add_child(shade)
	var stitch := Line2D.new()
	stitch.width = 2.0
	stitch.default_color = Color(0.9, 0.78, 0.5, 0.8)
	stitch.points = PackedVector2Array([Vector2(-10, FEET - 2), Vector2(10, FEET - 2)])
	add_child(stitch)
	scale = Vector2(1, 0.2)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	_cloth.skew = sin(_t * 3.0) * 0.08
	if is_instance_valid(patch):
		var from := global_position + Vector2(0, FEET - 30)
		var to := patch.global_position
		var mid := (from + to) / 2.0 + Vector2(0, minf(from.distance_to(to) * 0.12, 90.0))
		_thread.points = PackedVector2Array([from, mid.lerp(from, 0.5), mid, mid.lerp(to, 0.5), to])


## A silverfish got to it.
func eaten() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(&"warp_ribbons")
	AudioManager.play_sfx(&"swipe", 1.7, -4.0)
	_thread.visible = false
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 0.0), 0.25)
	tween.tween_callback(queue_free)


## Warping in when something stands where the ribbon is: it twitches, and stays.
func blocked() -> void:
	var tween := create_tween()
	tween.tween_property(_cloth, "modulate", Color(2, 2, 2), 0.05)
	tween.tween_property(_cloth, "modulate", Color.WHITE, 0.25)

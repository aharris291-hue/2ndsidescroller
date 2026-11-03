class_name Tells
extends RefCounted
## The shared tell language (Redesign Bible 3.1). Every enemy uses these, so the
## same cue always means the same thing:
## - a white glint: the attack can be parried;
## - a red glow: the attack must be dodged.
## With Settings.tell_shapes on, the red glow also raises a black and yellow warning
## sign over the attacker, so the cue never depends on telling red from other colours.


## A four-point white star that pops and fades at `offset` from `parent`.
static func glint(parent: Node2D, offset: Vector2, size := 1.0) -> void:
	var star := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 8:
		var r := (26.0 if i % 2 == 0 else 6.0) * size
		points.append(Vector2.from_angle(i * TAU / 8.0 - PI / 2.0) * r)
	star.polygon = points
	star.color = Color(1, 1, 1, 0.95)
	star.position = offset
	star.z_index = 8
	star.scale = Vector2(0.2, 0.2)
	# Tells keep their full colour on weathered pages (see Page), so they always read.
	star.add_to_group(&"vfx")
	parent.add_child(star)
	var tween := star.create_tween()
	tween.tween_property(star, "scale", Vector2(1.2, 1.2), 0.1).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(star, "rotation", 0.6, 0.3)
	tween.tween_property(star, "modulate:a", 0.0, 0.25)
	tween.tween_callback(star.queue_free)


## Pulses `item` red for `seconds`, then puts its colour back.
static func red_glow(item: CanvasItem, seconds: float) -> void:
	# On a weathered page the grey shader would wash the red out, so lift it off
	# while the glow runs and put it back after.
	var shader_material := item.material as ShaderMaterial
	if shader_material and shader_material.shader == Page.WEATHERED and not item.has_meta(&"tell_material"):
		item.set_meta(&"tell_material", shader_material)
		item.material = null
	if Settings.tell_shapes:
		_warning_sign(item, seconds)
	var tween := item.create_tween()
	var steps := maxi(int(seconds / 0.12), 1)
	for i in steps:
		tween.tween_property(item, "modulate", Color(1.8, 0.45, 0.4), 0.06)
		tween.tween_property(item, "modulate", Color(1.3, 0.7, 0.65), 0.06)
	tween.tween_property(item, "modulate", Color.WHITE, 0.05)
	tween.tween_callback(_restore_material.bind(item))


static func _restore_material(item: CanvasItem) -> void:
	if is_instance_valid(item) and item.has_meta(&"tell_material"):
		item.material = item.get_meta(&"tell_material")
		item.remove_meta(&"tell_material")


## A black-edged yellow triangle with an exclamation mark, over the item's head, for
## as long as its red glow runs. Added beside the item (not under it) so the red glow
## doesn't tint it.
static func _warning_sign(item: CanvasItem, seconds: float) -> void:
	var body := item as Node2D
	var parent := body.get_parent() as Node2D if body else null
	if parent == null:
		return
	var top := 60.0
	if body is Sprite2D and (body as Sprite2D).texture:
		top = (body as Sprite2D).texture.get_height() * 0.5 * absf(body.scale.y) + 30.0
	var sign := Node2D.new()
	sign.name = &"WarningSign"
	sign.position = body.position + Vector2(0, -top)
	sign.z_index = 9
	sign.add_to_group(&"vfx")
	var outline := Polygon2D.new()
	outline.polygon = PackedVector2Array([Vector2(0, -30), Vector2(28, 18), Vector2(-28, 18)])
	outline.color = Color(0.05, 0.04, 0.04)
	sign.add_child(outline)
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([Vector2(0, -21), Vector2(20, 13), Vector2(-20, 13)])
	fill.color = Color(1.0, 0.82, 0.1)
	sign.add_child(fill)
	var bar := Polygon2D.new()
	bar.polygon = PackedVector2Array([Vector2(-3, -11), Vector2(3, -11), Vector2(2, 3), Vector2(-2, 3)])
	bar.color = Color(0.05, 0.04, 0.04)
	sign.add_child(bar)
	var dot := Polygon2D.new()
	dot.polygon = PackedVector2Array([Vector2(-3, 6), Vector2(3, 6), Vector2(3, 11), Vector2(-3, 11)])
	dot.color = Color(0.05, 0.04, 0.04)
	sign.add_child(dot)
	parent.add_child(sign)
	var tween := sign.create_tween()
	tween.tween_property(sign, "scale", Vector2(1.25, 1.25), 0.08)
	tween.tween_property(sign, "scale", Vector2.ONE, 0.08)
	tween.tween_interval(maxf(seconds - 0.16, 0.05))
	tween.tween_callback(sign.queue_free)

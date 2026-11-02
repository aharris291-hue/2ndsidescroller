class_name Tells
extends RefCounted
## The shared tell language (Redesign Bible 3.1). Every enemy uses these, so the
## same cue always means the same thing:
## - a white glint: the attack can be parried;
## - a red glow: the attack must be dodged.


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

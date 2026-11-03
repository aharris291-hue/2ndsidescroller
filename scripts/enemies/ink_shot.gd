class_name InkShot
extends InkBlob
## A straight shot of ink from an Inkwell Turret. A cut knocks it back the way it came
## (faster, and now it's Patch's): it hurts whatever enemy it hits.

var reflected := false


func _on_area_entered(area: Area2D) -> void:
	if reflected or not (area is Hitbox and area.owner is Patch):
		return
	reflected = true
	velocity = -velocity * 1.4
	damage = 2
	hold_damage = 2
	knockback = 420.0
	life = 2.0
	# Now one of Patch's attacks: enemies' hurtboxes look for layer 8.
	set_deferred(&"collision_layer", 8)
	set_deferred(&"collision_mask", 1)
	landed.connect(func(_target: Node) -> void: _splat(0.0))
	modulate = Color(0.7, 0.85, 1.4)
	AudioManager.play_sfx(&"parry", 1.3)


func _on_body_entered(body: Node2D) -> void:
	if reflected and not (body is TileMapLayer or body is StaticBody2D):
		return
	super._on_body_entered(body)

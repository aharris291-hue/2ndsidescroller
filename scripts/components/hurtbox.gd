class_name Hurtbox
extends Area2D
## Reports every active Hitbox it overlaps, every physics frame.
## The receiver's HealthComponent decides whether the hit lands (invulnerability),
## so standing inside an enemy keeps hurting after the invulnerability window ends.

signal hit(hitbox: Hitbox)


func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
	for area in get_overlapping_areas():
		var hitbox := area as Hitbox
		if hitbox and hitbox.active and hitbox.owner != owner:
			hit.emit(hitbox)

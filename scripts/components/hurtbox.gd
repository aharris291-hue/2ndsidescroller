class_name Hurtbox
extends Area2D
## Reports every active Hitbox it overlaps, every physics frame.
## The receiver's HealthComponent decides whether the hit lands (invulnerability),
## so standing inside an enemy keeps hurting after the invulnerability window ends.
## When the owner has a `health` HealthComponent and the hit takes health off it,
## the hitbox is told it landed (for Thread, hitstop and Plunge bounces), and the
## owner's HoldComponent (if any) takes the hit's Hold damage.

signal hit(hitbox: Hitbox)


func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
	for area in get_overlapping_areas():
		var hitbox := area as Hitbox
		if hitbox == null or not hitbox.active or hitbox.owner == owner:
			continue
		var health := owner.get("health") as HealthComponent if owner else null
		var before := health.current if health else -1
		# A cut in the form this enemy fears: +1 damage and half again the Hold, for
		# this hit only (the same hitbox may be striking something else this frame).
		var weak := Bestiary.is_weak_to(owner, hitbox.form)
		var base_damage := hitbox.damage
		var base_hold := hitbox.hold_damage
		if weak:
			hitbox.damage += 1
			hitbox.hold_damage *= 1.5
		hit.emit(hitbox)
		if health and health.current < before and is_instance_valid(hitbox):
			var hold := owner.get_node_or_null(^"HoldComponent") as HoldComponent
			if hold:
				hold.take_hold(hitbox.hold_damage)
			hitbox.landed.emit(owner)
		if weak and is_instance_valid(hitbox):
			hitbox.damage = base_damage
			hitbox.hold_damage = base_hold

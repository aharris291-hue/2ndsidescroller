class_name HitReaction
extends RefCounted
## How an ordinary enemy takes a hit, by move (Hitbox.reaction):
##   FLINCH  light cuts: a small jolt and a short push. The enemy keeps fighting.
##   REEL    heavy cuts: knocked back and off balance for a moment (no attacks).
##   LAUNCH  the launcher: popped up into the air, helpless until it lands.
##   SEND    the combo-ending thrust and charged cuts: sent tumbling, and whatever
##           it tumbles into gets hit too (one victim). Enemies are weapons.
##   CRUSH   the Plunge and the slam: squashed flat where it stands, dazed longest.
##
## Enemies call apply() from their hit handler (it returns the knockback to use) and
## tick() at the top of their physics step: while it returns true they are reeling
## and should only fall, slide and move_and_slide, not think or attack.

const STUN := {
	Hitbox.Reaction.FLINCH: 0.0,
	Hitbox.Reaction.REEL: 0.45,
	Hitbox.Reaction.LAUNCH: 0.7,
	Hitbox.Reaction.SEND: 0.65,
	Hitbox.Reaction.CRUSH: 0.9,
}
## Share of the hit's knockback that moves the enemy, before its own weight.
const PUSH := {
	Hitbox.Reaction.FLINCH: 0.35,
	Hitbox.Reaction.REEL: 0.9,
	Hitbox.Reaction.LAUNCH: 0.0,
	Hitbox.Reaction.SEND: 1.7,
	Hitbox.Reaction.CRUSH: 0.0,
}
const TUMBLE_TIME := 0.5


static func reaction_of(hitbox: Hitbox) -> Hitbox.Reaction:
	return Hitbox.Reaction.LAUNCH if hitbox.launch else hitbox.reaction


## Reacts to a hit that landed. `weight` scales how far it's pushed (a shielded knight
## barely moves); `side_view` is false on flat pages, where nothing is launched up.
## Returns the knockback velocity the enemy should take (side view: sideways only, the
## hop or launch goes straight into its velocity).
static func apply(enemy: CharacterBody2D, hitbox: Hitbox, sprite: Node2D, base_scale: Vector2,
		weight := 1.0, side_view := true) -> Vector2:
	var kind := reaction_of(hitbox)
	if not side_view and kind == Hitbox.Reaction.LAUNCH:
		kind = Hitbox.Reaction.REEL
	var away := enemy.global_position - hitbox.global_position
	var side := signf(away.x) if absf(away.x) > 0.5 else 1.0
	var knockback := Vector2.ZERO
	match kind:
		Hitbox.Reaction.LAUNCH:
			knockback = Vector2(side * 80.0, -900.0)
		Hitbox.Reaction.CRUSH:
			knockback = Vector2.ZERO
		_:
			knockback = (away.normalized() if away != Vector2.ZERO else Vector2(side, 0)) * hitbox.knockback * PUSH[kind]
			if side_view:
				knockback.y = -150.0 if kind == Hitbox.Reaction.FLINCH else -260.0
	knockback *= weight
	if side_view:
		# The upward part is one impulse (gravity takes it from there); only the
		# sideways push is returned, for the enemy to add each frame as it decays.
		if knockback.y != 0.0:
			enemy.velocity.y = knockback.y
		knockback.y = 0.0
	var stun: float = STUN[kind]
	if stun > 0.0:
		enemy.set_meta(&"reel_left", maxf(stun, float(enemy.get_meta(&"reel_left", 0.0))))
	enemy.set_meta(&"last_reaction", kind)
	_animate(enemy, kind, sprite, base_scale, side, stun)
	if kind == Hitbox.Reaction.SEND and weight > 0.0:
		_tumble(enemy)
	return knockback


## Counts down a reel. True while the enemy is still off balance.
static func tick(enemy: Node, delta: float) -> bool:
	var left := float(enemy.get_meta(&"reel_left", 0.0))
	if left <= 0.0:
		return false
	enemy.set_meta(&"reel_left", left - delta)
	return true


static func is_reeling(enemy: Node) -> bool:
	return float(enemy.get_meta(&"reel_left", 0.0)) > 0.0


static func last_reaction(enemy: Node) -> int:
	return int(enemy.get_meta(&"last_reaction", -1))


static func _animate(enemy: Node, kind: Hitbox.Reaction, sprite: Node2D, base_scale: Vector2,
		side: float, stun: float) -> void:
	if sprite == null:
		return
	var old: Tween = enemy.get_meta(&"reaction_tween") if enemy.has_meta(&"reaction_tween") else null
	if old and old.is_valid():
		old.kill()
	var tween := enemy.create_tween()
	enemy.set_meta(&"reaction_tween", tween)
	match kind:
		Hitbox.Reaction.FLINCH:
			sprite.scale = base_scale * Vector2(0.86, 1.1)
			tween.tween_property(sprite, "scale", base_scale, 0.12)
		Hitbox.Reaction.REEL:
			sprite.scale = base_scale * Vector2(0.8, 1.15)
			sprite.rotation = 0.28 * side
			tween.set_parallel()
			tween.tween_property(sprite, "scale", base_scale, stun).set_trans(Tween.TRANS_ELASTIC)
			tween.tween_property(sprite, "rotation", 0.0, stun).set_trans(Tween.TRANS_SINE)
		Hitbox.Reaction.LAUNCH:
			sprite.scale = base_scale * Vector2(0.8, 1.2)
			tween.set_parallel()
			tween.tween_property(sprite, "scale", base_scale, 0.3)
			tween.tween_property(sprite, "rotation", 0.0, stun).from(-0.6 * side)
		Hitbox.Reaction.SEND:
			# Tumbles end over end as it flies.
			sprite.scale = base_scale * Vector2(1.2, 0.85)
			tween.set_parallel()
			tween.tween_property(sprite, "rotation", TAU * side, TUMBLE_TIME).from(0.0)
			tween.tween_property(sprite, "scale", base_scale, TUMBLE_TIME)
			tween.chain().tween_property(sprite, "rotation", 0.0, 0.0)
		Hitbox.Reaction.CRUSH:
			sprite.scale = base_scale * Vector2(1.45, 0.45)
			tween.tween_interval(stun * 0.6)
			tween.tween_property(sprite, "scale", base_scale, stun * 0.4).set_trans(Tween.TRANS_BACK)


## While it tumbles, the enemy's body is a weapon: the first other enemy it meets
## takes the hit (and reels), the way a bowling pin takes out the next.
static func _tumble(enemy: CharacterBody2D) -> void:
	var old := enemy.get_node_or_null(^"Tumble")
	if old:
		old.free()
	var hitbox := Hitbox.new()
	hitbox.name = &"Tumble"
	hitbox.collision_layer = 8
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.damage = 1
	hitbox.hold_damage = 1.5
	hitbox.knockback = 560.0
	hitbox.reaction = Hitbox.Reaction.REEL
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 56.0
	shape.shape = circle
	shape.position = Vector2(0, -40)
	hitbox.add_child(shape)
	enemy.add_child(hitbox)
	# Its own hurtbox ignores hitboxes with the same owner.
	hitbox.owner = enemy
	hitbox.landed.connect(func(target: Node) -> void:
		if target == enemy or not is_instance_valid(hitbox):
			return
		hitbox.active = false
		GameState.add_thread(0.15)
		TimeFX.hitstop(0.05)
		AudioManager.play_sfx(&"slam", 1.3, -4.0)
		EventBus.enemy_bowled.emit())
	# A bound method, so the connection goes away by itself if the enemy dies first.
	enemy.get_tree().create_timer(TUMBLE_TIME, false, true).timeout.connect(hitbox.queue_free)

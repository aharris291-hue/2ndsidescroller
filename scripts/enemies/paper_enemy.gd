class_name PaperEnemy
extends CharacterBody2D
## Shared body for the Phase 2 enemies (Paper Moth, Inkwell Turret, Folded Crane,
## Mimic Book). A scene only needs a Sprite2D (painted facing left); this builds the
## collision, hurtbox, contact hitbox, health and Hold from the exports, handles
## hit flashes, knockback, staggering, the Unstitch and death, and makes the enemy
## Inked (an elite) when `inked` is set.

const SCRAP_SCENE := preload("res://scenes/pickups/scrap.tscn")

@export var max_health := 3
@export var max_hold := 3.0
@export var contact_damage := 1
@export var body_size := Vector2(80, 80)
@export var hurt_size := Vector2(100, 100)
@export var scrap_drop := 2
@export var gravity := 2000.0
## Flying enemies ignore gravity.
@export var flies := false
## How much of a hit's knockback moves it (heavy things barely move).
@export var knockback_taken := 0.6
## Inked elite: darker, half again as tough, quicker to attack. See Inked.
@export var inked := false

var view_mode: PageView.Mode = PageView.Mode.SIDE
var health: HealthComponent
var hold: HoldComponent
var hurtbox: Hurtbox
var contact_hitbox: Hitbox
## Multiplies wind-up times (Inked elites are quicker).
var tempo := 1.0
var _knockback := Vector2.ZERO
var _facing := -1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var _sprite_scale := sprite.scale


func _ready() -> void:
	var page := get_tree().get_first_node_in_group("page") as Page
	if page:
		view_mode = page.view_mode
	if flies or view_mode == PageView.Mode.TOP:
		motion_mode = MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1
	_shape(self, body_size, Vector2(0, -body_size.y / 2.0))
	hurtbox = Hurtbox.new()
	hurtbox.name = &"Hurtbox"
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 8
	add_child(hurtbox)
	hurtbox.owner = self
	_shape(hurtbox, hurt_size, Vector2(0, -body_size.y / 2.0))
	contact_hitbox = Hitbox.new()
	contact_hitbox.name = &"ContactHitbox"
	contact_hitbox.collision_layer = 16
	contact_hitbox.collision_mask = 0
	contact_hitbox.monitoring = false
	contact_hitbox.damage = contact_damage
	add_child(contact_hitbox)
	contact_hitbox.owner = self
	_shape(contact_hitbox, body_size * 0.8, Vector2(0, -body_size.y / 2.0))
	health = HealthComponent.new()
	health.name = &"HealthComponent"
	health.max_health = max_health
	health.invulnerability_time = 0.08
	add_child(health)
	hold = HoldComponent.new()
	hold.name = &"HoldComponent"
	hold.max_hold = max_hold
	add_child(hold)
	if inked:
		Inked.apply(self)
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_on_died)
	hold.broken.connect(_on_hold_broken)
	add_to_group(&"enemies")


func _shape(parent: Node, size: Vector2, at: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	parent.add_child(shape)


func player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func is_staggered() -> bool:
	return hold.is_broken()


## Moves with gravity (unless it flies) and any knockback; subclasses set velocity first.
func move(delta: float) -> void:
	if not flies and view_mode == PageView.Mode.SIDE and not is_on_floor():
		velocity.y += gravity * delta
	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 3000.0 * delta)
	move_and_slide()
	sprite.flip_h = _facing > 0.0


## Call first in a subclass's physics step: while the enemy is reeling from a hit (see
## HitReaction) it only drifts and falls, and this returns true so it skips its turn.
func reeling(delta: float) -> bool:
	if not HitReaction.tick(self, delta):
		return false
	# Only the (decaying) knockback moves it.
	velocity.x = 0.0
	if flies or view_mode == PageView.Mode.TOP:
		velocity = Vector2.ZERO
	move(delta)
	return true


func face(x: float) -> void:
	if absf(x) > 1.0:
		_facing = signf(x)


func _on_hit(hitbox: Hitbox) -> void:
	if not health.take_damage(hitbox.damage, hitbox.global_position):
		return
	_knockback = HitReaction.apply(self, hitbox, sprite, _sprite_scale, knockback_taken,
		view_mode == PageView.Mode.SIDE and not flies)
	var tween := create_tween()
	sprite.modulate = Color(1.6, 1.6, 1.6)
	tween.tween_property(sprite, "modulate", _base_colour(), 0.2)
	hurt(hitbox)


## Subclasses: react to a hit that landed (cancel a wind-up, drop out of the air...).
func hurt(_hitbox: Hitbox) -> void:
	pass


func _base_colour() -> Color:
	return Inked.TINT if inked else Color.WHITE


func _on_hold_broken() -> void:
	Tells.glint(self, Vector2(0, -body_size.y), 0.7)
	staggered()


## Subclasses: Hold broke (it's open to an Unstitch for a moment).
func staggered() -> void:
	pass


## Patch's finisher.
func unstitch(_by: Node) -> void:
	health.clear_invulnerability()
	health.take_damage(999, global_position)


func _on_died() -> void:
	contact_hitbox.set_deferred("monitorable", false)
	contact_hitbox.active = false
	hurtbox.set_deferred("monitoring", false)
	AudioManager.play_sfx(&"enemy_pop", randf_range(0.8, 1.0))
	for i in scrap_drop:
		var scrap := SCRAP_SCENE.instantiate() as Collectible
		scrap.persistent = false
		scrap.position = position + Vector2(randf_range(-40, 40), randf_range(-60, -20))
		get_parent().add_child.call_deferred(scrap)
	if inked:
		Inked.on_died(self)
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "scale", _sprite_scale * Vector2(1.3, 0.1), 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)

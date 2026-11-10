class_name Silverfish
extends PaperEnemy
## A Silverfish (the Index): the archive's vermin, grown fat on the book. It skitters
## along the floor in quick darts, and when Patch is close it goes under: it slips
## into the page itself, and the only sign of it is the paper rippling as it comes
## towards him. The ripple stops under him, the floor bulges (the tell), and it bursts
## up, jaws first. That bite can't be guarded: move. Out of the floor it's open for a
## moment, and it's soft: three cuts.
##
## It eats paper, and Gran's ribbon is paper: a ribbon laid within reach of one is
## what it goes for first (WarpRibbon.eaten).

enum State { SKITTER, BURROW, TUNNEL, BULGE, BITE, EXPOSED }

@export var notice_range := 640.0
@export var dart_speed := 520.0
@export var tunnel_speed := 430.0
@export var bulge_time := 0.42
@export var exposed_time := 0.9
## How near a laid ribbon has to be for it to go after it.
@export var ribbon_range := 520.0

var state := State.SKITTER
var _left := 0.0
var _target_x := 0.0
var _ripple: CPUParticles2D
var _bite: Hitbox


func _init() -> void:
	bestiary_id = "silverfish"
	max_health = 3
	max_hold = 2.0
	contact_damage = 1
	body_size = Vector2(130, 46)
	hurt_size = Vector2(170, 70)
	scrap_drop = 2
	knockback_taken = 0.9


func _ready() -> void:
	super._ready()
	_left = randf_range(0.2, 0.8)
	_ripple = CPUParticles2D.new()
	_ripple.emitting = false
	_ripple.amount = 18
	_ripple.lifetime = 0.5
	_ripple.direction = Vector2(0, -1)
	_ripple.spread = 50.0
	_ripple.initial_velocity_min = 60.0
	_ripple.initial_velocity_max = 140.0
	_ripple.gravity = Vector2(0, 500)
	_ripple.scale_amount_min = 3.0
	_ripple.scale_amount_max = 6.0
	_ripple.color = Color(0.78, 0.74, 0.64)
	_ripple.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_ripple.emission_rect_extents = Vector2(30, 2)
	add_child(_ripple)
	_bite = Hitbox.new()
	_bite.collision_layer = 16
	_bite.collision_mask = 0
	_bite.monitoring = false
	_bite.damage = 1
	_bite.knockback = 560.0
	_bite.unblockable = true
	_bite.active = false
	_shape(_bite, Vector2(110, 120), Vector2(0, -60))
	add_child(_bite)
	_bite.owner = self


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	if state in [State.SKITTER, State.EXPOSED] and reeling(delta):
		return
	_left -= delta
	_eat_ribbons()
	match state:
		State.SKITTER:
			_skitter(delta)
		State.BURROW:
			velocity.x = 0.0
			if _left <= 0.0:
				state = State.TUNNEL
				# It gives up and comes up wherever it is after a while.
				_left = 2.2
				_ripple.emitting = true
		State.TUNNEL:
			var dx := _target_x - global_position.x
			var target := player()
			if target and not _ribbon_target():
				_target_x = target.global_position.x
			velocity.x = signf(dx) * tunnel_speed if absf(dx) > 12.0 else 0.0
			if absf(dx) <= 12.0 or is_on_wall() or _left <= 0.0:
				_bulge()
		State.BULGE:
			velocity.x = 0.0
			if _left <= 0.0:
				_burst()
		State.BITE:
			velocity.x = 0.0
			if _left <= 0.0:
				_bite.active = false
				state = State.EXPOSED
				_left = exposed_time
				hurtbox.set_deferred("monitoring", true)
		State.EXPOSED:
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			if _left <= 0.0:
				state = State.SKITTER
				_left = randf_range(0.5, 0.9) * tempo
	move(delta)


func _skitter(delta: float) -> void:
	var target := player()
	var ribbon := _ribbon_target()
	var goal: Node2D = ribbon if ribbon else target
	var dx := (goal.global_position.x - global_position.x) if goal else 0.0
	var dy := (goal.global_position.y - global_position.y) if goal else 9999.0
	velocity.x = move_toward(velocity.x, 0.0, 2600.0 * delta)
	if _left > 0.0 or not is_on_floor():
		return
	face(dx)
	if goal and absf(dx) < notice_range and absf(dy) < 160.0 and absf(dx) > 140.0:
		_go_under(goal.global_position.x)
	else:
		# A dart, then a twitching pause.
		var way := _facing if goal and absf(dx) < notice_range * 1.6 else (_facing if randf() < 0.6 else -_facing)
		velocity.x = way * dart_speed
		_left = randf_range(0.35, 0.7) * tempo
		AudioManager.play_sfx(&"page_flip", randf_range(1.7, 2.1), -16.0)


func _go_under(x: float) -> void:
	state = State.BURROW
	_target_x = x
	_left = 0.25 * tempo
	hurtbox.set_deferred("monitoring", false)
	contact_hitbox.active = false
	AudioManager.play_sfx(&"page_flip", 0.7, -6.0)
	var tween := create_tween()
	tween.tween_property(sprite, "position:y", sprite.position.y + 70.0, 0.22)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.22)


func _bulge() -> void:
	state = State.BULGE
	_left = bulge_time * tempo
	_ripple.emitting = false
	_ripple.amount = 30
	_ripple.initial_velocity_max = 260.0
	_ripple.emitting = true
	# The tell: the paper bulges and glows red (dodge, don't guard).
	Tells.red_glow(_ripple, bulge_time)
	AudioManager.play_sfx(&"growl", 2.0, -8.0)


func _burst() -> void:
	state = State.BITE
	_left = 0.3
	_ripple.emitting = false
	_bite.active = true
	contact_hitbox.active = true
	AudioManager.play_sfx(&"swipe", 0.8)
	var base_y := sprite.position.y - 70.0
	var tween := create_tween()
	sprite.rotation = -1.2 * -_facing
	tween.tween_property(sprite, "position:y", base_y - 70.0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 1.0, 0.08)
	tween.tween_property(sprite, "position:y", base_y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.25)


func _ribbon_target() -> Node2D:
	for r in get_tree().get_nodes_in_group(&"warp_ribbons"):
		var ribbon := r as Node2D
		if ribbon.global_position.distance_to(global_position) < ribbon_range:
			return ribbon
	return null


func _eat_ribbons() -> void:
	if state in [State.BURROW, State.TUNNEL, State.BULGE]:
		return
	for r in get_tree().get_nodes_in_group(&"warp_ribbons"):
		var ribbon := r as Node2D
		var d := ribbon.global_position + Vector2(0, WarpRibbon.FEET) - global_position
		if absf(d.x) < 80.0 and absf(d.y) < 70.0 and ribbon.has_method("eaten"):
			ribbon.eaten()


func hurt(_hitbox: Hitbox) -> void:
	if state == State.SKITTER:
		_left = maxf(_left, 0.3)

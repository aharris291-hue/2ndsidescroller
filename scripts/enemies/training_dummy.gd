class_name TrainingDummy
extends CharacterBody2D
## A paper fencing mannequin on a post, for the Combat Lab. It can't die: it shows the
## damage of each hit, its Hold bar, and staggers when Hold breaks so Patch can
## practise the Unstitch. With `spars` on it fights back on a rhythm, mixing
## parryable swings (white glint) with unblockable ones (red glow).

@export var spars := false
@export var swing_interval := 2.2
@export var parry_tell := 0.5
@export var red_tell := 0.65
## Chance that a swing is the unblockable kind.
@export var red_chance := 0.3

var _swing_left := 0.0
var _phase := 0
var _red := false
var _facing := -1.0
var _rebuilding := false

@onready var body: Node2D = $Body
@onready var health: HealthComponent = $HealthComponent
@onready var hold: HoldComponent = $HoldComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var swing: Hitbox = $Swing
@onready var hold_bar: Line2D = $HoldBar
@onready var seam: Line2D = $Body/Seam


func _ready() -> void:
	swing.active = false
	seam.visible = false
	_swing_left = swing_interval
	hurtbox.hit.connect(func(hitbox: Hitbox) -> void: health.take_damage(hitbox.damage, hitbox.global_position))
	health.damaged.connect(_on_damaged)
	hold.broken.connect(_on_broken)
	hold.recovered.connect(_on_recovered)
	hold.changed.connect(_on_hold_changed)
	_build_body()


func _physics_process(delta: float) -> void:
	velocity.y += 2000.0 * delta
	velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
	move_and_slide()
	body.rotation = lerpf(body.rotation, 0.0, 8.0 * delta) if not hold.is_broken() else lerpf(body.rotation, 0.25 * _facing, 6.0 * delta)
	# It never dies: health quietly refills.
	if health.current < health.max_health and not health.is_invulnerable():
		health.current = health.max_health
	if spars and not hold.is_broken() and not _rebuilding:
		_spar(delta)


func _spar(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_facing = signf(player.global_position.x - global_position.x)
		if _facing == 0.0:
			_facing = 1.0
		body.scale.x = _facing
	_swing_left -= delta
	match _phase:
		0:
			if _swing_left <= 0.0:
				_phase = 1
				_red = randf() < red_chance
				_swing_left = red_tell if _red else parry_tell
				if _red:
					Tells.red_glow(body, red_tell)
				else:
					Tells.glint(self, Vector2(40.0 * _facing, -130))
		1:
			body.rotation = -0.25 * _facing
			if _swing_left <= 0.0:
				_phase = 2
				_swing_left = 0.12
				swing.position.x = 70.0 * _facing
				swing.unblockable = _red
				swing.damage = 2 if _red else 1
				swing.active = true
				body.rotation = 0.45 * _facing
				AudioManager.play_sfx(&"swipe", 0.6 if _red else 0.9)
		2:
			if _swing_left <= 0.0:
				swing.active = false
				_phase = 0
				_swing_left = swing_interval * randf_range(0.8, 1.2)


## Patch parried: the swing is knocked aside and the post rocks back.
func on_parried(_by: Node) -> void:
	swing.active = false
	_phase = 0
	_swing_left = swing_interval
	body.rotation = -0.5 * _facing


## Patch's finisher: the mannequin unfolds flat, then props itself back up.
func unstitch(_by: Node) -> void:
	_rebuilding = true
	swing.active = false
	_phase = 0
	_float_text("UNSTITCHED", Color("ff6a5a"))
	var tween := create_tween()
	tween.tween_property(body, "scale:y", 0.05, 0.18)
	tween.tween_interval(1.2)
	tween.tween_property(body, "scale:y", 1.0, 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func() -> void:
		_rebuilding = false
		hold.clear()
		hold.current = hold.max_hold
		_on_hold_changed(hold.current, hold.max_hold)
		seam.visible = false)


func _on_damaged(amount: int, from_position: Vector2) -> void:
	_float_text(str(amount), Color("fff6dc"))
	body.rotation = 0.2 * signf(global_position.x - from_position.x)
	if spars and _phase == 1:
		# A hit interrupts the wind-up.
		_phase = 0
		_swing_left = swing_interval * 0.6
		body.modulate = Color.WHITE


func _on_broken() -> void:
	seam.visible = true
	swing.active = false
	_phase = 0
	_float_text("HOLD BROKEN", Color("ffd36e"))


func _on_recovered() -> void:
	seam.visible = false
	_swing_left = swing_interval


func _on_hold_changed(current: float, maximum: float) -> void:
	var w := 90.0 * current / maximum
	hold_bar.points = PackedVector2Array([Vector2(-45, -215), Vector2(-45 + w, -215)])


func _float_text(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color("281e2e"))
	label.add_theme_constant_override(&"outline_size", 8)
	label.add_theme_font_size_override(&"font_size", 34)
	label.position = Vector2(randf_range(-30, 10), -230)
	label.z_index = 9
	add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 70.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


## A papercraft mannequin: card post, padded paper torso, stitched seams.
func _build_body() -> void:
	var dark := Color("3a2a22")
	var parts := [
		[PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(6, -90), Vector2(-6, -90)]), Color("a77b4f")],
		[PackedVector2Array([Vector2(-40, 2), Vector2(40, 2), Vector2(30, -14), Vector2(-30, -14)]), Color("8a6240")],
		[PackedVector2Array([Vector2(-34, -84), Vector2(34, -84), Vector2(40, -120), Vector2(28, -160), Vector2(-28, -160), Vector2(-40, -120)]), Color("e9dcc0") if not spars else Color("d9c3a0")],
		[PackedVector2Array([Vector2(-16, -160), Vector2(16, -160), Vector2(20, -182), Vector2(0, -196), Vector2(-20, -182)]), Color("e9dcc0") if not spars else Color("d9c3a0")],
	]
	for p in parts:
		var poly := Polygon2D.new()
		poly.polygon = p[0]
		poly.color = p[1]
		body.add_child(poly)
		body.move_child(poly, 0)
		var edge := Line2D.new()
		var outline: PackedVector2Array = (p[0] as PackedVector2Array).duplicate()
		outline.append(outline[0])
		edge.points = outline
		edge.width = 4.0
		edge.default_color = dark
		body.add_child(edge)
	# A target patch where the heart would be.
	var target := Polygon2D.new()
	var circle := PackedVector2Array()
	for i in 16:
		circle.append(Vector2.from_angle(i * TAU / 16.0) * 12.0 + Vector2(0, -122))
	target.polygon = circle
	target.color = Color("c8463c")
	body.add_child(target)
	if spars:
		# The sparring post holds a wooden practice sword.
		var stick := Line2D.new()
		stick.points = PackedVector2Array([Vector2(30, -120), Vector2(100, -150)])
		stick.width = 9.0
		stick.default_color = Color("7b5232")
		body.add_child(stick)

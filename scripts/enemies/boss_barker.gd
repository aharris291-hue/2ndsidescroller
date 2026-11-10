class_name BossBarker
extends Node2D
## The Barker, Gatefold Fair's boss (Phase 3): the fair's showman, a tall paper puppet in
## a ringmaster's coat. The night of the flood he stood at the big top's door with his
## megaphone and told the crowd it was only a shower, that the show would go on, that
## NOBODY LEAVES. They stayed. He has been telling the same tale to the empty seats ever
## since. A duel in the ring. Its origin is his feet.
##
## He announces each act (a sign over his head), then does it:
## - The Knife-Thrower: three cards thrown straight at Patch. The red ones can't be
##   guarded: get out of the way. The last is white and glints: parry it and it spins
##   back into him and he's open (stunned).
## - The Stampede: carousel horses gallop across the ring from the wings, hooves first
##   (you hear them before you see them). Jump them.
## - The Voice: he fills his chest (red glow) and shouts through the megaphone: a wave
##   along the floor both ways. Jump it. Then he is out of breath, bent double, open.
## From half health he lies: the sign names one act and he does another. The tells
## never lie: cards glint in his hand, hooves drum in the wings, he swells to shout.
## Cuts while he is closed glance off. Hold and the Unstitch: BossStagger.

enum State { WAITING, STRUT, ANNOUNCE, KNIFE, STAMPEDE, VOICE, WINDED, STUNNED, DEFEATED }
enum Act { KNIFE, STAMPEDE, VOICE }

const ART := preload("res://assets/art/dark/enemies/barker.png")
const HORSE := preload("res://assets/art/dark/enemies/carousel_horse.png")
const ACT_NAMES := ["THE KNIFE-THROWER!", "THE GALLOPING STAMPEDE!", "THE VOICE THAT FILLS THE TENT!"]
## Where his card hand and his megaphone are on the art, from his feet (facing left).
const HAND := Vector2(90, -400)
const HORN := Vector2(-170, -440)

@export var boss_name := "The Barker"
@export var exit_door: PageDoor
@export var start_zone: Area2D
@export var arena_left := 360.0
@export var arena_right := 1640.0
@export var floor_y := 896.0
@export var keep_away := 520.0
@export var card_speed := 820.0
@export var horse_speed := 980.0
@export var wave_speed := 760.0
## Seconds the act's sign hangs before the act, per half of his health.
@export var announce_time: Array[float] = [1.1, 0.9]
@export var rests: Array[float] = [1.3, 0.95]
@export var winded_time := 2.6
@export var stun_time := 2.4
@export var defeated_flag := "boss_barker_defeated"
@export var defeat_dialogue := "barker_yields"

var state := State.WAITING
var act := Act.KNIFE
## What the sign said this time (from half health, not always `act`).
var announced := Act.KNIFE
var acts_done := 0
var lies_told := 0
var art: Sprite2D
var body_hurt: Hurtbox
var hold: HoldComponent
var sign_label: Label
var bestiary_id := "barker"
@onready var health: HealthComponent = $HealthComponent

var _rest_left := 1.6
var _tween: Tween
var _open := false
var _told := {}
var _facing := -1.0


func _ready() -> void:
	_build()
	hold = BossStagger.attach(self)
	hold.broken.connect(_on_hold_broken)
	body_hurt.hit.connect(_on_hit)
	health.died.connect(_on_defeated)
	if start_zone:
		start_zone.body_entered.connect(func(b: Node2D) -> void:
			if b is Patch:
				start_fight())
	if GameState.get_flag(defeated_flag) and not Rematch.watch(self):
		_show_exit()
		queue_free()
		return
	if exit_door:
		exit_door.visible = false
		exit_door.set_deferred("monitorable", false)


func _build() -> void:
	art = Sprite2D.new()
	art.texture = ART
	art.offset = Vector2(0, -ART.get_height() / 2.0)
	add_child(art)
	body_hurt = Hurtbox.new()
	body_hurt.collision_layer = 0
	body_hurt.collision_mask = 8
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 70.0
	capsule.height = 460.0
	shape.shape = capsule
	shape.position = Vector2(0, -250)
	body_hurt.add_child(shape)
	add_child(body_hurt)
	body_hurt.owner = self
	sign_label = Label.new()
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_label.size = Vector2(900, 60)
	sign_label.position = Vector2(-450, -660)
	sign_label.add_theme_font_size_override(&"font_size", 52)
	sign_label.add_theme_color_override(&"font_color", Color(0.95, 0.85, 0.6))
	sign_label.add_theme_color_override(&"font_outline_color", Color(0.12, 0.05, 0.04))
	sign_label.add_theme_constant_override(&"outline_size", 10)
	sign_label.modulate.a = 0.0
	add_child(sign_label)


func start_fight() -> void:
	if state != State.WAITING:
		return
	state = State.STRUT
	_rest_left = 1.4
	EventBus.boss_started.emit(boss_name, health.max_health)
	DialogueUI.narrate("\"ROLL UP! Roll up! A late arrival, ladies and gentlemen, a FOX, and only a little damp! Sit anywhere. Nobody leaves. The show goes on!\"")


## 0 or 1: which half of his health he is in.
func phase() -> int:
	return 1 if health.current <= health.max_health / 2 else 0


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if state != State.STRUT:
		return
	var player := _player()
	if player == null:
		return
	_facing = -1.0 if player.global_position.x < global_position.x else 1.0
	art.flip_h = _facing > 0.0
	var side := -_facing
	var want := clampf(player.global_position.x + keep_away * side, arena_left + 80.0, arena_right - 80.0)
	if absf(want - player.global_position.x) < keep_away * 0.6:
		want = clampf(player.global_position.x - keep_away * side, arena_left + 80.0, arena_right - 80.0)
	global_position.x = move_toward(global_position.x, want, 260.0 * delta)
	art.rotation = sin(Time.get_ticks_msec() * 0.006) * 0.03
	_rest_left -= delta
	if _rest_left <= 0.0:
		_announce()


# --- The acts ---------------------------------------------------------------------

func _next_act() -> Act:
	if phase() == 0:
		return [Act.KNIFE, Act.STAMPEDE, Act.VOICE][acts_done % 3]
	var choices := [Act.KNIFE, Act.STAMPEDE, Act.VOICE]
	choices.erase(act)
	return choices[randi() % choices.size()]


func _announce() -> void:
	state = State.ANNOUNCE
	art.rotation = 0.0
	act = _next_act()
	announced = act
	if phase() == 1 and (lies_told == 0 or randf() < 0.65):
		var others := [Act.KNIFE, Act.STAMPEDE, Act.VOICE]
		others.erase(act)
		announced = others[randi() % others.size()]
		lies_told += 1
		_say("lies", "He was lying now. Patch knew the sound of it. He'd made that sound himself, for years.")
	sign_label.text = ACT_NAMES[announced]
	var t := announce_time[phase()]
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(sign_label, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(t * 0.4)
	# The true tell, whatever the sign says.
	_tween.tween_callback(_tell)
	_tween.tween_interval(t * 0.6)
	_tween.tween_property(sign_label, "modulate:a", 0.0, 0.15)
	_tween.tween_callback(_perform)
	AudioManager.play_sfx(&"page_flip", 0.6)


func _tell() -> void:
	match act:
		Act.KNIFE:
			Tells.glint(self, Vector2(HAND.x * -_facing, HAND.y), 1.3)
			AudioManager.play_sfx(&"page_flip", 1.4)
		Act.STAMPEDE:
			_dust(_far_wing())
			AudioManager.play_sfx(&"slam", 0.5, -6.0)
		Act.VOICE:
			Tells.red_glow(art, 0.7)
			var swell := create_tween()
			swell.tween_property(art, "scale", Vector2(1.08, 1.06), 0.6)


func _perform() -> void:
	acts_done += 1
	match act:
		Act.KNIFE:
			_knife()
		Act.STAMPEDE:
			_stampede()
		Act.VOICE:
			_voice()


func _done_act(rest_scale := 1.0) -> void:
	if state == State.DEFEATED:
		return
	state = State.STRUT
	_rest_left = rests[phase()] * rest_scale


## The Knife-Thrower: red, red, white.
func _knife() -> void:
	state = State.KNIFE
	_kill_tween()
	_tween = create_tween()
	for i in 3:
		_tween.tween_callback(_throw.bind(i == 2))
		_tween.tween_interval(0.42 if i < 2 else 0.6)
	_tween.tween_callback(func() -> void:
		if state == State.KNIFE:
			_done_act())


func _throw(white: bool) -> void:
	if state != State.KNIFE:
		return
	var player := _player()
	if player == null:
		return
	var card := BarkerCard.new()
	card.parryable = white
	card.thrower = self
	var from := global_position + Vector2(HAND.x * -_facing, HAND.y)
	card.velocity = (player.global_position + Vector2(0, -56) - from).normalized() * card_speed
	get_parent().add_child(card)
	card.global_position = from
	if white:
		Tells.glint(card, Vector2.ZERO, 0.9)
	AudioManager.play_sfx(&"swipe", 1.3 if white else 1.1, -2.0)
	var flick := create_tween()
	flick.tween_property(art, "rotation", 0.1 * -_facing, 0.08)
	flick.tween_property(art, "rotation", 0.0, 0.15)


## The white card came back to him: he's cut open, reeling.
func card_returned() -> void:
	if state == State.DEFEATED:
		return
	_kill_tween()
	state = State.STUNNED
	_say("card", "His own card took him across the face. The painted grin split, and for a moment there was nothing behind it but grey.")
	_set_open(true)
	AudioManager.play_sfx(&"hit_wet", 0.7)
	_tween = create_tween()
	_tween.tween_property(art, "rotation", 0.35 * _facing, 0.2).set_trans(Tween.TRANS_BACK)
	_tween.tween_interval(stun_time)
	_tween.tween_callback(func() -> void:
		if state == State.STUNNED and not hold.is_broken():
			_recover())


func _far_wing() -> float:
	var player := _player()
	var px := player.global_position.x if player else global_position.x
	# The horses come from whichever wing is farther from Patch, so he sees them coming.
	return arena_left - 320.0 if px > (arena_left + arena_right) / 2.0 else arena_right + 320.0


## The Stampede: two horses (three from half health) across the ring.
func _stampede() -> void:
	state = State.STAMPEDE
	var from := _far_wing()
	var count := 2 + phase()
	_kill_tween()
	_tween = create_tween()
	for i in count:
		_tween.tween_callback(_gallop.bind(from))
		_tween.tween_interval(0.85)
	_tween.tween_interval(0.6)
	_tween.tween_callback(func() -> void:
		if state == State.STAMPEDE:
			_done_act(0.8))


func _gallop(from: float) -> void:
	if state == State.DEFEATED:
		return
	var dir := 1.0 if from < arena_left else -1.0
	var horse := Node2D.new()
	horse.add_to_group(&"barker_horses")
	var sprite := Sprite2D.new()
	sprite.texture = HORSE
	sprite.scale = Vector2(0.55, 0.55)
	sprite.offset = Vector2(0, -HORSE.get_height() / 2.0)
	sprite.flip_h = dir > 0.0
	horse.add_child(sprite)
	var hit := Hitbox.new()
	hit.collision_layer = 16
	hit.collision_mask = 0
	hit.monitoring = false
	hit.damage = 2
	hit.knockback = 700.0
	hit.unblockable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150, 96)
	shape.shape = rect
	shape.position = Vector2(0, -48)
	hit.add_child(shape)
	horse.add_child(hit)
	get_parent().add_child(horse)
	horse.global_position = Vector2(from, floor_y)
	var to := arena_right + 360.0 if dir > 0.0 else arena_left - 360.0
	var t := horse.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(horse, "global_position:x", to, absf(to - from) / horse_speed)
	t.parallel().tween_method(func(k: float) -> void:
		sprite.position.y = -absf(sin(k * 9.0)) * 26.0, 0.0, PI, absf(to - from) / horse_speed)
	t.tween_callback(horse.queue_free)
	AudioManager.play_sfx(&"slam", 0.55, -3.0)
	_say("stampede", "They came out of the dark at the edge of the ring, hooves first, eyes like holes. Not one of them had a rider.")


## The Voice: a wave along the floor both ways, then he's winded.
func _voice() -> void:
	state = State.VOICE
	art.scale = Vector2.ONE
	AudioManager.play_sfx(&"slam", 0.4)
	AudioManager.play_sfx(&"enemy_pop", 0.4, -2.0)
	for dir in [-1.0, 1.0]:
		_wave(dir)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(art, "scale", Vector2(0.94, 0.9), 0.3)
	_tween.tween_callback(_winded)


func _wave(dir: float) -> void:
	var wave := Node2D.new()
	wave.add_to_group(&"barker_waves")
	var ripple := Polygon2D.new()
	ripple.polygon = PackedVector2Array([Vector2(-40, 0), Vector2(-20, -54), Vector2(0, -66), Vector2(20, -54), Vector2(40, 0)])
	ripple.color = Color(0.9, 0.82, 0.7, 0.7)
	wave.add_child(ripple)
	var hit := Hitbox.new()
	hit.collision_layer = 16
	hit.collision_mask = 0
	hit.monitoring = false
	hit.damage = 2
	hit.knockback = 620.0
	hit.unblockable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 60)
	shape.shape = rect
	shape.position = Vector2(0, -30)
	hit.add_child(shape)
	wave.add_child(hit)
	get_parent().add_child(wave)
	wave.global_position = Vector2(global_position.x + dir * 60.0, floor_y)
	var to := arena_right + 200.0 if dir > 0.0 else arena_left - 200.0
	var t := wave.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(wave, "global_position:x", to, absf(to - wave.global_position.x) / wave_speed)
	t.tween_callback(wave.queue_free)


func _winded() -> void:
	if state != State.VOICE:
		return
	state = State.WINDED
	_say("winded", "He'd shouted himself empty. He bent double over the megaphone, wheezing, his painted grin still grinning.")
	_set_open(true)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(art, "rotation", 0.28 * _facing, 0.3)
	_tween.tween_interval(winded_time)
	_tween.tween_callback(func() -> void:
		if state == State.WINDED and not hold.is_broken():
			_recover())


func _recover() -> void:
	if state == State.DEFEATED:
		return
	_set_open(false)
	BossStagger.close(hold)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(art, "rotation", 0.0, 0.3)
	_tween.parallel().tween_property(art, "scale", Vector2.ONE, 0.3)
	_tween.tween_callback(_done_act)
	state = State.ANNOUNCE


func _dust(x: float) -> void:
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.emitting = true
	dust.amount = 40
	dust.lifetime = 0.9
	dust.explosiveness = 0.5
	dust.direction = Vector2(1.0 if x < arena_left else -1.0, -0.4)
	dust.spread = 30.0
	dust.initial_velocity_min = 200.0
	dust.initial_velocity_max = 460.0
	dust.scale_amount_min = 4.0
	dust.scale_amount_max = 10.0
	dust.color = Color(0.7, 0.62, 0.5, 0.6)
	get_parent().add_child(dust)
	dust.global_position = Vector2(clampf(x, arena_left - 40.0, arena_right + 40.0), floor_y - 30.0)
	get_tree().create_timer(1.5, false).timeout.connect(dust.queue_free)


# --- Being cut ------------------------------------------------------------------

func _on_hit(hitbox: Hitbox) -> void:
	if state == State.DEFEATED:
		return
	if not _open:
		if not health.is_invulnerable():
			AudioManager.play_sfx(&"parry", 1.5, -8.0)
			health.grant_invulnerability(0.25)
		return
	if health.take_damage(hitbox.damage, hitbox.global_position):
		EventBus.boss_health_changed.emit(health.current, health.max_health)
		AudioManager.play_sfx(&"hit_wet", 0.9)
		art.modulate = Color(1.8, 1.6, 1.5)
		create_tween().tween_property(art, "modulate", Color.WHITE, 0.2)


func can_stagger() -> bool:
	return state == State.STUNNED or state == State.WINDED


func is_open() -> bool:
	return _open


func finisher_point() -> Vector2:
	return global_position + Vector2(0, -300)


func _on_hold_broken() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	get_tree().create_timer(hold.stagger_time, false).timeout.connect(func() -> void:
		if state == State.STUNNED or state == State.WINDED:
			_recover())


func unstitch(_by: Node) -> void:
	if not can_stagger():
		return
	AudioManager.play_sfx(&"enemy_pop", 0.5)
	if BossStagger.unstitch(self, health, hold):
		DialogueUI.narrate("Patch cut the string at his jaw. The grin dropped open, and stayed open, and still he tried to talk.")
		get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
			if state == State.STUNNED or state == State.WINDED:
				_recover())


func _on_defeated() -> void:
	if Rematch.intercept(self):
		return
	state = State.DEFEATED
	_kill_tween()
	_set_open(false)
	sign_label.modulate.a = 0.0
	Bestiary.record(self)
	GameState.set_flag(defeated_flag)
	EventBus.boss_defeated.emit()
	for group in [&"barker_cards", &"barker_horses", &"barker_waves"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	# The strings go slack one at a time, and he folds down onto the sawdust.
	var t := create_tween().set_parallel()
	t.tween_property(art, "scale", Vector2(1.0, 0.55), 1.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(art, "rotation", 0.2 * _facing, 1.6)
	t.tween_property(self, "modulate", Color(0.72, 0.7, 0.72), 1.6)
	await t.finished
	if not defeat_dialogue.is_empty():
		DialogueUI.start(defeat_dialogue)
		await EventBus.dialogue_finished
	_show_exit()
	GameState.save_game()


func _show_exit() -> void:
	if exit_door:
		exit_door.visible = true
		exit_door.set_deferred("monitorable", true)


func _set_open(open: bool) -> void:
	_open = open
	art.self_modulate = Color.WHITE if open else Color(0.84, 0.82, 0.88)


func _say(key: String, line: String) -> void:
	if _told.has(key):
		return
	_told[key] = true
	DialogueUI.narrate(line)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

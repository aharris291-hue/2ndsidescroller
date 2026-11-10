class_name BossRedactor
extends Node2D
## The Redactor, the Index's boss (Phase 3): the book's archivist, a gaunt thing of
## folded index cards with a blank oval for a face and a bar of ink across where its
## eyes should be. Since the flood it has been going through the Index with its pen,
## striking out every entry that hurts: THE FLOOD, THAT NIGHT, DRIZZLE. It has got as
## far as P. A duel on the last page of the book. Its origin is its feet.
##
## It does three things, and the tells never lie:
## - Strike: a thin red line runs down the page where Patch stands, and then the pen
##   comes down it: a bar of ink from top to floor. Step out of the line. Twice (three
##   times from half health). A ribbon caught in the line is struck out too.
## - Stamp: it glides in close, lifts the iron stamp over its head (it glints) and
##   brings it down in front of itself. Get out from under it. The stamp sticks in the
##   page and pins its arm: it's open.
## - Redact: a red box rules itself round Patch, and then the box is real: walls too
##   tall to jump, and the ink rises in it. Nothing gets out of a redaction, except a
##   fox who left Gran's ribbon somewhere outside the lines (Bookmark Warp). Get out and
##   it has spent its ink: it shakes the pen, wide open. Stay in and the ink takes two.
## From half health a silverfish comes up out of the page after each redaction (no
## more than two at once), and they go for the ribbon.
## Cuts while it is closed glance off. Hold and the Unstitch: BossStagger.

enum State { WAITING, DRIFT, STRIKE, STAMP, REDACT, PINNED, SPENT, DEFEATED }
enum Move { STRIKE, STAMP, REDACT }

const ART := preload("res://assets/art/dark/enemies/redactor.png")
const SILVERFISH := preload("res://scenes/enemies/silverfish.tscn")
const INK := Color(0.05, 0.04, 0.05)
const RED := Color(0.85, 0.1, 0.08)
## Where the stamp comes down, in front of its feet (facing left).
const STAMP_REACH := 230.0
const STAMP_SIZE := Vector2(190, 80)

@export var boss_name := "The Redactor"
@export var exit_door: PageDoor
@export var start_zone: Area2D
@export var arena_left := 360.0
@export var arena_right := 1640.0
@export var floor_y := 896.0
@export var ceiling_y := 200.0
@export var keep_away := 480.0
## Seconds the red line shows before the pen comes down it, per half of its health.
@export var strike_tell: Array[float] = [0.6, 0.45]
@export var stamp_tell := 0.7
@export var box_tell: Array[float] = [0.5, 0.42]
## Seconds the ink takes to fill a box once it is shut.
@export var box_fill := 1.1
@export var box_size := Vector2(448, 420)
@export var rests: Array[float] = [1.2, 0.85]
@export var pinned_time := 1.7
@export var spent_time := 2.8
@export var max_silverfish := 2
@export var defeated_flag := "boss_redactor_defeated"
@export var defeat_dialogue := "redactor_yields"

var state := State.WAITING
var move := Move.STRIKE
var moves_done := 0
var redactions := 0
## Times Patch was caught in a box / got out of one (for tests and lines).
var caught := 0
var escaped := 0
var art: Sprite2D
var body_hurt: Hurtbox
var hold: HoldComponent
var bestiary_id := "redactor"
@onready var health: HealthComponent = $HealthComponent

var _rest_left := 1.4
var _tween: Tween
var _open := false
var _told := {}
var _facing := -1.0
var _box: RedactBox
var _last_redact := 0
var _stamp_node: Node2D
var _stamp_hit: Hitbox


func _ready() -> void:
	_build()
	hold = BossStagger.attach(self)
	hold.broken.connect(_on_hold_broken)
	body_hurt.hit.connect(_on_hit)
	health.died.connect(_on_defeated)
	if start_zone:
		start_zone.body_entered.connect(func(b: Node2D) -> void:
			if b.is_in_group(&"player"):
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
	capsule.radius = 90.0
	capsule.height = 520.0
	shape.shape = capsule
	shape.position = Vector2(0, -280)
	body_hurt.add_child(shape)
	add_child(body_hurt)
	body_hurt.owner = self


func start_fight() -> void:
	if state != State.WAITING:
		return
	state = State.DRIFT
	_rest_left = 1.6
	EventBus.boss_started.emit(boss_name, health.max_health)
	DialogueUI.narrate("It turned its blank face to him, slowly, the way you look up from a page to see who has come in. Then it uncapped the pen. Patch thought of Gran, who never lost her place in a book. She left a ribbon in it.")


## 0 or 1: which half of its health it is in.
func phase() -> int:
	return 1 if health.current <= health.max_health / 2 else 0


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if state != State.DRIFT:
		return
	var player := _player()
	if player == null:
		return
	_face(player.global_position.x)
	# It drifts, robe trailing, to keep the length of a page between them.
	var side := -_facing
	var want := clampf(player.global_position.x + keep_away * side, arena_left + 90.0, arena_right - 90.0)
	if absf(want - player.global_position.x) < keep_away * 0.6:
		want = clampf(player.global_position.x - keep_away * side, arena_left + 90.0, arena_right - 90.0)
	global_position.x = move_toward(global_position.x, want, 200.0 * delta)
	art.rotation = sin(Time.get_ticks_msec() * 0.004) * 0.025
	_rest_left -= delta
	if _rest_left <= 0.0:
		_next()


func _face(x: float) -> void:
	_facing = -1.0 if x < global_position.x else 1.0
	art.flip_h = _facing > 0.0


# --- The moves ----------------------------------------------------------------------

func _next() -> void:
	art.rotation = 0.0
	if phase() == 0:
		move = [Move.STRIKE, Move.STAMP, Move.REDACT][moves_done % 3]
	else:
		var choices := [Move.STRIKE, Move.STAMP, Move.REDACT]
		choices.erase(move)
		# Never more than two moves without a redaction.
		move = Move.REDACT if moves_done - _last_redact >= 2 else choices[randi() % choices.size()]
	moves_done += 1
	match move:
		Move.STRIKE:
			_strike()
		Move.STAMP:
			_stamp()
		Move.REDACT:
			_redact()



func _done(rest_scale := 1.0) -> void:
	if state == State.DEFEATED:
		return
	state = State.DRIFT
	_rest_left = rests[phase()] * rest_scale


## Strike: the pen comes down a red line, two or three times.
func _strike() -> void:
	state = State.STRIKE
	_kill_tween()
	_tween = create_tween()
	var count := 2 + phase()
	for i in count:
		_tween.tween_callback(_line)
		_tween.tween_interval(strike_tell[phase()] * 0.75)
	_tween.tween_interval(strike_tell[phase()] + 0.4)
	_tween.tween_callback(func() -> void:
		if state == State.STRIKE:
			_done())
	var lift := create_tween()
	lift.tween_property(art, "rotation", 0.08 * _facing, 0.2)
	_say("strike", "It drew a line down the page through where he stood, as neat as a ruler. Then the pen came down it.")


func _line() -> void:
	if state != State.STRIKE:
		return
	var player := _player()
	if player == null:
		return
	var x := clampf(player.global_position.x, arena_left + 40.0, arena_right - 40.0)
	var strike := Node2D.new()
	strike.add_to_group(&"redactor_strikes")
	strike.z_index = 4
	get_parent().add_child(strike)
	strike.global_position = Vector2(x, floor_y)
	var height := floor_y - ceiling_y
	# The tell: a ruled red line, and a faint band either side of it, the bar's width.
	var tell := Node2D.new()
	var band := Polygon2D.new()
	band.color = Color(RED, 0.24)
	band.polygon = PackedVector2Array([Vector2(-44, -height), Vector2(44, -height), Vector2(44, 0), Vector2(-44, 0)])
	tell.add_child(band)
	var rule := Line2D.new()
	rule.width = 6.0
	rule.default_color = Color(RED, 0.95)
	rule.points = PackedVector2Array([Vector2(0, -height), Vector2.ZERO])
	tell.add_child(rule)
	strike.add_child(tell)
	var pulse := tell.create_tween().set_loops(8)
	pulse.tween_property(tell, "modulate:a", 0.45, 0.07)
	pulse.tween_property(tell, "modulate:a", 1.0, 0.07)
	# The bar: drawn from the top of the page down, so it grows downwards.
	var bar := Polygon2D.new()
	bar.color = INK
	bar.polygon = PackedVector2Array([Vector2(-44, 0), Vector2(44, 0), Vector2(40, height), Vector2(-46, height)])
	bar.scale = Vector2(1, 0)
	bar.position = Vector2(0, -height)
	strike.add_child(bar)
	var hit := _hitbox(Vector2(80, height), Vector2(0, -height / 2.0), 1, 520.0)
	strike.add_child(hit)
	AudioManager.play_sfx(&"page_flip", 1.6, -6.0)
	var t := strike.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_interval(strike_tell[phase()])
	t.tween_callback(func() -> void:
		tell.visible = false
		hit.active = true
		_strike_out_ribbons(x, 70.0)
		AudioManager.play_sfx(&"slam", 1.3, -4.0))
	# The bar comes down from the top of the page to the floor, fast.
	t.tween_property(bar, "scale:y", 1.0, 0.08)
	t.tween_interval(0.18)
	t.tween_callback(func() -> void: hit.active = false)
	t.tween_property(bar, "modulate:a", 0.0, 0.5)
	t.tween_callback(strike.queue_free)


## Stamp: it glides in, lifts the stamp, and brings it down in front of itself.
func _stamp() -> void:
	state = State.STAMP
	var player := _player()
	if player == null:
		_done()
		return
	_face(player.global_position.x)
	var to := clampf(player.global_position.x - STAMP_REACH * _facing, arena_left + 90.0, arena_right - 90.0)
	_kill_tween()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(self, "global_position:x", to, clampf(absf(to - global_position.x) / 900.0, 0.15, 0.6)).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_lift_stamp)
	_tween.parallel().tween_property(art, "rotation", -0.12 * _facing, stamp_tell)
	_tween.tween_interval(stamp_tell)
	_tween.tween_callback(_slam)



## The tell: the stamp hangs over the spot, glinting, its shadow on the floor under it.
func _lift_stamp() -> void:
	if state != State.STAMP:
		return
	var stamp := Node2D.new()
	stamp.add_to_group(&"redactor_stamps")
	stamp.z_index = 4
	get_parent().add_child(stamp)
	stamp.global_position = Vector2(global_position.x + STAMP_REACH * _facing, floor_y)
	var w := STAMP_SIZE.x / 2.0
	var shadow := Polygon2D.new()
	shadow.name = &"Shadow"
	shadow.color = Color(0.0, 0.0, 0.0, 0.45)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * (w + 14.0), sin(a) * 12.0 - 4.0))
	shadow.polygon = pts
	stamp.add_child(shadow)
	var body := Node2D.new()
	body.name = &"Body"
	stamp.add_child(body)
	var rubber := Polygon2D.new()
	rubber.color = Color(0.36, 0.08, 0.07)
	rubber.polygon = PackedVector2Array([Vector2(-w, -18), Vector2(w, -18), Vector2(w, 0), Vector2(-w, 0)])
	body.add_child(rubber)
	var block := Polygon2D.new()
	block.color = Color(0.3, 0.27, 0.25)
	block.polygon = PackedVector2Array([Vector2(-w + 6, -STAMP_SIZE.y), Vector2(w - 6, -STAMP_SIZE.y), Vector2(w, -18), Vector2(-w, -18)])
	body.add_child(block)
	var edge := Line2D.new()
	edge.width = 4.0
	edge.default_color = Color(0.08, 0.06, 0.06)
	edge.closed = true
	edge.points = PackedVector2Array([Vector2(-w + 6, -STAMP_SIZE.y), Vector2(w - 6, -STAMP_SIZE.y), Vector2(w, 0), Vector2(-w, 0)])
	body.add_child(edge)
	var handle := Polygon2D.new()
	handle.color = Color(0.2, 0.13, 0.09)
	handle.polygon = PackedVector2Array([Vector2(-16, -STAMP_SIZE.y), Vector2(16, -STAMP_SIZE.y), Vector2(10, -STAMP_SIZE.y - 90), Vector2(26, -STAMP_SIZE.y - 130),
		Vector2(-26, -STAMP_SIZE.y - 130), Vector2(-10, -STAMP_SIZE.y - 90)])
	body.add_child(handle)
	body.position.y = -460.0
	_stamp_hit = _hitbox(STAMP_SIZE + Vector2(0, 40), Vector2(0, -STAMP_SIZE.y / 2.0), 2, 700.0)
	stamp.add_child(_stamp_hit)
	_stamp_node = stamp
	Tells.glint(body, Vector2(0, -STAMP_SIZE.y - 60.0), 1.4)
	AudioManager.play_sfx(&"page_flip", 0.6)


func _slam() -> void:
	if state != State.STAMP or not is_instance_valid(_stamp_node):
		return
	var stamp := _stamp_node
	var body := stamp.get_node("Body") as Node2D
	var hit := _stamp_hit
	var w := STAMP_SIZE.x / 2.0
	var t := stamp.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(body, "position:y", 0.0, 0.1).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		hit.active = true
		var mark := Polygon2D.new()
		mark.color = INK
		mark.polygon = PackedVector2Array([Vector2(-w - 12, -3), Vector2(w + 12, -3), Vector2(w + 8, 3), Vector2(-w - 10, 3)])
		stamp.add_child(mark)
		AudioManager.play_sfx(&"slam", 0.5)
		_strike_out_ribbons(stamp.global_position.x, w + 20.0))
	t.tween_interval(0.12)
	t.tween_callback(func() -> void: hit.active = false)
	t.tween_interval(pinned_time)
	t.tween_property(body, "position:y", -300.0, 0.3).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(stamp, "modulate:a", 0.0, 0.3)
	t.tween_callback(stamp.queue_free)
	art.rotation = 0.1 * _facing
	_pinned()


func _pinned() -> void:
	state = State.PINNED
	_set_open(true)
	_say("pinned", "The stamp stuck fast in the page, and its long arm with it. For a moment it stood bent over, pinned to its own work.")
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(pinned_time)
	_tween.tween_callback(func() -> void:
		if state == State.PINNED and not hold.is_broken():
			_recover())


## Redact: a box ruled round Patch, then walls, then ink.
func _redact() -> void:
	state = State.REDACT
	_last_redact = moves_done
	redactions += 1
	var player := _player()
	if player == null:
		_done()
		return
	var cx := clampf(player.global_position.x, arena_left + box_size.x / 2.0, arena_right - box_size.x / 2.0)
	_box = RedactBox.new()
	_box.size = box_size
	get_parent().add_child(_box)
	_box.global_position = Vector2(cx, floor_y)
	Tells.red_glow(art, box_tell[phase()])
	AudioManager.play_sfx(&"page_flip", 0.8, -2.0)
	_say("box", "A box ruled itself round him in red, as neat as a margin. It was striking him out.")
	_kill_tween()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(art, "rotation", 0.1 * _facing, 0.2)
	_tween.tween_interval(box_tell[phase()] - 0.2)
	_tween.tween_callback(func() -> void:
		if is_instance_valid(_box):
			_box.shut())
	_tween.tween_interval(box_fill)
	_tween.tween_callback(_flood_box)


func _flood_box() -> void:
	if state != State.REDACT or not is_instance_valid(_box):
		return
	var player := _player()
	var inside := player != null and _box.holds(player.global_position)
	_box.flood()
	if inside:
		caught += 1
		_say("caught", "Ink to the brim, cold and total. Patch came up out of it with half of himself blacked out. Somewhere to come back to, outside the lines. That was what the ribbon was for.")
		_done(1.3)
	else:
		escaped += 1
		_spent()
	if phase() == 1:
		_call_silverfish()


func _spent() -> void:
	state = State.SPENT
	_set_open(true)
	_say("spent", "The box filled with nobody in it. The Redactor shook its pen, and shook it, and nothing came. It had spent its ink on an empty line.")
	AudioManager.play_sfx(&"page_flip", 0.5, -4.0)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(art, "rotation", 0.22 * _facing, 0.3)
	_tween.tween_interval(spent_time)
	_tween.tween_callback(func() -> void:
		if state == State.SPENT and not hold.is_broken():
			_recover())


func _call_silverfish() -> void:
	if get_tree().get_nodes_in_group(&"redactor_silverfish").size() >= max_silverfish:
		return
	var player := _player()
	var px := player.global_position.x if player else global_position.x
	var fish := SILVERFISH.instantiate() as Node2D
	fish.add_to_group(&"redactor_silverfish")
	get_parent().add_child(fish)
	fish.global_position = Vector2(arena_left + 60.0 if px > (arena_left + arena_right) / 2.0 else arena_right - 60.0, floor_y - 4.0)
	_say("fish", "Something came up out of the page where the ink had soaked in: long, pale, hungry. It went straight for the ribbon.")


func _recover() -> void:
	if state == State.DEFEATED:
		return
	_set_open(false)
	BossStagger.close(hold)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(art, "rotation", 0.0, 0.3)
	_tween.tween_callback(_done)
	state = State.STRIKE


## Anything of Gran's ribbon under the pen or the stamp is struck out.
func _strike_out_ribbons(x: float, half_width: float) -> void:
	for r in get_tree().get_nodes_in_group(&"warp_ribbons"):
		var ribbon := r as Node2D
		if absf(ribbon.global_position.x - x) < half_width and ribbon.has_method("eaten"):
			ribbon.eaten()
			_say("ribbon", "The ribbon went under the ink with everything else.")


func _hitbox(size: Vector2, at: Vector2, damage: int, knockback: float) -> Hitbox:
	var hit := Hitbox.new()
	hit.collision_layer = 16
	hit.collision_mask = 0
	hit.monitoring = false
	hit.damage = damage
	hit.knockback = knockback
	hit.unblockable = true
	hit.active = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	hit.add_child(shape)
	return hit


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
	return state == State.PINNED or state == State.SPENT


func is_open() -> bool:
	return _open


func finisher_point() -> Vector2:
	return global_position + Vector2(0, -320)


func _on_hold_broken() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	get_tree().create_timer(hold.stagger_time, false).timeout.connect(func() -> void:
		if state == State.PINNED or state == State.SPENT:
			_recover())


func unstitch(_by: Node) -> void:
	if not can_stagger():
		return
	AudioManager.play_sfx(&"enemy_pop", 0.5)
	if BossStagger.unstitch(self, health, hold):
		DialogueUI.narrate("Patch cut the bar across its face. Under it, nothing: no eyes, only more paper, and on it, very faint, a name it had struck out first of all. Its own.")
		get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
			if state == State.PINNED or state == State.SPENT:
				_recover())


func _on_defeated() -> void:
	if Rematch.intercept(self):
		return
	state = State.DEFEATED
	_kill_tween()
	_set_open(false)
	Bestiary.record(self)
	GameState.set_flag(defeated_flag)
	EventBus.boss_defeated.emit()
	for group in [&"redactor_strikes", &"redactor_stamps", &"redactor_boxes", &"redactor_silverfish"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	# The cards it is made of come loose and settle, one by one, face up.
	var t := create_tween().set_parallel()
	t.tween_property(art, "scale", Vector2(1.1, 0.4), 1.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(art, "rotation", 0.15 * _facing, 1.8)
	t.tween_property(self, "modulate", Color(0.85, 0.82, 0.78), 1.8)
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
	art.self_modulate = Color.WHITE if open else Color(0.8, 0.8, 0.86)


func _say(key: String, line: String) -> void:
	if _told.has(key):
		return
	_told[key] = true
	DialogueUI.narrate(line)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

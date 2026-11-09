class_name BossBindwell
extends Node2D
## Old Bindwell, the Spine Peaks' boss (Phase 3): the bookbinder's needle who sewed the
## spine shut the night of the flood and didn't open it when the low pages knocked.
## A duel on the workshop floor. Its origin is the needle's point, on the floor.
##
## - Stitch: three hopping stabs, point first. The first two glow red (they can't be
##   guarded: dodge them); the third glints white and can be parried. A parry knocks
##   him off balance and opens him to the shears; a missed third stab sticks in the
##   boards for a moment, a shorter opening.
## - Thread snare (from two thirds health): he flicks a line of red thread along the
##   floor at chest height. Caught, Patch is reeled in to a stab. Jump it.
## - Sewing the floor shut (last third): between stitches he sews a length of floor at
##   one end of the room into a seam of red thread that cuts anything standing on it,
##   until the room is a narrow strip in the middle.
## Cuts while he is closed only glance off his steel. Hold and the Unstitch: BossStagger.

enum State { WAITING, STALK, WINDUP, STAB, STUCK, STUNNED, SNARE, SEW, DEFEATED }

const ART := preload("res://assets/art/dark/friends/bindwell.png")
const SCALE := 1.1
## The point in the art (px), which is the node's origin.
const POINT := Vector2(83.5, 420.0)

@export var boss_name := "Old Bindwell"
@export var exit_door: PageDoor
@export var start_zone: Area2D
@export var arena_left := 360.0
@export var arena_right := 1640.0
@export var floor_y := 896.0
@export var keep_away := 300.0
@export var drift_speed := 220.0
## Wind-up before each stab of a combo, per third of his health.
@export var windups: Array[float] = [0.45, 0.38, 0.32]
@export var rests: Array[float] = [1.2, 1.0, 0.85]
@export var stun_time := 2.2
@export var stuck_time := 0.8
@export var seam_width := 256.0
@export var defeated_flag := "boss_bindwell_defeated"
@export var defeat_dialogue := "bindwell_yields"

var state := State.WAITING
var combos := 0
var stab_index := 0
var seams: Array[Node2D] = []
var snared := 0.0
var art: Sprite2D
var point: Hitbox
var body_hurt: Hurtbox
var hold: HoldComponent
var bestiary_id := "bindwell"
@onready var health: HealthComponent = $HealthComponent

var _rest_left := 1.4
var _tween: Tween
var _open := false
var _told := {}
var _sewn_left := 0
var _sewn_right := 0


func _ready() -> void:
	_build()
	hold = BossStagger.attach(self)
	hold.broken.connect(_on_hold_broken)
	body_hurt.hit.connect(_on_hit)
	health.died.connect(_on_defeated)
	point.active = false
	if start_zone:
		start_zone.body_entered.connect(func(b: Node2D) -> void:
			if b is Patch:
				start_fight())
	if GameState.get_flag(defeated_flag):
		_show_exit()
		queue_free()
		return
	if exit_door:
		exit_door.visible = false
		exit_door.set_deferred("monitorable", false)


func _build() -> void:
	art = Sprite2D.new()
	art.texture = ART
	art.centered = false
	art.scale = Vector2(SCALE, SCALE)
	art.position = -POINT * SCALE
	add_child(art)
	point = Hitbox.new()
	point.collision_layer = 16
	point.collision_mask = 0
	point.monitoring = false
	point.damage = 2
	point.knockback = 620.0
	var tip := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 120)
	tip.shape = rect
	tip.position = Vector2(0, -60)
	point.add_child(tip)
	add_child(point)
	body_hurt = Hurtbox.new()
	body_hurt.collision_layer = 0
	body_hurt.collision_mask = 8
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 52.0
	capsule.height = 340.0
	shape.shape = capsule
	shape.position = Vector2(-6, -300)
	body_hurt.add_child(shape)
	add_child(body_hurt)
	for node: Node in [point, body_hurt]:
		node.owner = self


func start_fight() -> void:
	if state != State.WAITING:
		return
	state = State.STALK
	_rest_left = 1.2
	EventBus.boss_started.emit(boss_name, health.max_health)
	DialogueUI.narrate("\"Go back down, fox. There's nothing up here for anyone who came from down there.\" The needle turned its point to him.")


## 0, 1 or 2: which third of his health he is in.
func phase() -> int:
	return clampi(3 - ceili(float(health.current) / health.max_health * 3.0), 0, 2)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if snared > 0.0:
		snared -= delta
		var patch := _player() as Patch
		if patch:
			patch.push.x += signf(global_position.x - patch.global_position.x) * 560.0
	if state != State.STALK:
		return
	var player := _player()
	if player == null:
		return
	var side := 1.0 if player.global_position.x < global_position.x else -1.0
	art.flip_h = side < 0.0
	var want := clampf(player.global_position.x + keep_away * side, _floor_left() + 60.0, _floor_right() - 60.0)
	global_position.x = move_toward(global_position.x, want, drift_speed * delta)
	art.position.y = -POINT.y * SCALE + sin(Time.get_ticks_msec() * 0.004) * 6.0 - 8.0
	_rest_left -= delta
	if _rest_left > 0.0:
		return
	combos += 1
	if phase() == 2 and combos % 2 == 0 and _can_sew():
		_sew()
	elif phase() >= 1 and combos % 3 == 0:
		_snare()
	else:
		_combo()


# --- Stitch: three hopping stabs ---------------------------------------------

func _combo() -> void:
	stab_index = 0
	_next_stab()


func _next_stab() -> void:
	if state == State.DEFEATED:
		return
	stab_index += 1
	state = State.WINDUP
	var player := _player()
	var target_x := player.global_position.x if player else global_position.x
	target_x = clampf(target_x, _floor_left() + 40.0, _floor_right() - 40.0)
	var windup := windups[phase()]
	var last := stab_index == 3
	point.unblockable = not last
	if last:
		Tells.glint(self, Vector2(0, -60), windup)
	else:
		Tells.red_glow(art, windup)
	AudioManager.play_sfx(&"swipe", 0.6 if last else 0.8, -4.0)
	_kill_tween()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# Up and back on the thread, then point first onto the mark.
	_tween.tween_property(self, "global_position", Vector2(global_position.x + signf(global_position.x - target_x) * 40.0, floor_y - 170.0), windup).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(art, "rotation", 0.18 * signf(target_x - global_position.x), windup)
	_tween.tween_callback(func() -> void:
		state = State.STAB
		point.active = true)
	_tween.tween_property(self, "global_position", Vector2(target_x, floor_y), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(art, "rotation", 0.0, 0.13)
	_tween.tween_callback(_landed)


func _landed() -> void:
	if state != State.STAB:
		return
	AudioManager.play_sfx(&"slam", 0.6, -2.0)
	get_tree().create_timer(0.1, false).timeout.connect(func() -> void: point.active = false)
	if stab_index < 3:
		_kill_tween()
		_tween = create_tween()
		_tween.tween_interval(0.22)
		_tween.tween_callback(_next_stab)
		return
	# The third stab, not parried: the point sticks in the boards.
	state = State.STUCK
	_say("stuck", "The point went into the boards and stayed there. He pulled, and swore, and pulled.")
	_set_open(true)
	_kill_tween()
	_tween = create_tween()
	for i in 4:
		_tween.tween_property(art, "rotation", 0.05, stuck_time / 8.0)
		_tween.tween_property(art, "rotation", -0.05, stuck_time / 8.0)
	_tween.tween_callback(func() -> void:
		if state == State.STUCK:
			_recover())


## Patch parried the third stab: Bindwell is knocked off balance, wide open.
func on_parried(_by: Node) -> void:
	if state == State.DEFEATED:
		return
	_kill_tween()
	point.active = false
	state = State.STUNNED
	_say("parried", "Steel on steel. The old needle rang like a bell and staggered, and for a moment he was only a thing made of wire.")
	_set_open(true)
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(self, "global_position:y", floor_y, 0.2)
	_tween.parallel().tween_property(art, "rotation", 0.5 * (1.0 if art.flip_h else -1.0), 0.25).set_trans(Tween.TRANS_BACK)
	_tween.tween_interval(stun_time)
	_tween.tween_callback(func() -> void:
		if state == State.STUNNED and not hold.is_broken():
			_recover())


func _recover() -> void:
	if state == State.DEFEATED:
		return
	_set_open(false)
	BossStagger.close(hold)
	point.active = false
	state = State.WINDUP
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(art, "rotation", 0.0, 0.3)
	_tween.parallel().tween_property(self, "global_position:y", floor_y, 0.3)
	_tween.tween_callback(func() -> void:
		if state != State.DEFEATED:
			state = State.STALK
			_rest_left = rests[phase()])


# --- Thread snare ------------------------------------------------------------

func _snare() -> void:
	state = State.SNARE
	_say("snare", "He flicked his thread out along the floor, quick as a whip.")
	var player := _player()
	var dir := signf(player.global_position.x - global_position.x) if player else -1.0
	var line := Area2D.new()
	line.collision_layer = 0
	line.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90, 40)
	shape.shape = rect
	line.add_child(shape)
	var drawn := Line2D.new()
	drawn.width = 5.0
	drawn.default_color = Color(0.55, 0.06, 0.08)
	line.add_child(drawn)
	line.position = Vector2(global_position.x, floor_y - 62.0)
	line.add_to_group(&"bindwell_snares")
	get_parent().add_child(line)
	var start_x := global_position.x
	var caught := false
	line.body_entered.connect(func(b: Node2D) -> void:
		if b is Patch and not caught and state == State.SNARE:
			caught = true
			snared = 0.8
			AudioManager.play_sfx(&"grapple", 0.6)
			_say("caught", "The thread bit into him and pulled."))
	var far := arena_left - 200.0 if dir < 0.0 else arena_right + 200.0
	var t := line.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_method(func(x: float) -> void:
		line.position.x = x
		drawn.points = PackedVector2Array([Vector2(start_x - x, -40), Vector2(0, 0)]), start_x, far, absf(far - start_x) / 900.0)
	t.tween_callback(line.queue_free)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(absf(far - start_x) / 900.0 * 0.6)
	_tween.tween_callback(func() -> void:
		if state != State.SNARE:
			return
		if caught:
			_combo()
		else:
			state = State.STALK
			_rest_left = rests[phase()])


# --- Sewing the floor shut ----------------------------------------------------

func _floor_left() -> float:
	return arena_left + _sewn_left * seam_width


func _floor_right() -> float:
	return arena_right - _sewn_right * seam_width


func _can_sew() -> bool:
	return _floor_right() - _floor_left() > seam_width * 2.5


func _sew() -> void:
	state = State.SEW
	_say("sew", "He bent to the boards and began to sew the floor shut, a length at a time, the way he had sewn the spine.")
	var left := _sewn_left <= _sewn_right
	var x0 := _floor_left() if left else _floor_right() - seam_width
	if left:
		_sewn_left += 1
	else:
		_sewn_right += 1
	var seam := Node2D.new()
	seam.position = Vector2(x0, floor_y)
	var stitches := Line2D.new()
	stitches.width = 6.0
	stitches.default_color = Color(0.6, 0.07, 0.09, 0.35)
	var pts := PackedVector2Array()
	for i in int(seam_width / 16.0) + 1:
		pts.append(Vector2(i * 16.0, -10.0 if i % 2 == 0 else -2.0))
	stitches.points = pts
	seam.add_child(stitches)
	var cut := Hitbox.new()
	cut.collision_layer = 16
	cut.collision_mask = 0
	cut.monitoring = false
	cut.damage = 1
	cut.knockback = 480.0
	cut.unblockable = true
	cut.active = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(seam_width, 40)
	shape.shape = rect
	shape.position = Vector2(seam_width / 2.0, -20)
	cut.add_child(shape)
	seam.add_child(cut)
	seam.add_to_group(&"bindwell_seams")
	get_parent().add_child(seam)
	seams.append(seam)
	# It flickers as it's drawn tight, then it bites.
	var t := seam.create_tween()
	for i in 3:
		t.tween_property(stitches, "default_color:a", 1.0, 0.15)
		t.tween_property(stitches, "default_color:a", 0.35, 0.15)
	t.tween_property(stitches, "default_color:a", 1.0, 0.1)
	t.tween_callback(func() -> void:
		cut.active = true
		AudioManager.play_sfx(&"tab_pull", 0.7))
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(1.1)
	_tween.tween_callback(func() -> void:
		if state == State.SEW:
			state = State.STALK
			_rest_left = rests[phase()] * 0.6
			global_position.x = clampf(global_position.x, _floor_left() + 60.0, _floor_right() - 60.0))


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
		AudioManager.play_sfx(&"hit_wet", 0.8)
		art.modulate = Color(1.8, 1.6, 1.5)
		create_tween().tween_property(art, "modulate", Color.WHITE, 0.2)


func can_stagger() -> bool:
	return state == State.STUNNED or state == State.STUCK


func finisher_point() -> Vector2:
	return global_position + Vector2(0, -300)


func _on_hold_broken() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	get_tree().create_timer(hold.stagger_time, false).timeout.connect(func() -> void:
		if state == State.STUNNED or state == State.STUCK:
			_recover())


func unstitch(_by: Node) -> void:
	if not can_stagger():
		return
	AudioManager.play_sfx(&"enemy_pop", 0.5)
	if BossStagger.unstitch(self, health, hold):
		DialogueUI.narrate("Patch cut the thread at his eye. A whole yard of it came loose and lay on the boards like something dead.")
		get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
			if state == State.STUNNED or state == State.STUCK:
				_recover())


func _on_defeated() -> void:
	state = State.DEFEATED
	_kill_tween()
	point.active = false
	snared = 0.0
	_set_open(false)
	Bestiary.record(self)
	GameState.set_flag(defeated_flag)
	EventBus.boss_defeated.emit()
	for node in get_tree().get_nodes_in_group(&"bindwell_snares"):
		node.queue_free()
	for seam in seams:
		if is_instance_valid(seam):
			var cut := seam.get_child(1) as Hitbox
			cut.active = false
			seam.create_tween().tween_property(seam, "modulate:a", 0.0, 1.2)
	# He doesn't fall. He lies down, very slowly, the way an old man sits.
	var t := create_tween().set_parallel()
	t.tween_property(self, "global_position:y", floor_y, 0.4)
	t.tween_property(art, "rotation", -1.35, 2.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(art, "position", Vector2(-POINT.x * SCALE - 60.0, -POINT.y * SCALE + 80.0), 2.0)
	t.tween_property(self, "modulate", Color(0.75, 0.75, 0.82), 2.0)
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
	art.self_modulate = Color.WHITE if open else Color(0.86, 0.88, 0.95)


func _say(key: String, line: String) -> void:
	if _told.has(key):
		return
	_told[key] = true
	DialogueUI.narrate(line)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

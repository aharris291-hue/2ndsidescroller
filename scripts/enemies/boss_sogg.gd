class_name BossSogg
extends Node2D
## The Sogg, at the bottom of the Gutter (F-2 The Deepest Fold): the finale. Drizzle,
## the little rain cloud Patch pulled away from the night of the flood, went down into
## the ink and came up as this, a wall of pulp and water as tall as the page. Its origin
## is the floor at the foot of the wall, on the right of the arena.
##
## Four phases (Level Design Bible, "The Sogg"):
## 1. The wall. It stands in the water and reaches for him with its arms.
##    - Slam: an arm comes down out of the dark over where he stands, its shadow on
##      the floor; a white glint just before it falls (parry it). Parried, the fist
##      sticks in the floor for a long while; otherwise for a moment. Either way the
##      arm is open while it's down: cut it.
##    - Surge: the wall glows red, then a wave rolls the length of the floor (jump it).
##    From half of this phase, two slams at once, one after the other.
## 2. It splits. The wall falls into the water and comes up as Soggies, wave after
##    wave, some inked. Nothing to cut but them.
## 3. The drain. It pulls itself back together, smaller, and comes out of the wall
##    into the arena: rain over him, and a lunge (red) that leaves it spent and open,
##    the pale cloud showing in its chest. Every few cuts the water goes down a little,
##    a warm light comes from far above (Nell, at the table), and Patch talks to her,
##    and she answers, between the blows.
## 4. The tail. Down to nothing, it's only Drizzle, on the floor, torn. The shears
##    won't cut her. The only way on is to give her the Tape Tail: the tail she held on
##    to that night, to stitch her back. (The fight ends there: the next page is the
##    morning at Gran's table.)
## Cuts glance off whatever isn't open. Hold and the Unstitch: BossStagger.

enum State { WAITING, WALL, SLAM, SURGE, ARM_DOWN, SPLIT, DRAIN, RAIN, LUNGE, SPENT, TAIL, DONE }

const BODY := preload("res://assets/art/dark/bosses/sogg_body.png")
const ARM_ART := preload("res://assets/art/dark/bosses/sogg_arm.png")
const HEART_ART := preload("res://assets/art/dark/bosses/drizzle_heart.png")
const DRIZZLE := preload("res://assets/art/dark/characters/drizzle_pinned.png")
const DRIP := preload("res://scenes/enemies/ink_drip.tscn")
const KINDS := {
	"s": "res://scenes/enemies/soggy.tscn",
	"p": "res://scenes/enemies/ink_spitter.tscn",
	"k": "res://scenes/enemies/tack_knight.tscn",
	"c": "res://scenes/enemies/folded_crane.tscn",
	"m": "res://scenes/enemies/paper_moth.tscn",
}
const WATER := Color(0.04, 0.05, 0.08, 0.82)
## Where the fist comes to rest over the floor while it hangs, before it falls.
const ARM_HANG := 430.0
const FIST_WIDTH := 190.0
## What Patch says, and Drizzle answers, as the water goes down (phase 3).
const DRAIN_LINES := [
	["PATCH: \"Drizzle. It's me. I came down.\"", "THE SOGG: \"You came down. You didn't, then. I called and called.\""],
	["PATCH: \"I heard you. All the way down. I've heard you every night since.\"", "THE SOGG: \"Then why didn't you come back?\""],
	["PATCH: \"Because I was scared, and then I was ashamed, and then I told everyone a storm did it.\"", "THE SOGG: \"...A storm.\""],
	["PATCH: \"It was me. I pulled away. You were holding on and I pulled away.\"", "DRIZZLE, very small: \"I know. I was there.\""],
]

@export var boss_name := "The Sogg"
@export var start_zone: Area2D
@export var arena_left := 192.0
@export var arena_right := 1500.0
@export var floor_y := 896.0
## Damage the wall takes before it splits (phase 1); the rest of its health is the drain.
@export var wall_health := 8
@export var hits_per_stage := 3
@export var slam_tell: Array[float] = [0.85, 0.65]
@export var surge_tell := 0.7
@export var arm_down_time := 1.0
@export var parried_time := 2.4
@export var rests: Array[float] = [1.3, 1.0]
@export var lunge_tell := 0.65
@export var spent_time := 2.2
@export var waves: PackedStringArray = ["sss", "sSps", "SkSc"]
@export var defeated_flag := "boss_sogg_defeated"
@export var tail_dialogue := "sogg_tail"
@export_file("*.tscn") var next_page := "res://scenes/levels/interludes/ending_table.tscn"

var state := State.WAITING
## 0 the wall, 1 split, 2 the drain, 3 the tail.
var phase := 0
var wave := -1
var stage := 0
var slams := 0
var parried := 0
var body: Sprite2D
var heart: Sprite2D
var arms: Array[Node2D] = []
var drizzle: Sprite2D
var flood: Polygon2D
var warm: Sprite2D
var mend: Area2D
var hold: HoldComponent
var bestiary_id := "sogg"
@onready var health: HealthComponent = $HealthComponent

var _rest_left := 1.5
var _open := false
var _tween: Tween
var _alive := 0
var _moves := 0
var _down_arm: Node2D
var _contact: Hitbox
var _heart_hurt: Hurtbox
var _drizzle_hurt: Hurtbox
var _flood_level := 90.0
var _told := {}
var _refused := 0.0


func _ready() -> void:
	_build()
	hold = BossStagger.attach(self)
	hold.broken.connect(_on_hold_broken)
	health.died.connect(_tail)
	if start_zone:
		start_zone.body_entered.connect(func(b: Node2D) -> void:
			if b.is_in_group(&"player"):
				start_fight())
	Rematch.watch(self)


func _build() -> void:
	# Nothing to walk into but pulp: the arena ends a little right of arena_right.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(60, 2000)
	wall_shape.shape = wall_rect
	wall.add_child(wall_shape)
	wall.top_level = true
	add_child(wall)
	wall.global_position = Vector2(arena_right + 130.0, floor_y - 1000.0)
	flood = Polygon2D.new()
	flood.color = WATER
	flood.z_index = 3
	add_child(flood)
	flood.top_level = true
	# Light falling in from far above, soft at the edges (z -1 would put it behind the
	# backdrop).
	warm = Sprite2D.new()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
	fade.colors = PackedColorArray([Color(1, 0.78, 0.45, 0), Color(1, 0.78, 0.45, 1), Color(1, 0.78, 0.45, 1), Color(1, 0.78, 0.45, 0)])
	var across := GradientTexture2D.new()
	across.gradient = fade
	across.width = 256
	across.height = 64
	warm.texture = across
	warm.top_level = true
	warm.z_index = 2
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	warm.material = glow
	warm.scale = Vector2((arena_right - arena_left + 700.0) / 256.0, 1100.0 / 64.0)
	warm.modulate.a = 0.0
	add_child(warm)
	warm.global_position = Vector2((arena_left + arena_right) / 2.0, floor_y - 550.0)
	_set_flood(_flood_level)
	# The wall itself is in the scene (Body); the rest is built here.
	body = get_node_or_null(^"Body") as Sprite2D
	if body == null:
		body = Sprite2D.new()
		body.name = &"Body"
		body.texture = BODY
		body.scale = Vector2(1.45, 1.45)
		body.flip_h = true
		body.offset = Vector2(0, -BODY.get_height() / 2.0 + 30.0)
		add_child(body)
	heart = Sprite2D.new()
	heart.texture = HEART_ART
	heart.position = Vector2(-10, -330)
	heart.modulate = Color(1, 1, 1, 0.0)
	body.add_child(heart)
	# Spent, it slumps: the whole middle of it is in reach, round the pale cloud.
	_heart_hurt = _hurtbox(Vector2(240, 380), Vector2(-14, -230))
	add_child(_heart_hurt)
	_heart_hurt.owner = self
	_heart_hurt.hit.connect(_on_heart_hit)
	_set_monitoring(_heart_hurt, false)
	_contact = _hitbox(Vector2(260, 520), Vector2(0, -260), 2, 600.0, true)
	add_child(_contact)
	_contact.owner = self
	for i in 2:
		var arm := Node2D.new()
		arm.name = "Arm%d" % i
		arm.top_level = true
		arm.z_index = 4
		var art := Sprite2D.new()
		art.name = &"Art"
		art.texture = ARM_ART
		art.offset = Vector2(0, -ARM_ART.get_height() / 2.0)
		art.flip_h = i == 1
		arm.add_child(art)
		var hit := _hitbox(Vector2(FIST_WIDTH, 160), Vector2(0, -80), 2, 420.0, false)
		hit.name = &"Hit"
		arm.add_child(hit)
		var hurt := _hurtbox(Vector2(FIST_WIDTH + 40, 300), Vector2(0, -150))
		hurt.name = &"Hurt"
		arm.add_child(hurt)
		hurt.hit.connect(_on_arm_hit.bind(arm))
		_set_monitoring(hurt, false)
		var shadow := Polygon2D.new()
		shadow.name = &"Shadow"
		var points := PackedVector2Array()
		for k in 20:
			var a := k / 20.0 * TAU
			points.append(Vector2(cos(a) * FIST_WIDTH * 0.7, sin(a) * 18.0))
		shadow.polygon = points
		shadow.color = Color(0, 0, 0, 0.0)
		shadow.top_level = true
		arm.add_child(shadow)
		add_child(arm)
		hit.owner = self
		hurt.owner = self
		arm.global_position = Vector2(global_position.x - 300.0, floor_y - 1400.0)
		arms.append(arm)


func _hitbox(size: Vector2, at: Vector2, damage: int, knockback: float, unblockable: bool) -> Hitbox:
	var hit := Hitbox.new()
	hit.collision_layer = 16
	hit.collision_mask = 0
	hit.monitoring = false
	hit.damage = damage
	hit.knockback = knockback
	hit.unblockable = unblockable
	hit.active = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	hit.add_child(shape)
	return hit


func _hurtbox(size: Vector2, at: Vector2) -> Hurtbox:
	var hurt := Hurtbox.new()
	hurt.collision_layer = 0
	hurt.collision_mask = 8
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	hurt.add_child(shape)
	return hurt


func _set_monitoring(area: Area2D, on: bool) -> void:
	area.set_deferred("monitoring", on)
	area.set_deferred("monitorable", on)


func _set_flood(level: float) -> void:
	_flood_level = level
	flood.polygon = PackedVector2Array([
		Vector2(arena_left - 400, floor_y - level), Vector2(arena_right + 900, floor_y - level),
		Vector2(arena_right + 900, floor_y + 400), Vector2(arena_left - 400, floor_y + 400)])


func start_fight() -> void:
	if state != State.WAITING:
		return
	state = State.WALL
	_rest_left = 1.6
	EventBus.boss_started.emit(boss_name, health.max_health)
	DialogueUI.narrate("At the bottom of everything, the water stood up. It was as tall as the page, and it had arms, and somewhere in the middle of it, very small, something was knocking.")


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	_refused = maxf(_refused - delta, 0.0)
	var t := Time.get_ticks_msec() * 0.001
	match state:
		State.WALL, State.DRAIN:
			body.rotation = sin(t * 0.8) * 0.02
			if state == State.DRAIN:
				var player := _player()
				if player:
					var want := clampf(player.global_position.x + 420.0, arena_left + 300.0, arena_right)
					global_position.x = move_toward(global_position.x, want, 160.0 * delta)
			_rest_left -= delta
			if _rest_left <= 0.0:
				_next()


func _next() -> void:
	_moves += 1
	if phase == 0:
		var late := health.max_health - health.current >= wall_health / 2
		if _moves % 3 == 0:
			_surge()
		else:
			_slam(2 if late else 1)
	elif phase == 2:
		if _moves % 2 == 0:
			_rain()
		else:
			_lunge()


func _done(rest_scale := 1.0) -> void:
	if state == State.TAIL or state == State.DONE or state == State.SPLIT:
		return
	state = State.WALL if phase == 0 else State.DRAIN
	_rest_left = rests[0 if phase == 0 else 1] * rest_scale


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


# --- Phase 1: the wall ------------------------------------------------------------

## An arm comes down over where Patch stands (twice over in the second half).
func _slam(count: int) -> void:
	state = State.SLAM
	_kill_tween()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var tell: float = slam_tell[0 if count == 1 else 1]
	for i in count:
		var arm := arms[(slams + i) % 2]
		_tween.tween_callback(_raise.bind(arm, tell))
		_tween.tween_interval(tell)
		_tween.tween_callback(_fall.bind(arm))
		_tween.tween_interval(0.14)
		_tween.tween_callback(_landed.bind(arm, i == count - 1))
		if i < count - 1:
			_tween.tween_interval(0.35)
			_tween.tween_callback(_lift.bind(arm, false))
	slams += count


func _raise(arm: Node2D, tell: float) -> void:
	var player := _player()
	var x := clampf(player.global_position.x if player else arena_left + 400.0, arena_left + 80.0, arena_right - 40.0)
	arm.global_position = Vector2(x, floor_y - 1500.0)
	var shadow := arm.get_node("Shadow") as Polygon2D
	shadow.global_position = Vector2(x, floor_y)
	shadow.color.a = 0.0
	var t := arm.create_tween().set_parallel()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(arm, "global_position:y", floor_y - ARM_HANG, tell * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(shadow, "color:a", 0.55, tell)
	# The glint: this one can be parried.
	get_tree().create_timer(maxf(tell - 0.28, 0.05), false, true).timeout.connect(func() -> void:
		if state == State.SLAM:
			Tells.glint(arm, Vector2(0, -60), 1.1))
	AudioManager.play_sfx(&"growl", 0.55, -6.0)


func _fall(arm: Node2D) -> void:
	var hit := arm.get_node("Hit") as Hitbox
	hit.active = true
	var t := arm.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(arm, "global_position:y", floor_y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _landed(arm: Node2D, last: bool) -> void:
	var hit := arm.get_node("Hit") as Hitbox
	AudioManager.play_sfx(&"slam", 0.55)
	var player := _player()
	if player and player.has_method("_shake_camera"):
		player._shake_camera(16.0)
	get_tree().create_timer(0.12, false, true).timeout.connect(func() -> void: hit.active = false)
	if last:
		_arm_down(arm, arm_down_time)


## The fist is in the floor: the arm is open.
func _arm_down(arm: Node2D, seconds: float) -> void:
	state = State.ARM_DOWN
	_down_arm = arm
	_open = true
	_set_monitoring(arm.get_node("Hurt") as Area2D, true)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(seconds)
	_tween.tween_callback(_lift.bind(arm, true))


func _lift(arm: Node2D, finish: bool) -> void:
	if arm == _down_arm:
		_open = false
		_down_arm = null
		BossStagger.close(hold)
	(arm.get_node("Hit") as Hitbox).active = false
	_set_monitoring(arm.get_node("Hurt") as Area2D, false)
	var shadow := arm.get_node("Shadow") as Polygon2D
	var t := arm.create_tween().set_parallel()
	t.tween_property(arm, "global_position:y", floor_y - 1500.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(shadow, "color:a", 0.0, 0.3)
	if finish and state == State.ARM_DOWN:
		_done()


## Patch's parry snaps the falling fist aside: it buries itself in the floor.
func on_parried(_by: Node) -> void:
	if state != State.SLAM:
		return
	for arm in arms:
		var hit := arm.get_node("Hit") as Hitbox
		if hit.active:
			hit.active = false
			parried += 1
			_kill_tween()
			arm.create_tween().tween_property(arm, "global_position:y", floor_y, 0.06)
			_arm_down(arm, parried_time)
			_say("parry", "The fist went into the floor of the Gutter and stuck there, and for a moment the whole wall leaned on one arm.")
			return


## The wall glows red, and a wave runs the length of the floor.
func _surge() -> void:
	state = State.SURGE
	Tells.red_glow(body, surge_tell)
	AudioManager.play_sfx(&"growl", 0.45, -3.0)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(surge_tell)
	_tween.tween_callback(_send_wave)
	_tween.tween_interval(1.6)
	_tween.tween_callback(_done)


func _send_wave() -> void:
	var wave_node := Node2D.new()
	wave_node.add_to_group(&"sogg_waves")
	wave_node.top_level = true
	wave_node.z_index = 4
	var crest := Polygon2D.new()
	crest.color = Color(0.2, 0.24, 0.3, 0.97)
	crest.polygon = PackedVector2Array([Vector2(-120, 0), Vector2(-80, -90), Vector2(-14, -140), Vector2(50, -120), Vector2(110, -50), Vector2(140, 0)])
	wave_node.add_child(crest)
	var foam := Line2D.new()
	foam.width = 10.0
	foam.default_color = Color(0.86, 0.88, 0.9, 0.9)
	foam.points = PackedVector2Array([Vector2(-80, -90), Vector2(-14, -140), Vector2(50, -120), Vector2(110, -50)])
	wave_node.add_child(foam)
	var hit := _hitbox(Vector2(150, 100), Vector2(0, -50), 1, 520.0, true)
	wave_node.add_child(hit)
	add_child(wave_node)
	hit.owner = self
	hit.active = true
	wave_node.global_position = Vector2(global_position.x - 220.0, floor_y)
	var run := wave_node.create_tween()
	run.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var distance := wave_node.global_position.x - (arena_left - 160.0)
	run.tween_property(wave_node, "global_position:x", arena_left - 160.0, distance / 760.0)
	run.tween_callback(wave_node.queue_free)
	AudioManager.play_sfx(&"hit_wet", 0.5)


func _on_arm_hit(hitbox: Hitbox, arm: Node2D) -> void:
	if arm != _down_arm or not _open:
		_glance()
		return
	_damage(hitbox, arm.get_node("Art") as CanvasItem)


# --- Phase 2: it splits -----------------------------------------------------------

func _split() -> void:
	phase = 1
	state = State.SPLIT
	_open = false
	_kill_tween()
	BossStagger.close(hold)
	for arm in arms:
		_lift(arm, false)
	_contact.active = false
	DialogueUI.narrate("The wall came down. Not beaten: it fell into the water all at once, and the water stood up again in a dozen places, and every one of them had a face.")
	var t := create_tween().set_parallel()
	t.tween_property(body, "position:y", 520.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(body, "modulate:a", 0.0, 1.2)
	t.chain().tween_callback(_next_wave)


func _next_wave() -> void:
	wave += 1
	if wave >= waves.size():
		_reform()
		return
	var letters := waves[wave]
	_alive = letters.length()
	for i in letters.length():
		var c := letters[i]
		var foe := (load(KINDS.get(c.to_lower(), KINDS["s"])) as PackedScene).instantiate() as Node2D
		if c != c.to_lower():
			foe.set(&"inked", true)
		foe.add_to_group(&"sogg_spawn")
		var x := lerpf(arena_left + 160.0, arena_right - 60.0, (i + 0.5) / letters.length())
		foe.position = get_parent().to_local(Vector2(x, floor_y - 40.0))
		foe.modulate.a = 0.0
		foe.create_tween().tween_property(foe, "modulate:a", 1.0, 0.5)
		foe.tree_exiting.connect(_on_spawn_gone)
		get_parent().add_child.call_deferred(foe)
	AudioManager.play_sfx(&"growl", 0.7 + 0.1 * wave, -6.0)


func _on_spawn_gone() -> void:
	if phase != 1:
		return
	_alive -= 1
	if _alive <= 0:
		get_tree().create_timer(1.0, false).timeout.connect(_next_wave)


# --- Phase 3: the drain -----------------------------------------------------------

func _reform() -> void:
	phase = 2
	stage = 0
	state = State.SPLIT
	DialogueUI.narrate("The last of them went back into the water, and the water pulled itself together one more time: smaller now, and in the middle of it, where its heart should be, a pale little cloud.")
	global_position.x = arena_right - 100.0
	body.position.y = 0.0
	body.scale = Vector2(0.95, 0.95)
	var t := create_tween().set_parallel()
	t.tween_property(body, "modulate:a", 1.0, 1.0)
	t.tween_property(heart, "modulate:a", 0.45, 1.0)
	t.chain().tween_callback(func() -> void:
		state = State.DRAIN
		_rest_left = 1.2)


## Rain: drops of ink out of the dark over Patch.
func _rain() -> void:
	state = State.RAIN
	_kill_tween()
	_tween = create_tween()
	for i in 5:
		_tween.tween_callback(_drop)
		_tween.tween_interval(0.22)
	_tween.tween_interval(0.5)
	_tween.tween_callback(_done)


func _drop() -> void:
	var player := _player()
	var x := clampf((player.global_position.x if player else global_position.x) + randf_range(-260.0, 260.0), arena_left, arena_right)
	var drip := DRIP.instantiate() as Node2D
	drip.set("floor_y", floor_y - 10.0)
	drip.add_to_group(&"sogg_spawn")
	get_parent().add_child(drip)
	drip.global_position = Vector2(x, floor_y - 900.0)


## The lunge: red, then it throws itself along the floor at him, and it's spent.
func _lunge() -> void:
	state = State.LUNGE
	Tells.red_glow(body, lunge_tell)
	var player := _player()
	var x := clampf(player.global_position.x if player else arena_left + 400.0, arena_left + 140.0, arena_right)
	_kill_tween()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_interval(lunge_tell)
	_tween.tween_callback(func() -> void:
		_contact.active = true
		AudioManager.play_sfx(&"hit_wet", 0.45))
	_tween.tween_property(self, "global_position:x", x, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		_contact.active = false
		_spent())


func _spent() -> void:
	state = State.SPENT
	_open = true
	_set_monitoring(_heart_hurt, true)
	heart.modulate.a = 1.0
	body.self_modulate = Color(0.75, 0.8, 0.95)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_interval(spent_time)
	_tween.tween_callback(_recover)


func _recover() -> void:
	if state != State.SPENT:
		return
	_open = false
	_set_monitoring(_heart_hurt, false)
	heart.modulate.a = 0.45
	body.self_modulate = Color.WHITE
	BossStagger.close(hold)
	_done()


func _on_heart_hit(hitbox: Hitbox) -> void:
	if state != State.SPENT:
		_glance()
		return
	_damage(hitbox, body)


## The water goes down a little, the warm light comes on a little more, and they talk.
func _drain_to(new_stage: int) -> void:
	while stage < new_stage and stage < DRAIN_LINES.size():
		var lines: Array = DRAIN_LINES[stage]
		stage += 1
		if Rematch.on(self):
			continue
		DialogueUI.narrate(lines[0])
		get_tree().create_timer(2.6, false).timeout.connect(DialogueUI.narrate.bind(lines[1]))
	var left := 1.0 - float(stage) / DRAIN_LINES.size()
	var t := create_tween().set_parallel()
	t.tween_method(_set_flood, _flood_level, 90.0 * left, 1.4)
	t.tween_property(warm, "modulate:a", 0.24 * (1.0 - left), 1.4)
	if stage == 1:
		_say("warm", "Far above, at the very edge of the page, a warm light came on. The water began to go down.")


# --- Being cut ----------------------------------------------------------------------

func _glance() -> void:
	if not health.is_invulnerable():
		AudioManager.play_sfx(&"parry", 1.4, -8.0)
		health.grant_invulnerability(0.25)


func _damage(hitbox: Hitbox, flash: CanvasItem) -> void:
	if not health.take_damage(hitbox.damage, hitbox.global_position):
		return
	if phase == 0 and health.current <= health.max_health - wall_health:
		health.set_health(health.max_health - wall_health)
	EventBus.boss_health_changed.emit(health.current, health.max_health)
	AudioManager.play_sfx(&"hit_wet", 0.8)
	flash.modulate = Color(1.8, 1.6, 1.5)
	flash.create_tween().tween_property(flash, "modulate", Color.WHITE, 0.2)
	_after_damage()


func _after_damage() -> void:
	if health.is_dead():
		return
	if phase == 0 and health.current <= health.max_health - wall_health:
		_split()
	elif phase == 2:
		# The last exchange comes one cut before the end.
		var drained := (health.max_health - wall_health) - health.current
		_drain_to((drained + 1) / hits_per_stage)


func is_open() -> bool:
	return _open


func can_stagger() -> bool:
	return state == State.ARM_DOWN or state == State.SPENT


func finisher_point() -> Vector2:
	if state == State.ARM_DOWN and _down_arm:
		return _down_arm.global_position + Vector2(0, -120)
	return global_position + Vector2(-14, -260)


func _on_hold_broken() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	get_tree().create_timer(hold.stagger_time, false).timeout.connect(func() -> void:
		if state == State.ARM_DOWN and _down_arm:
			_lift(_down_arm, true)
		elif state == State.SPENT:
			_recover())


func unstitch(_by: Node) -> void:
	if not can_stagger():
		return
	AudioManager.play_sfx(&"enemy_pop", 0.5)
	var was := state
	if BossStagger.unstitch(self, health, hold):
		if phase == 0 and health.current <= health.max_health - wall_health:
			health.set_health(health.max_health - wall_health)
		DialogueUI.narrate("Patch opened a seam in it, and water came out of the Sogg in a sheet, black, and then grey, and then almost clear.")
		_after_damage()
		get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
			if state == was and was == State.SPENT:
				_recover()
			elif state == was and _down_arm:
				_lift(_down_arm, true))


# --- Phase 4: the tail --------------------------------------------------------------

func _tail() -> void:
	if Rematch.intercept(self):
		return
	if phase == 3:
		return
	phase = 3
	state = State.TAIL
	_open = false
	_kill_tween()
	BossStagger.close(hold)
	_contact.active = false
	_set_monitoring(_heart_hurt, false)
	for group in [&"sogg_spawn", &"sogg_waves"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	for arm in arms:
		_lift(arm, false)
	Bestiary.record(self)
	EventBus.boss_defeated.emit()
	var t := create_tween().set_parallel()
	t.tween_property(body, "modulate:a", 0.0, 1.6)
	t.tween_method(_set_flood, _flood_level, 0.0, 1.6)
	t.tween_property(warm, "modulate:a", 0.28, 1.6)
	drizzle = Sprite2D.new()
	drizzle.texture = DRIZZLE
	drizzle.scale = Vector2(0.6, 0.6)
	drizzle.offset = Vector2(0, -DRIZZLE.get_height() / 2.0)
	drizzle.modulate = Color(0.7, 0.72, 0.8, 0.0)
	add_child(drizzle)
	drizzle.global_position = Vector2(global_position.x - 80.0, floor_y)
	t.tween_property(drizzle, "modulate:a", 1.0, 1.6)
	# The shears won't do it.
	_drizzle_hurt = _hurtbox(Vector2(200, 200), Vector2(0, -100))
	drizzle.add_child(_drizzle_hurt)
	_drizzle_hurt.owner = self
	_drizzle_hurt.hit.connect(_on_drizzle_hit)
	mend = load("res://scripts/world/give_tail.gd").new()
	mend.boss = self
	add_child(mend)
	mend.top_level = true
	mend.global_position = drizzle.global_position
	await t.finished
	DialogueUI.narrate("When the water had gone there was nothing left of the Sogg but a little cloud on the floor of the Gutter, grey, torn almost in two, with a rip down her middle the shape of a paw that had pulled away.")


func _on_drizzle_hit(_hitbox: Hitbox) -> void:
	if _refused > 0.0:
		return
	_refused = 4.0
	DialogueUI.narrate("He lifted the shears over her, and couldn't. He had done enough to her.")


## Patch unpicks the Tape Tail and stitches her shut with it.
func give_tail() -> void:
	if state != State.TAIL:
		return
	state = State.DONE
	mend.queue_free()
	var player := _player()
	if player:
		player.set(&"input_enabled", false)
	if not tail_dialogue.is_empty():
		DialogueUI.start(tail_dialogue)
		await EventBus.dialogue_finished
	GameState.set_flag(defeated_flag)
	GameState.set_flag("gave_tail")
	GameState.abilities.erase(&"tape_tail")
	var t := create_tween()
	t.tween_property(drizzle, "modulate", Color(1.15, 1.12, 1.08), 1.4)
	t.parallel().tween_property(drizzle, "scale", Vector2(0.66, 0.66), 1.4).set_trans(Tween.TRANS_BACK)
	await t.finished
	GameState.save_game()
	if not next_page.is_empty():
		SceneManager.change_page(next_page)


## Rematch, inked phase: the flood comes back up, black, and has to be drained again.
func inked() -> void:
	# A third of its health back puts it at stage 2 of 4: the water comes back to half.
	stage = 2
	flood.color = Color(0.07, 0.03, 0.1, 0.9)
	var t := create_tween().set_parallel()
	t.tween_method(_set_flood, _flood_level, 45.0, 1.4)
	t.tween_property(warm, "modulate:a", 0.05, 1.4)


func _say(key: String, line: String) -> void:
	if _told.has(key):
		return
	_told[key] = true
	DialogueUI.narrate(line)

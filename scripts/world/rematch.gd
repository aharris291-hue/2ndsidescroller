class_name Rematch
extends Node
## Boss rematches (post-game): Gran's proof press in the Spine pulls a fresh proof of
## a boss's page, and Patch fights it again. The fight is the same until the boss's
## health runs out; then the ink comes back (the inked phase): the boss gets a third
## of its health back, goes black, moves faster with shorter openings, and ink rains
## on the arena. Beating that ends the rematch with a sticker for the ledger, by time
## and hits taken, and turns back to the press.
##
## A boss takes part with three calls: `Rematch.watch(self)` in _ready (true while a
## rematch of it is running, so it fights even though its flag is set),
## `Rematch.intercept(self)` at the top of its defeat handler (true = the rematch has
## the defeat; return), and optionally an `inked()` method for its own changes.
## While a rematch runs, one of these nodes rides along in the arena: it keeps the
## clock, counts the hits and runs the ink.

const HUB := "res://scenes/levels/hub/spine_hub.tscn"
## Where Patch comes back to: in front of the press in the gallery.
const HUB_SPOT := Vector2(1820, 560)
const DRIP_SCENE := preload("res://scenes/enemies/ink_drip.tscn")

## Every boss Patch can fight again, in book order. "par" is the time (seconds,
## inked phase included) for the gilt sticker; an estimate, not measured.
const BOSSES := [
	{"id": "millwheel", "name": "Old Millwheel", "flag": "boss_millwheel_defeated",
		"scene": "res://scenes/levels/thistledown/boss_mill_floor.tscn", "par": 100.0},
	{"id": "kraken", "name": "The Blotch Kraken", "flag": "boss_kraken_defeated",
		"scene": "res://scenes/levels/lanternfold/boss_ink_deep.tscn", "par": 120.0},
	{"id": "heron", "name": "The Grey Heron", "flag": "boss_heron_defeated",
		"scene": "res://scenes/levels/marsh/heronry.tscn", "par": 120.0},
	{"id": "bindwell", "name": "Old Bindwell", "flag": "boss_bindwell_defeated",
		"scene": "res://scenes/levels/peaks/bindwell_workshop.tscn", "par": 110.0},
	{"id": "barker", "name": "The Barker", "flag": "boss_barker_defeated",
		"scene": "res://scenes/levels/fair/the_big_top.tscn", "par": 140.0},
	{"id": "redactor", "name": "The Redactor", "flag": "boss_redactor_defeated",
		"scene": "res://scenes/levels/index/the_last_entry.tscn", "par": 150.0},
	{"id": "forecast", "name": "The Unwritten Forecast", "flag": "boss_forecast_defeated",
		"scene": "res://scenes/levels/margins/the_forecast.tscn", "par": 130.0},
	{"id": "sogg", "name": "The Sogg", "flag": "boss_sogg_defeated",
		"scene": "res://scenes/levels/finale/f_2_the_deepest_fold.tscn", "par": 200.0},
]

## Sticker names, by rank (index 0 = none yet).
const STICKERS: Array[String] = ["", "Paper", "Copper", "Silver", "Gilt"]
const STICKER_COLORS: Array[Color] = [
	Color(0.4, 0.4, 0.42), Color(0.78, 0.74, 0.66), Color(0.78, 0.47, 0.3),
	Color(0.78, 0.8, 0.84), Color(0.92, 0.76, 0.36)]

## How the inked phase changes each boss: property -> multiplier. Tells shrink a
## little (never by more than 15%), rests and openings shrink more, speeds go up.
const INK_TUNING := {
	"millwheel": {"sail_speeds": 1.3, "jam_time": 0.75, "drip_interval": 0.7},
	"kraken": {"slam_intervals": 0.75, "warn_time": 0.85, "stun_time": 0.75},
	"heron": {"stab_windups": 0.85, "rests": 0.7, "stuck_time": 0.8, "walk_speed": 1.25},
	"bindwell": {"windups": 0.9, "rests": 0.7, "stun_time": 0.8, "drift_speed": 1.2},
	"barker": {"announce_time": 0.85, "rests": 0.7, "card_speed": 1.2, "horse_speed": 1.15, "winded_time": 0.8},
	"redactor": {"strike_tell": 0.85, "box_tell": 0.9, "rests": 0.7, "spent_time": 0.8, "max_silverfish": 1.5},
	"forecast": {"rain_every": 0.8, "rests": 0.75, "spent_time": 0.85, "wind_period": 0.75},
	"sogg": {"rests": 0.7, "lunge_tell": 0.85, "spent_time": 0.85},
}
const INK_TINT := Color(0.42, 0.36, 0.5)
## Seconds between ink drops in the inked phase.
const INK_RAIN := 1.15

var boss: Node2D
var boss_id := ""
var par := 120.0
var elapsed := 0.0
var hits := 0
var inked := false
var finished := false
var _started := false
var _rain_left := 1.0
var _clock: Label
var _veil: CanvasLayer


# --- Starting and stopping ---------------------------------------------------------

static func entry(id: String) -> Dictionary:
	for b: Dictionary in BOSSES:
		if b["id"] == id:
			return b
	return {}


static func unlocked(id: String) -> bool:
	var b := entry(id)
	return not b.is_empty() and bool(GameState.get_flag(b["flag"]))


static func any_unlocked() -> bool:
	for b: Dictionary in BOSSES:
		if GameState.get_flag(b["flag"]):
			return true
	return false


## Best sticker so far (0 = none) and best time (0 = none).
static func best_rank(id: String) -> int:
	return int(GameState.get_flag("sticker:" + id, 0))


## A fight's length as m:ss.
static func clock(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


static func best_time(id: String) -> float:
	return float(GameState.get_flag("sticker_time:" + id, 0.0))


## Turns to the boss's arena with a rematch running.
static func start(id: String) -> bool:
	if not unlocked(id) or SceneManager.is_transitioning:
		return false
	GameState.rematch = id
	GameState.health = GameState.max_health
	SceneManager.change_page(entry(id)["scene"])
	return true


## Pages call this as they load: walking out of the arena (or loading any other
## page) ends the rematch with nothing recorded.
static func page_loaded(path: String) -> void:
	if GameState.rematch.is_empty():
		return
	var b := entry(GameState.rematch)
	if b.is_empty() or b["scene"] != path:
		GameState.rematch = ""


## Patch was torn during a rematch: the proof is pulled again, from the start.
static func retry() -> bool:
	if GameState.rematch.is_empty():
		return false
	GameState.health = GameState.max_health
	SceneManager.change_page(entry(GameState.rematch)["scene"])
	return true


# --- The boss's side ---------------------------------------------------------------

## Called from a boss's _ready. True while that boss is being fought again; the
## first call also sets up the run in its arena.
static func watch(who: Node2D) -> bool:
	var id: String = who.get(&"bestiary_id")
	if GameState.rematch.is_empty() or GameState.rematch != id:
		return false
	if not who.has_meta(&"rematch"):
		var run := Rematch.new()
		run.boss = who
		run.boss_id = id
		run.par = entry(id).get("par", 120.0)
		who.set_meta(&"rematch", run)
		who.add_sibling.call_deferred(run)
	return true


static func on(who: Node) -> bool:
	return is_instance_valid(who) and who.has_meta(&"rematch")


## Called first thing when a boss's health runs out. True when the rematch takes the
## defeat over (the boss should do nothing more).
static func intercept(who: Node) -> bool:
	if not who.has_meta(&"rematch"):
		return false
	var run: Rematch = who.get_meta(&"rematch")
	if not is_instance_valid(run):
		return false
	if not run.inked:
		run._ink()
	elif not run.finished:
		run._finish()
	return true


# --- The run -------------------------------------------------------------------------

func _ready() -> void:
	name = &"Rematch"
	EventBus.boss_started.connect(func(_n: String, _m: int) -> void: _started = true)
	var player := get_tree().get_first_node_in_group(&"player")
	if player and player.get(&"health"):
		(player.get(&"health") as HealthComponent).damaged.connect(func(_a: int, _f: Vector2) -> void:
			if not finished:
				hits += 1)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_clock = Label.new()
	_clock.add_theme_font_size_override(&"font_size", 30)
	_clock.add_theme_color_override(&"font_color", Color(0.85, 0.82, 0.76))
	_clock.add_theme_color_override(&"font_outline_color", Color(0.05, 0.04, 0.06))
	_clock.add_theme_constant_override(&"outline_size", 6)
	_clock.position = Vector2(1440, 78)
	_clock.size = Vector2(440, 44)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(_clock)
	_update_clock()


func _physics_process(delta: float) -> void:
	if finished:
		return
	if _started:
		elapsed += delta
	_update_clock()
	if inked:
		_rain_left -= delta
		if _rain_left <= 0.0:
			_rain_left = INK_RAIN * randf_range(0.8, 1.2)
			_drop()


func _update_clock() -> void:
	_clock.text = "%s   %s   hits %d" % ["INKED" if inked else "Rematch", Rematch.clock(elapsed), hits]


## Ink falls somewhere on the arena, never straight onto Patch twice running.
func _drop() -> void:
	if not is_instance_valid(boss):
		return
	var left: float = boss.get(&"arena_left") if boss.get(&"arena_left") != null else 0.0
	var right: float = boss.get(&"arena_right") if boss.get(&"arena_right") != null else 1920.0
	var floor_y: float = boss.get(&"floor_y") if boss.get(&"floor_y") != null else 896.0
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var x := randf_range(left + 40.0, right - 40.0)
	if player and randf() < 0.5:
		# Half of them fall near him, so standing still isn't safe.
		x = clampf(player.global_position.x + randf_range(-260.0, 260.0), left + 40.0, right - 40.0)
	var drip := DRIP_SCENE.instantiate() as Node2D
	drip.set(&"floor_y", floor_y - 20.0)
	drip.add_to_group(&"rematch_ink")
	get_parent().add_child(drip)
	drip.global_position = Vector2(x, floor_y - 860.0)


## Health ran out the first time: the ink comes back.
func _ink() -> void:
	inked = true
	_rain_left = 1.6
	var health := boss.get(&"health") as HealthComponent
	if health:
		health.set_health(maxi(health.max_health / 3, 1))
		health.grant_invulnerability(1.2)
		EventBus.boss_health_changed.emit(health.current, health.max_health)
	var tuning: Dictionary = INK_TUNING.get(boss_id, {})
	for key: String in tuning:
		_scale(key, tuning[key])
	var art := _art()
	if art:
		art.create_tween().tween_property(art, "self_modulate", INK_TINT, 0.8)
	if boss.has_method(&"inked"):
		boss.call(&"inked")
	_veil = CanvasLayer.new()
	_veil.layer = 1
	var shade := TextureRect.new()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	fade.colors = PackedColorArray([Color(0.03, 0.02, 0.05, 0.0), Color(0.03, 0.02, 0.05, 0.0), Color(0.03, 0.02, 0.05, 0.75)])
	var tex := GradientTexture2D.new()
	tex.gradient = fade
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 144
	shade.texture = tex
	shade.size = Vector2(1920, 1080)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.modulate.a = 0.0
	_veil.add_child(shade)
	add_child(_veil)
	shade.create_tween().tween_property(shade, "modulate:a", 1.0, 1.2)
	AudioManager.play_sfx(&"hit_wet", 0.5, -2.0)
	DialogueUI.narrate("The ink came back up through the paper, the way it had been before the page was mended. Worse.")
	_update_clock()


## The boss's painted body: whichever of art/body it has.
func _art() -> CanvasItem:
	for key in [&"art", &"body"]:
		var node: Variant = boss.get(key)
		if node is CanvasItem and is_instance_valid(node):
			return node
	return null


func _scale(key: String, by: float) -> void:
	var value: Variant = boss.get(key)
	if value == null:
		return
	if value is float:
		boss.set(key, value * by)
	elif value is int:
		boss.set(key, maxi(roundi(value * by), 1))
	elif value is Array:
		var scaled: Array = value.duplicate()
		for i in scaled.size():
			scaled[i] = scaled[i] * by
		boss.set(key, scaled)


## Beaten for good: stop everything, give the sticker, go back to the press.
func _finish() -> void:
	finished = true
	var rank := rank_for(elapsed, hits, par)
	var id := boss_id
	var new_best := rank > best_rank(id)
	if new_best:
		GameState.set_flag("sticker:" + id, rank)
	if best_time(id) <= 0.0 or elapsed < best_time(id):
		GameState.set_flag("sticker_time:" + id, elapsed)
	var player := get_tree().get_first_node_in_group(&"player")
	if player and player.get(&"health"):
		(player.get(&"health") as HealthComponent).grant_invulnerability(30.0)
	# Patch stands still for the card: nothing (wind, a slide, a stray press) carries
	# him out through the page's exit before the press turns back.
	if player:
		player.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	EventBus.boss_defeated.emit()
	boss.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	create_tween().tween_property(boss, "modulate:a", 0.0, 1.2)
	for group in [&"rematch_ink", &"enemies"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	if _veil:
		_veil.queue_free()
	AudioManager.play_sfx(&"page_flip", 0.7)
	_card(rank, new_best)
	await get_tree().create_timer(4.2, false).timeout
	GameState.rematch = ""
	GameState.save_game()
	SceneManager.change_page_at(HUB, HUB_SPOT)


## Rank 1..4 from time and hits: one for finishing, one for two hits or fewer (two
## for none), one for beating par. Gilt needs a clean fight under par.
static func rank_for(seconds: float, hits_taken: int, par_time: float) -> int:
	var rank := 1
	if hits_taken == 0:
		rank += 2
	elif hits_taken <= 2:
		rank += 1
	if seconds <= par_time:
		rank += 1
	return mini(rank, 4)


func _card(rank: int, new_best: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var box := DarkUI.dialog(layer, Vector2(720, 260))
	box.add_child(DarkUI.label(entry(boss_id)["name"], 34, DarkUI.BONE))
	var sticker := DarkUI.label("%s sticker" % STICKERS[rank], 44, STICKER_COLORS[rank])
	box.add_child(sticker)
	box.add_child(DarkUI.label("%s, %d %s taken.  Par %s." % [Rematch.clock(elapsed), hits,
		"hit" if hits == 1 else "hits", Rematch.clock(par)], 24, DarkUI.ASH))
	box.add_child(DarkUI.label("A new best for the ledger." if new_best else "The ledger keeps your best: %s." % STICKERS[best_rank(boss_id)], 22, DarkUI.ASH, true))

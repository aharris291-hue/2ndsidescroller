extends SceneTree
## Headless checks for the redesigned combat, run in the Combat Lab:
##   godot --headless --path . --script tools/godot/combat_test.gd
## Covers the light combo, heavy and charged cuts, Hold breaking and the Unstitch,
## the Plunge bounce, guard, parry, perfect dodge, Thread and Mend.

var _failures: Array[String] = []
var patch: Node
var gs: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	gs = root.get_node("GameState")
	# Test the standard rules, whatever this machine's pause-menu settings are.
	_standard_settings()
	gs.new_game(0)
	gs.sandbox = true
	change_scene_to_file("res://scenes/levels/combat_lab/combat_lab.tscn")
	await _frames(30)
	patch = get_first_node_in_group("player")
	var lab := current_scene
	var post: Node2D = lab.get_node("Actors/CuttingPost")
	var sparring: Node2D = lab.get_node("Actors/SparringPost")
	_check(patch != null and patch.is_on_floor(), "Patch stands in the Combat Lab")
	_check(not gs.save_game(), "the lab never writes a save")

	# --- Light combo on the cutting post.
	_put_patch(post.global_position.x - 90.0, 1.0)
	gs.thread = 0.0
	var steps := []
	for i in 4:
		await _tap(&"attack", 2, 7)
		steps.append(patch.combo_step)
	_check(steps == [1, 2, 3, 4], "four light cuts chain into a combo (%s)" % str(steps))
	_check(gs.thread > 0.3, "landed cuts fill Thread (%.2f)" % gs.thread)
	await _frames(30)

	# --- Heavy cut wears Hold down by 3.
	var hold: Node = post.get_node("HoldComponent")
	hold.current = hold.max_hold
	await _tap(&"heavy", 3, 30)
	_check(is_equal_approx(hold.current, hold.max_hold - 3.0), "a heavy cut takes 3 Hold (%.1f left)" % hold.current)

	# --- Charged heavy to level 3, the Full Cut.
	await _frames(20)
	await physics_frame
	Input.action_press(&"heavy")
	for i in 95:
		await physics_frame
	var level: int = patch.charge_level
	Input.action_release(&"heavy")
	await _frames(60)
	_check(level == 3, "holding heavy charges to level 3 (%d)" % level)
	_check(hold.is_broken(), "the Full Cut breaks the post's Hold")

	# --- Unstitch on the broken post.
	var before: float = gs.thread
	await _tap(&"heavy", 2, 40)
	_check(gs.thread >= minf(before + 0.9, gs.thread_max), "the Unstitch refills Thread")
	_check(not hold.is_broken(), "the Unstitch spends the stagger")
	await _frames(120)

	# --- Mend: spend a charge to heal.
	patch.health.set_health(2)
	gs.thread = 1.5
	await physics_frame
	Input.action_press(&"mend")
	for i in 90:
		await physics_frame
	Input.action_release(&"mend")
	await _frames(5)
	_check(patch.health.current == 4 and absf(gs.thread - 0.5) < 0.01, "Mend spends a charge and heals (%d hp, %.2f thread)" % [patch.health.current, gs.thread])

	# --- Plunge bounces off the post.
	_put_patch(post.global_position.x, -1.0, -260.0)
	patch.velocity = Vector2.ZERO
	await _frames(2)
	Input.action_press(&"move_down")
	await _tap(&"heavy", 2, 0)
	var bounced := false
	for i in 60:
		await physics_frame
		if patch.velocity.y < -400.0:
			bounced = true
			break
	Input.action_release(&"move_down")
	_check(bounced, "the Plunge bounces Patch off what it hits")
	await _frames(60)

	# --- Guard blocks, and a well-timed guard parries the sparring post.
	# Stop the post's own rhythm; the test swings it by hand.
	sparring.set("spars", false)
	await _frames(30)
	_put_patch(sparring.global_position.x - 95.0, 1.0)
	await _frames(10)
	var swing: Node = sparring.get_node("Swing")
	patch.health.set_health(6)
	patch.health.grant_invulnerability(0.0)
	await physics_frame
	Input.action_press(&"guard")
	for i in 20:
		await physics_frame
	swing.unblockable = false
	swing.damage = 1
	swing.position.x = -70.0
	swing.active = true
	await _frames(3)
	swing.active = false
	_check(patch.health.current == 6 and patch.state == 8, "guard blocks a frontal hit (hp %d, state %d)" % [patch.health.current, patch.state])
	Input.action_release(&"guard")
	await _frames(30)
	var parries: int = patch.parries
	_put_patch(sparring.global_position.x - 95.0, 1.0)
	for i in 20:
		await physics_frame
	Input.action_press(&"guard")
	await physics_frame
	await physics_frame
	swing.unblockable = false
	swing.active = true
	for i in 3:
		await physics_frame
	swing.active = false
	Input.action_release(&"guard")
	_check(patch.parries == parries + 1, "guard tapped as the hit lands is a parry")
	_check(patch.health.current == 6, "a parry takes no damage")
	await _frames(40)

	# --- Red glow can't be guarded.
	patch.health.grant_invulnerability(0.0)
	await _frames(30)
	await physics_frame
	Input.action_press(&"guard")
	for i in 20:
		await physics_frame
	swing.unblockable = true
	swing.damage = 2
	swing.active = true
	await _frames(3)
	swing.active = false
	Input.action_release(&"guard")
	_check(patch.health.current == 4, "a red-glow attack breaks through guard (hp %d)" % patch.health.current)
	await _frames(60)

	# --- Perfect dodge.
	patch.health.grant_invulnerability(0.0)
	_put_patch(sparring.global_position.x - 95.0, 1.0)
	await _frames(5)
	var dodges: int = patch.perfect_dodges
	await physics_frame
	Input.action_press(&"dash")
	await _frames(2)
	Input.action_release(&"dash")
	swing.unblockable = false
	swing.active = true
	await _frames(2)
	swing.active = false
	_check(patch.perfect_dodges == dodges + 1, "a hit at the start of a dodge is a perfect dodge")
	await create_timer(1.0, true, false, true).timeout
	_check(is_equal_approx(Engine.time_scale, 1.0), "time returns to normal after slow motion")

	await _auto_guard(sparring, swing)
	await _charms(sparring, swing)

	# --- Soggies have Hold and can be Unstitched.
	var soggy: Node2D = null
	for node in get_nodes_in_group("staggered"):
		pass
	for child in lab.get_node("Actors").get_children():
		if child.get_script() and str(child.get_script().resource_path).ends_with("soggy.gd"):
			soggy = child
			break
	_check(soggy != null and soggy.get_node_or_null("HoldComponent") != null, "Soggies have a Hold bar")
	if soggy:
		soggy.get_node("HoldComponent").take_hold(10.0)
		_check(soggy.is_in_group("staggered"), "a Soggy staggers when its Hold breaks")
		soggy.unstitch(patch)
		await create_timer(0.6).timeout
		_check(not is_instance_valid(soggy), "an Unstitched Soggy is gone")

	_tells_read_on_painted_art()
	await _accessibility(lab, sparring)
	_finish()


## Test the standard rules, whatever this machine's options say.
func _standard_settings() -> void:
	var settings := root.get_node("Settings")
	for option in [&"assist", &"assist_safe_falls", &"assist_wide_parry", &"auto_guard", &"tell_shapes", &"sound_captions"]:
		settings.set(option, false)
	settings.game_speed = 1.0
	settings.text_scale = 1.0
	settings.reset_bindings()
	settings.apply()


## Auto-guard blocks a frontal hit while Patch just stands there (never a parry), and
## with it off the same hit lands.
func _auto_guard(sparring: Node2D, swing: Node) -> void:
	var settings := root.get_node("Settings")
	settings.auto_guard = true
	patch.health.grant_invulnerability(0.0)
	_put_patch(sparring.global_position.x - 95.0, 1.0)
	await _frames(20)
	patch.health.set_health(6)
	var parries: int = patch.parries
	swing.unblockable = false
	swing.damage = 1
	swing.active = true
	await _frames(3)
	swing.active = false
	_check(patch.health.current == 6 and patch.parries == parries, "auto-guard blocks a frontal hit, without parrying (hp %d)" % patch.health.current)
	settings.auto_guard = false
	await _frames(40)
	patch.health.grant_invulnerability(0.0)
	_put_patch(sparring.global_position.x - 95.0, 1.0)
	await _frames(5)
	swing.active = true
	await _frames(3)
	swing.active = false
	_check(patch.health.current == 5, "with auto-guard off the same hit lands (hp %d)" % patch.health.current)
	await _frames(60)


## Stitch charms from Gran's sewing tin: the Thimble takes the chip out of a guarded
## heavy blow, and the Waxed Thread makes a Mend heal one more token.
func _charms(sparring: Node2D, swing: Node) -> void:
	var gs := root.get_node("GameState")
	var lost: Array[int] = []
	_put_patch(sparring.global_position.x - 95.0, 1.0)
	await _frames(10)
	swing.unblockable = false
	swing.damage = 3
	for thimble in [false, true]:
		gs.charms.clear()
		gs.equipped.clear()
		if thimble:
			gs.gain_charm(&"thimble")
			gs.set_charm_equipped(&"thimble", true)
		# A guard held well past the parry window, so the hit is a block.
		patch.health.clear_invulnerability()
		patch.health.set_health(6)
		patch.set(&"_guard_time", 1.0)
		patch.set(&"_block_cooldown", 0.0)
		patch.call(&"_guard_hit", swing)
		lost.append(6 - patch.health.current)
	_check(lost[0] == 2 and lost[1] == 0, "a guarded heavy blow chips 2, and nothing with Gran's Thimble (%s)" % str(lost))
	swing.damage = 1
	patch.health.clear_invulnerability()
	await _frames(20)

	gs.gain_charm(&"wax_thread")
	gs.set_charm_equipped(&"wax_thread", true)
	_put_patch(sparring.global_position.x - 95.0, 1.0)
	await _frames(10)
	# Nothing should land while he mends; this checks only the heal.
	patch.health.grant_invulnerability(3.0)
	patch.health.set_health(2)
	gs.thread = 1.5
	await physics_frame
	Input.action_press(&"mend")
	for i in 90:
		await physics_frame
	Input.action_release(&"mend")
	await _frames(5)
	_check(patch.health.current == 6, "with the Waxed Thread a Mend heals one more token (%d hp)" % patch.health.current)
	gs.charms.clear()
	gs.equipped.clear()
	swing.damage = 1
	await _frames(30)


## Rebinding, the left-hand layout, button prompts, shapes on tells, sound captions,
## text size and the options screen.
func _accessibility(lab: Node, sparring: Node2D) -> void:
	var settings := root.get_node("Settings")
	var glyphs := root.get_node("InputGlyphs")
	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	settings.rebind(&"jump", g)
	_check(settings.binding_text(&"jump", false) == "G" and not InputMap.action_has_event(&"jump", space), "jump rebinds to G and lets go of Space (%s)" % settings.binding_text(&"jump", false))
	_check(settings.binding_text(&"jump", true) == "A", "rebinding the keyboard leaves the controller alone")
	settings.rebind(&"attack", g)
	_check(settings.binding_text(&"jump", false) == "-" and settings.binding_text(&"attack", false) == "G", "a key bound to a second action leaves the first")
	settings.apply_preset(&"left_hand")
	_check(settings.binding_text(&"attack", false) == "Q" and glyphs.hint(&"guard") == "C", "the left-hand layout puts light cut on Q and guard on C")
	settings.reset_bindings()
	_check(glyphs.hint(&"jump") == "Space" and settings.binding_text(&"attack", false) == "J / Click", "reset puts the default keys back (%s)" % glyphs.hint(&"jump"))

	settings.assist_safe_falls = true
	patch.health.set_health(6)
	patch.call(&"_fell_off_page")
	_check(patch.health.current == 6, "with safe falls, falling off the page costs nothing")
	settings.assist_safe_falls = false
	patch.health.clear_invulnerability()
	patch.call(&"_fell_off_page")
	_check(patch.health.current == 5, "without it, a fall costs half a token (hp %d)" % patch.health.current)
	await _frames(30)

	settings.tell_shapes = true
	(load("res://scripts/components/tells.gd") as Script).call(&"red_glow", sparring, 0.5)
	_check(sparring.get_parent().get_node_or_null(^"WarningSign") != null, "with shapes on, a red glow also shows a warning sign")
	settings.tell_shapes = false
	await create_timer(0.8).timeout
	_check(sparring.get_parent().get_node_or_null(^"WarningSign") == null, "the warning sign goes when the glow ends")

	var captions := root.get_node("AudioManager").find_child("SoundCaptions", true, false)
	settings.sound_captions = true
	root.get_node("AudioManager").play_sfx(&"growl")
	_check(captions != null and captions.get_child_count() > 0 and (captions.get_child(-1) as Label).text == "[Growl]", "sound captions show [Growl] for a growl")
	settings.sound_captions = false

	settings.text_scale = 1.5
	settings.apply()
	var caption_label := root.get_node("DialogueUI").get_node(^"Caption/Margin/CaptionLabel") as Label
	_check(caption_label.get_theme_font_size(&"font_size") == 66, "large text grows the narrator's captions (%d)" % caption_label.get_theme_font_size(&"font_size"))
	settings.text_scale = 1.0
	settings.apply()

	var panel: Node = (load("res://scripts/ui/options_panel.gd") as Script).call(&"open_panel", root, &"controls")
	await _frames(3)
	var buttons := panel.find_children("*", "Button", true, false).size()
	_check(buttons >= settings.REBINDABLE.size() * 2 + 10, "the options screen lists every action for both devices and every accessibility option (%d buttons)" % buttons)
	panel.close()
	await _frames(2)
	_standard_settings()


func _put_patch(x: float, face: float, dy := 0.0) -> void:
	patch.global_position = Vector2(x, 916.0 + dy)
	patch.velocity = Vector2.ZERO
	patch.facing = Vector2(face, 0)
	patch.state = 0
	patch.combo_step = 0


func _tap(action: StringName, hold_frames: int, after: int) -> void:
	# Press right after a physics tick, as real input would arrive.
	await physics_frame
	Input.action_press(action)
	for i in hold_frames:
		await physics_frame
	Input.action_release(action)
	for i in after:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The tells must read on the painted art (docs/ART_STYLE.md, Readability): the red glow
## multiplies the sprite's colour, so a body of solid black ink would hide it, and the
## white glint must stay brighter than anything a tileset paints.
const TELL_SPRITES := [
	"res://assets/art/dark/sogg.png",
	"res://assets/art/dark/enemies/ink_spitter.png",
	"res://assets/art/dark/enemies/tack_knight.png",
	"res://assets/art/dark/bosses/millwheel_body.png",
	"res://assets/art/dark/bosses/kraken_body.png",
	"res://assets/art/dark/bosses/sogg_body.png",
]
## Every region's painted tiles (tools/art/dark_tileset.py).
const TILESETS := [
	"res://assets/art/dark/tiles/dark_tiles.png",
	"res://assets/art/dark/tiles/dark_tiles_meadow.png",
	"res://assets/art/dark/tiles/dark_tiles_harbor.png",
	"res://assets/art/dark/tiles/dark_tiles_marsh.png",
	"res://assets/art/dark/tiles/dark_tiles_peaks.png",
	"res://assets/art/dark/tiles/dark_tiles_fair.png",
	"res://assets/art/dark/tiles/dark_tiles_index.png",
	"res://assets/art/dark/tiles/dark_tiles_gutter.png",
]
const GLOW := Color(1.8, 0.45, 0.4)


func _tells_read_on_painted_art() -> void:
	# The glow has to show against the reddest region's tiles.
	var tile_red := -1.0
	var reddest := ""
	for tileset in TILESETS:
		var tiles := _mean_and_max(tileset)
		if tiles[0].r - tiles[0].g > tile_red:
			tile_red = tiles[0].r - tiles[0].g
			reddest = tileset.get_file()
		_check(tiles[1] < 0.005, "%s has no patch of white to mistake for a glint (%.2f%%)" % [tileset.get_file(), tiles[1] * 100.0])
	for path in TELL_SPRITES:
		var body := _mean_and_max(path)
		var mean: Color = body[0]
		# How far the glow pushes the body toward red, against the tiles behind it.
		var glow_red := minf(mean.r * GLOW.r, 1.0) - mean.g * GLOW.g
		_check(glow_red - tile_red > 0.12, "the red glow shows on %s (%.2f over %s)" % [path.get_file(), glow_red - tile_red, reddest])
		_check(body[1] < 0.005, "%s has no patch of white to mistake for a glint (%.2f%%)" % [path.get_file(), body[1] * 100.0])


## Mean colour of the opaque pixels, and the share of them that are near white (a stray
## highlight is fine; a patch of white would read as a glint).
func _mean_and_max(path: String) -> Array:
	var image := (load(path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var total := Color(0, 0, 0, 0)
	var count := 0
	var white := 0
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var c := image.get_pixel(x, y)
			if c.a < 0.8:
				continue
			total += Color(c.r, c.g, c.b, 0)
			count += 1
			if c.get_luminance() > 0.93:
				white += 1
	return [total / maxf(count, 1), white / maxf(count, 1)]


func _check(condition: bool, label: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + label)
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT TEST PASSED")
	else:
		print("COMBAT TEST FAILED: %d" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

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
	root.get_node("Settings").assist = false
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
	_finish()


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
const TILESET := "res://assets/art/dark/tiles/dark_tiles.png"
const GLOW := Color(1.8, 0.45, 0.4)


func _tells_read_on_painted_art() -> void:
	var tiles := _mean_and_max(TILESET)
	for path in TELL_SPRITES:
		var body := _mean_and_max(path)
		var mean: Color = body[0]
		# How far the glow pushes the body toward red, against the tiles behind it.
		var glow_red := minf(mean.r * GLOW.r, 1.0) - mean.g * GLOW.g
		var tile_red: float = tiles[0].r - tiles[0].g
		_check(glow_red - tile_red > 0.12, "the red glow shows on %s (%.2f over the tiles)" % [path.get_file(), glow_red - tile_red])
		_check(body[1] < 0.005, "%s has no patch of white to mistake for a glint (%.2f%%)" % [path.get_file(), body[1] * 100.0])
	_check(tiles[1] < 0.005, "the tiles have no patch of white to mistake for a glint (%.2f%%)" % [tiles[1] * 100.0])


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

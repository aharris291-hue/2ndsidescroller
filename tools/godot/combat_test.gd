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
	await _new_enemies(lab)
	await _hit_reactions(lab)
	await _boss_unstitch(lab)
	await _patterns()
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


## Phase 2's enemies, each in its own pen in the lab. Patch is kept untouchable while
## they show what they do; this checks their behaviour, not his survival.
func _new_enemies(lab: Node) -> void:
	var pens: Dictionary = lab.pens
	patch.health.grant_invulnerability(60.0)

	# Paper Moths: a swarm of three, one cut each, and they dart in after a glint.
	var moths: Array = pens["moths"]
	_check(moths.size() == 3 and moths[0].health.max_health == 1, "Paper Moths come three to a swarm and tear in one cut")
	_put_patch(4420.0, 1.0)
	var darted := false
	for i in 300:
		await physics_frame
		for moth in moths:
			if is_instance_valid(moth) and moth.state == 2:
				darted = true
		if darted:
			break
	_check(darted, "a Paper Moth darts at Patch")
	var moth: Node = moths[0]
	moth.health.clear_invulnerability()
	moth.health.take_damage(1, patch.global_position)
	await create_timer(1.0).timeout
	_check(not is_instance_valid(moth), "one cut and a moth is gone")

	# Inkwell Turret: fires straight shots; a cut sends one back for 2 damage.
	var turret: Node = pens["turret"][0]
	_put_patch(turret.global_position.x - 500.0, 1.0)
	var shot: Node = null
	for i in 360:
		await physics_frame
		for node in lab.get_node("Actors").get_children():
			if node is Area2D and node.get(&"reflected") == false:
				shot = node
		if shot:
			break
	_check(shot != null and absf(shot.velocity.y) < absf(shot.velocity.x), "the Inkwell Turret fires a straight shot")
	if shot:
		shot._on_area_entered(patch.attack_hitbox)
		_check(shot.reflected and signf(shot.velocity.x) == signf(turret.global_position.x - shot.global_position.x),
			"a cut sends the shot back toward the turret")
		shot.global_position = turret.global_position + Vector2(-40, -60)
		var before: int = turret.health.current
		turret.health.clear_invulnerability()
		await _frames(6)
		_check(turret.health.current == before - 2, "the turret's own shot hurts it (%d -> %d)" % [before, turret.health.current])

	# Folded Crane: glows red, dives unblockable, and sticks in the ground on a miss.
	var crane: Node = pens["crane"][0]
	_put_patch(crane.global_position.x, 1.0)
	var saw_unblockable := false
	var stuck := false
	for i in 600:
		await physics_frame
		if crane.state == 2 and crane.contact_hitbox.unblockable:
			saw_unblockable = true
			# Step aside, so the dive misses.
			_put_patch(crane.global_position.x - 400.0, 1.0)
		if crane.is_stuck():
			stuck = true
			break
	_check(saw_unblockable, "the Folded Crane's dive can't be guarded (red glow)")
	_check(stuck, "a missed dive sticks the crane's beak in the ground")

	# Mimic Book: a closed book until Patch is close.
	var mimic: Node = pens["mimic"][0]
	_check(mimic.is_disguised() and not mimic.contact_hitbox.active, "the Mimic Book lies there like any other book")
	_put_patch(mimic.global_position.x - 120.0, 1.0)
	await _frames(10)
	_check(not mimic.is_disguised() and mimic.contact_hitbox.active, "close up, the Mimic Book snaps open")

	# Inked elite: tougher, quicker, and leaves a pool of ink.
	var inked: Node = pens["inked"][0]
	var plain: Node = pens["soggies"][0] if not pens["soggies"].is_empty() else null
	_check(inked.is_in_group(&"inked") and plain != null
		and inked.health.max_health == ceili(plain.health.max_health * 1.5), "an Inked Soggy has half again the health")
	inked.health.clear_invulnerability()
	inked.health.take_damage(999, inked.global_position)
	await _frames(5)
	_check(lab.get_node("Actors").find_child("InkPool", false, false) != null, "an Inked elite leaves a pool of ink")
	patch.health.clear_invulnerability()
	_put_patch(400.0, 1.0)
	await _frames(30)


## Each move lands differently: light cuts flinch, heavies reel, the thrust sends an
## enemy tumbling into the next one, and the Plunge crushes.
func _hit_reactions(lab: Node) -> void:
	patch.health.grant_invulnerability(60.0)
	_put_patch(400.0, 1.0)
	# Patch's moves carry their reactions (FLINCH 0, REEL 1, LAUNCH 2, SEND 3, CRUSH 4).
	patch._combo_left = 0.0
	patch._start_attack()
	var light: int = patch.attack_hitbox.reaction
	patch.combo_step = 3
	patch._combo_left = 1.0
	patch._start_attack()
	var thrust: int = patch.attack_hitbox.reaction
	patch._attack_kind = 4
	patch._heavy_strike()
	var heavy: int = patch.attack_hitbox.reaction
	patch._attack_kind = 5
	patch._heavy_strike()
	var launcher: int = patch.attack_hitbox.reaction
	patch.attack_hitbox.active = false
	_put_patch(400.0, 1.0)
	_check([light, thrust, heavy, launcher] == [0, 3, 1, 2],
		"light cuts flinch, the thrust sends, heavies reel, the launcher launches (%s)" % str([light, thrust, heavy, launcher]))

	var scene: PackedScene = load("res://scenes/enemies/soggy.tscn")
	var reaction: Script = load("res://scripts/components/hit_reaction.gd")
	var actors := lab.get_node("Actors")
	var a: Node2D = scene.instantiate()
	var b: Node2D = scene.instantiate()
	a.position = Vector2(2560, 900)
	b.position = Vector2(2710, 900)
	actors.add_child(a)
	actors.add_child(b)
	await _frames(20)
	# Tough enough to take every reaction in turn.
	for foe in [a, b]:
		foe.health.max_health = 20
		foe.health.set_health(20)
	var hit := Hitbox.new()
	hit.collision_layer = 0
	hit.monitorable = false
	actors.add_child(hit)

	hit.global_position = a.global_position + Vector2(-60, -30)
	hit.reaction = 0
	a._on_hit(hit)
	_check(not reaction.is_reeling(a) and absf(a._knockback.x) < 250.0, "a light cut only makes a Soggy flinch")
	await create_timer(0.3).timeout
	a.health.clear_invulnerability()
	hit.global_position = a.global_position + Vector2(-60, -30)
	hit.reaction = 1
	a._on_hit(hit)
	_check(reaction.is_reeling(a), "a heavy cut leaves a Soggy reeling, unable to attack")
	await create_timer(0.6).timeout
	_check(not reaction.is_reeling(a), "it finds its feet again")

	a.health.clear_invulnerability()
	var b_before: int = b.health.current
	hit.global_position = a.global_position + Vector2(-60, -30)
	hit.reaction = 3
	hit.knockback = 900.0
	a._on_hit(hit)
	_check(a.get_node_or_null("Tumble") != null, "a sent Soggy's body becomes a weapon")
	var bowled := false
	for i in 40:
		await physics_frame
		if is_instance_valid(b) and b.health.current < b_before:
			bowled = true
			break
	_check(bowled and reaction.is_reeling(b), "a Soggy sent flying knocks into the next and hurts it")

	if is_instance_valid(b):
		b.health.clear_invulnerability()
		var base_y: float = b._sprite_scale.y
		hit.global_position = b.global_position + Vector2(0, -80)
		hit.reaction = 4
		b._on_hit(hit)
		_check(b.sprite.scale.y < base_y * 0.6 and reaction.is_reeling(b), "the Plunge crushes a Soggy flat")
	hit.queue_free()
	for foe in [a, b]:
		if is_instance_valid(foe):
			foe.queue_free()
	await _frames(5)


## A boss's Hold only wears while it's open; when it breaks, a heavy Unstitches it.
func _boss_unstitch(lab: Node) -> void:
	patch.health.grant_invulnerability(60.0)
	var boss: Node2D = (load("res://scenes/enemies/boss_millwheel.tscn") as PackedScene).instantiate()
	boss.position = Vector2(2600, 976)
	lab.get_node("Actors").add_child(boss)
	await _frames(5)
	var hud := root.get_node("HUD")
	hud.show_hud(true)
	root.get_node("EventBus").boss_started.emit("Old Millwheel", boss.health.max_health)
	var hold: Node = boss.get_node("HoldComponent")
	_check(hud.boss_hold.visible and is_equal_approx(hud.boss_hold.value, hold.max_hold), "the boss bar shows its Hold")
	hold.take_hold(3.0)
	_check(is_equal_approx(hold.current, hold.max_hold), "a spinning Millwheel's Hold can't be worn down")
	boss.state = 2
	boss._jam_left = 1.0
	boss._set_blades_active(false)
	boss._set_core_exposed(true)
	hold.take_hold(0.5)
	_check(is_equal_approx(hud.boss_hold.value, hold.max_hold - 0.5), "hits while it's jammed wear its Hold, and the bar follows")
	hold.take_hold(hold.max_hold)
	_check(boss.is_in_group(&"staggered") and boss._jam_left >= 2.9, "its Hold breaks and it stays open for the stagger")
	_check(hud.boss_seam.text.contains("Unstitch"), "the HUD says its seams are open")

	# Gran's Long Seam: Unstitch from further away, and it mends half a token.
	gs.learn_pattern(&"long_seam")
	patch.health.set_health(patch.health.max_health - 2)
	var hp_before: int = patch.health.current
	var core: Node2D = boss.get_node("Core")
	_put_patch(core.global_position.x - 230.0, 1.0)
	await _frames(3)
	_check(patch._find_staggered() == boss, "with the Long Seam, Patch can reach the core from further off (dy %d)" % int(core.global_position.y - patch.global_position.y))
	patch._start_heavy()
	_check(patch.state == 10, "a heavy press on a staggered boss starts the Unstitch")
	await create_timer(0.35).timeout
	_check(boss.health.current == boss.health.max_health - 3, "the Unstitch tears 3 health off the boss (%d)" % boss.health.current)
	_check(patch.health.current == hp_before + 1, "the Long Seam mends half a token on an Unstitch")
	_check(not boss.is_in_group(&"staggered") and is_equal_approx(hold.current, hold.max_hold)
		and hud.boss_seam.text.is_empty(), "after the Unstitch its Hold knits back and the seams close")
	# Leave before it recovers (that would spin up and call Soggies into the lab).
	boss.state = 0
	await create_timer(0.5).timeout
	boss.queue_free()
	gs.patterns.clear()
	hud.boss_bar.visible = false
	_put_patch(400.0, 1.0)
	await _frames(5)


## Gran's patterns change Patch's moves.
func _patterns() -> void:
	_check(patch._air_combo_length() == 3, "the air combo is three cuts")
	gs.learn_pattern(&"blanket_stitch")
	_check(patch._air_combo_length() == 4, "the Blanket Stitch adds a fourth")
	var window: float = patch._parry_window()
	gs.learn_pattern(&"backstitch")
	_check(is_equal_approx(patch._parry_window(), window * 1.5), "the Backstitch widens the parry window by half")
	# Quick Unpick: 0.32 s of holding reaches the first charge level (0.45 s without).
	var levels := []
	for learned in [false, true]:
		if learned:
			gs.learn_pattern(&"quick_unpick")
		_put_patch(400.0, 1.0)
		patch.state = 7
		patch._heavy_phase = 0
		patch._heavy_held = 0.0
		patch.charge_level = 0
		Input.action_press(&"heavy")
		patch._process_heavy(0.32)
		levels.append(patch.charge_level)
		Input.action_release(&"heavy")
	_check(levels == [0, 1], "the Quick Unpick charges heavies a third faster (%s)" % str(levels))
	gs.patterns.clear()
	_put_patch(400.0, 1.0)
	patch.attack_hitbox.active = false
	await _frames(10)


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
	"res://assets/art/dark/enemies/folded_crane.png",
	"res://assets/art/dark/enemies/paper_moth.png",
	"res://assets/art/dark/enemies/inkwell_turret.png",
	"res://assets/art/dark/enemies/mimic_book.png",
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

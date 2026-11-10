extends SceneTree
## Headless smoke test: boots the title screen, starts a new game, drives Patch around the
## first page (walk, jump, attack, talk, pull a tab), turns to the Margin (top-down), and
## round-trips a save. Exits non-zero if any check fails. Used by CI before exporting.
##
## Run: godot --headless --path . --script tools/godot/smoke_test.gd

var _failures: Array[String] = []
var _frame := 0
var _running := false


func _process(_delta: float) -> bool:
	if not _running:
		_running = true
		_run()
	return false


func _run() -> void:
	var game_state := root.get_node("GameState")
	var scene_manager := root.get_node("SceneManager")
	var dialogue := root.get_node("DialogueUI")
	# Test the standard rules, whatever this machine's pause-menu settings are.
	var settings = root.get_node("Settings")
	for option in [&"assist", &"assist_safe_falls", &"assist_wide_parry", &"auto_guard", &"tell_shapes", &"sound_captions"]:
		settings.set(option, false)
	settings.game_speed = 1.0
	settings.reset_bindings()
	settings.apply()
	game_state.slot = 2
	game_state.delete_save(2)

	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await _frames(20)
	_check(current_scene != null and current_scene.name == "TitleScreen", "title screen loads")
	_painted_art()
	await _voice_and_sound(dialogue)
	# Every action must work on a controller (the slam once had no button, which
	# stranded controller players at the ice on the flat Frostfold page).
	for action in [&"jump", &"attack", &"heavy", &"dash", &"guard", &"mend", &"grapple", &"slam", &"interact", &"warp", &"pause"]:
		var on_pad := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				on_pad = true
		_check(on_pad, "'%s' has a controller binding" % action)

	game_state.new_game(2)
	_check(not game_state.has_ability(&"crease_swipe"), "a new game starts without the shears (found in the Prologue)")
	game_state.unlock_ability(&"crease_swipe")
	# The test walks through enemies on its way round; it checks systems, not survival.
	game_state.max_health = 99
	game_state.health = 99
	await scene_manager.change_page("res://scenes/levels/thistledown/1_1_sodden_fields.tscn")
	await _frames(60)
	var patch := get_first_node_in_group("player") as CharacterBody2D
	_check(patch != null, "Patch spawns in the Sodden Fields")
	if patch == null:
		_finish()
		return
	_check(patch.is_on_floor(), "Patch lands on the ground")
	await _health_bars(patch)

	var start_x := patch.global_position.x
	Input.action_press(&"move_right")
	await _frames(40)
	Input.action_release(&"move_right")
	_check(patch.global_position.x > start_x + 150.0, "walking right moves Patch (%.0f px)" % (patch.global_position.x - start_x))

	var ground_y := patch.global_position.y
	Input.action_press(&"jump")
	await _frames(12)
	_check(patch.global_position.y < ground_y - 60.0, "jumping lifts Patch")
	Input.action_release(&"jump")
	await _frames(60)
	_check(patch.is_on_floor(), "Patch lands after jumping")

	Input.action_press(&"attack")
	await _frames(2)
	Input.action_release(&"attack")
	_check(patch.attack_hitbox.active, "Crease Swipe activates the attack hitbox")
	await _frames(20)
	_check(not patch.attack_hitbox.active, "attack hitbox switches off after the swipe")

	# Hit a Soggy until it dries out.
	var soggy := current_scene.get_node_or_null("Level/soggy_44_19") as Node2D
	if soggy:
		for i in 6:
			if not is_instance_valid(soggy):
				break
			patch.global_position = soggy.global_position + Vector2(-70, -10)
			patch.facing = Vector2.RIGHT
			Input.action_press(&"attack")
			await _frames(2)
			Input.action_release(&"attack")
			await _frames(25)
		await _frames(30)
		_check(not is_instance_valid(soggy), "a Soggy can be defeated")

	# Turn to the Margin (top-down page).
	await scene_manager.change_page("res://scenes/levels/margin/kitchen_table.tscn", &"FromPage")
	await _frames(30)
	patch = get_first_node_in_group("player") as CharacterBody2D
	_check(patch != null and patch.view_mode == 1, "the Margin uses the top-down view")
	if patch:
		var start_y := patch.global_position.y
		Input.action_press(&"move_down")
		await _frames(30)
		Input.action_release(&"move_down")
		_check(patch.global_position.y > start_y + 100.0, "Patch walks down in top-down view")
	# Out in the Margin Patch can save anywhere, from the pause menu.
	var pause_menu := root.get_node("PauseMenu")
	_check(pause_menu.in_margin(), "the pause menu offers 'Save here' in the Margin")
	if patch:
		pause_menu._on_save_here()
		_check(game_state.checkpoint_page == current_scene.scene_file_path
			and game_state.checkpoint_position.distance_to(patch.global_position) < 1.0
			and game_state.read_save(2).get("checkpoint_page", "") == current_scene.scene_file_path,
			"'Save here' saves with Patch's own spot as the checkpoint")

	await _chapter_one(game_state, scene_manager, dialogue)
	await _chapter_two(game_state, scene_manager, dialogue)
	await _blank_margins(game_state, scene_manager, dialogue)
	await _rematches(game_state, scene_manager, dialogue)
	await _arcade(game_state, scene_manager, dialogue)
	await _lab_trials(game_state, dialogue)
	await _chapter_three(game_state, scene_manager, dialogue)
	await _finale(game_state, scene_manager, dialogue)

	# Save and load.
	game_state.add_scraps(5)
	var scraps: int = game_state.scraps
	_check(game_state.save_game(), "saving writes the slot")
	game_state.new_game(2)
	# The test walks through enemies on its way round; it checks systems, not survival.
	game_state.max_health = 99
	game_state.health = 99
	_check(game_state.load_game(2) and game_state.scraps == scraps, "loading restores the slot")
	game_state.max_health = 99
	game_state.health = 99
	await _last_margin(game_state, scene_manager, dialogue)
	await _second_printing(game_state)
	game_state.delete_save(2)
	_finish()


## Post-game: Gran's papers, the Last Margin's door, and the Runaway (the true ending).
func _last_margin(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	var papers := load("res://scripts/world/papers.gd")
	var door_script := load("res://scripts/world/last_margin_door.gd")
	_check(papers.CATALOG.size() == 7, "seven papers on Gran's rack")
	_check(papers.material_for("foolscap") == null and papers.material_for("marbled") != null,
		"his own paper needs no reprint; the others do")
	for b: String in papers.STORY_BOSSES:
		game_state.set_flag("sticker:" + b, 0)
	game_state.set_flag("game_complete", false)
	game_state.set_flag("true_ending", false)
	game_state.set_flag("boss_runaway_defeated", false)
	# The finale's last page may still be turning.
	for i in 300:
		if not scene_manager.is_transitioning:
			break
		await _frames(1)
	await scene_manager.change_page("res://scenes/levels/hub/spine_hub.tscn", &"Start")
	await _wait_for_scene("SpineHub", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var door := current_scene.get_node_or_null("Level/last_margin_door_29_14")
	var rack := current_scene.get_node_or_null("Level/paper_rack_3_8")
	_check(door != null and rack != null, "the Last Margin's door and Gran's paper rack are in the Spine (%s)" % current_scene.name)
	if door == null or rack == null:
		return
	await _frames(2)
	_check(not door.visible and not rack.visible, "neither shows before the book is finished")
	game_state.set_flag("game_complete")
	game_state.set_flag("boss_forecast_defeated")
	await _frames(2)
	_check(door.visible and not door.is_open() and door_script.proofs_left() == 8,
		"then the door shows, shut, with every proof still to pull")
	for b: String in papers.STORY_BOSSES:
		game_state.set_flag("sticker:" + b, 1)
	await _frames(2)
	_check(door.is_open() and door.can_interact(), "a sticker from every boss opens it")
	_check(rack.visible and rack.can_interact(), "Gran's rack is out")
	_check(papers.refresh().has("newsprint") and papers.owned("newsprint") and not papers.owned("mourning"),
		"finishing the book earns Newsprint, and only that")
	var patch := current_scene.get_node("Patch")
	rack.interact(patch)
	await _skip_dialogue(dialogue)
	var panel: Node = rack._panel
	_check(panel != null and paused, "the rack opens its list, paused")
	panel._wear("newsprint")
	await _frames(2)
	_check(papers.worn() == "newsprint" and patch.rig.material != null and not paused,
		"Patch is reprinted on Newsprint")

	await scene_manager.change_page(door.target_page, &"Start")
	await _wait_for_scene("TheLastMargin", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	patch = current_scene.get_node("Patch")
	_check(patch.rig.material != null, "and stays on it on the next page")
	var level := current_scene.get_node("Level")
	var inked := 0
	var foes := 0
	for child in level.get_children():
		if child.get("inked") != null:
			foes += 1
			inked += 1 if child.inked else 0
	_check(foes >= 10 and inked == foes, "everything in the Last Margin is inked (%d/%d)" % [inked, foes])
	var runaway := current_scene.get_node_or_null("TheRunaway")
	_check(runaway != null and runaway.rig.material != null, "the Runaway waits at the bottom, in ink")
	if runaway == null:
		return
	for child in level.get_children():
		if child.get("inked") != null:
			child.queue_free()
	await _stand(patch, current_scene.get_node("StartZone").global_position + Vector2(0, 200))
	await _frames(10)
	_check(runaway.mode != 0, "stepping into the arena starts the fight")
	var hp: int = patch.health.current
	for i in 360:
		if patch.health.current < hp:
			break
		await _frames(1)
	_check(patch.health.current < hp, "he closes in and cuts")
	var cut: Node = load("res://scripts/components/hitbox.gd").new()
	cut.damage = 1
	current_scene.add_child(cut)
	runaway.health.clear_invulnerability()
	runaway._set_mode(1, 0.5)
	for i in 3:
		runaway.health.clear_invulnerability()
		runaway._on_hurt(cut)
	_check(runaway.mode == 4, "three quick cuts and he runs")
	runaway.health.clear_invulnerability()
	runaway.health.take_damage(runaway.health.current, runaway.global_position)
	await _frames(5)
	await _skip_dialogue(dialogue)
	_check(runaway.mode == 9 and runaway.mend_spot != null, "at zero he kneels and waits")
	runaway._on_hurt(cut)
	_check(runaway.mode == 9, "cutting him again does nothing")
	runaway.mend_spot.interact(patch)
	await _frames(4)
	await _skip_dialogue(dialogue)
	await _wait_for_scene("TheLastMarginEnd", 600)
	_check(game_state.get_flag("true_ending") and papers.owned("mourning"), "holding out his paw is the true ending")
	_check(game_state.checkpoint_page.ends_with("spine_hub.tscn"), "and the book reopens in the Spine")
	for i in 600:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue, 60)
	await _wait_for_scene("TitleScreen", 600)
	_check(game_state.get_flag("true_ending_seen"), "the true ending plays to the end")


## Post-game: the Second Printing (New Game+) of a finished book.
func _second_printing(game_state: Node) -> void:
	var printing := load("res://scripts/world/second_printing.gd")
	game_state.set_flag("game_complete")
	game_state.set_flag("sticker:millwheel", 3)
	game_state.set_flag("paper_finish", "newsprint")
	game_state.unlock_ability(&"tape_tail")
	var health: int = game_state.max_health
	_check(game_state.save_game(), "a finished book is saved")
	_check(printing.available(game_state.read_save(2)), "a finished book can be printed again")
	_check(printing.begin(2), "the Second Printing begins")
	_check(game_state.printing == 1 and game_state.abilities.is_empty() and not game_state.get_flag("game_complete"),
		"it starts the story over")
	_check(game_state.max_health == health and int(game_state.get_flag("sticker:millwheel", 0)) == 3
		and game_state.get_flag("paper:newsprint") and game_state.get_flag("paper:watermarked"),
		"keeping his health, stickers and papers, and earning Watermarked")
	game_state.new_game(2)
	_check(game_state.load_game(2) and game_state.printing == 1, "the printing is saved")
	var soggy := (load("res://scenes/enemies/soggy.tscn") as PackedScene).instantiate()
	var base: int = soggy.get_node("HealthComponent").max_health
	root.add_child(soggy)
	await _frames(1)
	_check(soggy.health.max_health == ceili(base * 1.5), "enemies are half again as tough (%d -> %d)" % [base, soggy.health.max_health])
	soggy.queue_free()
	game_state.printing = 0


func _chapter_one(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	# Prologue P-1: the text map builds a shelf Patch can stand on, and the lamps go out.
	await scene_manager.change_page("res://scenes/levels/prologue/p1_shelf_at_midnight.tscn")
	await _frames(40)
	await _skip_dialogue(dialogue)
	var shelf_patch := get_first_node_in_group("player") as CharacterBody2D
	_check(shelf_patch != null and shelf_patch.is_on_floor(), "Patch stands on the shelf in P-1")
	_check(current_scene.bounds.size == Vector2(72 * 64, 17 * 64), "the P-1 text map sets the page bounds")
	current_scene.lights_out()
	await _frames(200)
	await _skip_dialogue(dialogue)
	_check(game_state.get_flag("p1_lights_out"), "the lamps go out at the end of the shelf")

	# P-2: the ink rises once Patch has left Drizzle, and cutting the thread opens the exit.
	await scene_manager.change_page("res://scenes/levels/prologue/p2_the_rising.tscn")
	await _frames(20)
	await _skip_dialogue(dialogue)
	var ink := current_scene.get_node("Ink") as Node2D
	var ink_start := ink.position.y
	await _frames(240)
	_check(ink.position.y < ink_start - 30.0, "the ink rises in P-2")
	var bridge := current_scene.get_node("Level/thread_bridge_10_12")
	bridge.cut()
	_check(game_state.get_flag("cut_the_thread"), "the thread bridge can be cut")
	await _skip_dialogue(dialogue)
	await _spine_hub(game_state, scene_manager, dialogue)
	await _thistledown(game_state, scene_manager, dialogue)

	await _thistledown_story(game_state, scene_manager, dialogue)

	# Old Millwheel: jam the sails with the three tabs, hit the core, three times over.
	await scene_manager.change_page("res://scenes/levels/thistledown/boss_mill_floor.tscn")
	await _frames(20)
	await _skip_dialogue(dialogue)
	var patch = get_first_node_in_group("player")
	patch.health.max_health = 99
	patch.health.set_health(99)
	var boss := current_scene.get_node("OldMillwheel")
	boss.start_fight()
	_check(boss.state == 1, "the Old Millwheel fight starts")
	# Three jams win it; spare cycles cover a jam lost to a stray Soggy or drip knocking
	# Patch off the core (their spawns are random).
	for cycle in 8:
		if game_state.get_flag("boss_millwheel_defeated") or boss.health.is_dead():
			break
		for tab_name in ["MooringTab1", "MooringTab2", "MooringTab3"]:
			await current_scene.get_node("Props/" + tab_name).interact(null)
		await _frames(5)
		if cycle == 0:
			_check(boss.state == 2, "pulling all three tabs jams the sails")
		# Three landed cuts per jam; spare swings cover a cut lost to a stray Soggy or drip
		# (their spawns are random, so the run must not hinge on the random stream).
		for hit in 6:
			if hit > 0 and boss.state != 2:
				break
			# Standing on the floor beside the mill (not hovering): the core must be in reach.
			patch.global_position = boss.global_position + Vector2(-74, -60)
			patch.velocity = Vector2.ZERO
			patch.facing = Vector2.RIGHT
			await _frames(25)
			if cycle == 0 and hit == 0:
				_check(patch.is_on_floor(), "Patch stands on the floor beside the Old Millwheel")
			Input.action_press(&"attack")
			await _frames(2)
			Input.action_release(&"attack")
			await _frames(30)
		await _frames(70)
	_check(game_state.get_flag("boss_millwheel_defeated"), "Old Millwheel can be defeated from the ground")
	# The light combo: four quick presses chain into the thrust.
	await _frames(30)
	var combo_steps := []
	# A stray drip or Soggy in the arena can leave Patch flinching (random spawns),
	# which would eat the first press; start from a settled, neutral stance.
	for f in 120:
		if patch.state == 0 and patch.combo_step == 0:
			break
		await physics_frame
	# The same random drips and Soggies can land mid-combo (CI saw [1, 2, 0, 1]): a hit
	# flinches Patch and drops the chain. This checks the chain, not the arena, so no
	# hit may land while it runs.
	patch.health.grant_invulnerability(5.0)
	for press in 4:
		# Count physics frames here: the swipe reads input on the physics tick.
		# Hitstop stretches a swing over more ticks, so wait for the step to change.
		var before: int = patch.combo_step
		Input.action_press(&"attack")
		for f in 2:
			await physics_frame
		Input.action_release(&"attack")
		for f in 30:
			await physics_frame
			if patch.combo_step != before:
				break
		combo_steps.append(patch.combo_step)
	_check(combo_steps == [1, 2, 3, 4], "four quick cuts chain into a combo (%s)" % str(combo_steps))
	# The new enemies load, take hits and go down.
	for path in ["res://scenes/enemies/ink_spitter.tscn", "res://scenes/enemies/tack_knight.tscn"]:
		var foe := (load(path) as PackedScene).instantiate() as CharacterBody2D
		foe.position = patch.global_position + Vector2(600, -40)
		current_scene.add_child(foe)
		await _frames(10)
		for i in 8:
			if not is_instance_valid(foe) or foe.health.is_dead():
				break
			foe.health.take_damage(1, foe.global_position + Vector2(-10, 0))
			await _frames(6)
		await _frames(40)
		_check(not is_instance_valid(foe), "%s can be defeated" % path.get_file().get_basename())
	await _frames(150)
	_check(current_scene.get_node("Props/ToGransTable").visible, "the way to Gran's table opens")

	await _hayloft(game_state, scene_manager, dialogue)

	# The interlude closes Thistledown and turns back to the Spine.
	await scene_manager.change_page("res://scenes/levels/interludes/interlude_01.tscn")
	_check(current_scene.get("next_page") == "res://scenes/levels/hub/spine_hub.tscn", "after the Millwheel's interlude Patch goes back to the Spine")
	for i in 1200:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	await _frames(90)
	_check(game_state.get_flag("chapter1_complete"), "the interlude marks Chapter 1 complete")


func _chapter_two(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R2 := "res://scenes/levels/lanternfold/"
	await _lanternfold(game_state, scene_manager, dialogue)
	# The Margin heist: the 3D desk, and a strip of real tape that mends a heart.
	await scene_manager.change_page("res://scenes/levels/margin/tape_heist.tscn", &"FromPage")
	await _frames(30)
	await _skip_dialogue(dialogue)
	var heister = get_first_node_in_group("player")
	_check(_drawn_as_desk(), "the Margin heist is drawn as the 3D desk, with Patch on it")
	var hearts_before: int = game_state.max_health
	heister.global_position = current_scene.get_node("Pickups/TapeStrip").global_position
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(game_state.max_health == hearts_before + 2, "the heist's strip of tape is a heart patch now (the Tape Tail is in the lighthouse)")
	_check(current_scene.get_node("Props/BackIntoTheBook").target_page == "res://scenes/levels/lanternfold/2_1_the_drowned_quay.tscn", "the way back from the heist leads to the Drowned Quay")

	await _shadow_wharf(game_state, scene_manager, dialogue)
	await _under_the_flap(game_state, scene_manager, dialogue)

	# The Blotch Kraken: yank both blotters to stun it, swipe its eye, three times over.
	await scene_manager.change_page(R2 + "boss_ink_deep.tscn")
	await _frames(20)
	await _skip_dialogue(dialogue)
	var patch = get_first_node_in_group("player")
	patch.health.max_health = 99
	patch.health.set_health(99)
	var boss := current_scene.get_node("BlotchKraken")
	boss.start_fight()
	_check(boss.state == 1, "the Blotch Kraken fight starts")
	# Soggies and late tentacles can knock Patch about, so keep at it until it's dry.
	var stunned_once := false
	for attempt in 40:
		if boss.state == 3 or boss.health.is_dead():
			break
		if boss.state == 1:
			for ring_name in ["BlotterRing1", "BlotterRing2"]:
				current_scene.get_node("Props/" + ring_name).yank()
			await _frames(40)
			if not stunned_once:
				stunned_once = true
				_check(boss.state == 2, "dropping both blotters stuns the Kraken")
		if boss.state == 2:
			var eye := boss.get_node("Eye") as Node2D
			patch.global_position = eye.global_position + Vector2(-74, 6)
			patch.velocity = Vector2.ZERO
			patch.facing = Vector2.RIGHT
			await _frames(3)
			Input.action_press(&"attack")
			await _frames(2)
			Input.action_release(&"attack")
			await _frames(25)
		else:
			await _frames(20)
	_check(game_state.get_flag("boss_kraken_defeated"), "the Blotch Kraken can be defeated")
	for i in 400:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	await _frames(30)
	_check(current_scene.get_node("Props/ToGransTable").visible, "the Drizzle reveal plays and the way out opens")

	await _lightkeepers_store(game_state, scene_manager, dialogue)

	await scene_manager.change_page("res://scenes/levels/interludes/interlude_02.tscn")
	for i in 1200:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	await _frames(90)
	_check(game_state.get_flag("chapter2_complete"), "the second interlude marks Chapter 2 complete")
	await _wait_for_scene("SpineHub", 240)
	_check(current_scene.name == "SpineHub", "the second interlude goes back to the Spine (now on %s)" % current_scene.name)
	_check(load("res://scripts/world/book_map.gd").region_of(R2 + "boss_ink_deep.tscn").get("id") == &"lanternfold", "the Kraken's arena belongs to Lanternfold")
	_check(not ResourceLoader.exists("res://scenes/levels/ch2_lanternfold/lanternfold_town.tscn"), "the old harbour town pages are retired")
	await _watermark_marsh(game_state, scene_manager, dialogue)



## The optional Blank Margins: showers that write ledges over the gaps, and the Unwritten
## Forecast (rain, lightning, wind) with a heart patch.
func _blank_margins(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const M := "res://scenes/levels/margins/"
	var book_map := load("res://scripts/world/book_map.gd")
	var entry: Dictionary = book_map.region(&"margins")
	_check(entry.get("optional", false) and entry["open_flag"] == "boss_kraken_defeated" and entry["door"] == M + "m_1_the_blank_margins.tscn",
		"the Blank Margins are an optional region, open after Lanternfold")
	var was_mended: bool = game_state.get_flag("boss_forecast_defeated")
	game_state.set_flag("boss_forecast_defeated", false)
	_check(not book_map.torn_regions().has("The Blank Margins"), "the finale doesn't wait on the optional Margins")
	await scene_manager.change_page("res://scenes/levels/hub/spine_hub.tscn", &"Start")
	await _wait_for_scene("SpineHub", 120)
	await _frames(10)
	await _skip_dialogue(dialogue)
	var door := current_scene.get_node_or_null("Level/region_door_26_8")
	_check(door != null and door.region_id == &"margins" and door.target_page == entry["door"], "the Spine's gallery has a door out to the Margins")

	await scene_manager.change_page(entry["door"])
	await _wait_for_scene("TheBlankMargins", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(600.0)
	var shower := current_scene.get_node("RainShower")
	shower.manual = true
	shower._set_state(&"dry")
	await _frames(4)
	var ledges := get_nodes_in_group(&"rain_platforms")
	_check(ledges.size() >= 12, "the rain writes %d ledges across the Margins" % ledges.size())
	var first: Node2D = current_scene.get_node("Level/rain_platform_18_19")
	_check(not first.solid and first._shape.disabled, "dry, a rain ledge is only an outline")
	shower._set_state(&"pouring")
	shower._left = 99.0
	await _frames(4)
	_check(first.solid and not first._shape.disabled, "in the downpour it's solid")
	patch.global_position = first.global_position + Vector2(0, -60)
	patch.velocity = Vector2.ZERO
	await _frames(30)
	_check(patch.is_on_floor() and absf(patch.global_position.y - first.global_position.y) < 64.0, "Patch stands on a ledge of rain over nothing (floor %s, %.0f vs %.0f)" % [patch.is_on_floor(), patch.global_position.y, first.global_position.y])
	shower._set_state(&"dry")
	await _frames(30)
	_check(patch.global_position.y > first.global_position.y + 100.0, "when the rain stops, so does the ledge")
	# A self-running shower goes round dry, gathering, pouring.
	shower.manual = false
	var seen := {}
	for i in 600:
		seen[shower.state] = true
		if shower.state == &"pouring" and shower.easing:
			seen[&"easing"] = true
		await _frames(1)
	_check(seen.has(&"dry") and seen.has(&"gathering") and seen.has(&"pouring") and seen.has(&"easing"), "the showers come and go, with a tell before and a flicker before they stop (%s)" % str(seen.keys()))
	var gust := current_scene.get_node("Level/gust_97_12")
	_check(gust.strength < 0.0 and gust.size.x > 1500.0, "a wind blows back across the ledges")
	_check(FileAccess.get_file_as_string("res://levels/margins/m_1_the_blank_margins.txt").contains("abilities: rain"), "the Margins' map is climb-checked with its rain ledges")
	_check(current_scene.get_node("Level/page_exit_198_19").target_page == M + "the_forecast.tscn", "the far edge of the Margins leads to the storm")

	# The Unwritten Forecast.
	await scene_manager.change_page(M + "the_forecast.tscn")
	await _wait_for_scene("LastBlankPage", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.max_health = 99
	patch.health.set_health(99)
	patch.health.grant_invulnerability(900.0)
	var boss := current_scene.get_node("TheForecast")
	var reward := current_scene.get_node("HeartPatch")
	var exit := current_scene.get_node("ExitDoor")
	_check(boss.state == 0 and not reward.visible and not exit.visible, "the storm waits, keeping its heart patch, and the way home is shut")
	patch.global_position = current_scene.get_node("StartZone").global_position + Vector2(0, 200)
	await _frames(8)
	await _skip_dialogue(dialogue)
	_check(boss.state != 0, "the fight starts")
	var rain: Node = current_scene.get_node("RainShower")
	var rained := false
	for i in 300:
		if rain.state != &"dry":
			rained = true
			break
		await _frames(1)
	_check(rained, "it calls the rain, and the ledges over the gap come with it")
	var cut := Hitbox.new()
	cut.damage = 1
	current_scene.add_child(cut)
	var hp: int = boss.health.current
	boss._on_hit(cut)
	_check(boss.health.current == hp, "cuts glance off it in the sky")
	boss._kill_tween()
	boss._downburst()
	for i in 200:
		if boss.state == 5:
			break
		await _frames(1)
	_check(boss.state == 5 and boss.is_open() and absf(boss.global_position.y - boss.floor_y) < 2.0, "a downburst brings it down on the page, spent")
	boss.health.clear_invulnerability()
	boss._on_hit(cut)
	_check(boss.health.current == hp - 1, "spent, the barometer is in reach")
	# Lightning, from two thirds.
	boss.health.set_health(boss.health.max_health * 2 / 3)
	boss._recover()
	_check(boss.phase() == 1, "at two thirds the lightning starts")
	boss._kill_tween()
	boss._lightning(2)
	await _frames(4)
	var marks := get_nodes_in_group(&"forecast_marks").size()
	_check(marks == 2 and get_nodes_in_group(&"forecast_bolts").is_empty(), "white lines mark the floor before the bolts")
	await _frames(int(boss.bolt_tell * 60.0) + 6)
	_check(get_nodes_in_group(&"forecast_bolts").size() == 2, "then the bolts come down them")
	# Wind, from one third.
	boss.health.set_health(boss.health.max_health / 3)
	await _frames(10)
	_check(boss.phase() == 2 and boss.wind != 0.0, "at one third the wind gets up")
	var first_way: float = boss.wind
	boss._wind_left = 0.05
	await _frames(6)
	_check(boss.wind == -first_way, "and turns round")
	# Down.
	boss.health.clear_invulnerability()
	boss.health.take_damage(99, Vector2.ZERO)
	cut.queue_free()
	for i in 400:
		if reward.visible:
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	_check(game_state.get_flag("boss_forecast_defeated") and boss.wind == 0.0, "the storm comes apart and the wind drops")
	_check(reward.visible and exit.visible, "under it, a heart patch, and the way home opens")
	var hearts: int = game_state.max_health
	reward._on_body_entered(patch)
	_check(game_state.max_health > hearts, "the heart patch is Patch's")
	await _frames(4)
	await _skip_dialogue(dialogue)
	_check(not book_map.torn_regions().has("The Blank Margins"), "the Margins never hold up the finale")
	if was_mended:
		game_state.set_flag("boss_forecast_defeated")

## Post-game: Gran's proof press and the boss rematches (scripts/world/rematch.gd).
func _rematches(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	var rematch := load("res://scripts/world/rematch.gd")
	_check(rematch.BOSSES.size() == 8, "every boss can be fought again (%d)" % rematch.BOSSES.size())
	for b: Dictionary in rematch.BOSSES:
		_check(ResourceLoader.exists(b["scene"]), "%s's arena is there" % b["name"])
		_check(rematch.INK_TUNING.has(b["id"]), "%s has an inked phase" % b["name"])
	_check(rematch.rank_for(80.0, 0, 100.0) == 4 and rematch.rank_for(80.0, 2, 100.0) == 3
		and rematch.rank_for(140.0, 2, 100.0) == 2 and rematch.rank_for(140.0, 6, 100.0) == 1
		and rematch.rank_for(140.0, 0, 100.0) == 3, "stickers: gilt only for a clean fight under par")
	_check(rematch.clock(84.0) == "1:24" and rematch.clock(171.0) == "2:51", "fight times read as minutes and seconds")
	var flags_before: Dictionary = game_state.flags.duplicate()
	for b: Dictionary in rematch.BOSSES:
		game_state.set_flag(b["flag"], false)
	_check(not rematch.any_unlocked() and not rematch.start("millwheel"), "nothing to fight again before a page is mended")
	game_state.set_flag("boss_forecast_defeated")
	game_state.set_flag("sticker:forecast", 0)
	game_state.set_flag("sticker_time:forecast", 0.0)
	game_state.rematch = "forecast"
	rematch.page_loaded("res://scenes/levels/hub/spine_hub.tscn")
	_check(game_state.rematch == "", "turning to any other page ends a rematch")
	_check(not rematch.retry(), "with no rematch running, a torn Patch goes back to his bookmark")

	await scene_manager.change_page("res://scenes/levels/hub/spine_hub.tscn", &"Start")
	await _wait_for_scene("SpineHub", 120)
	await _frames(10)
	await _skip_dialogue(dialogue)
	var press := current_scene.get_node_or_null("Level/proof_press_30_8")
	_check(press != null and press.can_interact(), "Gran's proof press stands in the gallery")
	var panel_script := load("res://scripts/ui/rematch_panel.gd")
	_check(panel_script.row_text("forecast").contains("no sticker yet") and panel_script.row_text("millwheel").contains("not mended"),
		"the press lists mended pages, and keeps the rest back")

	# Pull the Forecast's proof.
	_check(rematch.start("forecast"), "a proof of the storm's page")
	await _wait_for_scene("LastBlankPage", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(game_state.rematch == "forecast", "the rematch survives the page turn")
	var boss := current_scene.get_node_or_null("TheForecast")
	var run := current_scene.get_node_or_null("Rematch")
	_check(boss != null and run != null and not current_scene.get_node("ExitDoor").visible,
		"the storm is back on its mended page, and the way out is shut")
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.global_position = current_scene.get_node("StartZone").global_position + Vector2(0, 200)
	await _frames(8)
	await _skip_dialogue(dialogue)
	_check(boss.state != 0, "the rematch starts the same way")
	await _frames(30)
	_check(run.elapsed > 0.2, "the clock runs (%.2f s)" % run.elapsed)
	patch.health.clear_invulnerability()
	patch.health.take_damage(1, Vector2.ZERO)
	_check(run.hits == 1, "and counts the hits Patch takes")
	patch.health.max_health = 99
	patch.health.set_health(99)
	patch.health.grant_invulnerability(900.0)
	var rain_was: Array = boss.rain_every.duplicate()
	# Patch stands still here: the inked wind would blow him out of the page's exit.
	boss.wind_strength = 0.0
	boss.health.clear_invulnerability()
	boss.health.take_damage(99, Vector2.ZERO)
	await _frames(2)
	_check(is_instance_valid(boss) and run.inked and boss.health.current == boss.health.max_health / 3 and boss.phase() == 2,
		"out of health, it comes back inked with a third of it (%d)" % boss.health.current)
	_check(absf(boss.rain_every[0] - rain_was[0] * 0.8) < 0.01, "inked, it calls the rain sooner")
	_check(not game_state.get_flag("sticker:forecast", 0), "no sticker yet")
	var inked := false
	for i in 240:
		if not get_nodes_in_group(&"rematch_ink").is_empty():
			inked = true
			break
		await _frames(1)
	_check(inked, "ink rains on the arena")
	boss.health.clear_invulnerability()
	boss.health.take_damage(99, Vector2.ZERO)
	await _frames(4)
	_check(run.finished and int(game_state.get_flag("sticker:forecast", 0)) >= 1 and float(game_state.get_flag("sticker_time:forecast", 0.0)) > 0.0,
		"beaten for good, the ledger gets a %s sticker" % rematch.STICKERS[int(game_state.get_flag("sticker:forecast", 0))])
	_check(not current_scene.get_node("ExitDoor").visible and (current_scene.get_node_or_null("HeartPatch") == null or not current_scene.get_node("HeartPatch").visible), "and the heart patch isn't given twice")
	await _wait_for_scene("SpineHub", 600)
	await _frames(60)
	patch = current_scene.get_node("Patch") as CharacterBody2D
	_check(game_state.rematch == "" and patch.global_position.distance_to(rematch.HUB_SPOT) < 120.0,
		"then it's back to the press (%s, %s)" % [game_state.rematch, patch.global_position])
	_check(panel_script.row_text("forecast").contains("sticker, best"), "the press shows the best sticker and time")

	# The Sogg: in a rematch its last cut brings the ink back instead of Drizzle.
	game_state.set_flag("boss_sogg_defeated")
	game_state.rematch = "sogg"
	await scene_manager.change_page("res://scenes/levels/finale/f_2_the_deepest_fold.tscn")
	await _wait_for_scene("TheDeepestFold", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var sogg := current_scene.get_node("TheSogg")
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	sogg.start_fight()
	sogg.phase = 2
	sogg.health.set_health(1)
	sogg.health.clear_invulnerability()
	sogg.health.take_damage(5, Vector2.ZERO)
	await _frames(4)
	_check(sogg.state != 10 and sogg.drizzle == null and sogg.health.current == sogg.health.max_health / 3,
		"the Sogg comes back inked, and the flood with it")
	sogg.health.clear_invulnerability()
	sogg.health.take_damage(99, Vector2.ZERO)
	await _frames(4)
	_check(sogg.drizzle == null and int(game_state.get_flag("sticker:sogg", 0)) >= 1, "beaten again, no tail is given: a sticker instead")
	await _wait_for_scene("SpineHub", 600)
	await _frames(60)
	game_state.flags = flags_before
	game_state.rematch = ""

## Post-game: Gran's penny theatre (scripts/world/arcade.gd) and its games.
func _arcade(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	var arcade := load("res://scripts/world/arcade.gd")
	var theater := load("res://scripts/minigames/shadow_theater.gd")
	var race := load("res://scripts/minigames/boat_race.gd")
	_check(arcade.GAMES.size() == 4, "the penny theatre has three shadow shows and Flood Run")
	for g: Dictionary in arcade.GAMES:
		_check(ResourceLoader.exists(g["scene"]), "%s's page is there" % g["name"])
	_check(theater.arcade_rank(96) == 4 and theater.arcade_rank(90) == 3 and theater.arcade_rank(72) == 2 and theater.arcade_rank(40) == 1,
		"shadow shows rank by the share of shadows caught")
	_check(race.arcade_score(12, 2) == 70 and race.arcade_score(1, 3) == 0, "Flood Run scores scraps less bumps")
	_check(race.arcade_rank(20, 24, 0, 3) == 4 and race.arcade_rank(5, 24, 1, 3) == 3 and race.arcade_rank(5, 24, 4, 3) == 1,
		"a clean run with most of the scraps is Gilt; holed is Paper")
	for g: Dictionary in arcade.GAMES:
		game_state.set_flag("arcade:" + g["id"], 0)
		game_state.set_flag("arcade_rank:" + g["id"], 0)
	var scraps: int = game_state.scraps
	_check(arcade.record("waltz", 80, 2, 2) == 40 and game_state.scraps == scraps + 40, "a first score pays scraps")
	_check(arcade.record("waltz", 70, 1, 2) == 0 and arcade.best("waltz") == 80 and arcade.best_rank("waltz") == 2,
		"a worse one pays nothing and the best stands")
	game_state.set_flag("arcade:waltz", 0)
	game_state.set_flag("arcade_rank:waltz", 0)

	await scene_manager.change_page("res://scenes/levels/hub/spine_hub.tscn", &"Start")
	await _wait_for_scene("SpineHub", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var cabinet := current_scene.get_node_or_null("Level/penny_theatre_16_14")
	_check(cabinet != null and cabinet.can_interact(), "Gran's penny theatre stands on the Spine's ground floor")

	# A short show, played by itself.
	arcade.pending = {"id": "waltz", "settings": {"bpm": 240.0, "beats": 8, "chart_seed": 11, "autoplay": true}}
	await scene_manager.change_page("res://scenes/minigames/shadow_theater.tscn")
	await _wait_for_scene("ShadowTheater", 120)
	_check(arcade.pending.is_empty() and current_scene.bpm == 240.0, "the show takes the theatre's settings")
	for i in 900:
		if current_scene.is_finished():
			break
		await _frames(1)
	_check(current_scene.is_finished() and arcade.best("waltz") == 100 and arcade.best_rank("waltz") == 4,
		"a perfect show is recorded as Gilt (%d)" % arcade.best("waltz"))
	await _wait_for_scene("SpineHub", 900)
	await _frames(30)
	var patch := current_scene.get_node("Patch") as Node2D
	_check(patch.global_position.distance_to(arcade.HUB_SPOT) < 120.0, "then back to the theatre")

	# A short Flood Run.
	arcade.pending = {"id": "flood_run", "settings": {"course_length": 2600.0}}
	await scene_manager.change_page("res://scenes/minigames/flood_run.tscn")
	await _wait_for_scene("FloodRun", 120)
	_check(current_scene.course_length == 2600.0 and current_scene.quest_id == "", "Flood Run is the arcade's own race")
	for i in 1200:
		if current_scene.is_finished():
			break
		await _frames(1)
	_check(current_scene.is_finished() and arcade.best_rank("flood_run") >= 1, "the boat reaches the end and the run is ranked")
	await _wait_for_scene("SpineHub", 900)
	await _frames(30)


## Post-game: the Combat Lab's trial floor (scripts/world/lab_trials.gd).
func _lab_trials(game_state: Node, dialogue: Node) -> void:
	var trials_script := load("res://scripts/world/lab_trials.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(trials_script.RECORDS_PATH))
	_check(trials_script.TRIALS.size() == 6, "six trials on the board")
	var clean: Dictionary = trials_script.trial("clean_cut")
	_check(trials_script.medal_for(clean, 10.0) == 3 and trials_script.medal_for(clean, 25.0) == 2 and trials_script.medal_for(clean, 90.0) == 1,
		"medals by time: gold, silver, bronze")
	change_scene_to_file("res://scenes/levels/combat_lab/combat_lab.tscn")
	await _wait_for_scene("CombatLab", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var lab := current_scene
	var trials := lab.get_node_or_null("LabTrials")
	_check(trials != null and lab.bounds.size.x >= 8900.0, "the Combat Lab runs on to a trial floor")
	var patch := lab.get_node("Patch") as CharacterBody2D
	patch.global_position = Vector2(7100, 900)
	await _frames(10)
	var board: Node = null
	for child in trials.get_children():
		if child.has_method("can_interact"):
			board = child
	_check(board != null and board.can_interact(), "a trial board stands by the gate")

	_check(trials.start("clean_cut"), "Clean Cut starts")
	await _frames(4)
	_check(trials.running() and not trials._gate.get_child(0).disabled and get_nodes_in_group(&"lab_trial_enemies").size() == 4,
		"the gate drops and four Soggies come")
	_check(patch.global_position.x > trials_script.FLOOR_LEFT, "Patch is on the trial floor")
	patch.health.grant_invulnerability(0.0)
	for e in get_nodes_in_group(&"lab_trial_enemies"):
		e.queue_free()
	await _frames(6)
	_check(not trials.running() and trials.won and int(trials_script.best("clean_cut").get("medal", 0)) == 3,
		"cleared fast and untouched: gold")
	await _frames(4)
	_check(trials._gate.get_child(0).disabled, "and the gate lifts")

	trials.start("clean_cut")
	await _frames(4)
	patch.health.clear_invulnerability()
	patch.health.take_damage(1, Vector2.ZERO)
	await _frames(4)
	_check(not trials.running() and not trials.won and int(trials_script.best("clean_cut")["medal"]) == 3,
		"touched once in Clean Cut, it fails, and the gold stands")
	_check(get_nodes_in_group(&"lab_trial_enemies").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).is_empty(), "a failed trial clears the floor")
	await _frames(4)

	trials.start("glint")
	await _frames(4)
	patch.health.grant_invulnerability(600.0)
	for i in 5:
		root.get_node("EventBus").player_parried.emit()
	await _frames(4)
	_check(trials.won and int(trials_script.best("glint").get("medal", 0)) >= 1, "five parries win The Glint")

	trials.start("grans_hand")
	await _frames(4)
	root.get_node("EventBus").style_changed.emit(5, 0.0)
	await _frames(4)
	_check(trials.won, "Gran's Hand on the style meter wins its trial")

	trials.start("inked")
	await _frames(4)
	var inked := get_nodes_in_group(&"lab_trial_enemies").filter(func(n: Node) -> bool: return n.get(&"inked") == true)
	_check(inked.size() == 2, "the Inked trial sends inked Soggies")
	trials._end(false, "test")
	await _frames(4)
	_check(patch.health.floor_health == 0, "after a trial Patch can be torn again as usual")
	game_state.sandbox = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(trials_script.RECORDS_PATH))

func _chapter_three(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const CH3 := "res://scenes/levels/ch3_spine/"
	# The old Frostfold, Spine and paperclip-heist pages are retired: the Spine Peaks
	# (scenes/levels/peaks) climb to the Sogg now, tested in _spine_peaks.
	for old in ["the_spine", "frostfold_slopes", "frostfold_flat"]:
		_check(not ResourceLoader.exists(CH3 + old + ".tscn"), "the old %s page is retired" % old)
	_check(not ResourceLoader.exists("res://scenes/levels/margin/paperclip_heist.tscn"), "the old paperclip heist is retired")
	_check(game_state.has_ability(&"pop_up_slam") and game_state.get_flag("patch_told_truth"), "Patch reaches the Sogg with the Pop-Up Slam, having told the truth")

	# The way down: the Spine's door (or the summit) turns first to Gran's table,
	# then down into the Gutter.
	_check(not ResourceLoader.exists(CH3 + "sogg_arena.tscn"), "the old summit fight with the Sogg is retired (the whole fight is at the bottom of the Gutter now)")
	var door: Node = load("res://scripts/world/finale_door.gd").new()
	root.add_child(door)
	_check(door.target_page == "res://scenes/levels/interludes/interlude_03.tscn", "the first time down, Gran's table comes first")
	door.free()
	await scene_manager.change_page("res://scenes/levels/interludes/interlude_03.tscn")
	for i in 1200:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	await _frames(90)
	_check(game_state.get_flag("chapter3_complete"), "the third interlude marks Chapter 3 complete")
	door = load("res://scripts/world/finale_door.gd").new()
	root.add_child(door)
	_check(door.target_page == "res://scenes/levels/finale/f_1_the_gutter_descent.tscn", "after that, the way down goes straight to the Gutter")
	door.free()


func _finale(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const FIN := "res://scenes/levels/finale/"
	# F-1 The Gutter Descent: the third interlude turns the page down into it.
	await _wait_for_scene("TheGutterDescent", 900)
	_check(current_scene.name == "TheGutterDescent", "the third interlude turns down into the Gutter")
	_check(not ResourceLoader.exists(FIN + "the_gutter.tscn"), "the old Gutter page is retired")
	await _frames(30)
	await _skip_dialogue(dialogue)
	var level := current_scene.get_node("Level")
	var patch := get_first_node_in_group("player") as CharacterBody2D
	_check(get_nodes_in_group("companion").is_empty(), "Patch goes down into the Gutter alone")
	patch.health.max_health = 99
	patch.health.set_health(99)
	patch.health.grant_invulnerability(9000.0)
	await _stand(patch, level.get_node("story_trigger_7_7").global_position)
	for i in 60:
		if dialogue.is_active():
			break
		await _frames(1)
	_check(dialogue.is_active(), "at the top of the spine, Patch sees where the Sogg went")
	await _skip_dialogue(dialogue)
	_check(level.get_node("page_exit_1_7").target_page == "res://scenes/levels/hub/spine_hub.tscn", "the way back goes up to the Spine")

	var frozen := level.get_node_or_null("soggy_184_21")
	_check(frozen != null and frozen.frozen, "Soggies frozen into the run-off")
	# The wave locks: each seals its gates until every wave is beaten, and stays open.
	var locks := {"gutter_lock_40_19": 9, "gutter_lock_123_17": 11, "gutter_lock_201_27": 16}
	for lock_name in locks:
		for e in get_nodes_in_group(&"enemies"):
			e.free()
		var lock := level.get_node(lock_name)
		_check(not lock.is_running() and not lock.gates[0].visible, "%s stands open until Patch walks in" % lock_name)
		await _stand(patch, lock.global_position + Vector2(lock.width * 32.0, -8.0))
		await _frames(4)
		await _skip_dialogue(dialogue, 200)
		_check(lock.is_running() and lock.gates[0].visible and lock.gates[1].visible, "walking into %s shuts its gates" % lock_name)
		_check(not lock.gates[1].get_child(0).disabled, "the gates of %s are solid" % lock_name)
		var seen := 0
		var inked := 0
		var kinds := {}
		for i in 80:
			if not lock.is_running():
				break
			await _frames(20)
			for e in get_nodes_in_group(&"enemies"):
				if e.get_parent() == level and not e.is_queued_for_deletion():
					seen += 1
					if e.get("inked"):
						inked += 1
					kinds[e.scene_file_path.get_file()] = true
					e.queue_free()
			await _skip_dialogue(dialogue, 200)
		await _frames(40)
		await _skip_dialogue(dialogue, 200)
		_check(not lock.is_running() and lock.is_cleared() and not lock.gates[0].visible, "beating every wave opens %s (%d foes, %d inked, %d kinds)" % [lock_name, seen, inked, kinds.size()])
		_check(seen == locks[lock_name] and inked >= 1, "%s sends all its waves, some of them inked" % lock_name)
		if lock_name == "gutter_lock_201_27":
			_check(kinds.size() >= 7, "the last lock sends every kind of enemy in the book (%s)" % [kinds.keys()])

	# The sump: the page comes down to meet the ink, and a current runs on under it.
	var currents := level.get_children().filter(func(n: Node) -> bool: return n.get_script() != null and n.get_script().resource_path.ends_with("ink_current.gd") and n.direction == Vector2.RIGHT)
	_check(not currents.is_empty(), "a current runs under the low page in the sump (only a Blot Dive gets through)")
	patch.global_position = Vector2(67 * 64 + 32, 23 * 64)
	patch.velocity = Vector2.ZERO
	for i in 6:
		await physics_frame
	_check(patch.blotting, "into the sump as a blot")
	Input.action_press(&"move_right")
	var swum := false
	for i in 400:
		if patch.global_position.x > 87.5 * 64:
			swum = true
			break
		if not patch.blotting:
			break
		await physics_frame
	Input.action_release(&"move_right")
	_check(swum and patch.blotting and patch.breath_left > 0.5, "the current carries him under the page on one breath (%.1f s to spare)" % patch.breath_left)
	patch.global_position = Vector2(92 * 64, 22 * 64 - 8)
	patch.velocity = Vector2.ZERO
	await _frames(4)
	# The chasm: no floor, one updraft.
	var draft := level.get_node_or_null("Updraft_109_16")
	_check(draft != null and draft.size.y > 20 * 64, "the chasm has one tall updraft to glide on")
	# The shutter: pull at the bottom of the shaft, warp back to the ribbon by the door.
	var shutter_p := level.get_node("shutter_172_17")
	var tab_t := level.get_node("pull_tab_152_28")
	_check(shutter_p.open_time > 0.0 and not shutter_p.open, "a spring shutter across the way down")
	await _stand(patch, Vector2(170 * 64, 18 * 64))
	var by_door := patch.global_position
	patch._warp_cooldown = 0.0
	await _tap(&"warp")
	_check(patch.ribbon != null, "Gran's ribbon laid by the shutter")
	await _stand(patch, (tab_t as Node2D).global_position)
	tab_t.interact(patch)
	for i in 60:
		if shutter_p.open and shutter_p._shape.disabled:
			break
		await physics_frame
	patch._warp_cooldown = 0.0
	await _tap(&"warp")
	_check(patch.global_position.distance_to(by_door) < 6.0, "from the bottom of the shaft, straight back to the shutter")
	Input.action_press(&"move_right")
	await _frames(40)
	Input.action_release(&"move_right")
	_check(patch.global_position.x > (shutter_p as Node2D).global_position.x + 64.0, "and through it before it drops")
	_check(level.get_node("page_exit_228_27").target_page == "res://scenes/levels/interludes/interlude_04.tscn", "the Gutter goes on down, and the page cuts to Gran's table first")

	# Interlude 4: Nell, at 2am, with the hairdryer. Then the deepest fold.
	await scene_manager.change_page("res://scenes/levels/interludes/interlude_04.tscn")
	await _wait_for_scene("Interlude04", 300)
	for i in 1200:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	await _wait_for_scene("TheDeepestFold", 900)
	_check(game_state.get_flag("nell_has_dryer") and current_scene.name == "TheDeepestFold", "Nell sits up with the hairdryer, and Patch goes down into the deepest fold")
	_check(not ResourceLoader.exists(FIN + "deepest_fold.tscn") and not ResourceLoader.exists("res://scripts/enemies/boss_sogg_final.gd") and not ResourceLoader.exists("res://scripts/world/hairdryer_beam.gd"), "the old hairdryer fight is gone")
	await _frames(20)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player")
	patch.health.max_health = 99
	patch.health.set_health(99)
	patch.health.grant_invulnerability(900.0)
	var boss := current_scene.get_node("TheSogg")
	_check(boss.get_script().resource_path.ends_with("boss_sogg.gd") and boss.state == 0, "the Sogg waits at the bottom of the Gutter")
	_check(get_nodes_in_group("companion").is_empty(), "Patch faces it alone")
	patch.global_position = current_scene.get_node("StartZone").global_position
	await _frames(6)
	await _skip_dialogue(dialogue)
	_check(boss.state != 0 and boss.phase == 0, "the water stands up: the fight starts")
	var cut := Hitbox.new()
	cut.damage = 1
	current_scene.add_child(cut)

	# Phase 1, the wall: an arm comes down over Patch; parried, the fist sticks.
	var slam_seen := false
	var parried_ok := false
	for i in 600:
		if boss.state == 2:
			slam_seen = true
			var falling: Array = boss.arms.filter(func(a: Node2D) -> bool: return (a.get_node("Hit") as Hitbox).active)
			if not falling.is_empty():
				boss.on_parried(patch)
				parried_ok = boss.state == 4 and boss.parried == 1
				break
		await _frames(1)
	_check(slam_seen and parried_ok, "an arm comes down over Patch, and a parry buries the fist in the floor")
	var arm: Node2D = boss._down_arm
	_check(arm != null and arm.get_node("Shadow").color.a > 0.2, "its shadow lies on the floor where it fell")
	var hp: int = boss.health.current
	boss._on_arm_hit(cut, boss.arms[1] if arm == boss.arms[0] else boss.arms[0])
	_check(boss.health.current == hp, "a cut on the other arm glances off")
	boss.health.clear_invulnerability()
	boss._on_arm_hit(cut, arm)
	_check(boss.health.current == hp - 1, "the buried arm is open to the shears")
	# A surge: the wall glows red and a wave runs along the floor.
	var surge_seen := false
	for i in 900:
		if not get_nodes_in_group(&"sogg_waves").is_empty():
			surge_seen = true
			break
		await _frames(1)
	_check(surge_seen, "the wall surges, and a wave runs the length of the floor")
	# Cut the arms down until the wall falls (wall_health = 8).
	for i in 3000:
		if boss.phase != 0:
			break
		if boss.state == 2 and boss.arms.any(func(a: Node2D) -> bool: return (a.get_node("Hit") as Hitbox).active):
			boss.on_parried(patch)
		if boss.state == 4 and boss._down_arm:
			boss.health.clear_invulnerability()
			boss._on_arm_hit(cut, boss._down_arm)
		await _frames(1)
	_check(boss.phase == 1 and boss.health.current == boss.health.max_health - boss.wall_health, "after 8 cuts the wall comes down (%d/%d)" % [boss.health.current, boss.health.max_health])

	# Phase 2: it splits into waves of Soggies.
	var waves_seen := 0
	for i in 2400:
		if boss.phase == 2:
			break
		var spawn := get_nodes_in_group(&"sogg_spawn").filter(func(n: Node) -> bool: return n.is_inside_tree())
		if not spawn.is_empty():
			waves_seen = maxi(waves_seen, boss.wave + 1)
			for foe in spawn:
				foe.queue_free()
		await _frames(1)
	_check(waves_seen == boss.waves.size(), "the water comes up in %d waves of Soggies (saw %d)" % [boss.waves.size(), waves_seen])
	_check(boss.phase == 2, "and pulls itself together again, smaller, with a pale cloud in it")

	# Phase 3: the drain. A lunge leaves it spent; cuts to its heart drain the water.
	var flood_before: float = boss._flood_level
	var lowest := flood_before
	var warmest := 0.0
	var spent_seen := false
	var rain_seen := false
	var since_cut := 99
	for i in 6000:
		if boss.phase != 2:
			break
		lowest = minf(lowest, boss._flood_level)
		warmest = maxf(warmest, boss.warm.modulate.a)
		since_cut += 1
		if boss.state == 7:
			rain_seen = true
		if boss.state == 9:
			spent_seen = true
			if since_cut > 40:
				since_cut = 0
				boss.health.clear_invulnerability()
				boss._on_heart_hit(cut)
		await _frames(1)
	_check(rain_seen and spent_seen, "it rains ink on him, and lunges, and is spent")
	_check(boss.stage == 4 and lowest < flood_before - 40.0, "the water goes down a stage at a time as they talk (stage %d, %.0f -> %.0f)" % [boss.stage, flood_before, lowest])
	_check(warmest > 0.08, "a warm light comes from far above (%.2f)" % warmest)

	# Phase 4: only Drizzle is left. The shears won't cut her.
	await _frames(120)
	_check(boss.state == 10 and boss.drizzle != null and boss.mend != null, "nothing's left of the Sogg but Drizzle, torn, on the floor")
	await _skip_dialogue(dialogue)
	boss._on_drizzle_hit(cut)
	_check(dialogue.is_active() or boss._refused > 0.0, "Patch can't bring the shears down on her")
	await _skip_dialogue(dialogue)
	_check(not game_state.get_flag("boss_sogg_defeated"), "cutting her ends nothing")
	cut.queue_free()
	_check(boss.mend.prompt_text == "Give her the tail", "the only way on: give her the tail")
	boss.mend.interact(patch)
	await _frames(4)
	await _skip_dialogue(dialogue)
	await _wait_for_scene("EndingTable", 600)
	_check(game_state.get_flag("boss_sogg_defeated") and game_state.get_flag("gave_tail") and not game_state.abilities.has(&"tape_tail"), "Patch stitches her shut with the Tape Tail, and doesn't have it any more")
	_check(current_scene.name == "EndingTable", "morning comes at Gran's table")
	for i in 1200:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)

	# Nell's page: Patch's new tail, his friends, and the last page.
	await _wait_for_scene("NellsPage", 600)
	await _frames(30)
	patch = get_first_node_in_group("player")
	_check(current_scene.name == "NellsPage" and game_state.get_flag("has_new_tail"), "the ending turns to Nell's crayon page")
	_check(patch.rig.mended and patch.rig.find_child("MendedTail", true, false) != null, "Patch has his new map-and-tape tail")
	_check(game_state.abilities.has(&"tape_tail"), "the map tail is a tail again: the Tape Tail is back")
	_check(get_nodes_in_group("companion").size() >= 2, "Dot and Corrugate are back with Patch")
	patch.global_position = current_scene.get_node("Story/ArrivalTalk").global_position + Vector2(0, 150)
	await _frames(10)
	await _skip_dialogue(dialogue)
	current_scene.get_node("Actors/Drizzle").interact(null)
	await _frames(4)
	_check(dialogue.is_active(), "Drizzle can be talked to on Nell's page")
	await _skip_dialogue(dialogue)
	await scene_manager.change_page("res://scenes/levels/interludes/the_end.tscn")
	for i in 1200:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	await _wait_for_scene("TitleScreen", 900)
	_check(game_state.get_flag("game_complete") and current_scene.name == "TitleScreen", "the last page finishes the game and returns to the title")


## Phase 1: the Spine hub. The Prologue leads into it; its doors open as regions are
## mended; Gran's sewing tin sells heart patches, spools and charms; the torn map fills
## in; bookmarks remember themselves for travel; the new save data round-trips.

## Region 1 (Phase 3): the Sodden Fields' soaked paper, awnings and current; the
## Sheepfold's three waves and wool Soggies; the Drowned Chapel's pews and bell.
func _thistledown(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R1 := "res://scenes/levels/thistledown/"
	var book_map := load("res://scripts/world/book_map.gd")
	var door: String = book_map.REGIONS[1]["door"]
	_check(door == R1 + "1_1_sodden_fields.tscn", "Thistledown's door opens on 1-1 The Sodden Fields")
	await scene_manager.change_page(door)
	await _wait_for_scene("SoddenFields", 120)
	await _frames(40)
	await _skip_dialogue(dialogue)
	var patch := get_first_node_in_group("player") as CharacterBody2D
	_check(patch != null and patch.is_on_floor(), "Patch stands in the Sodden Fields")
	if patch == null:
		return
	patch.health.grant_invulnerability(600.0)

	# Soaked paper: soft underfoot (a short hop), tears under Patch, mends again.
	var sheets: Array = get_nodes_in_group(&"soaked_paper").filter(func(n: Node) -> bool:
		return absf(n.global_position.x - 66.5 * 64.0) < 64.0)
	_check(sheets.size() == 1, "a soaked sheet hangs over the first open pit")
	if sheets.size() == 1:
		var sheet: Node2D = sheets[0]
		patch.global_position = sheet.global_position + Vector2(0, -100)
		patch.velocity = Vector2.ZERO
		await _frames(16)
		_check(patch.is_on_floor() and patch.soft_ground_left > 0.0, "standing on soaked paper is soft underfoot")
		var hop_from := patch.global_position.y
		var top := hop_from
		Input.action_press(&"jump")
		for f in 30:
			await physics_frame
			top = minf(top, patch.global_position.y)
		Input.action_release(&"jump")
		_check(hop_from - top < 110.0, "jumping off soaked paper is only a hop (%.0f px)" % (hop_from - top))
		patch.global_position = sheet.global_position + Vector2(0, -100)
		patch.velocity = Vector2.ZERO
		var torn := false
		for f in 120:
			await physics_frame
			if sheet.is_torn():
				torn = true
				break
		_check(torn, "soaked paper tears under Patch's weight")
		patch.global_position = Vector2(60 * 64.0, 19 * 64.0)
		patch.velocity = Vector2.ZERO
		await create_timer(4.2).timeout
		_check(not sheet.is_torn(), "a torn sheet is mended again after a few seconds")

	# The awning: cut its rope and the sheets under it dry and hold.
	var awnings: Array = get_nodes_in_group(&"awnings").filter(func(n: Node) -> bool:
		return absf(n.global_position.x - 95.5 * 64.0) < 64.0)
	_check(awnings.size() == 1, "an awning hangs over the S5 pit")
	if awnings.size() == 1:
		var awning: Node2D = awnings[0]
		var under: Array = awning.sheltered()
		_check(under.size() == 2, "the awning shelters both sheets in its pit (%d)" % under.size())
		patch.global_position = awning.global_position + Vector2(-40, 30)
		patch.velocity = Vector2.ZERO
		patch.facing = Vector2.RIGHT
		await _frames(4)
		Input.action_press(&"attack")
		await _frames(2)
		Input.action_release(&"attack")
		await _frames(30)
		if not awning.is_down:
			awning.cut()
			_check(false, "a swing of the shears cuts the awning's rope")
		else:
			_check(true, "a swing of the shears cuts the awning's rope")
		await create_timer(1.4).timeout
		var all_dry := true
		for s in under:
			all_dry = all_dry and s.dry
		_check(all_dry, "the dropped awning dries the sheets under it")
		if not under.is_empty():
			patch.global_position = under[0].global_position + Vector2(0, -100)
			patch.velocity = Vector2.ZERO
			await create_timer(1.5).timeout
			_check(patch.is_on_floor() and not under[0].is_torn() and patch.soft_ground_left <= 0.0, "dried paper holds and is firm to jump from")

	# The drowned lane: the current pushes Patch back while he stands still.
	var currents := get_nodes_in_group(&"currents")
	_check(currents.size() >= 1, "the drowned lane has a current")
	if not currents.is_empty():
		var current: Node2D = currents[0]
		patch.global_position = current.global_position + Vector2(0, -40)
		patch.velocity = Vector2.ZERO
		await _frames(10)
		var x0 := patch.global_position.x
		await _frames(40)
		_check(patch.global_position.x < x0 - 40.0, "the current drags Patch back (%.0f px)" % (patch.global_position.x - x0))

	# 1-2 The Sheepfold.
	await scene_manager.change_page(R1 + "1_2_the_sheepfold.tscn", &"Start")
	await _wait_for_scene("TheSheepfold", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	var fold := current_scene
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.max_health = 99
	patch.health.set_health(99)
	patch.health.grant_invulnerability(600.0)
	var disguised := get_nodes_in_group(&"enemies").filter(func(n: Node) -> bool:
		return n.has_method("is_disguised") and n.is_disguised())
	_check(disguised.size() == 3, "three of the 'sheep' in the pen are Soggies in wool (%d)" % disguised.size())
	fold.hold_the_fold()
	await _frames(5)
	_check(fold.is_running() and fold.wave == 1, "walking into the pen starts the first wave")
	var waves_seen := 1
	for round in 12:
		await _frames(20)
		for enemy in get_nodes_in_group(&"enemies"):
			if enemy.is_inside_tree() and fold.is_ancestor_of(enemy):
				if enemy.has_method("is_disguised") and enemy.is_disguised():
					continue
				enemy.queue_free()
		await create_timer(1.3).timeout
		waves_seen = maxi(waves_seen, fold.wave)
		if game_state.get_flag("sheepfold_held"):
			break
	_check(waves_seen >= 3, "the Sogg sends three waves at the fold")
	_check(game_state.get_flag("sheepfold_held") and not fold.is_running(), "holding the fold through all three waves sets 'sheepfold_held'")
	_check(get_nodes_in_group(&"enemies").filter(func(n: Node) -> bool:
		return n.has_method("is_disguised") and n.is_disguised()).is_empty(), "the third wave's sheep throw off their wool")
	await _skip_dialogue(dialogue)

	# 1-3 The Drowned Chapel (top-down): push the nave's pew onto its bell stone.
	await scene_manager.change_page(R1 + "1_3_drowned_chapel.tscn", &"FromSheepfold")
	await _wait_for_scene("DrownedChapel", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	var chapel := current_scene
	patch = get_first_node_in_group("player") as CharacterBody2D
	_check(patch.view_mode == 1, "the Drowned Chapel is seen from above")
	var nave_pew: Node2D = null
	for block in get_nodes_in_group(&"push_blocks"):
		if block.global_position.x < 20 * 64.0:
			nave_pew = block
	_check(nave_pew != null, "the nave has a pew")
	if nave_pew:
		var pew_y := nave_pew.global_position.y
		patch.global_position = nave_pew.global_position + Vector2(0, 72)
		patch.velocity = Vector2.ZERO
		Input.action_press(&"move_up")
		for f in 90:
			await physics_frame
			if nave_pew.global_position.y < pew_y - 60.0:
				break
		Input.action_release(&"move_up")
		await _frames(20)
		_check(nave_pew.global_position.y < pew_y - 60.0, "leaning on a pew slides it a tile")
		for i in 5:
			nave_pew.try_push(Vector2.UP)
			await _frames(16)
		await _frames(10)
		_check(chapel.room_solved(0) and game_state.get_flag("chapel_room_1"), "a pew over the nave's bell stone solves the nave")
	await _skip_dialogue(dialogue)
	var pews_ok := get_nodes_in_group(&"bell_stones").size() == 6 and get_nodes_in_group(&"push_blocks").size() == 6
	_check(pews_ok, "the chapel has six bell stones and six pews")
	# The heart patch: a found heart adds a whole heart and heals.
	var max_before: int = game_state.max_health
	game_state.add_found_heart()
	_check(game_state.max_health == max_before + 2 and game_state.health == game_state.max_health, "a found heart patch adds a heart and heals")
	game_state.max_health = 99
	game_state.health = 99


## Thistledown's people and the rest of the region: Fluff's Lost Flock across 1-1 to
## 1-3, Dot joining, 1-4's sluices and windmill, and 1-5's climb to the mill floor.
func _thistledown_story(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R1 := "res://scenes/levels/thistledown/"
	await scene_manager.change_page(R1 + "1_2_the_sheepfold.tscn", &"Start")
	await _frames(20)
	await _skip_dialogue(dialogue)
	var patch := get_first_node_in_group("player") as CharacterBody2D
	var fluff := current_scene.get_node("Level/npc_shepherd_fluff_72_19") as Node2D
	patch.global_position = fluff.global_position + Vector2(-60, -48)
	patch.velocity = Vector2.ZERO
	await _frames(10)
	Input.action_press(&"interact")
	await _frames(2)
	Input.action_release(&"interact")
	await _frames(2)
	_check(dialogue.is_active(), "interacting with Shepherd Fluff opens dialogue")
	await _skip_dialogue(dialogue)
	_check(not dialogue.is_active(), "dialogue can be advanced to the end")
	_check(game_state.quest_started("lost_flock"), "Shepherd Fluff gives the Lost Flock quest")
	await _frames(15)
	_check(patch.input_enabled, "control returns to Patch after dialogue")
	# One sheep on each of the first three pages.
	current_scene.get_node("Level/lost_sheep_46_13").interact(null)
	await _skip_dialogue(dialogue)
	await scene_manager.change_page(R1 + "1_1_sodden_fields.tscn", &"Start")
	await _frames(20)
	await _skip_dialogue(dialogue)
	current_scene.get_node("Level/lost_sheep_166_25").interact(null)
	await _skip_dialogue(dialogue)
	current_scene.get_node("Level/npc_dot_23_19").interact(null)
	await _skip_dialogue(dialogue)
	await _frames(10)
	_check(get_first_node_in_group("companion") != null and current_scene.get_node_or_null("Level/npc_dot_23_19") == null, "Dot joins Patch as a companion")
	await scene_manager.change_page(R1 + "1_3_drowned_chapel.tscn", &"FromSheepfold")
	await _frames(20)
	await _skip_dialogue(dialogue)
	current_scene.get_node("Level/lost_sheep_21_2").interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_progress("lost_flock") == 3, "all three lost sheep can be found")
	var exit_target := ""
	for node in current_scene.get_node("Level").get_children():
		if String(node.name).begins_with("page_exit_59"):
			exit_target = node.get("target_page")
	_check(exit_target == R1 + "1_4_the_millrace.tscn", "the chapel's back door leads on to the Millrace")
	await scene_manager.change_page(R1 + "1_2_the_sheepfold.tscn", &"FromChapel")
	await _frames(20)
	await _skip_dialogue(dialogue)
	var scraps_before: int = game_state.scraps
	current_scene.get_node("Level/npc_shepherd_fluff_72_19").interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_done("lost_flock") and game_state.scraps >= scraps_before + 15, "turning in the flock pays 15 Scraps")

	# 1-4 The Millrace: the deep race sweeps Patch back until its sluice drains it.
	await scene_manager.change_page(R1 + "1_4_the_millrace.tscn", &"FromChapel")
	await _wait_for_scene("TheMillrace", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(600.0)
	var sluices := get_nodes_in_group(&"sluices")
	sluices.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.x < b.global_position.x)
	_check(sluices.size() == 3, "the Millrace has three sluices (%d)" % sluices.size())
	if sluices.size() == 3:
		var drained := true
		for sluice in sluices:
			drained = drained and sluice.drains().size() == 1
		_check(drained, "each sluice drains its own section of the race")
		var deep: Node2D = sluices[0].drains()[0]
		patch.global_position = deep.global_position + Vector2(-500, -40)
		patch.velocity = Vector2.ZERO
		await _frames(10)
		var x0 := patch.global_position.x
		Input.action_press(&"move_right")
		await _frames(50)
		Input.action_release(&"move_right")
		_check(patch.global_position.x < x0, "the deep race sweeps Patch back however hard he runs (%.0f px)" % (patch.global_position.x - x0))
		await sluices[0].interact(null)
		await _frames(60)
		_check(not deep.flowing, "opening the sluice drains its section")
		patch.global_position = deep.global_position + Vector2(-500, -40)
		patch.velocity = Vector2.ZERO
		await _frames(10)
		x0 = patch.global_position.x
		Input.action_press(&"move_right")
		await _frames(50)
		Input.action_release(&"move_right")
		_check(patch.global_position.x > x0 + 300.0, "Patch can walk the drained race")
	var mill := current_scene.get_node("Level/windmill_wheel_110_19")
	var seat := mill.get_node("Gondola0") as Node2D
	var seat_at := seat.position
	await _frames(30)
	_check(mill.spinning and seat.position.distance_to(seat_at) > 10.0, "the windmill's seats are turning")
	var letter := current_scene.get_node_or_null("Level/lost_letter_191_25")
	_check(letter != null and letter.letter == "W", "Letter W lies in the pit under the third section")
	await scene_manager.change_page(R1 + "1_4_the_millrace.tscn", &"FromMill")
	await _frames(20)
	await _skip_dialogue(dialogue)
	var reopened := get_nodes_in_group(&"sluices").filter(func(n: Node) -> bool: return n.is_open)
	_check(reopened.size() == 1, "an opened sluice stays open when the page is turned again")

	# 1-5 The Mill Stair: gears turning, sacks soaked, the crane and an inked elite on top.
	await scene_manager.change_page(R1 + "1_5_the_mill_stair.tscn", &"Start")
	await _wait_for_scene("TheMillStair", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player") as CharacterBody2D
	_check(patch.is_on_floor() and current_scene.bounds.size.y > 100 * 64, "the Mill Stair is a tall climb, and Patch starts at its foot")
	var gears := current_scene.get_node("Level").get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("gear_wheel"))
	_check(gears.size() == 3 and gears.all(func(n: Node) -> bool: return n.spinning), "three of the mill's gears turn, carrying seats")
	var sacks := get_nodes_in_group(&"soaked_paper")
	_check(sacks.size() == 12 and sacks.all(func(n: Node) -> bool: return n.wet_texture.resource_path.ends_with("flour_sack.png")), "the soaked flour sacks are slung between the beams (%d)" % sacks.size())
	var level := current_scene.get_node("Level")
	var crane := level.get_node_or_null("folded_crane_14_5")
	var elite := level.get_node_or_null("soggy_22_5")
	_check(crane != null and elite != null and elite.inked, "the Folded Crane and an Inked Soggy wait at the top")
	var top_exit := ""
	for node in level.get_children():
		if node.get("target_page") != null and String(node.name).begins_with("page_exit_32"):
			top_exit = node.get("target_page")
	_check(top_exit == R1 + "boss_mill_floor.tscn", "the top of the stair opens onto the mill floor")


func _named(level: Node, prefix: String) -> Array[Node]:
	var out: Array[Node] = []
	for node in level.get_children():
		if String(node.name).begins_with(prefix):
			out.append(node)
	out.sort_custom(func(a: Node, b: Node) -> bool: return a.position.x < b.position.x if a.position.x != b.position.x else a.position.y > b.position.y)
	return out


## Lanternfold, part 1 (Phase 3): the Drowned Quay's lanterns and the Soggies who won't
## come into their light, the Lamplighter's Climb and the Tape Tail, and the Lamp Room's
## mirror puzzle.
func _lanternfold(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R2 := "res://scenes/levels/lanternfold/"
	var book_map := load("res://scripts/world/book_map.gd")
	_check(book_map.region(&"lanternfold")["door"] == R2 + "2_1_the_drowned_quay.tscn", "the Spine's Lanternfold door opens onto the Drowned Quay")
	_check(book_map.region_of(R2 + "2_3_the_lamp_room.tscn").get("id") == &"lanternfold", "the new pages belong to Lanternfold")
	await scene_manager.change_page(R2 + "2_1_the_drowned_quay.tscn", &"Start")
	await _wait_for_scene("TheDrownedQuay", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	var level := current_scene.get_node("Level")
	var posts := _named(level, "lantern_post")
	_check(posts.size() == 13, "the Drowned Quay has thirteen lantern posts (%d)" % posts.size())
	_check(posts[0].lit and posts[1].lit and not posts[2].lit, "the first two lamps burn and the rest are cold")
	# A Soggy won't come into a lamp's light, even after Patch standing in it.
	var lamp: Node2D = posts[1]
	var soggy := _named(level, "soggy")[1] as CharacterBody2D
	soggy.global_position = Vector2(lamp.global_position.x - lamp.radius - 120.0, soggy.global_position.y)
	patch.global_position = lamp.global_position + Vector2(40, -40)
	patch.velocity = Vector2.ZERO
	await _frames(120)
	_check(soggy.global_position.x < lamp.global_position.x - lamp.radius + 8.0 and soggy.global_position.x > lamp.global_position.x - lamp.radius - 260.0,
		"a Soggy chasing Patch stops at the edge of the light (%.0f px out)" % (lamp.global_position.x - lamp.radius - soggy.global_position.x))
	# Cold posts need the hand lantern.
	var cold: Node2D = posts[2]
	_check(not cold.can_interact(), "a cold lantern can't be lit without the hand lantern")
	var hand := _named(level, "hand_lantern")
	_check(hand.size() == 1, "the lamplighter's hand lantern lies by his cart")
	patch.global_position = (hand[0] as Node2D).global_position
	await _frames(10)
	await _skip_dialogue(dialogue)
	_check(game_state.get_flag("hand_lantern") and cold.can_interact(), "with the hand lantern Patch can light cold posts")
	var fleeing := _named(level, "soggy")[2] as CharacterBody2D
	fleeing.global_position = Vector2(cold.global_position.x + 120.0, cold.global_position.y - 40.0)
	patch.global_position = cold.global_position + Vector2(-600, -40)
	await _frames(10)
	cold.interact(null)
	for i in 3:
		await physics_frame
	# (Dot's Full Stop may pin it in place, so check it is running, not how far it got.)
	_check(cold.lit and fleeing._fleeing > 0.0 and fleeing._direction > 0.0 and fleeing.velocity.x >= 0.0,
		"lighting a lamp on top of a Soggy sends it running for the dark")
	# The short-trimmed lamps gutter out behind Patch.
	var short := posts.filter(func(p: Node) -> bool: return p.gutter_after > 0.0)
	_check(short.size() == 5, "the street has five short-trimmed lamps (%d)" % short.size())
	var trimmed: Node2D = short[0]
	trimmed.gutter_after = 0.4
	trimmed.light()
	await create_timer(0.9).timeout
	_check(not trimmed.lit, "a short-trimmed lamp goes out once Patch has left its light")
	var letters := _named(level, "lost_letter").map(func(n: Node) -> String: return n.letter)
	_check(letters == ["E", "L"], "Letters E and L are on the Drowned Quay (%s)" % [letters])
	var margin := _named(level, "page_door")
	_check(margin.size() == 1 and margin[0].target_page == "res://scenes/levels/margin/tape_heist.tscn" and margin[0].is_open(), "the Margin's folded corner leads to the tape heist")
	var quay_exit := _named(level, "page_exit")
	_check(quay_exit.size() == 1 and quay_exit[0].target_page == R2 + "2_2_the_lamplighters_climb.tscn", "the mole leads on to the lighthouse")
	_check(_named(level, "tack_knight").size() == 2, "Tack Knights walk the quay")

	# 2-2 The Lamplighter's Climb.
	await scene_manager.change_page(R2 + "2_2_the_lamplighters_climb.tscn", &"Start")
	await _wait_for_scene("TheLamplightersClimb", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player") as CharacterBody2D
	level = current_scene.get_node("Level")
	_check(patch.is_on_floor() and current_scene.bounds.size.y > 60 * 64, "the lighthouse is a tall climb, and Patch starts at its foot")
	_check(_named(level, "grapple_ring").size() == 4, "brass rings carry Patch up where the stair is gone")
	var tail := _named(level, "tape_strip")
	_check(tail.size() == 1 and not game_state.has_ability(&"tape_tail"), "the Tape Tail waits on the lamplighter's landing")
	patch.global_position = (tail[0] as Node2D).global_position
	await _frames(10)
	await _skip_dialogue(dialogue)
	_check(game_state.has_ability(&"tape_tail"), "the lamplighter's tape gives Patch the Tape Tail")
	var ring := _named(level, "grapple_ring")[0] as Node2D
	for r in _named(level, "grapple_ring"):
		if r.global_position.y > ring.global_position.y:
			ring = r
	patch.global_position = ring.global_position + Vector2(-260, 300)
	patch.velocity = Vector2.ZERO
	patch.facing = Vector2.RIGHT
	await _frames(20)
	_check(patch.try_grapple(), "the first ring is in reach from the landing")
	await _frames(60)
	_check(patch.global_position.y < ring.global_position.y + 120.0, "and the Tape Tail reels Patch up to it")
	var r_letter := _named(level, "lost_letter")
	_check(r_letter.size() == 1 and r_letter[0].letter == "R", "Letter R is on a ledge off a ring")
	var climb_exit := _named(level, "page_exit").filter(func(n: Node) -> bool: return n.target_page == R2 + "2_3_the_lamp_room.tscn")
	_check(climb_exit.size() == 1, "the top of the stair opens into the Lamp Room")

	# 2-3 The Lamp Room: carry the beam through every wick in each room.
	await scene_manager.change_page(R2 + "2_3_the_lamp_room.tscn", &"Start")
	await _wait_for_scene("TheLampRoom", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	_check(get_first_node_in_group("player").view_mode == 1, "the Lamp Room is seen from above")
	var gates := _named(level, "chapel_gate")
	_check(gates.size() == 3 and not gates.any(func(g: Node) -> bool: return g.is_open), "three grilles, all shut")
	var wicks := _named(level, "beam_wick")
	_check(wicks.size() == 6 and not wicks.any(func(w: Node) -> bool: return w.lit), "six cold wicks, none lit by the mirrors as they stand")
	var solution := [[[5, 10]], [[23, 4], [30, 4], [30, 11], [36, 11]], [[43, 12], [56, 12], [56, 5]]]
	for room in 3:
		for cell in solution[room]:
			level.get_node("beam_mirror_%d_%d" % [cell[0], cell[1]]).turn()
		await _frames(5)
		await _skip_dialogue(dialogue, 200)
		_check(game_state.get_flag(["lamp_room_1", "lamp_room_2", "lighthouse_lit"][room]) and gates[room].is_open,
			"turning the mirrors right lights room %d's wicks and opens its grille" % (room + 1))
	_check(wicks.all(func(w: Node) -> bool: return w.lit), "every wick burns once the great lamp is lit")
	var lamp_exit := _named(level, "page_exit").filter(func(n: Node) -> bool: return n.target_page == R2 + "2_4_the_shadow_wharf.tscn")
	_check(lamp_exit.size() == 1, "the way down leads to the Shadow Wharf")
	_check(level.get_node_or_null("spawn_point_56_6") == null and level.get_node_or_null("FromWharf") != null, "the Lamp Room has a way back up from the wharf")
	await scene_manager.change_page(R2 + "2_3_the_lamp_room.tscn", &"Start")
	await _wait_for_scene("TheLampRoom", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(_named(current_scene.get_node("Level"), "chapel_gate").all(func(g: Node) -> bool: return g.is_open), "a solved Lamp Room stays solved")


## 2-4 The Shadow Wharf: shadows that hold only while their lamp burns, gusts off the
## sea, the lamplighter's daughters and their father's five lamps, and Corrugate and his
## cat, whose joining opens the flap.
func _shadow_wharf(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R2 := "res://scenes/levels/lanternfold/"
	await scene_manager.change_page(R2 + "2_4_the_shadow_wharf.tscn", &"Start")
	await _wait_for_scene("TheShadowWharf", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	var level := current_scene.get_node("Level")
	var ledges := _named(level, "shadow_platform")
	_check(ledges.size() == 14, "the wharf has fourteen shadow ledges (%d)" % ledges.size())
	var ledge := level.get_node("shadow_platform_26_19")
	var post := level.get_node("lantern_post_22_21")
	_check(ledge.lamp == post and not ledge.solid, "a shadow ledge belongs to its nearest lamp, and is nothing while the lamp is cold")
	post.light()
	for i in 3:
		await physics_frame
	_check(ledge.solid and not ledge.get_child(0).disabled, "lighting the lamp makes its shadows solid")
	patch.global_position = ledge.global_position + Vector2(0, -60)
	patch.velocity = Vector2.ZERO
	for i in 40:
		await physics_frame
	_check(ledge.is_in_group(&"unsafe_floor") and patch._last_safe_position.y > ledge.global_position.y, "a fall never puts Patch back on a shadow")
	_check(patch.is_on_floor() and patch.global_position.y < ledge.global_position.y and patch.global_position.y > ledge.global_position.y - 80.0,
		"Patch can stand on a lit shadow (floor %s, %.0f px above it)" % [patch.is_on_floor(), ledge.global_position.y - patch.global_position.y])
	post.snuff()
	for i in 20:
		await physics_frame
	_check(not ledge.solid and patch.global_position.y > ledge.global_position.y + 20.0, "when the lamp goes out the shadow drops him")
	post.light()
	# Gusts shove Patch back along the boards.
	var gust := level.get_node("gust_50_21")
	patch.global_position = Vector2(58 * 64 + 32, 22 * 64 - 40)
	patch.velocity = Vector2.ZERO
	for i in 20:
		await physics_frame
	gust._t = 0.0
	var x0 := patch.global_position.x
	for i in 30:
		await physics_frame
	_check(gust.blowing and patch.global_position.x < x0 - 40.0, "a gust off the sea pushes Patch back (%.0f px)" % (x0 - patch.global_position.x))
	gust._t = gust.blow_time + 0.1
	for i in 5:
		await physics_frame
	_check(not gust.blowing, "and then drops")
	# Father's rounds: five lamps for the lamplighter's daughters.
	var sisters := level.get_node("npc_lamplighters_15_21")
	sisters.interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_started("festival_lanterns"), "the lamplighter's daughters ask Patch to finish their father's rounds")
	var lamps := _named(level, "lantern_").filter(func(n: Node) -> bool: return not String(n.name).begins_with("lantern_post"))
	_check(lamps.size() == 5, "five of his lamps along the wharf (%d)" % lamps.size())
	for lamp in lamps:
		lamp.interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_progress("festival_lanterns") == 5, "all five can be lit")
	sisters.interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_done("festival_lanterns"), "the daughters see it done")
	# Corrugate, his cat up the crane, and the flap.
	var flap := level.get_node("page_exit_258_21")
	_check(flap.target_page == R2 + "2_5_under_the_flap.tscn" and flap.requires_flag == "corrugate_joined", "the flap leads under the harbour, once Corrugate is with Patch")
	var corrugate := level.get_node("npc_corrugate_177_21")
	corrugate.interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_started("lost_cat"), "Corrugate asks Patch to fetch his cat")
	var crumple := level.get_node("crumple_197_9")
	_check(crumple.global_position.y < 12 * 64, "Crumple is up the crane, at the top of the shadows")
	crumple.interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_progress("lost_cat") == 1, "Crumple can be fetched down")
	corrugate.interact(null)
	await _skip_dialogue(dialogue)
	await _frames(10)
	_check(game_state.get_flag("corrugate_joined"), "Corrugate joins Patch")
	var companions := get_nodes_in_group("companion")
	_check(companions.any(func(c: Node) -> bool: return c.get("companion_flag") == "corrugate_joined"), "Corrugate follows Patch")
	_check(level.get_node("page_exit_1_21").target_spawn == &"FromWharf", "the wharf leads back up into the Lamp Room")


## 2-5 Under the Harbor Flap: islands and chains over the ink, rings over the gaps,
## Letters K and N, and the way to the Kraken.
func _under_the_flap(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R2 := "res://scenes/levels/lanternfold/"
	await scene_manager.change_page(R2 + "2_5_under_the_flap.tscn", &"Start")
	await _wait_for_scene("UnderTheFlap", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	var level := current_scene.get_node("Level")
	var letters := _named(level, "lost_letter").map(func(n: Node) -> String: return n.letter)
	_check(letters == ["K", "N"], "Letters K and N are under the flap (%s)" % [letters])
	_check(_named(level, "grapple_ring").size() == 7, "rings over the widest ink (%d)" % _named(level, "grapple_ring").size())
	_check(_named(level, "folded_crane").size() == 1 and _named(level, "inkwell_turret").size() == 1, "a crane and a turret guard the pilings")
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	# Off the first island and into the ink is a fall.
	var hp: int = game_state.health
	patch.global_position = Vector2(20 * 64, 15 * 64)
	patch.velocity = Vector2.ZERO
	for i in 40:
		await physics_frame
	patch.health.clear_invulnerability()
	patch.global_position = Vector2(24 * 64 + 32, 15 * 64)
	patch.velocity = Vector2.ZERO
	for i in 150:
		await physics_frame
	await _frames(30)
	_check(current_scene.name == "UnderTheFlap" and game_state.health < hp and patch.global_position.y < 16 * 64, "falling in the ink hurts and puts Patch back on land (hp %d of %d, y %.0f)" % [game_state.health, hp, patch.global_position.y])
	patch.health.grant_invulnerability(900.0)
	level = current_scene.get_node("Level")
	var exits := _named(level, "page_exit")
	_check(exits.any(func(e: Node) -> bool: return e.target_page == R2 + "boss_ink_deep.tscn"), "the far end leads to the Kraken")
	_check(exits.any(func(e: Node) -> bool: return e.target_page == R2 + "2_4_the_shadow_wharf.tscn" and e.target_spawn == &"FromFlap"), "and the near end back up to the wharf")


## The Lightkeeper's Store, 2-2's sealed back page: shut until the Kraken is beaten,
## then a dark run of short lamps to a heart patch and the keeper's 60 Scraps.
func _lightkeepers_store(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R2 := "res://scenes/levels/lanternfold/"
	await scene_manager.change_page(R2 + "2_2_the_lamplighters_climb.tscn", &"Start")
	await _wait_for_scene("TheLamplightersClimb", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var doors := _named(current_scene.get_node("Level"), "page_door").filter(func(d: Node) -> bool: return d.target_page == R2 + "lightkeepers_store.tscn")
	_check(doors.size() == 1 and doors[0].is_open(), "beating the Kraken unseals the keeper's store")
	await scene_manager.change_page(R2 + "lightkeepers_store.tscn", &"FromClimb")
	await _wait_for_scene("TheLightkeepersStore", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	_check(get_nodes_in_group(&"bookmarks").filter(func(n: Node) -> bool: return current_scene.is_ancestor_of(n)).is_empty(), "the store has no Bookmark")
	var level := current_scene.get_node("Level")
	_check(_named(level, "shadow_platform").all(func(l: Node) -> bool: return l.lamp != null), "every shadow in the store has a lamp to cast it")
	var hearts_before: int = game_state.max_health
	var scraps_before: int = game_state.scraps
	patch.global_position = (level.get_node("heart_patch_116_17") as Node2D).global_position
	await _frames(10)
	patch.global_position = (level.get_node("scrap_120_17") as Node2D).global_position
	await _frames(10)
	_check(game_state.max_health == hearts_before + 2, "the keeper's patch adds a heart")
	_check(game_state.scraps >= scraps_before + 60, "and his tin holds 60 Scraps")
	await _skip_dialogue(dialogue)
	game_state.max_health = 99
	game_state.health = 99


## Region 3, Watermark Marsh (part 1): ink that burns paper until Patch learns the
## Blot Dive on the Sump Road, currents that carry a blot, and the sluice wheels.
func _watermark_marsh(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R3 := "res://scenes/levels/marsh/"
	var door: Node = null
	for node in current_scene.get_node("Level").get_children():
		if node.get("region_id") == &"marsh":
			door = node
	_check(door != null and door.state() == "open" and door.target_page == R3 + "3_1_the_sump_road.tscn", "beating the Kraken opens the door to Watermark Marsh")
	_check(not game_state.has_ability(&"blot_dive"), "Patch can't Blot Dive before the Marsh")
	await scene_manager.change_page(R3 + "3_1_the_sump_road.tscn", &"Start")
	await _wait_for_scene("TheSumpRoad", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	var patch := get_first_node_in_group("player") as CharacterBody2D
	var level := current_scene.get_node("Level")
	var pools := _named(level, "Ink_")
	_check(pools.size() > 4 and _named(level, "Current_").size() >= 1, "the Sump Road has ink to cross (%d pools) and a current" % pools.size())
	var exits := _named(level, "page_exit")
	_check(exits.any(func(e: Node) -> bool: return e.target_page == "res://scenes/levels/hub/spine_hub.tscn"), "the road starts at a way back into the Spine")
	_check(exits.any(func(e: Node) -> bool: return e.target_page == R3 + "3_2_the_drowned_ledger.tscn"), "and ends at the Drowned Ledger")
	# Without the Blot Dive the ink burns a heart and puts him back on the road.
	var ditch: Node2D = pools[0]
	for pool in pools:
		if (pool as Node2D).global_position.x < ditch.global_position.x:
			ditch = pool
	patch.global_position = Vector2(4 * 64, 17 * 64)
	patch.velocity = Vector2.ZERO
	for i in 30:
		await physics_frame
	patch.health.clear_invulnerability()
	var hp: int = game_state.health
	patch.global_position = ditch.global_position + Vector2(ditch.size.x / 2.0, 40.0)
	patch.velocity = Vector2.ZERO
	for i in 20:
		await physics_frame
	_check(game_state.health < hp and not patch.blotting and not ditch.covers(patch.global_position), "the ink burns paper: a heart lost and back on the road (hp %d of %d)" % [game_state.health, hp])
	game_state.health = 99
	patch.health.grant_invulnerability(900.0)
	# The watermark on the hill.
	var page := level.get_node("ability_page_92_15") as Node2D
	_check(page.ability_id == &"blot_dive", "the watermark on the hill teaches the Blot Dive")
	patch.global_position = page.global_position
	await _frames(10)
	await _skip_dialogue(dialogue)
	_check(game_state.has_ability(&"blot_dive"), "Patch learns the Blot Dive")
	# In the deep cut he lets the ink in: a blot, untouchable, on one breath.
	var trench: Node2D = null
	for pool in pools:
		var p := pool as Node2D
		if p.global_position.x > 128 * 64 and p.global_position.x < 140 * 64 and (trench == null or p.size.y > trench.size.y):
			trench = p
	_check(trench != null, "a deep cut of ink on the road")
	patch.health.clear_invulnerability()
	patch.global_position = trench.global_position + Vector2(trench.size.x / 2.0, trench.size.y / 2.0)
	patch.velocity = Vector2.ZERO
	for i in 10:
		await physics_frame
	_check(patch.blotting and patch.health.is_invulnerable(), "in the ink Patch is a blot, and nothing can hurt him")
	var deep_y := patch.global_position.y
	Input.action_press(&"move_down")
	for i in 20:
		await physics_frame
	Input.action_release(&"move_down")
	_check(patch.blotting and patch.global_position.y > deep_y + 20.0 or patch.is_on_floor(), "he swims down through it")
	hp = game_state.health
	patch.breath_left = 0.02
	for i in 10:
		await physics_frame
	_check(game_state.health < hp and not patch.blotting, "when his breath runs out the ink takes a heart (hp %d of %d)" % [game_state.health, hp])
	game_state.health = 99
	# Up at the skin a jump throws him out.
	patch.health.grant_invulnerability(900.0)
	patch.global_position = trench.global_position + Vector2(trench.size.x / 2.0, 20.0)
	patch.velocity = Vector2.ZERO
	for i in 6:
		await physics_frame
	_check(patch.blotting, "back in the cut")
	Input.action_press(&"jump")
	for i in 3:
		await physics_frame
	Input.action_release(&"jump")
	for i in 12:
		await physics_frame
	_check(not patch.blotting and patch.global_position.y < trench.global_position.y - 40.0, "a jump at the surface leaps him out of the ink")
	# The culvert's current carries a blot along.
	var culvert := level.get_node("Current_204_18") as Node2D
	_check(culvert.direction == Vector2.RIGHT, "the culvert runs on towards the ledger house")
	patch.global_position = culvert.global_position + Vector2(160, 100)
	patch.velocity = Vector2.ZERO
	for i in 4:
		await physics_frame
	var x0 := patch.global_position.x
	for i in 30:
		await physics_frame
	_check(patch.blotting and patch.global_position.x > x0 + 100.0, "a current carries the blot along (%.0f px)" % (patch.global_position.x - x0))
	patch.global_position = level.get_node("FromLedger").global_position
	patch.velocity = Vector2.ZERO
	await _frames(10)

	await scene_manager.change_page(R3 + "3_2_the_drowned_ledger.tscn", &"Start")
	await _wait_for_scene("TheDrownedLedger", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	_check(_named(level, "mimic_book").size() == 2, "books in the stacks that open by themselves (%d)" % _named(level, "mimic_book").size())
	_check(_named(level, "Current_").any(func(c: Node) -> bool: return c.direction == Vector2.UP), "a drain that carries a blot up to the high shelves")
	exits = _named(level, "page_exit")
	_check(exits.any(func(e: Node) -> bool: return e.target_page == R3 + "3_3_the_sluice_house.tscn"), "the ledger house leads on to the sluice")
	_check(exits.any(func(e: Node) -> bool: return e.target_page == R3 + "3_1_the_sump_road.tscn" and e.target_spawn == &"FromLedger"), "and back out to the road")

	await scene_manager.change_page(R3 + "3_3_the_sluice_house.tscn", &"Start")
	await _wait_for_scene("TheSluiceHouse", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	var wheels := get_nodes_in_group(&"sluice_wheels").filter(func(n: Node) -> bool: return current_scene.is_ancestor_of(n))
	_check(wheels.size() == 3, "three wheels in the sluice house (%d)" % wheels.size())
	var b_left := level.get_node("Current_6_13")
	var b_right := level.get_node("Current_21_13")
	_check(b_left.direction == Vector2.LEFT and b_right.direction == Vector2.LEFT, "both halves of the middle way run against Patch")
	var w1 := level.get_node("sluice_wheel_2_9")
	var w2 := level.get_node("sluice_wheel_26_7")
	var w3 := level.get_node("sluice_wheel_12_7")
	_check(w1.currents() == [b_left] and w2.currents() == [b_right], "a wheel for each half of the middle way")
	_check(w3.currents().size() == 2 and not w3.currents().has(b_left) and not w3.currents().has(b_right), "the third wheel turns two channels that lead nowhere")
	w1.interact(null)
	w2.interact(null)
	_check(b_left.direction == Vector2.RIGHT and b_right.direction == Vector2.RIGHT, "turning both wheels sends the middle way out towards the outflow")
	w1.turn()
	_check(b_left.direction == Vector2.LEFT, "and turning one back reverses it again")
	w1.turn()
	var outflow := level.get_node("page_exit_36_17") as Node2D
	_check(outflow.target_page == R3 + "3_4_the_reed_beds.tscn" and load("res://scripts/world/ink_pool.gd").ink_at(self, outflow.global_position + Vector2(-64, -32)), "the outflow, under the ink, leads on to the reed beds")
	_check(load("res://scripts/world/book_map.gd").region_of(R3 + "3_3_the_sluice_house.tscn").get("id") == &"marsh", "the sluice house belongs to the Marsh")
	game_state.max_health = 99
	game_state.health = 99
	await _marsh_part_two(game_state, scene_manager, dialogue)


## Watermark Marsh part 2: the Reed Beds and the Weir, the Heron's Reach, the Grey
## Heron, and the Tally Room behind its seal.
func _marsh_part_two(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R3 := "res://scenes/levels/marsh/"
	await scene_manager.change_page(R3 + "3_4_the_reed_beds.tscn", &"Start")
	await _wait_for_scene("TheReedBeds", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var level := current_scene.get_node("Level")
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	var channel := level.get_node("Current_98_22")
	var shaft := level.get_node("Current_130_14")
	_check(channel.direction == Vector2.LEFT and shaft.direction == Vector2.UP, "the Weir: the channel runs back at Patch, the shaft runs up")
	var w1 := level.get_node("sluice_wheel_96_21")
	var w2 := level.get_node("sluice_wheel_110_19")
	_check(w1.currents().size() == 2 and w1.currents().has(channel) and w1.currents().has(shaft), "the bank wheel turns the channel and the shaft together")
	_check(w2.currents() == [shaft], "the mat wheel turns only the shaft")
	w1.turn()
	_check(channel.direction == Vector2.RIGHT and shaft.direction == Vector2.DOWN, "one wheel alone sends the shaft the wrong way")
	w2.turn()
	_check(channel.direction == Vector2.RIGHT and shaft.direction == Vector2.UP, "both wheels open the way to the high bank")
	# Ride the shaft: a blot at its foot is carried up and out.
	patch.global_position = shaft.global_position + Vector2(64, shaft.size.y - 40)
	patch.velocity = Vector2.ZERO
	var y0 := patch.global_position.y
	for i in 70:
		await physics_frame
	_check(patch.global_position.y < y0 - 200.0, "the upwelling carries the blot up the shaft (%.0f px)" % (y0 - patch.global_position.y))
	var door := level.get_node("page_door_150_13")
	_check(door.target_page == R3 + "tally_room.tscn" and not door.is_open(), "the Tally Room is sealed until the heron is down")
	var exits := _named(level, "page_exit")
	_check(exits.any(func(e: Node) -> bool: return e.target_page == R3 + "3_5_the_herons_reach.tscn"), "the reed beds lead on to the Heron's Reach")

	await scene_manager.change_page(R3 + "3_5_the_herons_reach.tscn", &"Start")
	await _wait_for_scene("TheHeronsReach", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	_check(_named(level, "tack_knight").filter(func(n: Node) -> bool: return n.inked).size() == 2, "Inked Tack Knights in the heron's larder and on the far bank")
	_check(_named(level, "grapple_ring").size() == 5, "rings over the black lake (%d)" % _named(level, "grapple_ring").size())
	exits = _named(level, "page_exit")
	_check(exits.any(func(e: Node) -> bool: return e.target_page == R3 + "heronry.tscn"), "the reach ends at the Heronry")

	# The Grey Heron.
	await scene_manager.change_page(R3 + "heronry.tscn", &"Start")
	await _wait_for_scene("TheHeronry", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player") as CharacterBody2D
	var heron := current_scene.get_node("GreyHeron")
	var exit_door := current_scene.get_node("ExitDoor")
	_check(not exit_door.visible, "no way out of the Heronry while the heron stands")
	heron.start_fight()
	_check(heron.state == 1, "the Grey Heron fight starts")
	# A stab at the ink only splashes; at the peat it sticks.
	heron._stab(Vector2(6 * 64, 14 * 64))
	for i in 90:
		await physics_frame
	_check(heron.state != 4, "a stab into the ink doesn't stick")
	for i in 60:
		if heron.state == 1:
			break
		await physics_frame
	var hp: int = game_state.health
	patch.health.clear_invulnerability()
	patch.global_position = Vector2(14 * 64, 14 * 64 - 50)
	patch.velocity = Vector2.ZERO
	heron._stab(patch.global_position + Vector2(0, 40))
	for i in 80:
		if heron.state == 4:
			break
		await physics_frame
	_check(heron.state == 4, "a stab into the peat sticks fast")
	_check(game_state.health < hp, "and it hurts, if Patch is standing there (hp %d of %d)" % [game_state.health, hp])
	game_state.health = 99
	patch.health.grant_invulnerability(900.0)
	_check(heron.skull.monitoring, "while it's stuck its head can be cut")
	var before: int = heron.health.current
	# Let Patch shake off the hit, then cut at the beak where it's buried.
	for i in 30:
		if patch.state == 0:
			break
		await physics_frame
	patch.global_position = Vector2(14 * 64 - 80, 14 * 64 - 50)
	patch.velocity = Vector2.ZERO
	patch.facing = Vector2.RIGHT
	await _frames(2)
	Input.action_press(&"attack")
	await _frames(2)
	Input.action_release(&"attack")
	await _frames(20)
	_check(heron.health.current < before, "a cut to the stuck head hurts the heron (%d of %d)" % [heron.health.current, heron.health.max_health])
	# A sweep: anything on the peat is hit, a blot in the ink is not.
	heron.health.current = 7
	for i in 120:
		if heron.state == 1:
			break
		await physics_frame
	patch.health.clear_invulnerability()
	patch.global_position = Vector2(23 * 64, 15 * 64 + 20)
	patch.velocity = Vector2.ZERO
	for i in 6:
		await physics_frame
	hp = game_state.health
	heron._sweep()
	for i in 120:
		await physics_frame
	_check(patch.blotting and game_state.health == hp, "a blot in the ink is untouched by the wing sweep")
	patch.health.grant_invulnerability(900.0)
	# Bring it down.
	heron.health.current = 1
	heron.health.take_damage(5, heron.global_position)
	for i in 300:
		if dialogue.is_active():
			break
		await physics_frame
	await _skip_dialogue(dialogue)
	await _frames(20)
	_check(game_state.get_flag("boss_heron_defeated") and exit_door.visible, "the Grey Heron folds down, and the way back opens")
	_check(game_state.bestiary.get("heron", 0) >= 1, "Nell's book gets a page for the heron")
	var book_map := load("res://scripts/world/book_map.gd")
	_check(book_map.region(&"marsh").get("mended_flag") == "boss_heron_defeated" and book_map.region(&"peaks").get("open_flag") == "boss_heron_defeated",
		"the heron mends the Marsh and opens the way to the Peaks")

	# The Tally Room, open now.
	await scene_manager.change_page(R3 + "3_4_the_reed_beds.tscn", &"FromVault")
	await _wait_for_scene("TheReedBeds", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(current_scene.get_node("Level/page_door_150_13").is_open(), "the heron down, the Tally Room unseals")
	await scene_manager.change_page(R3 + "tally_room.tscn", &"Start")
	await _wait_for_scene("TheTallyRoom", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	_check(get_nodes_in_group(&"bookmarks").filter(func(n: Node) -> bool: return current_scene.is_ancestor_of(n)).is_empty(), "the Tally Room has no Bookmark")
	var hearts_before: int = game_state.max_health
	var scraps_before: int = game_state.scraps
	patch.global_position = (level.get_node("heart_patch_114_13") as Node2D).global_position
	await _frames(10)
	patch.global_position = (level.get_node("scrap_117_13") as Node2D).global_position
	await _frames(10)
	await _skip_dialogue(dialogue)
	_check(game_state.max_health == hearts_before + 2 and game_state.scraps >= scraps_before + 60, "the clerks' last tally: a heart patch and 60 Scraps")
	game_state.max_health = 99
	game_state.health = 99
	await _spine_peaks(game_state, scene_manager, dialogue)


## The Spine Peaks part 1: the Rime Slopes (black ice, frost gusts, rimed Soggies, the
## frozen page and the Pop-Up Slam), the Fold Works (clockwork needles, the stair of
## peaks, the Frog Fold) and Bindwell's Pattern Room (the linked folds).
func _spine_peaks(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R4 := "res://scenes/levels/peaks/"
	var book_map := load("res://scripts/world/book_map.gd")
	_check(book_map.region(&"peaks").get("door") == R4 + "4_1_the_rime_slopes.tscn", "the Peaks door opens on the Rime Slopes")
	game_state.abilities.erase(&"pop_up_slam")
	game_state.abilities.erase(&"frog_fold")
	await scene_manager.change_page(R4 + "4_1_the_rime_slopes.tscn", &"Start")
	await _wait_for_scene("TheRimeSlopes", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(book_map.region_of(R4 + "4_1_the_rime_slopes.tscn").get("id") == &"peaks" and current_scene.snow, "the Rime Slopes are in the Peaks, and it snows")
	var level := current_scene.get_node("Level")
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	# Black ice: a running Patch slides on long after he lets go; on slate he stops.
	_check(level.get_node("Ice_34_22").get_script().resource_path.ends_with("ice_sheet.gd"), "the first ice run is laid as black ice")
	patch.global_position = Vector2(40 * 64, 22 * 64 - 4)
	await _frames(20)
	patch.velocity.x = 430.0
	await _frames(20)
	var on_ice: float = patch.velocity.x
	patch.global_position = Vector2(10 * 64, 22 * 64 - 4)
	await _frames(20)
	patch.velocity.x = 430.0
	await _frames(20)
	_check(on_ice > 250.0 and absf(patch.velocity.x) < 40.0, "Patch skates on the ice (%.0f px/s after letting go) and stops on slate (%.0f)" % [on_ice, patch.velocity.x])
	_check(level.get_node("gust_83_21").snow, "the frost gust blows snow")
	# A rimed Soggy: the shears skid off; a crushing blow cracks the frost.
	var rimed := level.get_node("soggy_106_21")
	var cut := Hitbox.new()
	cut.damage = 1
	current_scene.add_child(cut)
	cut.global_position = rimed.global_position + Vector2(-40, -30)
	var hp_before: int = rimed.health.current
	rimed._on_hit(cut)
	_check(rimed.frozen and rimed.health.current == hp_before, "the shears skid off a rimed Soggy")
	cut.reaction = Hitbox.Reaction.CRUSH
	rimed.health.clear_invulnerability()
	rimed._on_hit(cut)
	_check(not rimed.frozen and rimed.health.current < hp_before, "a crushing blow cracks the frost and hurts it")
	cut.queue_free()
	for enemy in get_nodes_in_group(&"enemies"):
		if current_scene.is_ancestor_of(enemy):
			enemy.queue_free()
	# The frozen page: no slam yet, the ice holds; Gran's pattern, then it shatters.
	var ice_wall := level.get_node("ice_block_139_26")
	patch.global_position = Vector2(137 * 64, 27 * 64 - 4)
	await _frames(20)
	patch._start_slam()
	await _frames(60)
	_check(is_instance_valid(ice_wall) and not ice_wall.is_queued_for_deletion(), "without the Pop-Up Slam the ice in the frozen page holds")
	patch.global_position = (level.get_node("ability_page_132_26") as Node2D).global_position
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(game_state.has_ability(&"pop_up_slam"), "Gran's pop-up pattern in the frozen page teaches the Pop-Up Slam")
	patch.global_position = Vector2(137 * 64, 27 * 64 - 4)
	await _frames(20)
	patch._start_slam()
	await _frames(60)
	_check(not is_instance_valid(ice_wall) or ice_wall.is_queued_for_deletion() or ice_wall.get_node("CollisionShape2D").disabled, "a Pop-Up Slam shatters the ice and lets him out")
	# The fold mark under the cliff: slam it and ride the peak up.
	var fold := level.get_node("fold_mark_164_21")
	patch.global_position = fold.global_position + Vector2(0, -4)
	await _frames(20)
	var ground_y := patch.global_position.y
	patch._start_slam()
	await _frames(70)
	_check(fold.is_up and patch.global_position.y < ground_y - 180.0, "the fold mark springs a peak and carries Patch up (%.0f px)" % (ground_y - patch.global_position.y))
	var tunnel_ice := level.get_node("ice_block_177_17")
	patch.global_position = Vector2(175 * 64, 18 * 64 - 4)
	await _frames(20)
	patch._start_slam()
	await _frames(60)
	_check(not is_instance_valid(tunnel_ice) or tunnel_ice.get_node("CollisionShape2D").disabled, "a slam clears the ice out of the tunnel")
	_check(level.get_node("page_exit_228_21").target_page == R4 + "4_2_the_fold_works.tscn", "the Rime Slopes lead on to the Fold Works")

	# The Fold Works: a needle stabs where Patch stands, sticks, and three cuts snap it.
	await scene_manager.change_page(R4 + "4_2_the_fold_works.tscn", &"Start")
	await _wait_for_scene("TheFoldWorks", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	patch = get_first_node_in_group("player") as CharacterBody2D
	var needle := level.get_node("clockwork_needle_46_17")  # (states: 3 stuck, 5 snapped)
	needle.speed = 0.0
	patch.global_position = Vector2(needle.global_position.x + needle.carriage.position.x, 26 * 64 - 4)
	patch.velocity = Vector2.ZERO
	await _frames(10)
	patch.health.clear_invulnerability()
	var hp: int = game_state.health
	for i in 180:
		if needle.state == 3:
			break
		await physics_frame
	await _frames(4)
	_check(needle.state == 3 and game_state.health < hp, "the needle stops over Patch, shakes, and stabs him (%d -> %d)" % [hp, game_state.health])
	patch.health.grant_invulnerability(900.0)
	var shears := Hitbox.new()
	shears.damage = 1
	current_scene.add_child(shears)
	shears.global_position = needle.pin.global_position + Vector2(0, 150)
	for i in 3:
		needle._on_hit(shears)
		await _frames(14)
	shears.queue_free()
	_check(needle.state == 5 and int(game_state.bestiary.get("clockwork_needle", 0)) >= 1,
		"three cuts to the stuck pin snap it, and Nell's book gets a page")
	# The Frog Fold: from Bindwell's bench; a folded-down jump goes far higher.
	game_state.abilities.erase(&"frog_fold")
	patch.global_position = (level.get_node("ability_page_160_17") as Node2D).global_position
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(game_state.has_ability(&"frog_fold"), "Bindwell's frog pattern teaches the Frog Fold")
	var heights := []
	for frog in [false, true]:
		patch.global_position = Vector2(165 * 64, 18 * 64 - 4)
		patch.velocity = Vector2.ZERO
		await _frames(20)
		var floor_y := patch.global_position.y
		if frog:
			Input.action_press(&"move_down")
			await _frames(30)
		Input.action_press(&"jump")
		var top := floor_y
		for i in 70:
			await physics_frame
			top = minf(top, patch.global_position.y)
		Input.action_release(&"jump")
		Input.action_release(&"move_down")
		heights.append(floor_y - top)
	_check(heights[0] > 150.0 and heights[0] < 230.0 and heights[1] > 290.0, "a plain jump rises %.0f px, a Frog Fold jump %.0f" % heights)
	_check(level.get_node("page_exit_236_9").target_page == R4 + "4_3_the_pattern_room.tscn", "the Fold Works lead on to the Pattern Room")

	# The Pattern Room: four linked folds; the solution raises them all into a stair.
	await scene_manager.change_page(R4 + "4_3_the_pattern_room.tscn", &"Start")
	await _wait_for_scene("ThePatternRoom", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	var folds := {}
	for c in ["P", "T", "U", "W"]:
		for node in get_nodes_in_group(&"fold_marks"):
			if current_scene.is_ancestor_of(node) and node.tag == c:
				folds[c] = node
	_check(folds.size() == 4 and folds["P"].is_up and not folds["T"].is_up and not folds["U"].is_up and folds["W"].is_up,
		"the pattern room starts with the shortest and tallest folds standing")
	for c in ["P", "T", "U", "W"]:
		var f: Node2D = folds[c]
		f.on_slam(f.global_position + Vector2(-94, 0), 0)
		await _frames(45)
	_check(folds.values().all(func(f: Node) -> bool: return f.is_up), "slamming P, T, U, then W stands every fold up")
	folds["P"].on_slam(folds["P"].global_position + Vector2(-94, 0), 0)
	await _frames(45)
	_check(not folds["P"].is_up and not folds["T"].is_up and folds["U"].is_up, "a slam flips only its own fold and its neighbours")
	_check(level.get_node("page_exit_37_2").target_page == R4 + "4_4_the_stitched_ascent.tscn", "the Pattern Room climbs on to the Stitched Ascent")
	game_state.max_health = 99
	game_state.health = 99
	await _spine_peaks_part_two(game_state, scene_manager, dialogue)


## The Spine Peaks part 2: the Stitched Ascent, Old Bindwell's duel in his workshop
## (red stabs to dodge, the white one to parry, his thread snare, the floor sewn shut),
## Bindwell come down to the hub, the cold store behind his sewn door, and the low point
## by the fire, which opens the way to the Sogg.
func _spine_peaks_part_two(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R4 := "res://scenes/levels/peaks/"
	var book_map := load("res://scripts/world/book_map.gd")
	_check(book_map.region(&"peaks").get("mended_flag") == "boss_bindwell_defeated", "beating Bindwell mends the Peaks")
	await scene_manager.change_page(R4 + "4_4_the_stitched_ascent.tscn", &"Start")
	await _wait_for_scene("TheStitchedAscent", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var level := current_scene.get_node("Level")
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	var door := level.get_node("page_door_126_13")
	_check(door.target_page == R4 + "cold_store.tscn" and not door.is_open(), "the cold store is sewn shut until Bindwell is beaten")
	_check(level.get_node("page_exit_146_9").target_page == R4 + "bindwell_workshop.tscn", "the ascent ends at Bindwell's workshop")
	_check(level.get_node("page_exit_1_51").target_page == R4 + "4_3_the_pattern_room.tscn", "the way back down goes to the Pattern Room")
	var needles := current_scene.find_children("*", "Node2D", true, false).filter(func(n: Node) -> bool:
		return n.get_script() != null and n.get_script().resource_path.ends_with("clockwork_needle.gd"))
	_check(needles.size() == 2, "two needles still run over the ascent (%d)" % needles.size())

	# Old Bindwell.
	await scene_manager.change_page(R4 + "bindwell_workshop.tscn", &"Start")
	await _wait_for_scene("BindwellsWorkshop", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player") as CharacterBody2D
	var boss := current_scene.get_node("Bindwell")
	var exit_door := current_scene.get_node("ExitDoor")
	_check(not exit_door.visible, "no way on past the workshop while Bindwell stands")
	boss.start_fight()
	_check(boss.state == 1, "Bindwell's duel starts")
	patch.health.grant_invulnerability(900.0)
	var hp: int = boss.health.current
	var cut := Hitbox.new()
	cut.damage = 1
	cut.collision_layer = 0
	cut.collision_mask = 0
	current_scene.add_child(cut)
	cut.global_position = boss.global_position + Vector2(-60, -200)
	boss._on_hit(cut)
	_check(boss.health.current == hp, "a cut while he's guarded only glances off his steel")
	# A stitch: the first stabs glow red and can't be guarded; the third can be parried.
	patch.global_position = Vector2(900, 896 - 50)
	patch.velocity = Vector2.ZERO
	boss.global_position.x = 1300.0
	boss._combo()
	_check(boss.point.unblockable, "his first stab can't be guarded")
	for i in 240:
		if boss.stab_index == 3:
			break
		await physics_frame
	_check(boss.stab_index == 3 and not boss.point.unblockable, "his third stab can be parried")
	patch.facing = Vector2.RIGHT if boss.global_position.x > patch.global_position.x else Vector2.LEFT
	patch._guard_time = 0.0
	_check(patch._guard_hit(boss.point) and boss.state == 5, "a parry on the third stab knocks him off balance")
	boss._on_hit(cut)
	_check(boss.health.current < hp, "and opens him to the shears (%d of %d)" % [boss.health.current, boss.health.max_health])
	_check(boss.can_stagger(), "off balance, his Hold can be broken for the Unstitch")
	for i in 400:
		if boss.state == 1:
			break
		await physics_frame
	_check(boss.state == 1, "he recovers and comes on again")
	# An unparried third stab sticks in the boards: a shorter opening.
	boss.stab_index = 2
	boss._next_stab()
	for i in 120:
		if boss.state == 4:
			break
		await physics_frame
	_check(boss.state == 4, "a third stab not parried sticks in the boards")
	for i in 200:
		if boss.state == 1:
			break
		await physics_frame
	# The thread snare (from two thirds health): caught, Patch is reeled in.
	boss.health.current = 9
	_check(boss.phase() == 1, "at two thirds he fights in his second phase")
	patch.global_position = Vector2(boss.global_position.x - 400.0, 896 - 50)
	patch.velocity = Vector2.ZERO
	boss._snare()
	var reeled := false
	for i in 90:
		if boss.snared > 0.0:
			reeled = true
			break
		await physics_frame
	_check(reeled, "his thread catches Patch on the ground and reels him in")
	for i in 300:
		if boss.state == 1:
			break
		await physics_frame
	# The last third: he sews the floor shut from the ends.
	boss.health.current = 4
	_check(boss.phase() == 2, "at a third he starts sewing the floor shut")
	var left: float = boss._floor_left()
	boss._sew()
	for i in 90:
		await physics_frame
	var seams := get_nodes_in_group(&"bindwell_seams")
	_check(seams.size() == 1 and (seams[0].get_child(1) as Hitbox).active and boss._floor_left() > left, "a sewn seam cuts the floor down from the end")
	# Down.
	boss.health.current = 1
	boss.health.clear_invulnerability()
	boss.health.take_damage(5, boss.global_position)
	for i in 400:
		if dialogue.is_active():
			break
		await physics_frame
	await _skip_dialogue(dialogue)
	await _frames(20)
	_check(game_state.get_flag("boss_bindwell_defeated") and exit_door.visible, "Bindwell yields, and the way on opens")
	_check(game_state.bestiary.get("bindwell", 0) >= 1, "Nell's book gets a page for Bindwell")
	_check(exit_door.target_page == R4 + "4_5_the_low_point.tscn", "the workshop opens onto the Low Point")

	# Bindwell comes down to the Spine.
	await scene_manager.change_page("res://scenes/levels/hub/spine_hub.tscn", &"Start")
	await _wait_for_scene("SpineHub", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var friend := current_scene.get_node_or_null("Bindwell")
	_check(friend != null and friend.dialogue_id == "bindwell_hub", "Bindwell has come down to the Spine")
	friend.interact(null)
	_check(dialogue.is_active(), "and he'll talk")
	await _skip_dialogue(dialogue)

	# The cold store, unsealed.
	await scene_manager.change_page(R4 + "4_4_the_stitched_ascent.tscn", &"FromColdStore")
	await _wait_for_scene("TheStitchedAscent", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(current_scene.get_node("Level/page_door_126_13").is_open(), "with Bindwell beaten, his sewn door opens")
	await scene_manager.change_page(R4 + "cold_store.tscn", &"Start")
	await _wait_for_scene("TheColdStore", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	var hearts_before: int = game_state.max_health
	var scraps_before: int = game_state.scraps
	patch.global_position = (level.get_node("heart_patch_48_2") as Node2D).global_position
	await _frames(10)
	patch.global_position = (level.get_node("scrap_52_2") as Node2D).global_position
	await _frames(10)
	await _skip_dialogue(dialogue)
	_check(game_state.max_health == hearts_before + 2 and game_state.scraps >= scraps_before + 60, "the cold store: a heart patch and 60 Scraps")
	game_state.max_health = 99
	game_state.health = 99

	# The low point, by the fire.
	await scene_manager.change_page(R4 + "4_5_the_low_point.tscn", &"Start")
	await _wait_for_scene("TheLowPoint", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	var summit := level.get_node("page_exit_134_17")
	_check(summit.target_page == "res://scenes/levels/interludes/interlude_03.tscn" and summit.requires_flag == "patch_told_truth", "the Low Point climbs on toward the Gutter (by way of Gran's table), once Patch has told the truth")
	_check(not game_state.get_flag("patch_told_truth"), "Patch hasn't said it yet")
	patch.global_position = (level.get_node("story_trigger_97_17") as Node2D).global_position + Vector2(0, -40)
	patch.velocity = Vector2.ZERO
	await _frames(10)
	_check(dialogue.is_active(), "by the fire, the low point plays")
	await _skip_dialogue(dialogue, 80)
	_check(game_state.get_flag("patch_told_truth"), "Patch tells them what he did to Drizzle")
	await _gatefold_fair(game_state, scene_manager, dialogue)


## Gatefold Fair part 1: the Midway (the carousel horse, the Paper Plane Glide and the
## vents), the Big Wheel (riding a gondola) and the Gatefold (the vent flap puzzle).
func _gatefold_fair(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R5 := "res://scenes/levels/fair/"
	var book_map := load("res://scripts/world/book_map.gd")
	var fair: Dictionary = book_map.region(&"fair")
	_check(fair.get("door") == R5 + "5_1_the_midway.tscn" and fair.get("open_flag") == "boss_bindwell_defeated", "Bindwell beaten, the Fair's door opens on the Midway")
	await scene_manager.change_page(R5 + "5_1_the_midway.tscn", &"Start")
	await _wait_for_scene("TheMidway", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var level := current_scene.get_node("Level")
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	# The carousel horse: rears, charges; a parry topples it.
	var horse := level.get_node("carousel_horse_52_21")
	_check(horse.get_script().resource_path.ends_with("carousel_horse.gd"), "a carousel horse paces the Midway")
	horse._rear()
	_check(horse.state == 1, "it rears before it charges")
	horse.on_parried(patch)
	await _frames(5)
	_check(horse.state == 3, "a parried charge topples it onto its side")
	horse.queue_free()
	# The Paper Plane Glide.
	_check(not game_state.has_ability(&"paper_plane"), "Patch can't glide yet")
	patch.global_position = (level.get_node("ability_page_70_18") as Node2D).global_position
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(game_state.has_ability(&"paper_plane"), "Gran's paper plane teaches the glide")
	var speeds := []
	for glide in [false, true]:
		patch.global_position = Vector2(84 * 64, 8 * 64)
		patch.velocity = Vector2.ZERO
		if glide:
			Input.action_press(&"jump")
		await _frames(40)
		speeds.append(patch.velocity.y)
		_check(patch.gliding == glide, "holding jump in the air glides (%s)" % glide)
		Input.action_release(&"jump")
		await _frames(2)
	_check(speeds[0] > 600.0 and speeds[1] <= 160.0, "a glide falls slowly (%.0f px/s, %.0f falling)" % [speeds[1], speeds[0]])
	# A vent lifts a glider.
	var vent := level.get_node("Updraft_101_9")
	_check(vent.size.y == 13 * 64.0, "a column of vent cells is one updraft")
	# (back on the boards first, so the glide test's fall into the dark is over)
	patch.global_position = Vector2(97 * 64, 22 * 64 - 48)
	patch.velocity = Vector2.ZERO
	await _frames(30)
	patch.global_position = vent.global_position + Vector2(0, -200)
	patch.velocity = Vector2.ZERO
	Input.action_press(&"jump")
	await _frames(4)
	var y0: float = patch.global_position.y
	await _frames(30)
	Input.action_release(&"jump")
	_check(patch.global_position.y < y0 - 80.0, "a vent lifts the paper plane (rose %.0f px)" % (y0 - patch.global_position.y))
	_check(level.get_node("page_exit_218_15").target_page == R5 + "5_2_the_big_wheel.tscn", "the Midway leads to the Big Wheel")

	# The Big Wheel: the gondolas carry Patch round.
	await scene_manager.change_page(R5 + "5_2_the_big_wheel.tscn", &"Start")
	await _wait_for_scene("TheBigWheel", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	var wheel := level.get_node("ferris_wheel_30_29")
	_check(wheel.gondolas.size() == 8, "the Big Wheel hangs eight gondolas")
	var low: Node2D = wheel.gondolas[0]
	for g in wheel.gondolas:
		if g.global_position.y > low.global_position.y:
			low = g
	var floor_y := 30 * 64.0
	_check(low.global_position.y < floor_y - 40.0, "its lowest bench clears the boards (%.0f px up)" % (floor_y - low.global_position.y))
	patch.global_position = low.global_position + Vector2(0, -60)
	patch.velocity = Vector2.ZERO
	await _frames(20)
	var ride_y: float = patch.global_position.y
	var on_seat: bool = patch.is_on_floor()
	await _frames(90)
	_check(on_seat and patch.is_on_floor() and absf(patch.global_position.y - ride_y) > 20.0, "Patch rides a gondola round (moved %.0f px)" % (ride_y - patch.global_position.y))
	_check(level.get_node("page_exit_80_29").target_page == R5 + "5_3_the_gatefold.tscn", "the wheel's far side leads to the Gatefold")

	# The Gatefold: three tabs flip the vent flaps; 1, 2, 3, 1, 2 opens all three.
	await scene_manager.change_page(R5 + "5_3_the_gatefold.tscn", &"Start")
	await _wait_for_scene("TheGatefold", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	var vents := [level.get_node("updraft_9_21"), level.get_node("updraft_16_13"), level.get_node("updraft_27_8")]
	_check(not vents[0].open and vents[1].open and vents[2].open, "the Gatefold starts with the high vents open and the floor's shut")
	var tabs := {"1": level.get_node("pull_tab_4_21"), "2": level.get_node("pull_tab_13_13"), "3": level.get_node("pull_tab_24_8")}
	for t in ["1", "2", "3", "1", "2"]:
		tabs[t].interact(null)
		await _frames(70)
	_check(vents.all(func(v: Node) -> bool: return v.open), "pulling 1, 2, 3, 1, 2 opens every vent")
	tabs["3"].interact(null)
	await _frames(70)
	_check(not vents[0].open and vents[1].open, "a tab flips only its own flaps")
	_check(level.get_node("page_exit_38_3").target_page == R5 + "5_4_the_ghost_train.tscn", "the top of the Gatefold leads on to the Ghost Train")
	await _gatefold_fair_two(game_state, scene_manager, dialogue)


## Gatefold Fair, part 2: the Ghost Train (cars that run on their own, ghouls that
## spring up across the rail), the Rigging up the big top, the Barker, and Lost
## Property behind the door he kept shut.
func _gatefold_fair_two(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R5 := "res://scenes/levels/fair/"
	await scene_manager.change_page(R5 + "5_4_the_ghost_train.tscn", &"Start")
	await _wait_for_scene("TheGhostTrain", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var level := current_scene.get_node("Level")
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	var train := level.get_node("GhostTrain_45_22")
	var high := level.get_node("GhostTrain_114_18")
	_check(train.length == 51 * 64.0 and high.length == 57 * 64.0, "each run of rail is one ghost train")
	_check(train.state == 0, "its car waits at the platform")
	var door := level.get_node("page_door_106_19")
	_check(not door.is_open() and door.target_page == R5 + "lost_property.tscn", "Lost Property is shut while the Barker stands")
	# Climb in: the car sets off on its own and carries him.
	for g in get_nodes_in_group(&"pop_ghouls"):
		g.set_physics_process(false)
	var cart: Node2D = train.cart
	patch.global_position = cart.global_position + Vector2(0, -90)
	patch.velocity = Vector2.ZERO
	await _frames(40)
	_check(train.state == 1, "with Patch aboard, the car sets off")
	var x0: float = patch.global_position.x
	await _frames(60)
	_check(patch.global_position.x > x0 + 300.0 and absf(patch.global_position.x - cart.global_position.x) < 100.0, "it carries him along the rail (%.0f px)" % (patch.global_position.x - x0))
	# A jump off a moving car comes down in it again.
	Input.action_press(&"jump")
	await _frames(6)
	Input.action_release(&"jump")
	var airborne: bool = not patch.is_on_floor()
	for i in 90:
		if patch.is_on_floor():
			break
		await physics_frame
	_check(airborne and patch.is_on_floor() and absf(patch.global_position.x - cart.global_position.x) < 100.0, "he jumps in the car and lands back in it (%.0f px off)" % (patch.global_position.x - cart.global_position.x))
	for i in 600:
		if train.state == 2:
			break
		await physics_frame
	_check(train.state == 2, "it stops hard at the buffers")
	patch.global_position = Vector2(100 * 64, 20 * 64 - 48)
	patch.velocity = Vector2.ZERO
	for i in 400:
		if train.state == 0:
			break
		await physics_frame
	_check(train.state == 0 and absf(cart.position.x - train.start_x()) < 1.0, "left empty, it rolls back for another rider")
	# A ghoul springs up across the rail when something comes along it.
	var ghoul := level.get_node("pop_ghoul_60_21")
	_check(ghoul.get_script().resource_path.ends_with("pop_ghoul.gd"), "ghouls wait under the rail")
	ghoul.set_physics_process(true)
	patch.global_position = ghoul.global_position + Vector2(-260, -10)
	patch.velocity = Vector2.ZERO
	var told := false
	for i in 60:
		told = told or ghoul.state == 1
		if ghoul.state == 2:
			break
		await physics_frame
	_check(told and ghoul.state == 2 and ghoul.hitbox.active and ghoul.hitbox.unblockable, "it rattles, then springs up across the rail: jump it")
	_check(level.get_node("page_exit_214_21").target_page == R5 + "5_5_the_rigging.tscn", "the end of the line leads to the big top")
	patch.global_position = Vector2(100 * 64, 20 * 64 - 48)
	await _frames(10)

	# The Rigging.
	await scene_manager.change_page(R5 + "5_5_the_rigging.tscn", &"Start")
	await _wait_for_scene("TheRigging", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	_check(level.get_node("Updraft_62_10").size.y == 30 * 64.0, "the generator's exhaust rises up the side of the tent")
	_check(level.get_node("page_exit_78_10").target_page == R5 + "the_big_top.tscn", "the hole at the top drops into the big top")

	# The Barker.
	await scene_manager.change_page(R5 + "the_big_top.tscn", &"FromRigging")
	await _wait_for_scene("TheBigTop", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	var boss := current_scene.get_node("Barker")
	var exit_door := current_scene.get_node("ExitDoor")
	_check(not exit_door.visible, "no way out of the ring while the Barker is talking")
	boss.start_fight()
	_check(boss.state == 1, "the Barker's show begins")
	await _skip_dialogue(dialogue)
	var hp: int = boss.health.current
	var cut := Hitbox.new()
	cut.damage = 1
	cut.collision_layer = 0
	cut.collision_mask = 0
	current_scene.add_child(cut)
	boss._on_hit(cut)
	_check(boss.health.current == hp, "a cut while he's performing glances off")
	# The Knife-Thrower: red, red, white; the white card parried cuts him open.
	patch.global_position = Vector2(boss.global_position.x - 520.0, 896 - 50)
	patch.velocity = Vector2.ZERO
	boss._announce()
	_check(boss.act == 0 and boss.announced == boss.act and boss.sign_label.text == "THE KNIFE-THROWER!", "in his first half the sign tells the truth")
	var white: Node = null
	var reds := 0
	for i in 200:
		for card in get_nodes_in_group(&"barker_cards"):
			if card.parryable:
				white = card
			elif card.hitbox.unblockable:
				reds = maxi(reds, 1)
		if white:
			break
		await physics_frame
	_check(reds > 0 and white != null, "he throws red cards, then a white one")
	white.on_parried(patch)
	for i in 120:
		if boss.state == 7:
			break
		await physics_frame
	_check(boss.state == 7 and boss.can_stagger(), "the parried white card spins back and cuts him open")
	await _skip_dialogue(dialogue)
	boss._on_hit(cut)
	_check(boss.health.current < hp, "open, he can be cut (%d of %d)" % [boss.health.current, boss.health.max_health])
	for i in 400:
		if boss.state == 1:
			break
		await physics_frame
	_check(boss.state == 1, "he gathers himself and goes on with the show")
	# The Stampede and the Voice.
	boss._stampede()
	await _frames(10)
	_check(get_nodes_in_group(&"barker_horses").size() >= 1 and boss.state == 4, "horses gallop out of the wings")
	await _skip_dialogue(dialogue)
	for i in 400:
		if boss.state == 1:
			break
		await physics_frame
	boss._voice()
	await _frames(30)
	_check(get_nodes_in_group(&"barker_waves").size() == 2, "his shout runs along the floor both ways")
	_check(boss.state == 6 and boss.is_open(), "then he's out of breath, bent double, open")
	await _skip_dialogue(dialogue)
	for i in 400:
		if boss.state == 1:
			break
		await physics_frame
	# From half health, the sign lies.
	boss.health.current = 7
	_check(boss.phase() == 1, "at half health he starts lying")
	boss._announce()
	_check(boss.lies_told == 1 and boss.announced != boss.act, "his first act after that is announced as something else")
	await _skip_dialogue(dialogue)
	# Down.
	boss.health.current = 1
	boss.health.clear_invulnerability()
	boss.health.take_damage(5, boss.global_position)
	for i in 400:
		if dialogue.is_active():
			break
		await physics_frame
	await _skip_dialogue(dialogue)
	await _frames(20)
	_check(game_state.get_flag("boss_barker_defeated") and exit_door.visible, "the Barker says it was raining, and the lights go out")
	_check(game_state.bestiary.get("barker", 0) >= 1, "Nell's book gets a page for the Barker")
	_check(get_nodes_in_group(&"barker_cards").is_empty() and get_nodes_in_group(&"barker_horses").is_empty(), "his acts end with him")
	var book_map := load("res://scripts/world/book_map.gd")
	_check(book_map.region(&"fair").get("mended_flag") == "boss_barker_defeated", "beating the Barker mends the Fair")

	# Lost Property opens.
	await scene_manager.change_page(R5 + "5_4_the_ghost_train.tscn", &"FromLostProperty")
	await _wait_for_scene("TheGhostTrain", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(current_scene.get_node("Level/page_door_106_19").is_open(), "with the show over, Lost Property opens")
	await scene_manager.change_page(R5 + "lost_property.tscn", &"Start")
	await _wait_for_scene("LostProperty", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player") as CharacterBody2D
	var hearts_before: int = game_state.max_health
	patch.global_position = (current_scene.get_node("Level/heart_patch_52_10") as Node2D).global_position
	await _frames(10)
	_check(game_state.max_health == hearts_before + 2, "Lost Property kept a heart for whoever came back")
	await _skip_dialogue(dialogue)
	game_state.max_health = 99
	game_state.health = 99
	await _the_index(game_state, scene_manager, dialogue)


## Presses an action for a couple of frames, as a player would.
func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


## Puts Patch on the floor at `at` (the top of the ground he'll stand on) and lets him land.
func _stand(patch: CharacterBody2D, at: Vector2) -> void:
	patch.global_position = at + Vector2(0, -60)
	patch.velocity = Vector2.ZERO
	await _frames(12)


## The Index part 1: Bookmark Warp (Gran's ribbon), silverfish, spring shutters (6-1),
## the drawers of the card catalogue (6-2), the Reading Room's shutter puzzle (6-3),
## and the way down to the Gutter, shut until the whole book is mended.
func _the_index(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R6 := "res://scenes/levels/index/"
	var book_map := load("res://scripts/world/book_map.gd")
	var index: Dictionary = book_map.region(&"index")
	_check(index.get("door") == R6 + "6_1_the_back_pages.tscn" and index.get("open_flag") == "boss_barker_defeated", "the Barker beaten, the Index's door opens on the Back Pages")
	await scene_manager.change_page(R6 + "6_1_the_back_pages.tscn", &"Start")
	await _wait_for_scene("TheBackPages", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var level := current_scene.get_node("Level")
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	for fish in get_nodes_in_group(&"enemies"):
		fish.queue_free()
	await _frames(2)
	# Gran's ribbon.
	_check(not game_state.has_ability(&"bookmark_warp"), "Patch can't warp yet")
	await _tap(&"warp")
	_check(patch.ribbon == null, "without the ribbon, the warp button does nothing")
	patch.global_position = (level.get_node("ability_page_50_17") as Node2D).global_position
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(game_state.has_ability(&"bookmark_warp"), "Gran's ribbon in her unfinished book teaches the Bookmark Warp")
	# Lay it, walk away, tear back.
	await _stand(patch, Vector2(30 * 64, 20 * 64))
	var laid_at := patch.global_position
	await _tap(&"warp")
	_check(patch.ribbon != null and patch.ribbon.global_position.distance_to(laid_at) < 4.0, "the warp button lays the ribbon where Patch stands")
	Input.action_press(&"move_left")
	await _frames(50)
	Input.action_release(&"move_left")
	await _frames(4)
	_check(patch.global_position.distance_to(laid_at) > 300.0, "Patch walks away from it (%.0f px)" % patch.global_position.distance_to(laid_at))
	await _tap(&"warp")
	_check(patch.global_position.distance_to(laid_at) < 6.0 and patch.ribbon == null, "the warp button again tears him straight back to it, and he picks it up")
	# In the air he can't lay it.
	patch.global_position = Vector2(30 * 64, 14 * 64)
	patch.velocity = Vector2.ZERO
	await _frames(2)
	patch._warp_cooldown = 0.0
	_check(not patch.bookmark_warp() and patch.ribbon == null, "the ribbon can only be laid on the ground")
	await _frames(40)
	# Nowhere to stand: if something solid is where the ribbon is, it stays put.
	await _stand(patch, Vector2(30 * 64, 20 * 64))
	patch._warp_cooldown = 0.0
	patch.bookmark_warp()
	var ribbon: Node2D = patch.ribbon
	ribbon.global_position = Vector2(90 * 64, 8 * 64)  # inside the cabinet over the passage
	var before := patch.global_position
	patch._warp_cooldown = 0.0
	_check(not patch.bookmark_warp() and patch.global_position == before and is_instance_valid(ribbon), "with no room where the ribbon is, the warp fails and the ribbon stays")
	ribbon.queue_free()
	patch.ribbon = null
	# The spring shutter: too quick to run back to, not too quick for the ribbon.
	var shutter_p := level.get_node("shutter_78_19")
	var tab_t := level.get_node("pull_tab_64_7")
	_check(not shutter_p.open and not shutter_p._shape.disabled, "the first shutter is down and solid")
	var tab_top := (tab_t as Node2D).global_position
	await _stand(patch, tab_top)
	tab_t.interact(patch)
	Input.action_press(&"move_right")
	await _frames(240)
	Input.action_release(&"move_right")
	_check(patch.global_position.x < (shutter_p as Node2D).global_position.x, "running from the tab, the shutter drops before Patch gets to it")
	_check(not shutter_p.open, "the spring shuts it again (%.1f s)" % shutter_p.open_time)
	await _stand(patch, Vector2(76 * 64, 20 * 64))
	var by_door := patch.global_position
	patch._warp_cooldown = 0.0
	await _tap(&"warp")
	await _stand(patch, tab_top)
	tab_t.interact(patch)
	for i in 60:
		if shutter_p.open and shutter_p._shape.disabled:
			break
		await physics_frame
	await _tap(&"warp")
	_check(patch.global_position.distance_to(by_door) < 6.0, "with the ribbon by the door, pull, and warp back to it")
	Input.action_press(&"move_right")
	await _frames(40)
	Input.action_release(&"move_right")
	_check(patch.global_position.x > (shutter_p as Node2D).global_position.x + 64.0, "and through before it drops")
	await _frames(120)
	_check(not shutter_p.open, "behind him, it drops shut")
	# Silverfish: under the floor, a bulge, the bite; and they eat ribbons.
	var fish_scene := load("res://scenes/enemies/silverfish.tscn") as PackedScene
	var fish := fish_scene.instantiate() as CharacterBody2D
	fish.position = Vector2(134 * 64, 20 * 64)
	level.add_child(fish)
	await _frames(10)
	_check(fish.get_script().resource_path.ends_with("silverfish.gd"), "a silverfish in the stacks")
	fish._go_under(fish.global_position.x + 300.0)
	await _frames(30)
	_check(fish.state == 2 and not fish.hurtbox.monitoring, "it goes under the page, where it can't be cut")
	for i in 240:
		if fish.state == 3:
			break
		await physics_frame
	_check(fish.state == 3, "the ripple stops and the floor bulges (the tell)")
	for i in 60:
		if fish.state == 4:
			break
		await physics_frame
	_check(fish.state == 4 and fish._bite.active and fish._bite.unblockable, "it bursts up biting, and the bite can't be guarded")
	for i in 60:
		if fish.state == 5:
			break
		await physics_frame
	_check(fish.state == 5 and fish.hurtbox.monitoring, "out of the floor it's open")
	fish.state = 5
	await _stand(patch, Vector2(134 * 64 - 260.0, 20 * 64))
	patch._warp_cooldown = 0.0
	patch.bookmark_warp()
	ribbon = patch.ribbon
	_check(ribbon != null, "a ribbon laid near a silverfish...")
	await _stand(patch, Vector2(fish.global_position.x - 900.0, 20 * 64))
	for i in 240:
		if not is_instance_valid(ribbon) or ribbon.is_queued_for_deletion():
			break
		await physics_frame
	_check(not is_instance_valid(ribbon) or ribbon.is_queued_for_deletion(), "...gets eaten")
	patch._warp_cooldown = 0.0
	patch.bookmark_warp()
	_check(patch.ribbon != null and patch.ribbon.global_position.distance_to(patch.global_position) < 4.0, "with that ribbon eaten, the next press lays a new one")
	patch.ribbon.queue_free()
	patch.ribbon = null
	fish.queue_free()
	_check(level.get_node("page_exit_190_19").target_page == R6 + "6_2_the_card_catalogue.tscn", "the Back Pages lead on to the Card Catalogue")

	# 6-2: drawers in and out on their clock; a ribbon laid on one rides with it.
	await scene_manager.change_page(R6 + "6_2_the_card_catalogue.tscn", &"Start")
	await _wait_for_scene("TheCardCatalogue", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.queue_free()
	var drawer := level.get_node("index_drawer_13_40")
	var xs := []
	for i in 300:
		xs.append(drawer.drawer.position.x)
		await physics_frame
	_check(xs.max() - xs.min() > 150.0, "a drawer slides out of the cabinet and back in (%.0f px)" % (xs.max() - xs.min()))
	for i in 400:
		if drawer.is_out():
			break
		await physics_frame
	await _stand(patch, (drawer.drawer as Node2D).global_position + Vector2(40, 0))
	_check(patch.is_on_floor() and patch.get_last_slide_collision() != null, "Patch stands on a drawer that's out")
	patch._warp_cooldown = 0.0
	patch.bookmark_warp()
	_check(patch.ribbon != null and patch.ribbon.get_parent() == drawer.drawer, "a ribbon laid on a drawer rides it")
	patch.ribbon.queue_free()
	patch.ribbon = null
	# The shaft: lay the ribbon by the shutter, drop to the tab, pull, warp, through.
	var shutter := level.get_node("shutter_26_7")
	await _stand(patch, Vector2(24 * 64 + 32, 8 * 64))
	by_door = patch.global_position
	patch._warp_cooldown = 0.0
	await _tap(&"warp")
	var tab := level.get_node("pull_tab_4_21")
	await _stand(patch, (tab as Node2D).global_position)
	tab.interact(patch)
	for i in 60:
		if shutter.open and shutter._shape.disabled:
			break
		await physics_frame
	await _tap(&"warp")
	Input.action_press(&"move_right")
	await _frames(40)
	Input.action_release(&"move_right")
	_check(patch.global_position.x > (shutter as Node2D).global_position.x + 64.0, "the shaft's tab, the ribbon by the door, and through")
	_check(level.get_node("page_exit_34_7").target_page == R6 + "6_3_the_reading_room.tscn", "the top of the catalogue leads to the Reading Room")

	# 6-3: every tab but the desk's shuts Patch in, and the ribbon gets him out. The
	# order tools/levels/build_index.py proves shortest: W, lay, U, warp, W, lay, T, warp.
	await scene_manager.change_page(R6 + "6_3_the_reading_room.tscn", &"Start")
	await _wait_for_scene("TheReadingRoom", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	var doors := {}
	for d in ["A", "B", "C"]:
		for node in get_nodes_in_group(&"shutters"):
			if node.tag == d:
				doors[d] = node
	var tabs := {"T": level.get_node("pull_tab_4_19"), "W": level.get_node("pull_tab_18_19"), "U": level.get_node("pull_tab_30_19")}
	_check(not doors["A"].open and not doors["B"].open and not doors["C"].open, "the Reading Room's shutters all start down")
	var hall := Vector2(14 * 64, 20 * 64)
	var steps := [["pull", "W"], ["lay"], ["walk", "U"], ["pull", "U"], ["warp"], ["pull", "W"], ["lay"], ["walk", "T"], ["pull", "T"], ["warp"]]
	var trapped := false
	for n in steps.size():
		var step: Array = steps[n]
		match step[0]:
			"pull":
				var t: Node2D = tabs[step[1]]
				if patch.global_position.distance_to(t.global_position) > 80.0:
					# Walk there: the tab must be reachable through the open shutters.
					var dir := signf(t.global_position.x - patch.global_position.x)
					Input.action_press(&"move_right" if dir > 0 else &"move_left")
					for i in 400:
						if absf(patch.global_position.x - t.global_position.x) < 40.0:
							break
						await physics_frame
					Input.action_release(&"move_right")
					Input.action_release(&"move_left")
				_check(absf(patch.global_position.x - t.global_position.x) < 60.0, "Patch gets to tab %s" % step[1])
				t.interact(patch)
				await _frames(50)
			"walk":
				pass
			"lay":
				await _stand(patch, hall)
				patch._warp_cooldown = 0.0
				await _tap(&"warp")
			"warp":
				if n == 4:
					trapped = not doors["C"].open and not doors["B"].open
				patch._warp_cooldown = 0.0
				await _tap(&"warp")
				await _frames(10)
	_check(trapped, "pulling U shuts Patch in with the shutters either side down")
	_check(doors["B"].open and doors["C"].open, "four pulls and two warps: the middle and right shutters are up")
	Input.action_press(&"move_right")
	for i in 400:
		if patch.global_position.x > 37 * 64:
			break
		await physics_frame
	Input.action_release(&"move_right")
	_check(patch.global_position.x > 37 * 64, "Patch walks through into the stair of desks")
	_check(level.get_node("page_exit_48_7").target_page == R6 + "6_4_the_stacks.tscn", "the Reading Room's way on goes deeper, into the Stacks")
	await _the_index_two(game_state, scene_manager, dialogue)

	# The way down to the Gutter: shut until every region is mended.
	game_state.set_flag("patch_told_truth")
	var torn: Array = book_map.torn_regions()
	_check(torn.is_empty(), "with every boss beaten, no region is still torn (%s)" % [torn])
	game_state.set_flag("boss_barker_defeated", false)
	torn = book_map.torn_regions()
	_check(torn == ["Gatefold Fair"], "with the Barker standing, the Fair is still torn (%s)" % [torn])
	await scene_manager.change_page(book_map.HUB, &"Start")
	await _wait_for_scene("SpineHub", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var finale_door: Node = null
	var index_door: Node = null
	for node in current_scene.get_node("Level").get_children():
		if node.get_script() and node.get_script().resource_path.ends_with("finale_door.gd"):
			finale_door = node
		if node.get("region_id") == &"index":
			index_door = node
	_check(finale_door != null and not finale_door.is_open() and not finale_door.can_interact(), "the Spine's way down stays sewn shut while a region is torn")
	_check(index_door.state() == "locked", "the Index's door is shut while the Barker stands")
	game_state.set_flag("boss_barker_defeated")
	await _frames(3)
	_check(finale_door.is_open() and index_door.state() == "mended", "with the Barker beaten (and the rest), the Index is open and mended, and the way down opens")
	var low_point: Node = (load("res://scenes/levels/peaks/4_5_the_low_point.tscn") as PackedScene).instantiate()
	var summit_props: Dictionary = low_point.get_node("Level").entity_props["E"]
	low_point.free()
	_check(summit_props.get("requires_whole_book") == true and summit_props.get("fallback_page") == book_map.HUB, "the Low Point's summit only goes down to the Gutter once the whole book is mended")


## The Index part 2: the Stacks (6-4) and its book-lift shutter, the Gnawing that chases
## Patch down the Gnawed Pages (6-5), the Redactor on the last page, and the Errata.
func _the_index_two(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R6 := "res://scenes/levels/index/"
	var book_map := load("res://scripts/world/book_map.gd")
	_check(book_map.region(&"index").get("mended_flag") == "boss_redactor_defeated", "the Redactor's defeat mends the Index")
	_check("The Index" in book_map.torn_regions(), "until then the Index is torn")
	# 6-4 The Stacks.
	await scene_manager.change_page(R6 + "6_4_the_stacks.tscn", &"Start")
	await _wait_for_scene("TheStacks", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var level := current_scene.get_node("Level")
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	for e in get_nodes_in_group(&"enemies"):
		e.queue_free()
	await _frames(2)
	var errata_door := level.get_node("page_door_97_7")
	_check(not errata_door.is_open() and errata_door.target_page == R6 + "errata.tscn", "the Errata is sealed while the Redactor works")
	var drawers := get_nodes_in_group(&"index_drawers").filter(func(d: Node) -> bool: return d.get_parent() == level)
	_check(drawers.size() == 7, "a column of drawers up the face of the stack (%d)" % drawers.size())
	_check(level.get_node_or_null("InkPool") != null or not get_nodes_in_group(&"ink").is_empty() or level.get_children().any(func(n: Node) -> bool: return n.get_script() != null and n.get_script().resource_path.ends_with("ink_pool.gd")), "the low aisle is flooded with ink")
	var shutter_p := level.get_node("shutter_138_21")
	var tab_t := level.get_node("pull_tab_114_32")
	_check(shutter_p.open_time > 0.0 and not shutter_p.open, "a spring shutter over the way on")
	# The book lift: pull at the bottom, warp back to the ribbon by the door, and through.
	await _stand(patch, Vector2(136 * 64, 22 * 64))
	var by_door := patch.global_position
	patch._warp_cooldown = 0.0
	await _tap(&"warp")
	_check(patch.ribbon != null, "Gran's ribbon laid by the shutter")
	await _stand(patch, (tab_t as Node2D).global_position)
	tab_t.interact(patch)
	for i in 60:
		if shutter_p.open and shutter_p._shape.disabled:
			break
		await physics_frame
	patch._warp_cooldown = 0.0
	await _tap(&"warp")
	_check(patch.global_position.distance_to(by_door) < 6.0, "from the bottom of the lift shaft, straight back to the shutter")
	Input.action_press(&"move_right")
	await _frames(40)
	Input.action_release(&"move_right")
	_check(patch.global_position.x > (shutter_p as Node2D).global_position.x + 64.0, "and through it before it drops")
	_check(level.get_node("page_exit_198_21").target_page == R6 + "6_5_the_gnawed_pages.tscn", "the Stacks lead on to the Gnawed Pages")

	# 6-5 The Gnawed Pages: the Gnawing.
	await scene_manager.change_page(R6 + "6_5_the_gnawed_pages.tscn", &"Start")
	await _wait_for_scene("TheGnawedPages", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	level = current_scene.get_node("Level")
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	var gnaw := level.get_node("gnawing_18_19")
	_check(not gnaw.running, "the Gnawing waits for him to come in")
	await _stand(patch, Vector2(26 * 64, 20 * 64))
	await _skip_dialogue(dialogue)
	_check(gnaw.running, "once he's past it, it comes after him")
	var front_was: float = gnaw.front
	patch._warp_cooldown = 0.0
	patch.bookmark_warp()
	var ribbon: Node2D = patch.ribbon
	for i in 300:
		if patch.global_position.x > gnaw.front + 40.0 and gnaw.front > 28 * 64:
			break
		await physics_frame
	_check(gnaw.front > front_was + 300.0, "it comes on down the page (%.0f px)" % (gnaw.front - front_was))
	_check(patch.global_position.x > gnaw.front, "standing still, Patch is thrown on ahead of it, never left inside it")
	_check(not is_instance_valid(ribbon) or ribbon.is_queued_for_deletion(), "it eats a ribbon left behind")
	var fish := level.get_node_or_null("silverfish_52_19")
	_check(fish != null, "a silverfish in the way")
	# Wherever the fish has crawled to by now (it moves), the front goes past it.
	gnaw.front = maxf(54 * 64, fish.global_position.x + 200.0)
	await _frames(3)
	_check(not is_instance_valid(fish) or fish.is_queued_for_deletion(), "the Gnawing eats its own kind too")
	var shutter_q := level.get_node("shutter_192_19")
	var tab_q := level.get_node("pull_tab_186_19")
	await _stand(patch, (tab_q as Node2D).global_position)
	gnaw.front = 180 * 64
	tab_q.interact(patch)
	for i in 60:
		if shutter_q.open and shutter_q._shape.disabled:
			break
		await physics_frame
	_check(shutter_q.open, "the last shutter, pulled on the run")
	Input.action_press(&"move_right")
	await _frames(90)
	Input.action_release(&"move_right")
	_check(patch.global_position.x > (shutter_q as Node2D).global_position.x + 64.0, "Patch gets through under it")
	for i in 400:
		if gnaw.done:
			break
		await physics_frame
	_check(gnaw.done and not gnaw.running and gnaw.front <= 192 * 64, "the Gnawing stops at the shutter and falls back")
	_check(level.get_node("page_exit_229_19").target_page == R6 + "the_last_entry.tscn", "and on, to the last page")

	# The Redactor.
	await scene_manager.change_page(R6 + "the_last_entry.tscn", &"FromGnawedPages")
	await _wait_for_scene("TheLastEntry", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	var boss := current_scene.get_node("Redactor")
	var exit_door := current_scene.get_node("ExitDoor")
	_check(not exit_door.visible, "no way out while the Redactor works")
	boss.start_fight()
	_check(boss.state == 1, "the Redactor uncaps its pen")
	await _skip_dialogue(dialogue)
	var cut := Hitbox.new()
	cut.damage = 1
	cut.collision_layer = 0
	cut.collision_mask = 0
	current_scene.add_child(cut)
	var hp: int = boss.health.current
	boss._on_hit(cut)
	_check(boss.health.current == hp, "a cut while it's closed glances off")
	# Strike: the pen comes down a red line, and a ribbon in the line goes with it.
	await _stand(patch, Vector2(900, 896))
	patch._warp_cooldown = 0.0
	patch.bookmark_warp()
	ribbon = patch.ribbon
	boss._strike()
	await _frames(4)
	_check(get_nodes_in_group(&"redactor_strikes").size() == 1 and boss.state == 2, "a red line down the page where he stands")
	await create_timer(0.9).timeout
	_check(not is_instance_valid(ribbon) or ribbon.is_queued_for_deletion(), "the pen comes down it and strikes the ribbon out")
	await _skip_dialogue(dialogue)
	for i in 300:
		if boss.state == 1:
			break
		await physics_frame
	_check(boss.state == 1 and get_nodes_in_group(&"redactor_strikes").is_empty(), "two strikes, and it drifts again")
	# Stamp: it comes down in front of it and sticks; it's pinned, open.
	boss._stamp()
	for i in 120:
		if boss.state == 5:
			break
		await physics_frame
	_check(boss.state == 5 and boss.is_open() and boss.can_stagger(), "the stamp sticks in the page and pins its arm: open")
	await _skip_dialogue(dialogue)
	boss._on_hit(cut)
	_check(boss.health.current < hp, "pinned, it can be cut (%d of %d)" % [boss.health.current, boss.health.max_health])
	for i in 300:
		if boss.state == 1:
			break
		await physics_frame
	_check(boss.state == 1 and not boss.is_open(), "it pulls the stamp free and closes up")
	# Redact, with no ribbon down: walled in, and the ink takes him.
	await _stand(patch, Vector2(1000, 896))
	if patch.ribbon:
		patch.ribbon.queue_free()
		patch.ribbon = null
	boss._redact()
	var box: Node2D = null
	for i in 120:
		var boxes := get_nodes_in_group(&"redactor_boxes")
		if not boxes.is_empty() and boxes[0].is_shut:
			box = boxes[0]
			break
		await physics_frame
	_check(box != null and box.holds(patch.global_position), "a box rules itself round him and the walls come down")
	await _skip_dialogue(dialogue)
	Input.action_press(&"move_left")
	await _frames(30)
	Input.action_release(&"move_left")
	_check(box.holds(patch.global_position), "he can't walk out of it")
	Input.action_press(&"jump")
	await _frames(20)
	Input.action_release(&"jump")
	await _frames(30)
	_check(box.holds(patch.global_position), "or jump out of it")
	for i in 200:
		if boss.state != 4:
			break
		await physics_frame
	_check(boss.caught == 1 and not boss.is_open(), "the ink rises to the brim with him in it")
	await _skip_dialogue(dialogue)
	for i in 300:
		if boss.state == 1:
			break
		await physics_frame
	# Redact, with Gran's ribbon outside the lines: warp out, and it has spent its ink.
	await _stand(patch, Vector2(500, 896))
	patch._warp_cooldown = 0.0
	await _tap(&"warp")
	var ribbon_at := patch.global_position
	await _stand(patch, Vector2(1100, 896))
	boss._redact()
	for i in 120:
		var boxes := get_nodes_in_group(&"redactor_boxes")
		if not boxes.is_empty() and boxes[0].is_shut:
			box = boxes[0]
			break
		await physics_frame
	await _skip_dialogue(dialogue)
	patch._warp_cooldown = 0.0
	await _tap(&"warp")
	_check(patch.global_position.distance_to(ribbon_at) < 6.0 and not box.holds(patch.global_position), "Gran's ribbon gets him out of the box")
	for i in 200:
		if boss.state == 6:
			break
		await physics_frame
	_check(boss.escaped == 1 and boss.state == 6 and boss.is_open(), "the box fills with nobody in it: it has spent its ink, open")
	await _skip_dialogue(dialogue)
	hp = boss.health.current
	boss._on_hit(cut)
	_check(boss.health.current < hp, "and it can be cut")
	for i in 400:
		if boss.state == 1:
			break
		await physics_frame
	# From half health, silverfish come up after a redaction.
	boss.health.current = 7
	_check(boss.phase() == 1, "at half health it gets worse")
	await _stand(patch, Vector2(500, 896))
	patch._warp_cooldown = 0.0
	await _tap(&"warp")
	await _stand(patch, Vector2(1100, 896))
	boss._redact()
	for i in 200:
		if boss.state != 4:
			break
		await physics_frame
	_check(get_nodes_in_group(&"redactor_silverfish").size() == 1, "after a redaction a silverfish comes up out of the page")
	await _skip_dialogue(dialogue)
	# Down.
	boss.health.current = 1
	boss.health.clear_invulnerability()
	boss.health.take_damage(5, boss.global_position)
	for i in 400:
		if dialogue.is_active():
			break
		await physics_frame
	await _skip_dialogue(dialogue)
	await _frames(20)
	_check(game_state.get_flag("boss_redactor_defeated") and exit_door.visible, "the Redactor leaves it all in, and the Index is whole")
	_check(game_state.bestiary.get("redactor", 0) >= 1, "Nell's book gets a page for the Redactor")
	_check(get_nodes_in_group(&"redactor_boxes").is_empty() and get_nodes_in_group(&"redactor_silverfish").is_empty(), "its work goes with it")
	_check(not ("The Index" in book_map.torn_regions()), "the Index is mended")

	# The Errata opens.
	await scene_manager.change_page(R6 + "6_4_the_stacks.tscn", &"FromErrata")
	await _wait_for_scene("TheStacks", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(current_scene.get_node("Level/page_door_97_7").is_open(), "with the Redactor beaten, the Errata opens")
	await scene_manager.change_page(R6 + "errata.tscn", &"Start")
	await _wait_for_scene("Errata", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player") as CharacterBody2D
	var hearts_before: int = game_state.max_health
	patch.global_position = (current_scene.get_node("Level/heart_patch_34_9") as Node2D).global_position
	await _frames(10)
	_check(game_state.max_health == hearts_before + 2, "for 'lost' read 'kept': a heart in the Errata")
	await _skip_dialogue(dialogue)
	game_state.max_health = 99
	game_state.health = 99
	await scene_manager.change_page(R6 + "6_3_the_reading_room.tscn", &"FromStacks")
	await _wait_for_scene("TheReadingRoom", 120)
	await _frames(10)


## The Hayloft, 1-2's sealed back page: shut until the Millwheel is beaten, then a
## heart patch and 60 Scraps at the end of its gauntlet.
func _hayloft(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const R1 := "res://scenes/levels/thistledown/"
	await scene_manager.change_page(R1 + "1_2_the_sheepfold.tscn", &"FromChapel")
	await _frames(20)
	await _skip_dialogue(dialogue)
	var door := current_scene.get_node("Level/page_door_141_18")
	_check(door.is_open() and door.target_page == R1 + "hayloft.tscn", "beating the Millwheel breaks the hayloft's seal")
	await scene_manager.change_page(R1 + "hayloft.tscn", &"FromSheepfold")
	await _wait_for_scene("TheHayloft", 120)
	await _frames(20)
	await _skip_dialogue(dialogue)
	var patch := get_first_node_in_group("player") as CharacterBody2D
	_check(get_nodes_in_group(&"bookmarks").filter(func(n: Node) -> bool: return current_scene.is_ancestor_of(n)).is_empty(), "the Hayloft has no Bookmark")
	var hearts_before: int = game_state.max_health
	var scraps_before: int = game_state.scraps
	var heart := current_scene.get_node("Level/heart_patch_110_11") as Node2D
	patch.global_position = heart.global_position
	await _frames(10)
	var tin := current_scene.get_node("Level/scrap_113_11") as Node2D
	patch.global_position = tin.global_position
	await _frames(10)
	_check(game_state.max_health == hearts_before + 2, "the Hayloft's heart patch adds a heart")
	_check(game_state.scraps >= scraps_before + 60, "and Fluff's tin holds 60 Scraps")
	await _skip_dialogue(dialogue)
	game_state.max_health = 99
	game_state.health = 99

func _spine_hub(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const HUB := "res://scenes/levels/hub/spine_hub.tscn"
	var shop := load("res://scripts/ui/shop_panel.gd")
	var map_script := load("res://scripts/ui/map_panel.gd")
	var book_map := load("res://scripts/world/book_map.gd")
	var exit_target := ""
	for node in current_scene.get_node("Level").get_children():
		if node.get("requires_flag") == "cut_the_thread":
			exit_target = node.get("target_page")
	_check(exit_target == HUB and book_map.HUB == HUB, "the Prologue's way out leads into the Spine")
	game_state.remember_bookmark(current_scene.scene_file_path, Vector2(600, 1000), "The Rising")

	await scene_manager.change_page(HUB)
	await _wait_for_scene("SpineHub", 120)
	await _frames(30)
	await _skip_dialogue(dialogue)
	var patch := get_first_node_in_group("player") as CharacterBody2D
	_check(current_scene.name == "SpineHub" and patch != null and patch.is_on_floor(), "Patch stands in the Spine")
	var card := current_scene.get_node_or_null("TitleCard")
	_check(card != null and card.place_name == "The Spine", "walking into the Spine writes its name across the screen")
	# Music that fills in: with only the Prologue mended the music is still far off.
	var audio := root.get_node("AudioManager")
	_check(is_equal_approx(audio.fullness(), 1.0 / 7.0), "one region of seven mended: the music is a seventh full (%.2f)" % audio.fullness())
	var doors := {}
	for node in current_scene.get_node("Level").get_children():
		if node.get("region_id") != null and node.get("region_id") != &"":
			doors[node.get("region_id")] = node
	_check(doors.size() == 7 and doors.has(&"margins"), "the Spine has a door for each of the six regions and the optional Margins (%d)" % doors.size())
	_check(doors[&"thistledown"].state() == "open" and doors[&"thistledown"].can_interact(), "Thistledown's door is open from the start")
	_check(doors[&"lanternfold"].state() == "locked" and not doors[&"lanternfold"].can_interact(), "Lanternfold's door stays shut until Thistledown is mended")
	_check(doors[&"index"].state() == "locked" and not doors[&"index"].can_interact(), "the Index's door stays shut until the Barker is beaten")
	_check(doors[&"fair"].state() == "locked", "the Fair's door stays shut until Bindwell is beaten")
	_check(doors[&"marsh"].state() == "locked", "the Marsh's door stays shut until the Kraken is beaten")
	_check(doors[&"margins"].state() == "locked", "the Margins' door stays shut until the Kraken is beaten")
	var stair := current_scene.get_node("Stair")
	_check(not stair.is_open() and stair.get_children().filter(func(n: Node) -> bool: return n is StaticBody2D).is_empty(),
		"the stair to the gallery is broken until a region is mended")
	game_state.set_flag("boss_millwheel_defeated")
	await _frames(3)
	_check(doors[&"lanternfold"].state() == "open" and stair.get_children().filter(func(n: Node) -> bool: return n is StaticBody2D).size() == 2,
		"mending Thistledown opens Lanternfold's door and nails the stair back")
	_check(doors[&"thistledown"].state() == "mended", "Thistledown's door shows it mended")
	var cutoff_before: float = audio._lowpass.cutoff_hz
	var wet_before: float = audio._reverb.wet
	audio.update_fullness()
	await create_timer(4.5).timeout
	_check(is_equal_approx(audio.music_fullness, 2.0 / 7.0) and audio._lowpass.cutoff_hz > cutoff_before * 1.5
		and audio._reverb.wet < wet_before - 0.03, "mending a region fills the music in (cutoff %d Hz)" % audio._lowpass.cutoff_hz)
	# Climb: the two boards and the gallery are each within a jump of the last.
	var tops: Array[float] = [960.0, 832.0, 704.0, 576.0]
	var climbable := true
	for i in tops.size() - 1:
		climbable = climbable and tops[i] - tops[i + 1] <= 128.0
	_check(climbable, "each step up to the gallery is two tiles, within Patch's jump")

	# The torn map: the Prologue is mended, Thistledown seen-not-mended, the Marsh blank.
	game_state.visited["res://scenes/levels/thistledown/1_1_sodden_fields.tscn"] = true
	var regions: Array = book_map.REGIONS
	var states := {}
	for entry in regions:
		states[entry["id"]] = map_script.region_state(entry)
	_check(states[&"prologue"] == "mended" and states[&"thistledown"] == "mended" and states[&"marsh"] == "unknown"
		and states[&"lanternfold"] == "unknown", "the torn map shows mended, seen and blank regions (%s)" % str(states))
	game_state.set_flag("boss_millwheel_defeated", false)
	_check(map_script.region_state(regions[1]) == "seen", "a region Patch has been to but not mended is inked in")
	var opened: Node = map_script.open_panel(root)
	await _frames(2)
	_check(paused and map_script.current == opened, "the torn map opens and pauses the game")
	opened.close()
	await _frames(2)
	_check(not paused and map_script.current == null, "folding the map away unpauses")

	# Bookmarks remember themselves; with two known, any bookmark offers travel.
	var bookmark := get_first_node_in_group("bookmarks")
	bookmark._on_body_entered(patch)
	var hub_spot: Vector2 = bookmark.global_position + bookmark.respawn_offset
	_check(game_state.bookmarks.size() >= 2 and map_script.travel_list().size() == game_state.bookmarks.size(),
		"touching a bookmark remembers it for travel (%d known)" % game_state.bookmarks.size())
	var travel_spot := bookmark.get_node("TravelSpot")
	_check(travel_spot.can_interact(), "a bookmark offers travel once two are known")
	var travel: Node = map_script.open_panel(root, true)
	await _frames(2)
	travel.go_to(HUB, hub_spot)
	await _frames(40)
	patch = get_first_node_in_group("player") as CharacterBody2D
	_check(current_scene.name == "SpineHub" and not paused and patch.global_position.distance_to(hub_spot) < 80.0,
		"travelling by bookmark puts Patch at that bookmark")

	# Gran's sewing tin.
	for i in 120:
		if not scene_manager.is_transitioning:
			break
		await _frames(1)
	var tin: Node
	for node in current_scene.get_node("Level").get_children():
		if node.get("prompt_text") == "Open Gran's sewing tin":
			tin = node
	_check(tin != null and tin.can_interact(), "Gran's sewing tin is in the Spine")
	var before := {"scraps": game_state.scraps, "max_health": game_state.max_health}
	game_state.scraps = 0
	_check(not shop.buy_heart(), "a heart patch can't be bought without the scraps")
	game_state.scraps = 1000
	# Dad notices the first thing bought (his remarks are spaced out; skip the wait).
	var dad := root.get_node("DadNotes")
	dad._since_last = 999.0
	_check(shop.buy_heart() and game_state.max_health == before["max_health"] + 2
		and patch.health.max_health == game_state.max_health and patch.health.current == patch.health.max_health,
		"a heart patch adds a paper token, and Patch is mended to it")
	_check(game_state.get_flag("dad:bought_heart"), "Dad remarks on the first heart patch")
	_check(not dad.remark("bought_heart", true), "each of Dad's remarks is made only once")
	_check(not dad.remark("parry"), "Dad doesn't remark twice within a few seconds")
	for i in 3:
		dad._on_torn()
	_check(game_state.get_flag("dad:torn_3"), "Dad notices Patch torn three times on one page")
	_check(shop.buy_spool() and game_state.thread_max == 4.0, "a Thread spool adds a Thread charge")
	_check(shop.buy_charm(&"magpie_button") and shop.buy_charm(&"red_knot") and shop.buy_charm(&"heron_pin")
		and game_state.equipped.size() == 2 and not game_state.has_charm(&"heron_pin"),
		"charms are sewn on until both slots are full")
	game_state.thread = 0.0
	game_state.add_thread(1.0)
	_check(is_equal_approx(game_state.thread, 1.25), "the Red Knot fills Thread a quarter faster")
	_check(game_state.set_charm_equipped(&"red_knot", false) and game_state.set_charm_equipped(&"heron_pin", true)
		and game_state.has_charm(&"heron_pin"), "a charm can be taken off to make room for another")
	var panel: Node = null
	tin.interact(patch)
	await _frames(2)
	_check(paused, "opening the sewing tin pauses the game")
	panel = tin._shop
	var found_panel := panel != null
	if found_panel:
		# Under the lid: Gran's pattern cards, one row per pattern.
		panel._page_button.pressed.emit()
		await _frames(1)
		_check(panel._page == 1 and panel._list.get_child_count() == 4, "the tin's lid lifts to Gran's four pattern cards")
		panel.close()
	await _frames(2)
	_check(found_panel and not paused, "closing the sewing tin unpauses")

	# Gran's patterns: bought once with Scraps, kept for good.
	var shop_script: Script = load("res://scripts/ui/shop_panel.gd")
	game_state.scraps = 200
	_check(shop_script.buy_pattern(&"long_seam") and game_state.has_pattern(&"long_seam")
		and game_state.scraps == 50, "a pattern card can be bought at the tin")
	_check(not shop_script.buy_pattern(&"long_seam"), "a pattern is only learned once")
	_check(not shop_script.buy_pattern(&"blanket_stitch"), "a pattern can't be bought without the scraps")
	# Nell's bestiary: a page for each kind beaten; the pause menu opens it.
	game_state.bestiary.clear()
	game_state.record_defeat("soggy")
	game_state.record_defeat("soggy")
	game_state.shear_form = 1
	var pause_menu_node := root.get_node("PauseMenu")
	pause_menu_node.bestiary_button.pressed.emit()
	await _frames(2)
	var bestiary_panel = load("res://scripts/ui/bestiary_panel.gd").get(&"current")
	_check(bestiary_panel != null and paused and bestiary_panel._title.text == "Soggy"
		and bestiary_panel._count.text == "Beaten 2 times" and bestiary_panel._weak.text.contains("1 more"),
		"the pause menu opens Nell's bestiary at the Soggy page, weakness still hidden")
	if bestiary_panel:
		bestiary_panel.close()
	await _frames(2)
	_check(not paused, "closing the bestiary unpauses")
	# Save format 4 keeps all of it.
	game_state.save_game()
	_check(game_state.read_save(2).get("version", 0) == 6, "saves are written as version 6")
	await _play_report(game_state)
	await _difficulty_curve(game_state)
	game_state.shear_form = 0
	game_state.bestiary.clear()
	game_state.load_game(2)
	_check(game_state.heart_patches == 1 and game_state.spools == 1 and game_state.thread_max == 4.0
		and game_state.charms.size() == 3 and game_state.has_charm(&"heron_pin")
		and game_state.bookmarks.size() >= 2 and game_state.visited.has(HUB)
		and game_state.has_pattern(&"long_seam"),
		"loading restores upgrades, charms, patterns, bookmarks and the map")
	_check(game_state.shear_form == 1 and int(game_state.bestiary.get("soggy", 0)) == 2,
		"loading restores the shears' form and Nell's bestiary")
	# A version 1 save (from before the hub) still loads, with none of the new things.
	var save_path: String = game_state.save_path(2)
	var current_save := FileAccess.get_file_as_string(save_path)
	var old_save := FileAccess.open(save_path, FileAccess.WRITE)
	old_save.store_string(JSON.stringify({"version": 1, "max_health": 8, "scraps": 5,
		"checkpoint_page": HUB, "flags": {}}))
	old_save.close()
	_check(game_state.load_game(2) and game_state.heart_patches == 0 and game_state.charms.is_empty()
		and game_state.bookmarks.is_empty() and game_state.thread_max == 3.0
		and game_state.patterns.is_empty(), "a version 1 save still loads")
	var v2_save := FileAccess.open(save_path, FileAccess.WRITE)
	v2_save.store_string(JSON.stringify({"version": 2, "max_health": 10, "scraps": 5, "heart_patches": 1,
		"charms": ["red_knot"], "checkpoint_page": HUB, "flags": {}}))
	v2_save.close()
	_check(game_state.load_game(2) and game_state.heart_patches == 1 and game_state.charms.size() == 1
		and game_state.patterns.is_empty(), "a version 2 save still loads, with no patterns yet")
	var v3_save := FileAccess.open(save_path, FileAccess.WRITE)
	v3_save.store_string(JSON.stringify({"version": 3, "max_health": 10, "scraps": 5,
		"patterns": ["backstitch"], "checkpoint_page": HUB, "flags": {}}))
	v3_save.close()
	_check(game_state.load_game(2) and game_state.has_pattern(&"backstitch") and game_state.shear_form == 0
		and game_state.bestiary.is_empty(), "a version 3 save still loads, with Bill shears and an empty bestiary")

	# Put the run back the way it was, so later checks see the standard game.
	var restore := FileAccess.open(save_path, FileAccess.WRITE)
	restore.store_string(current_save)
	restore.close()
	game_state.load_game(2)
	game_state.heart_patches = 0
	game_state.spools = 0
	game_state.patterns.clear()
	game_state.bestiary.clear()
	game_state.shear_form = 0
	game_state.thread_max = 3.0
	game_state.max_health = before["max_health"]
	game_state.charms.clear()
	game_state.equipped.clear()
	game_state.scraps = before["scraps"]
	patch.health.max_health = game_state.max_health
	patch.health.set_health(game_state.max_health)


func _wait_for_scene(scene_name: String, max_frames: int) -> void:
	for i in max_frames:
		if current_scene and current_scene.name == scene_name:
			return
		await _frames(1)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _skip_dialogue(dialogue: Node, max_lines := 40) -> void:
	for i in max_lines:
		if not dialogue.is_active():
			return
		var press := InputEventAction.new()
		press.action = &"interact"
		press.pressed = true
		Input.parse_input_event(press)
		await _frames(2)
		var release := InputEventAction.new()
		release.action = &"interact"
		release.pressed = false
		Input.parse_input_event(release)
		await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## Every enemy and friend is painted (docs/ART_STYLE.md): its art comes from
## assets/art/dark, and it stands within its size band next to Patch (150 px).
const PATCH_HEIGHT := 150.0
const FRIEND_BAND := Vector2(0.3, 1.6)
const PAINTED := {
	"res://scenes/enemies/soggy.tscn": Vector2(0.65, 0.85),
	"res://scenes/enemies/ink_spitter.tscn": Vector2(0.65, 0.85),
	"res://scenes/enemies/tack_knight.tscn": Vector2(1.0, 1.3),
	"res://scenes/enemies/ink_blob.tscn": Vector2(0.15, 0.5),
	"res://scenes/enemies/paper_moth.tscn": Vector2(0.4, 0.7),
	"res://scenes/enemies/inkwell_turret.tscn": Vector2(0.65, 0.85),
	"res://scenes/enemies/folded_crane.tscn": Vector2(0.65, 0.85),
	"res://scenes/enemies/mimic_book.tscn": Vector2(0.5, 0.75),
	"res://scenes/enemies/carousel_horse.tscn": Vector2(1.0, 1.6),
	"res://scenes/enemies/ink_drip.tscn": Vector2(0.15, 0.5),
	"res://scenes/enemies/boss_millwheel.tscn": Vector2(2.5, 6.0),
	"res://scenes/enemies/boss_kraken.tscn": Vector2(2.5, 6.0),
	"res://scenes/enemies/boss_sogg.tscn": Vector2(2.5, 6.0),
	"res://scenes/world/npc_shepherd_fluff.tscn": FRIEND_BAND,
	"res://scenes/world/lost_sheep.tscn": FRIEND_BAND,
	"res://scenes/world/npc_dot.tscn": FRIEND_BAND,
	"res://scenes/world/dot_companion.tscn": FRIEND_BAND,
	"res://scenes/world/npc_corrugate.tscn": FRIEND_BAND,
	"res://scenes/world/corrugate_companion.tscn": FRIEND_BAND,
	"res://scenes/world/npc_bindwell.tscn": FRIEND_BAND,
	"res://scenes/world/npc_lamplighters.tscn": FRIEND_BAND,
	"res://scenes/world/crumple.tscn": FRIEND_BAND,
	"res://scenes/world/npc_drizzle.tscn": FRIEND_BAND,
	"res://scenes/world/drizzle_companion.tscn": FRIEND_BAND,
}


func _painted_art() -> void:
	for path in PAINTED:
		var enemy := (load(path) as PackedScene).instantiate()
		var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null:
			sprite = enemy.get_node_or_null("Body") as Sprite2D  # bosses
		# Every other sprite in the scene (sails, core, eye, heart) is painted too.
		for part in enemy.find_children("*", "Sprite2D"):
			var part_path: String = part.texture.resource_path if part.texture else ""
			_check(part_path.begins_with("res://assets/art/dark/"), "%s's %s is painted (%s)" % [path.get_file(), part.name if part.name != "Sprite2D" else part.get_parent().name, part_path])
		var texture_path := sprite.texture.resource_path if sprite and sprite.texture else ""
		_check(texture_path.begins_with("res://assets/art/dark/"), "%s is painted (%s)" % [path.get_file(), texture_path])
		if sprite and sprite.texture:
			var used := sprite.texture.get_image().get_used_rect()
			var size := used.size.y * absf(sprite.scale.y) / PATCH_HEIGHT
			var band: Vector2 = PAINTED[path]
			_check(size >= band.x and size <= band.y, "%s stands %.2f x Patch (band %.2f-%.2f)" % [path.get_file(), size, band.x, band.y])
		enemy.free()
	_painted_tiles()
	_painted_props()
	_side_only_enemies()
	# Patch himself: nothing of his comes from the old bright art any more.
	for path in ["res://scenes/player/patch.tscn", "res://scripts/player/patch.gd", "res://scripts/player/dark_rig.gd", "res://scripts/minigames/shadow_theater.gd"]:
		var text := FileAccess.get_file_as_string(path)
		_check(not text.contains("res://assets/art/characters/"), "%s uses only painted art" % path.get_file())


## Every region has its painted tiles, and every top piece has a pale lit lip above its
## fill, so standable ground reads against the dark.
func _painted_tiles() -> void:
	# Read through load(): naming TextLevel here would compile its autoload-using deps early.
	var regions: Dictionary = (load("res://scripts/world/text_level.gd") as Script).get_script_constant_map()["REGION_TILESETS"]
	for region in regions:
		var tile_set := load(regions[region]) as TileSet
		var source := tile_set.get_source(0) as TileSetAtlasSource if tile_set else null
		_check(source != null and source.get_tiles_count() == 32 and source.texture.resource_path.begins_with("res://assets/art/dark/tiles/"), "%s has its 32 painted tiles" % region)
		if source == null:
			continue
		var image := source.texture.get_image()
		if image.is_compressed():
			image.decompress()
		for row in 4:
			var lip := 0.0
			var fill := 0.0
			for x in range(0, 64, 4):
				var best := 0.0
				for y in range(0, 16):
					best = maxf(best, image.get_pixel(2 * 64 + x, row * 64 + y).get_luminance())
				lip += best / 16.0
				fill += image.get_pixel(x, row * 64 + 40).get_luminance() / 16.0
			_check(lip > fill + 0.2, "%s row %d has a pale lip over its ground (%.2f vs %.2f)" % [region, row, lip, fill])


## Nothing in the game draws the old bright art: every scene and script points at the
## painted props and backdrops. The warm air under the hair dryer is the one old piece
## kept (it is already a dim, warm haze).
const OLD_ART := ["res://assets/art/props/", "res://assets/art/backgrounds/", "res://assets/art/characters/"]
const OLD_ART_KEPT := ["res://assets/art/props/warm_beam.png"]


func _painted_props() -> void:
	var offenders: Array[String] = []
	for path in _files_under("res://scenes", ".tscn") + _files_under("res://scripts", ".gd"):
		var text := FileAccess.get_file_as_string(path)
		for kept in OLD_ART_KEPT:
			text = text.replace(kept, "")
		for old in OLD_ART:
			if text.contains(old):
				offenders.append(path.get_file())
				break
	_check(offenders.is_empty(), "every scene and script uses painted art (old art in %s)" % ", ".join(offenders))
	# Each painted prop keeps its old canvas, so scenes, offsets and hitboxes still fit.
	var dir := DirAccess.open("res://assets/art/props")
	for file in dir.get_files():
		if not file.ends_with(".png") or ("res://assets/art/props/" + file) in OLD_ART_KEPT:
			continue
		var painted := "res://assets/art/dark/props/" + file
		if not ResourceLoader.exists(painted):
			continue
		var old_size := (load("res://assets/art/props/" + file) as Texture2D).get_size()
		var new_size := (load(painted) as Texture2D).get_size()
		_check(old_size == new_size, "painted %s keeps the old canvas (%s vs %s)" % [file, new_size, old_size])


## The Phase 2 enemies fly, dive or hop under gravity, so they only work on side-view
## pages. A top-down page (view_mode = 1) must not place them.
const SIDE_ONLY := ["paper_moth.tscn", "inkwell_turret.tscn", "folded_crane.tscn", "mimic_book.tscn", "carousel_horse.tscn"]


func _side_only_enemies() -> void:
	var offenders: Array[String] = []
	for path in _files_under("res://scenes/levels", ".tscn"):
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("\nview_mode = 1"):
			continue
		for scene in SIDE_ONLY:
			if text.contains("enemies/" + scene):
				offenders.append(path.get_file())
				break
	_check(offenders.is_empty(), "side-view enemies stay off top-down pages (%s)" % ", ".join(offenders))


## A Margin page is drawn as the 3D desk: the main screen no longer draws the 2D page,
## and Patch's painted rig is filmed onto the desk (it can't be copied as a flat sprite).
func _drawn_as_desk() -> bool:
	var diorama := current_scene.get_node_or_null("Diorama")
	if diorama == null:
		return false
	var page_hidden: bool = not current_scene.visible or (root.canvas_cull_mask & current_scene.visibility_layer) == 0
	return page_hidden and diorama.get("_rig_sprite") != null


func _files_under(root_path: String, ext: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		return found
	for file in dir.get_files():
		if file.ends_with(ext):
			found.append(root_path.path_join(file))
	for sub in dir.get_directories():
		found.append_array(_files_under(root_path.path_join(sub), ext))
	return found


func _check(condition: bool, label: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + label)
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE TEST PASSED")
		quit(0)
	else:
		print("SMOKE TEST FAILED: %d check(s)" % _failures.size())
		quit(1)


## The voice pass: every recorded clip belongs to a real line, a voiced line plays its
## recording instead of the blips, and every sound the scripts ask for exists (a
## missing name only warns at run time, so a typo goes unheard).
func _voice_and_sound(dialogue: Node) -> void:
	var conversations: Dictionary = dialogue.get(&"_conversations")
	var clips := 0
	var strays: Array[String] = []
	var first_voiced := ""
	for file in DirAccess.get_files_at("res://assets/audio/vo/"):
		if not file.ends_with(".ogg"):
			continue
		var stem := file.get_basename()
		var cut := stem.rfind("_")
		var conv := stem.substr(0, cut)
		var index := int(stem.substr(cut + 1))
		if not conversations.has(conv) or index >= (conversations[conv] as Array).size():
			strays.append(file)
			continue
		clips += 1
		if first_voiced.is_empty() and index == 0:
			first_voiced = conv
	_check(clips >= 285, "story dialogue is voiced (%d recorded lines)" % clips)
	_check(strays.is_empty(), "every recording belongs to a dialogue line %s" % [strays])
	if not first_voiced.is_empty():
		dialogue.start(first_voiced)
		await _frames(5)
		_check(dialogue.is_speaking(), "a voiced line plays its recording ('%s')" % first_voiced)
		_check(dialogue.get(&"_voiced"), "a voiced line skips the blips")
		await _skip_dialogue(dialogue, 200)
		_check(not dialogue.is_speaking(), "finishing a conversation stops its recording")
	var sfx: Dictionary = root.get_node("AudioManager").get(&"SFX")
	var unknown: Array[String] = []
	var regex := RegEx.create_from_string("play_sfx\\(&\"([a-z_]+)\"")
	for path in _scripts_under("res://scripts/"):
		for m in regex.search_all(FileAccess.get_file_as_string(path)):
			if not sfx.has(StringName(m.get_string(1))):
				unknown.append("%s in %s" % [m.get_string(1), path.get_file()])
	_check(unknown.is_empty(), "every sound the scripts play exists %s" % [unknown])


func _scripts_under(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir + file)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_under(dir + sub + "/"))
	return out


## Patch's torn-paper health strip follows his health, and ordinary enemies grow a
## small bar over their heads once hurt (one-hit enemies and bosses don't).
func _health_bars(patch: Node) -> void:
	var hud := root.get_node("HUD")
	var strip: Control = hud.find_child("PatchHealth", true, false)
	_check(strip != null and strip.visible, "Patch's health shows as a paper strip")
	if strip == null:
		return
	var before: float = patch.health.current
	patch.health.take_damage(2, patch.global_position)
	await _frames(2)
	_check(is_equal_approx(strip.get(&"value"), before - 2.0), "the strip drops when Patch is hurt (%s)" % strip.get(&"value"))
	patch.health.clear_invulnerability()
	patch.health.heal(2)
	await _frames(2)
	_check(is_equal_approx(strip.get(&"value"), before), "the strip refills when Patch heals")
	_check(not hud.find_child("BossHealth", true, false).visible and hud.find_child("BossPaper", true, false) != null, "the boss bar is a paper strip too")
	var tough: Node2D = null
	var flimsy: Node2D = null
	for enemy in get_nodes_in_group("enemies"):
		var h = enemy.get("health")
		if h == null:
			continue
		if h.max_health > 1 and tough == null:
			tough = enemy
		elif h.max_health == 1 and flimsy == null:
			flimsy = enemy
	if tough:
		var bar := _enemy_bar(tough)
		_check(bar != null and bar.modulate.a == 0.0, "an unhurt enemy's bar is hidden")
		tough.get("health").take_damage(1, patch.global_position)
		await _frames(2)
		_check(bar != null and bar.modulate.a > 0.9, "a hurt enemy shows its bar")
		tough.get("health").clear_invulnerability()
		tough.get("health").heal(1)
	if flimsy:
		_check(_enemy_bar(flimsy) == null, "one-hit enemies get no bar")


func _enemy_bar(enemy: Node) -> Node2D:
	for child in enemy.get_children():
		if child.get_script() != null and child.get_script().get_global_name() == &"EnemyBar":
			return child
	return null


## The play report: time, visits, deaths and hits are counted per page, saved with
## the game, written out as a readable report, and shown from the pause menu.
## The difficulty curve: the main-path bosses get tougher in book order, and the last
## regions cut one point deeper so found hearts don't make them soft.
func _difficulty_curve(game_state: Node) -> void:
	var book_map = load("res://scripts/world/book_map.gd")
	var order := ["millwheel", "kraken", "heron", "bindwell", "barker", "redactor", "sogg"]
	var last := 0
	var rising := true
	var seen: Array[String] = []
	for id: String in order:
		var state := (load("res://scenes/enemies/boss_%s.tscn" % id) as PackedScene).get_state()
		var hp := 0
		for n in state.get_node_count():
			for k in state.get_node_property_count(n):
				if state.get_node_property_name(n, k) == &"max_health":
					hp = int(state.get_node_property_value(n, k))
		seen.append("%s %d" % [id, hp])
		rising = rising and hp > 0 and hp >= last
		last = hp
	_check(rising, "boss health rises through the book (%s)" % ", ".join(seen))
	_check(book_map.ink_depth("res://scenes/levels/thistledown/1_1_x.tscn") == 0 and book_map.ink_depth("res://scenes/levels/marsh/3_1_x.tscn") == 0
		and book_map.ink_depth("res://scenes/levels/fair/5_1_x.tscn") == 1 and book_map.ink_depth("res://scenes/levels/index/6_1_x.tscn") == 1
		and book_map.ink_depth("res://scenes/levels/finale/f_1_x.tscn") == 1 and book_map.ink_depth("res://scenes/levels/combat_lab/lab.tscn") == 0,
		"only the Fair, the Index and the Gutter cut deeper")
	var patch = get_first_node_in_group("player")
	if patch == null:
		return
	var was: String = game_state.current_page
	var hit = load("res://scripts/components/hitbox.gd").new()
	hit.damage = 2
	root.add_child(hit)
	var settings = root.get_node("Settings")
	var kept: Array = [settings.auto_guard, settings.assist]
	settings.auto_guard = false
	settings.assist = false
	var taken := []
	for page in ["res://scenes/levels/thistledown/1_1_x.tscn", "res://scenes/levels/fair/5_1_x.tscn"]:
		game_state.current_page = page
		patch.state = 0
		patch.health.clear_invulnerability()
		patch.health.set_health(patch.health.max_health)
		var before: int = patch.health.current
		patch._on_hurtbox_hit(hit)
		taken.append(before - patch.health.current)
	settings.auto_guard = kept[0]
	settings.assist = kept[1]
	patch.state = 0
	patch.health.set_health(patch.health.max_health)
	game_state.current_page = was
	hit.queue_free()
	patch.health.clear_invulnerability()
	_check(taken == [2, 3], "a 2-point hit takes 2 in Thistledown and 3 at the Fair (%s)" % [taken])


func _play_report(game_state: Node) -> void:
	var stats: Dictionary = game_state.page_stats
	var here: Dictionary = stats.get(game_state.current_page, {})
	_check(float(here.get("t", 0.0)) > 1.0 and int(here.get("v", 0)) >= 1, "play time and visits are counted on this page (%s)" % [here])
	var hits := 0
	for page: String in stats:
		hits += int(stats[page].get("h", 0))
	_check(hits > 0, "hits taken are counted (%d)" % hits)
	_check(game_state.read_save(2).has("page_stats"), "the play report is saved with the game")
	var report := FileAccess.get_file_as_string("user://play_report_slot_2.txt")
	_check(report.begins_with("Play report:") and report.contains("Thistledown"), "the play report is written next to the save")
	var pause := root.get_node("PauseMenu")
	pause.call(&"open")
	await _frames(2)
	var button: Button = pause.find_child("ReportButton", true, false)
	_check(button != null, "the pause menu has a play report button")
	if button:
		button.pressed.emit()
		await _frames(3)
		var panel: Node = root.get_node_or_null("PlayReportPanel")
		_check(panel != null and paused, "the play report opens and pauses the game")
		if panel:
			panel.call(&"close")
			await _frames(2)
		_check(not paused, "closing the play report unpauses")


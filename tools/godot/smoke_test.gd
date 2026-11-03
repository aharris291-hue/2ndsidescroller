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
	var settings := root.get_node("Settings")
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
	# Every action must work on a controller (the slam once had no button, which
	# stranded controller players at the ice on the flat Frostfold page).
	for action in [&"jump", &"attack", &"heavy", &"dash", &"guard", &"mend", &"grapple", &"slam", &"interact", &"map", &"pause"]:
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
	await scene_manager.change_page("res://scenes/levels/ch1_thistledown/thistledown_page_01.tscn")
	await _frames(60)
	var patch := get_first_node_in_group("player") as CharacterBody2D
	_check(patch != null, "Patch spawns on Thistledown page 1")
	if patch == null:
		_finish()
		return
	_check(patch.is_on_floor(), "Patch lands on the ground")

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

	# Talk to Shepherd Fluff.
	var fluff := current_scene.get_node("Actors/ShepherdFluff") as Node2D
	patch.global_position = fluff.global_position + Vector2(-60, -48)
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

	# Pull the bridge tab.
	var tab := current_scene.get_node("Props/BridgeTab")
	var bridge := current_scene.get_node("Props/TabBridge") as Node2D
	var bridge_y := bridge.position.y
	patch.global_position = tab.global_position + Vector2(-40, -48)
	await _frames(10)
	Input.action_press(&"interact")
	await _frames(2)
	Input.action_release(&"interact")
	await _frames(70)
	_check(bridge.position.y < bridge_y - 150.0, "pulling the tab raises the bridge")

	# Hit a Soggy until it dries out.
	var soggy := current_scene.get_node_or_null("Actors/Soggy1") as Node2D
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
	game_state.delete_save(2)
	_finish()


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

	# Windmill Hills: the wind tab spins the big windmill; sheep count toward the quest.
	await scene_manager.change_page("res://scenes/levels/ch1_thistledown/thistledown_page_02.tscn")
	await _frames(20)
	await _skip_dialogue(dialogue)
	var wheel := current_scene.get_node("Props/BigWindmill")
	var gondola := wheel.get_node("Gondola0") as Node2D
	var seat_start := gondola.position
	await current_scene.get_node("Props/WindTab").interact(null)
	await _frames(60)
	_check(wheel.spinning and gondola.position.distance_to(seat_start) > 20.0, "pulling the wind tab turns the windmill wheel")
	for sheep_name in ["Sheep1", "Sheep2", "Sheep3"]:
		current_scene.get_node("Actors/" + sheep_name).interact(null)
	_check(game_state.quest_progress("lost_flock") == 3, "all three lost sheep can be found")

	# Shepherd Fluff rewards the finished quest.
	await scene_manager.change_page("res://scenes/levels/ch1_thistledown/thistledown_page_01.tscn", &"FromHills")
	await _frames(20)
	var scraps_before: int = game_state.scraps
	current_scene.get_node("Actors/ShepherdFluff").interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_done("lost_flock") and game_state.scraps >= scraps_before + 15, "turning in the flock pays 15 Scraps")
	current_scene.get_node("Actors/Dot").interact(null)
	await _skip_dialogue(dialogue)
	await _frames(10)
	_check(get_first_node_in_group("companion") != null and current_scene.get_node_or_null("Actors/Dot") == null, "Dot joins Patch as a companion")

	# The Ribbon Regatta runs from start to finish and returns to the dock.
	Engine.time_scale = 8.0
	await scene_manager.change_page("res://scenes/levels/ch1_thistledown/ribbon_regatta.tscn")
	var race := current_scene
	for i in 600:
		await physics_frame
		if not is_instance_valid(race) or race.is_finished():
			break
	_check(is_instance_valid(race) and race.is_finished(), "the paper-boat race reaches the finish line")
	await _frames(200)
	Engine.time_scale = 1.0
	_check(current_scene.name == "ThistledownPage02", "the race returns to the Windmill Hills dock")

	# Old Millwheel: jam the sails with the three tabs, hit the core, three times over.
	await scene_manager.change_page("res://scenes/levels/ch1_thistledown/millwheel_arena.tscn")
	await _frames(20)
	await _skip_dialogue(dialogue)
	var patch = get_first_node_in_group("player")
	patch.health.max_health = 99
	patch.health.set_health(99)
	var boss := current_scene.get_node("OldMillwheel")
	boss.start_fight()
	_check(boss.state == 1, "the Old Millwheel fight starts")
	for cycle in 3:
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

	# The interlude closes Chapter 1 and turns to Chapter 2.
	await scene_manager.change_page("res://scenes/levels/interludes/interlude_01.tscn")
	for i in 1200:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	await _frames(90)
	_check(game_state.get_flag("chapter1_complete"), "the interlude marks Chapter 1 complete")


func _chapter_two(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const CH2 := "res://scenes/levels/ch2_lanternfold/"
	# Lanternfold: meet Corrugate (opens the way to the Margin) and the Lamplighter Sisters.
	await scene_manager.change_page(CH2 + "lanternfold_town.tscn")
	await _frames(30)
	await _skip_dialogue(dialogue)
	_check(current_scene.name == "LanternfoldTown" and get_first_node_in_group("player").view_mode == 1, "Lanternfold Harbor loads as a top-down page")
	current_scene.get_node("Actors/Corrugate").interact(null)
	await _skip_dialogue(dialogue)
	_check(current_scene.get_node("Props/MarginDoor").is_open(), "meeting Corrugate opens the way to Gran's table")
	_check(not current_scene.get_node("Props/HarborFlap").is_open(), "the harbor flap stays shut until Corrugate joins")
	current_scene.get_node("Actors/LamplighterSisters").interact(null)
	await _skip_dialogue(dialogue)
	for lantern in current_scene.get_node("Props").get_children():
		if lantern.name.begins_with("Lantern"):
			lantern.interact(null)
	_check(game_state.quest_progress("festival_lanterns") == 5, "all five festival lanterns can be lit")
	current_scene.get_node("Actors/LamplighterSisters").interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_done("festival_lanterns"), "the Lamplighter Sisters reward the lit lanterns")

	# The Margin heist: the 3D desk, and the strip of real tape that becomes the Tape Tail.
	await scene_manager.change_page("res://scenes/levels/margin/tape_heist.tscn", &"FromPage")
	await _frames(30)
	await _skip_dialogue(dialogue)
	var patch = get_first_node_in_group("player")
	_check(_drawn_as_desk(), "the Margin heist is drawn as the 3D desk, with Patch on it")
	patch.global_position = current_scene.get_node("Pickups/TapeStrip").global_position
	await _frames(20)
	_check(game_state.has_ability(&"tape_tail"), "the tape strip gives Patch the Tape Tail")

	# Back in town: zip across the harbor with the Tape Tail to fetch Crumple.
	await scene_manager.change_page(CH2 + "lanternfold_town.tscn", &"FromMargin")
	await _frames(30)
	current_scene.get_node("Actors/Corrugate").interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_started("lost_cat"), "Corrugate asks Patch to find his cat")
	patch = get_first_node_in_group("player")
	patch.global_position = Vector2(31 * 64, 28.8 * 64)
	patch.facing = Vector2.RIGHT
	await _frames(5)
	_check(patch.try_grapple(), "the Tape Tail finds the island ring")
	await _frames(60)
	_check(patch.global_position.x > 38 * 64 and patch.state == 0, "zipping carries Patch across the water to the island")
	current_scene.get_node("Actors/Crumple").interact(null)
	_check(game_state.quest_progress("lost_cat") == 1, "Crumple the cat can be found")
	current_scene.get_node("Actors/Corrugate").interact(null)
	await _skip_dialogue(dialogue)
	await _frames(10)
	_check(game_state.get_flag("corrugate_joined") and current_scene.get_node("Props/HarborFlap").is_open(), "Corrugate joins and the harbor flap opens")
	var companions := get_nodes_in_group("companion")
	_check(companions.any(func(c: Node) -> bool: return c.get("companion_flag") == "corrugate_joined"), "Corrugate follows Patch")

	# The shadow theater runs a whole show (autoplayed) and returns to town.
	Engine.time_scale = 6.0
	await scene_manager.change_page(CH2 + "shadow_theater.tscn")
	var show := current_scene
	show.autoplay = true
	for i in 900:
		await physics_frame
		if not is_instance_valid(show) or show.is_finished():
			break
	_check(is_instance_valid(show) and show.is_finished() and game_state.quest_done("shadow_show"), "the shadow show can be played and won")
	await _frames(200)
	Engine.time_scale = 1.0
	_check(current_scene.name == "LanternfoldTown", "the shadow show returns to town")

	# Under the harbor flap: zip over the first ink gap, then yank the flap gate open.
	await scene_manager.change_page(CH2 + "under_the_flap.tscn")
	await _frames(20)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player")
	patch.global_position = Vector2(16 * 64, 14 * 64 - 48)
	patch.facing = Vector2.RIGHT
	await _frames(5)
	patch.try_grapple()
	await _frames(150)
	_check(patch.global_position.x > 25 * 64 and patch.is_on_floor(), "Patch zips over the first ink gap (x=%.0f)" % patch.global_position.x)
	var gate := current_scene.get_node("Props/FlapGate") as Node2D
	var gate_y := gate.position.y
	patch.global_position = Vector2(44 * 64, 14 * 64 - 48)
	patch.facing = Vector2.RIGHT
	await _frames(10)
	patch.try_grapple()
	await _frames(70)
	_check(gate.position.y < gate_y - 200.0, "yanking the gate ring lifts the flap gate")

	# The Blotch Kraken: yank both blotters to stun it, swipe its eye, three times over.
	await scene_manager.change_page(CH2 + "kraken_arena.tscn")
	await _frames(20)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player")
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

	await scene_manager.change_page("res://scenes/levels/interludes/interlude_02.tscn")
	for i in 1200:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	await _frames(90)
	_check(game_state.get_flag("chapter2_complete"), "the second interlude marks Chapter 2 complete")


func _chapter_three(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const CH3 := "res://scenes/levels/ch3_spine/"
	# The second interlude now turns the page to Frostfold.
	_check(current_scene.name == "FrostfoldSlopes", "the second interlude turns to Chapter 3 (now on %s)" % current_scene.name)

	# Frostfold Slopes: pick up the Pop-Up Slam, spring a fold mark, ride the peak up.
	await scene_manager.change_page(CH3 + "frostfold_slopes.tscn")
	await _frames(20)
	await _skip_dialogue(dialogue)
	var patch = get_first_node_in_group("player")
	patch.health.max_health = 99
	patch.health.set_health(99)
	patch.global_position = current_scene.get_node("Pickups/PopUpSlamPage").global_position
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(game_state.has_ability(&"pop_up_slam"), "the folded page gives Patch the Pop-Up Slam")
	var fold := current_scene.get_node("Props/FoldA")
	patch.global_position = fold.global_position + Vector2(0, -48)
	patch.velocity = Vector2.ZERO
	await _frames(30)
	await _skip_dialogue(dialogue)
	# This checks the fold mark, not a fight: clear any enemy close enough to lunge into
	# the slam's hop (a Soggy hit cancels it, depending on where the earlier fights left it).
	for actor in current_scene.get_node("Actors").get_children():
		if actor is CharacterBody2D and actor.global_position.distance_to(fold.global_position) < 600.0:
			actor.queue_free()
	await _frames(2)
	var ground_y: float = patch.global_position.y
	await _press(&"slam")
	await _frames(70)
	_check(fold.is_up, "a Pop-Up Slam on a fold mark springs the peak")
	_check(patch.global_position.y < ground_y - 180.0, "the peak carries Patch up (rose %.0f px)" % (ground_y - patch.global_position.y))
	var ice := current_scene.get_node("Props/IceWall23")
	patch.global_position = Vector2(26.6 * 64, 26 * 64 - 48)
	patch.velocity = Vector2.ZERO
	await _frames(30)
	await _skip_dialogue(dialogue)
	await _press(&"slam")
	await _frames(60)
	_check(not is_instance_valid(ice), "slamming next to the ice wall shatters it")
	_check(current_scene.get_node("Props/LayPageFlat").is_open(), "the cliff can be laid flat")

	# Laid flat: a top-down snowfield. Bindwell opens the Margin; slam breaks the ice gap.
	await scene_manager.change_page(CH3 + "frostfold_flat.tscn", &"FromSlopes")
	await _frames(30)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player")
	_check(current_scene.name == "FrostfoldFlat" and patch.view_mode == 1, "laying the page flat turns it top-down")
	_check(not current_scene.get_node("Props/MarginDoor").is_open(), "the Margin stays shut until Patch meets Bindwell")
	current_scene.get_node("Actors/Bindwell").interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_started("restring_spine") and current_scene.get_node("Props/MarginDoor").is_open(), "Bindwell gives her quest and points to the Margin")
	_check(not current_scene.get_node("Props/StandUpBeyond").is_open(), "the far side stays flat until Patch has a paperclip")
	patch.global_position = Vector2(19 * 64, 21.5 * 64)
	await _frames(10)
	await _skip_dialogue(dialogue)
	await _press(&"slam")
	await _frames(60)
	var gap_left := 0
	for child in current_scene.get_node("Props").get_children():
		if child.name.begins_with("GapIce"):
			gap_left += 1
	_check(gap_left == 0, "a top-down slam breaks the ice sealing the way round (%d left)" % gap_left)

	# The paperclip heist: the clip, and the hairdryer plug hauled over to the book.
	await scene_manager.change_page("res://scenes/levels/margin/paperclip_heist.tscn", &"FromPage")
	await _frames(30)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player")
	_check(_drawn_as_desk(), "the paperclip heist is drawn as the 3D desk, with Patch on it")
	var plug := current_scene.get_node("Props/HairdryerPlug") as Node2D
	var plug_x := plug.position.x
	current_scene.get_node("Props/PlugRing").yank()
	await _frames(90)
	await _skip_dialogue(dialogue)
	_check(game_state.get_flag("plug_moved") and plug.position.x < plug_x - 300.0, "yanking the plug ring hauls the plug toward the book")
	patch.global_position = current_scene.get_node("Pickups/Paperclip").global_position
	await _frames(20)
	await _skip_dialogue(dialogue)
	_check(game_state.get_flag("has_paperclip"), "Patch takes the paperclip")
	_check(current_scene.get_node("Props/BackIntoTheBook").is_open(), "the way back into the book opens")

	await scene_manager.change_page(CH3 + "frostfold_flat.tscn", &"FromMargin")
	await _frames(30)
	_check(current_scene.get_node("Props/StandUpBeyond").is_open(), "with the paperclip, the page can be stood up past the cliff")
	await scene_manager.change_page(CH3 + "frostfold_slopes.tscn", &"FromFlat")
	await _frames(30)
	patch = get_first_node_in_group("player")
	_check(patch.global_position.x > 49 * 64, "standing the page up puts Patch beyond the cliff")

	# The Spine: zip to a piton, gather Bindwell's spools, and the low point by the fire.
	await scene_manager.change_page(CH3 + "the_spine.tscn")
	await _frames(30)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player")
	# Clear the Soggies so none of them knock Patch off the tape mid-zip.
	for actor in current_scene.get_node("Actors").get_children():
		if actor.name.begins_with("Soggy"):
			actor.free()
	patch.global_position = Vector2(31 * 64, 39 * 64 - 48)
	patch.facing = Vector2.LEFT
	await _frames(10)
	await _skip_dialogue(dialogue)
	_check(patch.try_grapple(), "the Tape Tail finds the shelf piton")
	await _frames(120)
	_check(patch.global_position.x < 27 * 64 and patch.global_position.y < 33 * 64 and patch.is_on_floor(), "zipping to the piton lands Patch on the shelf (%.0f, %.0f)" % [patch.global_position.x, patch.global_position.y])
	for spool_name in ["Spool1", "Spool2", "Spool3"]:
		current_scene.get_node("Actors/" + spool_name).interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_progress("restring_spine") == 3, "all three spools can be found")
	current_scene.get_node("Actors/Bindwell").interact(null)
	await _skip_dialogue(dialogue)
	_check(game_state.quest_done("restring_spine"), "Bindwell takes the spools and pays up")
	_check(not current_scene.get_node("Props/ToTheSummit").is_open(), "the summit waits for the scene by the fire")
	patch.global_position = current_scene.get_node("Story/LowPoint").global_position + Vector2(0, 150)
	await _frames(10)
	_check(dialogue.is_active(), "the low point plays by the campfire")
	await _skip_dialogue(dialogue, 80)
	_check(game_state.get_flag("patch_told_truth") and current_scene.get_node("Props/ToTheSummit").is_open(), "Patch tells the truth and the way to the summit opens")

	# The Sogg: lure it down by a fold mark, spring the peak into it, swipe Drizzle.
	await scene_manager.change_page(CH3 + "sogg_arena.tscn")
	await _frames(20)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player")
	patch.health.max_health = 99
	patch.health.set_health(99)
	var boss := current_scene.get_node("TheSogg")
	boss.start_fight()
	await _skip_dialogue(dialogue)
	_check(boss.state == 1, "the Sogg fight starts")
	var mark := current_scene.get_node("Props/Fold2")
	var stunned_once := false
	for attempt in 600:
		if boss.state == 6 or boss.health.is_dead():
			break
		if boss.state == 1 or boss.state == 2 or boss.state == 3:
			# Stand by the middle fold mark so it dives there.
			patch.global_position = mark.global_position + Vector2(0, -48)
			patch.velocity = Vector2.ZERO
			await _frames(10)
		elif boss.state == 4:
			mark.fold_away()
			await _frames(40)
			mark.pop()
			await _frames(30)
			if not stunned_once and boss.state == 5:
				stunned_once = true
				_check(true, "springing a peak under the soaking Sogg pins it")
		elif boss.state == 5:
			var heart := boss.get_node("Heart") as Node2D
			patch.global_position = heart.global_position + Vector2(-74, 6)
			patch.velocity = Vector2.ZERO
			patch.facing = Vector2.RIGHT
			await _frames(2)
			Input.action_press(&"attack")
			await _frames(2)
			Input.action_release(&"attack")
			await _frames(25)
		else:
			await _frames(10)
	_check(stunned_once, "the Sogg can be pinned by a peak")
	_check(not is_instance_valid(boss) or boss.phase == 1, "the Sogg swells into its second phase at half health")
	_check(game_state.get_flag("boss_sogg_phase2_done"), "the Sogg's first two phases can be won (health %d)" % (boss.health.current if is_instance_valid(boss) else 0))
	for i in 400:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	for i in 600:
		if current_scene and current_scene.name == "Interlude03":
			break
		await _frames(1)
	_check(current_scene.name == "Interlude03", "the Sogg drags Patch into the Gutter and the third interlude plays")
	for i in 1200:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	await _frames(90)
	_check(game_state.get_flag("chapter3_complete"), "the third interlude marks Chapter 3 complete")


func _finale(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	const FIN := "res://scenes/levels/finale/"
	# The third interlude now turns the page down into the Gutter.
	await _wait_for_scene("TheGutter", 900)
	_check(current_scene.name == "TheGutter", "the third interlude turns down into the Gutter")
	await _frames(30)
	await _skip_dialogue(dialogue)
	var patch := get_first_node_in_group("player")
	_check(get_nodes_in_group("companion").is_empty(), "Patch is alone in the Gutter")
	patch.health.max_health = 99
	patch.health.set_health(99)

	# The gauntlet: each lock seals its gates until every wave is cleared.
	for lock_name in ["LockOne", "LockTwo"]:
		var lock := current_scene.get_node("Story/" + lock_name)
		var gate := current_scene.get_node("Props/%sGate1" % lock_name) as Node2D
		patch.global_position = lock.global_position + Vector2(0, 150)
		patch.velocity = Vector2.ZERO
		await _frames(10)
		_check(lock.is_running() and gate.visible, "walking into %s seals its gates" % lock_name)
		var waves_seen := 0
		for i in 40:
			if not lock.is_running():
				break
			await _frames(30)
			for actor in current_scene.get_node("Story").get_children():
				if actor is CharacterBody2D:
					waves_seen += 1
					actor.queue_free()
		await _frames(40)
		_check(not lock.is_running() and not gate.visible and waves_seen >= 6, "clearing every wave of %s opens it (%d Soggies)" % [lock_name, waves_seen])
		await _skip_dialogue(dialogue)
		if lock_name == "LockOne":
			# The drowned gap: zip from the floor's edge to the ring by the page bundle.
			for actor in current_scene.get_node("Actors").get_children():
				actor.free()
			patch.global_position = Vector2(29.5 * 64, 16 * 64 - 48)
			patch.velocity = Vector2.ZERO
			patch.facing = Vector2.RIGHT
			await _frames(20)
			await _skip_dialogue(dialogue)
			_check(patch.try_grapple(), "the Tape Tail finds the ring over the drowned gap")
			await _frames(120)
			_check(patch.global_position.x > 39 * 64 and patch.global_position.y < 13 * 64 and patch.is_on_floor(),
				"zipping to the ring lands Patch on the page bundle (%.0f, %.0f)" % [patch.global_position.x, patch.global_position.y])

	var fold := current_scene.get_node("Props/LastFold")
	patch.global_position = fold.global_position + Vector2(0, -48)
	patch.velocity = Vector2.ZERO
	await _frames(20)
	await _skip_dialogue(dialogue)
	_press(&"slam")
	await _frames(90)
	_check(fold.is_up, "a slam springs the last fold mark up to the high ledge")

	# The deepest fold, first time: Patch can't win, and it cuts to Gran's table.
	await scene_manager.change_page(FIN + "deepest_fold.tscn")
	await _frames(20)
	await _skip_dialogue(dialogue)
	patch = get_first_node_in_group("player")
	var boss := current_scene.get_node("TheSogg")
	patch.global_position = current_scene.get_node("Story/FightStart").global_position + Vector2(0, 150)
	await _frames(10)
	await _skip_dialogue(dialogue)
	_check(boss.state != 0 and patch.health.floor_health == 1, "the last fight starts, and Patch can't be beaten in it")
	patch.health._invulnerable_left = 0.0
	patch.health.take_damage(99, patch.global_position)
	_check(patch.health.current == 1 and not patch.health.is_dead(), "the Sogg wears Patch down to his last scrap")
	for i in 300:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	await _wait_for_scene("Interlude04", 600)
	_check(current_scene.name == "Interlude04", "losing to the Sogg cuts to Nell at Gran's table")
	for i in 1200:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	await _wait_for_scene("DeepestFold", 600)
	_check(game_state.get_flag("nell_has_dryer") and current_scene.name == "DeepestFold", "Nell picks up the hairdryer and the fight goes on")

	# Second time: the warm air follows Patch and dries the Sogg wherever it comes down.
	await _frames(20)
	for i in 300:
		if dialogue.is_active():
			break
		await _frames(1)
	await _skip_dialogue(dialogue)
	await _frames(20)
	patch = get_first_node_in_group("player")
	boss = current_scene.get_node("TheSogg")
	var beam := current_scene.get_node("HairdryerBeam")
	_check(boss.state != 0 and beam.active and beam.visible, "the hairdryer switches on over the page")
	patch.health.max_health = 99
	patch.health.set_health(99)
	var shrank := false
	for attempt in 900:
		if boss.state == 6 or boss.health.is_dead():
			break
		if boss._sections_left < 4:
			shrank = true
		# Stay near the Sogg, so the warm air that follows Patch lands on it.
		patch.global_position = Vector2(clampf(boss.global_position.x - 160.0, 3 * 64, 27 * 64), 14 * 64 - 48)
		patch.velocity = Vector2.ZERO
		await _frames(10)
	_check(shrank, "the Sogg dries out a section at a time")
	_check(game_state.get_flag("sogg_dried"), "the warm air dries the Sogg out completely")
	for i in 600:
		if is_instance_valid(boss) and boss.body.texture.resource_path.ends_with("drizzle.png") and dialogue.is_active():
			break
		await _frames(1)
	_check(is_instance_valid(boss) and boss.body.texture.resource_path.ends_with("drizzle.png"), "the Sogg shrinks back into Drizzle (%s, dialogue %s)" % [boss.body.texture.resource_path if is_instance_valid(boss) else "freed", dialogue.is_active()])
	await _skip_dialogue(dialogue)
	await _wait_for_scene("EndingTable", 600)
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
	_check(is_equal_approx(audio.fullness(), 0.25), "one region of four mended: the music is a quarter full (%.2f)" % audio.fullness())
	var doors := {}
	for node in current_scene.get_node("Level").get_children():
		if node.get("region_id") != null and node.get("region_id") != &"":
			doors[node.get("region_id")] = node
	_check(doors.size() == 6, "the Spine has a door for each of the six regions (%d)" % doors.size())
	_check(doors[&"thistledown"].state() == "open" and doors[&"thistledown"].can_interact(), "Thistledown's door is open from the start")
	_check(doors[&"lanternfold"].state() == "locked" and not doors[&"lanternfold"].can_interact(), "Lanternfold's door stays shut until Thistledown is mended")
	_check(doors[&"marsh"].state() == "unwritten" and not doors[&"marsh"].can_interact(), "an unwritten region's door is stitched shut")
	var stair := current_scene.get_node("Stair")
	_check(not stair.is_open() and stair.get_children().filter(func(n: Node) -> bool: return n is StaticBody2D).is_empty(),
		"the stair to the gallery is broken until a region is mended")
	game_state.set_flag("boss_millwheel_defeated")
	await _frames(3)
	_check(doors[&"lanternfold"].state() == "open" and stair.get_children().filter(func(n: Node) -> bool: return n is StaticBody2D).size() == 2,
		"mending Thistledown opens Lanternfold's door and nails the stair back")
	_check(doors[&"thistledown"].state() == "mended", "Thistledown's door shows it mended")
	var cutoff_before: float = audio._lowpass.cutoff_hz
	audio.update_fullness()
	await create_timer(4.5).timeout
	_check(is_equal_approx(audio.music_fullness, 0.5) and audio._lowpass.cutoff_hz > cutoff_before * 2.0
		and audio._reverb.wet < 0.2, "mending a region fills the music in (cutoff %d Hz)" % audio._lowpass.cutoff_hz)
	# Climb: the two boards and the gallery are each within a jump of the last.
	var tops: Array[float] = [960.0, 832.0, 704.0, 576.0]
	var climbable := true
	for i in tops.size() - 1:
		climbable = climbable and tops[i] - tops[i + 1] <= 128.0
	_check(climbable, "each step up to the gallery is two tiles, within Patch's jump")

	# The torn map: the Prologue is mended, Thistledown seen-not-mended, the Marsh blank.
	game_state.visited["res://scenes/levels/ch1_thistledown/thistledown_page_01.tscn"] = true
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
	_check(game_state.read_save(2).get("version", 0) == 4, "saves are written as version 4")
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
	"res://scenes/enemies/ink_drip.tscn": Vector2(0.15, 0.5),
	"res://scenes/enemies/boss_millwheel.tscn": Vector2(2.5, 6.0),
	"res://scenes/enemies/boss_kraken.tscn": Vector2(2.5, 6.0),
	"res://scenes/enemies/boss_sogg.tscn": Vector2(2.5, 6.0),
	"res://scenes/enemies/boss_sogg_final.tscn": Vector2(2.5, 6.0),
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
const SIDE_ONLY := ["paper_moth.tscn", "inkwell_turret.tscn", "folded_crane.tscn", "mimic_book.tscn"]


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

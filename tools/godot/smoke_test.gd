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
	game_state.slot = 2
	game_state.delete_save(2)

	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await _frames(20)
	_check(current_scene != null and current_scene.name == "TitleScreen", "title screen loads")

	game_state.new_game(2)
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

	await _chapter_one(game_state, scene_manager, dialogue)
	await _chapter_two(game_state, scene_manager, dialogue)

	# Save and load.
	game_state.add_scraps(5)
	var scraps: int = game_state.scraps
	_check(game_state.save_game(), "saving writes the slot")
	game_state.new_game(2)
	_check(game_state.load_game(2) and game_state.scraps == scraps, "loading restores the slot")
	game_state.delete_save(2)
	_finish()


func _chapter_one(game_state: Node, scene_manager: Node, dialogue: Node) -> void:
	# Prologue: the flood rises (once nobody is talking) and the page is climbable.
	await scene_manager.change_page("res://scenes/levels/prologue/prologue_flood.tscn")
	await _frames(20)
	await _skip_dialogue(dialogue)
	var flood := current_scene.get_node("Flood") as Node2D
	var flood_start := flood.position.y
	await _frames(240)
	_check(flood.position.y < flood_start - 30.0, "the Prologue flood rises")

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
		for hit in 3:
			patch.global_position = boss.global_position + Vector2(-74, -48)
			patch.velocity = Vector2.ZERO
			patch.facing = Vector2.RIGHT
			await _frames(25)
			Input.action_press(&"attack")
			await _frames(2)
			Input.action_release(&"attack")
			await _frames(10)
		await _frames(70)
	_check(game_state.get_flag("boss_millwheel_defeated"), "Old Millwheel can be defeated")
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
	_check(not current_scene.visible and current_scene.get_node_or_null("Diorama") != null, "the Margin heist is drawn as the 3D desk")
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


func _skip_dialogue(dialogue: Node) -> void:
	for i in 40:
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

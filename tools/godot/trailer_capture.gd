extends "res://tools/godot/smoke_test.gd"
## Trailer footage: Patch fighting through each region, played by script.
## Run with Godot's Movie Maker under a display, for example:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 \
##     --fixed-fps 30 --write-movie /tmp/trailer.avi -s tools/godot/trailer_capture.gd
## The frames each clip starts and ends on (<name>, <name>_end) are written to user://trailer_marks.txt, so
## tools/video/cut_trailer.py can cut the clips out without the loading frames.

const L := "res://scenes/levels/"
var _marks: Array[String] = []


func _mark(clip: String) -> void:
	_marks.append("%s %d" % [clip, Engine.get_frames_drawn()])


func _clean_ui() -> void:
	root.get_node("DialogueUI").visible = false
	for n in root.find_children("*", "", true, false):
		if n.get_script() and n.get_script().get_global_name() == &"TitleCard":
			n.visible = false


func _go(page: String) -> CharacterBody2D:
	await root.get_node("SceneManager").change_page(page)
	await _frames(30)
	await _skip_dialogue(root.get_node("DialogueUI"))
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(9000.0)
	_clean_ui()
	return patch


func _tap(action: StringName, hold := 2) -> void:
	Input.action_press(action)
	await _frames(hold)
	Input.action_release(action)


## Patch walks for `seconds` toward `dir`, jumping now and then.
func _walk(dir: StringName, seconds: float) -> void:
	Input.action_press(dir)
	var t := 0.0
	while t < seconds:
		_clean_ui()
		if fmod(t, 1.6) < 0.04:
			await _tap(&"jump", 8)
		await _frames(1)
		t += 1.0 / 30.0
	Input.action_release(dir)


## A scripted fight: close in, cut, sometimes dash through or slam, for `seconds`.
func _fight(boss: Node2D, patch: CharacterBody2D, seconds: float) -> void:
	var t := 0.0
	var beat := 0
	while t < seconds:
		_clean_ui()
		var dx := boss.global_position.x - patch.global_position.x
		var dir := &"move_right" if dx > 0 else &"move_left"
		if absf(dx) > 260.0:
			Input.action_press(dir)
			await _frames(6)
			Input.action_release(dir)
		else:
			beat += 1
			patch.facing = Vector2.RIGHT if dx > 0 else Vector2.LEFT
			match beat % 7:
				3:
					await _tap(&"heavy", 14)
				5:
					await _tap(&"dash", 2)
				6:
					await _tap(&"jump", 6)
					await _frames(8)
					await _tap(&"attack")
				_:
					await _tap(&"attack")
			await _frames(7)
		t += 0.3
		# Keep the boss standing: the trailer shows the fight, not the ending.
		if "health" in boss and boss.health.current <= 3:
			boss.health.current = boss.health.max_health / 2
		patch.health.grant_invulnerability(9000.0)


func _boss(page: String, boss_name: String, seconds: float, dx := -380.0) -> void:
	var patch := await _go(page)
	var boss := current_scene.find_child(boss_name, true, false) as Node2D
	if dx != 0.0:
		patch.global_position = Vector2(boss.global_position.x + dx, patch.global_position.y - 120)
		patch.velocity = Vector2.ZERO
	await _frames(20)
	if boss.has_method("start_fight"):
		boss.start_fight()
	await _skip_dialogue(root.get_node("DialogueUI"))
	await _frames(10)
	_mark(boss_name)
	await _fight(boss, patch, seconds)
	_mark(boss_name + "_end")


func _run() -> void:
	# The trailer lays its own music over the footage, so the game's music stays silent.
	var music := AudioServer.get_bus_index(&"Music")
	if music >= 0:
		AudioServer.set_bus_mute(music, true)
	var gs := root.get_node("GameState")
	gs.slot = 3
	gs.delete_save(3)
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await _frames(20)
	gs.new_game(3)
	for a in [&"crease_swipe", &"pop_up_slam", &"frog_fold", &"paper_plane", &"tape_tail", &"blot_dive", &"fold_dash", &"bookmark_warp"]:
		gs.unlock_ability(a)
	gs.max_health = 24
	gs.health = 20
	await _go(L + "thistledown/1_1_sodden_fields.tscn")
	await _frames(20)
	_mark("SoddenFields")
	await _walk(&"move_right", 7.0)
	_mark("SoddenFields_end")
	await _go(L + "hub/spine_hub.tscn")
	await _frames(10)
	_mark("SpineHub")
	await _walk(&"move_right", 4.0)
	_mark("SpineHub_end")
	await _boss(L + "thistledown/boss_mill_floor.tscn", "OldMillwheel", 7.0, -420.0)
	await _boss(L + "lanternfold/boss_ink_deep.tscn", "BlotchKraken", 6.0, -520.0)
	await _boss(L + "marsh/heronry.tscn", "GreyHeron", 6.0)
	await _boss(L + "peaks/bindwell_workshop.tscn", "Bindwell", 6.0)
	await _boss(L + "fair/the_big_top.tscn", "Barker", 6.0)
	await _boss(L + "index/the_last_entry.tscn", "Redactor", 6.0)
	await _boss(L + "finale/f_2_the_deepest_fold.tscn", "TheSogg", 8.0, -1050.0)
	_mark("End")
	var f := FileAccess.open("user://trailer_marks.txt", FileAccess.WRITE)
	f.store_string("\n".join(_marks))
	gs.delete_save(3)
	_finish()

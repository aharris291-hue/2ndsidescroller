extends "res://tools/godot/smoke_test.gd"

## Store screenshots: one per region and boss, HUD on, captions and title cards off.
## Needs a real renderer, so run it under a display (xvfb-run on Linux):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 -s tools/godot/store_shots.gd
## PNGs land in user://store_shots/; docs/store/screenshots holds the current set as JPGs.
const OUTDIR := "user://store_shots/"
const L := "res://scenes/levels/"

func _shot(name: String) -> void:
	root.get_node("DialogueUI").visible = false
	for n in root.find_children("*", "", true, false):
		if n.get_script() and n.get_script().get_global_name() == &"TitleCard":
			n.visible = false
	await _frames(2)
	await RenderingServer.frame_post_draw
	get_root().get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTDIR) + name + ".png")
	root.get_node("DialogueUI").visible = true

func _go(page: String) -> CharacterBody2D:
	await root.get_node("SceneManager").change_page(page)
	await _frames(30)
	await _skip_dialogue(root.get_node("DialogueUI"))
	var patch := get_first_node_in_group("player") as CharacterBody2D
	patch.health.grant_invulnerability(900.0)
	return patch

func _swing(patch: CharacterBody2D, face: Vector2) -> void:
	patch.facing = face
	Input.action_press(&"attack")
	await _frames(2)
	Input.action_release(&"attack")

func _boss(page: String, boss_name: String, shot: String, dx := -380.0, wait := 1.4) -> void:
	var patch := await _go(page)
	var boss := current_scene.find_child(boss_name, true, false) as Node2D
	if boss == null:
		print("no boss ", boss_name)
		return
	if dx != 0.0:
		patch.global_position = Vector2(boss.global_position.x + dx, patch.global_position.y - 120)
	patch.velocity = Vector2.ZERO
	await _frames(30)
	if boss.has_method("start_fight"):
		boss.start_fight()
	await _skip_dialogue(root.get_node("DialogueUI"))
	await create_timer(wait).timeout
	await _skip_dialogue(root.get_node("DialogueUI"))
	await _swing(patch, Vector2.RIGHT if dx < 0 else Vector2.LEFT)
	await create_timer(0.12).timeout
	await _shot(shot)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTDIR))
	var gs := root.get_node("GameState")
	gs.slot = 3
	gs.delete_save(3)
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await _frames(40)
	gs.new_game(3)
	for a in [&"crease_swipe", &"pop_up_slam", &"frog_fold", &"paper_plane", &"tape_tail", &"blot_dive", &"fold_dash", &"bookmark_warp"]:
		gs.unlock_ability(a)
	gs.max_health = 24
	gs.health = 18
	var patch := await _go(L + "thistledown/1_1_sodden_fields.tscn")
	patch.global_position.x += 700
	await create_timer(1.0).timeout
	await _shot("01_sodden_fields")
	await _go(L + "hub/spine_hub.tscn")
	await create_timer(1.0).timeout
	await _shot("02_spine_hub")
	await _boss(L + "thistledown/boss_mill_floor.tscn", "OldMillwheel", "03_millwheel", -420.0)
	await _boss(L + "lanternfold/boss_ink_deep.tscn", "BlotchKraken", "04_kraken", -520.0)
	await _boss(L + "marsh/heronry.tscn", "GreyHeron", "05_heron")
	await _boss(L + "peaks/bindwell_workshop.tscn", "Bindwell", "06_bindwell")
	await _boss(L + "fair/the_big_top.tscn", "Barker", "07_barker")
	await _boss(L + "index/the_last_entry.tscn", "Redactor", "08_redactor")
	await _boss(L + "finale/f_2_the_deepest_fold.tscn", "TheSogg", "09_sogg", -1050.0, 0.9)
	gs.delete_save(3)
	_finish()

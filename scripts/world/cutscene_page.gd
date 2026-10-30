class_name CutscenePage
extends Control
## A still storybook scene (the real world, or a title card) that plays one conversation
## from data/dialogue and then turns to the next page. Used for the Prologue opening and
## the interlude at Gran's table between chapters.

@export var conversation_id := ""
@export_multiline var title_caption := ""
@export_file("*.tscn") var next_page := ""
## Story flag set when the cutscene finishes, e.g. "chapter1_complete".
@export var sets_flag := ""
@export var music: AudioStream
## Cutscenes happen in the real world, outside the book, so they fill the screen.
@export var in_book := false
## Save the game when this cutscene finishes (chapter ends).
@export var save_on_finish := false

@onready var background: TextureRect = $Background
@onready var title_label: Label = $TitleLabel


func _ready() -> void:
	GameState.in_gameplay = false
	HUD.show_hud(false)
	if music:
		AudioManager.play_music(music)
	title_label.text = title_caption
	title_label.modulate.a = 0.0
	# A slow push-in on the illustration, like a page being read.
	background.pivot_offset = background.size / 2.0
	var zoom := create_tween()
	zoom.tween_property(background, "scale", Vector2(1.06, 1.06), 14.0).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.6).timeout
	if not title_caption.is_empty():
		var fade := create_tween()
		fade.tween_property(title_label, "modulate:a", 1.0, 0.8)
		fade.tween_interval(2.2)
		fade.tween_property(title_label, "modulate:a", 0.0, 0.8)
		await fade.finished
	if not conversation_id.is_empty():
		DialogueUI.start(conversation_id)
		await EventBus.dialogue_finished
	_finish()


func _finish() -> void:
	if not sets_flag.is_empty():
		GameState.set_flag(sets_flag)
	if save_on_finish:
		GameState.save_game()
	if not next_page.is_empty():
		SceneManager.change_page(next_page)
	else:
		SceneManager.go_to_title()

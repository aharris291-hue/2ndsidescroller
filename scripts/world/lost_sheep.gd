class_name LostSheep
extends Interactable
## One of Shepherd Fluff's sheep, swollen and grumpy from the damp. Talking to it
## sends it trotting home and counts toward the "lost_flock" quest.

@export var quest_id := "lost_flock"
@export_multiline var found_caption := "The sheep gave a soggy \"baa\" and trotted off home."

@onready var sprite: Sprite2D = $Sprite2D
var _time := randf() * TAU
var _found := false


func _ready() -> void:
	prompt_text = "Shoo home"
	super._ready()
	if GameState.is_collected(_unique_id()):
		queue_free()


func _process(delta: float) -> void:
	super._process(delta)
	_time += delta * 1.5
	sprite.rotation = sin(_time) * 0.04


func can_interact() -> bool:
	return not _found


func interact(_player: Patch) -> void:
	_found = true
	GameState.mark_collected(_unique_id())
	var all_found := GameState.advance_quest(quest_id)
	AudioManager.play_sfx(&"voice_blip", 0.6)
	var caption := found_caption
	if all_found:
		caption += " That's the whole flock! Shepherd Fluff will want to hear."
	else:
		caption += " (%d/%d found)" % [GameState.quest_progress(quest_id), GameState.quest_goal(quest_id)]
	DialogueUI.narrate(caption)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(-1, 1), 0.15)
	tween.tween_property(self, "position:x", position.x - 400.0, 1.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.2)
	tween.tween_callback(queue_free)


func _unique_id() -> String:
	return "%s:%s" % [owner.scene_file_path if owner else "", get_path()]

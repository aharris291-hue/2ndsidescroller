class_name FestivalLantern
extends Interactable
## A paper lantern for Lanternfold's festival. The damp put them all out; lighting
## one counts toward the Lamplighter Sisters' "festival_lanterns" quest.

const TEXTURE_OFF := preload("res://assets/art/props/lantern_off.png")
const TEXTURE_ON := preload("res://assets/art/props/lantern_on.png")

@export var quest_id := "festival_lanterns"

var is_lit := false
var _time := randf() * TAU

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	prompt_text = "Light"
	super._ready()
	is_lit = GameState.is_collected(_unique_id())
	sprite.texture = TEXTURE_ON if is_lit else TEXTURE_OFF


func _process(delta: float) -> void:
	super._process(delta)
	_time += delta * (2.0 if is_lit else 0.8)
	sprite.rotation = sin(_time) * (0.03 if is_lit else 0.01)


func can_interact() -> bool:
	return not is_lit


func interact(_player: Patch) -> void:
	is_lit = true
	GameState.mark_collected(_unique_id())
	sprite.texture = TEXTURE_ON
	AudioManager.play_sfx(&"checkpoint", 1.2)
	var all_lit := GameState.advance_quest(quest_id)
	if all_lit:
		DialogueUI.narrate("Every lantern in Lanternfold was glowing again. The Lamplighter Sisters would want to hear.")
	else:
		DialogueUI.narrate("The lantern caught and glowed. (%d/%d lit)" % [GameState.quest_progress(quest_id), GameState.quest_goal(quest_id)])
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.1)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _unique_id() -> String:
	return "%s:%s" % [owner.scene_file_path if owner else "", get_path()]

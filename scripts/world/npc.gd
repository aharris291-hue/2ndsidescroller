class_name NPC
extends Interactable
## A character Patch can talk to. Conversations live in data/dialogue/*.json.
## After the first talk, repeat_dialogue_id is used (if set) and first_talk_flag is set.
##
## Quest givers: set quest_id and the NPC picks its conversation from the quest's state:
## dialogue_id to start it, quest_progress_dialogue while it's under way,
## quest_turn_in_dialogue when the goal is met (completing it), then repeat_dialogue_id.

const COMPANION_SCENE := preload("res://scenes/world/dot_companion.tscn")

@export var dialogue_id := ""
@export var repeat_dialogue_id := ""
## Story flag set after the first conversation, e.g. "met_shepherd_fluff".
@export var first_talk_flag := ""
@export var idle_bob := 4.0
## After the first conversation this NPC leaves the page and follows Patch (Dot).
@export var joins_as_companion := false
## The follower that replaces this NPC when it joins.
@export var companion_scene: PackedScene = COMPANION_SCENE

@export_group("Quest")
@export var quest_id := ""
@export var quest_progress_dialogue := ""
@export var quest_turn_in_dialogue := ""

@onready var _sprite: Node2D = get_node_or_null("Sprite2D")
var _time := randf() * TAU


func _ready() -> void:
	prompt_text = "Talk"
	super._ready()
	if joins_as_companion and not first_talk_flag.is_empty() and GameState.get_flag(first_talk_flag):
		queue_free()


func _process(delta: float) -> void:
	super._process(delta)
	if _sprite:
		_time += delta * 2.0
		_sprite.position.y = -absf(sin(_time)) * idle_bob


func interact(_player: Patch) -> void:
	var talk_id := _pick_dialogue()
	DialogueUI.start(talk_id)
	if not first_talk_flag.is_empty():
		GameState.set_flag(first_talk_flag)
	if joins_as_companion:
		await EventBus.dialogue_finished
		var companion := companion_scene.instantiate() as Node2D
		companion.global_position = global_position + Vector2(0, -60)
		get_parent().add_child(companion)
		queue_free()


func _pick_dialogue() -> String:
	if not quest_id.is_empty():
		if not GameState.quest_started(quest_id):
			GameState.start_quest(quest_id)
			return dialogue_id
		if GameState.quest_done(quest_id):
			return repeat_dialogue_id if not repeat_dialogue_id.is_empty() else dialogue_id
		if GameState.quest_progress(quest_id) >= GameState.quest_goal(quest_id):
			GameState.complete_quest(quest_id)
			return quest_turn_in_dialogue
		return quest_progress_dialogue
	var met: bool = not first_talk_flag.is_empty() and GameState.get_flag(first_talk_flag)
	if met and not repeat_dialogue_id.is_empty():
		return repeat_dialogue_id
	return dialogue_id

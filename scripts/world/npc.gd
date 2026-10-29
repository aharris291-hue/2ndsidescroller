class_name NPC
extends Interactable
## A character Patch can talk to. Conversations live in data/dialogue/*.json.
## After the first talk, repeat_dialogue_id is used (if set) and first_talk_flag is set.

@export var dialogue_id := ""
@export var repeat_dialogue_id := ""
## Story flag set after the first conversation, e.g. "met_shepherd_fluff".
@export var first_talk_flag := ""
@export var idle_bob := 4.0

@onready var _sprite: Node2D = get_node_or_null("Sprite2D")
var _time := randf() * TAU


func _ready() -> void:
	prompt_text = "Talk"
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	if _sprite:
		_time += delta * 2.0
		_sprite.position.y = -absf(sin(_time)) * idle_bob


func interact(_player: Patch) -> void:
	var talk_id := dialogue_id
	var met: bool = not first_talk_flag.is_empty() and GameState.get_flag(first_talk_flag)
	if met and not repeat_dialogue_id.is_empty():
		talk_id = repeat_dialogue_id
	DialogueUI.start(talk_id)
	if not first_talk_flag.is_empty():
		GameState.set_flag(first_talk_flag)

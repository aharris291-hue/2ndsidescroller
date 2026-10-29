class_name DialogueTrigger
extends Area2D
## Starts a conversation the first time Patch walks into this area.

@export var dialogue_id := ""
## Story flag that marks this trigger as used. Defaults to "seen:<dialogue_id>".
@export var once_flag := ""


func _ready() -> void:
	if once_flag.is_empty():
		once_flag = "seen:" + dialogue_id
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Patch and not GameState.get_flag(once_flag) and not DialogueUI.is_active():
		GameState.set_flag(once_flag)
		DialogueUI.start(dialogue_id)

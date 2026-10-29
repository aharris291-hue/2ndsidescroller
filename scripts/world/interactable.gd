class_name Interactable
extends Area2D
## Base for anything Patch can use with the Interact button: NPCs, pull-tabs, doors.
## Shows a small prompt while Patch is close. Subclasses override interact().
##
## Collision setup: layer "interactables" (6) so Patch's InteractArea finds it,
## mask "player" (2) so the prompt knows when he's near.

@export var prompt_text := "Interact"
@export var prompt_offset := Vector2(0, -110)

var _prompt: Label
var _player_near := false


func _ready() -> void:
	_prompt = Label.new()
	_prompt.text = "%s  [%s]" % [prompt_text, InputGlyphs.interact_hint()]
	_prompt.theme_type_variation = &"PromptLabel"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(240, 40)
	_prompt.position = prompt_offset - Vector2(120, 20)
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func can_interact() -> bool:
	return true


func interact(_player: Patch) -> void:
	pass


func _process(_delta: float) -> void:
	_prompt.visible = _player_near and can_interact() and not DialogueUI.is_active()


func _on_body_entered(body: Node2D) -> void:
	if body is Patch:
		_player_near = true
		_prompt.text = "%s  [%s]" % [prompt_text, InputGlyphs.interact_hint()]


func _on_body_exited(body: Node2D) -> void:
	if body is Patch:
		_player_near = false

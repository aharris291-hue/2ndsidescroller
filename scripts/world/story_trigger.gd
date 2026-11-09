class_name StoryTrigger
extends Area2D
## One-time story beat for text-map levels: when Patch walks into it, it shows a
## narrator caption, starts a conversation, and/or calls a method on the page.
## It sizes its own shape (`size`, standing on its origin), so a map can place it.

@export_multiline var caption := ""
@export var dialogue_id := ""
## Method called on the page (this trigger's owner), e.g. "lights_out".
@export var page_method := ""
@export var size := Vector2(128, 256)
## Only fires once this flag is set (empty = no condition).
@export var requires_flag := ""
## A story flag set when it fires, e.g. "patch_told_truth".
@export var sets_flag := ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _flag() -> String:
	return "story:%s:%s" % [owner.scene_file_path if owner else "", name]


func _on_body_entered(body: Node2D) -> void:
	if not body is Patch or GameState.get_flag(_flag()):
		return
	if not requires_flag.is_empty() and not GameState.get_flag(requires_flag):
		return
	GameState.set_flag(_flag())
	if not sets_flag.is_empty():
		GameState.set_flag(sets_flag)
	if not caption.is_empty():
		var text := caption
		for action in [&"jump", &"attack", &"heavy", &"guard", &"mend", &"dash", &"grapple", &"slam", &"warp", &"interact"]:
			text = text.replace("{%s}" % action, InputGlyphs.hint(action))
		DialogueUI.narrate(text)
	if not dialogue_id.is_empty() and not DialogueUI.is_active():
		DialogueUI.start(dialogue_id)
	if not page_method.is_empty() and owner and owner.has_method(page_method):
		owner.call_deferred(page_method)

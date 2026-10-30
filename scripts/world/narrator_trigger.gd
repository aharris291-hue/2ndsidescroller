class_name NarratorTrigger
extends Area2D
## Shows a narrator caption the first time Patch walks through. Used for tutorials
## and story beats. "{jump}", "{attack}", "{dash}", "{grapple}", "{slam}" and "{interact}" become button names.

@export_multiline var caption := ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var flag := "narrated:%s:%s" % [owner.scene_file_path if owner else "", name]
	if body is Patch and not GameState.get_flag(flag):
		GameState.set_flag(flag)
		var text := caption
		for action in [&"jump", &"attack", &"dash", &"grapple", &"slam", &"interact"]:
			text = text.replace("{%s}" % action, InputGlyphs.hint(action))
		DialogueUI.narrate(text)

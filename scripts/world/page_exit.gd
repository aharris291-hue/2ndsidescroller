class_name PageExit
extends Area2D
## Walking (or falling) into this area turns to another page, with no button press.
## Used where the way on is a drop, a collapse or the edge of a page.

@export_file("*.tscn") var target_page := ""
@export var target_spawn: StringName = &""
## Story flag that must be set first (empty = always open).
@export var requires_flag := ""
@export var size := Vector2(128, 256)
## The way down to the Gutter (4-5's summit): open only once every region of the book
## is mended (BookMap.torn_regions). Until then, walking in narrates `closed_caption`
## and turns to `fallback_page` instead.
@export var requires_whole_book := false
@export var closed_caption := ""
@export_file("*.tscn") var fallback_page := ""
@export var fallback_spawn: StringName = &""


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


func _on_body_entered(body: Node2D) -> void:
	if not body is Patch or target_page.is_empty() or SceneManager.is_transitioning:
		return
	if not requires_flag.is_empty() and not GameState.get_flag(requires_flag):
		return
	if requires_whole_book and not BookMap.torn_regions().is_empty():
		if not closed_caption.is_empty():
			DialogueUI.narrate(closed_caption.replace("{torn}", _listed(BookMap.torn_regions())))
		if not fallback_page.is_empty():
			SceneManager.change_page(fallback_page, fallback_spawn)
		return
	SceneManager.change_page(target_page, target_spawn)


static func _listed(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]

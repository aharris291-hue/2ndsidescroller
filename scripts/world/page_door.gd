class_name PageDoor
extends Interactable
## A folded page corner that leads to another page, or out into the Margin.

@export_file("*.tscn") var target_page := ""
## Name of the Marker2D (in "spawn_points") where Patch appears on the target page.
@export var target_spawn: StringName = &""
@export var door_prompt := "Step through"
## Story flag that must be set before the door appears (empty = always open).
@export var requires_flag := ""


func _ready() -> void:
	prompt_text = door_prompt
	super._ready()


func _process(delta: float) -> void:
	# Flag-gated doors show themselves once unlocked (bosses hide their own exits).
	if not requires_flag.is_empty():
		visible = is_open()
	super._process(delta)


func is_open() -> bool:
	return requires_flag.is_empty() or GameState.get_flag(requires_flag)


func can_interact() -> bool:
	return is_open() and not target_page.is_empty() and not SceneManager.is_transitioning


func interact(_player: Patch) -> void:
	SceneManager.change_page(target_page, target_spawn)

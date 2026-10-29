class_name PageDoor
extends Interactable
## A folded page corner that leads to another page, or out into the Margin.

@export_file("*.tscn") var target_page := ""
## Name of the Marker2D (in "spawn_points") where Patch appears on the target page.
@export var target_spawn: StringName = &""
@export var door_prompt := "Step through"


func _ready() -> void:
	prompt_text = door_prompt
	super._ready()


func can_interact() -> bool:
	return not target_page.is_empty() and not SceneManager.is_transitioning


func interact(_player: Patch) -> void:
	SceneManager.change_page(target_page, target_spawn)

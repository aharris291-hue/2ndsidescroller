extends Page
## P-1 The Shelf at Midnight. Patch shows off to Drizzle along a lamp-lit shelf. At the
## far end the lamps go out one by one, ink starts to drip, and the shelf gives way
## under him (into P-2).

@export var dark_tint := Color(0.32, 0.34, 0.46)

var _lights_out := false


func _ready() -> void:
	super._ready()
	if GameState.get_flag("p1_lights_out"):
		_set_dark(true)
	for drips in get_tree().get_nodes_in_group(&"midnight_drips"):
		drips.set_physics_process(GameState.get_flag("p1_lights_out"))


## Called by the LightsOut trigger.
func lights_out() -> void:
	if _lights_out:
		return
	_lights_out = true
	GameState.set_flag("p1_lights_out")
	var lamps := get_tree().get_nodes_in_group(&"lamps")
	lamps.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.x > b.global_position.x)
	var tween := create_tween()
	for lamp in lamps:
		tween.tween_callback(lamp.snuff)
		tween.tween_interval(0.35)
	tween.tween_callback(_set_dark.bind(false))
	tween.tween_callback(DialogueUI.start.bind("midnight_dark"))
	await tween.finished
	for drips in get_tree().get_nodes_in_group(&"midnight_drips"):
		drips.set_physics_process(true)


func _set_dark(instant: bool) -> void:
	var atmosphere := _atmosphere()
	if atmosphere == null:
		return
	if instant:
		atmosphere.ambient = dark_tint
		return
	var tween := create_tween()
	tween.tween_property(atmosphere, "ambient", dark_tint, 1.2)
	AudioManager.play_sfx(&"growl", 0.6, -6.0)


func _atmosphere() -> DarkAtmosphere:
	for child in get_children():
		if child is DarkAtmosphere:
			return child
	return null

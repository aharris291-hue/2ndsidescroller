extends Node
## Player preferences (volume, display, comfort and assist options), stored apart from
## save slots in user://settings.cfg.

## Emitted after any setting is applied, so live systems (weather, camera) can follow.
signal changed

const PATH := "user://settings.cfg"

var music_volume := 0.8
var sfx_volume := 0.9
var fullscreen := false
## Show pages as an open book on a desk (BookFrame). Off = flat full-screen page.
var book_view := true
## Camera shake on heavy hits, slams and boss blows.
var screen_shake := true
## Lightning flashes in the rain (off for players sensitive to flashing light).
var flashing := true
## Weather detail: true = full fog, film grain and rain; false = lighter for older GPUs.
var high_effects := true
## Assist: enemy hits take at most half a paper token, for a gentler adventure.
var assist := false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		music_volume = config.get_value("audio", "music_volume", music_volume)
		sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)
		fullscreen = config.get_value("video", "fullscreen", fullscreen)
		book_view = config.get_value("video", "book_view", book_view)
		high_effects = config.get_value("video", "high_effects", high_effects)
		screen_shake = config.get_value("comfort", "screen_shake", screen_shake)
		flashing = config.get_value("comfort", "flashing", flashing)
		assist = config.get_value("comfort", "assist", assist)
	apply()


func apply() -> void:
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	# Headless runs (CI, exports) have no window to change.
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	changed.emit()


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "book_view", book_view)
	config.set_value("video", "high_effects", high_effects)
	config.set_value("comfort", "screen_shake", screen_shake)
	config.set_value("comfort", "flashing", flashing)
	config.set_value("comfort", "assist", assist)
	config.save(PATH)


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply()
	save()


func toggle_book_view() -> void:
	book_view = not book_view
	BookFrame.refresh()
	save()


## Flips one of the on/off options by name ("screen_shake", "flashing", "high_effects",
## "assist"), applies it and saves.
func toggle(option: StringName) -> void:
	set(option, not get(option))
	apply()
	save()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))

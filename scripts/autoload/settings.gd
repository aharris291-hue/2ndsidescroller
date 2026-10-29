extends Node
## Player preferences (volume, fullscreen), stored apart from save slots in user://settings.cfg.

const PATH := "user://settings.cfg"

var music_volume := 0.8
var sfx_volume := 0.9
var fullscreen := false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		music_volume = config.get_value("audio", "music_volume", music_volume)
		sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)
		fullscreen = config.get_value("video", "fullscreen", fullscreen)
	apply()


func apply() -> void:
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	# Headless runs (CI, exports) have no window to change.
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.save(PATH)


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply()
	save()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))

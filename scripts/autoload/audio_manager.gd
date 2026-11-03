extends Node
## Music with crossfades, plus a small pool of sound-effect players.
## Sound effects are addressed by name, e.g. AudioManager.play_sfx(&"jump").

const SFX := {
	&"jump": preload("res://assets/audio/sfx/jump.wav"),
	&"swipe": preload("res://assets/audio/sfx/swipe.wav"),
	&"hurt": preload("res://assets/audio/sfx/hurt.wav"),
	&"pickup": preload("res://assets/audio/sfx/pickup.wav"),
	&"page_flip": preload("res://assets/audio/sfx/page_flip.wav"),
	&"checkpoint": preload("res://assets/audio/sfx/checkpoint.wav"),
	&"tab_pull": preload("res://assets/audio/sfx/tab_pull.wav"),
	&"enemy_pop": preload("res://assets/audio/sfx/enemy_pop.wav"),
	&"voice_blip": preload("res://assets/audio/sfx/voice_blip.wav"),
	&"grapple": preload("res://assets/audio/sfx/grapple.wav"),
	&"slam": preload("res://assets/audio/sfx/slam.wav"),
	&"dryer": preload("res://assets/audio/sfx/dryer.wav"),
	# Dark Rebuild sounds (ElevenLabs Sound Effects).
	&"shears": preload("res://assets/audio/dark/sfx_swing.ogg"),
	&"hit_wet": preload("res://assets/audio/dark/sfx_hit.ogg"),
	&"parry": preload("res://assets/audio/dark/sfx_parry.ogg"),
	&"growl": preload("res://assets/audio/dark/sfx_growl.ogg"),
	&"dissolve": preload("res://assets/audio/dark/sfx_death.ogg"),
}
## Patch's voice (ElevenLabs, voice "Jett"). One line at a time; a new line cuts the old one.
const VOICE := {
	&"light": preload("res://assets/audio/dark/vo_light.ogg"),
	&"effort": preload("res://assets/audio/dark/vo_effort.ogg"),
	&"heavy": preload("res://assets/audio/dark/vo_heavy.ogg"),
	&"hurt": preload("res://assets/audio/dark/vo_hurt.ogg"),
	&"hurt2": preload("res://assets/audio/dark/vo_hurt2.ogg"),
	&"parry": preload("res://assets/audio/dark/vo_parry.ogg"),
	&"finisher": preload("res://assets/audio/dark/vo_finisher.ogg"),
	&"mend": preload("res://assets/audio/dark/vo_mend.ogg"),
	&"death": preload("res://assets/audio/dark/vo_death.ogg"),
	&"dodge": preload("res://assets/audio/dark/vo_dodge.ogg"),
}
## Accessibility (Settings.sound_captions): sounds worth a caption, and its words.
const SOUND_CAPTIONS := {
	&"growl": "Growl",
	&"dissolve": "Ink dissolves",
	&"dryer": "Hair dryer roars",
	&"checkpoint": "Bookmark rings",
	&"page_flip": "Page turns",
	&"parry": "Clang",
	&"slam": "Thud",
	&"enemy_pop": "Something tears",
	&"tab_pull": "Tab pulls",
}
const POOL_SIZE := 10
const FADE_TIME := 0.8

var _music_a := AudioStreamPlayer.new()
var _music_b := AudioStreamPlayer.new()
var _active_music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _voice := AudioStreamPlayer.new()
var _captions: VBoxContainer
## When each caption was last shown, so a burst of the same sound shows one line.
var _caption_shown := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for player in [_music_a, _music_b]:
		player.bus = &"Music"
		player.volume_db = -80.0
		# Tracks are imported looping (seamless). This restart is only a fallback for
		# any new track added without the loop flag.
		player.finished.connect(player.play)
		add_child(player)
	_active_music = _music_a
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_pool.append(player)
	_voice.bus = &"SFX"
	add_child(_voice)
	_build_captions()


func play_music(stream: AudioStream) -> void:
	if stream == null or (_active_music.stream == stream and _active_music.playing):
		return
	var old := _active_music
	_active_music = _music_b if old == _music_a else _music_a
	_active_music.stream = stream
	_active_music.play()
	var tween := create_tween().set_parallel()
	tween.tween_property(_active_music, "volume_db", 0.0, FADE_TIME)
	tween.tween_property(old, "volume_db", -80.0, FADE_TIME)
	tween.chain().tween_callback(old.stop)


func stop_music() -> void:
	var tween := create_tween()
	tween.tween_property(_active_music, "volume_db", -80.0, FADE_TIME)
	tween.tween_callback(_active_music.stop)


func play_sfx(sfx_name: StringName, pitch := 1.0, volume_db := 0.0) -> void:
	var stream: AudioStream = SFX.get(sfx_name)
	if stream == null:
		push_warning("Unknown sound effect: %s" % sfx_name)
		return
	var player := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()
	if Settings.sound_captions and SOUND_CAPTIONS.has(sfx_name):
		show_sound_caption(SOUND_CAPTIONS[sfx_name])


## Shows "[words]" in the lower left for a moment (Settings.sound_captions).
func show_sound_caption(words: String) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_caption_shown.get(words, -10000)) < 900:
		return
	_caption_shown[words] = now
	var label := Label.new()
	label.text = "[%s]" % words
	label.add_theme_font_size_override(&"font_size", roundi(30 * Settings.text_scale))
	label.add_theme_color_override(&"font_color", Color("e6dccb"))
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override(&"outline_size", 10)
	_captions.add_child(label)
	while _captions.get_child_count() > 4:
		_captions.get_child(0).free()
	var tween := label.create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


func _build_captions() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	_captions = VBoxContainer.new()
	_captions.name = &"SoundCaptions"
	_captions.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_captions.position = Vector2(40, 860)
	_captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_captions)


## Plays one of Patch's voice lines. `important` lines always cut in; others are
## skipped while he's already talking, so quick combos don't turn into chatter.
func play_voice(line: StringName, important := false, volume_db := 0.0) -> void:
	var stream: AudioStream = VOICE.get(line)
	if stream == null:
		push_warning("Unknown voice line: %s" % line)
		return
	if _voice.playing and not important:
		return
	_voice.stream = stream
	_voice.pitch_scale = randf_range(0.97, 1.03)
	_voice.volume_db = volume_db
	_voice.play()

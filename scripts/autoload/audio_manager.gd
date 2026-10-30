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
}
const POOL_SIZE := 10
const FADE_TIME := 0.8

var _music_a := AudioStreamPlayer.new()
var _music_b := AudioStreamPlayer.new()
var _active_music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for player in [_music_a, _music_b]:
		player.bus = &"Music"
		player.volume_db = -80.0
		# Restart when the track ends, so any WAV loops without import tweaks.
		player.finished.connect(player.play)
		add_child(player)
	_active_music = _music_a
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_pool.append(player)


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

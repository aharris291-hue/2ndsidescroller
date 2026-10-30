extends CanvasLayer
## Conversations and narrator captions.
##
## Conversations are loaded from data/dialogue/*.json. Each entry is a list of lines:
##   {"speaker": "patch", "text": "Stand back, everyone!"}
## Speakers (name, color, voice pitch) come from data/speakers.json.
## Text types out with a voice blip per couple of letters, pitched per speaker.
##
## Narrator captions (Dad's handwriting) float at the top of the screen and never
## pause play: DialogueUI.narrate("The meadow was quiet. Too quiet.")

const DIALOGUE_FILES: Array[String] = [
	"res://data/dialogue/ch1_thistledown.json",
	"res://data/dialogue/ch2_lanternfold.json",
	"res://data/dialogue/margin.json",
	"res://data/dialogue/prologue.json",
	"res://data/dialogue/interludes.json",
]
const SPEAKERS_FILE := "res://data/speakers.json"
const CHARS_PER_SECOND := 45.0
const CAPTION_HOLD := 3.5

var _conversations: Dictionary = {}
var _speakers: Dictionary = {}
var _lines: Array = []
var _index := 0
var _visible_chars := 0.0
var _last_blip_char := 0
var _active := false
var _pitch := 1.0
var _caption_queue: Array[String] = []
var _caption_busy := false

@onready var box: Control = $Box
@onready var name_label: Label = $Box/Margin/VBox/NameLabel
@onready var text_label: RichTextLabel = $Box/Margin/VBox/Text
@onready var continue_hint: Label = $Box/Margin/VBox/ContinueHint
@onready var caption: Control = $Caption
@onready var caption_label: Label = $Caption/Margin/CaptionLabel


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_speakers = _load_json(SPEAKERS_FILE)
	for path in DIALOGUE_FILES:
		_conversations.merge(_load_json(path))
	# Narrator captions print straight onto the page in bold capitals, like the book's own text.
	caption.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	caption_label.uppercase = true
	caption_label.add_theme_font_size_override(&"font_size", 46)
	caption_label.add_theme_color_override(&"font_color", Color("281e2e"))
	caption_label.add_theme_color_override(&"font_outline_color", Color("fff8e2"))
	caption_label.add_theme_constant_override(&"outline_size", 14)
	box.visible = false
	caption.visible = false
	caption.modulate.a = 0.0


func is_active() -> bool:
	return _active


func start(conversation_id: String) -> void:
	var lines: Array = _conversations.get(conversation_id, [])
	if lines.is_empty():
		push_warning("No dialogue named '%s'." % conversation_id)
		return
	_lines = lines
	_index = 0
	_active = true
	box.visible = true
	EventBus.dialogue_started.emit()
	_show_line()


func narrate(text: String) -> void:
	_caption_queue.append(text)
	if not _caption_busy:
		_next_caption()


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	var speaker: Dictionary = _speakers.get(line.get("speaker", ""), {})
	name_label.text = speaker.get("name", "")
	name_label.add_theme_color_override(&"font_color", Color(speaker.get("color", "#2b2118")))
	_pitch = float(speaker.get("pitch", 1.0))
	text_label.text = line.get("text", "")
	text_label.visible_characters = 0
	_visible_chars = 0.0
	_last_blip_char = 0
	continue_hint.visible = false


func _process(delta: float) -> void:
	if not _active or _line_finished():
		return
	_visible_chars += CHARS_PER_SECOND * delta
	text_label.visible_characters = int(_visible_chars)
	# Animal Crossing-style voice: a blip every other letter, pitched per speaker.
	var shown := text_label.visible_characters
	if shown - _last_blip_char >= 2:
		_last_blip_char = shown
		var parsed := text_label.get_parsed_text()
		if shown <= parsed.length() and parsed[shown - 1] != " ":
			AudioManager.play_sfx(&"voice_blip", _pitch * randf_range(0.92, 1.08), -6.0)
	if _line_finished():
		continue_hint.visible = true


func _line_finished() -> bool:
	return text_label.visible_characters < 0 or text_label.visible_characters >= text_label.get_total_character_count()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	var advance := event.is_action_pressed(&"interact") or event.is_action_pressed(&"jump") \
		or event.is_action_pressed(&"attack") or event.is_action_pressed(&"ui_accept")
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if not _line_finished():
		text_label.visible_characters = -1
		continue_hint.visible = true
		return
	_index += 1
	if _index < _lines.size():
		_show_line()
	else:
		_active = false
		box.visible = false
		EventBus.dialogue_finished.emit()


func _next_caption() -> void:
	if _caption_queue.is_empty():
		_caption_busy = false
		return
	_caption_busy = true
	caption_label.text = _caption_queue.pop_front()
	caption.visible = true
	var tween := create_tween()
	tween.tween_property(caption, "modulate:a", 1.0, 0.4)
	tween.tween_interval(CAPTION_HOLD + caption_label.text.length() * 0.03)
	tween.tween_property(caption, "modulate:a", 0.0, 0.6)
	await tween.finished
	caption.visible = false
	_next_caption()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Could not parse %s" % path)
		return {}
	return parsed

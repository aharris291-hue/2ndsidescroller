class_name Collectible
extends Area2D
## Pickups: Scraps (currency), Lost Letters, tape (healing), ability pages, and key
## items (real things from the Margin, like the paperclip, which set a story flag).
## Everything but Scraps is one-time: once collected it stays gone across saves.

enum Kind { SCRAP, LOST_LETTER, TAPE, ABILITY, KEY_ITEM }

@export var kind := Kind.SCRAP
@export var amount := 1
## For LOST_LETTER: which letter (A–Z) this restores.
@export var letter := "A"
## For ABILITY: the ability id, e.g. &"fold_dash".
@export var ability_id: StringName = &""
## For KEY_ITEM: the story flag set on pickup, e.g. "has_paperclip".
@export var flag := ""
@export_multiline var unlock_caption := ""
## Dropped pickups (from enemies) are never saved as collected.
@export var persistent := true

var _time := randf() * TAU
var _taken := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var _label: Label = get_node_or_null("Label")


func _ready() -> void:
	if _is_one_time() and GameState.is_collected(_unique_id()):
		queue_free()
		return
	if _label:
		_label.text = letter if kind == Kind.LOST_LETTER else ""
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta * 3.0
	sprite.position.y = sin(_time) * 6.0
	if _label:
		_label.position.y = sprite.position.y - _label.size.y * 0.5


func _is_one_time() -> bool:
	return persistent and kind != Kind.SCRAP


func _unique_id() -> String:
	return "%s:%s" % [owner.scene_file_path if owner else "", get_path()]


func _on_body_entered(body: Node2D) -> void:
	var player := body as Patch
	if player == null or _taken:
		return
	_taken = true
	match kind:
		Kind.SCRAP:
			GameState.add_scraps(amount)
		Kind.LOST_LETTER:
			GameState.collect_letter(letter)
			DialogueUI.narrate("A Lost Letter! \"%s\" is back where it belongs." % letter)
			if GameState.letters.size() >= GameState.LETTER_TOTAL:
				DialogueUI.narrate("That's all twenty-six! Every Lost Letter is home. At the very back of the book, a line of Dad's has come back.")
		Kind.TAPE:
			player.health.heal(amount)
		Kind.ABILITY:
			GameState.unlock_ability(ability_id)
			if not unlock_caption.is_empty():
				var text := unlock_caption
				for action in [&"dash", &"grapple", &"slam", &"attack", &"jump"]:
					text = text.replace("{%s}" % action, InputGlyphs.hint(action))
				DialogueUI.narrate(text)
		Kind.KEY_ITEM:
			GameState.set_flag(flag)
			if not unlock_caption.is_empty():
				DialogueUI.narrate(unlock_caption)
	if _is_one_time():
		GameState.mark_collected(_unique_id())
	AudioManager.play_sfx(&"pickup", randf_range(0.95, 1.1) if kind == Kind.SCRAP else 0.85)
	set_deferred("monitoring", false)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - 60.0, 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)

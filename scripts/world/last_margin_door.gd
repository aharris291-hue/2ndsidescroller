class_name LastMarginDoor
extends PageDoor
## The way to the Last Margin (the true ending), in the Spine past Gran's sewing tin.
## It isn't there until the book is finished. Then it shows, stitched shut in black
## thread, and opens once Patch has crossed the Blank Margins and faced every boss
## again on Gran's proof press and beaten it inked (any sticker). Its sign says what's
## left.

const PAGE := "res://scenes/levels/postgame/the_last_margin.tscn"
const HUB := "res://scenes/levels/hub/spine_hub.tscn"
## In front of this door on the Spine's ground floor ('N' in the hub's map).
const HUB_SPOT := Vector2(1888, 940)
const DOOR := preload("res://assets/art/dark/props/region_door.png")

var _sprite: Sprite2D
var _sign: Label


func _init() -> void:
	collision_layer = 32
	collision_mask = 2
	prompt_offset = Vector2(0, -300)


func _ready() -> void:
	target_page = PAGE
	target_spawn = &"Start"
	door_prompt = "Go to the last page"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150, 240)
	shape.shape = rect
	shape.position = Vector2(0, -120)
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = DOOR
	_sprite.position = Vector2(0, -130)
	_sprite.material = Papers.material_for(Papers.INK)
	add_child(_sprite)
	_sign = DarkUI.label("", 22, DarkUI.BONE)
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.autowrap_mode = TextServer.AUTOWRAP_OFF
	_sign.size = Vector2(360, 60)
	_sign.position = Vector2(-180, 4)
	_sign.add_theme_constant_override(&"outline_size", 6)
	_sign.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_sign)
	super._ready()
	_refresh()


func _process(_delta: float) -> void:
	_refresh()
	_prompt.visible = visible and _player_near and can_interact() and not DialogueUI.is_active()


## The story bosses still to be beaten inked on the proof press.
static func proofs_left() -> int:
	return Papers.STORY_BOSSES.filter(func(b: String) -> bool: return Rematch.best_rank(b) == 0).size()


static func unlocked() -> bool:
	return GameState.get_flag("game_complete") and GameState.get_flag("boss_forecast_defeated") \
		and proofs_left() == 0


func is_open() -> bool:
	return unlocked()


func _refresh() -> void:
	visible = GameState.get_flag("game_complete")
	if not visible:
		return
	var left := proofs_left()
	if is_open():
		modulate = Color.WHITE
		_sign.text = "The last page\nthe margin"
	elif not GameState.get_flag("boss_forecast_defeated"):
		modulate = Color(0.55, 0.55, 0.6)
		_sign.text = "The last page\nthe Blank Margins first"
	else:
		modulate = Color(0.55, 0.55, 0.6)
		_sign.text = "The last page\n%d %s still to pull" % [left, "proof" if left == 1 else "proofs"]

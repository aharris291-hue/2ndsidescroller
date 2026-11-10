class_name FinaleDoor
extends PageDoor
## The way down out of the Spine to the Sogg and the Gutter (the finale). It stays
## sewn shut until Patch has told the truth at the Low Point (4-5) and every region of
## the book is mended (BookMap.torn_regions); its sign says what's still torn.

const DOOR := preload("res://assets/art/dark/props/region_door.png")

var _sprite: Sprite2D
var _sign: Label


func _init() -> void:
	collision_layer = 32
	collision_mask = 2
	prompt_offset = Vector2(0, -300)


func _ready() -> void:
	target_page = "res://scenes/levels/ch3_spine/sogg_arena.tscn"
	target_spawn = &"Start"
	door_prompt = "Go down to the Gutter"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150, 240)
	shape.shape = rect
	shape.position = Vector2(0, -120)
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = DOOR
	_sprite.position = Vector2(0, -130)
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
	_prompt.visible = _player_near and can_interact() and not DialogueUI.is_active()


func is_open() -> bool:
	return GameState.get_flag("patch_told_truth") and BookMap.torn_regions().is_empty()


func _refresh() -> void:
	var torn := BookMap.torn_regions()
	if is_open():
		_sprite.modulate = Color(0.75, 0.3, 0.28)
		_sign.text = "The way down\nthe Gutter"
	elif not torn.is_empty():
		_sprite.modulate = Color(0.3, 0.2, 0.2)
		_sign.text = "The way down\n%d %s still torn" % [torn.size(), "region" if torn.size() == 1 else "regions"]
	else:
		_sprite.modulate = Color(0.3, 0.2, 0.2)
		_sign.text = "The way down\nnot yet"

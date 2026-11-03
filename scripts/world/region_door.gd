class_name RegionDoor
extends PageDoor
## A door in the Spine hub leading to one region of the book (see BookMap). Always
## shown: a door whose region isn't open yet is dimmed and says why, and a door to a
## region not yet written stays stitched shut.

const DOOR := preload("res://assets/art/dark/props/region_door.png")

@export var region_id: StringName = &""

var _sprite: Sprite2D
var _sign: Label


func _init() -> void:
	collision_layer = 32
	collision_mask = 2
	prompt_offset = Vector2(0, -300)


func _ready() -> void:
	var entry := BookMap.region(region_id)
	target_page = entry.get("door", "")
	requires_flag = entry.get("open_flag", "")
	target_spawn = &"Start"
	door_prompt = "Enter %s" % entry.get("name", "")
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
	_sign.size = Vector2(320, 60)
	_sign.position = Vector2(-160, 4)
	_sign.add_theme_constant_override(&"outline_size", 6)
	_sign.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_sign)
	super._ready()
	_refresh()


func _process(_delta: float) -> void:
	# Unlike a plain PageDoor, never hide: show the state instead.
	_refresh()
	_prompt.visible = _player_near and can_interact() and not DialogueUI.is_active()


func can_interact() -> bool:
	return state() != "unwritten" and super.can_interact()


func state() -> String:
	var entry := BookMap.region(region_id)
	if entry.is_empty() or not BookMap.is_written(entry):
		return "unwritten"
	if not is_open():
		return "locked"
	if not str(entry["mended_flag"]).is_empty() and GameState.get_flag(entry["mended_flag"]):
		return "mended"
	return "open"


func _refresh() -> void:
	var entry := BookMap.region(region_id)
	var s := state()
	match s:
		"unwritten":
			_sprite.modulate = Color(0.32, 0.3, 0.32)
			_sign.text = "%s\nstitched shut" % entry.get("name", "?")
		"locked":
			_sprite.modulate = Color(0.45, 0.42, 0.45)
			_sign.text = "%s\nthe thread won't give yet" % entry.get("name", "?")
		"mended":
			_sprite.modulate = Color(1, 0.94, 0.86)
			_sign.text = "%s\nmended" % entry.get("name", "?")
		_:
			_sprite.modulate = Color.WHITE
			_sign.text = entry.get("name", "?")

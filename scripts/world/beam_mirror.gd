class_name BeamMirror
extends Interactable
## A swivel mirror on an iron pivot (2-3, the Lamp Room, seen from above). Its glass
## runs corner to corner, '/' or '\'; Patch turns it from one to the other. The page
## traces the lamp's beam off it (see LampRoom).

signal turned

const TEX := preload("res://assets/art/dark/props/beam_mirror.png")

## 0 = '/', 1 = '\'.
@export_range(0, 1) var slant := 0

var _sprite: Sprite2D


func _ready() -> void:
	add_to_group(&"beam_mirrors")
	prompt_text = "Turn the mirror"
	prompt_offset = Vector2(0, -70)
	collision_layer = 32
	collision_mask = 2
	var area := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 76.0
	area.shape = circle
	add_child(area)
	# The pivot itself is in the way.
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var block := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(52, 52)
	block.shape = rect
	body.add_child(block)
	add_child(body)
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.rotation = 0.0 if slant == 0 else PI / 2.0
	add_child(_sprite)
	super._ready()


func interact(_player: Patch) -> void:
	turn()


func turn() -> void:
	slant = 1 - slant
	AudioManager.play_sfx(&"tab_pull", 0.7, -4.0)
	var swing := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	swing.tween_property(_sprite, "rotation", 0.0 if slant == 0 else PI / 2.0, 0.2)
	turned.emit()


## Where a beam travelling `dir` (one of the four grid directions) goes after this glass.
func reflect(dir: Vector2i) -> Vector2i:
	return Vector2i(-dir.y, -dir.x) if slant == 0 else Vector2i(dir.y, dir.x)

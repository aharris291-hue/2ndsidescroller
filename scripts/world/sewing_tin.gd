class_name SewingTin
extends Interactable
## Gran's sewing tin on the mending table in the Spine. Opens the shop (ShopPanel).

const TABLE := preload("res://assets/art/dark/props/mending_table.png")
const CUSHION := preload("res://assets/art/dark/props/pincushion.png")
const SPOOL := preload("res://assets/art/dark/props/spool.png")

var _shop: ShopPanel


func _init() -> void:
	prompt_text = "Open Gran's sewing tin"
	prompt_offset = Vector2(0, -230)
	collision_layer = 32
	collision_mask = 2


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(300, 160)
	shape.shape = rect
	shape.position = Vector2(0, -80)
	add_child(shape)
	_sprite(TABLE, Vector2(0, -75))
	_sprite(CUSHION, Vector2(-70, -150), 0.6)
	_sprite(SPOOL, Vector2(60, -136), 0.7)
	super._ready()


func _sprite(texture: Texture2D, at: Vector2, scale_by := 1.0) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = Vector2.ONE * scale_by
	add_child(sprite)


func can_interact() -> bool:
	return not is_instance_valid(_shop) and not SceneManager.is_transitioning


func interact(_player: Patch) -> void:
	_shop = ShopPanel.open_panel(get_tree().root)

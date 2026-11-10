class_name PennyTheatre
extends Interactable
## Gran's penny theatre on the Spine's ground floor ('Q' in the hub's map): the
## minigame arcade (Arcade).

const ART := preload("res://assets/art/dark/props/penny_theatre.png")
var _panel: CanvasLayer


func _init() -> void:
	prompt_text = "Put a penny in"
	prompt_offset = Vector2(0, -330)
	collision_layer = 32
	collision_mask = 2


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(220, 220)
	shape.shape = rect
	shape.position = Vector2(0, -110)
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = ART
	sprite.position = Vector2(0, -ART.get_height() / 2.0 + 4.0)
	add_child(sprite)
	super._ready()


func can_interact() -> bool:
	return not is_instance_valid(_panel) and not SceneManager.is_transitioning


func interact(_player: Patch) -> void:
	if not GameState.get_flag("penny_theatre_seen"):
		GameState.set_flag("penny_theatre_seen")
		DialogueUI.narrate("Gran's penny theatre, from the pier, before the pier went. The little candle inside still lit when Patch turned the crank. It always had.")
	_panel = Arcade.ArcadePanel.open(get_tree().root)

class_name ProofPress
extends Interactable
## Gran's proof press in the Spine's gallery: the boss rematches (RematchPanel).
## Usable once any boss's page is mended.

const ART := preload("res://assets/art/dark/props/proof_press.png")

var _panel: RematchPanel


func _init() -> void:
	prompt_text = "Pull a proof"
	prompt_offset = Vector2(0, -250)
	collision_layer = 32
	collision_mask = 2


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(320, 200)
	shape.shape = rect
	shape.position = Vector2(0, -100)
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = ART
	sprite.scale = Vector2(0.72, 0.72)
	# Its bench stands back from the gallery's edge, clear of the Margins door.
	sprite.position = Vector2(-28, -ART.get_height() * 0.36 + 4.0)
	add_child(sprite)
	super._ready()


func can_interact() -> bool:
	return Rematch.any_unlocked() and not is_instance_valid(_panel) \
		and not SceneManager.is_transitioning


func interact(_player: Patch) -> void:
	if not GameState.get_flag("proof_press_seen"):
		GameState.set_flag("proof_press_seen")
		DialogueUI.narrate("Gran's proof press. Patch had never been allowed to touch it. The proofs were still pegged on the string over it, one for every page he had mended, and every one of them was the page before.")
	_panel = RematchPanel.open_panel(get_tree().root)

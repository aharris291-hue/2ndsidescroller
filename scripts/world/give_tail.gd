extends Interactable
## The finale's last choice (BossSogg, phase 4): Patch gives Drizzle the Tape Tail to
## stitch her shut with. A child of the little torn cloud on the floor of the Gutter.

var boss: Node


func _init() -> void:
	collision_layer = 32
	collision_mask = 2
	prompt_text = "Give her the tail"
	prompt_offset = Vector2(0, -260)


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(260, 240)
	shape.shape = rect
	shape.position = Vector2(0, -120)
	add_child(shape)
	super._ready()


func interact(_player: Patch) -> void:
	if boss and boss.has_method("give_tail"):
		boss.give_tail()

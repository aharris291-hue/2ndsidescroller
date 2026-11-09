class_name InkPool
extends Area2D
## Settled ink (Region 3, Watermark Marsh), drawn in a text map as '~'. Black, still,
## and it takes what falls in: without the Blot Dive, touching it burns a heart and
## puts Patch back where he last stood. With it, Patch lets the ink in and swims
## through it as a blot (see Patch._process_blot).
##
## Covers `size` from its origin at the top-left. `surface` draws the still skin on top (resources/shaders/settled_ink.gdshader)
## (off for the lower blocks of a deep pool, which sit under another pool).

const INK_SHADER := preload("res://resources/shaders/settled_ink.gdshader")

@export var size := Vector2(128, 128)
@export var surface := true


func _ready() -> void:
	add_to_group(&"ink_pools")
	collision_layer = 0
	collision_mask = 2
	z_index = 3
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)
	var body := ColorRect.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size = size + Vector2(0, 6) if surface else size
	body.position.y = -6.0 if surface else 0.0
	var mat := ShaderMaterial.new()
	mat.shader = INK_SHADER
	mat.set_shader_parameter(&"rect_size", body.size)
	mat.set_shader_parameter(&"surface", surface)
	body.material = mat
	add_child(body)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("enter_ink"):
		body.enter_ink(self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("leave_ink"):
		body.leave_ink(self)


func covers(point: Vector2) -> bool:
	return Rect2(global_position, size).has_point(point)


## True if `point` is inside any ink on the page.
static func ink_at(tree: SceneTree, point: Vector2) -> bool:
	for node in tree.get_nodes_in_group(&"ink_pools"):
		if (node as InkPool).covers(point):
			return true
	return false

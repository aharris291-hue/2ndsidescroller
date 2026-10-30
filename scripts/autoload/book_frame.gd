extends CanvasLayer
## Shows the game as an open pop-up book lying on a desk, the way the story is
## really being read. Everything drawn below this layer (the current page) is
## warped onto the book in perspective; the HUD, dialogue and menus sit above it.
##
## Turn it off from the pause menu (Settings.book_view) for a flat full-screen page.
## Scenes outside the book (the Margin, real-world cutscenes) set `in_book = false`.

const SHADER := preload("res://resources/shaders/book_frame.gdshader")
const DESK := preload("res://assets/art/backgrounds/bg_desk.png")

## Corners of the pages on screen (0-1): top-left, top-right, bottom-right, bottom-left.
## The top edge is narrower, so the book looks like it's tilted away from you.
@export var corners: PackedVector2Array = PackedVector2Array([
	Vector2(0.095, 0.085), Vector2(0.905, 0.085), Vector2(0.97, 0.895), Vector2(0.03, 0.895),
])

var _rect: ColorRect


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"desk_tex", DESK)
	material.set_shader_parameter(&"to_page", _screen_to_page(corners))
	_rect.material = material
	add_child(_rect)
	refresh.call_deferred()


## Shows the book around the current scene, unless book view is off or the scene is
## set in the real world (a scene with `in_book = false`, like the Margin or a cutscene).
func refresh() -> void:
	var scene := get_tree().current_scene
	visible = Settings.book_view and (scene == null or scene.get(&"in_book") != false)


## Builds the perspective transform that takes a screen position to a page position.
## It's the inverse of the square-to-quad homography (Heckbert's method).
static func _screen_to_page(quad: PackedVector2Array) -> Basis:
	var p0 := quad[0]
	var p1 := quad[1]
	var p2 := quad[2]
	var p3 := quad[3]
	var d1 := p1 - p2
	var d2 := p3 - p2
	var d3 := p0 - p1 + p2 - p3
	var det := d1.x * d2.y - d2.x * d1.y
	var g := (d3.x * d2.y - d2.x * d3.y) / det
	var h := (d1.x * d3.y - d3.x * d1.y) / det
	var page_to_screen := Basis(
		Vector3(p1.x - p0.x + g * p1.x, p1.y - p0.y + g * p1.y, g),
		Vector3(p3.x - p0.x + h * p3.x, p3.y - p0.y + h * p3.y, h),
		Vector3(p0.x, p0.y, 1.0))
	return page_to_screen.inverse()

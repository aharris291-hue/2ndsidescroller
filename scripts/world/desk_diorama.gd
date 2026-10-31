class_name DeskDiorama
extends Node
## Draws a real-world page (the Margin) as a lit 3D desk instead of flat 2D.
##
## Gameplay doesn't change: the page's 2D nodes still move, collide and run their
## scripts. This node hides the 2D drawing and builds a 3D diorama that mirrors it:
## the floor tiles become a wooden desk, book tiles become stacks of real books,
## ink tiles become glossy puddles, and every Sprite2D becomes a paper cutout
## (a Sprite3D) standing on the desk, casting a shadow. Labels become Label3Ds.
##
## 2D pixels map to 3D metres at PIXELS_PER_METRE; 2D x is 3D x, 2D y is 3D z.

const PIXELS_PER_METRE := 128.0
const WOOD_ALBEDO := preload("res://assets/materials/wood_albedo.png")
const WOOD_NORMAL := preload("res://assets/materials/wood_normal.png")
const PAPER_NORMAL := preload("res://assets/materials/paper_normal.png")
const CARDBOARD_NORMAL := preload("res://assets/materials/cardboard_normal.png")
const FONT := preload("res://assets/fonts/PatrickHand-Regular.ttf")

const TILE_PAGE := Vector2i(1, 1)
const TILE_BOOKS := Vector2i(2, 1)
const TILE_INK := Vector2i(3, 1)
const BOOK_COLORS: Array[Color] = [
	Color("d8475a"), Color("3f8fd8"), Color("f0a03a"), Color("5fbfa8"), Color("8a63c9"), Color("e9d27a"),
]

## The 2D page this diorama redraws. Defaults to the parent.
@export var page: Node2D
## Camera offset from Patch, in metres: up and toward the viewer.
@export var camera_offset := Vector3(0.0, 6.2, 7.6)
@export var camera_fov := 40.0

var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _player: Node2D
# Each entry: {"source": CanvasItem, "target": Node3D}
var _mirrors: Array[Dictionary] = []
var _mirrored := {}
var _rescan_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if page == null:
		page = get_parent() as Node2D
	_rng.seed = 2026
	_build_viewport()
	_build_lighting()
	_build_desk()
	_build_tiles()
	_build_decor()
	_scan()
	# The 2D drawing is replaced by the diorama; its nodes keep working underneath.
	page.visible = false
	_update_mirrors()
	_update_camera(1.0)


func _process(delta: float) -> void:
	_rescan_left -= delta
	if _rescan_left <= 0.0:
		_rescan_left = 0.4
		_scan()
	_update_mirrors()
	_update_camera(delta)


## Converts a 2D page position to a point on the desk.
static func to_desk(p: Vector2, height := 0.0) -> Vector3:
	return Vector3(p.x / PIXELS_PER_METRE, height, p.y / PIXELS_PER_METRE)


# ------------------------------------------------------------------ scene setup


func _build_viewport() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -50
	add_child(layer)
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_viewport.positional_shadow_atlas_size = 4096
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "Desk"
	_viewport.add_child(_world)

	_camera = Camera3D.new()
	_camera.fov = camera_fov
	_camera.near = 0.1
	_camera.far = 200.0
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 11.0
	attributes.dof_blur_far_transition = 8.0
	attributes.dof_blur_amount = 0.09
	_camera.attributes = attributes
	_world.add_child(_camera)
	_camera.make_current()


func _build_lighting() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("9cc4e8")
	sky_material.sky_horizon_color = Color("f3dcc0")
	sky_material.ground_bottom_color = Color("5a3c28")
	sky_material.ground_horizon_color = Color("c99a72")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.4
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.08
	env.fog_enabled = true
	env.fog_light_color = Color("e9cfae")
	env.fog_density = 0.004
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_world.add_child(world_env)

	# Late-afternoon sun through a window: warm, low, with soft shadows.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe2b8")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.2
	sun.directional_shadow_max_distance = 45.0
	sun.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	_world.add_child(sun)

	# The Great Light: Gran's lamp, a warm pool on one side of the desk.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffc884")
	lamp.light_energy = 2.0
	lamp.omni_range = 16.0
	lamp.shadow_enabled = true
	lamp.position = to_desk(_page_bounds().end * Vector2(0.85, 0.15), 6.0)
	_world.add_child(lamp)


func _build_desk() -> void:
	var bounds := _page_bounds()
	var size := bounds.size / PIXELS_PER_METRE + Vector2(60, 60)
	var desk := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 1.0, size.y)
	desk.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = WOOD_ALBEDO
	mat.normal_enabled = true
	mat.normal_texture = WOOD_NORMAL
	mat.normal_scale = 0.7
	mat.roughness = 0.55
	mat.albedo_color = Color(0.82, 0.78, 0.74)
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0) / 10.0
	mat.uv1_triplanar = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	desk.material_override = mat
	desk.position = to_desk(bounds.get_center(), -0.5)
	_world.add_child(desk)


func _build_tiles() -> void:
	for child in page.get_children():
		var layer := child as TileMapLayer
		if layer == null:
			continue
		var page_cells: Array[Vector2i] = []
		for cell in layer.get_used_cells():
			var atlas := layer.get_cell_atlas_coords(cell)
			var center := layer.to_global(layer.map_to_local(cell))
			match atlas:
				TILE_PAGE:
					page_cells.append(cell)
				TILE_BOOKS:
					_add_book_stack(center)
				TILE_INK:
					_add_ink(center)
		if not page_cells.is_empty():
			_add_page_sheet(layer, page_cells)


func _add_book_stack(center: Vector2) -> void:
	var tile := 64.0 / PIXELS_PER_METRE
	var count := _rng.randi_range(2, 4)
	var y := 0.0
	for i in count:
		var thickness := _rng.randf_range(0.12, 0.2)
		var book := Node3D.new()
		book.position = to_desk(center, y + thickness / 2.0)
		book.rotation.y = _rng.randf_range(-0.12, 0.12)
		var cover := _box(Vector3(tile * 0.98, thickness, tile * 0.9), _material(BOOK_COLORS[_rng.randi() % BOOK_COLORS.size()], 0.7, CARDBOARD_NORMAL))
		book.add_child(cover)
		var pages := _box(Vector3(tile * 0.94, thickness * 0.8, tile * 0.92), _material(Color("f4ead2"), 0.9, PAPER_NORMAL))
		pages.position.x = tile * 0.03
		book.add_child(pages)
		_world.add_child(book)
		y += thickness


func _add_ink(center: Vector2) -> void:
	var puddle := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	var r := _rng.randf_range(0.3, 0.38)
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = 0.02
	mesh.radial_segments = 24
	puddle.mesh = mesh
	var mat := _material(Color("1c2550"), 0.04)
	mat.metallic_specular = 1.0
	mat.clearcoat_enabled = true
	puddle.material_override = mat
	puddle.position = to_desk(center, 0.011)
	puddle.scale = Vector3(1.0, 1.0, _rng.randf_range(0.8, 1.1))
	_world.add_child(puddle)


func _add_page_sheet(layer: TileMapLayer, cells: Array[Vector2i]) -> void:
	var rect := Rect2i(cells[0], Vector2i.ONE)
	for cell in cells:
		rect = rect.expand(cell).expand(cell + Vector2i.ONE)
	var top_left := layer.to_global(layer.map_to_local(rect.position) - Vector2(32, 32))
	var size := Vector2(rect.size) * 64.0
	var tile_texture := _tile_texture(layer, TILE_PAGE)
	var mat := _material(Color.WHITE, 0.85, PAPER_NORMAL)
	mat.albedo_texture = tile_texture
	mat.uv1_scale = Vector3(rect.size.x, rect.size.y, 1.0)
	var sheet := _box(Vector3(size.x / PIXELS_PER_METRE, 0.03, size.y / PIXELS_PER_METRE), mat)
	sheet.position = to_desk(top_left + size / 2.0, 0.015)
	sheet.rotation.y = 0.01
	_world.add_child(sheet)


func _tile_texture(layer: TileMapLayer, atlas: Vector2i) -> Texture2D:
	var source := layer.tile_set.get_source(0) as TileSetAtlasSource
	var image := source.texture.get_image()
	if image.is_compressed():
		image.decompress()
	var region := image.get_region(Rect2i(atlas * 64, Vector2i(64, 64)))
	return ImageTexture.create_from_image(region)


## Everyday things lying around the edge of the play area, for scale.
func _build_decor() -> void:
	var b := _page_bounds()
	var top := b.position.y - 260.0
	# A giant mug.
	var mug := Node3D.new()
	mug.position = to_desk(Vector2(b.position.x + b.size.x * 0.22, top - 200.0))
	var mug_mat := _material(Color("4f86c6"), 0.25)
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.0
	cyl.bottom_radius = 1.85
	cyl.height = 4.2
	body.mesh = cyl
	body.material_override = mug_mat
	body.position.y = 2.1
	mug.add_child(body)
	var handle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.35
	handle.mesh = torus
	handle.material_override = mug_mat
	handle.position = Vector3(2.0, 2.2, 0)
	handle.rotation_degrees = Vector3(90, 0, 0)
	mug.add_child(handle)
	_world.add_child(mug)
	# Pencils.
	for i in 3:
		var pencil := Node3D.new()
		pencil.position = to_desk(Vector2(b.position.x + b.size.x * (0.5 + i * 0.07), top + i * 60.0), 0.2)
		pencil.rotation.y = 0.3 + i * 0.25
		var shaft := MeshInstance3D.new()
		var hex := CylinderMesh.new()
		hex.top_radius = 0.2
		hex.bottom_radius = 0.2
		hex.height = 6.0
		hex.radial_segments = 6
		shaft.mesh = hex
		shaft.material_override = _material([Color("f2c53d"), Color("e2574c"), Color("4caf7a")][i], 0.5)
		shaft.rotation_degrees.z = 90
		pencil.add_child(shaft)
		var tip := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.2
		cone.height = 0.7
		cone.radial_segments = 6
		tip.mesh = cone
		tip.material_override = _material(Color("e8c9a0"), 0.8)
		tip.rotation_degrees.z = -90
		tip.position.x = 3.35
		pencil.add_child(tip)
		_world.add_child(pencil)
	# Alphabet blocks.
	var letters := ["A", "B", "C"]
	for i in letters.size():
		var block := _box(Vector3(1.6, 1.6, 1.6), _material([Color("e8d9b5"), Color("f0b84a"), Color("d8475a")][i], 0.6))
		block.position = to_desk(Vector2(b.end.x + 220.0 + (i % 2) * 120.0, b.position.y + 300.0 + i * 230.0), 0.8)
		block.rotation.y = _rng.randf_range(-0.4, 0.4)
		var label := Label3D.new()
		label.text = letters[i]
		label.font = FONT
		label.font_size = 160
		label.pixel_size = 0.006
		label.modulate = Color("2a2030")
		label.position = Vector3(0, 0, 0.81)
		block.add_child(label)
		_world.add_child(block)
	# A stack of real books behind the play area.
	for i in 4:
		var big := _box(Vector3(9.0, 0.9, 6.0), _material(BOOK_COLORS[(i + 2) % BOOK_COLORS.size()], 0.75, CARDBOARD_NORMAL))
		big.position = to_desk(Vector2(b.end.x - 600.0, top - 520.0), 0.45 + i * 0.9)
		big.rotation.y = _rng.randf_range(-0.15, 0.15)
		_world.add_child(big)


# ------------------------------------------------------------------ mirroring


func _scan() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	_scan_node(page)


func _scan_node(node: Node) -> void:
	for child in node.get_children():
		if child is Sprite2D or child is Label:
			if not _mirrored.has(child.get_instance_id()):
				_add_mirror(child)
		if not (child is TileMapLayer):
			_scan_node(child)


func _add_mirror(item: CanvasItem) -> void:
	var target: Node3D
	if item is Sprite2D:
		if item.get_parent().name.contains("TapeRoll"):
			target = _tape_roll()
		else:
			var sprite := Sprite3D.new()
			sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			sprite.shaded = true
			sprite.double_sided = true
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			target = sprite
	else:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font = FONT
		label.font_size = 64
		label.outline_size = 18
		label.modulate = Color("2a2030")
		label.outline_modulate = Color("fff8e2")
		label.pixel_size = 0.004
		label.no_depth_test = true
		target = label
	_world.add_child(target)
	_mirrors.append({"source": item, "target": target})
	_mirrored[item.get_instance_id()] = true


func _tape_roll() -> Node3D:
	var roll := Node3D.new()
	var tape := MeshInstance3D.new()
	var torus := TorusMesh.new()
	# Sized to the roll's 150 px collision circle so Patch bumps into what he sees.
	torus.inner_radius = 0.62
	torus.outer_radius = 1.2
	torus.rings = 48
	tape.mesh = torus
	var tape_mat := _material(Color(0.95, 0.9, 0.72), 0.2)
	tape_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	tape_mat.albedo_color.a = 0.85
	tape_mat.clearcoat_enabled = true
	tape.material_override = tape_mat
	tape.scale = Vector3(1.0, 1.1, 1.0)
	tape.position.y = 0.62
	roll.add_child(tape)
	var core := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.62
	cyl.bottom_radius = 0.62
	cyl.height = 1.2
	core.mesh = cyl
	core.material_override = _material(Color("b9874f"), 0.9, CARDBOARD_NORMAL)
	core.position.y = 0.6
	roll.add_child(core)
	return roll


func _update_mirrors() -> void:
	var i := 0
	while i < _mirrors.size():
		var entry := _mirrors[i]
		# Check before typing: a freed pickup can't be assigned to a typed variable.
		if not is_instance_valid(entry.source) or not (entry.source as CanvasItem).is_inside_tree():
			if is_instance_valid(entry.target):
				(entry.target as Node3D).queue_free()
			_mirrors.remove_at(i)
			continue
		_sync(entry.source, entry.target)
		i += 1


func _sync(source: CanvasItem, target: Node3D) -> void:
	var shown := _shown(source)
	target.visible = shown
	if not shown:
		return
	var ground := _ground_point(source)
	var tint := _tint(source)
	if source is Sprite2D:
		var sprite := source as Sprite2D
		var xform := sprite.get_global_transform()
		var lift := ground.y - xform.origin.y
		if target is Sprite3D:
			var s3 := target as Sprite3D
			s3.texture = sprite.texture
			s3.hframes = sprite.hframes
			s3.vframes = sprite.vframes
			s3.frame = sprite.frame
			s3.region_enabled = sprite.region_enabled
			s3.region_rect = sprite.region_rect
			s3.flip_h = sprite.flip_h != (xform.determinant() < 0.0)
			s3.pixel_size = absf(xform.get_scale().y) / PIXELS_PER_METRE
			s3.modulate = tint
			var height := 0.0
			if sprite.texture:
				height = sprite.texture.get_height() / float(maxi(1, sprite.vframes)) * s3.pixel_size
			target.position = to_desk(Vector2(xform.origin.x, ground.y), maxf(lift / PIXELS_PER_METRE, height * 0.5))
		else:
			target.position = to_desk(Vector2(xform.origin.x, ground.y))
	else:
		var label := source as Label
		var label3 := target as Label3D
		label3.text = label.text
		label3.modulate.a = tint.a
		var center := label.get_global_transform() * (label.size / 2.0)
		target.position = to_desk(Vector2(center.x, ground.y), 0.6 + (ground.y - center.y) / PIXELS_PER_METRE)


## The point on the floor a drawing stands on: its body or area, else its parent.
func _ground_point(item: Node) -> Vector2:
	var node := item.get_parent()
	while node != null and node != page:
		if node is CollisionObject2D:
			return (node as Node2D).global_position
		node = node.get_parent()
	var parent := item.get_parent() as Node2D
	return parent.global_position if parent else Vector2.ZERO


## Visible by its own flags and every ancestor's below the (hidden) page root.
func _shown(item: CanvasItem) -> bool:
	var node: Node = item
	while node != null and node != page:
		if node is CanvasItem and not (node as CanvasItem).visible:
			return false
		node = node.get_parent()
	return true


func _tint(item: CanvasItem) -> Color:
	var color := item.self_modulate
	var node: Node = item
	while node != null and node != page:
		if node is CanvasItem:
			color *= (node as CanvasItem).modulate
		node = node.get_parent()
	return color


func _update_camera(delta: float) -> void:
	var focus := Vector3.ZERO
	if _player and is_instance_valid(_player):
		focus = to_desk(_player.global_position)
	else:
		focus = to_desk(_page_bounds().get_center())
	var wanted := focus + camera_offset
	var weight := clampf(delta * 5.0, 0.0, 1.0)
	_camera.position = _camera.position.lerp(wanted, weight) if _camera.position != Vector3.ZERO else wanted
	_camera.look_at(_camera.position - camera_offset + Vector3(0, 0.6, 0), Vector3.UP)


# ------------------------------------------------------------------ helpers


func _page_bounds() -> Rect2:
	var bounds = page.get(&"bounds")
	return bounds if bounds is Rect2 else Rect2(0, 0, 2560, 1536)


func _material(color: Color, roughness: float, normal: Texture2D = null) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if normal:
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = 0.6
	return mat


func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	return mesh_instance

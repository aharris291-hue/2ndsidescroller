class_name DarkRig
extends Node2D
## Patch's cut-out puppet for the Dark Rebuild: one painted image skinned onto a
## Skeleton2D, so his limbs bend instead of the whole picture tilting.
##
## The mesh and bone weights are built at load time from the painting's alpha, so
## swapping in a new painting only needs new joint positions (tools/art/dark_assets.py
## measures them). Patch drives it every frame through `drive()`.

const TEXTURE := preload("res://assets/art/dark/patch.png")
## The painting cut into puppet layers (back to front) and the bones each one follows.
const LAYERS := [
	[preload("res://assets/art/dark/patch_arm_b.png"), [&"arm_b", &"fore_b"]],
	[preload("res://assets/art/dark/patch_body.png"),
		[&"hips", &"chest", &"head", &"thigh_f", &"shin_f", &"thigh_b", &"shin_b", &"tail"]],
	[preload("res://assets/art/dark/patch_arm_f.png"), [&"arm_f", &"fore_f", &"shears"]],
]
## Joint positions on the painting, in its pixels (written by tools/art/dark_assets.py).
const JOINTS := {
	&"hips": Vector2(101.3, 186.5), &"chest": Vector2(111.3, 131.4), &"neck": Vector2(131.4, 109.3),
	&"head": Vector2(156.4, 70.2), &"head_tip": Vector2(172.5, 20.1),
	&"shoulder_f": Vector2(147.4, 141.4), &"elbow_f": Vector2(176.5, 167.5), &"hand_f": Vector2(193.5, 205.6),
	&"shears_tip": Vector2(288.8, 280.8),
	&"shoulder_b": Vector2(71.2, 116.3), &"elbow_b": Vector2(42.1, 151.4), &"hand_b": Vector2(23.1, 196.5),
	&"hip_f": Vector2(124.8, 205.6), &"knee_f": Vector2(147.4, 268.2), &"foot_f": Vector2(175.0, 328.4),
	&"hip_b": Vector2(82.2, 205.6), &"knee_b": Vector2(63.2, 265.7), &"foot_b": Vector2(29.6, 340.9),
	&"tail": Vector2(58.2, 196.5), &"tail_tip": Vector2(9.5, 258.2),
}
## name, parent, joint it pivots on, joint it points to.
const BONES := [
	[&"hips", &"", &"hips", &"chest"],
	[&"chest", &"hips", &"chest", &"neck"],
	[&"head", &"chest", &"neck", &"head_tip"],
	[&"arm_f", &"chest", &"shoulder_f", &"elbow_f"],
	[&"fore_f", &"arm_f", &"elbow_f", &"hand_f"],
	[&"shears", &"fore_f", &"hand_f", &"shears_tip"],
	[&"arm_b", &"chest", &"shoulder_b", &"elbow_b"],
	[&"fore_b", &"arm_b", &"elbow_b", &"hand_b"],
	[&"thigh_f", &"hips", &"hip_f", &"knee_f"],
	[&"shin_f", &"thigh_f", &"knee_f", &"foot_f"],
	[&"thigh_b", &"hips", &"hip_b", &"knee_b"],
	[&"shin_b", &"thigh_b", &"knee_b", &"foot_b"],
	[&"tail", &"hips", &"tail", &"tail_tip"],
]
## Where Patch's feet touch the ground on the painting, and how big he is on screen.
const FEET := Vector2(112.0, 354.0)
const GRID := 9.0

## Height in pixels on screen.
@export var display_height := 150.0
## Where his feet sit relative to Patch's body origin.
@export var feet_offset := Vector2(0, 42)

var bones := {}
var _targets := {}
var _anim := 0.0
var _swing := 0.0
var _last_state := -1
var _last_step := -1
var _skeleton: Skeleton2D


func _ready() -> void:
	var s := display_height / float(TEXTURE.get_height())
	scale = Vector2(s, s)
	position = feet_offset
	var holder := Node2D.new()
	holder.position = -FEET
	add_child(holder)
	_skeleton = Skeleton2D.new()
	_skeleton.name = &"Skeleton"
	holder.add_child(_skeleton)
	for spec in BONES:
		var bone := Bone2D.new()
		bone.name = spec[0]
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length((JOINTS[spec[3]] - JOINTS[spec[2]]).length())
		bone.set_bone_angle((JOINTS[spec[3]] - JOINTS[spec[2]]).angle())
		var parent: Node = _skeleton if spec[1] == &"" else bones[spec[1]]
		var parent_origin: Vector2 = Vector2.ZERO if spec[1] == &"" else JOINTS[_bone_spec(spec[1])[2]]
		bone.position = JOINTS[spec[2]] - parent_origin
		parent.add_child(bone)
		bone.rest = bone.transform
		bones[spec[0]] = bone
		_targets[spec[0]] = 0.0
	for layer in LAYERS:
		var polygon := Polygon2D.new()
		polygon.texture = layer[0]
		holder.add_child(polygon)
		_build_mesh(polygon, layer[0], layer[1])


func _bone_spec(bone_name: StringName) -> Array:
	for spec in BONES:
		if spec[0] == bone_name:
			return spec
	return []


## A grid mesh over the painting's opaque pixels, each vertex weighted to its
## nearest bones so joints bend smoothly.
func _build_mesh(polygon: Polygon2D, texture: Texture2D, bone_names: Array) -> void:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var w := image.get_width()
	var h := image.get_height()
	var cols := int(ceil(w / GRID))
	var rows := int(ceil(h / GRID))
	var index := {}
	var points := PackedVector2Array()
	var triangles := []
	for cy in rows:
		for cx in cols:
			if not _cell_has_paint(image, cx, cy):
				continue
			var corners := [Vector2i(cx, cy), Vector2i(cx + 1, cy), Vector2i(cx + 1, cy + 1), Vector2i(cx, cy + 1)]
			var ids := []
			for c in corners:
				if not index.has(c):
					index[c] = points.size()
					points.append(Vector2(minf(c.x * GRID, w), minf(c.y * GRID, h)))
				ids.append(index[c])
			triangles.append(PackedInt32Array([ids[0], ids[1], ids[2]]))
			triangles.append(PackedInt32Array([ids[0], ids[2], ids[3]]))
	polygon.polygon = points
	polygon.uv = points
	polygon.polygons = triangles
	polygon.skeleton = polygon.get_path_to(_skeleton)
	var weights := {}
	for bone_name in bone_names:
		weights[bone_name] = PackedFloat32Array()
		weights[bone_name].resize(points.size())
	for i in points.size():
		var p := points[i]
		var best := []
		for bone_name in bone_names:
			var spec := _bone_spec(bone_name)
			var d := _segment_distance(p, JOINTS[spec[2]], JOINTS[spec[3]])
			best.append([d, bone_name])
		best.sort_custom(func(a, b): return a[0] < b[0])
		var total := 0.0
		var picks := []
		for k in mini(2, best.size()):
			var wgt := 1.0 / pow(best[k][0] * best[k][0] + 30.0, 2.0)
			picks.append([best[k][1], wgt])
			total += wgt
		for pick in picks:
			weights[pick[0]][i] = pick[1] / total
	for bone_name in bone_names:
		polygon.add_bone(_skeleton.get_path_to(bones[bone_name]), weights[bone_name])


func _cell_has_paint(image: Image, cx: int, cy: int) -> bool:
	var x0 := int(cx * GRID)
	var y0 := int(cy * GRID)
	for y in range(y0, mini(y0 + int(GRID) + 1, image.get_height()), 3):
		for x in range(x0, mini(x0 + int(GRID) + 1, image.get_width()), 3):
			if image.get_pixel(x, y).a > 0.05:
				return true
	return false


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Animation --------------------------------------------------------------------
# Angles are in degrees from the painted pose. Positive turns clockwise on screen;
# Patch faces right in the painting, so a negative turn on a leg swings it forward.

## Called by Patch every frame with what he's doing.
func drive(patch: Patch, delta: float) -> void:
	var t := {}
	for key in _targets:
		t[key] = 0.0
	var grounded := patch.is_on_floor() or patch.view_mode == PageView.Mode.TOP
	var speed := absf(patch.velocity.x) / patch.run_speed
	var state := patch.state
	if state != _last_state or (state == Patch.State.ATTACK and patch.combo_step != _last_step):
		_swing = 0.0
	_last_state = state
	_last_step = patch.combo_step
	_swing += delta
	match state:
		Patch.State.ATTACK:
			_pose_attack(t, patch)
		Patch.State.HEAVY:
			_pose_heavy(t, patch)
		Patch.State.FINISHER:
			_pose_finisher(t)
		Patch.State.GUARD:
			_pose_guard(t)
		Patch.State.MEND:
			_pose_mend(t)
		Patch.State.HURT:
			_pose_hurt(t)
		Patch.State.DASH:
			_pose_dash(t)
		Patch.State.SLAM:
			_pose_plunge(t)
		_:
			if not grounded:
				_pose_air(t, patch)
			elif speed > 0.1:
				_pose_run(t, speed, delta)
			else:
				_pose_idle(t, delta)
	var snap := 26.0 if state in [Patch.State.ATTACK, Patch.State.HEAVY, Patch.State.FINISHER, Patch.State.HURT] else 14.0
	for key in t:
		_targets[key] = lerpf(_targets[key], t[key], minf(1.0, snap * delta))
		bones[key].rotation = deg_to_rad(_targets[key])


func _pose_idle(t: Dictionary, delta: float) -> void:
	_anim += delta * 2.2
	var breath := sin(_anim)
	t[&"chest"] = 2.0 * breath
	t[&"head"] = -1.5 * breath + 2.0
	t[&"arm_f"] = -4.0 + 2.0 * breath
	t[&"fore_f"] = -6.0
	t[&"arm_b"] = 3.0 * breath
	t[&"tail"] = 6.0 * sin(_anim * 0.7)
	t[&"thigh_f"] = -3.0
	t[&"shin_f"] = 4.0


func _pose_run(t: Dictionary, speed: float, delta: float) -> void:
	_anim += delta * (9.0 + 5.0 * speed)
	var s := sin(_anim)
	var c := cos(_anim)
	var amp := clampf(speed, 0.3, 1.0)
	t[&"hips"] = 8.0 * amp
	t[&"chest"] = 4.0 * amp
	t[&"head"] = -8.0 * amp
	t[&"thigh_f"] = -34.0 * s * amp - 6.0
	t[&"thigh_b"] = 34.0 * s * amp - 6.0
	t[&"shin_f"] = maxf(0.0, 50.0 * -c) * amp + 8.0
	t[&"shin_b"] = maxf(0.0, 50.0 * c) * amp + 8.0
	t[&"arm_b"] = -32.0 * s * amp
	t[&"fore_b"] = -25.0 * amp
	t[&"arm_f"] = 14.0 * s * amp - 10.0
	t[&"fore_f"] = -18.0
	t[&"tail"] = 14.0 * c


func _pose_air(t: Dictionary, patch: Patch) -> void:
	var rising := patch.velocity.y < 0.0
	if rising:
		t[&"thigh_f"] = -48.0
		t[&"shin_f"] = 70.0
		t[&"thigh_b"] = 10.0
		t[&"shin_b"] = 45.0
		t[&"arm_b"] = -50.0
		t[&"arm_f"] = -25.0
		t[&"fore_f"] = -20.0
		t[&"hips"] = -4.0
	else:
		t[&"thigh_f"] = -18.0
		t[&"shin_f"] = 20.0
		t[&"thigh_b"] = 18.0
		t[&"shin_b"] = 10.0
		t[&"arm_b"] = -95.0
		t[&"fore_b"] = -30.0
		t[&"arm_f"] = -60.0
		t[&"fore_f"] = -15.0
		t[&"hips"] = 4.0
	t[&"tail"] = -20.0 if rising else 25.0


## Light cuts alternate between a falling slash and a rising one; the last hit is a thrust.
func _pose_attack(t: Dictionary, patch: Patch) -> void:
	var k := clampf(_swing / maxf(patch.attack_time, 0.01), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	match patch.get(&"_attack_kind"):
		Patch.Attack.THRUST:
			t[&"hips"] = 10.0
			t[&"chest"] = 8.0
			t[&"arm_f"] = lerpf(30.0, -38.0, e)
			t[&"fore_f"] = lerpf(40.0, -20.0, e)
			t[&"shears"] = lerpf(10.0, -12.0, e)
			t[&"thigh_f"] = -40.0
			t[&"shin_f"] = 20.0
			t[&"thigh_b"] = 30.0
			t[&"arm_b"] = 40.0
		Patch.Attack.OVERHEAD:
			t[&"chest"] = -10.0
			t[&"head"] = -15.0
			t[&"arm_f"] = lerpf(20.0, -150.0, e)
			t[&"fore_f"] = lerpf(10.0, -30.0, e)
		_:
			var rising := patch.combo_step % 2 == 0
			var from := 5.0 if rising else -120.0
			var to := -120.0 if rising else 5.0
			t[&"arm_f"] = lerpf(from, to, e)
			t[&"fore_f"] = lerpf(-40.0, -15.0, e) if not rising else lerpf(-15.0, -45.0, e)
			t[&"shears"] = lerpf(-20.0, 0.0, e) if not rising else lerpf(0.0, -25.0, e)
			t[&"chest"] = lerpf(-8.0, 10.0, e) if not rising else lerpf(10.0, -8.0, e)
			t[&"hips"] = 6.0
			t[&"thigh_f"] = -30.0
			t[&"shin_f"] = 18.0
			t[&"thigh_b"] = 22.0
			t[&"arm_b"] = lerpf(-20.0, 20.0, e)
			t[&"head"] = -5.0


func _pose_heavy(t: Dictionary, patch: Patch) -> void:
	var phase: int = patch.get(&"_heavy_phase")
	var kind: int = patch.get(&"_attack_kind")
	if kind == Patch.Attack.LAUNCHER and phase > 0:
		var e := clampf(_swing / 0.12, 0.0, 1.0)
		t[&"arm_f"] = lerpf(50.0, -150.0, e)
		t[&"fore_f"] = lerpf(20.0, -20.0, e)
		t[&"chest"] = lerpf(12.0, -14.0, e)
		t[&"thigh_f"] = -25.0
		t[&"thigh_b"] = 25.0
		return
	if phase <= 1:
		# Wind up: the shears drawn back over his shoulder, weight on the back foot.
		var shake := sin(Time.get_ticks_msec() * 0.06) * 1.5 * patch.charge_level
		t[&"chest"] = -14.0 + shake
		t[&"hips"] = -6.0
		t[&"head"] = -6.0
		t[&"arm_f"] = -165.0
		t[&"fore_f"] = -35.0
		t[&"shears"] = -20.0
		t[&"arm_b"] = 45.0
		t[&"fore_b"] = -40.0
		t[&"thigh_f"] = -28.0
		t[&"shin_f"] = 22.0
		t[&"thigh_b"] = 20.0
		t[&"shin_b"] = 25.0
	else:
		# The cut comes down hard and he follows through, low.
		t[&"chest"] = 18.0
		t[&"hips"] = 12.0
		t[&"head"] = -10.0
		t[&"arm_f"] = -8.0
		t[&"fore_f"] = -25.0
		t[&"shears"] = 0.0
		t[&"arm_b"] = 25.0
		t[&"thigh_f"] = -45.0
		t[&"shin_f"] = 35.0
		t[&"thigh_b"] = 35.0
		t[&"shin_b"] = 10.0


func _pose_finisher(t: Dictionary) -> void:
	var e := clampf(_swing / 0.2, 0.0, 1.0)
	t[&"chest"] = lerpf(-12.0, 20.0, e)
	t[&"hips"] = 10.0
	t[&"arm_f"] = lerpf(-150.0, 5.0, e)
	t[&"fore_f"] = lerpf(-30.0, -10.0, e)
	t[&"arm_b"] = lerpf(-60.0, 25.0, e)
	t[&"thigh_f"] = -50.0
	t[&"shin_f"] = 50.0
	t[&"thigh_b"] = 40.0


func _pose_guard(t: Dictionary) -> void:
	# Shears raised across his body, blade up, bracing.
	t[&"chest"] = -6.0
	t[&"head"] = 6.0
	t[&"arm_f"] = -70.0
	t[&"fore_f"] = -55.0
	t[&"shears"] = -30.0
	t[&"arm_b"] = -40.0
	t[&"fore_b"] = -60.0
	t[&"thigh_f"] = -22.0
	t[&"shin_f"] = 20.0
	t[&"thigh_b"] = 18.0
	t[&"shin_b"] = 18.0


func _pose_mend(t: Dictionary) -> void:
	var p := sin(Time.get_ticks_msec() * 0.012)
	t[&"chest"] = 16.0
	t[&"head"] = 18.0
	t[&"hips"] = 4.0
	t[&"arm_b"] = -70.0 + 6.0 * p
	t[&"fore_b"] = -80.0
	t[&"arm_f"] = 10.0
	t[&"fore_f"] = -50.0
	t[&"thigh_f"] = -20.0
	t[&"shin_f"] = 40.0
	t[&"thigh_b"] = 15.0
	t[&"shin_b"] = 30.0


func _pose_hurt(t: Dictionary) -> void:
	t[&"hips"] = -10.0
	t[&"chest"] = -16.0
	t[&"head"] = -22.0
	t[&"arm_f"] = 35.0
	t[&"arm_b"] = -60.0
	t[&"thigh_f"] = -25.0
	t[&"thigh_b"] = 15.0


func _pose_dash(t: Dictionary) -> void:
	t[&"hips"] = 18.0
	t[&"chest"] = 10.0
	t[&"thigh_f"] = -40.0
	t[&"shin_f"] = 60.0
	t[&"thigh_b"] = 40.0
	t[&"shin_b"] = 40.0
	t[&"arm_f"] = 20.0
	t[&"arm_b"] = 50.0
	t[&"tail"] = 30.0


func _pose_plunge(t: Dictionary) -> void:
	# Both hands on the shears, blade pointed straight down.
	t[&"chest"] = 14.0
	t[&"arm_f"] = 25.0
	t[&"fore_f"] = 30.0
	t[&"shears"] = 25.0
	t[&"arm_b"] = -30.0
	t[&"fore_b"] = -70.0
	t[&"thigh_f"] = -60.0
	t[&"shin_f"] = 80.0
	t[&"thigh_b"] = -20.0
	t[&"shin_b"] = 70.0

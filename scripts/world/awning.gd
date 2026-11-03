class_name Awning
extends Node2D
## A rolled canvas awning tied up on a rope. Cut the rope (any of Patch's cuts) and the
## canvas drops, sheltering the paper below it from the rain: every SoakedPaper sheet
## under it, within `reach` px, dries out and holds for good. Once cut, it stays down,
## even after a reload.
##
## Stands on its origin like the rest of the text-map entities: the rope is at the top
## of the cell it is placed in.

const ROLLED := preload("res://assets/art/dark/props/awning_rolled.png")
const CANVAS := preload("res://assets/art/dark/props/awning_canvas.png")
const CLEAT := preload("res://assets/art/dark/props/piton.png")

## How wide the shelter is (the canvas stretches to it).
@export var width := 224.0
## How far below the rope a sheet can be and still be sheltered.
@export var reach := 640.0
@export_multiline var cut_caption := ""
## Where its rope is tied off, relative to the awning (zero: cut it at the awning).
## A high awning ties off down on the ground, so Patch can cut it from there.
@export var cleat_offset := Vector2.ZERO

signal dropped

var is_down := false
var _sprite: Sprite2D
var _rope: Area2D
var _line: Line2D


func _ready() -> void:
	add_to_group(&"awnings")
	_sprite = Sprite2D.new()
	_sprite.texture = ROLLED
	_sprite.centered = false
	_sprite.scale.x = width / ROLLED.get_width()
	_sprite.position = Vector2(-width / 2.0, -64)
	add_child(_sprite)
	_rope = Area2D.new()
	_rope.collision_layer = 0
	_rope.collision_mask = 8
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 56)
	shape.shape = rect
	shape.position = Vector2(0, -40)
	if cleat_offset != Vector2.ZERO:
		# The rope runs down from the awning's end to a cleat; the cut is there.
		_line = Line2D.new()
		_line.width = 4.0
		_line.default_color = Color(0.3, 0.24, 0.17)
		var end := Vector2(-width / 2.0 if cleat_offset.x < 0.0 else width / 2.0, -58)
		_line.points = PackedVector2Array([end, cleat_offset + Vector2(0, -40)])
		add_child(_line)
		var cleat := Sprite2D.new()
		cleat.texture = CLEAT
		cleat.position = cleat_offset + Vector2(0, -28)
		cleat.scale = Vector2(0.8, 0.8)
		add_child(cleat)
		rect.size = Vector2(72, 96)
		shape.position = cleat_offset + Vector2(0, -48)
	_rope.add_child(shape)
	add_child(_rope)
	if GameState.is_collected(_unique_id()):
		# Deferred, so the sheets below are in the tree to be dried.
		_set_down.call_deferred(false)


func _physics_process(_delta: float) -> void:
	if is_down:
		return
	for area in _rope.get_overlapping_areas():
		var hitbox := area as Hitbox
		if hitbox and hitbox.active and hitbox.owner is Patch:
			cut()
			return


## Drops the canvas and dries what is under it.
func cut() -> void:
	if is_down:
		return
	GameState.mark_collected(_unique_id())
	AudioManager.play_sfx(&"shears", 0.8, -2.0)
	if not cut_caption.is_empty():
		DialogueUI.narrate(cut_caption)
	_set_down(true)


func _set_down(animate: bool) -> void:
	is_down = true
	set_physics_process(false)
	_sprite.texture = CANVAS
	_sprite.scale.x = width / CANVAS.get_width()
	if _line:
		_line.visible = false
	if animate:
		_sprite.scale.y = 0.2
		create_tween().tween_property(_sprite, "scale:y", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for sheet in sheltered():
		sheet.dry_out(1.2 if animate else 0.0)
	dropped.emit()


## The sheets of soaked paper this awning shelters.
func sheltered() -> Array[SoakedPaper]:
	var out: Array[SoakedPaper] = []
	for node in get_tree().get_nodes_in_group(&"soaked_paper"):
		var sheet := node as SoakedPaper
		if sheet == null:
			continue
		var d := sheet.global_position - global_position
		if absf(d.x) <= width / 2.0 + 40.0 and d.y > 0.0 and d.y <= reach:
			out.append(sheet)
	return out


func _unique_id() -> String:
	return "%s:%s" % [owner.scene_file_path if owner else "", get_path()]

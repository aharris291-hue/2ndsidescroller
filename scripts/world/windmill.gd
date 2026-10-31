class_name Windmill
extends Node2D
## A pop-up windmill. Its sails turn while `spinning`; with gondolas, cardboard seats
## hang from the sail tips and stay level, so Patch can ride them up like a wheel.
## Link a PullTab to start (or stop) the sails.

@export var spinning := false
@export var spin_speed := 0.6
@export var gondola_count := 0
@export var radius := 190.0
@export var tab: PullTab

var _angle := 0.0
var _gondolas: Array[AnimatableBody2D] = []

@onready var sails: Node2D = $Sails


func _ready() -> void:
	for child in get_children():
		if child is AnimatableBody2D:
			_gondolas.append(child)
	if tab:
		tab.toggled.connect(func(pulled: bool) -> void: spinning = pulled)
	_place_gondolas()


func _physics_process(delta: float) -> void:
	if not spinning:
		return
	_angle = wrapf(_angle + spin_speed * delta, 0.0, TAU)
	sails.rotation = _angle
	_place_gondolas()


func _place_gondolas() -> void:
	for i in _gondolas.size():
		var a := _angle + TAU * i / _gondolas.size()
		_gondolas[i].position = sails.position + Vector2.from_angle(a) * radius

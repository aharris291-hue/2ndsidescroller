class_name BookFall
extends Node2D
## Books shaken loose from the shelves above (P-2). While Patch is within `width`
## of this node, a book picks a spot near him, sheds dust there for `warning` seconds,
## then drops. A dropped book hurts on the way down and lies still once it lands.


@export var width := 1920.0
@export var interval := 2.6
@export var warning := 0.8
## How far above Patch the books start.
@export var drop_height := 620.0
## Only while Patch is between these heights (page coordinates).
@export var min_y := -INF
@export var max_y := INF

var _left := 2.0


func _physics_process(delta: float) -> void:
	if DialogueUI.is_active():
		return
	_left -= delta
	if _left > 0.0:
		return
	_left = interval * randf_range(0.8, 1.25)
	var player := get_tree().get_first_node_in_group(&"player") as Patch
	if player == null or player.global_position.y < min_y or player.global_position.y > max_y:
		return
	var x := clampf(player.global_position.x + player.velocity.x * 0.5 + randf_range(-90, 90), 48.0, width - 48.0)
	_drop_at(Vector2(x, player.global_position.y - drop_height))


func _drop_at(start: Vector2) -> void:
	# Dust trickles first: the tell.
	var dust := CPUParticles2D.new()
	dust.position = start + Vector2(0, 40)
	dust.amount = 18
	dust.lifetime = 0.9
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(36, 4)
	dust.gravity = Vector2(0, 520)
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 4.0
	dust.color = Color(0.75, 0.7, 0.62, 0.8)
	add_child(dust)
	get_tree().create_timer(warning).timeout.connect(_spawn_book.bind(start, dust))


func _spawn_book(start: Vector2, dust: CPUParticles2D) -> void:
	if is_instance_valid(dust):
		dust.emitting = false
		get_tree().create_timer(1.0).timeout.connect(dust.queue_free)
	var book := FallingBook.new()
	book.position = start
	add_child(book)

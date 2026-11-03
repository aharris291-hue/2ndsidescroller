extends Page
## 1-3 The Drowned Chapel, seen from above. Three rooms, each shut by an iron grille
## until every bell stone in it has a pew dragged over it:
##   the nave (one stone) opens the aisles; the aisles (two) open the crypt; the
##   crypt's three ring the cracked bell, which drains the chapel and opens the way out.
## Each room stays solved once it has been ("chapel_room_1", "chapel_room_2",
## "chapel_bell_rung"); the pews themselves reset whenever the page is left.

const ROOM_WIDTH := 20 * 64.0
const FLAGS := ["chapel_room_1", "chapel_room_2", "chapel_bell_rung"]
const CAPTIONS := [
	"Somewhere under the floor, a chain ran out, and the grille sank.",
	"The second grille went down. Beyond it, steps, and the cold of the crypt.",
	"",
]
const BELL := preload("res://assets/art/dark/props/chapel_bell.png")

var _gates: Array[ChapelGate] = []
var _stones := [[], [], []]
var _bell: Sprite2D


func _ready() -> void:
	super._ready()
	var level := get_node(^"Level")
	for child in level.get_children():
		if child is ChapelGate:
			_gates.append(child)
		elif child is BellStone:
			_stones[room_of(child.position.x)].append(child)
			child.pressed_changed.connect(_on_stone.bind(room_of(child.position.x)))
	_gates.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.x < b.position.x)
	_bell = Sprite2D.new()
	_bell.texture = BELL
	_bell.position = Vector2(2 * ROOM_WIDTH + 10 * 64.0, 7 * 64.0 + 32.0)
	_bell.z_index = 2
	add_child(_bell)
	for i in FLAGS.size():
		if GameState.get_flag(FLAGS[i]) and i < _gates.size():
			_gates[i].open(true)


static func room_of(x: float) -> int:
	return clampi(floori(x / ROOM_WIDTH), 0, 2)


func room_solved(room: int) -> bool:
	for stone: BellStone in _stones[room]:
		if not stone.pressed:
			return false
	return not _stones[room].is_empty()


func _on_stone(_pressed: bool, room: int) -> void:
	if GameState.get_flag(FLAGS[room]) or not room_solved(room):
		return
	GameState.set_flag(FLAGS[room])
	if room < 2:
		_gates[room].open()
		DialogueUI.narrate(CAPTIONS[room])
		return
	_ring_bell()


func _ring_bell() -> void:
	AudioManager.play_sfx(&"checkpoint", 0.5)
	var swing := create_tween()
	for i in 6:
		swing.tween_property(_bell, "rotation", 0.25 if i % 2 == 0 else -0.25, 0.18)
	swing.tween_property(_bell, "rotation", 0.0, 0.2)
	DialogueUI.narrate("Three ropes, one bell. It rang once, cracked and enormous, and the font at the head of the nave tipped over, and the water went down through the floor as if it had been called.")
	if _gates.size() > 2:
		_gates[2].open()

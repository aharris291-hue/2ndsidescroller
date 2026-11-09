extends Page
## 2-3 The Lamp Room, seen from above. Three rooms round the great lamp, each shut by an
## iron grille. In each, a cracked lens in the wall throws the lamp's beam; Patch turns
## swivel mirrors to carry it through every cold wick in the room at once. That opens
## the room's grille ("lamp_room_1", "lamp_room_2"); the last room lights the great
## lamp itself ("lighthouse_lit") and opens the way down to the harbour.
##
## The beam runs cell to cell on the 64 px grid: stone ('$'), grilles and lenses stop
## it, mirrors turn it, wicks let it through. Mirrors keep their angle only for the
## visit; a solved room stays solved, its wicks burning.

const TILE := 64
const ROOM_WIDTH := 20 * TILE
const FLAGS := ["lamp_room_1", "lamp_room_2", "lighthouse_lit"]
const CAPTIONS := [
	"Every wick in the room caught at once. Somewhere in the wall a weight dropped, and the grille went down.",
	"The second grille sank. Past it, the great lamp itself, cold, with its brass gone green.",
	"",
]
const MAX_STEPS := 600

var _level: TextLevel
var _gates: Array[ChapelGate] = []
var _mirrors := {}
var _wicks := {}
var _sources: Array[BeamSource] = []
var _beams: Array[Line2D] = []


func _ready() -> void:
	super._ready()
	_level = get_node(^"Level") as TextLevel
	for child in _level.get_children():
		if child is ChapelGate:
			_gates.append(child)
		elif child is BeamMirror:
			_mirrors[cell_of(child.position)] = child
			child.turned.connect(trace)
		elif child is BeamWick:
			_wicks[cell_of(child.position)] = child
		elif child is BeamSource:
			_sources.append(child)
	_gates.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.x < b.position.x)
	_sources.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.x < b.position.x)
	for source in _sources:
		var line := Line2D.new()
		line.width = 10.0
		line.default_color = Color(1.0, 0.82, 0.5, 0.85)
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		line.material = glow
		line.z_index = 1
		add_child(line)
		_beams.append(line)
	for i in FLAGS.size():
		if GameState.get_flag(FLAGS[i]) and i < _gates.size():
			_gates[i].open(true)
	trace()


## The grid cell a text-map entity sits in (they stand on a cell's bottom edge, or are
## offset up to its middle).
static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori((pos.y - 1.0) / TILE))


static func room_of_cell(cell: Vector2i) -> int:
	return clampi(cell.x * TILE / ROOM_WIDTH, 0, 2)


func _blocks(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= _level.rows.size() or cell.x < 0 or cell.x >= _level.rows[cell.y].length():
		return true
	if _level.rows[cell.y][cell.x] == "$":
		return true
	for gate in _gates:
		var g := cell_of(gate.position)
		# A grille fills its own cell and the one above it.
		if cell.x == g.x and (cell.y == g.y or cell.y == g.y - 1):
			return true
	for source in _sources:
		if cell_of(source.position) == cell:
			return true
	return false


## Runs every lens's beam through the mirrors, lights the wicks it crosses, and opens
## any room whose wicks are all burning.
func trace() -> void:
	var burning := {}
	for i in _sources.size():
		var source := _sources[i]
		var cell := cell_of(source.position)
		var dir := source.direction
		var points := PackedVector2Array([_centre(cell)])
		var seen := {}
		for _step in MAX_STEPS:
			var next := cell + dir
			if _blocks(next):
				points.append(_centre(cell) + Vector2(dir) * TILE * 0.5)
				break
			cell = next
			if seen.has([cell, dir]):
				points.append(_centre(cell))
				break
			seen[[cell, dir]] = true
			if _wicks.has(cell):
				burning[cell] = true
			if _mirrors.has(cell):
				points.append(_centre(cell))
				dir = (_mirrors[cell] as BeamMirror).reflect(dir)
		_beams[i].points = points
	for cell: Vector2i in _wicks:
		var room := room_of_cell(cell)
		(_wicks[cell] as BeamWick).set_lit(burning.has(cell) or GameState.get_flag(FLAGS[room]))
	for room in 3:
		if GameState.get_flag(FLAGS[room]):
			continue
		var any := false
		var all := true
		for cell: Vector2i in _wicks:
			if room_of_cell(cell) == room:
				any = true
				if not burning.has(cell):
					all = false
		if any and all:
			_solve(room)


func room_solved(room: int) -> bool:
	return GameState.get_flag(FLAGS[room])


func _solve(room: int) -> void:
	GameState.set_flag(FLAGS[room])
	AudioManager.play_sfx(&"checkpoint", 0.6 + room * 0.1)
	if room < _gates.size():
		_gates[room].open()
	if room < 2:
		DialogueUI.narrate(CAPTIONS[room])
		return
	DialogueUI.narrate("The beam came round the last mirror and into the great lamp, and the lamp took it, and for the first time since the flood the light went out over Lanternfold. Down in the harbour, one by one, the lanterns answered.")


func _centre(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE, TILE) * 0.5

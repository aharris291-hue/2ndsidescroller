@tool
class_name TextLevel
extends Node2D
## Builds a level from a text map: one character per 64 px cell, read from `map_file`.
## Add it as a child of a Page. When the page loads it lays the tiles (picking edge and
## corner pieces from each cell's neighbours), places the entities from the legend,
## adds the Start marker, and sets the page's bounds to the map's size.
##
## Terrain (rows of the region's tile atlas, see tools/art/dark_tileset.py). Each
## character is a role; `region` decides what it looks like (shelf shown):
##   #  main ground (shelf wood)      %  built (stacked books)
##   &  soft ground (sodden earth)    $  hard stone (damp stone)
##   -  one-way plank (jump up through it)
##   =  ice: hard stone with black ice on top (an IceSheet: Patch skates on it)
## Built-in entities:
##   @  Start (where a fresh visit spawns Patch)     k  Bookmark (checkpoint)
##   s  Soggy        d  ink drip spawner (drips onto the floor below it)
##   ~  settled ink (InkPool): deadly without the Blot Dive, swum through with it
##   > < ^ v  ink running that way (an InkCurrent inside the pool)
##   |  updraft (Gatefold Fair): each column of them is one Updraft, two tiles wide;
##      entity_props["|"] sets its properties (blow_time, rest_time, phase)
## Anything else ('.' or space included) is empty, unless `entities` names it.
## Lines that start with ';' are comments.
##
## `entities` maps any other character to a scene (or a script for a node that builds
## itself, like StoryTrigger), and `entity_props` maps the same
## character to properties to set on each instance (an "offset" key moves it from the
## cell's bottom centre). Each instance is named "<name>_<column>_<row>", so the ids
## of one-time pickups stay the same between visits.

const TILE := 64
## Painted tilesets by region (tools/art/dark_tileset.py).
const REGION_TILESETS := {
	"shelf": "res://resources/dark_tiles.tres",
	"meadow": "res://resources/dark_tiles_meadow.tres",
	"harbor": "res://resources/dark_tiles_harbor.tres",
	"marsh": "res://resources/dark_tiles_marsh.tres",
	"peaks": "res://resources/dark_tiles_peaks.tres",
	"fair": "res://resources/dark_tiles_fair.tres",
	"index": "res://resources/dark_tiles_index.tres",
	"gutter": "res://resources/dark_tiles_gutter.tres",
}
const TERRAIN := {"#": 0, "%": 1, "&": 2, "$": 3, "=": 3}
const ICE := "="
const INK := "~<>^v"
## Ink that runs: an InkCurrent each way (it carries a Blot-Diving Patch).
const CURRENTS := {">": Vector2.RIGHT, "<": Vector2.LEFT, "^": Vector2.UP, "v": Vector2.DOWN}
const CURRENT_STRENGTH := 320.0
const PLANK := "-"
const UPDRAFT := "|"
const PLANK_COLUMN := 7
const BUILT_IN := {
	"k": preload("res://scenes/world/bookmark.tscn"),
	"s": preload("res://scenes/enemies/soggy.tscn"),
}

@export_file("*.txt") var map_file := ""
## Which region's painted tiles to lay (a key of REGION_TILESETS).
@export_enum("shelf", "meadow", "harbor", "marsh", "peaks", "fair", "index", "gutter") var region := "shelf"
## Extra legend: character -> PackedScene or Script.
@export var entities: Dictionary = {}
## Character -> {property: value}; "offset" (Vector2) shifts the instance.
@export var entity_props: Dictionary = {}
## Material for planks: the wood row by default.
@export var plank_material := 0
## Rebuild in the editor so the layout can be seen without running the game.
@export var preview_in_editor := false:
	set(value):
		preview_in_editor = false
		if Engine.is_editor_hint() and is_inside_tree():
			build()

var rows: PackedStringArray = []
var tiles: TileMapLayer
var _built := false


# Build as soon as the page instance gives us a parent, before anything enters the
# tree, so every entity's owner is already the page when its _ready runs (bookmarks
# and one-time pickups need it).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED and not Engine.is_editor_hint() and not is_inside_tree():
		build()


func _ready() -> void:
	if Engine.is_editor_hint() or _built:
		return
	build()


## Size of the map in pixels.
func map_size() -> Vector2:
	var width := 0
	for row in rows:
		width = maxi(width, row.length())
	return Vector2(width * TILE, rows.size() * TILE)


## The cell's bottom centre, where things stand.
static func cell_floor(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE / 2.0, (cell.y + 1) * TILE)


func build() -> void:
	_built = true
	for child in get_children():
		child.free()
	rows = load_rows(map_file)
	tiles = TileMapLayer.new()
	tiles.name = &"Tiles"
	tiles.tile_set = load(REGION_TILESETS.get(region, REGION_TILESETS["shelf"]))
	add_child(tiles)
	var page := get_parent()
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var c := row[x]
			if TERRAIN.has(c):
				tiles.set_cell(Vector2i(x, y), 0, Vector2i(_piece(x, y), TERRAIN[c]))
			elif c == PLANK:
				tiles.set_cell(Vector2i(x, y), 0, Vector2i(PLANK_COLUMN, plank_material))
			elif INK.contains(c) or c == UPDRAFT:
				pass
			elif not Engine.is_editor_hint():
				_place(c, Vector2i(x, y), page)
	if not Engine.is_editor_hint():
		_add_blocks(INK, func(span: Vector2i, y: int, top: bool) -> Node2D:
			var pool := InkPool.new()
			pool.name = "Ink_%d_%d" % [span.x, y]
			pool.surface = top
			return pool)
		for c in CURRENTS:
			_add_blocks(c, func(span: Vector2i, y: int, _top: bool) -> Node2D:
				var current := InkCurrent.new()
				current.name = "Current_%d_%d" % [span.x, y]
				current.direction = CURRENTS[c]
				current.strength = CURRENT_STRENGTH
				return current)
	if not Engine.is_editor_hint():
		_add_ice()
		_add_updrafts()
	if not Engine.is_editor_hint() and page is Page:
		var size := map_size()
		(page as Page).bounds = Rect2(Vector2.ZERO, size)
		_add_edges(size)


static func load_rows(path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("TextLevel: can't open map %s" % path)
		return out
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with(";"):
			continue
		out.append(line.rstrip(" \r"))
	# Drop trailing blank lines so the map's height is what was drawn.
	while out.size() > 0 and out[out.size() - 1].strip_edges().is_empty():
		out.remove_at(out.size() - 1)
	return out


func _solid(x: int, y: int) -> bool:
	if y < 0 or y >= rows.size():
		return y >= rows.size()  # below the map counts as ground, above it as air
	if x < 0 or x >= rows[y].length():
		return true  # the page edges are walls
	return TERRAIN.has(rows[y][x])


## Atlas column for a solid cell: tops and corners where it meets air, sides where it
## meets air left or right, fill (two variants, hashed so they don't checker) inside.
func _piece(x: int, y: int) -> int:
	var open_up := not _solid(x, y - 1)
	var open_left := not _solid(x - 1, y)
	var open_right := not _solid(x + 1, y)
	if open_up:
		if open_left and not open_right:
			return 3
		if open_right and not open_left:
			return 4
		return 2
	if open_left and not open_right:
		return 5
	if open_right and not open_left:
		return 6
	return 1 if (x * 73856093 ^ y * 19349663) & 4 else 0


func _place(c: String, cell: Vector2i, page: Node) -> void:
	if c == "@":
		var start := Marker2D.new()
		start.name = &"Start"
		start.position = cell_floor(cell) + Vector2(0, -4)
		start.add_to_group(&"spawn_points")
		add_child(start)
		return
	if c == "d":
		var drips := DripSpawner.new()
		drips.name = "Drips_%d_%d" % [cell.x, cell.y]
		drips.position = Vector2(cell.x * TILE, cell.y * TILE)
		drips.width = TILE
		drips.interval = 2.4
		drips.floor_y = _floor_below(cell)
		drips.active_range = 900.0
		add_child(drips)
		return
	var source: Resource = entities.get(c, BUILT_IN.get(c))
	var node: Node2D
	if source is PackedScene:
		node = (source as PackedScene).instantiate() as Node2D
	elif source is Script:
		node = (source as Script).new() as Node2D
	if node == null:
		return
	node.name = "%s_%d_%d" % [source.resource_path.get_file().get_basename(), cell.x, cell.y]
	node.position = cell_floor(cell)
	var props: Dictionary = entity_props.get(c, {})
	for key in props:
		if key == "offset":
			node.position += props[key]
		else:
			node.set(key, props[key])
	add_child(node)
	# Bookmarks and pickups key their saved state off the page that owns them.
	node.owner = page


## Ink: each row's runs of `chars` become blocks, and a run with the same span on the
## row below grows its block downward, so a pool is a few rectangles, not one per cell.
## `make` builds each block's node (an InkPool or InkCurrent, both with a `size` from a
## top-left origin); `top` is true for a block with no ink above it.
func _add_blocks(chars: String, make: Callable) -> void:
	var open := {}  # Vector2i(x0, x1) -> block still growing down
	var blocks: Array[Node2D] = []
	for y in rows.size():
		var row := rows[y]
		var next := {}
		var x := 0
		while x < row.length():
			if not chars.contains(row[x]):
				x += 1
				continue
			var x0 := x
			while x < row.length() and chars.contains(row[x]):
				x += 1
			var span := Vector2i(x0, x - 1)
			if open.has(span):
				var grown: Node2D = open[span]
				grown.size.y += TILE
				next[span] = grown
				continue
			var top := y == 0 or x0 >= rows[y - 1].length() or not INK.contains(rows[y - 1][x0])
			var block: Node2D = make.call(span, y, top)
			block.position = Vector2(x0 * TILE, y * TILE)
			block.size = Vector2((x - x0) * TILE, TILE)
			next[span] = block
			blocks.append(block)
		open = next
	for block in blocks:
		add_child(block)


## Ice: an IceSheet along each run of '=' cells with open air above them.
func _add_ice() -> void:
	for y in rows.size():
		var row := rows[y]
		var x := 0
		while x < row.length():
			if row[x] != ICE or _solid(x, y - 1):
				x += 1
				continue
			var x0 := x
			while x < row.length() and row[x] == ICE and not _solid(x, y - 1):
				x += 1
			var sheet := IceSheet.new()
			sheet.name = "Ice_%d_%d" % [x0, y]
			sheet.position = Vector2(x0 * TILE, y * TILE)
			sheet.size = Vector2((x - x0) * TILE, TILE)
			add_child(sheet)


## Updrafts: each vertical run of '|' becomes one Updraft, its foot on the run's bottom.
func _add_updrafts() -> void:
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] != UPDRAFT or (y > 0 and x < rows[y - 1].length() and rows[y - 1][x] == UPDRAFT):
				continue
			var y1 := y
			while y1 + 1 < rows.size() and x < rows[y1 + 1].length() and rows[y1 + 1][x] == UPDRAFT:
				y1 += 1
			var draft := Updraft.new()
			draft.name = "Updraft_%d_%d" % [x, y]
			draft.size = Vector2(TILE * 2, (y1 - y + 1) * TILE)
			draft.position = Vector2(x * TILE + TILE / 2.0, (y1 + 1) * TILE)
			var props: Dictionary = entity_props.get(UPDRAFT, {})
			for key in props:
				draft.set(key, props[key])
			add_child(draft)


func _floor_below(cell: Vector2i) -> float:
	for y in range(cell.y + 1, rows.size()):
		if cell.x < rows[y].length() and (TERRAIN.has(rows[y][cell.x]) or rows[y][cell.x] == PLANK):
			return y * TILE
	return rows.size() * TILE


func _add_edges(size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = &"PageEdges"
	for side in [[Vector2(1, 0), 0.0], [Vector2(-1, 0), size.x]]:
		var shape := CollisionShape2D.new()
		var boundary := WorldBoundaryShape2D.new()
		boundary.normal = side[0]
		shape.shape = boundary
		shape.position = Vector2(side[1], 0)
		body.add_child(shape)
	add_child(body)

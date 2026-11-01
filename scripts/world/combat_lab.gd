extends Page
## The Combat Lab: a practice page for the redesigned combat (milestone M1).
## Reached from the title screen. Nothing here is saved. It has four stations:
## a cutting post, a sparring post that fights back, platforms over a post for
## air combos and the Plunge, and a pen of Soggies that refills when it's empty.

const SOGGY := preload("res://scenes/enemies/soggy.tscn")
const GROUND_ROW := 15
const WIDTH_TILES := 60
const SOGGY_SPOTS := [Vector2(3000, 900), Vector2(3260, 900), Vector2(3520, 900)]

var _pen: Array = []
var _refill_left := 0.0

@onready var ground: TileMapLayer = $Ground
@onready var signs: Node2D = $Signs


func _ready() -> void:
	GameState.sandbox = true
	for ability in [&"crease_swipe", &"fold_dash"]:
		if not GameState.has_ability(ability):
			GameState.abilities.append(ability)
	GameState.health = GameState.max_health
	GameState.thread = 1.0
	_build_ground()
	super._ready()
	_add_signs()
	_fill_pen()


func _physics_process(delta: float) -> void:
	var alive := []
	for soggy in _pen:
		if is_instance_valid(soggy):
			alive.append(soggy)
	_pen = alive
	if _pen.is_empty():
		_refill_left -= delta
		if _refill_left <= 0.0:
			_fill_pen()
	else:
		_refill_left = 2.0


func _build_ground() -> void:
	for x in WIDTH_TILES:
		ground.set_cell(Vector2i(x, GROUND_ROW), 0, Vector2i(0, 0))
		ground.set_cell(Vector2i(x, GROUND_ROW + 1), 0, Vector2i(1, 0))
	# Two ledges above the third post, for air combos and the Plunge.
	for x in range(28, 32):
		ground.set_cell(Vector2i(x, 11), 0, Vector2i(2, 0))
	for x in range(35, 39):
		ground.set_cell(Vector2i(x, 9), 0, Vector2i(2, 0))


func _fill_pen() -> void:
	for spot in SOGGY_SPOTS:
		var soggy := SOGGY.instantiate()
		soggy.position = spot
		soggy.set("scrap_drop", 0)
		$Actors.add_child(soggy)
		_pen.append(soggy)


func _add_signs() -> void:
	var h := func(action: StringName) -> String: return InputGlyphs.hint(action)
	_sign(Vector2(420, 330), "COMBAT LAB\nNothing here is saved. Pause to leave.\nThread fills as your cuts land. Hold %s to spend a charge and Mend." % h.call(&"mend"))
	_sign(Vector2(560, 560), "THE CUTTING POST\n%s x4: light combo, ending in a thrust\n%s: heavy cut (wears down Hold)\nHold %s: charge (3 levels; level 3 is the Full Cut)\nUp + %s: launcher\nBreak its Hold, then %s: UNSTITCH" % [h.call(&"attack"), h.call(&"heavy"), h.call(&"heavy"), h.call(&"heavy"), h.call(&"heavy")])
	_sign(Vector2(1240, 560), "THE SPARRING POST\nHold %s to guard. Tap it just as a swing lands to PARRY.\nWhite glint: parry it. Red glow: dodge it.\n%s: Edge-On dodge. Dodge at the last moment to slow time." % [h.call(&"guard"), h.call(&"dash")])
	_sign(Vector2(1820, 330), "THE LEDGES\nIn the air, %s x3: air combo\nIn the air, Down + %s: PLUNGE (bounces off what it hits)\nOne dodge in the air." % [h.call(&"attack"), h.call(&"heavy")])
	_sign(Vector2(2860, 560), "THE SOGGY PEN\nThey glint before they lunge: parry them.\nBreak their Hold, then Unstitch.\nThe pen refills when it's empty.")


func _sign(at: Vector2, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(620, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", 26)
	label.add_theme_color_override(&"font_color", Color("281e2e"))
	label.add_theme_color_override(&"font_outline_color", Color("fff8e2"))
	label.add_theme_constant_override(&"outline_size", 10)
	signs.add_child(label)

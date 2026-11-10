extends Page
## The Combat Lab: a practice page for the redesigned combat (milestone M1).
## Reached from the title screen. Nothing here is saved. It has four stations:
## a cutting post, a sparring post that fights back, platforms over a post for
## air combos and the Plunge, and pens of enemies that refill when they're empty:
## Soggies, then (Phase 2) a pen for each new enemy and an Inked elite. At the far
## end, the trial floor (LabTrials): six timed challenges with medals.

const GROUND_TEX := preload("res://assets/art/dark/ground.png")
const GROUND_ROW := 15
## The last 28 tiles are the trial floor (LabTrials).
const WIDTH_TILES := 140
const LAB_WIDTH := WIDTH_TILES * 64
## Each pen: what lives in it, where, and any properties (no scrap drops: nothing here
## is kept). A pen refills a few seconds after its last enemy is gone.
const PENS := [
	{"name": "soggies", "scene": "res://scenes/enemies/soggy.tscn",
		"spots": [Vector2(3000, 900), Vector2(3260, 900), Vector2(3520, 900)]},
	{"name": "moths", "scene": "res://scenes/enemies/paper_moth.tscn",
		"spots": [Vector2(4300, 700), Vector2(4420, 640), Vector2(4540, 720)]},
	{"name": "turret", "scene": "res://scenes/enemies/inkwell_turret.tscn",
		"spots": [Vector2(5300, 958)]},
	{"name": "crane", "scene": "res://scenes/enemies/folded_crane.tscn",
		"spots": [Vector2(6000, 560)]},
	{"name": "mimic", "scene": "res://scenes/enemies/mimic_book.tscn",
		"spots": [Vector2(6500, 958)]},
	{"name": "inked", "scene": "res://scenes/enemies/soggy.tscn",
		"spots": [Vector2(6850, 900)], "props": {"inked": true}},
]

## Pen name -> its living enemies.
var pens := {}
var _refill_left := {}

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
	add_child(DarkAtmosphere.new())
	super._ready()
	_add_signs()
	for pen: Dictionary in PENS:
		_fill_pen(pen)
	add_child(LabTrials.new())


func _physics_process(delta: float) -> void:
	for pen: Dictionary in PENS:
		var alive: Array = (pens.get(pen["name"], []) as Array).filter(
			func(enemy: Variant) -> bool: return is_instance_valid(enemy) and not (enemy as Node).is_queued_for_deletion())
		pens[pen["name"]] = alive
		if alive.is_empty():
			_refill_left[pen["name"]] = _refill_left.get(pen["name"], 2.0) - delta
			if _refill_left[pen["name"]] <= 0.0:
				_fill_pen(pen)
		else:
			_refill_left[pen["name"]] = 2.0


func _build_ground() -> void:
	for x in WIDTH_TILES:
		ground.set_cell(Vector2i(x, GROUND_ROW), 0, Vector2i(0, 0))
		ground.set_cell(Vector2i(x, GROUND_ROW + 1), 0, Vector2i(1, 0))
	# Two ledges above the third post, for air combos and the Plunge.
	for x in range(28, 32):
		ground.set_cell(Vector2i(x, 11), 0, Vector2i(2, 0))
	for x in range(35, 39):
		ground.set_cell(Vector2i(x, 9), 0, Vector2i(2, 0))
	# The tiles only give the collision; the soaked-paper slabs are what you see.
	ground.self_modulate.a = 0.0
	_slab(Vector2(-40, GROUND_ROW * 64 - 14), Vector2(WIDTH_TILES * 64 + 80, 256))
	_slab(Vector2(28 * 64 - 10, 11 * 64 - 10), Vector2(4 * 64 + 20, 70))
	_slab(Vector2(35 * 64 - 10, 9 * 64 - 10), Vector2(4 * 64 + 20, 70))


## A slab of stacked, soaked pages.
func _slab(at: Vector2, size: Vector2) -> void:
	var slab := Sprite2D.new()
	slab.texture = GROUND_TEX
	slab.centered = false
	slab.region_enabled = true
	slab.region_rect = Rect2(Vector2.ZERO, size)
	slab.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	slab.position = at
	slab.z_index = -1
	add_child(slab)


func _fill_pen(pen: Dictionary) -> void:
	var alive: Array = []
	for spot: Vector2 in pen["spots"]:
		var enemy := (load(pen["scene"]) as PackedScene).instantiate()
		enemy.position = spot
		enemy.set("scrap_drop", 0)
		for key in pen.get("props", {}):
			enemy.set(key, pen["props"][key])
		$Actors.add_child(enemy)
		alive.append(enemy)
	pens[pen["name"]] = alive


func _add_signs() -> void:
	var h := func(action: StringName) -> String: return InputGlyphs.hint(action)
	_sign(Vector2(300, 150), "COMBAT LAB\nNothing here is saved. Pause to leave.\nThread fills as your cuts land. Hold %s to spend a charge and Mend." % h.call(&"mend"))
	_sign(Vector2(520, 330), "THE CUTTING POST\n%s x4: light combo, ending in a thrust\n%s: heavy cut (wears down Hold)\nHold %s: charge (3 levels; level 3 is the Full Cut)\nUp + %s: launcher\nBreak its Hold, then %s: UNSTITCH\n%s: switch the shears (Bill, Wings, Beak), even mid-combo" % [h.call(&"attack"), h.call(&"heavy"), h.call(&"heavy"), h.call(&"heavy"), h.call(&"heavy"), h.call(&"switch_form")])
	_sign(Vector2(1240, 330), "THE SPARRING POST\nHold %s to guard. Tap it just as a swing lands to PARRY.\nWhite glint: parry it. Red glow: dodge it.\n%s: Edge-On dodge. Dodge at the last moment to slow time." % [h.call(&"guard"), h.call(&"dash")])
	_sign(Vector2(1900, 200), "THE LEDGES\nIn the air, %s x3: air combo\nIn the air, Down + %s: PLUNGE (bounces off what it hits)\nOne dodge in the air." % [h.call(&"attack"), h.call(&"heavy")])
	_sign(Vector2(2860, 330), "THE SOGGY PEN\nThey glint before they lunge: parry them.\nEnd a combo with the thrust to send one\ntumbling into the others. Heavies make them reel.\nBreak their Hold, then Unstitch.")
	_sign(Vector2(3980, 120), "PAPER MOTHS\nThey dart in one at a time after a glint.\nOne cut tears a moth. Quick cuts, not heavy ones.")
	_sign(Vector2(4900, 330), "THE INKWELL TURRET\nIt glints at the nib, then fires straight.\nClose in, or cut the shot to send it back.")
	_sign(Vector2(5640, 120), "THE FOLDED CRANE\nIt circles high, glows red, then dives: DODGE.\nIf it misses, its beak sticks in the ground.")
	_sign(Vector2(7000, 120), "THE TRIAL FLOOR\nSix trials behind a gate, with medals.\nRead the board to start one.")
	_sign(Vector2(6280, 330), "A BOOK\n...probably just a book.\n\nINKED ELITES (right) are darker, tougher\nand quicker, and leave a pool of ink.")


## A torn notice: dark, soaked paper with a dried-blood red edge.
func _sign(at: Vector2, text: String) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.82)
	style.border_color = Color("6b1f1a")
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override(&"panel", style)
	card.position = at
	card.custom_minimum_size = Vector2(640, 0)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(608, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", 25)
	label.add_theme_color_override(&"font_color", Color("d8d0c0"))
	card.add_child(label)
	signs.add_child(card)

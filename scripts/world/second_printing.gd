class_name SecondPrinting
extends RefCounted
## The Second Printing (New Game+): once a book is finished, its slot can be set again
## from the first page. The story starts over; Patch keeps what he's made of and what
## he's learned (health, spools, charms, patterns, the shears' form, scraps, the
## bestiary, his papers and every sticker and arcade best), and the book is set in
## heavier type: enemies have half again their health (HealthComponent) and every cut
## on Patch goes half again as deep (Patch).
##
## GameState.printing counts the printings (0 is the first edition) and is saved.

const ENEMY_HEALTH := 1.5
const DAMAGE_TAKEN := 1.5
## Flags that survive into the next printing (by prefix): records of the post-game,
## and which paper he wears.
const KEPT_FLAGS := ["sticker:", "sticker_time:", "arcade:", "arcade_rank:", "paper:", "paper_finish"]


static func available(save: Dictionary) -> bool:
	var flags: Variant = save.get("flags", {})
	return flags is Dictionary and bool(flags.get("game_complete", false))


## Loads the slot, keeps what carries over, clears the rest, and saves it as the next
## printing at the first page. Returns false if the slot can't be set again.
static func begin(save_slot: int) -> bool:
	if not available(GameState.read_save(save_slot)) or not GameState.load_game(save_slot):
		return false
	# Earned now, so the papers outlive the flags they were earned by.
	Papers.refresh()
	var keep := {
		"max_health": GameState.max_health, "heart_patches": GameState.heart_patches,
		"spools": GameState.spools, "scraps": GameState.scraps,
		"charms": GameState.charms.duplicate(), "equipped": GameState.equipped.duplicate(),
		"charm_slots": GameState.charm_slots, "patterns": GameState.patterns.duplicate(),
		"shear_form": GameState.shear_form, "bestiary": GameState.bestiary.duplicate(),
		"printing": GameState.printing + 1,
	}
	var flags := {}
	for key: String in GameState.flags:
		for prefix: String in KEPT_FLAGS:
			if key.begins_with(prefix):
				flags[key] = GameState.flags[key]
	GameState.new_game(save_slot)
	GameState.max_health = keep["max_health"]
	GameState.health = GameState.max_health
	GameState.heart_patches = keep["heart_patches"]
	GameState.spools = keep["spools"]
	GameState.thread_max = GameState.BASE_THREAD + GameState.spools
	GameState.scraps = keep["scraps"]
	GameState.charms.assign(keep["charms"])
	GameState.equipped.assign(keep["equipped"])
	GameState.charm_slots = keep["charm_slots"]
	GameState.patterns.assign(keep["patterns"])
	GameState.shear_form = keep["shear_form"]
	GameState.bestiary = keep["bestiary"]
	GameState.printing = keep["printing"]
	GameState.flags = flags
	Papers.refresh()
	GameState.checkpoint_page = GameState.FIRST_PAGE
	GameState.save_game()
	return true


static func ordinal(printing: int) -> String:
	const NAMES := ["First", "Second", "Third", "Fourth", "Fifth"]
	return NAMES[printing] if printing < NAMES.size() else "%dth" % (printing + 1)


## The title screen's choice for a finished book: read on, or set it again.
class PrintingPanel extends CanvasLayer:
	signal closed
	var save_slot := 0

	static func open(parent: Node, for_slot: int) -> PrintingPanel:
		var panel := PrintingPanel.new()
		panel.save_slot = for_slot
		parent.add_child(panel)
		return panel

	func _ready() -> void:
		layer = 32
		var data := GameState.read_save(save_slot)
		var printing := int(data.get("printing", 0))
		var box := DarkUI.dialog(self, Vector2(940, 560))
		box.add_child(DarkUI.label("Book %d is finished" % (save_slot + 1), 40, DarkUI.BONE))
		box.add_child(DarkUI.label("A second printing sets the whole story again from the first page, in heavier type. Patch keeps his health, spools, charms, patterns, scraps, papers and every sticker and best. The enemies have half again their strength, and every cut goes half again as deep.", 22, DarkUI.ASH, true))
		var read_on := DarkUI.button("Go on reading the %s Printing" % SecondPrinting.ordinal(printing), 24)
		read_on.pressed.connect(_read_on)
		box.add_child(read_on)
		var again := DarkUI.button("Begin the %s Printing (this book's progress is set over)" % SecondPrinting.ordinal(printing + 1), 24)
		again.pressed.connect(_begin)
		box.add_child(again)
		var back := DarkUI.button("Back")
		back.pressed.connect(close)
		box.add_child(back)
		read_on.grab_focus.call_deferred()

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			close()

	func _read_on() -> void:
		queue_free()
		if GameState.load_game(save_slot):
			SceneManager.change_page_at(GameState.checkpoint_page, GameState.checkpoint_position)

	func _begin() -> void:
		queue_free()
		if SecondPrinting.begin(save_slot):
			SceneManager.change_page(GameState.FIRST_PAGE)

	func close() -> void:
		closed.emit()
		queue_free()

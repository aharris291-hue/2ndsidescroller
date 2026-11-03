class_name ShearForms
extends RefCounted
## Gran's stork shears do three things, so they fight three ways (Redesign Bible 2.2):
##   Bill   closed, one long thin blade. Balanced reach; the default.
##   Wings  pivot unscrewed, a blade in each hand. Fast, short, five-cut combo, best in
##          the air. Unlocked once Thistledown is mended (Old Millwheel beaten).
##   Beak   held wide; every cut snaps the jaws shut. Slow and heavy: big Hold damage,
##          and it snips straight through a Tack Knight's shield. Unlocked in
##          Lanternfold, once Corrugate joins.
## The switch_form action cycles through the unlocked ones, mid-combo too: a switch
## during a swing comes out as a quick transition cut.
## Each enemy family is weak to one form (see Bestiary): +1 damage, +50% Hold.

enum Form { BILL, WINGS, BEAK }

const STATS := {
	Form.BILL: {
		"name": "Bill", "speed": 1.0, "reach": 1.0, "combo": 4, "air_combo": 3,
		"light_damage": 1, "light_hold": 0.5, "heavy_bonus": 0, "hold_scale": 1.0,
		"pierce": false, "colour": Color("fff6dc"),
	},
	Form.WINGS: {
		"name": "Wings", "speed": 0.7, "reach": 0.8, "combo": 5, "air_combo": 5,
		"light_damage": 1, "light_hold": 0.35, "heavy_bonus": -1, "hold_scale": 0.8,
		"pierce": false, "colour": Color("cfe6ff"),
	},
	Form.BEAK: {
		"name": "Beak", "speed": 1.4, "reach": 1.15, "combo": 3, "air_combo": 2,
		"light_damage": 2, "light_hold": 1.0, "heavy_bonus": 1, "hold_scale": 1.6,
		"pierce": true, "colour": Color("ffd07a"),
	},
}
## The story flag that unlocks each form (Bill is always there).
const UNLOCK_FLAG := {
	Form.WINGS: "boss_millwheel_defeated",
	Form.BEAK: "corrugate_joined",
}


static func stats(form: int) -> Dictionary:
	return STATS.get(form, STATS[Form.BILL])


static func display_name(form: int) -> String:
	return stats(form)["name"]


static func is_unlocked(form: int) -> bool:
	if form == Form.BILL:
		return true
	if not GameState.has_ability(&"crease_swipe"):
		return false
	return GameState.sandbox or GameState.get_flag(UNLOCK_FLAG.get(form, ""))


static func unlocked() -> Array[int]:
	var list: Array[int] = []
	for form: int in STATS:
		if is_unlocked(form):
			list.append(form)
	return list


## The next unlocked form after `form` (itself if it's the only one).
static func next(form: int) -> int:
	var list := unlocked()
	var i := list.find(form)
	return list[(i + 1) % list.size()] if i >= 0 else Form.BILL

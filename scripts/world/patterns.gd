class_name Patterns
extends RefCounted
## Gran's patterns: shear techniques Patch learns at the sewing tin, from the pattern
## cards tucked under its lid. Unlike charms they are permanent and need no slot.
## Effects are read where they apply (GameState.has_pattern), all in Patch.

const CATALOG := {
	&"backstitch": {
		"name": "Backstitch",
		"text": "The parry window is half again as long, and a parry tears more of a foe's Hold.",
		"price": 90,
	},
	&"quick_unpick": {
		"name": "Quick Unpick",
		"text": "Heavy cuts charge a third faster.",
		"price": 110,
	},
	&"blanket_stitch": {
		"name": "Blanket Stitch",
		"text": "One more cut in the air combo.",
		"price": 120,
	},
	&"long_seam": {
		"name": "Long Seam",
		"text": "Unstitch from further away, and every Unstitch mends half a paper token.",
		"price": 150,
	},
}


static func display_name(pattern_id: StringName) -> String:
	return CATALOG.get(pattern_id, {}).get("name", String(pattern_id))


static func description(pattern_id: StringName) -> String:
	return CATALOG.get(pattern_id, {}).get("text", "")


static func price(pattern_id: StringName) -> int:
	return int(CATALOG.get(pattern_id, {}).get("price", -1))

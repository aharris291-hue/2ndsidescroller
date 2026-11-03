class_name Charms
extends RefCounted
## Stitch charms: small perks sewn onto Patch's bandana at Gran's sewing tin. He can
## wear GameState.charm_slots of them at once. Effects are read where they apply
## (GameState.has_charm): Patch's guard, dodge and mend, Scrap pickups, Thread.

const CATALOG := {
	&"wax_thread": {
		"name": "Waxed Thread",
		"text": "Mend heals one more paper token.",
	},
	&"thimble": {
		"name": "Gran's Thimble",
		"text": "Guarding takes no chip damage, even from heavy blows.",
	},
	&"magpie_button": {
		"name": "Magpie Button",
		"text": "Scraps you pick up are worth half again as much.",
	},
	&"heron_pin": {
		"name": "Heron Pin",
		"text": "The perfect-dodge window is half again as long.",
	},
	&"red_knot": {
		"name": "Red Knot",
		"text": "Thread fills a quarter faster.",
	},
}


static func display_name(charm_id: StringName) -> String:
	return CATALOG.get(charm_id, {}).get("name", String(charm_id))


static func description(charm_id: StringName) -> String:
	return CATALOG.get(charm_id, {}).get("text", "")

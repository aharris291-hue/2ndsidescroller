class_name Bestiary
extends RefCounted
## Nell's bestiary: a school exercise book she keeps beside the real book, filling in a
## page for every kind of thing Patch beats. Nell is eleven and writes like it, but she
## was in the house the night the water came up, and it shows in what she notices.
##
## An entry appears the first time Patch beats one (GameState.record_defeat). Its
## weakness (the shears' form it fears: +1 damage, +50% Hold) is written in once he
## has beaten REVEAL_AFTER of them.

const REVEAL_AFTER := 3

const ENTRIES := {
	"soggy": {
		"name": "Soggy",
		"art": "res://assets/art/dark/sogg.png",
		"note": "Wet pages balled up and walking. Some still have words on. One had half of Gran's shopping list on it and I had to stop for a bit.",
		"tell": "Crouches and glints before it lunges. Parry the lunge.",
		"weak": ShearForms.Form.WINGS,
	},
	"tack_knight": {
		"name": "Tack Knight",
		"art": "res://assets/art/dark/enemies/tack_knight.png",
		"note": "A drawing pin for a shield. Dad says they were toy soldiers once. They don't look like toys now. They don't stop.",
		"tell": "Shakes, then charges. Its shield turns any cut from the front.",
		"weak": ShearForms.Form.BEAK,
	},
	"ink_spitter": {
		"name": "Ink Spitter",
		"art": "res://assets/art/dark/enemies/ink_spitter.png",
		"note": "A cracked ink bottle. When it swells up it is about to spit. It smells like the hallway did after.",
		"tell": "Swells before each throw. Close the distance.",
		"weak": ShearForms.Form.BILL,
	},
	"paper_moth": {
		"name": "Paper Moth",
		"art": "res://assets/art/dark/enemies/paper_moth.png",
		"note": "They come in threes. They were the corners of pages, I think, the bits you fold down to keep your place.",
		"tell": "One glints, then darts. One cut tears it.",
		"weak": ShearForms.Form.WINGS,
	},
	"inkwell_turret": {
		"name": "Inkwell Turret",
		"art": "res://assets/art/dark/enemies/inkwell_turret.png",
		"note": "Dad's old inkwell. It only shoots straight. If Patch cuts the ink it goes back the other way, which is fair.",
		"tell": "Glints at the nib, then fires. Cut the shot to send it back.",
		"weak": ShearForms.Form.BEAK,
	},
	"folded_crane": {
		"name": "Folded Crane",
		"art": "res://assets/art/dark/enemies/folded_crane.png",
		"note": "Gran folded a thousand of these for Mum's wedding. This one has a needle for a beak. You can't block it. You can only not be there.",
		"tell": "Red glow, then a dive that can't be blocked. Dodge, then hit it while its beak is stuck.",
		"weak": ShearForms.Form.BILL,
	},
	"mimic_book": {
		"name": "Mimic Book",
		"art": "res://assets/art/dark/enemies/mimic_book.png",
		"note": "Looks like a book. Is not a book. I don't trust any of the books on that shelf any more.",
		"tell": "Lies still until Patch is close. Hit it first and it's dazed.",
		"weak": ShearForms.Form.BEAK,
	},
	"inked": {
		"name": "Inked",
		"art": "res://assets/art/dark/sogg.png",
		"tint": Color(0.52, 0.48, 0.64),
		"note": "Some of them have gone dark all the way through. They are faster and harder to tear, and when they go they leave a stain that burns.",
		"tell": "Any kind can be Inked. Quicker tells; don't stand in the pool it leaves.",
		"weak": -1,
	},
	"millwheel": {
		"name": "Old Millwheel",
		"art": "res://assets/art/dark/bosses/millwheel_body.png",
		"note": "The windmill on the first page. It used to turn when you pulled the tab. I used to pull it over and over. I'm sorry I did that now.",
		"tell": "Pull the three tabs to jam the sails, then go for the core. Heavies break its Hold.",
		"weak": -1,
	},
	"kraken": {
		"name": "The Blotch Kraken",
		"art": "res://assets/art/dark/bosses/kraken_body.png",
		"note": "All the ink from the harbour, in one shape, with an eye. It was holding Drizzle. I didn't know that until the end.",
		"tell": "Yank both blotter rings to drop the blotters on it, then cut the eye.",
		"weak": -1,
	},
	"clockwork_needle": {
		"name": "Clockwork Needle",
		"art": "res://assets/art/dark/props/clockwork_head.png",
		"note": "Bindwell's sewing machines. He hung them over the Peaks to stitch the paper down so the flood couldn't lift it. Nobody told them the flood was over. They still sew anything that moves.",
		"tell": "The pin shakes before it drops. Step out from under it, then cut the pin while it's stuck. Three cuts snap it.",
		"weak": -1,
	},
	"carousel_horse": {
		"name": "Carousel Horse",
		"art": "res://assets/art/dark/enemies/carousel_horse.png",
		"note": "Off the fair's carousel, with the pole still through it. Nell rode the white one every summer and called it Captain. It doesn't remember her. It goes round on its own now, looking for anyone to carry.",
		"tell": "It rears before it charges. The charge is three big bounds and you can guard them: parry one, or let it run into a wall, and it goes over on its side. Cut it while it's down.",
		"weak": -1,
	},
	"bindwell": {
		"name": "Old Bindwell",
		"art": "res://assets/art/dark/friends/bindwell.png",
		"note": "The bookbinder's needle. He sewed the spine shut the night of the flood, to keep the water out of the high pages, and when the low pages knocked he didn't open it. He knew Patch was out there. He sewed anyway.",
		"tell": "The red stabs can't be guarded: step out of them. The white one can. Parry it and he's only wire for a moment. Jump his thread. When he sews the floor, stay in the middle.",
		"weak": -1,
	},
	"barker": {
		"name": "The Barker",
		"art": "res://assets/art/dark/enemies/barker.png",
		"note": "Gatefold Fair's showman. The night of the flood he stood in the big top's door with his megaphone and told the crowd it was only a shower, that the show would go on, that nobody leaves. They stayed. He kept telling it to the empty seats until Patch made him say what it was.",
		"tell": "The sign over his head says which act is next; from half health it lies. Watch him, not the sign: cards glint in his hand (parry the white one and it cuts him open), hooves drum in the wings (jump the horses), and he swells before he shouts (jump the wave, then he's out of breath).",
		"weak": -1,
	},
	"heron": {
		"name": "The Grey Heron",
		"art": "res://assets/art/dark/bosses/heron.png",
		"note": "It was printed in the paper of the marsh, like the other watermarks. It stood in the reeds the night of the flood and watched. So did Patch. He told me that part himself.",
		"tell": "Get in close on the peat so it stabs the peat, not the ink. Then its beak sticks: cut its head. When it spreads its wings, get in the ink.",
		"weak": -1,
	},
	"sogg": {
		"name": "The Sogg",
		"art": "res://assets/art/dark/bosses/sogg_body.png",
		"note": "I don't want to write this one. It is the water. It is what came in under the door.",
		"tell": "Get it down beside a fold mark and slam the peak up through it.",
		"weak": -1,
	},
}
## The order the pages come in Nell's book.
const ORDER := ["soggy", "tack_knight", "ink_spitter", "paper_moth", "inkwell_turret",
	"folded_crane", "mimic_book", "clockwork_needle", "carousel_horse", "inked", "millwheel", "kraken", "heron", "bindwell", "barker", "sogg"]


static func entry(enemy_id: String) -> Dictionary:
	return ENTRIES.get(enemy_id, {})


static func weak_form(enemy_id: String) -> int:
	return int(entry(enemy_id).get("weak", -1))


static func count(enemy_id: String) -> int:
	return int(GameState.bestiary.get(enemy_id, 0))


static func weakness_known(enemy_id: String) -> bool:
	return weak_form(enemy_id) >= 0 and count(enemy_id) >= REVEAL_AFTER


## Records a beaten enemy (and that it was Inked, if it was).
static func record(enemy: Node) -> void:
	var enemy_id := String(enemy.get(&"bestiary_id")) if enemy.get(&"bestiary_id") != null else ""
	if enemy_id.is_empty():
		return
	GameState.record_defeat(enemy_id)
	if enemy.get(&"inked"):
		GameState.record_defeat("inked")


## A cut in the form this enemy fears hits harder. Used by Hurtbox.
static func is_weak_to(enemy: Node, form: int) -> bool:
	if form < 0 or enemy == null:
		return false
	var enemy_id = enemy.get(&"bestiary_id")
	return enemy_id != null and weak_form(String(enemy_id)) == form

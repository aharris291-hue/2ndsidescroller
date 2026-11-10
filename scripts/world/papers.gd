class_name Papers
extends RefCounted
## Paper finishes for Patch (post-game): the same painted fox, reprinted on one of the
## papers Gran kept pegged on her drying rack in the Spine (PaperRack). Each is earned
## once by a post-game feat and then stays: the flag "paper:<id>" is set the first time
## its feat is seen, so it survives the Second Printing, which clears the feat flags.
## The one he wears is the flag "paper_finish". The look is paper_finish.gdshader.

const SHADER := preload("res://resources/shaders/paper_finish.gdshader")
const RACK := "res://scenes/levels/hub/spine_hub.tscn"

## id, name, how it's earned, and the shader's colours. "foolscap" is his own paper.
const CATALOG := [
	{"id": "foolscap", "name": "Foolscap", "how": "The paper he was made on.", "note": "His own."},
	{"id": "newsprint", "name": "Newsprint", "how": "Finish the book.",
		"note": "Cheap, grey, and it yellows. Gran wrapped the good china in it.",
		"dark": Color(0.08, 0.08, 0.08), "light": Color(0.82, 0.8, 0.74)},
	{"id": "blueprint", "name": "Blueprint", "how": "Gold in all six Combat Lab trials.",
		"note": "Grandad's plans for a shed he never built. Every line of him in white.",
		"dark": Color(0.04, 0.12, 0.3), "light": Color(0.78, 0.86, 0.95)},
	{"id": "watermarked", "name": "Watermarked", "how": "Begin the Second Printing.",
		"note": "Hold it to the light and there's another fox in it, very faint.",
		"dark": Color(0.16, 0.2, 0.26), "light": Color(0.86, 0.9, 0.93), "amount": 0.8},
	{"id": "marbled", "name": "Marbled Endpaper", "how": "Gilt in every game at the penny theatre.",
		"note": "Oil and ink floated on water and lifted off on a sheet. No two the same.",
		"dark": Color(0.12, 0.05, 0.06), "light": Color(0.85, 0.78, 0.66),
		"marble": 0.7, "marble_color": Color(0.55, 0.16, 0.14)},
	{"id": "gilt_edge", "name": "Gilt Edge", "how": "A Gilt sticker from every proof on the press.",
		"note": "The card she kept for weddings and the other thing.",
		"dark": Color(0.16, 0.09, 0.02), "light": Color(1.0, 0.86, 0.5)},
	{"id": "mourning", "name": "Mourning Card", "how": "Reach the Last Margin, and come back from it.",
		"note": "Black card. She had a box of it. She said you buy it once and it lasts.",
		"dark": Color(0.02, 0.02, 0.03), "light": Color(0.42, 0.4, 0.44), "keep_red": 0.85},
]
## The Runaway's paper (BossRunaway): Patch, all in wet ink.
const INK := {"dark": Color(0.0, 0.0, 0.02), "light": Color(0.2, 0.18, 0.26), "keep_red": 0.25}

const LAB_TRIALS := ["clean_cut", "glint", "edge_on", "moth_season", "inked", "grans_hand"]
const ARCADE_GAMES := ["waltz", "reel", "long_night", "flood_run"]
const STORY_BOSSES := ["millwheel", "kraken", "heron", "bindwell", "barker", "redactor", "forecast", "sogg"]


static func entry(id: String) -> Dictionary:
	for p: Dictionary in CATALOG:
		if p["id"] == id:
			return p
	return {}


## Whether the feat behind a paper is done right now (not whether it was ever earned).
static func feat_done(id: String) -> bool:
	match id:
		"foolscap":
			return true
		"newsprint":
			return GameState.get_flag("game_complete")
		"blueprint":
			return LAB_TRIALS.all(func(t: String) -> bool: return int(LabTrials.best(t).get("medal", 0)) >= 3)
		"watermarked":
			return GameState.printing > 0
		"marbled":
			return ARCADE_GAMES.all(func(g: String) -> bool: return Arcade.best_rank(g) >= 4)
		"gilt_edge":
			return STORY_BOSSES.all(func(b: String) -> bool: return Rematch.best_rank(b) >= 4)
		"mourning":
			return GameState.get_flag("true_ending")
	return false


static func owned(id: String) -> bool:
	return id == "foolscap" or GameState.get_flag("paper:" + id)


## Marks every paper whose feat is done as earned. Returns the ids newly earned.
static func refresh() -> Array[String]:
	var fresh: Array[String] = []
	for p: Dictionary in CATALOG:
		var id: String = p["id"]
		if not owned(id) and feat_done(id):
			GameState.set_flag("paper:" + id)
			fresh.append(id)
	return fresh


static func worn() -> String:
	var id := String(GameState.get_flag("paper_finish", "foolscap"))
	return id if owned(id) and not entry(id).is_empty() else "foolscap"


static func wear(id: String) -> bool:
	if not owned(id):
		return false
	GameState.set_flag("paper_finish", id)
	return true


## A material that reprints a painting on the paper `id` (or the INK dictionary), or
## null for his own paper.
static func material_for(spec: Variant) -> ShaderMaterial:
	var p: Dictionary = spec if spec is Dictionary else entry(String(spec))
	if not p.has("dark"):
		return null
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"dark", p["dark"])
	mat.set_shader_parameter(&"light", p["light"])
	mat.set_shader_parameter(&"amount", p.get("amount", 1.0))
	mat.set_shader_parameter(&"keep_red", p.get("keep_red", 0.6))
	mat.set_shader_parameter(&"marble", p.get("marble", 0.0))
	mat.set_shader_parameter(&"marble_color", p.get("marble_color", Color.BLACK))
	return mat

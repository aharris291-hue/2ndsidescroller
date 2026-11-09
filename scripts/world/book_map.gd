class_name BookMap
extends RefCounted
## The book's regions, for the torn map and the Spine hub's doors.
##
## Each region lists the folders its pages live in, the boss flag that marks it mended,
## the flag that opens its door in the hub, and the page its door leads to. Regions
## not yet written (built in Phase 3) have no pages; their doors stay sealed.

const HUB := "res://scenes/levels/hub/spine_hub.tscn"

const REGIONS := [
	{
		"id": &"prologue", "name": "The Shelf", "dirs": ["res://scenes/levels/prologue/"], "subtitle": "the night of the flood",
		"mended_flag": "cut_the_thread", "open_flag": "", "door": "",
		"spot": Vector2(0.5, 0.88),
	},
	{
		"id": &"thistledown", "name": "Thistledown", "dirs": ["res://scenes/levels/thistledown/"], "subtitle": "the drowned meadow",
		"mended_flag": "boss_millwheel_defeated", "open_flag": "",
		"door": "res://scenes/levels/thistledown/1_1_sodden_fields.tscn",
		"spot": Vector2(0.2, 0.66),
	},
	{
		"id": &"lanternfold", "name": "Lanternfold", "dirs": ["res://scenes/levels/lanternfold/"], "subtitle": "the harbour that went dark",
		"mended_flag": "boss_kraken_defeated", "open_flag": "boss_millwheel_defeated",
		"door": "res://scenes/levels/lanternfold/2_1_the_drowned_quay.tscn",
		"spot": Vector2(0.8, 0.66),
	},
	{
		"id": &"marsh", "name": "Watermark Marsh", "dirs": ["res://scenes/levels/marsh/"], "subtitle": "where the ink settled",
		"mended_flag": "", "open_flag": "boss_kraken_defeated",
		"door": "res://scenes/levels/marsh/3_1_the_sump_road.tscn",
		"spot": Vector2(0.17, 0.36),
	},
	{
		"id": &"peaks", "name": "The Spine Peaks", "dirs": ["res://scenes/levels/ch3_spine/"], "subtitle": "the cold top of the book",
		"mended_flag": "boss_sogg_phase2_done", "open_flag": "boss_kraken_defeated",
		"door": "res://scenes/levels/ch3_spine/the_spine.tscn",
		"spot": Vector2(0.5, 0.14),
	},
	{
		"id": &"fair", "name": "Gatefold Fair", "dirs": [], "subtitle": "the fair that never closed",
		"mended_flag": "", "open_flag": "", "door": "",
		"spot": Vector2(0.83, 0.36),
	},
	{
		"id": &"index", "name": "The Index", "dirs": [], "subtitle": "everything, listed",
		"mended_flag": "", "open_flag": "", "door": "",
		"spot": Vector2(0.5, 0.36),
	},
]


static func region(region_id: StringName) -> Dictionary:
	for entry: Dictionary in REGIONS:
		if entry["id"] == region_id:
			return entry
	return {}


## The region a page belongs to, or {} (the hub and the Margin belong to none).
static func region_of(page_path: String) -> Dictionary:
	for entry: Dictionary in REGIONS:
		for dir: String in entry["dirs"]:
			if page_path.begins_with(dir):
				return entry
	return {}


static func is_written(entry: Dictionary) -> bool:
	return not (entry["dirs"] as Array).is_empty()

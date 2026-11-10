extends Node
## Everything about the current playthrough that must survive page changes and saves:
## inventory, unlocked abilities, story flags, checkpoint, and the save-slot files.

## 2: heart patches, Thread spools, stitch charms, bookmarks for travel and the pages
## seen (for the torn map). Version 1 saves load with none of those.
## 3: Gran's patterns (sword techniques bought at the tin). Older saves load with none.
## 4: the shears' current form and Nell's bestiary (what Patch has beaten, how often).
## 5: the printing (the Second Printing, New Game+). Older saves are the first.
const SAVE_VERSION := 6
const SLOT_COUNT := 3
const FIRST_PAGE := "res://scenes/levels/prologue/prologue_intro.tscn"
const QUESTS_FILE := "res://data/quests.json"
## Patch finds Gran's shears partway up the Prologue (P-2 The Rising).
const STARTING_ABILITIES: Array[StringName] = []
const LETTER_TOTAL := 26

var slot := 0
## Patch's starting health: six paper tokens (each token is 2 health).
const BASE_MAX_HEALTH := 12

var max_health := BASE_MAX_HEALTH
var health := BASE_MAX_HEALTH
var scraps := 0
## Patch's Thread meter, in charges (filled by landing hits; not saved).
var thread := 0.0
const BASE_THREAD := 3.0
var thread_max := BASE_THREAD
## Upgrades bought from Gran's sewing tin: each heart patch is one more paper token
## (2 health), each spool one more Thread charge.
var heart_patches := 0
var spools := 0
## Stitch charms owned, and the ones sewn on (at most charm_slots).
var charms: Array[StringName] = []
## Gran's patterns: techniques learned at the sewing tin (see Patterns).
var patterns: Array[StringName] = []
## Which form Gran's shears are in (ShearForms.Form).
var shear_form := 0
## Nell's bestiary: enemy id -> how many Patch has beaten (see Bestiary).
var bestiary := {}
var equipped: Array[StringName] = []
var charm_slots := 2
## Bookmarks Patch has touched, for travel: "page#x,y" -> {page, x, y, title}.
var bookmarks: Dictionary = {}
## Pages Patch has been on, for the torn map.
var visited: Dictionary = {}
## True in the Combat Lab: nothing is saved, so a save slot can't be overwritten.
var sandbox := false
## The boss being fought again from Gran's proof press (Rematch), or "". Never saved.
var rematch := ""
## Which printing of the book this is: 0 is the first edition, 1+ a Second Printing
## (SecondPrinting), with tougher enemies.
var printing := 0
var letters: Array[String] = []
var abilities: Array[StringName] = []
## Unique ids of one-time pickups that are already collected.
var collected: Dictionary = {}
## Story flags, e.g. "met_shepherd_fluff": true.
var flags: Dictionary = {}
## Side quests: quest id -> {"progress": int, "done": bool}. Definitions live in data/quests.json.
var quests: Dictionary = {}
var quest_defs: Dictionary = {}
var checkpoint_page := ""
var checkpoint_position := Vector2.ZERO
var current_page := ""
var play_time := 0.0
## Play report (PlayReport): page path -> {"t": seconds played, "d": deaths, "h": hits
## taken, "v": visits}. Measured, so PRs and tuning can quote real play times.
var page_stats: Dictionary = {}
var _last_health := -1
## True while a gameplay page is running; the clock only counts real play.
var in_gameplay := false


func _ready() -> void:
	if FileAccess.file_exists(QUESTS_FILE):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUESTS_FILE))
		if typeof(parsed) == TYPE_DICTIONARY:
			quest_defs = parsed
	EventBus.player_died.connect(func() -> void: _stat(&"d", 1))
	EventBus.player_health_changed.connect(_on_health_seen)


func _process(delta: float) -> void:
	if in_gameplay and not get_tree().paused:
		play_time += delta
		_stat(&"t", delta)


func _stat(key: StringName, amount: float) -> void:
	if current_page.is_empty() or sandbox:
		return
	var entry: Dictionary = page_stats.get(current_page, {})
	entry[String(key)] = float(entry.get(String(key), 0.0)) + amount
	page_stats[current_page] = entry


## Counts a visit each time a page loads (Page calls this).
func note_visit(page_path: String) -> void:
	current_page = page_path
	_last_health = -1
	_stat(&"v", 1)


func _on_health_seen(current: int, _maximum: int) -> void:
	if _last_health >= 0 and current < _last_health:
		_stat(&"h", 1)
	_last_health = current


func new_game(new_slot: int) -> void:
	slot = new_slot
	sandbox = false
	rematch = ""
	printing = 0
	max_health = BASE_MAX_HEALTH
	health = max_health
	scraps = 0
	thread = 0.0
	thread_max = BASE_THREAD
	heart_patches = 0
	spools = 0
	charms.clear()
	patterns.clear()
	shear_form = 0
	bestiary.clear()
	equipped.clear()
	charm_slots = 2
	bookmarks.clear()
	visited.clear()
	letters.clear()
	abilities = STARTING_ABILITIES.duplicate()
	collected.clear()
	flags.clear()
	quests.clear()
	checkpoint_page = ""
	checkpoint_position = Vector2.ZERO
	current_page = ""
	play_time = 0.0
	page_stats.clear()


# --- Inventory and progress --------------------------------------------------

func add_thread(amount: float) -> void:
	# Red Knot charm: Thread fills a quarter faster.
	if amount > 0.0 and has_charm(&"red_knot"):
		amount *= 1.25
	var before := thread
	thread = clampf(thread + amount, 0.0, thread_max)
	if thread != before:
		EventBus.thread_changed.emit(thread, thread_max)


func has_ability(ability_id: StringName) -> bool:
	return abilities.has(ability_id)


func unlock_ability(ability_id: StringName) -> void:
	if not abilities.has(ability_id):
		abilities.append(ability_id)
		EventBus.ability_unlocked.emit(ability_id)


func add_scraps(amount: int) -> void:
	scraps += amount
	EventBus.scraps_changed.emit(scraps)


# --- Upgrades and charms ------------------------------------------------------

func add_heart_patch() -> void:
	heart_patches += 1
	max_health += 2
	health = max_health
	EventBus.player_health_changed.emit(health, max_health)


## A heart patch found in the world (a sealed back page's reward): a paper token more,
## without changing what Gran's tin charges for the ones she sells.
func add_found_heart() -> void:
	max_health += 2
	health = max_health
	EventBus.player_health_changed.emit(health, max_health)


func add_spool() -> void:
	spools += 1
	thread_max = BASE_THREAD + spools
	EventBus.thread_changed.emit(thread, thread_max)


func gain_charm(charm_id: StringName) -> void:
	if not charms.has(charm_id):
		charms.append(charm_id)


## Sews a charm on (true) or takes it off. Returns false when every slot is full.
func set_charm_equipped(charm_id: StringName, on: bool) -> bool:
	if not on:
		equipped.erase(charm_id)
		return true
	if equipped.has(charm_id):
		return true
	if not charms.has(charm_id) or equipped.size() >= charm_slots:
		return false
	equipped.append(charm_id)
	return true


func has_charm(charm_id: StringName) -> bool:
	return equipped.has(charm_id)


func learn_pattern(pattern_id: StringName) -> void:
	if not patterns.has(pattern_id):
		patterns.append(pattern_id)


func has_pattern(pattern_id: StringName) -> bool:
	return patterns.has(pattern_id)


## Counts a beaten enemy for Nell's bestiary. Returns the new count.
func record_defeat(enemy_id: String) -> int:
	bestiary[enemy_id] = int(bestiary.get(enemy_id, 0)) + 1
	if bestiary[enemy_id] == 1:
		EventBus.bestiary_entry.emit(enemy_id)
	return bestiary[enemy_id]


# --- Bookmarks and the map ------------------------------------------------------

func remember_bookmark(page_path: String, position: Vector2, title: String) -> void:
	var key := "%s#%d,%d" % [page_path, roundi(position.x), roundi(position.y)]
	bookmarks[key] = {"page": page_path, "x": position.x, "y": position.y, "title": title}


func mark_visited(page_path: String) -> void:
	if not page_path.is_empty():
		visited[page_path] = true


func collect_letter(letter: String) -> void:
	if not letters.has(letter):
		letters.append(letter)
	EventBus.letter_collected.emit(letter, letters.size())


func mark_collected(pickup_id: String) -> void:
	collected[pickup_id] = true


func is_collected(pickup_id: String) -> bool:
	return collected.has(pickup_id)


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value


func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)


# --- Quests -----------------------------------------------------------------

func quest_started(quest_id: String) -> bool:
	return quests.has(quest_id)


func quest_done(quest_id: String) -> bool:
	return quests.has(quest_id) and quests[quest_id].get("done", false)


func quest_progress(quest_id: String) -> int:
	return int(quests.get(quest_id, {}).get("progress", 0))


func quest_goal(quest_id: String) -> int:
	return int(quest_defs.get(quest_id, {}).get("goal", 1))


func quest_title(quest_id: String) -> String:
	return quest_defs.get(quest_id, {}).get("title", quest_id)


func start_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		quests[quest_id] = {"progress": 0, "done": false}
		EventBus.quest_updated.emit(quest_id)


## Adds progress (starting the quest if needed). Returns true when the goal is now met.
func advance_quest(quest_id: String, amount := 1) -> bool:
	start_quest(quest_id)
	quests[quest_id]["progress"] = mini(quest_progress(quest_id) + amount, quest_goal(quest_id))
	EventBus.quest_updated.emit(quest_id)
	return quest_progress(quest_id) >= quest_goal(quest_id)


func complete_quest(quest_id: String) -> void:
	start_quest(quest_id)
	if quests[quest_id]["done"]:
		return
	quests[quest_id]["done"] = true
	add_scraps(int(quest_defs.get(quest_id, {}).get("reward_scraps", 0)))
	EventBus.quest_updated.emit(quest_id)


## One line per started quest, for the pause menu.
func quest_log() -> Array[String]:
	var lines: Array[String] = []
	for quest_id in quests:
		var mark := "[done]" if quest_done(quest_id) else "%d/%d" % [quest_progress(quest_id), quest_goal(quest_id)]
		lines.append("%s  %s" % [quest_title(quest_id), mark])
	return lines


func set_checkpoint(page_path: String, position: Vector2) -> void:
	checkpoint_page = page_path
	checkpoint_position = position
	EventBus.checkpoint_reached.emit(page_path, position)


# --- Saving ------------------------------------------------------------------

func save_path(save_slot: int) -> String:
	return "user://save_slot_%d.json" % save_slot


func has_save(save_slot: int) -> bool:
	return FileAccess.file_exists(save_path(save_slot))


func save_game() -> bool:
	if sandbox:
		return false
	var data := {
		"version": SAVE_VERSION,
		"max_health": max_health,
		"scraps": scraps,
		"heart_patches": heart_patches,
		"spools": spools,
		"charms": charms.map(func(c: StringName) -> String: return String(c)),
		"equipped": equipped.map(func(c: StringName) -> String: return String(c)),
		"charm_slots": charm_slots,
		"patterns": patterns.map(func(p: StringName) -> String: return String(p)),
		"shear_form": shear_form,
		"printing": printing,
		"bestiary": bestiary,
		"bookmarks": bookmarks,
		"visited": visited.keys(),
		"letters": letters,
		"abilities": abilities.map(func(a: StringName) -> String: return String(a)),
		"collected": collected.keys(),
		"flags": flags,
		"quests": quests,
		"checkpoint_page": checkpoint_page,
		"checkpoint_position": [checkpoint_position.x, checkpoint_position.y],
		"play_time": play_time,
		"page_stats": page_stats,
		"saved_at": Time.get_datetime_string_from_system(),
	}
	# Write to a temp file first so a crash mid-write never corrupts the real save.
	var final_path := save_path(slot)
	var temp_path := final_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(temp_path, final_path)
	if err != OK:
		push_error("Could not finalize save: %s" % error_string(err))
		return false
	PlayReport.write(slot)
	EventBus.game_saved.emit(slot)
	return true


func load_game(save_slot: int) -> bool:
	sandbox = false
	var data := read_save(save_slot)
	if data.is_empty():
		return false
	new_game(save_slot)
	# Older saves stored the old 6-health cap; never load below the current base.
	max_health = maxi(int(data.get("max_health", BASE_MAX_HEALTH)), BASE_MAX_HEALTH)
	health = max_health
	scraps = int(data.get("scraps", 0))
	# Version 2: upgrades, charms, bookmarks and the map (absent in version 1 saves).
	heart_patches = int(data.get("heart_patches", 0))
	max_health = maxi(max_health, BASE_MAX_HEALTH + heart_patches * 2)
	health = max_health
	spools = int(data.get("spools", 0))
	thread_max = BASE_THREAD + spools
	for charm in data.get("charms", []):
		charms.append(StringName(charm))
	for charm in data.get("equipped", []):
		if charms.has(StringName(charm)):
			equipped.append(StringName(charm))
	charm_slots = int(data.get("charm_slots", 2))
	# Version 3: Gran's patterns.
	for pattern in data.get("patterns", []):
		learn_pattern(StringName(pattern))
	# Version 4: the shears' form and Nell's bestiary.
	shear_form = int(data.get("shear_form", 0))
	# Version 5: the printing.
	printing = int(data.get("printing", 0))
	var seen: Variant = data.get("bestiary", {})
	if seen is Dictionary:
		for id in seen:
			bestiary[String(id)] = int(seen[id])
	var marks: Variant = data.get("bookmarks", {})
	if marks is Dictionary:
		bookmarks = marks
	for page_path in data.get("visited", []):
		visited[String(page_path)] = true
	for letter in data.get("letters", []):
		letters.append(String(letter))
	abilities.clear()
	for ability in data.get("abilities", []):
		abilities.append(StringName(ability))
	for pickup_id in data.get("collected", []):
		collected[String(pickup_id)] = true
	flags = data.get("flags", {})
	quests = data.get("quests", {})
	checkpoint_page = String(data.get("checkpoint_page", FIRST_PAGE))
	var pos: Array = data.get("checkpoint_position", [0, 0])
	checkpoint_position = Vector2(float(pos[0]), float(pos[1]))
	play_time = float(data.get("play_time", 0.0))
	page_stats = data.get("page_stats", {})
	return true


## Returns the parsed save file, or an empty Dictionary if missing or unreadable.
func read_save(save_slot: int) -> Dictionary:
	if not has_save(save_slot):
		return {}
	var text := FileAccess.get_file_as_string(save_path(save_slot))
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save slot %d is unreadable." % save_slot)
		return {}
	return parsed


func delete_save(save_slot: int) -> void:
	if has_save(save_slot):
		DirAccess.remove_absolute(save_path(save_slot))


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 3600, (total / 60) % 60]

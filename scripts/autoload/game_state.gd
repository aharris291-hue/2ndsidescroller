extends Node
## Everything about the current playthrough that must survive page changes and saves:
## inventory, unlocked abilities, story flags, checkpoint, and the save-slot files.

const SAVE_VERSION := 1
const SLOT_COUNT := 3
const FIRST_PAGE := "res://scenes/levels/ch1_thistledown/thistledown_page_01.tscn"
const STARTING_ABILITIES: Array[StringName] = [&"crease_swipe"]
const LETTER_TOTAL := 26

var slot := 0
var max_health := 6
var health := 6
var scraps := 0
var letters: Array[String] = []
var abilities: Array[StringName] = []
## Unique ids of one-time pickups that are already collected.
var collected: Dictionary = {}
## Story flags, e.g. "met_shepherd_fluff": true.
var flags: Dictionary = {}
var checkpoint_page := ""
var checkpoint_position := Vector2.ZERO
var current_page := ""
var play_time := 0.0
## True while a gameplay page is running; the clock only counts real play.
var in_gameplay := false


func _process(delta: float) -> void:
	if in_gameplay and not get_tree().paused:
		play_time += delta


func new_game(new_slot: int) -> void:
	slot = new_slot
	max_health = 6
	health = max_health
	scraps = 0
	letters.clear()
	abilities = STARTING_ABILITIES.duplicate()
	collected.clear()
	flags.clear()
	checkpoint_page = ""
	checkpoint_position = Vector2.ZERO
	current_page = ""
	play_time = 0.0


# --- Inventory and progress --------------------------------------------------

func has_ability(ability_id: StringName) -> bool:
	return abilities.has(ability_id)


func unlock_ability(ability_id: StringName) -> void:
	if not abilities.has(ability_id):
		abilities.append(ability_id)
		EventBus.ability_unlocked.emit(ability_id)


func add_scraps(amount: int) -> void:
	scraps += amount
	EventBus.scraps_changed.emit(scraps)


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
	var data := {
		"version": SAVE_VERSION,
		"max_health": max_health,
		"scraps": scraps,
		"letters": letters,
		"abilities": abilities.map(func(a: StringName) -> String: return String(a)),
		"collected": collected.keys(),
		"flags": flags,
		"checkpoint_page": checkpoint_page,
		"checkpoint_position": [checkpoint_position.x, checkpoint_position.y],
		"play_time": play_time,
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
	EventBus.game_saved.emit(slot)
	return true


func load_game(save_slot: int) -> bool:
	var data := read_save(save_slot)
	if data.is_empty():
		return false
	new_game(save_slot)
	max_health = int(data.get("max_health", 6))
	health = max_health
	scraps = int(data.get("scraps", 0))
	for letter in data.get("letters", []):
		letters.append(String(letter))
	abilities.clear()
	for ability in data.get("abilities", []):
		abilities.append(StringName(ability))
	for pickup_id in data.get("collected", []):
		collected[String(pickup_id)] = true
	flags = data.get("flags", {})
	checkpoint_page = String(data.get("checkpoint_page", FIRST_PAGE))
	var pos: Array = data.get("checkpoint_position", [0, 0])
	checkpoint_position = Vector2(float(pos[0]), float(pos[1]))
	play_time = float(data.get("play_time", 0.0))
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

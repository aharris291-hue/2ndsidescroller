extends Node
## Achievements: unlocked once across every save slot and stored in
## user://achievements.json. When the game runs under Steam (the GodotSteam
## extension registers an engine singleton called "Steam"), each unlock is also passed
## to Steam. The ids below are the API names to enter in the Steamworks dashboard,
## so the Steam achievements must use exactly these. Without Steam, the list still
## works offline and shows in the pause menu.
##
## Each condition is checked again whenever a flag is set, an ability is learned,
## something is bought, a bestiary page is filled, or the game saves. So an achievement
## earned in an old save unlocks the next time that save is played.

const PATH := "user://achievements.json"

## id -> [name, description]. In book order.
const LIST := {
	"SHEARS": ["Gran's Shears", "Take up the stork shears on the night of the flood."],
	"MILLWHEEL": ["The Wheel Stops", "Bring down the Old Millwheel and mend Thistledown."],
	"KRAKEN": ["Blotted Dry", "Soak the Blotch Kraken dry under Lanternfold."],
	"HERON": ["Grey Feathers", "Fold the Grey Heron down in Watermark Marsh."],
	"BINDWELL": ["Unbound", "Cut Old Bindwell loose from the Spine Peaks."],
	"BARKER": ["The Show Is Over", "Close the Barker's show at Gatefold Fair."],
	"REDACTOR": ["Leave It In", "Stop the Redactor before the Index is blacked out."],
	"FORECAST": ["Unwritten", "Face the Unwritten Forecast in the Blank Margins."],
	"THE_END": ["The End", "Go down into the Gutter and finish the story."],
	"TAIL": ["What He Owed", "Give Drizzle the tail."],
	"HEARTS": ["Gran's Tin, Emptied", "Buy every heart patch in Gran's sewing tin."],
	"BESTIARY": ["Nell's List", "Fill every page of Nell's bestiary."],
	"PROOFS": ["Proof Pressed", "Ink a sticker for every story boss on the proof press."],
	"LAST_MARGIN": ["The Last Margin", "Hold out a paw to the Runaway."],
	"SECOND_PRINTING": ["Heavier Type", "Begin a Second Printing."],
}

var unlocked: Dictionary = {}
var _steam: Object


func _ready() -> void:
	_load()
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
	EventBus.flag_set.connect(func(_f: String, _v: Variant) -> void: check_all())
	EventBus.ability_unlocked.connect(func(_a: StringName) -> void: check_all())
	EventBus.upgrade_bought.connect(func(_k: StringName) -> void: check_all())
	EventBus.bestiary_entry.connect(func(_e: String) -> void: check_all())
	EventBus.game_saved.connect(func(_s: int) -> void: check_all())


## Whether achievement `id` has been earned in the current save.
static func earned(id: String) -> bool:
	match id:
		"SHEARS": return GameState.has_ability(&"crease_swipe")
		"MILLWHEEL": return GameState.get_flag("boss_millwheel_defeated")
		"KRAKEN": return GameState.get_flag("boss_kraken_defeated")
		"HERON": return GameState.get_flag("boss_heron_defeated")
		"BINDWELL": return GameState.get_flag("boss_bindwell_defeated")
		"BARKER": return GameState.get_flag("boss_barker_defeated")
		"REDACTOR": return GameState.get_flag("boss_redactor_defeated")
		"FORECAST": return GameState.get_flag("boss_forecast_defeated")
		"THE_END": return GameState.get_flag("game_complete")
		"TAIL": return GameState.get_flag("gave_tail")
		"HEARTS": return ShopPanel.heart_price() < 0
		"BESTIARY": return Bestiary.ENTRIES.keys().all(func(k: String) -> bool: return GameState.bestiary.has(k))
		"PROOFS": return Papers.STORY_BOSSES.all(func(b: String) -> bool: return Rematch.best_rank(b) > 0)
		"LAST_MARGIN": return GameState.get_flag("true_ending")
		"SECOND_PRINTING": return GameState.printing > 0
	return false


func check_all() -> void:
	for id: String in LIST:
		if not unlocked.has(id) and earned(id):
			unlock(id)


func unlock(id: String) -> void:
	if unlocked.has(id) or not LIST.has(id):
		return
	unlocked[id] = Time.get_unix_time_from_system()
	_save()
	if _steam:
		_steam.call("setAchievement", id)
		_steam.call("storeStats")
	if is_inside_tree():
		_toast(LIST[id][0])


func count() -> int:
	return unlocked.size()


## The list as text, for the play report panel: earned ones first, then the rest.
func summary() -> String:
	var lines: Array[String] = ["Achievements: %d of %d" % [count(), LIST.size()]]
	for id: String in LIST:
		var mark := "[x]" if unlocked.has(id) else "[ ]"
		lines.append("    %s %s: %s" % [mark, LIST[id][0], LIST[id][1]])
	return "\n".join(lines) + "\n"


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is Dictionary:
		unlocked = data


func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(unlocked))


## A torn slip at the top of the screen, gone after a few seconds.
func _toast(title: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = "AchievementToast"
	layer.layer = 40
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17110f", 0.92)
	style.border_color = DarkUI.BLOOD
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.position = Vector2(1920 - 560, 40)
	panel.custom_minimum_size = Vector2(520, 0)
	var box := VBoxContainer.new()
	box.add_child(DarkUI.label("Achievement", 18, DarkUI.ASH, true))
	box.add_child(DarkUI.label(title, 28, DarkUI.BONE))
	panel.add_child(box)
	layer.add_child(panel)
	AudioManager.play_sfx(&"stamp")
	var tween := layer.create_tween()
	panel.modulate.a = 0.0
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(3.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(layer.queue_free)

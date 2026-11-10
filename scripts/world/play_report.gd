class_name PlayReport
extends RefCounted
## The play report: how long each page actually took, how often Patch died there and
## how many hits he took, from GameState.page_stats. Written next to the save as
## user://play_report_slot_<n>.txt every time the game saves (on Windows that is
## %APPDATA%/Godot/app_userdata/Patch and the Pop-Up Kingdom/), and readable in the
## pause menu. tools/telemetry/summarize.py totals several reports.

const OTHER := "The Spine and the Margin"


static func path(slot: int) -> String:
	return "user://play_report_slot_%d.txt" % slot


static func clock(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%dm %02ds" % [s / 60, s % 60]


static func page_name(page_path: String) -> String:
	var stem := page_path.get_file().get_basename()
	# "1_2_the_mill_race" -> "1-2 The mill race"
	var parts := stem.split("_")
	var numbers: Array[String] = []
	while not parts.is_empty() and parts[0].is_valid_int():
		numbers.append(parts[0])
		parts.remove_at(0)
	var words := " ".join(parts).capitalize()
	return ("%s %s" % ["-".join(numbers), words]).strip_edges()


## Region name -> {"t", "d", "h", "pages": [[name, stats], ...]}, in book order.
static func by_region(stats: Dictionary) -> Dictionary:
	var out := {}
	for entry: Dictionary in BookMap.REGIONS:
		out[entry["name"]] = {"t": 0.0, "d": 0, "h": 0, "pages": []}
	out[OTHER] = {"t": 0.0, "d": 0, "h": 0, "pages": []}
	var paths := stats.keys()
	paths.sort()
	for page_path: String in paths:
		var s: Dictionary = stats[page_path]
		var region := BookMap.region_of(page_path)
		var key: String = region["name"] if not region.is_empty() else OTHER
		var r: Dictionary = out[key]
		r["t"] += float(s.get("t", 0.0))
		r["d"] += int(s.get("d", 0))
		r["h"] += int(s.get("h", 0))
		(r["pages"] as Array).append([page_name(page_path), s])
	for key in out.keys():
		if (out[key]["pages"] as Array).is_empty():
			out.erase(key)
	return out


static func text(stats: Dictionary, total_time: float) -> String:
	var lines: Array[String] = ["Play report: %s played in all, measured." % clock(total_time), ""]
	var regions := by_region(stats)
	for name: String in regions:
		var r: Dictionary = regions[name]
		lines.append("%s: %s, %d deaths, %d hits taken" % [name, clock(r["t"]), r["d"], r["h"]])
		for page: Array in r["pages"]:
			var s: Dictionary = page[1]
			lines.append("    %s: %s, %d visits, %d deaths, %d hits" % [page[0], clock(float(s.get("t", 0.0))),
				int(s.get("v", 0)), int(s.get("d", 0)), int(s.get("h", 0))])
		lines.append("")
	return "\n".join(lines)


static func write(slot: int) -> void:
	var file := FileAccess.open(path(slot), FileAccess.WRITE)
	if file:
		file.store_string(text(GameState.page_stats, GameState.play_time))


## The report on paper, from the pause menu. Pauses the game while it's open.
class ReportPanel extends CanvasLayer:
	signal closed

	static func open_panel(parent: Node) -> ReportPanel:
		var panel := ReportPanel.new()
		panel.name = "PlayReportPanel"
		parent.add_child(panel)
		return panel

	func _ready() -> void:
		layer = 32
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		var box := DarkUI.dialog(self, Vector2(1100, 820))
		box.add_child(DarkUI.label("Dad's notebook: where the time went", 36, DarkUI.BONE))
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(1040, 600)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.add_child(scroll)
		var body := DarkUI.label(PlayReport.text(GameState.page_stats, GameState.play_time), 22)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(1000, 0)
		scroll.add_child(body)
		var leave := DarkUI.button("Close the notebook")
		leave.pressed.connect(close)
		box.add_child(leave)
		leave.grab_focus.call_deferred()

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			close()

	func close() -> void:
		get_tree().paused = false
		closed.emit()
		queue_free()

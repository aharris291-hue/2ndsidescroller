extends Page
## P-2 The Rising. Drizzle is pinned under a fallen spine at the bottom of the shelf and
## the ink is coming up. The only way out is up. Patch leaves him.
##
## Beats: the intro conversation (flag "left_drizzle") starts the ink. It waits below
## Gran's shelf until Patch has the shears and has beaten the two Soggies that crawl
## out for him ("rising_fight_done"). On the far side of the thread bridge more Soggies
## follow him across, and the exit opens once he cuts the thread ("cut_the_thread").
## A reload starts the ink a fixed distance below Patch, wherever he respawned.

const SOGGY := preload("res://scenes/enemies/soggy.tscn")
## Where the ink waits until the shelf fight is over, and where it stops for good.
const FIGHT_STOP_Y := 1290.0
const FINAL_STOP_Y := 900.0
const FIGHT_SPAWNS := [Vector2(1780, 1152), Vector2(1700, 1152)]
const BRIDGE_SPAWNS := [Vector2(352, 768), Vector2(200, 768)]

@onready var ink: RisingWater = $Ink

var _fighters: Array[Node] = []


func _ready() -> void:
	super._ready()
	ink.stop_y = FINAL_STOP_Y if GameState.get_flag("rising_fight_done") else FIGHT_STOP_Y
	var player := get_tree().get_first_node_in_group(&"player") as Patch
	# Arriving from P-1 makes the bottom of the shelf the place to come back to.
	if player and GameState.checkpoint_page != scene_file_path:
		GameState.set_checkpoint(scene_file_path, player.global_position)
	if player:
		ink.position.y = minf(ink.position.y, player.global_position.y + 560.0)
	ink.set_physics_process(GameState.get_flag("left_drizzle"))
	EventBus.ability_unlocked.connect(_on_ability)
	if GameState.has_ability(&"crease_swipe") and not GameState.get_flag("rising_fight_done"):
		_start_fight.call_deferred()
	if not GameState.get_flag("left_drizzle"):
		_play_intro.call_deferred()


func _play_intro() -> void:
	DialogueUI.start("rising_pinned")
	await EventBus.dialogue_finished
	GameState.set_flag("left_drizzle")
	ink.set_physics_process(true)


func _on_ability(ability_id: StringName) -> void:
	if ability_id == &"crease_swipe":
		_start_fight()


func _start_fight() -> void:
	DialogueUI.narrate("The ink had hands now.")
	_fighters = _spawn(FIGHT_SPAWNS)
	for soggy in _fighters:
		soggy.tree_exited.connect(_on_fighter_gone)


func _on_fighter_gone() -> void:
	if not is_inside_tree():
		return
	for soggy in _fighters:
		if is_instance_valid(soggy) and soggy.is_inside_tree():
			return
	GameState.set_flag("rising_fight_done")
	ink.stop_y = FINAL_STOP_Y


## Called by the trigger on the far side of the thread bridge.
func soggies_on_bridge() -> void:
	if not GameState.get_flag("cut_the_thread"):
		_spawn(BRIDGE_SPAWNS)


func _spawn(points: Array) -> Array[Node]:
	var spawned: Array[Node] = []
	for point in points:
		var soggy := SOGGY.instantiate() as Node2D
		soggy.position = point
		add_child.call_deferred(soggy)
		spawned.append(soggy)
	return spawned

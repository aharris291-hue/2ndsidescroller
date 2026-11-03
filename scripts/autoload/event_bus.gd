extends Node
## Global signals, so systems can react to each other without holding references.
## Emit from the system that owns the change; listen from anywhere.

signal player_health_changed(current: int, maximum: int)
signal player_died
## Patch's Thread meter (see Patch): charges spent on Mend and thread moves.
signal thread_changed(current: float, maximum: float)
signal scraps_changed(total: int)
signal letter_collected(letter: String, total: int)
signal ability_unlocked(ability_id: StringName)
signal checkpoint_reached(page_path: String, spawn_position: Vector2)
signal dialogue_started
signal dialogue_finished
signal page_entered(page: Node)
signal game_saved(slot: int)
signal quest_updated(quest_id: String)
signal boss_started(boss_name: String, max_health: int)
signal boss_health_changed(current: int, maximum: int)
signal boss_defeated
## Patch turned a blow with a well-timed guard / dodged right as it landed.
signal player_parried
signal player_perfect_dodge
## Something bought at Gran's sewing tin: &"heart", &"spool" or &"charm".
signal upgrade_bought(kind: StringName)

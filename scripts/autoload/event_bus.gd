extends Node
## Global signals, so systems can react to each other without holding references.
## Emit from the system that owns the change; listen from anywhere.

signal player_health_changed(current: int, maximum: int)
signal player_died
signal scraps_changed(total: int)
signal letter_collected(letter: String, total: int)
signal ability_unlocked(ability_id: StringName)
signal checkpoint_reached(page_path: String, spawn_position: Vector2)
signal dialogue_started
signal dialogue_finished
signal page_entered(page: Node)
signal game_saved(slot: int)

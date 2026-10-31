class_name NPCCorrugate
extends NPC
## Corrugate, the cardboard tortoise captain of Lanternfold. His story runs in steps:
## he needs real tape from Gran's table, then his cat, and then he joins Patch and
## lifts the harbor flap (the "corrugate_joined" flag opens it).

const JOINED_FLAG := "corrugate_joined"


func _ready() -> void:
	super._ready()
	if GameState.get_flag(JOINED_FLAG):
		queue_free()


func interact(_player: Patch) -> void:
	var talk_id := _pick_dialogue()
	DialogueUI.start(talk_id)
	GameState.set_flag("met_corrugate")
	if talk_id == "corrugate_joins":
		GameState.set_flag(JOINED_FLAG)
		await EventBus.dialogue_finished
		var companion := companion_scene.instantiate() as Node2D
		companion.global_position = global_position
		get_parent().add_child(companion)
		queue_free()


func _pick_dialogue() -> String:
	if not GameState.has_ability(&"tape_tail"):
		return "corrugate_need_tape" if GameState.get_flag("met_corrugate") else "corrugate_intro"
	if not GameState.quest_started(quest_id):
		GameState.start_quest(quest_id)
		return "corrugate_cat"
	if GameState.quest_progress(quest_id) >= GameState.quest_goal(quest_id):
		GameState.complete_quest(quest_id)
		return "corrugate_joins"
	return "corrugate_cat_progress"

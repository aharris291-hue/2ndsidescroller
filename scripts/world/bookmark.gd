class_name Bookmark
extends Area2D
## Checkpoint. Touching a bookmark saves the game, mends Patch to full health,
## and makes this the place he returns to after tearing.

const TEXTURE_OFF := preload("res://assets/art/props/bookmark_off.png")
const TEXTURE_ON := preload("res://assets/art/props/bookmark_on.png")

## Where Patch reappears, relative to the bookmark.
@export var respawn_offset := Vector2(0, -8)

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("bookmarks")
	body_entered.connect(_on_body_entered)
	sprite.texture = TEXTURE_ON if _is_current() else TEXTURE_OFF


func _is_current() -> bool:
	return GameState.checkpoint_page == owner.scene_file_path \
		and GameState.checkpoint_position.distance_to(global_position + respawn_offset) < 1.0


func _on_body_entered(body: Node2D) -> void:
	var player := body as Patch
	if player == null:
		return
	player.health.set_health(player.health.max_health)
	if _is_current():
		return
	for other in get_tree().get_nodes_in_group("bookmarks"):
		other.sprite.texture = TEXTURE_OFF
	sprite.texture = TEXTURE_ON
	GameState.set_checkpoint(owner.scene_file_path, global_position + respawn_offset)
	GameState.save_game()
	AudioManager.play_sfx(&"checkpoint")
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.8), 0.08)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

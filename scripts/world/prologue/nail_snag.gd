extends StoryTrigger
## P-2: the nail that takes Patch's tail. Shows the bare nail until Patch climbs past,
## then the torn scrap of tail stays caught on it (flag "tail_torn").

const BARE := preload("res://assets/art/dark/props/nail_bare.png")
const TORN := preload("res://assets/art/dark/props/nail.png")

var _sprite: Sprite2D


func _ready() -> void:
	super._ready()
	_sprite = Sprite2D.new()
	_sprite.texture = TORN if GameState.get_flag("tail_torn") else BARE
	_sprite.position = Vector2(0, -150)
	add_child(_sprite)
	body_entered.connect(_snag)


func _snag(body: Node2D) -> void:
	if not body is Patch or GameState.get_flag("tail_torn"):
		return
	GameState.set_flag("tail_torn")
	_sprite.texture = TORN
	AudioManager.play_sfx(&"tab_pull", 0.7)
	AudioManager.play_voice(&"hurt")
	(body as Patch).velocity.y = minf((body as Patch).velocity.y, -200.0)

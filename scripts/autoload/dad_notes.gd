extends Node
## Dad, who wrote the book, reacting to how it's being played. Each remark is one of
## his captions (DialogueUI.narrate), shown once per save (flag "dad:<id>"), and never
## more often than every MIN_GAP seconds, so he notices rather than nags.
##
## What he notices: the first parry and perfect dodge, Patch torn again and again on
## one page (the fifth time he points at the assists), Patch down to his last token,
## standing still for a long while, the first things bought at Gran's tin, and each
## region mended.

const MIN_GAP := 45.0
const IDLE_TIME := 50.0
const LINES := {
	"parry": "Patch met the blow and turned it aside. Gran always said he never knew when to back down.",
	"perfect_dodge": "For one long breath the ink moved slower than he did.",
	"torn_3": "Again. Dad's pen hovered over the page. He did not write that Patch gave up, because Patch didn't.",
	"torn_5": "(In the margin, in pencil: if a page is being cruel, the pause menu has assists. Nobody is keeping score.)",
	"last_token": "One scrap of him left. Dad wrote faster.",
	"idle": "Patch stood very still. Somewhere below, the ink was still rising.",
	"bought_heart": "Gran's stitches were small and tight. They held better than his had.",
	"bought_spool": "A fresh spool, still waxed. It smelled like her sewing room.",
	"bought_charm": "He sewed it onto his bandana, crooked, the way she'd shown him.",
	"bought_pattern": "Gran's handwriting on the card, slanting off the edge. Patch read it twice before he tried it.",
	"bowled": "One Soggy went into the next like a dropped stack of plates. Dad underlined it twice.",
	"mended": "Another page sewn back in. Somewhere, the music came a little closer.",
}

## Seconds since the last remark (starts ready).
var _since_last := MIN_GAP
var _idle := 0.0
var _torn_here := 0
var _torn_page := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.player_parried.connect(remark.bind("parry"))
	EventBus.player_perfect_dodge.connect(remark.bind("perfect_dodge"))
	EventBus.player_died.connect(_on_torn)
	EventBus.player_health_changed.connect(_on_health)
	EventBus.upgrade_bought.connect(func(kind: StringName) -> void: remark("bought_" + String(kind)))
	EventBus.boss_defeated.connect(_on_mended)
	EventBus.enemy_bowled.connect(remark.bind("bowled"))
	EventBus.page_entered.connect(func(_page: Node) -> void: _idle = 0.0)


## Shows one of Dad's remarks if he hasn't made it before and isn't talking already.
## Returns whether it was shown. `force` skips the time gap (big moments).
func remark(id: String, force := false) -> bool:
	if not LINES.has(id) or GameState.sandbox or not GameState.in_gameplay:
		return false
	var flag := "dad:" + id
	if GameState.get_flag(flag) or (_since_last < MIN_GAP and not force):
		return false
	if DialogueUI.is_active():
		return false
	GameState.set_flag(flag)
	_since_last = 0.0
	DialogueUI.narrate(LINES[id])
	return true


func _process(delta: float) -> void:
	_since_last += delta
	if not GameState.in_gameplay or DialogueUI.is_active() or SceneManager.is_transitioning:
		_idle = 0.0
		return
	_idle += delta
	if _idle >= IDLE_TIME:
		_idle = 0.0
		remark("idle")


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		_idle = 0.0


func _on_torn() -> void:
	if GameState.current_page != _torn_page:
		_torn_page = GameState.current_page
		_torn_here = 0
	_torn_here += 1
	if _torn_here == 3:
		remark("torn_3", true)
	elif _torn_here >= 5:
		remark("torn_5", true)


func _on_health(current: int, _maximum: int) -> void:
	if current > 0 and current <= 2:
		remark("last_token")


func _on_mended() -> void:
	# The flag is per save: say it for the first boss, after that the music says it.
	remark("mended", true)

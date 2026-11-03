class_name StyleMeter
extends Node
## How well Patch is fighting, in Gran's words for sewing that holds. Landed cuts,
## parries, perfect dodges, Unstitches, form switches and knocking one enemy into
## another all add to it; the same move over and over adds less and less. Taking a hit
## drops a whole rank, and standing about lets it drain.
##
## The higher the rank, the more Thread each landed cut gives (thread_bonus), so
## fighting well is also how Patch heals. The HUD shows the rank (EventBus.style_changed).

const RANKS := ["", "Tacked", "Basted", "Stitched", "Seamed", "Gran's Hand"]
const PER_RANK := 10.0
const TOP := 5
## Points per move, before the repeat penalty.
const VALUES := {
	&"light": 1.0, &"thrust": 2.0, &"air": 1.5, &"overhead": 1.2, &"heavy": 2.0,
	&"launcher": 2.5, &"charged": 3.0, &"plunge": 2.5, &"parry": 4.0,
	&"perfect_dodge": 3.0, &"unstitch": 5.0, &"bowled": 3.0, &"switch": 1.5,
}
## The same move again within the last few is worth this much less each time.
const REPEAT := [1.0, 0.6, 0.3, 0.15, 0.1]
const MEMORY := 4
const DRAIN_DELAY := 2.5

var points := 0.0
var _recent: Array[StringName] = []
var _idle := 0.0
var _last_rank := 0


func _ready() -> void:
	EventBus.player_parried.connect(add.bind(&"parry"))
	EventBus.player_perfect_dodge.connect(add.bind(&"perfect_dodge"))
	EventBus.enemy_bowled.connect(add.bind(&"bowled"))
	EventBus.page_entered.connect(func(_page: Node) -> void: reset())
	_emit()


func rank() -> int:
	return mini(floori(points / PER_RANK), TOP)


func rank_name() -> String:
	return RANKS[rank()]


## How full the current rank is, 0..1 (always full at the top).
func fill() -> float:
	return 1.0 if rank() >= TOP else fmod(points, PER_RANK) / PER_RANK


func thread_bonus() -> float:
	return 1.0 + 0.1 * rank()


func add(move: StringName) -> void:
	var value: float = VALUES.get(move, 1.0)
	value *= REPEAT[mini(_recent.count(move), REPEAT.size() - 1)]
	_recent.push_back(move)
	if _recent.size() > MEMORY:
		_recent.pop_front()
	points = minf(points + value, PER_RANK * TOP)
	_idle = 0.0
	_emit()


## Patch took a hit: down a whole rank, to the bottom of it.
func hurt() -> void:
	points = maxf(rank() - 1, 0) * PER_RANK
	_recent.clear()
	_emit()


func reset() -> void:
	points = 0.0
	_recent.clear()
	_emit()


func _process(delta: float) -> void:
	if points <= 0.0:
		return
	_idle += delta
	if _idle > DRAIN_DELAY:
		points = maxf(points - (1.5 + rank()) * delta, 0.0)
		_emit()


func _emit() -> void:
	var now := rank()
	if now == TOP and _last_rank < TOP:
		DadNotes.remark("style_top")
	_last_rank = now
	EventBus.style_changed.emit(now, fill())

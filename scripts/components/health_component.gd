class_name HealthComponent
extends Node
## Hit points with a short invulnerability window after each hit.
## For Patch, health is "paper condition": every 2 points is one crisp/creased/torn token.

signal changed(current: int, maximum: int)
signal damaged(amount: int, from_position: Vector2)
signal died

@export var max_health := 6
@export var invulnerability_time := 0.8

## Damage never takes health below this (0 = can die). For scripted fights that must
## end in a cutscene, not a game over.
var floor_health := 0
var current := 0
var _invulnerable_left := 0.0


func _ready() -> void:
	# The Second Printing: everything but Patch (who sets his own) is half again as tough.
	if GameState.printing > 0 and current <= 0 and not get_parent() is Patch:
		max_health = ceili(max_health * SecondPrinting.ENEMY_HEALTH)
	if current <= 0:
		current = max_health
	# Enemies join their group in their own _ready, which runs after this one.
	_add_enemy_bar.call_deferred()


## Ordinary enemies get a small bar over their heads (bosses use the HUD's).
func _add_enemy_bar() -> void:
	var body := get_parent() as Node2D
	if body and body.is_in_group(&"enemies") and not &"boss_name" in body and max_health > 1:
		EnemyBar.attach(body, self)


func _physics_process(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func is_dead() -> bool:
	return current <= 0


## Returns true if the damage landed (not blocked by invulnerability).
func take_damage(amount: int, from_position: Vector2) -> bool:
	if is_dead() or is_invulnerable() or amount <= 0:
		return false
	current = maxi(current - amount, floor_health)
	_invulnerable_left = invulnerability_time
	changed.emit(current, max_health)
	damaged.emit(amount, from_position)
	if current == 0:
		died.emit()
	return true


## A short window where nothing can hurt (a parry, a finisher).
func grant_invulnerability(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


func clear_invulnerability() -> void:
	_invulnerable_left = 0.0


func heal(amount: int) -> void:
	if is_dead():
		return
	current = mini(current + amount, max_health)
	changed.emit(current, max_health)


func set_health(value: int) -> void:
	current = clampi(value, 0, max_health)
	changed.emit(current, max_health)

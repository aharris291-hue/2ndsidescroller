class_name BossStagger
extends RefCounted
## Boss Hold bars. Every boss gets a HoldComponent that only wears down while it is
## open (stunned, jammed or pinned, see each boss's can_stagger). Light cuts barely
## scratch it; heavy and charged cuts tear it. When it breaks, the boss's window stays
## open for the stagger and its seams show: a heavy press there Unstitches it for a
## big chunk of health (Patch's finisher, aimed at the boss's finisher_point).
##
## The HUD shows the bar under the boss's health (EventBus.boss_hold_changed).

const MAX_HOLD := 6.0
const STAGGER_TIME := 3.0
const UNSTITCH_DAMAGE := 3


static func attach(boss: Node2D, max_hold := MAX_HOLD) -> HoldComponent:
	var hold := HoldComponent.new()
	hold.name = &"HoldComponent"
	hold.max_hold = max_hold
	hold.stagger_time = STAGGER_TIME
	# Slow to knit back, so the work done in one window carries into the next.
	hold.regen_delay = 6.0
	hold.regen_rate = 0.5
	boss.add_child(hold)
	hold.owner = boss
	hold.changed.connect(func(current: float, maximum: float) -> void:
		EventBus.boss_hold_changed.emit(current, maximum))
	hold.broken.connect(func() -> void:
		EventBus.boss_hold_changed.emit(0.0, hold.max_hold)
		EventBus.boss_staggered.emit(true)
		AudioManager.play_sfx(&"tab_pull", 0.5)
		TimeFX.hitstop(0.12)
		if boss.has_method(&"finisher_point"):
			Tells.glint(boss, boss.to_local(boss.finisher_point()) + Vector2(0, -40), 0.8))
	hold.recovered.connect(func() -> void: EventBus.boss_staggered.emit(false))
	return hold


## The boss's window closed (it recovered): a broken Hold knits back up at once, so
## it can't be Unstitched mid-attack.
static func close(hold: HoldComponent) -> void:
	if hold and hold.is_broken():
		hold.clear()
		EventBus.boss_staggered.emit(false)


## The boss is Unstitched: a big hit that ignores its invulnerability flicker.
## Returns true if the boss lived through it.
static func unstitch(boss: Node2D, health: HealthComponent, hold: HoldComponent, damage := UNSTITCH_DAMAGE) -> bool:
	hold.clear()
	EventBus.boss_staggered.emit(false)
	health.clear_invulnerability()
	health.take_damage(damage, boss.global_position)
	EventBus.boss_health_changed.emit(health.current, health.max_health)
	return not health.is_dead()

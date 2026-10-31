class_name BossMillwheel
extends Node2D
## Old Millwheel, the Chapter 1 boss: a waterlogged windmill golem.
##
## Loop: its soggy sails sweep the arena (jump them!) while ink drips fall. Pull all
## three mooring tabs to jam the sails; that exposes its button core for a few seconds.
## Swipe the core, then the tabs shake loose, more Soggies arrive, and the sails speed up.
## At zero health it isn't destroyed: it dries out, shrinks, and the way on opens.

enum State { WAITING, SPINNING, JAMMED, DEFEATED }

const SOGGY_SCENE := preload("res://scenes/enemies/soggy.tscn")
const DRIP_SCENE := preload("res://scenes/enemies/ink_drip.tscn")

@export var boss_name := "Old Millwheel"
## The mooring PullTabs that jam the sails when all are pulled.
@export var tabs: Array[Node] = []
@export var exit_door: PageDoor
## The fight starts when Patch walks into this area.
@export var start_zone: Area2D
## Sail speed (radians/second) per phase, from full health down.
@export var sail_speeds: Array[float] = [1.1, 1.6, 2.2]
@export var jam_time := 4.5
@export var drip_interval := 1.5
@export var arena_left := 160.0
@export var arena_right := 1180.0
@export var floor_y := 896.0
@export var defeated_flag := "boss_millwheel_defeated"

var state := State.WAITING
var _drip_left := 0.0
var _jam_left := 0.0

@onready var body: Sprite2D = $Body
@onready var sails: Node2D = $Sails
@onready var core: Hurtbox = $Core
@onready var health: HealthComponent = $HealthComponent


func _ready() -> void:
	core.hit.connect(_on_core_hit)
	health.died.connect(_on_defeated)
	for tab in tabs:
		(tab as PullTab).toggled.connect(_on_tab_toggled)
	if start_zone:
		start_zone.body_entered.connect(func(b: Node2D) -> void:
			if b is Patch:
				start_fight())
	if GameState.get_flag(defeated_flag):
		_show_exit()
		queue_free()
		return
	_set_core_exposed(false)
	if exit_door:
		exit_door.visible = false
		exit_door.set_deferred("monitorable", false)


## Called by the arena when Patch walks in.
func start_fight() -> void:
	if state != State.WAITING:
		return
	state = State.SPINNING
	EventBus.boss_started.emit(boss_name, health.max_health)
	DialogueUI.narrate("The old mill groaned awake. Its soggy sails began to turn. Pull the mooring tabs to jam them!")


func _physics_process(delta: float) -> void:
	match state:
		State.SPINNING:
			sails.rotation += _sail_speed() * delta
			_drip_left -= delta
			if _drip_left <= 0.0:
				_drip_left = drip_interval
				_spawn_drip()
		State.JAMMED:
			# Rattle against the tabs while jammed.
			sails.rotation += sin(Time.get_ticks_msec() * 0.03) * 0.004
			_jam_left -= delta
			if _jam_left <= 0.0:
				_recover()


func _sail_speed() -> float:
	var phase := clampi(sail_speeds.size() - ceili(float(health.current) / health.max_health * sail_speeds.size()), 0, sail_speeds.size() - 1)
	return sail_speeds[phase]


func _on_tab_toggled(_pulled: bool) -> void:
	if state != State.SPINNING:
		return
	for tab in tabs:
		if not (tab as PullTab).is_pulled:
			return
	state = State.JAMMED
	_jam_left = jam_time
	_set_blades_active(false)
	_set_core_exposed(true)
	AudioManager.play_sfx(&"tab_pull", 0.6)
	DialogueUI.narrate("The sails jammed! Its button core is showing. Swipe it!")


func _on_core_hit(hitbox: Hitbox) -> void:
	if state != State.JAMMED:
		return
	if health.take_damage(hitbox.damage, hitbox.global_position):
		EventBus.boss_health_changed.emit(health.current, health.max_health)
		AudioManager.play_sfx(&"enemy_pop", 0.7)
		var tween := create_tween()
		body.modulate = Color(1.6, 1.6, 1.6)
		tween.tween_property(body, "modulate", Color.WHITE, 0.25)
		# Three hits per jam knock it back into motion early.
		if not health.is_dead() and health.current % 3 == 0:
			_recover()


func _recover() -> void:
	if state == State.DEFEATED:
		return
	state = State.SPINNING
	_set_core_exposed(false)
	_set_blades_active(true)
	for tab in tabs:
		(tab as PullTab).reset()
	for i in 2:
		var soggy := SOGGY_SCENE.instantiate() as Node2D
		soggy.position = Vector2(randf_range(arena_left + 100.0, arena_right - 200.0), floor_y - 300.0)
		get_parent().add_child.call_deferred(soggy)


func _on_defeated() -> void:
	state = State.DEFEATED
	_set_core_exposed(false)
	_set_blades_active(false)
	GameState.set_flag(defeated_flag)
	EventBus.boss_defeated.emit()
	DialogueUI.narrate("The warm Great Light dried Old Millwheel out. With a creak and a sigh, it folded back into a plain little windmill.")
	var tween := create_tween().set_parallel()
	tween.tween_property(sails, "rotation", sails.rotation + TAU, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(0.55, 0.55), 2.0).set_trans(Tween.TRANS_BACK)
	tween.tween_property(body, "self_modulate", Color(1.15, 1.05, 0.9), 2.0)
	await tween.finished
	_show_exit()
	GameState.save_game()


func _show_exit() -> void:
	if exit_door:
		exit_door.visible = true
		exit_door.set_deferred("monitorable", true)


func _spawn_drip() -> void:
	var drip := DRIP_SCENE.instantiate() as Node2D
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var x := player.global_position.x if player and randf() < 0.6 else randf_range(arena_left, arena_right)
	drip.position = Vector2(clampf(x + randf_range(-80, 80), arena_left, arena_right), 120.0)
	drip.set("floor_y", floor_y - 20.0)
	get_parent().add_child(drip)


func _set_blades_active(active: bool) -> void:
	for blade in sails.get_children():
		if blade is Hitbox:
			blade.active = active


func _set_core_exposed(exposed: bool) -> void:
	core.visible = exposed
	core.set_deferred("monitoring", exposed)

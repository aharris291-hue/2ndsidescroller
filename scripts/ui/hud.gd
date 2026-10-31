extends CanvasLayer
## In-game HUD: paper-condition tokens (health), Scraps, and Lost Letters.
## Each token is worth 2 health: crisp (2), creased (1), torn (0).

const CRISP := preload("res://assets/art/ui/health_crisp.png")
const CREASED := preload("res://assets/art/ui/health_creased.png")
const TORN := preload("res://assets/art/ui/health_torn.png")

@onready var tokens: HBoxContainer = $Root/Top/Tokens
@onready var scraps_label: Label = $Root/Top/ScrapsLabel
@onready var letters_label: Label = $Root/Top/LettersLabel
@onready var boss_bar: Control = $Root/BossBar
@onready var boss_name: Label = $Root/BossBar/BossName
@onready var boss_health: ProgressBar = $Root/BossBar/BossHealth


func _ready() -> void:
	layer = 10
	visible = false
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.scraps_changed.connect(func(total: int) -> void: scraps_label.text = "x %d" % total)
	EventBus.letter_collected.connect(func(_l: String, total: int) -> void: _set_letters(total))
	EventBus.boss_started.connect(_on_boss_started)
	EventBus.boss_health_changed.connect(func(current: int, _max: int) -> void: boss_health.value = current)
	EventBus.boss_defeated.connect(func() -> void: boss_bar.visible = false)
	EventBus.page_entered.connect(func(_page: Node) -> void: boss_bar.visible = false)
	boss_bar.visible = false


func show_hud(show: bool) -> void:
	visible = show
	if show:
		scraps_label.text = "x %d" % GameState.scraps
		_set_letters(GameState.letters.size())


func _set_letters(total: int) -> void:
	letters_label.text = "Lost Letters %d/%d" % [total, GameState.LETTER_TOTAL]


func _on_health_changed(current: int, maximum: int) -> void:
	var count := ceili(maximum / 2.0)
	while tokens.get_child_count() < count:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(56, 56)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tokens.add_child(icon)
	while tokens.get_child_count() > count:
		var extra := tokens.get_child(tokens.get_child_count() - 1)
		tokens.remove_child(extra)
		extra.queue_free()
	for i in count:
		var points := clampi(current - i * 2, 0, 2)
		var icon := tokens.get_child(i) as TextureRect
		icon.texture = [TORN, CREASED, CRISP][points]


func _on_boss_started(display_name: String, max_health: int) -> void:
	boss_name.text = display_name
	boss_health.max_value = max_health
	boss_health.value = max_health
	boss_bar.visible = true

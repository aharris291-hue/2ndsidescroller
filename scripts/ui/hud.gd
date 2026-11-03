extends CanvasLayer
## In-game HUD: paper-condition tokens (health), Scraps, and Lost Letters.
## Each token is worth 2 health: crisp (2), creased (1), torn (0).

const CRISP := preload("res://assets/art/dark/ui/health_crisp.png")
const CREASED := preload("res://assets/art/dark/ui/health_creased.png")
const TORN := preload("res://assets/art/dark/ui/health_torn.png")

@onready var tokens: HBoxContainer = $Root/Top/Tokens
@onready var scraps_label: Label = $Root/Top/ScrapsLabel
@onready var letters_label: Label = $Root/Top/LettersLabel
@onready var boss_bar: Control = $Root/BossBar
@onready var boss_name: Label = $Root/BossBar/BossName
@onready var boss_health: ProgressBar = $Root/BossBar/BossHealth
## Thread: one little spool bar per charge, wound with Gran's red thread.
var _spools: HBoxContainer
## The boss's Hold: a thin bone-white bar under its health. When it breaks the bar
## burns red and a line says how to Unstitch.
var boss_hold: ProgressBar
var boss_seam: Label


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
	_style_dark()
	_build_hold_bar()
	_spools = HBoxContainer.new()
	_spools.name = "ThreadSpools"
	_spools.add_theme_constant_override(&"separation", 6)
	tokens.get_parent().add_child(_spools)
	tokens.get_parent().move_child(_spools, tokens.get_index() + 1)
	EventBus.thread_changed.connect(_on_thread_changed)
	_on_thread_changed(GameState.thread, GameState.thread_max)


func _on_thread_changed(current: float, maximum: float) -> void:
	var count := int(ceil(maximum))
	while _spools.get_child_count() < count:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(22, 52)
		bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.08, 0.07, 0.07, 0.85)
		back.border_color = Color("1c1612")
		back.set_border_width_all(3)
		back.set_corner_radius_all(6)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("8f1e1a")
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override(&"background", back)
		bar.add_theme_stylebox_override(&"fill", fill)
		_spools.add_child(bar)
	while _spools.get_child_count() > count:
		var extra := _spools.get_child(_spools.get_child_count() - 1)
		_spools.remove_child(extra)
		extra.queue_free()
	for i in count:
		var bar := _spools.get_child(i) as ProgressBar
		bar.value = clampf(current - i, 0.0, 1.0)
		bar.modulate = Color(1.15, 1.15, 1.15) if current - i >= 1.0 else Color.WHITE


## Dark rebuild: bone-coloured text with a heavy shadow, so it reads over rain and fog.
func _style_dark() -> void:
	for label: Label in [scraps_label, letters_label, boss_name]:
		label.add_theme_color_override(&"font_color", Color("d8d0c0"))
		label.add_theme_color_override(&"font_outline_color", Color(0.04, 0.03, 0.03, 0.9))
		label.add_theme_constant_override(&"outline_size", 8)
	$Root/Top/ScrapIcon.modulate = Color(0.72, 0.68, 0.62)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.06, 0.05, 0.05, 0.85)
	back.border_color = Color("2a1d18")
	back.set_border_width_all(3)
	back.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("7a1a16")
	fill.border_color = Color("2a1d18")
	fill.set_border_width_all(3)
	fill.set_corner_radius_all(2)
	boss_health.add_theme_stylebox_override(&"background", back)
	boss_health.add_theme_stylebox_override(&"fill", fill)


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
	boss_hold.max_value = BossStagger.MAX_HOLD
	boss_hold.value = BossStagger.MAX_HOLD
	_set_seam_open(false)


func _build_hold_bar() -> void:
	boss_hold = ProgressBar.new()
	boss_hold.name = "BossHold"
	boss_hold.custom_minimum_size = Vector2(920, 10)
	boss_hold.show_percentage = false
	boss_hold.max_value = BossStagger.MAX_HOLD
	boss_hold.value = BossStagger.MAX_HOLD
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.06, 0.05, 0.05, 0.85)
	back.border_color = Color("2a1d18")
	back.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("cfc4ad")
	boss_hold.add_theme_stylebox_override(&"background", back)
	boss_hold.add_theme_stylebox_override(&"fill", fill)
	boss_bar.add_child(boss_hold)
	boss_seam = Label.new()
	boss_seam.name = "BossSeam"
	boss_seam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_seam.add_theme_font_size_override(&"font_size", 24)
	boss_seam.add_theme_color_override(&"font_color", Color("e05a48"))
	boss_seam.add_theme_color_override(&"font_outline_color", Color(0.04, 0.03, 0.03, 0.9))
	boss_seam.add_theme_constant_override(&"outline_size", 8)
	boss_seam.modulate.a = 0.0
	boss_bar.add_child(boss_seam)
	# Room for the two new rows above the bottom edge.
	boss_bar.offset_top -= 46.0
	EventBus.boss_hold_changed.connect(func(current: float, maximum: float) -> void:
		boss_hold.max_value = maximum
		boss_hold.value = current)
	EventBus.boss_staggered.connect(_set_seam_open)


func _set_seam_open(open: bool) -> void:
	var fill := boss_hold.get_theme_stylebox(&"fill") as StyleBoxFlat
	fill.bg_color = Color("e05a48") if open else Color("cfc4ad")
	if open:
		# Broken: the whole bar burns red while the seams are open.
		boss_hold.value = boss_hold.max_value
	boss_seam.text = "Its seams are open: %s to Unstitch" % InputGlyphs.hint(&"heavy") if open else ""
	boss_seam.modulate.a = 1.0 if open else 0.0

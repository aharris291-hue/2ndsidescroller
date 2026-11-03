class_name ShopPanel
extends CanvasLayer
## Gran's sewing tin: Patch spends Scraps on heart patches (one more paper token each),
## Thread spools (one more Thread charge each) and stitch charms, and sews charms on
## or takes them off. The game is paused while it's open.

signal closed

## Prices go up with each one bought; the list's length is the stock.
const HEART_PRICES: Array[int] = [40, 80, 120, 160]
const SPOOL_PRICES: Array[int] = [60, 120]
const CHARM_PRICES := {
	&"wax_thread": 50,
	&"magpie_button": 60,
	&"red_knot": 70,
	&"heron_pin": 80,
	&"thimble": 90,
}

var _list: VBoxContainer
var _scraps: Label
var _note: Label
var _close: Button


static func open_panel(parent: Node) -> ShopPanel:
	var shop := ShopPanel.new()
	parent.add_child(shop)
	return shop


func _ready() -> void:
	layer = 32
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var box := DarkUI.dialog(self, Vector2(940, 720))
	box.add_child(DarkUI.label("Gran's sewing tin", 40, DarkUI.BONE))
	box.add_child(DarkUI.label("A biscuit tin of needles, buttons and thread that smells of her. Whatever Patch finds, she would have known what to mend with it.", 22, DarkUI.ASH, true))
	_scraps = DarkUI.label("", 26, DarkUI.BONE)
	box.add_child(_scraps)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 8)
	box.add_child(_list)
	_note = DarkUI.label("", 22, DarkUI.ASH, true)
	_note.custom_minimum_size.y = 32
	box.add_child(_note)
	_close = DarkUI.button("Close the tin")
	_close.pressed.connect(close)
	box.add_child(_close)
	_rebuild(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	get_tree().paused = false
	GameState.save_game()
	closed.emit()
	queue_free()


static func heart_price() -> int:
	var bought := GameState.heart_patches
	return HEART_PRICES[bought] if bought < HEART_PRICES.size() else -1


static func spool_price() -> int:
	var bought := GameState.spools
	return SPOOL_PRICES[bought] if bought < SPOOL_PRICES.size() else -1


## Buys the next heart patch; false if sold out or Patch can't afford it.
static func buy_heart() -> bool:
	var price := heart_price()
	if price < 0 or GameState.scraps < price:
		return false
	GameState.add_scraps(-price)
	GameState.add_heart_patch()
	_sync_player()
	EventBus.upgrade_bought.emit(&"heart")
	return true


static func buy_spool() -> bool:
	var price := spool_price()
	if price < 0 or GameState.scraps < price:
		return false
	GameState.add_scraps(-price)
	GameState.add_spool()
	EventBus.upgrade_bought.emit(&"spool")
	return true


static func buy_charm(charm_id: StringName) -> bool:
	if GameState.charms.has(charm_id) or not CHARM_PRICES.has(charm_id):
		return false
	var price: int = CHARM_PRICES[charm_id]
	if GameState.scraps < price:
		return false
	GameState.add_scraps(-price)
	GameState.gain_charm(charm_id)
	# Sew it straight on if there's a free slot.
	GameState.set_charm_equipped(charm_id, true)
	EventBus.upgrade_bought.emit(&"charm")
	return true


## Patch's own health keeps a copy of the maximum; give him the new token, full.
static func _sync_player() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var player := tree.get_first_node_in_group(&"player")
	if player and player.get(&"health"):
		var health: HealthComponent = player.get(&"health")
		health.max_health = GameState.max_health
		health.set_health(health.max_health)


func _rebuild(focus_index: int) -> void:
	for child in _list.get_children():
		child.free()
	_scraps.text = "Scraps: %d        Heart patches: %d/%d        Spools: %d/%d        Charms sewn on: %d/%d" % [
		GameState.scraps, GameState.heart_patches, HEART_PRICES.size(),
		GameState.spools, SPOOL_PRICES.size(), GameState.equipped.size(), GameState.charm_slots]
	_add_row(_offer_text("Heart patch", "one more paper token", heart_price()),
		heart_price(), buy_heart, "Gran's tight little stitches. Patch feels harder to tear.")
	_add_row(_offer_text("Thread spool", "one more Thread charge", spool_price()),
		spool_price(), buy_spool, "A fresh spool, still waxed. More Thread to mend with.")
	for charm_id: StringName in CHARM_PRICES:
		if GameState.charms.has(charm_id):
			var on := GameState.equipped.has(charm_id)
			var b := DarkUI.button("%s %s: %s" % ["Take off" if on else "Sew on",
				Charms.display_name(charm_id), Charms.description(charm_id)], 22)
			b.pressed.connect(_toggle_charm.bind(charm_id))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_list.add_child(b)
		else:
			var price: int = CHARM_PRICES[charm_id]
			_add_row("%s (charm): %s   %d scraps" % [Charms.display_name(charm_id), Charms.description(charm_id), price],
				price, buy_charm.bind(charm_id), "%s, sewn onto his bandana." % Charms.display_name(charm_id))
	var buttons := _list.get_children()
	var target: Control = _close
	for i in range(mini(focus_index, buttons.size() - 1), buttons.size()):
		if not (buttons[i] as Button).disabled:
			target = buttons[i]
			break
	target.grab_focus.call_deferred()


func _offer_text(item: String, what: String, price: int) -> String:
	if price < 0:
		return "%s: %s   (none left)" % [item, what]
	return "%s: %s   %d scraps" % [item, what, price]


func _add_row(text: String, price: int, buy: Callable, bought_note: String) -> void:
	var b := DarkUI.button(text, 22)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = price < 0 or GameState.scraps < price
	var index := _list.get_child_count()
	b.pressed.connect(func() -> void:
		if buy.call():
			AudioManager.play_sfx(&"checkpoint")
			_note.text = bought_note
		_rebuild(index))
	_list.add_child(b)


func _toggle_charm(charm_id: StringName) -> void:
	var index := _list.get_children().find(get_viewport().gui_get_focus_owner())
	var on := GameState.equipped.has(charm_id)
	if not GameState.set_charm_equipped(charm_id, not on):
		_note.text = "Both slots are full. Take a charm off first."
	else:
		_note.text = ""
	_rebuild(maxi(index, 0))

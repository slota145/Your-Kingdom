class_name GoodsStrip
extends PanelContainer
## The goods the player keeps an eye on, under the top bar (UI-3 part 1, a friend's playtest
## 2026-11-23: no opening of "Stocks" every moment): an icon and the stock of each, by default
## wood, stone, planks and all the food together; "+" picks others or takes them off. The
## choice is the player's (Options "game/pinned_goods"), not the save's.

## The pseudo good counting every food together.
const FOOD := "food"
## Goods eaten as food (their category).
const FOOD_CATEGORY := &"food"
## Most goods on the strip (it has to fit next to the messages on a small screen).
const MAX_PINNED := 10
const OPTION := "game/pinned_goods"
## Seconds between two countings (the stock sums every storage).
const REFRESH_SECONDS := 0.5
const ICON_SIZE := Vector2(26, 26)

var province: ProvinceSim
var data: DataRegistry

var _row: HBoxContainer
var _add: Button
var _menu: PopupMenu
## Pinned id -> the label with its number.
var _values: Dictionary[String, Label] = {}
## Menu item index -> pinned id.
var _menu_ids: Array[String] = []
var _timer: float = 0.0


func _init() -> void:
	theme = UiKit.board_theme()
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 10)
	add_child(_row)
	_add = Button.new()
	_add.text = "+"
	_add.focus_mode = Control.FOCUS_NONE
	_add.tooltip_text = "ui.pinned.add_tip"
	_add.custom_minimum_size = Vector2(30, 0)
	_add.pressed.connect(_open_menu)
	_menu = PopupMenu.new()
	_menu.theme = UiKit.theme()
	_menu.hide_on_checkable_item_selection = false
	_menu.id_pressed.connect(_on_menu_pressed)
	add_child(_menu)
	Options.changed.connect(_on_option_changed)


func setup(registry: DataRegistry) -> void:
	data = registry
	_rebuild()


## The ids on the strip, in order (goods and [constant FOOD]).
static func pinned() -> PackedStringArray:
	return PackedStringArray(Options.get_value(OPTION))


static func set_pinned(ids: PackedStringArray) -> void:
	# An Array: the options file keeps the type of the default.
	Options.set_value(OPTION, Array(ids))


## [param id] on the strip or off it (at most [constant MAX_PINNED]).
static func toggle(id: String) -> void:
	var ids := pinned()
	var at := ids.find(id)
	if at >= 0:
		ids.remove_at(at)
	elif ids.size() < MAX_PINNED:
		ids.append(id)
	set_pinned(ids)


## The stock of [param id] in [param p]: one good, or all the food together.
static func amount(p: ProvinceSim, registry: DataRegistry, id: String) -> int:
	if id != FOOD:
		return p.kingdom_stock(StringName(id))
	var sum := 0
	for good: GoodDef in registry.goods():
		if good.category == FOOD_CATEGORY:
			sum += p.kingdom_stock(good.id)
	return sum


func _on_option_changed(key: String) -> void:
	if key == OPTION:
		_rebuild()


func _rebuild() -> void:
	if data == null:
		return
	for child: Node in _row.get_children():
		_row.remove_child(child)
		if child != _add:
			child.queue_free()
	_values.clear()
	for id: String in pinned():
		if id != FOOD and data.get_good(StringName(id)) == null:
			continue
		var box := HBoxContainer.new()
		box.add_theme_constant_override(&"separation", 4)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.tooltip_text = _name(id)
		var icon := TextureRect.new()
		icon.texture = ArtPaths.texture("goods/icons/%s.png" % ("bread" if id == FOOD else id))
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var value := UiKit.label("", false)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(value)
		_row.add_child(box)
		_values[id] = value
	_row.add_child(_add)
	_refresh()


func _name(id: String) -> String:
	return tr("ui.pinned.food") if id == FOOD else tr("good.%s.name" % id)


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= REFRESH_SECONDS:
		_refresh()


func _refresh() -> void:
	_timer = 0.0
	if province == null or data == null:
		return
	for id: String in _values:
		_values[id].text = str(amount(province, data, id))
		_values[id].get_parent().tooltip_text = _tip(id)


## The tooltip of [param id]: its name, for food also each kind.
func _tip(id: String) -> String:
	if id != FOOD:
		return _name(id)
	var parts := PackedStringArray()
	for good: GoodDef in data.goods():
		if good.category == FOOD_CATEGORY:
			parts.append("%s: %d" % [tr(good.name_key()), province.kingdom_stock(good.id)])
	return "%s\n%s" % [_name(id), "\n".join(parts)]


## The list of goods to pin: food together first, then every good by name; ticked = pinned.
func _open_menu() -> void:
	_menu.clear()
	_menu_ids.clear()
	var ids := pinned()
	var all: Array[String] = [FOOD]
	var goods: Array[GoodDef] = data.goods().duplicate()
	goods.sort_custom(func(a: GoodDef, b: GoodDef) -> bool: return tr(a.name_key()) < tr(b.name_key()))
	for good: GoodDef in goods:
		all.append(String(good.id))
	for i: int in all.size():
		_menu.add_check_item(_name(all[i]), i)
		_menu.set_item_checked(i, ids.has(all[i]))
		_menu.set_item_disabled(i, not ids.has(all[i]) and ids.size() >= MAX_PINNED)
		_menu_ids.append(all[i])
	_menu.reset_size()
	var at := _add.get_screen_position() + Vector2(0, _add.size.y)
	_menu.popup(Rect2i(Vector2i(at), Vector2i.ZERO))


func _on_menu_pressed(index: int) -> void:
	if index < 0 or index >= _menu_ids.size():
		return
	toggle(_menu_ids[index])
	var ids := pinned()
	for i: int in _menu_ids.size():
		_menu.set_item_checked(i, ids.has(_menu_ids[i]))
		_menu.set_item_disabled(i, not ids.has(_menu_ids[i]) and ids.size() >= MAX_PINNED)

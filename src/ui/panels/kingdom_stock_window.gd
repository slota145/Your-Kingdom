class_name KingdomStockWindow
extends PanelContainer
## "Kingdom stocks" (ROADMAP M4b-2): every good with what the province holds (storages,
## stacks by workshops, herds, market stalls and goods on the ground), how much it makes and
## uses per minute (average of the last 5 minutes) and the balance, green or red. The last
## column says what the travelling merchant may buy: everything above the number, when ticked.

signal command_requested(command: Command)
signal closed

const REFRESH := 0.5
const COLUMNS := 7

var province: ProvinceSim

var _grid: GridContainer
var _hint: Label
var _rows: Dictionary[StringName, Dictionary] = {}
var _timer: float = 0.0


func _init() -> void:
	# Opaque: the window covers a busy town and has many small numbers.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.11, 0.09, 0.97)
	style.set_content_margin_all(12.0)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override(&"panel", style)
	var box := VBoxContainer.new()
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiKit.title("ui.stocks.title")
	title.custom_minimum_size.x = 0
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.button("ui.close", func() -> void: closed.emit()))
	_hint = UiKit.label("ui.stocks.hint")
	_hint.custom_minimum_size.x = 640.0
	_hint.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	box.add_child(_hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", 14)
	scroll.add_child(_grid)


func open(source: ProvinceSim) -> void:
	province = source
	visible = true
	_build_rows()
	_refresh()


func _process(delta: float) -> void:
	if not visible or province == null:
		return
	_timer += delta
	if _timer >= REFRESH:
		_refresh()


func _small(text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	return l


func _build_rows() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_rows.clear()
	for key: String in ["", "ui.stocks.good", "ui.stocks.stock", "ui.stocks.made", "ui.stocks.used",
			"ui.stocks.balance", "ui.stocks.sell"]:
		var header := _small(key)
		header.add_theme_color_override(&"font_color", Color(0.95, 0.82, 0.5))
		_grid.add_child(header)
	var goods := province.data.goods()
	goods.sort_custom(func(a: GoodDef, b: GoodDef) -> bool: return tr(a.name_key()) < tr(b.name_key()))
	for def: GoodDef in goods:
		var good := def.id
		var icon := TextureRect.new()
		icon.texture = ArtPaths.texture("goods/icons/%s.png" % good)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		_grid.add_child(icon)
		_grid.add_child(_small(def.name_key()))
		var stock := _small()
		var made := _small()
		var used := _small()
		var balance := _small()
		for l: Label in [stock, made, used, balance]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.custom_minimum_size.x = 64.0
			_grid.add_child(l)
		var sell := HBoxContainer.new()
		var tick := CheckBox.new()
		tick.tooltip_text = "ui.stocks.sell_hint"
		var amount := SpinBox.new()
		amount.min_value = 0
		amount.max_value = Merchant.MAX_SELL_ABOVE
		amount.step = 1
		amount.tooltip_text = "ui.stocks.sell_hint"
		amount.get_line_edit().add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
		var price := _small(tr("ui.stocks.price") % def.base_price)
		if def.is_live():
			tick.disabled = true
			amount.editable = false
			price.text = tr("ui.stocks.not_for_sale")
		tick.toggled.connect(func(on: bool) -> void:
			command_requested.emit(SetSellAboveCommand.new(good, int(amount.value) if on else -1)))
		amount.value_changed.connect(func(value: float) -> void:
			if tick.button_pressed:
				command_requested.emit(SetSellAboveCommand.new(good, int(value))))
		sell.add_child(tick)
		sell.add_child(amount)
		sell.add_child(price)
		_grid.add_child(sell)
		_rows[good] = {"stock": stock, "made": made, "used": used, "balance": balance,
				"tick": tick, "amount": amount}


func _refresh() -> void:
	_timer = 0.0
	var tick := province.tick
	for good: StringName in _rows:
		var row: Dictionary = _rows[good]
		var made := province.ledger.made_per_minute(good, tick)
		var used := province.ledger.used_per_minute(good, tick)
		(row["stock"] as Label).text = str(province.kingdom_stock(good))
		(row["made"] as Label).text = tr("ui.stocks.rate") % made
		(row["used"] as Label).text = tr("ui.stocks.rate") % used
		var balance := row["balance"] as Label
		balance.text = tr("ui.stocks.balance_value") % (made - used)
		var colour := Color(0.55, 0.9, 0.45) if made - used > 0.05 else (Color(1.0, 0.45, 0.4) \
				if made - used < -0.05 else Color(0.85, 0.85, 0.85))
		balance.add_theme_color_override(&"font_color", colour)
		var selling := province.merchant.sell_above.has(good)
		var check := row["tick"] as CheckBox
		check.set_pressed_no_signal(selling)
		var spin := row["amount"] as SpinBox
		if selling and not spin.get_line_edit().has_focus():
			spin.set_value_no_signal(int(province.merchant.sell_above[good]))

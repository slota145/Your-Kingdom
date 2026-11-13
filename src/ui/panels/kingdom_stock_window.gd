class_name KingdomStockWindow
extends PanelContainer
## "Kingdom stocks" (ROADMAP M4b-2): every good with what the province holds (storages,
## stacks by workshops, herds, market stalls and goods on the ground), how much it makes and
## uses per minute (average of the last 5 minutes) and the balance, green or red. The last
## column says what the travelling merchant may buy: everything above the number, when ticked.
## The column after it (M5 part 2) is for the goods the sea merchant sells: he unloads them
## while the kingdom holds less than the number, when ticked. The column before the merchant's
## (E5) is the player's limit: at that stock workshops and gatherers making the good stop.

signal command_requested(command: Command)
signal closed

const REFRESH := 0.5
const COLUMNS := 9

var province: ProvinceSim

var _grid: GridContainer
var _hint: Label
var _rows: Dictionary[StringName, Dictionary] = {}
var _timer: float = 0.0


func _init() -> void:
	# The theme's parchment panel (opaque: the window covers a busy town, ROADMAP UI-1).
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
	_hint.custom_minimum_size.x = 960.0
	_hint.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	box.add_child(_hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1040, 520)
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
			"ui.stocks.balance", "ui.stocks.limit", "ui.stocks.sell", "ui.stocks.buy"]:
		var header := _small(key)
		header.add_theme_color_override(&"font_color", UiKit.HEADING)
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
		var limit := _limit_cell(def)
		_grid.add_child(limit["cell"])
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
				"tick": tick, "amount": amount, "limit_tick": limit["tick"],
				"limit_amount": limit["amount"]}
		_grid.add_child(_buy_cell(good))


## The player's limit of a good (E5): ticked, workshops stop once the kingdom holds the number.
## Live goods (animals) have none.
func _limit_cell(def: GoodDef) -> Dictionary:
	var good := def.id
	var cell := HBoxContainer.new()
	var tick := CheckBox.new()
	tick.tooltip_text = "ui.stocks.limit_hint"
	var amount := SpinBox.new()
	amount.min_value = 0
	amount.max_value = SetGoodsLimitCommand.MAX_LIMIT
	amount.step = 1
	amount.value = 100
	amount.tooltip_text = "ui.stocks.limit_hint"
	amount.get_line_edit().add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	if def.is_live():
		tick.disabled = true
		amount.editable = false
	tick.toggled.connect(func(on: bool) -> void:
		command_requested.emit(SetGoodsLimitCommand.new(good, int(amount.value) if on else -1)))
	amount.value_changed.connect(func(value: float) -> void:
		if tick.button_pressed:
			command_requested.emit(SetGoodsLimitCommand.new(good, int(value))))
	cell.add_child(tick)
	cell.add_child(amount)
	return {"cell": cell, "tick": tick, "amount": amount}


## "Buy up to N" from the sea merchant, for the goods he sells (an empty cell otherwise).
func _buy_cell(good: StringName) -> Control:
	var cell := HBoxContainer.new()
	if not SeaMerchant.OFFER.has(good):
		return cell
	var tick := CheckBox.new()
	tick.tooltip_text = "ui.stocks.buy_hint"
	var amount := SpinBox.new()
	amount.min_value = 1
	amount.max_value = SeaMerchant.MAX_BUY_UP_TO
	amount.step = 1
	amount.value = 10
	amount.tooltip_text = "ui.stocks.buy_hint"
	amount.get_line_edit().add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	tick.toggled.connect(func(on: bool) -> void:
		command_requested.emit(SetBuyUpToCommand.new(good, int(amount.value) if on else 0)))
	amount.value_changed.connect(func(value: float) -> void:
		if tick.button_pressed:
			command_requested.emit(SetBuyUpToCommand.new(good, int(value))))
	cell.add_child(tick)
	cell.add_child(amount)
	cell.add_child(_small(tr("ui.stocks.buy_price") % SeaMerchant.sell_price(province, good)))
	_rows[good]["buy_tick"] = tick
	_rows[good]["buy_amount"] = amount
	return cell


func _refresh() -> void:
	_timer = 0.0
	var tick := province.tick
	for good: StringName in _rows:
		var row: Dictionary = _rows[good]
		var made := province.ledger.made_per_minute(good, tick)
		var used := province.ledger.used_per_minute(good, tick)
		var stock_label := row["stock"] as Label
		stock_label.text = str(province.kingdom_stock(good))
		# At the limit (E5) the stock reads in the warning colour: its makers stand idle.
		var limited := province.goods_limits.has(good)
		if limited and province.limit_reached(good):
			stock_label.add_theme_color_override(&"font_color", UiKit.HEADING)
			stock_label.tooltip_text = "ui.stocks.limit_reached"
		else:
			stock_label.remove_theme_color_override(&"font_color")
			stock_label.tooltip_text = ""
		(row["limit_tick"] as CheckBox).set_pressed_no_signal(limited)
		var limit_spin := row["limit_amount"] as SpinBox
		if limited and not limit_spin.get_line_edit().has_focus():
			limit_spin.set_value_no_signal(int(province.goods_limits[good]))
		(row["made"] as Label).text = tr("ui.stocks.rate") % made
		(row["used"] as Label).text = tr("ui.stocks.rate") % used
		var balance := row["balance"] as Label
		balance.text = tr("ui.stocks.balance_value") % (made - used)
		var colour := UiKit.GOOD if made - used > 0.05 else (UiKit.BAD \
				if made - used < -0.05 else UiKit.INK_SOFT)
		balance.add_theme_color_override(&"font_color", colour)
		var selling := province.merchant.sell_above.has(good)
		var check := row["tick"] as CheckBox
		check.set_pressed_no_signal(selling)
		var spin := row["amount"] as SpinBox
		if selling and not spin.get_line_edit().has_focus():
			spin.set_value_no_signal(int(province.merchant.sell_above[good]))
		if row.has("buy_tick"):
			var buying := province.sea_merchant.buy_up_to.has(good)
			(row["buy_tick"] as CheckBox).set_pressed_no_signal(buying)
			var buy_spin := row["buy_amount"] as SpinBox
			if buying and not buy_spin.get_line_edit().has_focus():
				buy_spin.set_value_no_signal(int(province.sea_merchant.buy_up_to[good]))

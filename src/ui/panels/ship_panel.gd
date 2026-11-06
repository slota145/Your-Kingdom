class_name ShipPanel
extends PanelContainer
## The selected ship (M5 part 2): its kind, what it is doing, whose it is and its hold. The
## hold list reads the ship's Stockpile like the stockpile panel, so it matches the
## simulation after every unit the dockers carry (tests/scenario/test_m5_port.gd).

signal closed

var province: ProvinceSim
var ship_id: int = 0

var _title: Label
var _body: Label
var _hold: StockpilePanel


func _init() -> void:
	custom_minimum_size.x = UiKit.PANEL_WIDTH
	var box := VBoxContainer.new()
	add_child(box)
	_title = UiKit.title()
	box.add_child(_title)
	_body = UiKit.label()
	box.add_child(_body)
	_hold = StockpilePanel.new()
	_hold.title_key = "ui.ship.hold"
	box.add_child(_hold)
	var buttons := HFlowContainer.new()
	box.add_child(buttons)
	buttons.add_child(UiKit.button("ui.close", func() -> void: closed.emit()))


func show_ship(source: ProvinceSim, id: int) -> void:
	province = source
	ship_id = id
	visible = true
	_refresh()


## The goods and units the hold list shows now.
func listed() -> Dictionary[StringName, int]:
	return _hold.listed()


func _process(_delta: float) -> void:
	if visible and province != null:
		_refresh()


func _refresh() -> void:
	var ship := province.ships.get(ship_id) as ShipUnit
	if ship == null:
		_hold.stock = null
		closed.emit()
		return
	_title.text = tr(ship.def.name_key())
	_body.text = "\n".join(describe(province, ship))
	_hold.stock = ship.hold
	_hold.refresh()


## Lines about [param ship]: where it is, and for the sea merchant how the trade goes.
static func describe(province: ProvinceSim, ship: ShipUnit) -> PackedStringArray:
	var lines := PackedStringArray()
	var trader := province.sea_merchant
	var foreign := ship.id == trader.ship_id and trader.state != SeaMerchant.State.AWAY
	var moored_at := province.buildings.get_building(ship.dock_id) if ship.is_moored() else null
	if moored_at != null:
		lines.append(TranslationServer.translate("ui.ship.moored") % TranslationServer.translate(moored_at.def.name_key()))
	elif foreign and trader.state == SeaMerchant.State.LEAVING:
		lines.append(TranslationServer.translate("ui.ship.leaving"))
	elif foreign and trader.state == SeaMerchant.State.COMING:
		lines.append(TranslationServer.translate("ui.ship.coming"))
	else:
		lines.append(TranslationServer.translate("ui.ship.sailing"))
	lines.append(TranslationServer.translate("ui.ship.capacity") % [ship.hold.total_amount(), ship.def.capacity()])
	if foreign:
		lines.append(TranslationServer.translate("ui.ship.sea_merchant"))
		if trader.is_trading():
			var left := maxi(trader.leave_at - province.tick, 0) / SimClock.TICKS_PER_SECOND
			lines.append(TranslationServer.translate("ui.ship.trading_left") % [left / 60, left % 60])
		lines.append(TranslationServer.translate("ui.ship.trade") % [trader.bought, trader.earned, trader.spent])
	return lines

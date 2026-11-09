class_name ShipPanel
extends PanelContainer
## The selected ship (M5 part 2): its kind, what it is doing, whose it is and its hold. The
## hold list reads the ship's Stockpile like the stockpile panel, so it matches the
## simulation after every unit the dockers carry (tests/scenario/test_m5_port.gd).
## P2 part 2: the hold also as a grid of its slots, each empty or with the icon and amount of
## its good; a warship's soldiers aboard by kind, and a button that sets them ashore.

signal closed
signal command_requested(command: Command)

const SLOT_SIZE := Vector2(40, 40)
const SLOT_COLUMNS := 6

var province: ProvinceSim
var ship_id: int = 0

var _title: Label
var _body: Label
var _hold: StockpilePanel
var _slots: GridContainer
var _troops: Label
var _land: Button
## What the slot grid shows now (good and amount per slot), rebuilt only when it changes.
var _slot_key: String = ""


func _init() -> void:
	custom_minimum_size.x = UiKit.PANEL_WIDTH
	var box := VBoxContainer.new()
	add_child(box)
	_title = UiKit.title()
	box.add_child(_title)
	_body = UiKit.label()
	box.add_child(_body)
	_slots = GridContainer.new()
	_slots.columns = SLOT_COLUMNS
	_slots.add_theme_constant_override(&"h_separation", 3)
	_slots.add_theme_constant_override(&"v_separation", 3)
	box.add_child(_slots)
	_hold = StockpilePanel.new()
	_hold.title_key = "ui.ship.hold"
	_hold.visible = false   # the slot grid shows the hold (P2 part 2); the list stays for listed()
	box.add_child(_hold)
	_troops = UiKit.label()
	box.add_child(_troops)
	var buttons := HFlowContainer.new()
	box.add_child(buttons)
	_land = UiKit.button("ui.ship.land_troops", func() -> void: command_requested.emit(LandTroopsCommand.new(ship_id)))
	buttons.add_child(_land)
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
	_refresh_slots(ship.hold)
	var warship := TroopTransport.carries_troops(province, ship)
	_troops.visible = warship
	_land.visible = warship and not ship.troops.is_empty()
	_land.disabled = ship.troop_order == TroopTransport.LAND
	if warship:
		_troops.text = "\n".join(troop_lines(province, ship))


## The hold's slots in a grid: an empty frame, or the good's icon with the amount on it.
func _refresh_slots(hold: Stockpile) -> void:
	var key := ""
	for i: int in hold.slot_count():
		key += "%s:%d;" % [hold.slot_good[i], hold.slot_amount[i]]
	if key == _slot_key:
		return
	_slot_key = key
	for child: Node in _slots.get_children():
		child.queue_free()
	for i: int in hold.slot_count():
		_slots.add_child(_slot(hold.slot_good[i], hold.slot_amount[i]))


static func _slot(good: StringName, amount: int) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = SLOT_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.11, 0.07, 0.85)
	style.border_color = Color(0.55, 0.42, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	frame.add_theme_stylebox_override(&"panel", style)
	if good == &"" or amount <= 0:
		frame.tooltip_text = TranslationServer.translate("ui.ship.slot_empty")
		return frame
	frame.tooltip_text = Loc.good_count(good, amount)
	var icon := TextureRect.new()
	icon.texture = ArtPaths.texture("goods/icons/%s.png" % good)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = SLOT_SIZE - Vector2(6, 6)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	var count := Label.new()
	count.text = str(amount)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.size_flags_horizontal = Control.SIZE_SHRINK_END
	count.size_flags_vertical = Control.SIZE_SHRINK_END
	count.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.8))
	count.add_theme_color_override(&"font_outline_color", Color.BLACK)
	count.add_theme_constant_override(&"outline_size", 3)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(count)
	return frame


## A warship's soldiers: how many aboard of its room, by kind, and those on their way.
static func troop_lines(province: ProvinceSim, ship: ShipUnit) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append(TranslationServer.translate("ui.ship.troops") % [ship.troops.size(), ship.def.troops])
	var kinds: Dictionary[StringName, int] = {}
	for id: int in ship.troops:
		var agent := province.agents.get_agent(id)
		if agent != null:
			kinds[agent.kind] = kinds.get(agent.kind, 0) + 1
	var names: Array[StringName] = []
	names.assign(kinds.keys())
	names.sort()
	for kind: StringName in names:
		var unit := province.data.get_unit(kind)
		lines.append("  %s × %d" % [TranslationServer.translate(unit.name_key()) if unit != null else String(kind), kinds[kind]])
	if not ship.boarding.is_empty():
		lines.append(TranslationServer.translate("ui.ship.troops_boarding") % ship.boarding.size())
	if ship.troop_order == TroopTransport.LAND:
		lines.append(TranslationServer.translate("ui.ship.troops_landing"))
	return lines


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
	elif ship.voyage != null and ship.path_state != ShipUnit.PathState.MOVING and not ship.is_moored():
		lines.append(TranslationServer.translate("ui.ship.at_anchor"))
	else:
		lines.append(TranslationServer.translate("ui.ship.sailing"))
	lines.append(TranslationServer.translate("ui.ship.capacity") % [ship.hold.total_amount(), ship.def.capacity()])
	if ship.voyage != null:
		# The player's cog (M5 part 3): its plan is set in the panel of its port.
		var home := province.buildings.get_building(ship.home_id)
		lines.append(TranslationServer.translate("ui.ship.player_cog") % (TranslationServer.translate(home.def.name_key()) \
				if home != null else TranslationServer.translate("ui.ship.no_home")))
	if province.landing != null and province.landing.is_landing_ship(ship):
		lines.append(TranslationServer.translate("ui.ship.settlers"))
	if foreign:
		lines.append(TranslationServer.translate("ui.ship.sea_merchant"))
		if trader.is_trading():
			var left := maxi(trader.leave_at - province.tick, 0) / SimClock.TICKS_PER_SECOND
			lines.append(TranslationServer.translate("ui.ship.trading_left") % [left / 60, left % 60])
		lines.append(TranslationServer.translate("ui.ship.trade") % [trader.bought, trader.earned, trader.spent])
	return lines

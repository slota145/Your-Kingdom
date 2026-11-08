class_name BuildMenu
extends PanelContainer
## The build bar: tabs by kind of building (owner feedback 2026-11-05: finding buildings by
## their names alone got tiring), each tab a row of picture buttons; roads and demolition
## always on the right. Tooltips name the building, what it does and what it costs.

signal tool_selected(tool: Dictionary)
## The player hides the build bar (owner's request 2026-11-07); the "Build" button or B shows it.
signal hide_requested

## Tab id -> its buildings in order (ids missing from the data are skipped).
const TABS: Array[Dictionary] = [
	{"id": &"housing", "buildings": [&"hut", &"well", &"chapel", &"church", &"market", &"tavern"]},
	{"id": &"resources", "buildings": [&"woodcutter", &"forester", &"sawmill", &"quarry", &"clay_pit",
			&"brickworks"]},
	{"id": &"food", "buildings": [&"farm", &"mill", &"bakery", &"fishing_hut", &"pigsty",
			&"slaughterhouse"]},
	{"id": &"drink", "buildings": [&"hop_farm", &"brewery", &"apiary", &"meadery", &"vineyard", &"wine_press"]},
	{"id": &"textiles", "buildings": [&"sheep_farm", &"weaver", &"tailor"]},
	{"id": &"storage", "buildings": [&"pioneer_camp", &"stockpile", &"town_hall", &"stable", &"trading_post"]},
	{"id": &"harbour", "buildings": [&"tar_kiln", &"shipyard", &"large_shipyard", &"fishing_wharf", &"port", &"mooring",
		&"crane", &"port_warehouse"]},
	{"id": &"military", "buildings": [&"charcoal_burner", &"mine", &"smelter", &"blacksmith",
		&"armourer", &"bowyer", &"stud_farm", &"armoury", &"barracks"]},
	{"id": &"defence", "buildings": [&"gatehouse", &"tower", &"palisade_gate", &"siege_workshop"],
		"tools": [&"palisade", &"stone_wall", &"stairs"]},
]
## Wall tools (M7 part 2): tool kind -> its cost, shown in the tooltip.
const WALL_COSTS: Dictionary[StringName, String] = {&"palisade": "wood", &"stone_wall": "stone", &"stairs": "stone"}
const ICON_SIZE := Vector2(72, 56)

var _tab_buttons: Array[Button] = []
var _rows: Array[Control] = []
var _rotate_hint: Label
## Building buttons by building id.
var _buttons: Dictionary[StringName, Button] = {}
## The only building allowed now (a start from a ship: the pioneer camp first, M5 part 3).
var _locked_to: StringName = &""


func setup(registry: DataRegistry) -> void:
	theme = UiKit.board_theme()   # a wooden board like the top bar (ROADMAP UI-1)
	var box := VBoxContainer.new()
	add_child(box)
	# A flow, not a box (B1): on a narrow screen the tools on the right go on to a second line
	# instead of running off the edge.
	var tabs := HFlowContainer.new()
	box.add_child(tabs)
	var group := ButtonGroup.new()
	for i: int in TABS.size():
		var tab: Dictionary = TABS[i]
		var b := UiKit.button("ui.build.tab.%s" % tab["id"], func() -> void: _show_tab(i))
		b.toggle_mode = true
		b.button_group = group
		b.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE + 2)
		tabs.add_child(b)
		_tab_buttons.append(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	_rotate_hint = Label.new()
	_rotate_hint.text = "ui.build.rotate_hint"
	_rotate_hint.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE + 2)
	_rotate_hint.visible = false
	tabs.add_child(_rotate_hint)
	var road := UiKit.button("ui.build.road", func() -> void: tool_selected.emit({"kind": &"road"}))
	road.tooltip_text = "ui.build.road_tip"
	tabs.add_child(road)
	var paving := UiKit.button("ui.build.paving", func() -> void: tool_selected.emit({"kind": &"paving"}))
	paving.tooltip_text = "ui.build.paving_tip"
	tabs.add_child(paving)
	# N1: quays on the sea, laid by dragging like roads.
	var pier := UiKit.button("ui.build.pier", func() -> void: tool_selected.emit({"kind": &"pier"}))
	pier.tooltip_text = "ui.build.pier_tip"
	tabs.add_child(pier)
	var quay := UiKit.button("ui.build.stone_quay", func() -> void: tool_selected.emit({"kind": &"quay"}))
	quay.tooltip_text = "ui.build.stone_quay_tip"
	tabs.add_child(quay)
	# B1: bridges over rivers, fords and lakes, dragged from bank to bank.
	var bridge := UiKit.button("ui.build.bridge", func() -> void: tool_selected.emit({"kind": &"bridge"}))
	bridge.tooltip_text = "ui.build.bridge_tip"
	tabs.add_child(bridge)
	var stone_bridge := UiKit.button("ui.build.stone_bridge", func() -> void: tool_selected.emit({"kind": &"stone_bridge"}))
	stone_bridge.tooltip_text = "ui.build.stone_bridge_tip"
	tabs.add_child(stone_bridge)
	var demolish := UiKit.button("ui.build.demolish", func() -> void: tool_selected.emit({"kind": &"demolish"}))
	demolish.tooltip_text = "ui.build.demolish_tip"
	tabs.add_child(demolish)
	var hide := UiKit.button("ui.build.hide", func() -> void: hide_requested.emit())
	hide.tooltip_text = "ui.build.hide_tip"
	tabs.add_child(hide)
	for tab: Dictionary in TABS:
		var row := HFlowContainer.new()
		box.add_child(row)
		_rows.append(row)
		for tool: StringName in tab.get("tools", []):
			row.add_child(_wall_button(tool))
		for id: StringName in tab["buildings"]:
			var def := registry.get_building(id)
			if def != null:
				var button := _building_button(def)
				_buttons[id] = button
				row.add_child(button)
	_show_tab(0)


## Until [param only] is placed, the menu offers nothing else (M5 part 3: on a map that
## starts from a ship, the pioneer camp first); empty = everything. Cheap when unchanged.
func lock_to(only: StringName) -> void:
	if only == _locked_to:
		return
	_locked_to = only
	for id: StringName in _buttons:
		_buttons[id].visible = only == &"" or id == only
	for i: int in TABS.size():
		var has := only == &"" or (TABS[i]["buildings"] as Array).has(only)
		_tab_buttons[i].visible = has
		if only != &"" and has:
			_show_tab(i)


## Shows the hint about turning buildings with R while one is being placed (M4b-1.5).
func show_rotate_hint(on: bool) -> void:
	_rotate_hint.visible = on


func _show_tab(index: int) -> void:
	for i: int in _rows.size():
		_rows[i].visible = i == index
		_tab_buttons[i].set_pressed_no_signal(i == index)


## A picture of the building with its name under it.
func _building_button(def: BuildingDef) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 0)
	b.pressed.connect(func() -> void: tool_selected.emit({"kind": &"building", "def": def.id}))
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(content)
	var icon := TextureRect.new()
	icon.texture = _icon(def)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var name := Label.new()
	name.text = def.name_key()
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name)
	b.custom_minimum_size.y = ICON_SIZE.y + 30
	b.tooltip_text = def.desc_key()
	b.mouse_entered.connect(func() -> void:
		var lines := PackedStringArray([tr(def.desc_key()), tr("ui.build.cost") % UiKit.goods_list(def.build_cost)])
		if def.gold_cost > 0:
			lines.append(tr("ui.build.gold_cost") % def.gold_cost)
		b.tooltip_text = "\n".join(lines))
	return b


## A wall tool (M7 part 2): drag a line of palisade, stone wall or stairs.
func _wall_button(tool: StringName) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, ICON_SIZE.y + 30)
	b.pressed.connect(func() -> void: tool_selected.emit({"kind": tool}))
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(content)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/walls/icons/%s.png" % tool) as Texture2D
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var name := Label.new()
	var key := "ui.build." + String(tool)
	name.text = key
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name)
	b.tooltip_text = key + "_tip"
	return b


## The finished building's art (a storage yard has none: its second construction phase).
static func _icon(def: BuildingDef) -> Texture2D:
	var visual := BuildingVisualDef.for_building(def.id)
	var art_id := visual.art_id if visual != null else String(def.id)
	var name := "construction_2" if visual != null and visual.yard else "base"
	return ArtPaths.texture("buildings/%s/%s.png" % [art_id, name])

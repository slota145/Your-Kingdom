class_name BuildMenu
extends PanelContainer
## The build bar: tabs by kind of building (owner feedback 2026-11-05: finding buildings by
## their names alone got tiring), each tab a row of picture buttons; roads and demolition
## always on the right. Tooltips name the building, what it does and what it costs.

signal tool_selected(tool: Dictionary)

## Tab id -> its buildings in order (ids missing from the data are skipped).
const TABS: Array[Dictionary] = [
	{"id": &"housing", "buildings": [&"hut", &"well", &"chapel", &"church", &"market", &"tavern"]},
	{"id": &"resources", "buildings": [&"woodcutter", &"forester", &"sawmill", &"quarry", &"clay_pit",
			&"brickworks"]},
	{"id": &"food", "buildings": [&"farm", &"mill", &"bakery", &"fishing_hut"]},
	{"id": &"drink", "buildings": [&"hop_farm", &"brewery", &"apiary", &"meadery"]},
	{"id": &"textiles", "buildings": [&"sheep_farm", &"weaver", &"tailor"]},
	{"id": &"storage", "buildings": [&"stockpile", &"town_hall"]},
]
const ICON_SIZE := Vector2(72, 56)

var _tab_buttons: Array[Button] = []
var _rows: Array[Control] = []
var _rotate_hint: Label


func setup(registry: DataRegistry) -> void:
	var box := VBoxContainer.new()
	add_child(box)
	var tabs := HBoxContainer.new()
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
	var demolish := UiKit.button("ui.build.demolish", func() -> void: tool_selected.emit({"kind": &"demolish"}))
	demolish.tooltip_text = "ui.build.demolish_tip"
	tabs.add_child(demolish)
	for tab: Dictionary in TABS:
		var row := HFlowContainer.new()
		box.add_child(row)
		_rows.append(row)
		for id: StringName in tab["buildings"]:
			var def := registry.get_building(id)
			if def != null:
				row.add_child(_building_button(def))
	_show_tab(0)


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


## The finished building's art (a storage yard has none: its second construction phase).
static func _icon(def: BuildingDef) -> Texture2D:
	var visual := BuildingVisualDef.for_building(def.id)
	var art_id := visual.art_id if visual != null else String(def.id)
	var name := "construction_2" if visual != null and visual.yard else "base"
	return ArtPaths.texture("buildings/%s/%s.png" % [art_id, name])

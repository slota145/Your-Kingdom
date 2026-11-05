class_name BuildMenu
extends PanelContainer
## The build bar: one button per building of the slice, plus roads and demolition.
## Tooltips name the building, what it does and what it costs.

signal tool_selected(tool: Dictionary)

## Order of the buttons (ids missing from the data are skipped).
const ORDER: Array[StringName] = [&"hut", &"well", &"woodcutter", &"farm", &"mill", &"bakery",
		&"stockpile", &"town_hall"]


func setup(registry: DataRegistry) -> void:
	var row := HFlowContainer.new()
	add_child(row)
	for id: StringName in ORDER:
		var def := registry.get_building(id)
		if def == null:
			continue
		var b := UiKit.button(def.name_key(), func() -> void:
			tool_selected.emit({"kind": &"building", "def": def.id}))
		b.tooltip_text = def.desc_key()
		b.mouse_entered.connect(func() -> void:
			var lines := PackedStringArray([tr(def.desc_key()), tr("ui.build.cost") % UiKit.goods_list(def.build_cost)])
			b.tooltip_text = "\n".join(lines))
		row.add_child(b)
	var road := UiKit.button("ui.build.road", func() -> void: tool_selected.emit({"kind": &"road"}))
	road.tooltip_text = "ui.build.road_tip"
	row.add_child(road)
	var demolish := UiKit.button("ui.build.demolish", func() -> void: tool_selected.emit({"kind": &"demolish"}))
	demolish.tooltip_text = "ui.build.demolish_tip"
	row.add_child(demolish)

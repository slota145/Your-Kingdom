class_name ArmyPanel
extends PanelContainer
## The selected soldiers (M7 part 2, control as in Stronghold): how many of each kind and
## their life, the stance buttons (attack on sight, defend the place, hold the place) and
## "back to the barracks". How to command them is written under it.

signal stance_requested(stance: int)
signal return_requested
signal closed

var province: ProvinceSim
var ids: Array[int] = []

var _title: Label
var _body: Label
var _stances: Array[Button] = []


func _init() -> void:
	custom_minimum_size.x = UiKit.PANEL_WIDTH
	var box := VBoxContainer.new()
	add_child(box)
	_title = UiKit.title()
	box.add_child(_title)
	_body = UiKit.label()
	box.add_child(_body)
	var row := HFlowContainer.new()
	box.add_child(row)
	var group := ButtonGroup.new()
	for key: String in ["ui.army.aggressive", "ui.army.defensive", "ui.army.hold"]:
		var stance := _stances.size()
		var b := UiKit.button(key, func() -> void: stance_requested.emit(stance))
		b.toggle_mode = true
		b.button_group = group
		b.tooltip_text = key + "_tip"
		row.add_child(b)
		_stances.append(b)
	var buttons := HFlowContainer.new()
	box.add_child(buttons)
	buttons.add_child(UiKit.button("ui.army.return", func() -> void: return_requested.emit()))
	buttons.add_child(UiKit.button("ui.close", func() -> void: closed.emit()))
	var hint := UiKit.label("ui.army.hint")
	hint.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	box.add_child(hint)


func show_army(source: ProvinceSim, soldier_ids: Array[int]) -> void:
	province = source
	ids = soldier_ids
	visible = true
	_refresh()


func _process(_delta: float) -> void:
	if visible and province != null:
		_refresh()


func _refresh() -> void:
	var counts: Dictionary[StringName, int] = {}
	var hp := 0
	var full := 0
	var stance := -1
	var alive: Array[int] = []
	for id: int in ids:
		var agent := province.agents.get_agent(id)
		if agent == null or agent.combat == null:
			continue
		alive.append(id)
		counts[agent.kind] = counts.get(agent.kind, 0) + 1
		hp += agent.combat.hp
		full += province.data.get_unit(agent.kind).combat.hp
		stance = agent.combat.stance if stance < 0 or stance == agent.combat.stance else 99
	ids = alive
	if alive.is_empty():
		closed.emit()
		return
	_title.text = tr_n("ui.army.title", "ui.army.title_plural", alive.size()) % alive.size()
	var lines := PackedStringArray()
	var kinds: Array[StringName] = counts.keys()
	kinds.sort()
	for kind: StringName in kinds:
		lines.append("%s: %d" % [AgentDescriber.kind_name(kind), counts[kind]])
	lines.append(tr("ui.army.life") % roundi(100.0 * hp / maxi(full, 1)))
	_body.text = "\n".join(lines)
	for i: int in _stances.size():
		_stances[i].set_pressed_no_signal(i == stance)

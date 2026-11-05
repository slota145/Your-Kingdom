class_name AgentPanel
extends PanelContainer
## The selected person: profession, what they are doing now, what they carry, where they
## live and work. "Follow" keeps the camera on them.

signal follow_toggled(on: bool)
signal closed

var province: ProvinceSim
var agent_id: int = 0
var following: bool = false

var _title: Label
var _body: Label
var _follow: Button


func _init() -> void:
	custom_minimum_size.x = UiKit.PANEL_WIDTH
	var box := VBoxContainer.new()
	add_child(box)
	_title = UiKit.title()
	box.add_child(_title)
	_body = UiKit.label()
	box.add_child(_body)
	var buttons := HFlowContainer.new()
	box.add_child(buttons)
	_follow = UiKit.button("ui.agent.follow", _toggle_follow)
	_follow.toggle_mode = true
	buttons.add_child(_follow)
	buttons.add_child(UiKit.button("ui.close", func() -> void: closed.emit()))


func show_agent(source: ProvinceSim, id: int) -> void:
	province = source
	agent_id = id
	visible = true
	_refresh()


func set_following(on: bool) -> void:
	following = on
	_follow.set_pressed_no_signal(on)


func _toggle_follow() -> void:
	set_following(_follow.button_pressed)
	follow_toggled.emit(following)


func _process(_delta: float) -> void:
	if visible and province != null:
		_refresh()


func _refresh() -> void:
	var agent := province.agents.get_agent(agent_id)
	if agent == null:
		closed.emit()
		return
	_title.text = AgentDescriber.kind_name(agent.kind)
	var lines := PackedStringArray([AgentDescriber.doing(province, agent)])
	if agent.is_carrying():
		lines.append(tr("ui.agent.carrying") % LocFormat.good_count(agent.carry_good, agent.carry_amount))
	var home := province.buildings.get_building(agent.home_id)
	if home != null:
		lines.append(tr("ui.agent.home") % tr(home.level_def().name_key() if home.house != null else home.def.name_key()))
	var work := province.buildings.get_building(agent.workplace_id)
	if work != null:
		lines.append(tr("ui.agent.workplace") % tr(work.def.name_key()))
	_body.text = "\n".join(lines)

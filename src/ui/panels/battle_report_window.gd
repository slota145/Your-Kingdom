class_name BattleReportWindow
extends PanelContainer
## The report of a battle of the player's army or fleet on the world map (ROADMAP M8 part 2):
## a sea battle (with the ships sunk) or a battle in the field, won or lost, the phases and the
## losses of both sides.

signal closed

var _title: Label
var _text: Label


func _init() -> void:
	custom_minimum_size = Vector2(460, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	add_child(box)
	_title = UiKit.title()
	_title.add_theme_font_size_override(&"font_size", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_text = UiKit.label()
	box.add_child(_text)
	var ok := UiKit.button("ui.close", func() -> void:
		visible = false
		closed.emit())
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ok)


## Shows the newest report of [param sim] (a battle the player fought in).
func show_last(sim: Simulation) -> void:
	if sim.world.reports.is_empty():
		return
	var entry: Dictionary = sim.world.reports[sim.world.reports.size() - 1]
	var mine := String(entry["attacker"]) == String(ProvinceDef.OWNER_PLAYER)
	if not mine and String(entry["defender"]) != String(ProvinceDef.OWNER_PLAYER):
		return
	var result := BattleResult.from_dict(entry["result"])
	var won := result.a_won() == mine
	_title.text = tr("ui.world.report_%d" % int(entry["kind"])) + " — " \
			+ tr("ui.world.report_won" if won else "ui.world.report_lost")
	var lines := PackedStringArray()
	for phase: Dictionary in result.report:
		lines.append(tr("ui.world.report_phase_%d" % int(phase["phase"]))
				% [int(phase["a"]) if mine else int(phase["b"]), int(phase["b"]) if mine else int(phase["a"])])
	lines.append(tr("ui.world.report_losses") % [WorldArmyBox._sum(result.lost_a if mine else result.lost_b),
			WorldArmyBox._sum(result.lost_b if mine else result.lost_a)])
	if entry.has("ships_a"):
		lines.append(tr("ui.world.report_ships") % [int(entry["ships_a"] if mine else entry["ships_b"]),
				int(entry["ships_b"] if mine else entry["ships_a"])])
	_text.text = "\n".join(lines)
	visible = true

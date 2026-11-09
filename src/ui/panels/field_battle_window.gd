class_name FieldBattleWindow
extends PanelContainer
## The player's army met an enemy army in the field (ROADMAP M8 part 2, survey 2026-11-09):
## the game pauses and this window asks how to fight: on the battlefield (live, as in M7) or
## at once (BattleResolver, with the chances).

signal chosen(command: Command)

var battle_id: int = 0

var _title: Label
var _text: Label
var _auto: Button


func _init() -> void:
	custom_minimum_size = Vector2(520, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	add_child(box)
	_title = UiKit.title("ui.battle.title")
	_title.add_theme_font_size_override(&"font_size", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_text = UiKit.label()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var live := UiKit.button("ui.battle.live", func() -> void:
		chosen.emit(FieldBattleCommand.new(battle_id, FieldBattles.LIVE)))
	live.tooltip_text = "ui.battle.live_tip"
	buttons.add_child(live)
	_auto = UiKit.button("ui.battle.auto", func() -> void:
		chosen.emit(FieldBattleCommand.new(battle_id, FieldBattles.AUTO)))
	_auto.tooltip_text = "ui.battle.auto_tip"
	buttons.add_child(_auto)
	box.add_child(buttons)


## Shows battle [param id] of [param sim].
func show_battle(sim: Simulation, id: int) -> void:
	var battle := sim.world.battles.get(id) as FieldBattle
	if battle == null or battle.state != FieldBattle.State.PENDING:
		visible = false
		return
	battle_id = id
	var mine := sim.world.armies.get(battle.a) as Army
	var theirs := sim.world.armies.get(battle.b) as Army
	if mine == null or theirs == null:
		visible = false
		return
	var who := tr("ui.battle.bandits") if theirs.owner == Army.BANDITS \
			else tr("ruler.%s.name" % theirs.owner) if Rulers.is_ruler(theirs.owner) else tr("ui.battle.enemy")
	var where := sim.world.def_of(battle.province, sim.data)
	var lines := PackedStringArray()
	lines.append(tr("ui.battle.met") % [who, tr(where.name_key()) if where != null else ""])
	lines.append(tr("ui.battle.sides") % [_units(mine), _units(theirs)])
	_text.text = "\n".join(lines)
	_auto.text = tr("ui.battle.auto") % roundi(100.0 * FieldBattles.chances(sim, battle))
	visible = true


static func _units(army: Army) -> String:
	var parts := PackedStringArray()
	var ids: Array[StringName] = []
	ids.assign(army.units.keys())
	ids.sort()
	for unit: StringName in ids:
		parts.append("%s: %d" % [AgentDescriber.kind_name(unit), army.units[unit]])
	return ", ".join(parts) if not parts.is_empty() else "0"

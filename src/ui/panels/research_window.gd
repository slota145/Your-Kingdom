class_name ResearchWindow
extends PanelContainer
## "Research" (ROADMAP E4 part 2, owner's survey 2026-11-11: a tree with arrows), opened from the
## top bar and from a school's panel. One card per research: basic ones on the left, advanced on
## the right, arrows from what a research needs. A card shows its cost and time and whether it
## is done, studied now, queued, ready or waiting for another; a click starts or queues it, a
## click on a planned one takes it back (its gold returns). Above: the current research with its
## progress, the teachers at work and the queue. Reads the simulation; changes go out as commands.

signal command_requested(command: Command)
signal closed

const REFRESH := 0.5
const CARD := Vector2(214, 74)
const COL_W := 262.0
const ROW_H := 84.0
## Room for the headings over the school's and the university's columns.
const HEAD_H := 30.0
const DONE := Color(0.62, 0.86, 0.55)
const NOW := Color(1.0, 0.9, 0.5)
const QUEUED := Color(0.95, 0.82, 0.6)
const WAITING := Color(0.62, 0.6, 0.58)

var sim: Simulation

var _status: Label
var _progress: ProgressBar
var _queue: Label
var _tree: Control
var _cards: Dictionary[StringName, Button] = {}
var _timer: float = 0.0


func _init() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiKit.title("ui.research.title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.button("ui.close", func() -> void: closed.emit()))
	_status = UiKit.label("")
	_status.custom_minimum_size.x = 760.0
	box.add_child(_status)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(760, 14)
	_progress.show_percentage = false
	box.add_child(_progress)
	_queue = UiKit.label("")
	_queue.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	box.add_child(_queue)
	var hint := UiKit.label("ui.research.hint")
	hint.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	box.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800, 330)
	box.add_child(scroll)
	_tree = Control.new()
	_tree.draw.connect(_draw_arrows)
	scroll.add_child(_tree)
	for i: int in 2:
		var heading := UiKit.title("ui.research.school" if i == 0 else "ui.research.university")
		heading.position = Vector2(i * 3 * COL_W + 4, 0)
		_tree.add_child(heading)


func open(simulation: Simulation) -> void:
	sim = simulation
	visible = true
	_build_cards()
	_refresh()


func _process(delta: float) -> void:
	if not visible or sim == null:
		return
	_timer += delta
	if _timer >= REFRESH:
		_timer = 0.0
		_refresh()


func _build_cards() -> void:
	for card: Button in _cards.values():
		card.queue_free()
	_cards.clear()
	var size := Vector2.ZERO
	for def: ResearchDef in sim.data.researches():
		var card := Button.new()
		card.custom_minimum_size = CARD
		card.size = CARD
		card.position = _card_pos(def)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.clip_text = true
		card.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
		var id := def.id
		card.pressed.connect(func() -> void: _clicked(id))
		_tree.add_child(card)
		_cards[id] = card
		size = size.max(card.position + CARD)
	_tree.custom_minimum_size = size + Vector2(8, 8)


## School research in the first three columns, the university's in the next three (E4 part 3).
func _card_pos(def: ResearchDef) -> Vector2:
	var column := def.tier - 1 + (3 if def.institution == ResearchDef.UNIVERSITY else 0)
	return Vector2(column * COL_W + 4, def.row * ROW_H + HEAD_H + 4)


func _clicked(id: StringName) -> void:
	if sim.research.current == id or sim.research.queue.has(id):
		command_requested.emit(CancelResearchCommand.new(id))
	else:
		command_requested.emit(StartResearchCommand.new(id))
	_refresh.call_deferred()


func _refresh() -> void:
	var research := sim.research
	var teachers := Researching.teachers(sim, ResearchDef.SCHOOL)
	if research.open:
		_status.text = tr("ui.research.all_open")
	elif research.current != &"":
		var def := sim.data.get_research(research.current)
		var left := maxf(def.time - research.progress, 0.0)
		var rate := Researching.study_rate(sim, def.institution)
		teachers = Researching.teachers(sim, def.institution)
		_status.text = tr("ui.research.current") % [tr(def.name_key()),
				_time_text(left / maxf(rate, 1.0)), teachers]
		if teachers == 0:
			var uni := def.institution == ResearchDef.UNIVERSITY
			var built := Researching.has_institution(sim, def.institution)
			_status.text += "\n" + tr(("ui.research.no_scholar" if uni else "ui.research.no_teacher") if built
					else ("ui.research.no_university" if uni else "ui.research.no_school"))
	elif not research.queue.is_empty():
		_status.text = tr("ui.research.waiting_gold") % tr(sim.data.get_research(research.queue[0]).name_key())
	elif not Researching.has_institution(sim, ResearchDef.SCHOOL):
		_status.text = tr("ui.research.no_school")
	else:
		_status.text = tr("ui.research.idle")
	var current := sim.data.get_research(research.current) if research.current != &"" else null
	_progress.visible = current != null
	if current != null:
		_progress.max_value = current.time
		_progress.value = research.progress
	var names := PackedStringArray()
	for id: StringName in research.queue:
		names.append(tr(sim.data.get_research(id).name_key()))
	_queue.text = tr("ui.research.queue") % (", ".join(names) if not names.is_empty() else tr("ui.research.queue_empty"))
	for def: ResearchDef in sim.data.researches():
		_refresh_card(def)
	_tree.queue_redraw()


func _refresh_card(def: ResearchDef) -> void:
	var research := sim.research
	var card := _cards[def.id]
	var state := ""
	var colour := Color.WHITE
	var tip := PackedStringArray([tr(def.name_key()), tr(def.desc_key())])
	if research.is_done(def.id):
		state = tr("ui.research.done")
		colour = DONE
	elif research.current == def.id:
		state = tr("ui.research.studying") % roundi(100.0 * research.progress / def.time)
		colour = NOW
		tip.append(tr("ui.research.click_cancel"))
	elif research.queue.has(def.id):
		state = tr("ui.research.queued") % (research.queue.find(def.id) + 1)
		colour = QUEUED
		tip.append(tr("ui.research.click_cancel"))
	else:
		var missing := PackedStringArray()
		for need: StringName in def.requires:
			if not research.is_planned(need):
				missing.append(tr(sim.data.get_research(need).name_key()))
		if not missing.is_empty():
			state = tr("ui.research.needs") % ", ".join(missing)
			colour = WAITING
		else:
			state = tr("ui.research.cost") % [def.gold_cost, _time_text(def.time)]
			tip.append(tr("ui.research.click_start"))
	var unlocks := PackedStringArray()
	for b: StringName in def.buildings:
		unlocks.append(tr("building.%s.name" % b))
	for s: StringName in def.ships:
		unlocks.append(tr("ship.%s.name" % s))
	for u: StringName in def.units:
		unlocks.append(tr("unit.%s.name" % u))
	for t: StringName in def.tools:
		unlocks.append(tr("ui.build.%s" % t))
	if not unlocks.is_empty():
		tip.append(tr("ui.research.unlocks") % ", ".join(unlocks))
	card.text = tr(def.name_key()) + "\n" + state
	card.modulate = colour
	card.tooltip_text = "\n".join(tip)
	card.disabled = research.open or research.is_done(def.id)


## Arrows from each research to those that need it (from the right edge to the left edge).
func _draw_arrows() -> void:
	if sim == null:
		return
	for def: ResearchDef in sim.data.researches():
		for need: StringName in def.requires:
			var from_def := sim.data.get_research(need)
			if from_def == null:
				continue
			var a := _card_pos(from_def) + Vector2(CARD.x, CARD.y / 2)
			var b := _card_pos(def) + Vector2(0, CARD.y / 2)
			var mid := (a.x + b.x) / 2
			var colour := UiKit.INK if sim.research.is_planned(need) else UiKit.INK_SOFT
			var line := PackedVector2Array([a, Vector2(mid, a.y), Vector2(mid, b.y), b])
			_tree.draw_polyline(line, colour, 3.0)
			_tree.draw_colored_polygon(PackedVector2Array([b, b + Vector2(-10, -6), b + Vector2(-10, 6)]), colour)


static func _time_text(seconds: float) -> String:
	var s := ceili(seconds)
	return "%d:%02d" % [s / 60, s % 60]

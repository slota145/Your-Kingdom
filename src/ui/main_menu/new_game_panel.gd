class_name NewGamePanel
extends VBoxContainer
## "New game" of the main menu (ROADMAP M8 part 1, owner's surveys 2026-11-09): the scenario,
## the world (generated from a number, or the hand-made "Kingdom"), its size, the AI rulers and
## their difficulty, the victory condition (with its target). "Start" sends GameSettings to the
## game scene. M8 part 5: four scenarios with a line about each; the Merchant islands take a
## gold target instead of a victory condition, the Invasion from the sea has neither (nor rulers).
## E4 part 1: a tick box for the developer mode. UI-2 part 3: it sits in NewGameWindow beside
## the live world preview; every change of an option emits [signal options_changed], and the
## "Roll another" button under the preview calls [method reroll].

signal start_requested(settings: GameSettings)
signal back_requested
signal options_changed

const HANDMADE := &"kingdom"
## Numbers of first plundering waves offered (then "all").
const PLUNDER_CHOICES := 5

var _scenario: OptionButton
var _scenario_hint: Label
var _gold: SpinBox
var _gold_row: Control
var _victory_row: Control
## The Invasion (M8 part 5, owner's request 2026-11-10): 60 minutes or survival, and how many
## first waves only plunder.
var _invasion_goal: OptionButton
var _plunder: OptionButton
var _world: OptionButton
var _seed: SpinBox
var _provinces: HSlider
var _islands: HSlider
var _rulers: OptionButton
var _difficulty: OptionButton
var _victory: OptionButton
var _target: SpinBox
var _target_row: Control
var _rulers_row: Control
var _generated_rows: Array[Control] = []
var _next: Button
## The developer mode (E4 part 1): to try the game out.
var _dev: CheckBox


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	add_child(UiKit.title("ui.new_game.title"))
	var scenario_keys: Array = []
	for scenario: StringName in GameSettings.SCENARIOS:
		scenario_keys.append("ui.scenario.%s" % scenario)
	_scenario = _choice("ui.new_game.scenario", scenario_keys)
	_scenario.item_selected.connect(func(_i: int) -> void: _refresh())
	_scenario_hint = UiKit.label("", false)
	_scenario_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scenario_hint.custom_minimum_size.x = 420
	add_child(_scenario_hint)
	_world = _choice("ui.new_game.world", ["ui.new_game.world_generated", "world.%s.name" % HANDMADE])
	_world.item_selected.connect(func(_i: int) -> void: _refresh())
	var seed_row := HBoxContainer.new()
	seed_row.add_child(UiKit.label("ui.new_game.seed", false))
	_seed = SpinBox.new()
	_seed.min_value = 1
	_seed.max_value = 99999
	_seed.value = randi_range(1, 99999)
	_seed.value_changed.connect(func(_v: float) -> void: _refresh())
	seed_row.add_child(_seed)
	add_child(seed_row)
	_generated_rows.append(seed_row)
	_provinces = _slider("ui.new_game.provinces", GameSettings.MIN_PROVINCES, GameSettings.MAX_PROVINCES, 22)
	_islands = _slider("ui.new_game.islands", 0, GameSettings.MAX_ISLANDS, 3)
	_rulers = _choice("ui.new_game.rulers", ["1", "2", "3"])
	_rulers.selected = 1
	_rulers_row = _rulers.get_parent()
	# Item index = GameSettings level (peaceful last, M8 part 4).
	_difficulty = _choice("ui.new_game.difficulty", ["ui.difficulty.easy", "ui.difficulty.normal", "ui.difficulty.hard",
			"ui.difficulty.peaceful"])
	_difficulty.selected = GameSettings.NORMAL
	_victory = _choice("ui.new_game.victory", ["ui.victory.conquest", "ui.victory.provinces",
			"ui.victory.patricians", "ui.victory.free"])
	_victory.item_selected.connect(func(_i: int) -> void: _refresh())
	_victory_row = _victory.get_parent()
	_gold_row = HBoxContainer.new()
	var gold_label := UiKit.label("ui.new_game.gold", false)
	gold_label.custom_minimum_size.x = 150
	_gold_row.add_child(gold_label)
	_gold = SpinBox.new()
	_gold.min_value = GameSettings.MIN_GOLD
	_gold.max_value = GameSettings.MAX_GOLD
	_gold.step = 1000
	_gold.value = GameSettings.DEFAULT_GOLD
	_gold_row.add_child(_gold)
	add_child(_gold_row)
	_invasion_goal = _choice("ui.new_game.invasion_goal", ["ui.invasion.hold_60", "ui.invasion.endless"])
	_invasion_goal.tooltip_text = "ui.invasion.endless_hint"
	var plunder_items: Array = ["ui.invasion.plunder_none"]
	for n: int in range(1, PLUNDER_CHOICES + 1):
		plunder_items.append(str(n))
	plunder_items.append("ui.invasion.plunder_all")
	_plunder = _choice("ui.new_game.plunder", plunder_items)
	_plunder.selected = GameSettings.DEFAULT_PLUNDER
	_plunder.tooltip_text = "ui.invasion.plunder_hint"
	_target_row = HBoxContainer.new()
	_target_row.add_child(UiKit.label("ui.new_game.target", false))
	_target = SpinBox.new()
	_target.min_value = 2
	_target.max_value = 2000
	_target_row.add_child(_target)
	add_child(_target_row)
	_dev = CheckBox.new()
	_dev.text = "ui.new_game.dev_mode"
	_dev.tooltip_text = "ui.new_game.dev_mode_hint"
	add_child(_dev)
	var buttons := HBoxContainer.new()
	_next = UiKit.button("ui.new_game.next", func() -> void: start_requested.emit(settings()))
	buttons.add_child(_next)
	buttons.add_child(UiKit.button("ui.new_game.back", func() -> void: back_requested.emit()))
	add_child(buttons)
	_refresh()


## A new world number (the "Roll another" button under the preview).
func reroll() -> void:
	var old := int(_seed.value)
	while int(_seed.value) == old:
		_seed.value = randi_range(1, 99999)


func is_generated() -> bool:
	return _world.selected == 0


func _choice(label_key: String, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	var label := UiKit.label(label_key, false)
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: String in items:
		option.add_item(item)
	row.add_child(option)
	add_child(row)
	return option


## A slider with its label and the value beside it (a row of the generated world).
func _slider(label_key: String, from: int, to: int, value: int) -> HSlider:
	var row := HBoxContainer.new()
	var label := UiKit.label(label_key, false)
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = from
	slider.max_value = to
	slider.step = 1
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var shown := UiKit.label(str(value), false)
	shown.custom_minimum_size.x = 36
	row.add_child(shown)
	slider.value_changed.connect(func(v: float) -> void:
		shown.text = str(int(v))
		_refresh())
	add_child(row)
	_generated_rows.append(row)
	return slider


## What the player chose.
func settings() -> GameSettings:
	var s := GameSettings.new()
	if _world.selected == 1:
		s.world_def = HANDMADE
		s.rulers = 0
		s.victory = GameSettings.VICTORY_FREE if _victory.selected == 0 else GameSettings.VICTORIES[_victory.selected]
	else:
		s.world_seed = int(_seed.value)
		s.province_count = int(_provinces.value)
		s.islands = int(_islands.value)
		s.rulers = _rulers.selected + 1
		s.victory = GameSettings.VICTORIES[_victory.selected]
	s.difficulty = _difficulty.selected
	s.dev_mode = _dev.button_pressed
	if s.victory == GameSettings.VICTORY_PROVINCES or s.victory == GameSettings.VICTORY_PATRICIANS:
		s.victory_target = int(_target.value)
	if _world.selected == 0:
		s.scenario = GameSettings.SCENARIOS[_scenario.selected]
		s.gold_target = int(_gold.value)
		s.endless = _invasion_goal.selected == 1
		s.plunder_waves = GameSettings.PLUNDER_ALL if _plunder.selected > PLUNDER_CHOICES else _plunder.selected
		s.fit_scenario()
	return s


func _refresh() -> void:
	var generated := _world.selected == 0
	# The scenarios are worlds made from a number; "Kingdom" is played as it is.
	_scenario.disabled = not generated
	if not generated:
		_scenario.selected = 0
	var scenario := GameSettings.SCENARIOS[_scenario.selected]
	_scenario_hint.text = tr("ui.scenario.%s_hint" % scenario)
	_next.text = tr("ui.new_game.next" if generated else "ui.new_game.start")
	for row: Control in _generated_rows:
		row.visible = generated
	_rulers_row.visible = generated and scenario != GameSettings.INVASION
	# (The difficulty is the rulers': the Invasion has none.)
	_difficulty.get_parent().visible = scenario != GameSettings.INVASION
	_gold_row.visible = scenario == GameSettings.ISLANDS
	_invasion_goal.get_parent().visible = scenario == GameSettings.INVASION
	_plunder.get_parent().visible = scenario == GameSettings.INVASION
	_islands.get_parent().visible = generated and scenario != GameSettings.ISLANDS   # (all islands there)
	_victory_row.visible = scenario != GameSettings.ISLANDS and scenario != GameSettings.INVASION
	# The hand-made world has no rulers: no conquest there.
	_victory.set_item_disabled(0, not generated)
	if not generated and _victory.selected == 0:
		_victory.selected = 3
	var kind := GameSettings.VICTORIES[_victory.selected]
	_target_row.visible = _victory_row.visible and (kind == GameSettings.VICTORY_PROVINCES
			or kind == GameSettings.VICTORY_PATRICIANS)
	if _target_row.visible:
		var probe := GameSettings.new()
		probe.province_count = int(_provinces.value)
		_target.value = probe.default_target(kind)
	options_changed.emit()

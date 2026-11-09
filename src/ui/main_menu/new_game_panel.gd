class_name NewGamePanel
extends VBoxContainer
## "New game" of the main menu (ROADMAP M8 part 1, owner's surveys 2026-11-09): the scenario,
## the world (generated from a number, or the hand-made "Kingdom"), its size, the AI rulers and
## their difficulty, the victory condition (with its target). "Start" sends GameSettings to the
## game scene.

signal start_requested(settings: GameSettings)
signal back_requested

const HANDMADE := &"kingdom"

var _scenario: OptionButton
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


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	add_child(UiKit.title("ui.new_game.title"))
	_scenario = _choice("ui.new_game.scenario", ["ui.scenario.colonization"])
	_scenario.tooltip_text = "ui.scenario.colonization_hint"
	_world = _choice("ui.new_game.world", ["ui.new_game.world_generated", "world.%s.name" % HANDMADE])
	_world.item_selected.connect(func(_i: int) -> void: _refresh())
	var seed_row := HBoxContainer.new()
	seed_row.add_child(UiKit.label("ui.new_game.seed", false))
	_seed = SpinBox.new()
	_seed.min_value = 1
	_seed.max_value = 99999
	_seed.value = randi_range(1, 99999)
	seed_row.add_child(_seed)
	seed_row.add_child(UiKit.button("ui.new_game.random", func() -> void: _seed.value = randi_range(1, 99999)))
	add_child(seed_row)
	_generated_rows.append(seed_row)
	_provinces = _slider("ui.new_game.provinces", GameSettings.MIN_PROVINCES, GameSettings.MAX_PROVINCES, 22)
	_islands = _slider("ui.new_game.islands", 0, GameSettings.MAX_ISLANDS, 3)
	_rulers = _choice("ui.new_game.rulers", ["1", "2", "3"])
	_rulers.selected = 1
	_rulers_row = _rulers.get_parent()
	_difficulty = _choice("ui.new_game.difficulty", ["ui.difficulty.easy", "ui.difficulty.normal", "ui.difficulty.hard"])
	_difficulty.selected = GameSettings.NORMAL
	_victory = _choice("ui.new_game.victory", ["ui.victory.conquest", "ui.victory.provinces",
			"ui.victory.patricians", "ui.victory.free"])
	_victory.item_selected.connect(func(_i: int) -> void: _refresh())
	_target_row = HBoxContainer.new()
	_target_row.add_child(UiKit.label("ui.new_game.target", false))
	_target = SpinBox.new()
	_target.min_value = 2
	_target.max_value = 2000
	_target_row.add_child(_target)
	add_child(_target_row)
	var buttons := HBoxContainer.new()
	_next = UiKit.button("ui.new_game.next", func() -> void: start_requested.emit(settings()))
	buttons.add_child(_next)
	buttons.add_child(UiKit.button("ui.new_game.back", func() -> void: back_requested.emit()))
	add_child(buttons)
	_refresh()


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
	if s.victory == GameSettings.VICTORY_PROVINCES or s.victory == GameSettings.VICTORY_PATRICIANS:
		s.victory_target = int(_target.value)
	return s


func _refresh() -> void:
	var generated := _world.selected == 0
	_next.text = tr("ui.new_game.next" if generated else "ui.new_game.start")
	for row: Control in _generated_rows:
		row.visible = generated
	_rulers_row.visible = generated
	# The hand-made world has no rulers: no conquest there.
	_victory.set_item_disabled(0, not generated)
	if not generated and _victory.selected == 0:
		_victory.selected = 3
	var kind := GameSettings.VICTORIES[_victory.selected]
	_target_row.visible = kind == GameSettings.VICTORY_PROVINCES or kind == GameSettings.VICTORY_PATRICIANS
	if _target_row.visible:
		var probe := GameSettings.new()
		probe.province_count = int(_provinces.value)
		_target.value = probe.default_target(kind)

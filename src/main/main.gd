extends Control
## The main menu (ROADMAP UI-1, owner's decision 2026-11-07): the living harbour picture
## (MenuBackdrop) and, on the parchment at the left, the title and the wooden buttons: new game
## in the world, the quick save, single provinces on the old maps (unfolded on demand), the
## language and quitting. The developer's tools (sandbox, benchmark, plural forms and the glyph
## test) fold away under one button.

const PLURAL_SAMPLES: PackedInt32Array = [1, 2, 5, 12, 22, 1250]
const GAME_SCENE := "res://src/main/game_scene.tscn"
const SANDBOX_SCENE := "res://src/prototype/m2/m2_sandbox.tscn"
const BENCHMARK_SCENE := "res://src/prototype/m2/m2_bench.tscn"
const MENU_WIDTH := 380.0

var _title: Label
var _subtitle: Label
var _new_game: Button
var _load_game: Button
var _maps_button: Button
var _maps: VBoxContainer
var _language: Button
var _tools_button: Button
var _tools: VBoxContainer
var _plural_list: Label


func _ready() -> void:
	theme = UiKit.theme()
	add_child(MenuBackdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = MENU_WIDTH
	column.add_child(panel)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	_title = UiKit.title("ui.main.title")
	_title.add_theme_font_size_override(&"font_size", 56)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.custom_minimum_size.x = MENU_WIDTH - 40.0
	box.add_child(_title)
	_subtitle = UiKit.label("ui.main.subtitle")
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override(&"font_color", UiKit.INK_SOFT)
	_subtitle.custom_minimum_size.x = MENU_WIDTH - 40.0
	box.add_child(_subtitle)
	box.add_child(HSeparator.new())
	var worlds := Data.registry.all_of(&"world")
	_new_game = _menu_button(box, "ui.main.new_game", func() -> void:
		Game.start_request = {"world": worlds[0].id}
		_open(GAME_SCENE))
	_new_game.disabled = worlds.is_empty()
	var quick := SaveService.slot_path("quick")
	_load_game = _menu_button(box, "ui.main.load_game", _start_game.bind(quick))
	_load_game.disabled = not FileAccess.file_exists(quick)
	_maps_button = _menu_button(box, "ui.main.single_provinces", func() -> void:
		_maps.visible = not _maps.visible
		_tools.visible = false)
	_maps = VBoxContainer.new()
	_maps.visible = false
	box.add_child(_maps)
	for def: GameDef in Data.registry.all_of(&"map"):
		var map := def as MapDef
		var button := _menu_button(_maps, "", func() -> void:
			Game.start_request = {"map": map.id}
			_open(GAME_SCENE))
		button.set_meta(&"map", map.id)
		button.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE + 4)
	_language = _menu_button(box, "ui.main.toggle_language", Loc.cycle_locale)
	_tools_button = _menu_button(box, "ui.main.tools", func() -> void:
		_tools.visible = not _tools.visible
		_maps.visible = false)
	_tools = VBoxContainer.new()
	_tools.visible = false
	box.add_child(_tools)
	_menu_button(_tools, "ui.main.open_sandbox", _open.bind(SANDBOX_SCENE))
	_menu_button(_tools, "ui.main.open_benchmark", _open.bind(BENCHMARK_SCENE))
	var glyphs := UiKit.label("ui.main.glyph_test")
	glyphs.custom_minimum_size.x = MENU_WIDTH - 40.0
	_tools.add_child(glyphs)
	_tools.add_child(UiKit.label("ui.main.plural_demo"))
	var plural_scroll := ScrollContainer.new()
	plural_scroll.custom_minimum_size = Vector2(MENU_WIDTH - 40.0, 140.0)
	plural_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tools.add_child(plural_scroll)
	_plural_list = UiKit.label()
	_plural_list.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	_plural_list.custom_minimum_size.x = MENU_WIDTH - 60.0
	plural_scroll.add_child(_plural_list)
	_menu_button(box, "ui.main.quit", func() -> void: get_tree().quit())
	EventBus.language_changed.connect(_on_language_changed)
	_refresh()


func _menu_button(parent: Control, key: String, on_pressed: Callable) -> Button:
	var b := UiKit.button(key, on_pressed)
	b.add_theme_font_size_override(&"font_size", 30)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b


func _open(scene: String) -> void:
	get_tree().change_scene_to_file(scene)


func _start_game(load_path: String) -> void:
	Game.start_request = {"load": load_path} if load_path != "" else {}
	_open(GAME_SCENE)


func _on_language_changed(_locale: String) -> void:
	_refresh()


func _refresh() -> void:
	for child: Node in _maps.get_children():
		if child is Button and child.has_meta(&"map"):
			var id: StringName = child.get_meta(&"map")
			(child as Button).text = tr("map.%s.name" % id)
			(child as Button).tooltip_text = tr("map.%s.desc" % id)
	var lines := PackedStringArray()
	for good: GoodDef in Data.registry.goods():
		var samples := PackedStringArray()
		for amount: int in PLURAL_SAMPLES:
			samples.append(Loc.good_count(good.id, amount))
		lines.append("%s: %s" % [tr(good.name_key()), ", ".join(samples)])
	_plural_list.text = "\n".join(lines)

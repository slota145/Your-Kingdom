class_name OptionsWindow
extends PanelContainer
## The "Options" window (ROADMAP M10 part 3), from the main menu and the pause menu: tabs
## Screen, Sound, Controls and Game. Every change takes effect at once and is kept in
## user://settings.cfg by the Options autoload; the window only shows and edits it.

signal closed

const LABEL_WIDTH := 360.0

var _tabs: TabContainer
## The action whose key is being given (waiting for a key press), &"" when none.
var _listening: StringName = &""
var _key_buttons: Dictionary[StringName, Button] = {}
var _key_note: Label


func _init() -> void:
	theme = UiKit.theme()
	custom_minimum_size = Vector2(760, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	EventBus.language_changed.connect(_on_language_changed)


func _on_language_changed(_locale: String) -> void:
	_rebuild.call_deferred()


## The name of the first key of [param action] ("F5", "Space"…), or "-" when it has none.
static func key_name(action: StringName) -> String:
	var keys := Options.keys_of(action)
	if keys.is_empty():
		return "-"
	var keycode := keys[0] as Key
	# The letter this key gives on the player's keyboard layout (none without a screen).
	if DisplayServer.get_name() != "headless":
		var local := DisplayServer.keyboard_get_keycode_from_physical(keycode)
		if local != KEY_NONE:
			keycode = local
	return OS.get_keycode_string(keycode)


func open() -> void:
	_rebuild()
	visible = true
	move_to_front()


func close() -> void:
	_listening = &""
	visible = false
	closed.emit()


func _rebuild() -> void:
	var current := _tabs.current_tab if _tabs != null else 0
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_key_buttons.clear()
	_build()
	_tabs.current_tab = clampi(current, 0, _tabs.get_tab_count() - 1)


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	add_child(box)
	box.add_child(UiKit.title("ui.options.title"))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The tabs' pages lie on the window's parchment (dark ink stays readable).
	var page := StyleBoxFlat.new()
	page.bg_color = Color(0, 0, 0, 0)
	page.border_color = UiKit.INK_SOFT
	page.border_width_top = 2
	page.content_margin_top = 10
	page.content_margin_left = 4
	page.content_margin_right = 4
	_tabs.add_theme_stylebox_override(&"panel", page)
	box.add_child(_tabs)
	_tab("ui.options.tab_screen", _screen_tab())
	_tab("ui.options.tab_sound", _sound_tab())
	_tab("ui.options.tab_controls", _controls_tab())
	_tab("ui.options.tab_game", _game_tab())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override(&"separation", 8)
	buttons.add_child(UiKit.button("ui.options.defaults", func() -> void:
		Options.reset()
		_rebuild()))
	buttons.add_child(UiKit.button("ui.options.close", close))
	box.add_child(buttons)


func _tab(title_key: String, content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(content)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, tr(title_key))


# --- Tabs ----------------------------------------------------------------------------------

func _screen_tab() -> VBoxContainer:
	var list := _list()
	_choice(list, "ui.options.window_mode", [tr("ui.options.windowed"), tr("ui.options.fullscreen")],
			int(Options.get_value("display/mode")), func(i: int) -> void: Options.set_value("display/mode", i))
	var sizes := Options.resolutions_for(DisplayServer.screen_get_size() if DisplayServer.get_name() != "headless" else Vector2i.ZERO)
	var size: Vector2i = Options.get_value("display/resolution")
	var names: Array[String] = []
	for s: Vector2i in sizes:
		names.append("%d × %d" % [s.x, s.y])
	_choice(list, "ui.options.resolution", names, maxi(sizes.find(size), 0), func(i: int) -> void:
		Options.set_value("display/resolution", sizes[i]))
	_check(list, "ui.options.vsync", "display/vsync")
	var scales: Array[String] = []
	for f: float in Options.UI_SCALES:
		scales.append(tr("ui.options.ui_scale_auto") % roundi(Options.ui_scale_for_auto() * 100.0) if f == Options.AUTO_UI_SCALE
				else tr("ui.options.percent") % roundi(f * 100.0))
	_choice(list, "ui.options.ui_scale", scales, _index_of(Options.UI_SCALES, float(Options.get_value("display/ui_scale"))),
			func(i: int) -> void: Options.set_value("display/ui_scale", Options.UI_SCALES[i]))
	var limits: Array[String] = []
	for fps: int in Options.FPS_LIMITS:
		limits.append(tr("ui.options.no_limit") if fps == 0 else str(fps))
	_choice(list, "ui.options.max_fps", limits, maxi(Array(Options.FPS_LIMITS).find(int(Options.get_value("display/max_fps"))), 0),
			func(i: int) -> void: Options.set_value("display/max_fps", Options.FPS_LIMITS[i]))
	_check(list, "ui.options.show_fps", "display/show_fps")
	return list


func _sound_tab() -> VBoxContainer:
	var list := _list()
	for key: String in ["audio/master", "audio/music", "audio/effects", "audio/ambience", "audio/interface"]:
		_volume(list, "ui.options." + key.get_slice("/", 1), key)
	_check(list, "ui.options.mute_in_background", "audio/mute_in_background")
	_check(list, "ui.options.battle_music", "audio/battle_music")
	return list


func _controls_tab() -> VBoxContainer:
	var list := _list()
	var hint := UiKit.label("ui.options.keys_hint")
	hint.add_theme_color_override(&"font_color", UiKit.INK_SOFT)
	list.add_child(hint)
	for action: StringName in Options.REBINDABLE:
		var row := _row(list, "ui.action.%s" % action)
		var button := Button.new()
		button.custom_minimum_size.x = 180
		button.text = key_name(action)
		button.pressed.connect(_listen.bind(action))
		row.add_child(button)
		_key_buttons[action] = button
	_key_note = UiKit.label("")
	_key_note.add_theme_color_override(&"font_color", UiKit.BAD)
	list.add_child(_key_note)
	list.add_child(UiKit.button("ui.options.keys_defaults", func() -> void:
		Options.reset_keys()
		_key_note.text = ""
		_refresh_keys()))
	return list


func _game_tab() -> VBoxContainer:
	var list := _list()
	var every: Array[String] = []
	for minutes: int in Options.AUTOSAVE_MINUTES:
		every.append(tr("ui.options.autosave_off") if minutes == 0 else tr("ui.options.autosave_every") % minutes)
	_choice(list, "ui.options.autosave", every,
			maxi(Array(Options.AUTOSAVE_MINUTES).find(int(Options.get_value("game/autosave_minutes"))), 0),
			func(i: int) -> void: Options.set_value("game/autosave_minutes", Options.AUTOSAVE_MINUTES[i]))
	_check(list, "ui.options.edge_scroll", "game/edge_scroll")
	var speeds: Array[String] = []
	for speed: float in Options.CAMERA_SPEEDS:
		speeds.append("%s×" % String.num(speed, 2))
	_choice(list, "ui.options.camera_speed", speeds,
			_index_of(Options.CAMERA_SPEEDS, float(Options.get_value("game/camera_speed"))),
			func(i: int) -> void: Options.set_value("game/camera_speed", Options.CAMERA_SPEEDS[i]))
	var languages: Array[String] = []
	for locale: String in Loc.SUPPORTED_LOCALES:
		languages.append(tr("ui.options.language_%s" % locale))
	_choice(list, "ui.options.language", languages, maxi(Loc.SUPPORTED_LOCALES.find(Loc.get_locale()), 0),
			func(i: int) -> void: Options.set_value("game/language", Loc.SUPPORTED_LOCALES[i]))
	return list


# --- Keys ----------------------------------------------------------------------------------

func _listen(action: StringName) -> void:
	_refresh_keys()
	_listening = action
	_key_buttons[action].text = tr("ui.options.press_key")
	_key_note.text = ""


func _input(event: InputEvent) -> void:
	if _listening == &"" or not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	var action := _listening
	_listening = &""
	if key.physical_keycode != KEY_ESCAPE:
		var taken := Options.bind(action, int(key.physical_keycode))
		if taken != &"":
			_key_note.text = tr("ui.options.key_taken") % [key_name(action), tr("ui.action.%s" % taken)]
	_refresh_keys()


func _refresh_keys() -> void:
	for action: StringName in _key_buttons:
		_key_buttons[action].text = key_name(action)


# --- Rows ----------------------------------------------------------------------------------

func _list() -> VBoxContainer:
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 8)
	return list


func _row(list: VBoxContainer, label_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var label := UiKit.label(label_key, false)
	label.custom_minimum_size.x = LABEL_WIDTH
	row.add_child(label)
	list.add_child(row)
	return row


func _choice(list: VBoxContainer, label_key: String, items: Array[String], selected: int, on_pick: Callable) -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: String in items:
		option.add_item(item)
	option.selected = selected
	option.item_selected.connect(on_pick)
	_row(list, label_key).add_child(option)
	return option


func _check(list: VBoxContainer, label_key: String, key: String) -> CheckBox:
	var box := CheckBox.new()
	box.button_pressed = bool(Options.get_value(key))
	box.toggled.connect(func(on: bool) -> void: Options.set_value(key, on))
	_row(list, label_key).add_child(box)
	return box


func _volume(list: VBoxContainer, label_key: String, key: String) -> HSlider:
	var row := _row(list, label_key)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundf(float(Options.get_value(key)) * 100.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var shown := UiKit.label(tr("ui.options.percent") % int(slider.value), false)
	shown.custom_minimum_size.x = 52
	row.add_child(shown)
	slider.value_changed.connect(func(v: float) -> void:
		shown.text = tr("ui.options.percent") % int(v)
		Options.set_value(key, v / 100.0))
	return slider


static func _index_of(values: PackedFloat32Array, value: float) -> int:
	for i: int in values.size():
		if is_equal_approx(values[i], value):
			return i
	return 0

extends Node
## Autoload "Options" (ROADMAP M10 part 3): the player's settings, kept in
## user://settings.cfg apart from the saved games, applied at start and whenever one
## changes. Screen (window or full screen, window size, vsync, interface scale, frame limit,
## frame counter), sound (five volumes, quiet in the background, battle music), game
## (autosave, edge scrolling, camera speed, language) and the keys of the actions.

signal changed(key: String)

const PATH := "user://settings.cfg"

const WINDOWED := 0
const FULLSCREEN := 1

## Window sizes offered (those that fit the screen).
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
		Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
## 0 = automatic (AUTO_UI_SCALE): fits the window, so a 1920×1080 screen gets 150%.
const UI_SCALES: PackedFloat32Array = [0.0, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]
const AUTO_UI_SCALE := 0.0
## The version of the settings file: 2 made the interface scale automatic (friend's playtest
## 2026-11-17: the top bar was hard to read on a big screen), older files get "automatic".
const SETTINGS_VERSION := 2
## 0 = no limit.
const FPS_LIMITS: PackedInt32Array = [0, 30, 60, 120, 144]
## 0 = no autosave.
const AUTOSAVE_MINUTES: PackedInt32Array = [0, 2, 5, 10]
const CAMERA_SPEEDS: PackedFloat32Array = [0.5, 0.75, 1.0, 1.5, 2.0]

## Volume key -> audio bus.
const BUSES: Dictionary[String, StringName] = {
	"audio/master": &"Master", "audio/music": &"Music", "audio/effects": &"Effects",
	"audio/ambience": &"Ambience", "audio/interface": &"Interface",
}

const DEFAULTS: Dictionary[String, Variant] = {
	"display/mode": WINDOWED,
	"display/resolution": Vector2i(1600, 900),
	"display/vsync": true,
	"display/ui_scale": AUTO_UI_SCALE,
	"display/max_fps": 0,
	"display/show_fps": false,
	"audio/master": 1.0,
	"audio/music": 1.0,
	"audio/effects": 1.0,
	"audio/ambience": 1.0,
	"audio/interface": 1.0,
	"audio/mute_in_background": true,
	"audio/battle_music": true,
	"game/autosave_minutes": 5,
	"game/edge_scroll": false,
	"game/camera_speed": 1.0,
	"game/language": "pl",
	# UI-3 part 1: the messages folded away, the goods shown under the top bar ("food" = all
	# the food together).
	"game/notes_folded": false,
	"game/pinned_goods": ["wood", "stone", "planks", "food"],
	# UI-4 part 2: the version whose "What's new" was shown last ("" = none yet).
	"game/news_seen": "",
}

## Actions the player can give other keys, in the order shown (InputSetup has them all).
const REBINDABLE: Array[StringName] = [&"camera_up", &"camera_down", &"camera_left", &"camera_right",
		&"camera_zoom_1", &"camera_zoom_2", &"camera_zoom_3", &"camera_zoom_4", &"toggle_pause",
		&"game_speed_up", &"game_speed_down", &"toggle_build_menu", &"rotate_building", &"cycle_look",
		&"world_map", &"toggle_grid", &"toggle_lower_buildings", &"toggle_gate", &"quick_save", &"quick_load"]

var values: Dictionary[String, Variant] = {}
## Keys given by the player: action -> physical keycodes (the first is shown and changed).
var bindings: Dictionary[StringName, Array] = {}
## Whether to write the file on a change (off in tests that use their own path).
var path: String = PATH

## The volume each bus has in default_bus_layout.tres; the sliders scale it.
var _base_db: Dictionary[StringName, float] = {}
var _fps_layer: CanvasLayer
var _fps_label: Label
var _fps_time: float = 0.0
var _loading: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: String in BUSES:
		var index := AudioServer.get_bus_index(BUSES[key])
		if index != -1:
			_base_db[BUSES[key]] = AudioServer.get_bus_volume_db(index)
	_build_fps_counter()
	InputSetup.ensure_defaults()
	load_file()
	apply_all()
	EventBus.language_changed.connect(func(locale: String) -> void:
		if not _loading and values.get("game/language") != locale:
			values["game/language"] = locale
			save_file()
			changed.emit("game/language"))


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	values[key] = value
	_apply(key)
	save_file()
	changed.emit(key)


## Seconds between autosaves (0 = none).
func autosave_seconds() -> float:
	return float(int(get_value("game/autosave_minutes"))) * 60.0


func load_file() -> void:
	values = DEFAULTS.duplicate()
	bindings.clear()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key: String in DEFAULTS:
		var parts := key.split("/")
		if file.has_section_key(parts[0], parts[1]):
			var stored: Variant = file.get_value(parts[0], parts[1])
			if typeof(stored) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and stored is int):
				values[key] = stored
	if int(file.get_value("meta", "version", 1)) < 2:
		values["display/ui_scale"] = AUTO_UI_SCALE
	if file.has_section("keys"):
		for action: String in file.get_section_keys("keys"):
			var keys: Variant = file.get_value("keys", action)
			if keys is Array and REBINDABLE.has(StringName(action)):
				bindings[StringName(action)] = (keys as Array).filter(func(k: Variant) -> bool: return k is int)


func save_file() -> void:
	if path == "":
		return
	var file := ConfigFile.new()
	file.set_value("meta", "version", SETTINGS_VERSION)
	for key: String in values:
		var parts := key.split("/")
		file.set_value(parts[0], parts[1], values[key])
	for action: StringName in bindings:
		file.set_value("keys", String(action), bindings[action])
	file.save(path)


func apply_all() -> void:
	_loading = true
	for key: String in DEFAULTS:
		_apply(key)
	_apply_bindings()
	_loading = false


## Back to the defaults (the keys separately: [method reset_keys]).
func reset() -> void:
	values = DEFAULTS.duplicate()
	apply_all()
	save_file()
	changed.emit("")


# --- Keys ----------------------------------------------------------------------------------

## The physical keycodes of [param action] now.
func keys_of(action: StringName) -> Array[int]:
	var result: Array[int] = []
	if not InputMap.has_action(action):
		return result
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			result.append(int(key.physical_keycode))
	return result


## Gives [param action] the key [param keycode] in place of its first one. Another action
## with that key loses it (returned, &"" when none), so no key does two things.
func bind(action: StringName, keycode: int) -> StringName:
	var taken := &""
	for other: StringName in REBINDABLE:
		if other == action:
			continue
		var keys := keys_of(other)
		if keys.has(keycode):
			keys.erase(keycode)
			bindings[other] = keys
			taken = other
	var mine := keys_of(action)
	mine.erase(keycode)
	if mine.is_empty():
		mine.append(keycode)
	else:
		mine[0] = keycode
	bindings[action] = mine
	_apply_bindings()
	save_file()
	changed.emit("keys")
	return taken


func reset_keys() -> void:
	bindings.clear()
	for action: StringName in REBINDABLE:
		_set_keys(action, InputSetup.DEFAULTS.get(action, []))
	save_file()
	changed.emit("keys")


func _apply_bindings() -> void:
	for action: StringName in bindings:
		_set_keys(action, bindings[action])


func _set_keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	for keycode: Variant in keys:
		var key := InputEventKey.new()
		key.physical_keycode = int(keycode) as Key
		InputMap.action_add_event(action, key)


# --- Applying ------------------------------------------------------------------------------

func _apply(key: String) -> void:
	var value: Variant = get_value(key)
	match key:
		"display/mode", "display/resolution":
			_apply_window()
		"display/vsync":
			DisplayServer.window_set_vsync_mode(
					DisplayServer.VSYNC_ENABLED if bool(value) else DisplayServer.VSYNC_DISABLED)
		"display/max_fps":
			Engine.max_fps = int(value)
		"display/show_fps":
			_fps_layer.visible = bool(value)
		"game/language":
			if Loc.get_locale() != String(value):
				Loc.set_locale(String(value))
		_:
			if BUSES.has(key):
				_apply_volume(BUSES[key], float(value))


## Volume [param level] (0..1) of [param bus], on top of its volume in the bus layout.
func _apply_volume(bus: StringName, level: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, volume_db(_base_db.get(bus, 0.0), level))
	if bus != &"Master":
		AudioServer.set_bus_mute(index, level <= 0.0)


## The interface scale in use: the chosen one, or for "automatic" the visible height of the
## window over the 720 px the interface was made for, in steps of 25% (1 to 3): 1920×1080
## (one screen pixel per game pixel) gives 1.5, 2560×1440 (two per pixel) gives 1.
func ui_scale() -> float:
	var chosen := float(get_value("display/ui_scale"))
	if chosen > 0.0:
		return chosen
	var height := get_viewport().get_visible_rect().size.y if is_inside_tree() else 720.0
	return auto_ui_scale(height)


## What "automatic" gives now (shown in the options).
func ui_scale_for_auto() -> float:
	return auto_ui_scale(get_viewport().get_visible_rect().size.y if is_inside_tree() else 720.0)


static func auto_ui_scale(visible_height: float) -> float:
	return clampf(floorf(visible_height / 720.0 * 4.0 + 0.001) / 4.0, 1.0, 3.0)


## Decibels of a bus at [param level] (0..1) when its layout volume is [param base_db].
static func volume_db(base_db: float, level: float) -> float:
	return base_db + linear_to_db(maxf(level, 0.0001))


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if int(get_value("display/mode")) == FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var size: Vector2i = get_value("display/resolution")
	var screen := DisplayServer.screen_get_usable_rect()
	size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


## Window sizes that fit the screen (all of them without a screen).
static func resolutions_for(screen: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for size: Vector2i in RESOLUTIONS:
		if screen == Vector2i.ZERO or (size.x <= screen.x and size.y <= screen.y):
			result.append(size)
	return result


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if bool(get_value("audio/mute_in_background")):
				AudioServer.set_bus_mute(0, true)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			AudioServer.set_bus_mute(0, false)


# --- Frame counter -------------------------------------------------------------------------

func _build_fps_counter() -> void:
	_fps_layer = CanvasLayer.new()
	_fps_layer.layer = 127
	_fps_layer.visible = false
	add_child(_fps_layer)
	_fps_label = Label.new()
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fps_label.position = Vector2(-8, 40)
	_fps_label.add_theme_color_override(&"font_color", Color(1, 1, 0.85))
	_fps_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0))
	_fps_label.add_theme_constant_override(&"outline_size", 4)
	_fps_layer.add_child(_fps_label)


func _process(delta: float) -> void:
	if not _fps_layer.visible:
		return
	_fps_time -= delta
	if _fps_time <= 0.0:
		_fps_time = 0.5
		_fps_label.text = tr("ui.options.fps_counter") % Engine.get_frames_per_second()

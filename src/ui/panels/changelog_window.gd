class_name ChangelogWindow
extends PanelContainer
## "What's new" (UI-4 part 2, owner's survey 2026-11-23): what every released version of the game
## brought, newest first, in plain words; from the main menu, and once by itself after an update
## (the version last shown is kept in the options).
## The texts are localization keys: changelog.<version with _>.title and .1, .2… (localization/*.po).

signal closed

## Released versions, newest first: [version, date, number of points].
const VERSIONS: Array[Array] = [
	["0.9.3", "2026-11-23", 9],
	["0.9.2", "2026-11-17", 5],
	["0.9.1", "2026-11-15", 1],
	["0.9.0", "2026-11-14", 6],
]
## The option holding the version whose news were last shown.
const SEEN_KEY := "game/news_seen"

var _list: VBoxContainer


func _init() -> void:
	theme = UiKit.theme()
	custom_minimum_size = Vector2(720, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiKit.title("ui.news.title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size.x = 0
	head.add_child(title)
	head.add_child(UiKit.button("ui.news.close", close))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 440
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	scroll.add_child(_list)


func open() -> void:
	_rebuild()
	visible = true
	move_to_front()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## The localization key of point [param n] of [param version] (n = 0: its title).
static func key(version: String, n: int) -> String:
	var base := "changelog.%s." % version.replace(".", "_")
	return base + ("title" if n == 0 else str(n))


## The game's own version ("0.9.3").
static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))


## Whether the news of this version have not been shown yet; marks them shown.
static func take_unseen() -> bool:
	var version := game_version()
	if String(Options.get_value(SEEN_KEY)) == version:
		return false
	Options.set_value(SEEN_KEY, version)
	return true


func _rebuild() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	for entry: Array in VERSIONS:
		var version: String = entry[0]
		var heading := UiKit.label("", false)
		heading.text = tr("ui.news.version") % [version, entry[1], tr(key(version, 0))]
		heading.add_theme_color_override(&"font_color", UiKit.HEADING)
		_list.add_child(heading)
		for n: int in range(1, int(entry[2]) + 1):
			var point := UiKit.label("", true)
			point.text = "• " + tr(key(version, n))
			point.custom_minimum_size.x = 660
			_list.add_child(point)
		_list.add_child(HSeparator.new())

class_name MessagesWindow
extends PanelContainer
## The history of messages (M10 part 5, friend's playtest 2026-11-17): the last
## Notifications.HISTORY_SIZE messages, newest first, each with its game time; a message
## about a place has "Show", which moves the camera there.

signal show_requested(at: Vector2)
signal closed

var notes: Notifications
var _list: VBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(560, 420)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	add_child(box)
	box.add_child(UiKit.title("ui.messages.title"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_list)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_child(UiKit.button("ui.options.close", close))
	box.add_child(buttons)


func open() -> void:
	visible = true
	move_to_front()
	refresh()
	if notes != null:
		notes.mark_read()


func close() -> void:
	visible = false
	closed.emit()


## Called when a message comes while the window is open.
func on_history_changed() -> void:
	if visible:
		refresh()


func refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if notes == null or notes.history.is_empty():
		var empty := UiKit.label("ui.messages.empty")
		empty.add_theme_color_override(&"font_color", UiKit.INK_SOFT)
		_list.add_child(empty)
		return
	for entry: Dictionary in notes.history:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var time := UiKit.label(String(entry["time"]), false)
		time.custom_minimum_size.x = 64
		time.add_theme_color_override(&"font_color", UiKit.INK_SOFT)
		row.add_child(time)
		var text := UiKit.label(String(entry["text"]))
		text.custom_minimum_size.x = 0
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		if entry["at"] != null:
			var at: Vector2 = entry["at"]
			var show := UiKit.button("ui.messages.show", func() -> void: show_requested.emit(at))
			show.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(show)
		_list.add_child(row)

class_name SavesWindow
extends PanelContainer
## "Save game" and "Load game" (UI-3 part 2, a friend's playtest 2026-11-23: one save slot was
## frustrating): every save in a list, newest first, with its name, when it was saved and the
## game time. Saving: a new save under a name, or over one of the player's own. Loading: any
## save, the quick save (F5) and the autosave too. Deleting and overwriting ask once more:
## the button turns into "Sure?" and acts on the second click.

signal closed
## Save into [param path] under [param save_name].
signal save_chosen(path: String, save_name: String)
signal load_chosen(path: String)

enum Mode { SAVE, LOAD }

const LIST_HEIGHT := 360.0

var mode: Mode = Mode.LOAD
var _title: Label
var _name_row: HBoxContainer
var _name: LineEdit
var _list: VBoxContainer
var _empty: Label
## The button waiting for its second click (overwrite, delete), null when none.
var _armed: Button


func _init() -> void:
	theme = UiKit.theme()
	custom_minimum_size = Vector2(720, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_title = UiKit.title("")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.custom_minimum_size.x = 0
	head.add_child(_title)
	head.add_child(UiKit.button("ui.saves.close", close))
	_name_row = HBoxContainer.new()
	_name_row.add_theme_constant_override(&"separation", 8)
	box.add_child(_name_row)
	_name = LineEdit.new()
	_name.max_length = SaveService.NAME_LENGTH
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_submitted.connect(func(_text: String) -> void: _save_new())
	_name_row.add_child(_name)
	_name_row.add_child(UiKit.button("ui.saves.save_new", _save_new))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = LIST_HEIGHT
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_list)
	_empty = UiKit.label("ui.saves.none", false)
	_empty.add_theme_color_override(&"font_color", UiKit.INK_SOFT)


func open(how: Mode) -> void:
	mode = how
	_title.text = tr("ui.saves.title_save" if how == Mode.SAVE else "ui.saves.title_load")
	_name_row.visible = how == Mode.SAVE
	_name.text = tr("ui.saves.default_name") % Time.get_datetime_string_from_system(false, true).left(16).replace("T", " ")
	refresh()
	visible = true
	move_to_front()
	if how == Mode.SAVE:
		_name.grab_focus.call_deferred()
		_name.select_all.call_deferred()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Rebuilds the list from the files.
func refresh() -> void:
	_armed = null
	for child: Node in _list.get_children():
		_list.remove_child(child)
		if child != _empty:
			child.queue_free()
	var saves := SaveService.list_saves()
	var shown := 0
	for entry: Dictionary in saves:
		# Saving goes into the player's own saves only (F5 and the autosave keep theirs).
		if mode == Mode.SAVE and entry["kind"] != "slot":
			continue
		_list.add_child(_row(entry))
		shown += 1
	if shown == 0:
		_list.add_child(_empty)


## Saves on the list now.
func row_count() -> int:
	var count := _list.get_child_count()
	return count - 1 if _empty.get_parent() == _list else count


func _notification(what: int) -> void:
	# The "no saves" line is not always on the list.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_empty) and _empty.get_parent() == null:
		_empty.free()


## The name a save shows: the player's, or what it is.
static func title_of(entry: Dictionary) -> String:
	match String(entry.get("kind", "")):
		"quick":
			return TranslationServer.translate("ui.saves.quick")
		"auto":
			return TranslationServer.translate("ui.saves.auto")
	var name := String(entry.get("name", ""))
	if name != "":
		return name
	var slot := String(entry.get("slot", ""))
	return TranslationServer.translate("ui.saves.unnamed") % slot.trim_prefix(SaveService.SLOT_PREFIX)


## "Saved 2026-11-23 14:05 · game time 1:23:05 · Colonization".
static func details_of(entry: Dictionary) -> String:
	var parts := PackedStringArray()
	var saved := String(entry.get("saved_at", ""))
	if saved == "" and entry.has("modified"):
		saved = Time.get_datetime_string_from_unix_time(int(entry["modified"]), true)
	if saved != "":
		parts.append(TranslationServer.translate("ui.saves.saved_at") % saved.left(16).replace("T", " "))
	if entry.has("game_seconds"):
		parts.append(TranslationServer.translate("ui.saves.game_time") % Notifications.game_time(
				int(entry["game_seconds"]) * SimClock.TICKS_PER_SECOND))
	var scenario := String(entry.get("scenario", ""))
	if scenario != "":
		parts.append(TranslationServer.translate("ui.scenario.%s" % scenario))
	return " · ".join(parts)


func _row(entry: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override(&"panel", UiKit.inset_box())
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	frame.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 0)
	row.add_child(text)
	var name := UiKit.label(title_of(entry), false)
	name.add_theme_color_override(&"font_color", UiKit.HEADING)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(name)
	var details := UiKit.label(details_of(entry), false)
	details.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE + 2)
	details.add_theme_color_override(&"font_color", UiKit.INK_SOFT)
	text.add_child(details)
	var path := String(entry["path"])
	if mode == Mode.LOAD:
		row.add_child(UiKit.button("ui.saves.load", func() -> void: load_chosen.emit(path)))
	else:
		var keep := String(entry.get("name", ""))
		var over := Button.new()
		over.text = "ui.saves.overwrite"
		over.pressed.connect(_confirm.bind(over, func() -> void: save_chosen.emit(path, keep)))
		row.add_child(over)
	if entry["kind"] == "slot":
		var delete := Button.new()
		delete.text = "ui.saves.delete"
		delete.pressed.connect(_confirm.bind(delete, func() -> void:
			SaveService.delete_save(path)
			refresh()))
		row.add_child(delete)
	return frame


## First click arms [param button] ("Sure?"), the second does [param action].
func _confirm(button: Button, action: Callable) -> void:
	if _armed == button:
		_armed = null
		action.call()
		return
	if _armed != null and is_instance_valid(_armed):
		_armed.text = _armed.get_meta(&"text", _armed.text)
		_armed.remove_theme_color_override(&"font_color")
	_armed = button
	button.set_meta(&"text", button.text)
	button.text = tr("ui.saves.sure")
	button.add_theme_color_override(&"font_color", UiKit.GOLD)


func _save_new() -> void:
	save_chosen.emit(SaveService.slot_path(SaveService.free_slot()), _name.text)

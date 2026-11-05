class_name Notifications
extends VBoxContainer
## Short messages about what happened (building finished, house upgraded or declining...).
## Each fades out after a while; only the newest few are kept.

const LIFETIME := 7.0
const MAX_SHOWN := 5

## Simulation event type -> localization key of the message (%s = building name).
const MESSAGES: Dictionary[StringName, String] = {
	&"building_completed": "ui.note.building_completed",
	&"house_upgraded": "ui.note.house_upgraded",
	&"house_warning": "ui.note.house_warning",
	&"resident_left": "ui.note.resident_left",
	&"worker_reassigned": "ui.note.worker_reassigned",
}

var province: ProvinceSim


func on_sim_event(event: Dictionary) -> void:
	var type: StringName = event["type"]
	if type == &"command_rejected":
		push(tr("ui.command_error.%s" % event["reason"]))
		return
	if type == &"merchant_arrived":
		push(tr("ui.note.merchant_arrived"))
		return
	if type == &"merchant_left" and int(event.get("earned", 0)) > 0:
		push(tr("ui.note.merchant_left") % int(event["earned"]))
		return
	if not MESSAGES.has(type) or province == null:
		return
	if type == &"building_completed" and province.tick == 0:
		return
	var b := province.buildings.get_building(int(event.get("building", event.get("to", 0))))
	var name := "?"
	if b != null:
		name = tr(b.level_def().name_key() if b.house != null else b.def.name_key())
	push(tr(MESSAGES[type]) % name)


func push(text: String) -> void:
	var l := UiKit.label(text)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	l.add_theme_constant_override(&"outline_size", 6)
	add_child(l)
	var tween := l.create_tween()
	tween.tween_interval(LIFETIME)
	tween.tween_property(l, "modulate:a", 0.0, 1.0)
	tween.tween_callback(l.queue_free)
	while get_child_count() > MAX_SHOWN:
		var old := get_child(0)
		remove_child(old)
		old.queue_free()

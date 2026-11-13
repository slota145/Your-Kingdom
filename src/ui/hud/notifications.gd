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
	# M7 part 2: bandit raids.
	match type:
		&"raid_warning":
			push(tr("ui.note.raid_warning"))
			return
		&"raid_started":
			push(tr("ui.note.raid_started"))
			return
		&"raid_looted":
			push(tr("ui.note.raid_looted") % int(event.get("gold", 0)))
			return
		&"raid_defeated":
			push(tr("ui.note.raid_defeated"))
			return
		&"raid_left":
			push(tr("ui.note.raid_left"))
			return
		&"building_broken":
			push(tr("ui.note.building_broken") % tr("building.%s.name" % event["def"]))
			return
		&"siege_engine_built":
			push(tr("ui.note.siege_engine_built") % tr("unit.%s.name" % event["unit"]))
			return
	if type == &"merchant_arrived":
		push(tr("ui.note.merchant_arrived"))
		return
	if type == &"sea_merchant_arrived":
		push(tr("ui.note.sea_merchant_arrived"))
		return
	if type == &"sea_merchant_left" and int(event.get("earned", 0)) + int(event.get("spent", 0)) > 0:
		push(tr("ui.note.sea_merchant_left") % [int(event["earned"]), int(event["spent"])])
		return
	# M5 part 3: the start from a ship and the cog's voyages.
	if type == &"landing_anchored":
		push(tr("ui.note.landing"))
		return
	if type == &"voyage_departed":
		push(tr("ui.note.voyage_departed"))
		return
	if type == &"voyage_returned":
		push(tr("ui.note.voyage_returned") % int(event.get("gold", 0)))
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
	# Over the town, not on parchment: light text with a dark outline.
	l.add_theme_color_override(&"font_color", UiKit.LIGHT)
	l.add_theme_color_override(&"font_outline_color", Color(0.14, 0.08, 0.05))
	l.add_theme_constant_override(&"outline_size", 6)
	# UI-2 part 1: a dark see-through strip behind each message, so it never runs into the
	# town's or the world map's own labels underneath.
	var strip := StyleBoxFlat.new()
	strip.bg_color = Color(0.14, 0.08, 0.05, 0.62)
	strip.set_corner_radius_all(4)
	strip.content_margin_left = 8.0
	strip.content_margin_right = 8.0
	strip.content_margin_top = 2.0
	strip.content_margin_bottom = 2.0
	l.add_theme_stylebox_override(&"normal", strip)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(l)
	var tween := l.create_tween()
	tween.tween_interval(LIFETIME)
	tween.tween_property(l, "modulate:a", 0.0, 1.0)
	tween.tween_callback(l.queue_free)
	while get_child_count() > MAX_SHOWN:
		var old := get_child(0)
		remove_child(old)
		old.queue_free()

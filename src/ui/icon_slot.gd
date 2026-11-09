class_name IconSlot
extends RefCounted
## A small framed icon for panels (P2 part 3): goods a workshop needs and makes, a house's
## needs. [param state]: NEUTRAL, OK (green frame) or MISSING (red frame, the icon dimmed).

enum State { NEUTRAL, OK, MISSING }

const SIZE := Vector2(36, 36)


static func make(texture: Texture2D, tip: String, state: State = State.NEUTRAL) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.11, 0.07, 0.85)
	style.border_color = [Color(0.55, 0.42, 0.25), Color(0.36, 0.7, 0.3), Color(0.82, 0.25, 0.2)][state]
	style.set_border_width_all(2 if state != State.NEUTRAL else 1)
	style.set_corner_radius_all(2)
	frame.add_theme_stylebox_override(&"panel", style)
	frame.tooltip_text = tip
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = SIZE - Vector2(8, 8)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if state == State.MISSING:
			icon.modulate = Color(0.55, 0.5, 0.5, 0.75)
		frame.add_child(icon)
	return frame


static func good(good_id: StringName, tip: String, state: State = State.NEUTRAL) -> Control:
	return make(ArtPaths.texture("goods/icons/%s.png" % good_id), tip, state)

class_name InputSetup
extends RefCounted
## Default key bindings, registered in code so they live in one place and can later be
## overridden by player settings.

const DEFAULTS: Dictionary[StringName, Array] = {
	&"camera_left": [KEY_A, KEY_LEFT],
	&"camera_right": [KEY_D, KEY_RIGHT],
	&"camera_up": [KEY_W, KEY_UP],
	&"camera_down": [KEY_S, KEY_DOWN],
	&"camera_zoom_1": [KEY_1],
	&"camera_zoom_2": [KEY_2],
	&"camera_zoom_3": [KEY_3],
	&"camera_zoom_4": [KEY_4],
	&"toggle_grid": [KEY_F],
	&"toggle_lower_buildings": [KEY_H],
	&"toggle_gate": [KEY_G],
	&"toggle_pause": [KEY_SPACE],
	&"toggle_mirror_compare": [KEY_M],
}


static func ensure_defaults() -> void:
	for action: StringName in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: int in DEFAULTS[action]:
			var key := InputEventKey.new()
			key.physical_keycode = keycode as Key
			InputMap.action_add_event(action, key)

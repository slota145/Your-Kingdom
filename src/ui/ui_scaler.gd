class_name UiScaler
extends Node
## Makes the interface under [member target] bigger or smaller (Options "display/ui_scale",
## M10 part 3) while the map stays as it is: the target Control is scaled and sized to the
## screen divided by the scale, so everything anchored in it still fits the screen.
## Add it as a child of the full-screen root Control of an interface.

var target: Control


static func attach(root: Control) -> UiScaler:
	var scaler := UiScaler.new()
	scaler.target = root
	root.add_child(scaler)
	return scaler


func _ready() -> void:
	Options.changed.connect(func(key: String) -> void:
		if key == "display/ui_scale" or key == "":
			fit())
	get_viewport().size_changed.connect(fit)
	fit.call_deferred()


func fit() -> void:
	if target == null or not is_instance_valid(target):
		return
	var factor := float(Options.get_value("display/ui_scale"))
	var screen := get_viewport().get_visible_rect().size
	target.set_anchors_preset(Control.PRESET_TOP_LEFT)
	target.position = Vector2.ZERO
	target.scale = Vector2(factor, factor)
	target.size = screen / factor

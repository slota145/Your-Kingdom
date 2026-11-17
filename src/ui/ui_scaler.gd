class_name UiScaler
extends Node
## Makes the interface under [member target] bigger or smaller (Options "display/ui_scale",
## M10 part 3; automatic by default, it grows with the window) while the map stays as it is: the target Control is scaled and sized to the
## screen divided by the scale, so everything anchored in it still fits the screen.
## Add it as a child of the full-screen root Control of an interface.

var target: Control


static func attach(root: Control) -> UiScaler:
	var scaler := UiScaler.new()
	scaler.target = root
	root.add_child(scaler)
	return scaler


func _ready() -> void:
	# Methods, not lambdas: Godot drops these connections when this node is freed (a lambda
	# would be called on a freed node and crash an exported game).
	Options.changed.connect(_on_option_changed)
	get_viewport().size_changed.connect(fit)
	fit.call_deferred()


func _on_option_changed(key: String) -> void:
	if key == "display/ui_scale" or key == "":
		fit()


func fit() -> void:
	if not is_inside_tree() or target == null or not is_instance_valid(target):
		return
	var factor: float = Options.ui_scale()
	var screen := get_viewport().get_visible_rect().size
	target.set_anchors_preset(Control.PRESET_TOP_LEFT)
	target.position = Vector2.ZERO
	target.scale = Vector2(factor, factor)
	target.size = screen / factor

class_name StartPicker
extends PanelContainer
## The second step of "New game" (M8 part 1, owner's survey 2026-11-09): the generated world
## on parchment; the player clicks the province he wants to start in (in Colonization one on
## the coast or an island, the others are dimmed), or lets chance choose. The AI rulers get
## their provinces only after this, as far from him as can be. Drag to move, the wheel to zoom
## (WorldPreview, shared with the live preview of "New game", UI-2 part 3).

signal start_requested(settings: GameSettings)
signal back_requested

var _settings: GameSettings
var _preview: WorldPreview
var _title: Label
var _choice: Label
var _start: Button


func _init() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	add_child(box)
	_title = UiKit.title("ui.new_game.pick_start")
	box.add_child(_title)
	box.add_child(UiKit.label("ui.new_game.pick_hint"))
	_preview = WorldPreview.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(640, 420)
	_preview.picked.connect(_pick)
	box.add_child(_preview)
	_choice = UiKit.label()
	box.add_child(_choice)
	var buttons := HBoxContainer.new()
	buttons.add_child(UiKit.button("ui.new_game.random_start", func() -> void:
		if not _preview.allowed.is_empty():
			_pick(_preview.allowed[randi_range(0, _preview.allowed.size() - 1)])))
	_start = UiKit.button("ui.new_game.start", func() -> void:
		_settings.start = String(_preview.selected)
		start_requested.emit(_settings))
	buttons.add_child(_start)
	buttons.add_child(UiKit.button("ui.new_game.back", func() -> void: back_requested.emit()))
	box.add_child(buttons)


## Shows the world of [param settings] (made now, without owners) to choose the start in.
func open(settings: GameSettings) -> void:
	_settings = settings
	var data: DataRegistry = Data.registry
	var world := WorldGenerator.geography(data, settings)
	_preview.allowed = WorldGenerator.start_choices(data, world, settings)
	_preview.show_world(world, data)
	_pick(&"")
	visible = true


func _pick(id: StringName) -> void:
	_preview.selected = id
	_preview.queue_redraw()
	_start.disabled = id == &""
	if id == &"":
		_choice.text = tr("ui.new_game.no_start")
		return
	var def := Data.registry.get_province(id)
	_choice.text = tr("ui.new_game.start_at") % [tr(def.name_key()),
			tr("ui.new_game.island") if def.island else tr("world.template.%s" % def.template)]

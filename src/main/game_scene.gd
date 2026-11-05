extends Node2D
## The M3 game: one province on the start map (or a loaded save), its view and the UI.
## The player changes the simulation only through commands.
##
## Mouse: left = select / use the tool (drag for roads and fields), right or Esc = cancel the
## tool. Keys: WASD/arrows pan, wheel or 1-4 zoom, Space pause, +/- speed, F grid,
## F5 quick save, F9 quick load, F11 pseudolocalization (UI text-fit check).

const START_MAP := &"riverlands"
const QUICK_SLOT := "quick"
## Screen pixels around a person's feet that count as clicking them.
const PICK_RADIUS := 18.0

var sim: Simulation
var view: ProvinceView
var camera: GameCamera

var _ui: CanvasLayer
var _top: TopBar
var _build: BuildMenu
var _building_panel: BuildingPanel
var _agent_panel: AgentPanel
var _notes: Notifications
var _tool: Dictionary = {}
var _hover: Vector2i = Vector2i(-999, -999)
var _drag_tiles: Array[Vector2i] = []
var _dragging: bool = false
var _follow_id: int = 0
var _time: float = 0.0
var _preview_dirty: bool = false


func _ready() -> void:
	InputSetup.ensure_defaults()
	var load_path := String(Game.start_request.get("load", ""))
	Game.start_request = {}
	var loaded: Simulation = null
	if load_path != "":
		loaded = SaveService.load_simulation(load_path, Data.registry)
	_build_ui()
	_start(loaded if loaded != null else _new_game())
	EventBus.sim_event_emitted.connect(_on_sim_event)


func _exit_tree() -> void:
	Game.stop()


func _new_game() -> Simulation:
	var problems := PackedStringArray()
	var game := Simulation.from_map(Data.registry, Data.registry.get_map(START_MAP), 1, problems)
	for problem: String in problems:
		push_warning("Map: " + problem)
	return game


func _start(simulation: Simulation) -> void:
	sim = simulation
	if view != null:
		view.queue_free()
	if camera != null:
		camera.queue_free()
	view = ProvinceView.new()
	add_child(view)
	move_child(view, 0)
	view.setup(sim.province)
	camera = GameCamera.new()
	add_child(camera)
	var size := sim.province.grid.size
	camera.bounds = Rect2(IsoMath.grid_to_screen(Vector2(0, size.y)).x, 0,
			size.x * IsoMath.HALF_W * 2.0, size.y * IsoMath.HALF_H * 2.0)
	camera.position = IsoMath.grid_to_screen(Vector2(_start_tile()))
	camera.make_current()
	_top.province = sim.province
	_top.clock = sim.clock
	_notes.province = sim.province
	_close_panels()
	_set_tool({})
	Game.start(sim)


func _start_tile() -> Vector2i:
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"town_hall":
			return b.origin + b.def.footprint
	return sim.province.grid.size / 2


# --- UI --------------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	_ui.add_child(root)
	_top = TopBar.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.save_requested.connect(_quick_save)
	_top.load_requested.connect(_quick_load)
	_top.menu_requested.connect(func() -> void: get_tree().change_scene_to_file("res://src/main/main.tscn"))
	root.add_child(_top)
	_build = BuildMenu.new()
	_build.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_build.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build.setup(Data.registry)
	_build.tool_selected.connect(_set_tool)
	root.add_child(_build)
	_building_panel = BuildingPanel.new()
	_building_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_building_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_building_panel.position.y = 64
	_building_panel.closed.connect(_close_panels)
	_building_panel.demolish_requested.connect(func(id: int) -> void:
		_execute(DemolishCommand.new(id))
		_close_panels())
	_building_panel.add_fields_requested.connect(func(id: int) -> void:
		_set_tool({"kind": &"field", "farm": id}))
	root.add_child(_building_panel)
	_agent_panel = AgentPanel.new()
	_agent_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_agent_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_agent_panel.position.y = 64
	_agent_panel.closed.connect(_close_panels)
	_agent_panel.follow_toggled.connect(func(on: bool) -> void:
		_follow_id = _agent_panel.agent_id if on else 0)
	root.add_child(_agent_panel)
	_notes = Notifications.new()
	_notes.position = Vector2(12, 64)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_notes)


func _close_panels() -> void:
	_building_panel.visible = false
	_agent_panel.visible = false
	_agent_panel.set_following(false)
	_follow_id = 0
	_preview_dirty = true


# --- Frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if sim == null:
		return
	_time += delta
	view.update_view(Game.alpha(), camera.visible_world_rect(), _time, delta)
	if _follow_id != 0:
		var agent := sim.province.agents.get_agent(_follow_id)
		if agent == null:
			_close_panels()
		else:
			camera.position = IsoMath.grid_to_screen(agent.prev_pos.lerp(agent.pos, Game.alpha()))
	var tile := ProvinceView.tile_at(get_global_mouse_position())
	if tile != _hover or _preview_dirty:
		_hover = tile
		_preview_dirty = false
		_update_preview()


func _on_sim_event(event: Dictionary) -> void:
	view.on_sim_event(event)
	_notes.on_sim_event(event)
	if not _tool.is_empty() or _building_panel.visible:
		_preview_dirty = true


# --- Tools ---------------------------------------------------------------------------------

func _set_tool(tool: Dictionary) -> void:
	_tool = tool
	_drag_tiles.clear()
	_dragging = false
	if not tool.is_empty():
		_close_panels()
	_update_preview()


func _update_preview() -> void:
	if view == null:
		return
	var tiles: Dictionary[Vector2i, String] = {}
	var kind: StringName = _tool.get("kind", &"")
	match kind:
		&"building":
			var def := sim.data.get_building(_tool["def"])
			var origin := _building_origin(def)
			if def.service_radius > 0:
				_add_range(tiles, def.id)
				var preview := PackedByteArray()
				preview.resize(sim.province.grid.size.x * sim.province.grid.size.y)
				ServiceCoverage.flood(sim.province, origin + def.entrance, def.service_radius, preview)
				_add_flags(tiles, preview, "range")
			var ok := sim.province.placement_error(def, origin) == &""
			for t: Vector2i in def.footprint_tiles(origin):
				tiles[t] = "ok" if ok else "bad"
		&"road":
			for t: Vector2i in _drag_tiles + ([_hover] as Array[Vector2i]):
				tiles[t] = "ok" if sim.province.road_error(t) == &"" else "bad"
		&"field":
			var farm := sim.province.buildings.get_building(int(_tool["farm"]))
			if farm != null:
				var area := Rect2i(farm.origin, farm.def.footprint).grow(farm.def.work_radius)
				for y: int in range(area.position.y, area.end.y):
					for x: int in range(area.position.x, area.end.x):
						if sim.province.field_error(farm.id, Vector2i(x, y)) == &"":
							tiles[Vector2i(x, y)] = "range"
				for t: Vector2i in _drag_tiles + ([_hover] as Array[Vector2i]):
					tiles[t] = "ok" if sim.province.field_error(farm.id, t) == &"" else "bad"
		&"demolish":
			if _demolish_target(_hover) != null:
				tiles[_hover] = "bad"
		_:
			if _building_panel.visible:
				var b := sim.province.buildings.get_building(_building_panel.building_id)
				if b != null and b.def.service_radius > 0:
					_add_range(tiles, b.def.id)
	view.overlay.show_tiles(tiles)


func _add_range(tiles: Dictionary[Vector2i, String], service: StringName) -> void:
	sim.province.coverage.update(sim.province)
	_add_flags(tiles, sim.province.coverage.map_of(service), "range")


func _add_flags(tiles: Dictionary[Vector2i, String], flags: PackedByteArray, art: String) -> void:
	var width := sim.province.grid.size.x
	for i: int in flags.size():
		if flags[i] == 1:
			tiles[Vector2i(i % width, i / width)] = art


## The building's origin so that the cursor tile is its front (entrance) corner.
func _building_origin(def: BuildingDef) -> Vector2i:
	return _hover - def.footprint + Vector2i.ONE


func _demolish_target(tile: Vector2i) -> Command:
	var owner := sim.province.grid.occupant(tile)
	if owner != 0 and sim.province.buildings.has_building(owner):
		return DemolishCommand.new(owner)
	if sim.province.fields.has_field(tile):
		return RemoveFieldCommand.new(tile)
	if sim.province.grid.has_road(tile):
		var road: Array[Vector2i] = [tile]
		return RemoveRoadCommand.new(road)
	return null


func _execute(command: Command) -> StringName:
	var error := sim.execute(command)
	for event: Dictionary in sim.events.drain():
		EventBus.sim_event_emitted.emit(event)
	return error


# --- Input ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		_set_tool({})
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_on_left_press()
		else:
			_on_left_release()
		return
	if event is InputEventMouseMotion and _dragging:
		if _drag_tiles.is_empty() or _drag_tiles.back() != _hover:
			_extend_drag(_hover)
			_update_preview()
		return
	if event.is_action_pressed(&"ui_cancel"):
		if not _tool.is_empty():
			_set_tool({})
		else:
			_close_panels()
	elif event.is_action_pressed(&"toggle_pause"):
		Game.toggle_pause()
	elif event.is_action_pressed(&"game_speed_up"):
		Game.set_speed_index(Game.speed_index + 1)
	elif event.is_action_pressed(&"game_speed_down"):
		Game.set_speed_index(Game.speed_index - 1)
	elif event.is_action_pressed(&"toggle_grid"):
		view.terrain.show_grid = not view.terrain.show_grid
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_F5: _quick_save()
			KEY_F9: _quick_load()
			KEY_F11: _toggle_pseudolocalization()


func _on_left_press() -> void:
	var kind: StringName = _tool.get("kind", &"")
	match kind:
		&"":
			_select_at(get_global_mouse_position())
		&"building":
			var def := sim.data.get_building(_tool["def"])
			_execute(PlaceBuildingCommand.new(def.id, _building_origin(def)))
			_update_preview()
		&"demolish":
			var command := _demolish_target(_hover)
			if command != null:
				_execute(command)
		&"road", &"field":
			_dragging = true
			_drag_tiles = [_hover]
			_update_preview()


func _on_left_release() -> void:
	if not _dragging:
		return
	_dragging = false
	var kind: StringName = _tool.get("kind", &"")
	if kind == &"road":
		var tiles: Array[Vector2i] = []
		for t: Vector2i in _drag_tiles:
			if sim.province.road_error(t) == &"":
				tiles.append(t)
		if not tiles.is_empty():
			_execute(BuildRoadCommand.new(tiles))
	elif kind == &"field":
		for t: Vector2i in _drag_tiles:
			if sim.province.field_error(int(_tool["farm"]), t) == &"":
				_execute(PlaceFieldCommand.new(int(_tool["farm"]), t))
	_drag_tiles.clear()
	_update_preview()


## Adds the tiles from the last dragged tile to [param tile], one grid step at a time.
func _extend_drag(tile: Vector2i) -> void:
	var last: Vector2i = _drag_tiles.back()
	while last != tile:
		var d := tile - last
		if absi(d.x) >= absi(d.y):
			last.x += signi(d.x)
		else:
			last.y += signi(d.y)
		if not _drag_tiles.has(last):
			_drag_tiles.append(last)


func _select_at(world_pos: Vector2) -> void:
	var best: Agent = null
	var best_d := PICK_RADIUS / camera.zoom.x
	for agent: Agent in sim.province.agents.all():
		var feet := IsoMath.grid_to_screen(agent.prev_pos.lerp(agent.pos, Game.alpha()))
		# Click anywhere on the body: up to ~40 px above the feet.
		var body := Vector2(feet.x, clampf(world_pos.y, feet.y - 40.0, feet.y))
		var d := body.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = agent
	_close_panels()
	if best != null:
		_agent_panel.show_agent(sim.province, best.id)
		return
	var owner := sim.province.grid.occupant(ProvinceView.tile_at(world_pos))
	if owner != 0:
		_building_panel.show_building(sim.province, owner)
	_update_preview()


# --- Save, load, checks --------------------------------------------------------------------

func _quick_save() -> void:
	var error := SaveService.save_simulation(SaveService.slot_path(QUICK_SLOT), sim)
	_notes.push(tr("ui.note.saved") if error == OK else tr("ui.note.save_failed"))


func _quick_load() -> void:
	var path := SaveService.slot_path(QUICK_SLOT)
	var loaded: Simulation = SaveService.load_simulation(path, Data.registry) \
			if FileAccess.file_exists(path) else null
	if loaded == null:
		_notes.push(tr("ui.note.load_failed"))
		return
	_start(loaded)
	_notes.push(tr("ui.note.loaded"))


func _toggle_pseudolocalization() -> void:
	TranslationServer.pseudolocalization_enabled = not TranslationServer.pseudolocalization_enabled
	TranslationServer.reload_pseudolocalization()
	EventBus.language_changed.emit(Loc.get_locale())

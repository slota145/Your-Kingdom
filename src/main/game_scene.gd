extends Node2D
## The game: a world of provinces (M6) or a single map (or a loaded save), the viewed
## province's view, the world map and the UI. The player changes the simulation only through
## commands.
##
## Mouse: left = select / use the tool (drag for roads and fields), right or Esc = cancel the
## tool. Keys: WASD/arrows pan, wheel or 1-4 zoom, Space pause, +/- speed, F grid,
## R turns the building being placed, B shows or hides the build bar, T changes its look, M world map, F5 quick save, F9 quick load, F11 pseudolocalization
## (UI text-fit check).

const START_MAP := &"riverlands"

## Map of a new single-province game (main menu, M4b-3).
var _map_id: StringName = START_MAP
## World of a new game (main menu, M6); empty = a single-province game on [member _map_id].
var _world_id: StringName = &""
const QUICK_SLOT := "quick"
## Screen pixels around a person's feet that count as clicking them.
## A person is picked only when clicked close to the body, so clicks near people still
## reach the building behind them (owner feedback 2026-11-05).
const PICK_RADIUS := 9.0
## Seconds between two refreshes of the placement preview caused by the simulation (a
## sped-up town sends events every frame; flooding a service range each time cost frames).
const PREVIEW_REFRESH := 0.25
## How far (world px) from a ship's hull a click still picks it, and how high its sail reaches.
const SHIP_PICK_RADIUS := 40.0
const SHIP_PICK_HEIGHT := 90.0

var sim: Simulation
var view: ProvinceView
var camera: GameCamera

var _ui: CanvasLayer
var _top: TopBar
var _build: BuildMenu
## Shows the build bar again while it is hidden (owner's request 2026-11-07).
var _build_show: Button
var _building_panel: BuildingPanel
var _agent_panel: AgentPanel
var _ship_panel: ShipPanel
var _stocks: KingdomStockWindow
var _routes: RoutesWindow
var _world_map: WorldMapScreen
var _notes: Notifications
var _tool: Dictionary = {}
var _hover: Vector2i = Vector2i(-999, -999)
var _drag_tiles: Array[Vector2i] = []
var _dragging: bool = false
var _follow_id: int = 0
var _time: float = 0.0
var _preview_dirty: bool = false
## Something in the simulation changed since the preview was drawn (refreshed with a delay).
var _preview_stale: bool = false
var _preview_time: float = 0.0
var _turn: PlacementTurn = PlacementTurn.new()


func _ready() -> void:
	InputSetup.ensure_defaults()
	var load_path := String(Game.start_request.get("load", ""))
	_map_id = StringName(String(Game.start_request.get("map", START_MAP)))
	_world_id = StringName(String(Game.start_request.get("world", "")))
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
	var world := Data.registry.get_world(_world_id) if _world_id != &"" else null
	if world != null:
		var in_world := Simulation.from_world(Data.registry, world, 1, problems)
		for problem: String in problems:
			push_warning("World: " + problem)
		if in_world != null:
			return in_world
	var map := Data.registry.get_map(_map_id)
	if map == null:
		map = Data.registry.get_map(START_MAP)
	var game := Simulation.from_map(Data.registry, map, 1, problems)
	for problem: String in problems:
		push_warning("Map: " + problem)
	return game


func _start(simulation: Simulation) -> void:
	sim = simulation
	_show_province()
	_world_map.visible = false
	_top.clock = sim.clock
	_top.treasury = sim.treasury
	_building_panel.treasury = sim.treasury
	_building_panel.sim = sim
	Game.start(sim)


## Builds the view of the viewed province (a new game, a loaded one, or another province
## entered from the world map).
func _show_province() -> void:
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
	_notes.province = sim.province
	_stocks.visible = false
	_routes.visible = false
	_close_panels()
	_set_tool({})


func _start_tile() -> Vector2i:
	if sim.province.landing != null:
		return sim.province.landing.beach   # a start from a ship (M5 part 3)
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
	_top.menu_requested.connect(_back_to_menu)
	_top.stocks_requested.connect(_toggle_stocks)
	_top.world_requested.connect(_toggle_world_map)
	_top.routes_requested.connect(_toggle_routes)
	root.add_child(_top)
	_build = BuildMenu.new()
	_build.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_build.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build.setup(Data.registry)
	_build.tool_selected.connect(_set_tool)
	_build.hide_requested.connect(_show_build_menu.bind(false))
	root.add_child(_build)
	_build_show = UiKit.button("ui.build.show", _show_build_menu.bind(true))
	_build_show.tooltip_text = "ui.build.show_tip"
	_build_show.theme = UiKit.board_theme()
	_build_show.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build_show.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_build_show.visible = false
	root.add_child(_build_show)
	_building_panel = BuildingPanel.new()
	_building_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_building_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_building_panel.position.y = 64
	_building_panel.closed.connect(_close_panels)
	_building_panel.command_requested.connect(func(command: Command) -> void: _execute(command))
	_building_panel.demolish_requested.connect(func(id: int) -> void:
		_execute(DemolishCommand.new(id))
		_close_panels())
	_building_panel.add_fields_requested.connect(func(id: int) -> void:
		_set_tool({"kind": &"field", "farm": id}))
	_building_panel.plant_area_requested.connect(func(id: int) -> void:
		_set_tool({"kind": &"plant", "building": id}))
	_building_panel.stocks_requested.connect(_toggle_stocks)
	root.add_child(_building_panel)
	_stocks = KingdomStockWindow.new()
	_stocks.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_stocks.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stocks.position.y = 64
	_stocks.visible = false
	_stocks.closed.connect(func() -> void: _stocks.visible = false)
	_stocks.command_requested.connect(func(command: Command) -> void: _execute(command))
	root.add_child(_stocks)
	_routes = RoutesWindow.new()
	_routes.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_routes.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_routes.position.y = 64
	_routes.visible = false
	_routes.closed.connect(func() -> void: _routes.visible = false)
	_routes.command_requested.connect(func(command: Command) -> void: _execute(command))
	_agent_panel = AgentPanel.new()
	_agent_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_agent_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_agent_panel.position.y = 64
	_agent_panel.closed.connect(_close_panels)
	_agent_panel.follow_toggled.connect(func(on: bool) -> void:
		_follow_id = _agent_panel.agent_id if on else 0)
	root.add_child(_agent_panel)
	_ship_panel = ShipPanel.new()
	_ship_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_ship_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ship_panel.position.y = 64
	_ship_panel.visible = false
	_ship_panel.closed.connect(_close_panels)
	root.add_child(_ship_panel)
	_world_map = WorldMapScreen.new()
	_world_map.visible = false
	_world_map.closed.connect(_toggle_world_map)
	_world_map.enter_requested.connect(_enter_province)
	_world_map.command_requested.connect(func(command: Command) -> void: _execute(command))
	_world_map.routes_requested.connect(func(from: int) -> void:
		_routes.open(sim, from)
		_routes.move_to_front())
	root.add_child(_world_map)
	# Over the world map too (opened from its panel).
	root.add_child(_routes)
	_notes = Notifications.new()
	_notes.position = Vector2(12, 64)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_notes)


## Notes about expeditions and neutral settlements on the world map (M6 parts 2 and 3).
func _note_world_event(event: Dictionary) -> void:
	var type: StringName = event["type"]
	if type == &"expedition_ready":
		_notes.push(tr("ui.note.expedition_ready"))
		return
	if type != &"expedition_departed" and type != &"expedition_arrived" \
			and type != &"settlement_joined" and type != &"settlement_refused" \
			and type != &"settlement_asks":
		return
	var def := sim.world.def_of(int(event["province"]), sim.data)
	var name := tr(def.name_key()) if def != null else ""
	_notes.push(tr("ui.note.%s" % type) % name)


## Opens or closes the world map (M6). A single-province game has none.
func _toggle_world_map() -> void:
	if _world_map.visible:
		_world_map.visible = false
		return
	if sim.world.is_single():
		_notes.push(tr("ui.note.single_province"))
		return
	_set_tool({})
	_close_panels()
	_world_map.open(sim)


## Enters province [param id] from the world map: it comes in detail, the one viewed so far
## goes to the simplified mode (ARCHITECTURE §7.2).
func _enter_province(id: int) -> void:
	_world_map.visible = false
	if id == sim.viewed_id:
		return
	if _execute(EnterProvinceCommand.new(id)) != &"":
		return
	_show_province()
	var def := sim.world.def_of(id, sim.data)
	_notes.push(tr("ui.note.entered") % (tr(def.name_key()) if def != null else ""))


## Shows or hides the build bar (button, B); hiding it drops the tool in hand.
func _show_build_menu(on: bool) -> void:
	_build.visible = on
	_build_show.visible = not on
	if not on:
		_set_tool({})


## Opens or closes the trade routes window (M6 part 3). A single-province game has none.
func _toggle_routes() -> void:
	if _routes.visible:
		_routes.visible = false
	elif sim.world.is_single():
		_notes.push(tr("ui.note.single_province"))
	else:
		_routes.open(sim)


func _toggle_stocks() -> void:
	if _stocks.visible:
		_stocks.visible = false
	else:
		_stocks.open(sim.province)


func _close_panels() -> void:
	_building_panel.visible = false
	_agent_panel.visible = false
	_ship_panel.visible = false
	_agent_panel.set_following(false)
	_follow_id = 0
	_preview_dirty = true


# --- Frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if sim == null:
		return
	_time += delta
	_build.lock_to(sim.province.first_building)
	view.update_view(Game.alpha(), camera.visible_world_rect(), _time, delta)
	if _follow_id != 0:
		var agent := sim.province.agents.get_agent(_follow_id)
		if agent == null:
			_close_panels()
		else:
			camera.position = IsoMath.grid_to_screen(agent.prev_pos.lerp(agent.pos, Game.alpha()))
	var tile := ProvinceView.tile_at(get_global_mouse_position())
	if tile != _hover or _preview_dirty \
			or (_preview_stale and _time - _preview_time >= PREVIEW_REFRESH):
		_hover = tile
		_preview_dirty = false
		_preview_stale = false
		_preview_time = _time
		_update_preview()


func _on_sim_event(event: Dictionary) -> void:
	_note_world_event(event)
	view.on_sim_event(event)
	_notes.on_sim_event(event)
	if not _tool.is_empty() or _building_panel.visible:
		_preview_stale = true


# --- Tools ---------------------------------------------------------------------------------

func _set_tool(tool: Dictionary) -> void:
	_tool = tool
	_drag_tiles.clear()
	_dragging = false
	_turn.begin()
	_build.show_rotate_hint(tool.get("kind", &"") == &"building")
	if not tool.is_empty():
		_close_panels()
	_update_preview()


func _update_preview() -> void:
	if view == null:
		return
	var tiles: Dictionary[Vector2i, String] = {}
	var kind: StringName = _tool.get("kind", &"")
	var ghost := ""
	var ghost_origin := Vector2i.ZERO
	var ghost_ok := false
	match kind:
		&"building":
			var def := sim.data.get_building(_tool["def"])
			var origin := _building_origin(def)
			var turn := _turn.update(sim.province, def, origin)
			if def.service_radius > 0:
				_add_range(tiles, def.id)
				var preview := PackedByteArray()
				preview.resize(sim.province.grid.size.x * sim.province.grid.size.y)
				ServiceCoverage.flood(sim.province, origin + def.entrance_at(turn), def.service_radius, preview)
				_add_flags(tiles, preview, "range")
			var ok := sim.province.placement_error(def, origin, turn) == &""
			for t: Vector2i in def.footprint_tiles(origin):
				tiles[t] = "ok" if ok else "bad"
			# The tiles in front of the doors: where people will come and go.
			for k: int in def.door_orientations(turn):
				tiles[def.door_front(origin, k)] = "range"
			ghost = BuildingLayer.base_art(def, origin, turn, _turn.look)
			ghost_origin = origin
			ghost_ok = ok
		&"road":
			for t: Vector2i in _drag_tiles + ([_hover] as Array[Vector2i]):
				tiles[t] = "ok" if sim.province.road_error(t) == &"" else "bad"
		&"paving":
			for t: Vector2i in _drag_tiles + ([_hover] as Array[Vector2i]):
				tiles[t] = "ok" if sim.province.paving_error(t) == &"" else "bad"
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
		&"plant":
			var forester := sim.province.buildings.get_building(int(_tool["building"]))
			if forester != null:
				var work := Rect2i(forester.origin, forester.def.footprint).grow(forester.def.work_radius)
				for y: int in range(work.position.y, work.end.y):
					for x: int in range(work.position.x, work.end.x):
						tiles[Vector2i(x, y)] = "range"
				for t: Vector2i in forester.plant_area:
					tiles[t] = "ok"
				for t: Vector2i in _drag_tiles + ([_hover] as Array[Vector2i]):
					tiles[t] = "ok" if work.has_point(t) else "bad"
		&"demolish":
			if _demolish_target(_hover) != null:
				tiles[_hover] = "bad"
		_:
			if _building_panel.visible:
				var b := sim.province.buildings.get_building(_building_panel.building_id)
				if b != null and b.def.service_radius > 0:
					_add_range(tiles, b.def.id)
				if b != null:
					for t: Vector2i in b.plant_area:
						tiles[t] = "ok"
	view.overlay.show_tiles(tiles)
	view.buildings.show_ghost(ghost, ghost_origin, ghost_ok)


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
	if _world_map.visible:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"world_map"):
			_toggle_world_map()
		return
	if event.is_action_pressed(&"world_map"):
		_toggle_world_map()
	elif event.is_action_pressed(&"toggle_build_menu"):
		_show_build_menu(not _build.visible)
	elif event.is_action_pressed(&"ui_cancel"):
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
	elif event.is_action_pressed(&"rotate_building") and _tool.get("kind", &"") == &"building":
		_turn.rotate(sim.data.get_building(_tool["def"]))
		_update_preview()
	elif event.is_action_pressed(&"cycle_look") and _tool.get("kind", &"") == &"building":
		var visual := BuildingVisualDef.for_building(_tool["def"])
		if visual != null and sim.data.get_building(_tool["def"]).is_house():
			_turn.cycle_look(visual.look_count(1))
			_update_preview()
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
			var origin := _building_origin(def)
			var turn := _turn.update(sim.province, def, origin)
			if _execute(PlaceBuildingCommand.new(def.id, origin, false, turn, _turn.look)) == &"":
				_turn.placed()
			_update_preview()
		&"demolish":
			var command := _demolish_target(_hover)
			if command != null:
				_execute(command)
		&"road", &"paving", &"field", &"plant":
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
	elif kind == &"paving":
		var to_pave: Array[Vector2i] = []
		for t: Vector2i in _drag_tiles:
			if sim.province.paving_error(t) == &"":
				to_pave.append(t)
		if not to_pave.is_empty():
			_execute(BuildPavingCommand.new(to_pave))
	elif kind == &"plant":
		var marked: Array[Vector2i] = _drag_tiles.duplicate()
		_execute(SetPlantAreaCommand.new(int(_tool["building"]), marked))
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
	var ship := _ship_at(world_pos)
	if ship != 0:
		_ship_panel.show_ship(sim.province, ship)
		return
	# The building drawn under the cursor wins; the tile under it is only the fallback.
	var owner := view.buildings.building_at(world_pos)
	if owner == 0:
		owner = sim.province.grid.occupant(ProvinceView.tile_at(world_pos))
	if owner != 0:
		_building_panel.show_building(sim.province, owner)
	_update_preview()


## The ship whose hull is under [param world_pos] (M5 part 2), 0 if none.
func _ship_at(world_pos: Vector2) -> int:
	var best := 0
	var best_d := SHIP_PICK_RADIUS
	for ship: ShipUnit in sim.province.ships.values():
		if ship.is_away():
			continue
		var at := IsoMath.grid_to_screen(ship.prev_pos.lerp(ship.pos, Game.alpha()))
		# The hull and the sail above it.
		var body := Vector2(at.x, clampf(world_pos.y, at.y - SHIP_PICK_HEIGHT, at.y))
		var d := body.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = ship.id
	return best


# --- Save, load, checks --------------------------------------------------------------------

func _quick_save() -> void:
	var error := SaveService.save_simulation(SaveService.slot_path(QUICK_SLOT), sim)
	_notes.push(tr("ui.note.saved") if error == OK else tr("ui.note.save_failed"))


## Going back to the menu quick-saves first, so a misclick never loses the game
## ("Load game" in the menu continues from it).
func _back_to_menu() -> void:
	_quick_save()
	get_tree().change_scene_to_file("res://src/main/main.tscn")


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

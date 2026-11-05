class_name ProvinceView
extends Node2D
## Everything of one province on screen (ARCHITECTURE §6): ground, roads and fields, then a
## y-sorted world with trees, buildings, piles and people, then overlays. Reads the
## simulation state every frame and reacts to its events; never changes it.

## Seconds between redraws of growing fields.
const FIELD_REDRAW := 1.0

var province: ProvinceSim
var terrain: TerrainLayer
var overlay: TileOverlay
var world: Node2D
var nature: NatureLayer
var buildings: BuildingLayer
var piles: PileLayer
var agents: AgentViewPool

var _field_timer: float = 0.0
var _buildings_dirty: bool = false


func setup(source: ProvinceSim) -> void:
	province = source
	terrain = TerrainLayer.new()
	# Ground decals in the world (stockpile yards) use z -1: the ground must be below them.
	terrain.z_index = -3
	add_child(terrain)
	terrain.setup_province(province)
	overlay = TileOverlay.new()
	overlay.z_index = -2
	add_child(overlay)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	nature = NatureLayer.new()
	world.add_child(nature)
	nature.setup(province.resources)
	buildings = BuildingLayer.new()
	world.add_child(buildings)
	buildings.setup(province)
	piles = PileLayer.new()
	world.add_child(piles)
	agents = AgentViewPool.new()
	agents.province = province
	world.add_child(agents)


func update_view(alpha: float, visible_rect: Rect2, time: float, delta: float) -> void:
	if _buildings_dirty:
		_buildings_dirty = false
		buildings.refresh_all()
	agents.update_view(province.agents, alpha, visible_rect, time)
	piles.update_view(province.piles)
	buildings.update_view()
	_field_timer += delta
	if _field_timer >= FIELD_REDRAW:
		_field_timer = 0.0
		terrain.refresh_fields()


func on_sim_event(event: Dictionary) -> void:
	nature.on_sim_event(event)
	match event["type"]:
		&"building_placed", &"building_removed", &"building_completed", &"site_opened", \
				&"site_phase_started", &"site_phase_finished", &"house_upgraded", &"building_turned", \
				&"look_changed":
			_buildings_dirty = true
		&"road_changed":
			terrain.refresh_tile(event["tile"])
			_buildings_dirty = true   # a road beside houses can make a corner
		&"field_changed", &"resource_depleted":
			terrain.refresh_tile(event["tile"])
		&"good_harvested":
			terrain.refresh_tile(event["tile"])


## Screen position of the tile under a world-space point.
static func tile_at(world_pos: Vector2) -> Vector2i:
	return IsoMath.tile_at_screen(world_pos)

class_name ProvinceView
extends Node2D
## Everything of one province on screen (ARCHITECTURE §6): ground, roads and fields, then a
## y-sorted world with trees, buildings, piles and people, then overlays. Reads the
## simulation state every frame and reacts to its events; never changes it.

## Seconds between redraws of growing fields.
const FIELD_REDRAW := 1.0
## The merchant's cart stands beside him, to the right of the tile in front of the market.
const CART_OFFSET := Vector2(22.0, 4.0)
## Ground point of the cart image (vehicles/merchant_cart.png).
const CART_FOOT := Vector2(48.0, 64.0)

var province: ProvinceSim
var terrain: TerrainLayer
var overlay: TileOverlay
## The reach of the services already standing (below the cursor overlay): redrawn only when
## the coverage changes, not with every move of the mouse (review fix 2026-11-07).
var range_overlay: TileOverlay
## Tiles waiting for cobbles (review fix 2026-11-07).
var paving_plan: PavingPlanLayer
var world: Node2D
var nature: NatureLayer
var vines: VineLayer
var buildings: BuildingLayer
var piles: PileLayer
var agents: AgentViewPool
## Ships and ships on slipways (M5), fish shoals on the water.
var ships: ShipLayer
var shoals: ShoalLayer
## Quays on the sea and harbour buildings' strips over the water, as one mass (N1).
var quays: QuayLayer
## Bridges over rivers, fords and lakes (B1); their railings stand in the y-sorted world.
var bridges: BridgeLayer
## Cargo cranes: the jib, the rope and the load over the world (N1 part 2).
var cranes: CraneLayer
## Palisades, stone walls and stairs (M7 part 2).
var forts: FortLayer
## Life bars, arrows, selection (over the world) and the fallen (in it).
var troops: TroopsLayer
var corpses: CorpseLayer
## Rams and ladders (M7 part 2).
var siege: SiegeLayer
## Animal pens: fences, gates and the animals walking inside (Z1).
var pens: PenLayer
## The travelling merchant's cart while he trades (M4b-2).
var cart: Sprite2D

var _field_timer: float = 0.0
var _buildings_dirty: bool = false


func setup(source: ProvinceSim) -> void:
	province = source
	terrain = TerrainLayer.new()
	# Ground decals in the world (stockpile yards) use z -1: the ground must be below them.
	terrain.z_index = -3
	add_child(terrain)
	terrain.setup_province(province)
	range_overlay = TileOverlay.new()
	range_overlay.z_index = -2
	add_child(range_overlay)
	overlay = TileOverlay.new()
	overlay.z_index = -2
	add_child(overlay)
	shoals = ShoalLayer.new()
	shoals.z_index = -1
	add_child(shoals)
	shoals.setup(province)
	paving_plan = PavingPlanLayer.new()
	paving_plan.z_index = -2
	add_child(paving_plan)
	paving_plan.setup(province)
	quays = QuayLayer.new()
	quays.z_index = -1
	add_child(quays)
	quays.setup(province)
	bridges = BridgeLayer.new()
	bridges.z_index = -1
	add_child(bridges)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	bridges.rails.y_sort_enabled = true
	world.add_child(bridges.rails)
	bridges.setup(province)
	nature = NatureLayer.new()
	world.add_child(nature)
	nature.setup(province.resources)
	vines = VineLayer.new()
	world.add_child(vines)
	vines.setup(province)
	buildings = BuildingLayer.new()
	world.add_child(buildings)
	buildings.setup(province)
	piles = PileLayer.new()
	world.add_child(piles)
	pens = PenLayer.new()
	world.add_child(pens)
	pens.setup(province)
	forts = FortLayer.new()
	world.add_child(forts)
	forts.setup(province)
	agents = AgentViewPool.new()
	agents.province = province
	world.add_child(agents)
	agents.warm_up(province)
	agents.forts = forts
	siege = SiegeLayer.new()
	world.add_child(siege)
	siege.setup(province)
	corpses = CorpseLayer.new()
	world.add_child(corpses)
	corpses.setup(province)
	troops = TroopsLayer.new()
	add_child(troops)
	troops.setup(province, agents)
	ships = ShipLayer.new()
	world.add_child(ships)
	ships.setup(province)
	cart = Sprite2D.new()
	cart.centered = false
	cart.offset = -CART_FOOT
	cart.texture = ArtPaths.texture("vehicles/merchant_cart.png")
	cart.visible = false
	world.add_child(cart)
	cranes = CraneLayer.new()
	cranes.z_index = 1
	add_child(cranes)
	cranes.setup(province)


func update_view(alpha: float, visible_rect: Rect2, time: float, delta: float) -> void:
	if _buildings_dirty:
		_buildings_dirty = false
		buildings.refresh_all()
	agents.update_view(province.agents, alpha, visible_rect, time)
	troops.update_view(alpha, delta)
	siege.update_view(alpha, time)
	corpses.update_view(delta)
	ships.update_view(alpha, time)
	shoals.update_view(time)
	cranes.update_view()
	piles.update_view(province.piles)
	piles.update_yards(province.buildings)
	pens.update_view(delta)
	buildings.update_view()
	forts.update_view()
	var merchant := province.merchant
	cart.visible = merchant.is_trading()
	if cart.visible:
		cart.position = IsoMath.tile_center_screen(merchant.stand) + CART_OFFSET
	_field_timer += delta
	if _field_timer >= FIELD_REDRAW:
		_field_timer = 0.0
		terrain.refresh_fields()
		vines.refresh()


func on_sim_event(event: Dictionary) -> void:
	nature.on_sim_event(event)
	paving_plan.on_sim_event(event)
	forts.on_sim_event(event)
	corpses.on_sim_event(event)
	pens.on_sim_event(event)
	match event["type"]:
		&"building_placed", &"building_removed", &"building_completed", &"site_opened", \
				&"site_phase_started", &"site_phase_finished", &"house_upgraded", &"building_turned", \
				&"look_changed", &"ship_build_closed":
			_buildings_dirty = true
			quays.refresh()
		&"quay_changed", &"quay_ordered", &"paving_closed":
			quays.refresh()
			bridges.refresh()
		&"bridge_changed", &"bridge_ordered":
			bridges.refresh()
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

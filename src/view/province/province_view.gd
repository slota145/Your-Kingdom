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
var world: Node2D
var nature: NatureLayer
var buildings: BuildingLayer
var piles: PileLayer
var agents: AgentViewPool
## Ships and ships on slipways (M5), fish shoals on the water.
var ships: ShipLayer
var shoals: ShoalLayer
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
	overlay = TileOverlay.new()
	overlay.z_index = -2
	add_child(overlay)
	shoals = ShoalLayer.new()
	shoals.z_index = -1
	add_child(shoals)
	shoals.setup(province)
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
	ships = ShipLayer.new()
	world.add_child(ships)
	ships.setup(province)
	cart = Sprite2D.new()
	cart.centered = false
	cart.offset = -CART_FOOT
	cart.texture = ArtPaths.texture("vehicles/merchant_cart.png")
	cart.visible = false
	world.add_child(cart)


func update_view(alpha: float, visible_rect: Rect2, time: float, delta: float) -> void:
	if _buildings_dirty:
		_buildings_dirty = false
		buildings.refresh_all()
	agents.update_view(province.agents, alpha, visible_rect, time)
	ships.update_view(alpha, time)
	shoals.update_view(time)
	piles.update_view(province.piles)
	piles.update_yards(province.buildings)
	buildings.update_view()
	var merchant := province.merchant
	cart.visible = merchant.is_trading()
	if cart.visible:
		cart.position = IsoMath.tile_center_screen(merchant.stand) + CART_OFFSET
	_field_timer += delta
	if _field_timer >= FIELD_REDRAW:
		_field_timer = 0.0
		terrain.refresh_fields()


func on_sim_event(event: Dictionary) -> void:
	nature.on_sim_event(event)
	match event["type"]:
		&"building_placed", &"building_removed", &"building_completed", &"site_opened", \
				&"site_phase_started", &"site_phase_finished", &"house_upgraded", &"building_turned", \
				&"look_changed", &"ship_build_closed":
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

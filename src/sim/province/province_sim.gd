class_name ProvinceSim
extends RefCounted
## Detailed simulation of one province (ARCHITECTURE §4.1): map, buildings, people, goods.
##
## Storages are buildings with a stockpile or ground piles; both are addressed by entity id.
## Systems run in the fixed order of ARCHITECTURE §4.2 from [method step].

var data: DataRegistry
var events: SimEvents
var ids: EntityIds
## Current tick, mirrored from the SimClock before each step.
var tick: int = 0

var grid: TileGrid
var nav: NavGrid
## Road tiles only, for horse wagons (M4b-3): every other tile is solid.
var road_nav: NavGrid
## Water for ships (M5): boats sail on shallow and deep sea, cogs on deep sea and fairways.
var boat_nav: NavGrid
var cog_nav: NavGrid
## Shallow tiles dredged from a berth to deep water (Ships.fairway_tiles); derived, not saved.
var fairway: Dictionary[Vector2i, bool] = {}
## Ships on the water by entity id (M5).
var ships: Dictionary[int, ShipUnit] = {}
## Ships on shipyard slipways by entity id (M5).
var ship_builds: Dictionary[int, ShipBuild] = {}
var resources: ResourceField
var buildings: BuildingStore = BuildingStore.new()
var agents: AgentStore = AgentStore.new()
var piles: Dictionary[int, GroundPile] = {}
## Construction and upgrade sites by entity id.
var sites: Dictionary[int, ConstructionSite] = {}
## Road tiles waiting for cobbles, by entity id (M4b-3).
var paving: Dictionary[int, PavingSite] = {}
var fields: FieldStore = FieldStore.new()
## Wild deer and boar on the forest and meadows (E2 part 2).
var wild: WildHerds = WildHerds.new()
## Palisades, stone walls and stairs; gatehouse and tower tiles (M7 part 2).
var walls: Walls
## Gatehouse passage tiles -> gatehouse id (M7 part 2). Not saved: rebuilt from buildings.
var passages: Dictionary[Vector2i, int] = {}
## Where fighters walk: the wall-walk, the enemy's ground, ways between them (M7 part 2).
var mil: MilitaryNav
## Bandit raids on this province (M7 part 2).
var raids: Raids = Raids.new()
## Arrows in flight (M7 part 2).
var arrows: Array[Troops.Arrow] = []
## The side whose walls and gates these are (CombatState.PLAYER, or TOWN in a neutral
## settlement); set by Simulation from the province's owner, not saved (M7 part 3).
var home_faction: int = CombatState.PLAYER
## Soldiers who marched off the map since the last tick: {army, unit, hp} (Simulation adds
## them to their army at once, so this is never saved).
var marched: Array[Dictionary] = []
var jobs: JobBoard = JobBoard.new()
var paths: PathRequestQueue = PathRequestQueue.new()
## The kingdom's gold. Owned by the Simulation (it is global), shared here for convenience.
var treasury: Treasury = Treasury.new()
## Developer mode (ROADMAP E4 part 1): every construction and paving site is done at once
## without materials, and the start protection never ends. Set by the Simulation on the
## player's provinces (Simulation.bind_dev_mode); not saved here.
var dev_mode: bool = false
## The owner's research (E4 part 2): what may be built and how much better some buildings
## work. Set by the Simulation (Simulation.research_of); not saved here.
var research: ResearchState = ResearchState.opened()
## Derived from buildings and the map; not saved.
var coverage: ServiceCoverage = ServiceCoverage.new()

const _NO_BUILDINGS: Array[BuildingState] = []
var _goods_index_version: int = -1
var _storage_buildings: Array[BuildingState] = []
var _market_buildings: Array[BuildingState] = []
var _yard_buildings: Dictionary[StringName, Array] = {}
## Building def id -> goods its yard (or herd) can hold.
var _yard_goods_of: Dictionary[StringName, Array] = {}
## Bumped whenever a ground pile is added or removed (index for _pile_at).
var _piles_version: int = 0
var _pile_index_version: int = -1
var _pile_index: Dictionary[Vector2i, int] = {}
## The travelling merchant (M4b-2).
var merchant: Merchant = Merchant.new()
## The sea merchant with his foreign cog (M5 part 2).
var sea_merchant: SeaMerchant = SeaMerchant.new()
## The start from a ship while it lasts (M5 part 3); null otherwise.
var landing: Landing = null
## An expedition of settlers getting ready to set out from here (M6 part 2); null otherwise.
var departure: Departure = null
## Wagons of trade routes being loaded or unloaded here, by route id (M6 part 3).
var route_wagons: Dictionary[int, RouteWagon] = {}
## Until a building of this id is placed, nothing else may be (the pioneer camp on a map that
## starts by ship, M5 part 3); empty = anything.
var first_building: StringName = &""
## The province's rare resource (M6 part 3: vines let vineyards be built), from its ProvinceDef.
var rare_resource: StringName = &""
## The province's traits (ROADMAP E3: rich_stone lets a stone pit be built), from its ProvinceDef
## (ProvinceDef.traits_of: rich_iron comes with iron ore as the rare resource). Not saved: data,
## not state; Simulation.from_dict sets them again from the world's ProvinceDefs.
var traits: Array[StringName] = []
## Start protection (review fix 2026-11-07): until this tick residents neither lose happiness
## nor move out, and a short supply raises no warning (0: no protection; old saves).
var grace_until: int = 0
## Goods made and used per minute (statistics for the player, M4b-2); not saved.
var ledger: GoodsLedger = GoodsLedger.new()
## How fast each building works while viewed: the calibration of the simplified mode (M6).
var production: ProductionLog = ProductionLog.new()
## Workers per building counted by the simplified mode (ProvinceAbstract.staff); empty while
## the province is viewed (people are its workers then). Not saved.
var abstract_staff: Dictionary[int, int] = {}
## Where newcomers enter the province.
var entry_tile: Vector2i = Vector2i.ZERO
## Units of a good workshops leave in the province for construction and households
## (GDD §4.1: the sawmill must not eat all the wood). Set by the player, 0 = none.
var keep_for_building: Dictionary[StringName, int] = {}
## Terrain definitions by TileGrid index.
var terrains: Array[TerrainDef] = []

## The building that makes a province the seat of a town (M6 part 2).
const SEAT := &"town_hall"
## Vine soil (M6 part 3): laid in provinces with vines; vines grow faster there.
const VINES := &"vines"
const VINE_SOIL := &"vine_soil"
const VINE_PATCHES := 5
const VINE_RADIUS := 4
const VINE_GAP := 18
## Ore veins (M7): how many rock tiles become veins, and how far apart (Chebyshev).
const ORE_VEIN := &"ore_vein"
const ROCK := &"rock"
const IRON_ORE := &"iron_ore"
const ORE_VEINS := 6
const ORE_GAP := 4
const ORE_VEINS_RICH := 24
const ORE_GAP_RICH := 3
var _seat_version: int = -1
var _seat: int = 0

## Walking cost on a dirt road: +50% speed (GDD §5.2).
const ROAD_COST := 0.67
## Walking cost on a paved road: +80% speed (GDD §5.2, M4b-3).
const PAVED_COST := 0.55
## Walking cost on a field tile (ARCHITECTURE §5.3).
const FIELD_COST := 1.2
## Walking cost of a pen tile (Z1): fenced, so paths go round it unless they end inside.
const PEN_COST := 6.0
## Due pens (_place_due_pens) were looked for since this province was made or loaded.
var _due_pens_checked: bool = false
## How often young trees are checked for growing up (1 s).
const GROW_CHECK_TICKS := 10
## How long the start protection lasts (owner's survey 2026-11-07: 15 minutes, in a new game
## and in each newly settled province).
const GRACE_SECONDS := 900.0


func _init(registry: DataRegistry, size: Vector2i, event_queue: SimEvents, entity_ids: EntityIds) -> void:
	data = registry
	events = event_queue
	ids = entity_ids
	grid = TileGrid.new(size)
	nav = NavGrid.new(size)
	road_nav = NavGrid.new(size)
	road_nav.set_solid_rect(Rect2i(Vector2i.ZERO, size), true)
	boat_nav = NavGrid.new(size)
	boat_nav.set_solid_rect(Rect2i(Vector2i.ZERO, size), true)
	cog_nav = NavGrid.new(size)
	cog_nav.set_solid_rect(Rect2i(Vector2i.ZERO, size), true)
	resources = ResourceField.new(size)
	walls = Walls.new(size)
	mil = MilitaryNav.new(size)
	terrains = registry.terrains_by_index()
	coverage.setup(size)


func step() -> void:
	if dev_mode:
		finish_works_now()
	jobs.update(self)
	for agent: Agent in agents.all():
		# Someone walking to the next step has nothing to decide (TaskRunner.tick_agent would
		# return at once): skipped here without the call (M4b-3).
		if agent.task != null and (agent.path_state == Agent.PathState.MOVING \
				or agent.path_state == Agent.PathState.WAITING):
			continue
		if agent.combat != null and agent.combat.commanded:
			continue   # under orders: Troops drives him (M7 part 2)
		if agents.has_agent(agent.id):
			TaskRunner.tick_agent(self, agent)
	Movement.serve_paths(self)
	Movement.move_all(self)
	Troops.update(self)
	Ships.move_all(self)
	TroopTransport.update(self)
	_remove_empty_piles()
	if tick % GROW_CHECK_TICKS == 0:
		if not paving.is_empty():
			_top_up_paving()
		_grow_saplings()
		_regrow_nodes()
		if landing != null:
			landing.update(self)
			if landing.is_over():
				landing = null
		if departure != null:
			departure.update(self)
		for wagon: RouteWagon in route_wagons.values():
			wagon.update(self)
		Ships.update(self)
		_breed_herds()
		wild.update(self)
		_update_markets()
		merchant.update(self)
		sea_merchant.update(self)
		Voyage.update_all(self)
		Harbour.update(self)
		jobs.trim_yard_requests(self)
	Population.update(self)
	Barracks.update(self)
	SiegeWorks.update(self)


# --- Map -----------------------------------------------------------------------------------

func terrain_at(tile: Vector2i) -> TerrainDef:
	var index := grid.terrain(tile)
	return terrains[index] if index < terrains.size() else null


func is_tile_solid(tile: Vector2i) -> bool:
	if grid.is_blocked(tile) or resources.blocks_movement(tile):
		return true
	if not walls.is_empty() and walls.blocks_ground(tile):
		return true
	if not passages.is_empty() and passages.has(tile):
		return false   # the way through a gatehouse (M7 part 2)
	var terrain := terrain_at(tile)
	if terrain != null and not terrain.walkable and not grid.has_quay(tile) and not grid.has_bridge(tile):
		return true
	# A whole building is solid, its entrances too: people step onto an entrance only from
	# the tile in front of its door (find_path), never across a corner of the building.
	return grid.occupant(tile) != 0


## Starts the start protection at [param now] (a new game, a newly settled province).
func start_grace(now: int) -> void:
	grace_until = now + SimClock.seconds_to_ticks(GRACE_SECONDS)


func in_grace() -> bool:
	return dev_mode or tick < grace_until


## Seconds of start protection left (0 when over).
func grace_seconds_left() -> float:
	return maxf(0.0, (grace_until - tick) / float(SimClock.TICKS_PER_SECOND))


## Changes whenever a planned path may have become impossible: a tile turned solid or free
## for people or for wagons (Movement checks the rest of its path then).
func blocking_version() -> int:
	return nav.solid_version + road_nav.solid_version


func refresh_tile(tile: Vector2i) -> void:
	var nav_solid := is_tile_solid(tile)
	var version := nav.version
	nav.set_solid(tile, nav_solid)
	var cost := 1.0
	var passage := not passages.is_empty() and passages.has(tile)
	if passage:
		cost = PAVED_COST
	elif grid.has_road(tile):
		cost = PAVED_COST if grid.is_paved(tile) else ROAD_COST
	elif grid.has_quay(tile):
		cost = PAVED_COST if grid.quay(tile) == TileGrid.STONE_QUAY else ROAD_COST
	elif grid.has_bridge(tile):
		cost = PAVED_COST if grid.bridge(tile) == TileGrid.STONE_BRIDGE else ROAD_COST
	elif fields.has_field(tile):
		# People go round a fenced pen when they can (Z1); its keeper walks in.
		cost = PEN_COST if is_pen(tile) else FIELD_COST
	else:
		var terrain := terrain_at(tile)
		if terrain != null:
			cost = terrain.move_cost
	# Service reach counts roads, fields and terrain but not trees (M4b-3): cutting and
	# planting near the town does not make every service measure its reach again.
	coverage.set_tile(tile, cost, nav_solid, nav.version != version)
	if not grid.has_road(tile) and not fields.has_field(tile) and not grid.has_bridge(tile):
		# Trees are walkable but slow people down like the forest floor (M4b-2).
		var node := resources.def_at(tile)
		if node != null and node.move_cost > cost and not resources.is_depleted(tile):
			cost = node.move_cost
	if not is_equal_approx(nav.get_cost(tile), cost):
		nav.set_cost(tile, cost)
	mil.refresh_tile(self, tile, nav_solid, cost)
	# A bridge is a road for wagons too (B1).
	var on_road := (grid.has_road(tile) or passage or grid.has_bridge(tile)) and not nav_solid
	road_nav.set_solid(tile, not on_road)
	if on_road and not is_equal_approx(road_nav.get_cost(tile), cost):
		road_nav.set_cost(tile, cost)
	var depth := sail_depth(tile)
	var open_water := depth > 0 and grid.occupant(tile) == 0 and not grid.is_blocked(tile) \
			and (paving.is_empty() or paving_site_at(tile) == 0)
	boat_nav.set_solid(tile, not open_water)
	cog_nav.set_solid(tile, not (open_water and (depth >= 2 or fairway.has(tile))))


## Which ships sail on [param tile] (TerrainDef.sail_depth): 0 none, 1 boats, 2 boats and cogs.
## A quay (N1) is no water for ships.
func sail_depth(tile: Vector2i) -> int:
	if grid.has_quay(tile):
		return 0
	var terrain := terrain_at(tile)
	return terrain.sail_depth if terrain != null else 0


## Recomputes the fairways after a building with a berth came or went; tiles that changed
## update the cog NavGrid.
func refresh_fairways() -> void:
	var fresh := Ships.fairway_tiles(self)
	var changed: Array[Vector2i] = []
	for tile: Vector2i in fresh:
		if not fairway.has(tile):
			changed.append(tile)
	for tile: Vector2i in fairway:
		if not fresh.has(tile):
			changed.append(tile)
	fairway = fresh
	for tile: Vector2i in changed:
		refresh_tile(tile)


## Terrain from a map image (pixel colour -> TerrainDef.map_color), trees on forest, and the
## start layout: finished buildings, residents and goods. Returns colours not matching any
## terrain (they become the default terrain).
##
## A province of the world (M6 part 2) plays a variant of the map: [param mirrored] swaps x
## and y (on screen: left and right), [param richness] (1-3, GDD §2.1) thins out (1) or
## enriches (3) its forests, rocks and shoals, and [param settled] leaves the start layout
## out (settlers bring their own, Expedition). A province with vines as its rare resource
## ([param rare], M6 part 3) gets patches of vine soil (the only ground a vineyard tends).
## [param own_traits] are the province's traits (ProvinceDef.traits, ROADMAP E3).
func load_map(map: MapDef, mirrored: bool = false, richness: int = 2, settled: bool = false,
		rare: StringName = &"", own_traits: Array[StringName] = []) -> PackedStringArray:
	var problems := _load_terrain(map, mirrored)
	_apply_richness(richness)
	rare_resource = rare
	traits = ProvinceDef.traits_of(own_traits, rare)
	lay_ore_veins()
	if rare == VINES:
		_lay_vine_soil()
	entry_tile = _variant_tile(map.entry_tile, mirrored)
	rebuild_nav()
	if settled:
		first_building = map.first_building if map.first_building != &"" else &"pioneer_camp"
		return problems
	treasury.gold = map.start_gold
	if map.start_by_ship:
		first_building = map.first_building
		landing = Landing.begin(self, map, mirrored)
		return problems
	for start: StartBuildingDef in map.start_buildings:
		var def := data.get_building(start.building)
		var origin := _variant_tile(start.origin, mirrored)
		var orientation := 1 if mirrored else 0
		var error := placement_error(def, origin, orientation)
		if error != &"":
			problems.append("start %s at %s: %s" % [start.building, origin, error])
			continue
		var building := add_building(def, origin, true, orientation)
		if building.house != null:
			building.house.residents = mini(start.residents, building.capacity())
		var store := building.stock if building.stock != null else building.supply
		if store != null:
			for good: StringName in start.goods:
				store.add(good, start.goods[good])
	return problems


## Iron ore veins in the rocks (M7, owner's decision 2026-11-07: small veins on every map,
## many in the province with iron ore): rock tiles chosen by a fixed hash of the tile (a
## province always gets the same ones), at least ORE_GAP tiles apart, turn into ore veins.
func lay_ore_veins() -> void:
	var vein := data.get_resource_node(ORE_VEIN)
	if vein == null:
		return
	var rocks: Array[Vector2i] = []
	for tile: Vector2i in resources.tiles_with_nodes():
		var def := resources.def_at(tile)
		if def != null and def.id == ROCK:
			rocks.append(tile)
	for tile: Vector2i in choose_ore_veins(rocks, rare_resource == IRON_ORE):
		resources.place(tile, vein)


## The rock tiles of [param rocks] that become ore veins (also used by the save migration to
## v18, so an older game gets the same veins as a new one).
static func choose_ore_veins(rocks: Array[Vector2i], rich: bool) -> Array[Vector2i]:
	# At most a third of the rocks: the quarry keeps its stone.
	var wanted := mini(ORE_VEINS_RICH if rich else ORE_VEINS, maxi(rocks.size() / 3, 1))
	var gap := ORE_GAP_RICH if rich else ORE_GAP
	var sorted := rocks.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ha := _vein_hash(a)
		var hb := _vein_hash(b)
		return ha < hb or (ha == hb and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	var chosen: Array[Vector2i] = []
	for tile: Vector2i in sorted:
		if chosen.size() >= wanted:
			break
		var near := false
		for other: Vector2i in chosen:
			if maxi(absi(other.x - tile.x), absi(other.y - tile.y)) < gap:
				near = true
				break
		if not near:
			chosen.append(tile)
	return chosen


static func _vein_hash(tile: Vector2i) -> int:
	return ((tile.x * 73856093) ^ (tile.y * 19349663)) & 0x7fffffff


## Patches of vine soil on open grass and meadow (M6 part 3): up to VINE_PATCHES round
## patches of radius VINE_RADIUS, on the free spots chosen by a fixed hash of the tile (a
## province always gets the same ones), at least VINE_GAP tiles apart and off the map edge.
func _lay_vine_soil() -> void:
	var soil: TerrainDef = data.get_terrain(VINE_SOIL)
	if soil == null:
		return
	var candidates: Array[Vector2i] = []
	var step := 6
	for y: int in range(VINE_RADIUS + 4, grid.size.y - VINE_RADIUS - 4, step):
		for x: int in range(VINE_RADIUS + 4, grid.size.x - VINE_RADIUS - 4, step):
			if _vine_spot_free(Vector2i(x, y)):
				candidates.append(Vector2i(x, y))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ha := (a.x * 73856093) ^ (a.y * 19349663)
		var hb := (b.x * 73856093) ^ (b.y * 19349663)
		return ha < hb if ha != hb else a < b)
	var chosen: Array[Vector2i] = []
	for centre: Vector2i in candidates:
		if chosen.size() >= VINE_PATCHES:
			break
		var near := false
		for other: Vector2i in chosen:
			if (other - centre).length_squared() < VINE_GAP * VINE_GAP:
				near = true
		if near:
			continue
		chosen.append(centre)
		for y: int in range(centre.y - VINE_RADIUS, centre.y + VINE_RADIUS + 1):
			for x: int in range(centre.x - VINE_RADIUS, centre.x + VINE_RADIUS + 1):
				var tile := Vector2i(x, y)
				if (tile - centre).length_squared() <= VINE_RADIUS * VINE_RADIUS + 1 \
						and _open_ground(tile):
					grid.set_terrain(tile, soil.index)


func _vine_spot_free(centre: Vector2i) -> bool:
	for y: int in range(centre.y - VINE_RADIUS - 2, centre.y + VINE_RADIUS + 3):
		for x: int in range(centre.x - VINE_RADIUS - 2, centre.x + VINE_RADIUS + 3):
			if not _open_ground(Vector2i(x, y)):
				return false
	return true


## Grass or meadow without a tree, rock or building.
func _open_ground(tile: Vector2i) -> bool:
	if not grid.is_inside(tile) or grid.occupant(tile) != 0 or resources.has_node(tile):
		return false
	var terrain := terrain_at(tile)
	return terrain != null and (terrain.id == &"grass" or terrain.id == &"meadow")


## [param tile] of the map in its variant (mirrored: x and y swapped).
static func _variant_tile(tile: Vector2i, mirrored: bool) -> Vector2i:
	return Vector2i(tile.y, tile.x) if mirrored and tile != Agent.NO_TILE else tile


## Poor land (richness 1) loses every third node, rich land (3) has half as much again in each
## (decided by the tile, so a variant always looks the same).
func _apply_richness(richness: int) -> void:
	if richness == 2:
		return
	for tile: Vector2i in resources.tiles_with_nodes():
		if richness <= 1 and (tile.x * 7 + tile.y * 13) % 3 == 0:
			resources.clear(tile)
		elif richness >= 3:
			resources.set_amount(tile, ceili(resources.amount(tile) * 1.5))


func _load_terrain(map: MapDef, mirrored: bool) -> PackedStringArray:
	var problems := PackedStringArray()
	var image := map.terrain_image
	var by_color: Dictionary[int, TerrainDef] = {}
	var with_node: Dictionary[int, TerrainDef] = {}
	for terrain: TerrainDef in terrains:
		if terrain != null:
			by_color[terrain.map_color.to_rgba32() | 0xff] = terrain
			if terrain.extra_node != &"":
				by_color[terrain.extra_map_color.to_rgba32() | 0xff] = terrain
				with_node[terrain.extra_map_color.to_rgba32() | 0xff] = terrain
	for y: int in image.get_height():
		for x: int in image.get_width():
			var tile := _variant_tile(Vector2i(x, y), mirrored)
			if not grid.is_inside(tile):
				continue
			var color := image.get_pixel(x, y).to_rgba32() | 0xff
			var terrain: TerrainDef = by_color.get(color)
			if terrain == null:
				problems.append("unknown colour %08x at %s" % [color, tile])
				continue
			grid.set_terrain(tile, terrain.index)
			if with_node.has(color):
				resources.place(tile, data.get_resource_node(terrain.extra_node))
			elif terrain.resource_node != &"":
				resources.place(tile, data.get_resource_node(terrain.resource_node))
	for spot: Vector2i in map.resource_spots:
		var node := data.get_resource_node(map.resource_spots[spot])
		var tile := _variant_tile(spot, mirrored)
		if node == null or not grid.is_inside(tile):
			problems.append("resource spot %s at %s" % [map.resource_spots[spot], tile])
			continue
		resources.place(tile, node)
	return problems

func rebuild_nav() -> void:
	for y: int in grid.size.y:
		for x: int in grid.size.x:
			refresh_tile(Vector2i(x, y))


## A walkable neighbour of [param node] closest to [param from], or Agent.NO_TILE.
## Orthogonal neighbours win ties, then the IsoMath direction order.
func approach_tile(node: Vector2i, from: Vector2i) -> Vector2i:
	var best := Agent.NO_TILE
	var best_d := 1 << 30
	for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]:
		var t := node + step
		if not nav.is_walkable(t):
			continue
		var d := (t - from).length_squared()
		if d < best_d:
			best_d = d
			best = t
	return best


# --- Buildings -----------------------------------------------------------------------------

## &"" when the building fits at [param origin] turned to [param orientation], otherwise
## the reason.
func placement_error(def: BuildingDef, origin: Vector2i, orientation: int = 0) -> StringName:
	if def == null:
		return &"unknown_building"
	if def.needs_rare != &"" and rare_resource != def.needs_rare:
		return StringName("needs_%s" % def.needs_rare)
	if def.needs_trait != &"" and not traits.has(def.needs_trait):
		return StringName("needs_%s" % def.needs_trait)
	if orientation < 0 or orientation >= def.orientation_count():
		return &"bad_orientation"
	if first_building != &"" and def.id != first_building:
		return &"build_camp_first"
	if def.unique:
		for other: BuildingState in buildings.all():
			if other.def == def:
				return &"only_one"
	var on_water := def.water_tiles_at(origin, orientation)
	var stilts := stilt_tiles(def, origin)
	if def.stilts_row:
		var error := _stilts_error(def, origin, stilts)
		if error != &"":
			if not def.on_quay:
				return error
			# A harbour building that does not fit on piles asks for a quay, as before (a
			# builder may still be laying it under the building; P2 part 1: also those that
			# may stand on land).
			stilts.clear()
	for tile: Vector2i in def.footprint_tiles(origin):
		if not grid.is_inside(tile):
			return &"outside_map"
		var terrain := terrain_at(tile)
		# A quay (N1) carries harbour buildings, on their water tiles or their land tiles.
		if grid.has_quay(tile):
			if not def.on_quay:
				return &"not_on_quay"
			if def.stone_quay_only and grid.quay(tile) != TileGrid.STONE_QUAY:
				return &"needs_stone_quay"
		elif stilts.has(tile):
			pass   # one row on piles over the water (B1 part 2)
		elif def.stone_quay_only:
			return &"needs_stone_quay"
		elif def.quay_only:
			return &"needs_quay"
		elif def.stilts_row and def.on_quay and _is_water(tile):
			return &"needs_quay"
		elif on_water.has(tile):
			if sail_depth(tile) == 0:
				return &"needs_sea"
		elif terrain != null and not terrain.buildable:
			return &"terrain_not_buildable"
		if not paving.is_empty() and paving_site_at(tile) != 0:
			return &"tile_occupied"
		if grid.is_blocked(tile) or grid.occupant(tile) != 0 or resources.has_node(tile):
			return &"tile_occupied"
		if _pile_at(tile) != 0 or fields.has_field(tile) or grid.has_road(tile) or grid.has_bridge(tile):
			return &"tile_occupied"
		# A gatehouse or a tower may stand in a wall line (it takes the wall's place, M7 part 2).
		if not walls.is_empty() and (walls.is_stairs(tile) or (walls.blocks_ground(tile) and not def.is_fort())):
			return &"tile_occupied"
	if def.needs_terrain_near != &"" and not has_terrain_near(def, origin):
		return StringName("no_%s_nearby" % def.needs_terrain_near)
	if def.needs_node_near != &"" and not has_node_near(def, origin):
		return StringName("no_%s_nearby" % def.needs_node_near)
	if def.has_berth():
		var berth := def.berth_at(origin, orientation)
		if not grid.is_inside(berth) or sail_depth(berth) == 0 or grid.occupant(berth) != 0:
			return &"no_berth"
		if def.berth_fairway and Ships.fairway_from(self, berth).is_empty() and sail_depth(berth) < 2:
			return &"no_deep_water"
		if not paving.is_empty() and paving_site_at(berth) != 0:
			return &"no_berth"
	if def.served_by_port and Harbour.serving_port(self, origin + Vector2i(def.footprint) / 2) == null:
		return &"no_port_nearby"
	if def.crane_reach > 0 and Cranes.berth_building(self, def, origin, false) == null:
		return &"no_berth_nearby"
	var area := Rect2i(origin, def.footprint)
	for ship: ShipUnit in ships.values():
		if area.has_point(ship.tile()):
			return &"tile_has_ship"
	var entrances: Array[Vector2i] = []
	for o: int in def.door_orientations(orientation):
		entrances.append(origin + def.entrance_at(o))
	for agent: Agent in agents.all():
		var t := agent.tile()
		if not entrances.has(t) and t.x >= origin.x and t.y >= origin.y 				and t.x < origin.x + def.footprint.x and t.y < origin.y + def.footprint.y:
			return &"tile_has_people"
	return _access_error(def, origin, orientation)


## The tiles of a building at [param origin] that would stand over water on piles (B1 part 2):
## water a building with BuildingDef.stilts_row may lean over (shallow sea, lake, river, ford),
## not under a quay. Empty for other buildings.
func stilt_tiles(def: BuildingDef, origin: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if not def.stilts_row:
		return tiles
	for tile: Vector2i in def.footprint_tiles(origin):
		if grid.is_inside(tile) and not grid.has_quay(tile) \
				and (_stilt_water(tile) or (def.stilts_rows >= 2 and sail_depth(tile) > 0)):
			tiles.append(tile)
	return tiles


## Sea, lake, river or ford.
func _is_water(tile: Vector2i) -> bool:
	var terrain := terrain_at(tile)
	return terrain != null and (terrain.sail_depth > 0 or terrain.is_kind(&"water") or terrain.id == &"ford")


## Water a building may stand over on piles: shallow sea, or a river, ford or lake.
func _stilt_water(tile: Vector2i) -> bool:
	var terrain := terrain_at(tile)
	if terrain == null:
		return false
	if terrain.sail_depth > 0:
		return terrain.sail_depth == 1
	return terrain.is_kind(&"water") or terrain.id == &"ford"


## &"" when the tiles of [param stilts] (over the water) are one edge row of the building, the
## water goes on beyond them (no river dammed), and boats keep their way to the open sea.
func _stilts_error(def: BuildingDef, origin: Vector2i, stilts: Array[Vector2i]) -> StringName:
	if stilts.is_empty():
		return &""
	var last := origin + def.footprint - Vector2i.ONE
	var outward := Vector2i.ZERO
	for side: Array in [[Vector2i(-1, 0), origin.x], [Vector2i(1, 0), last.x], [Vector2i(0, -1), origin.y],
			[Vector2i(0, 1), last.y]]:
		var d: Vector2i = side[0]
		var line: int = side[1]
		# The piles stand in the outer rows on this side (one row, or BuildingDef.stilts_rows).
		var used := 0
		for tile: Vector2i in stilts:
			used = maxi(used, absi((tile.x if d.x != 0 else tile.y) - line) + 1)
		if used <= def.stilts_rows and (def.footprint.x if d.x != 0 else def.footprint.y) >= used + 1:
			outward = d
			break
	if outward == Vector2i.ZERO:
		return &"too_much_water"
	var sea := false
	for tile: Vector2i in stilts:
		for k: int in [1, 2]:
			var beyond := tile + outward * k
			if not grid.is_inside(beyond):
				continue
			if not _stilt_water(beyond) and sail_depth(beyond) == 0:
				return &"blocks_water"
			if grid.occupant(beyond) != 0 or grid.has_quay(beyond) or grid.has_bridge(beyond):
				return &"blocks_water"
		if fairway.has(tile):
			return &"keeps_fairway"
		for building: BuildingState in buildings.all():
			if building.def.has_berth() and building.berth_tile() == tile:
				return &"keeps_berth"
		if sail_depth(tile) > 0:
			sea = true
	if sea:
		var blocked: Dictionary[Vector2i, bool] = {}
		for paving_site: PavingSite in paving.values():
			if paving_site.is_quay():
				for t: Vector2i in paving_site.tiles:
					blocked[t] = true
		var before := _sea_reach(blocked)
		for tile: Vector2i in stilts:
			blocked[tile] = true
		var after := _sea_reach(blocked)
		for target: Vector2i in before:
			if not after.has(target):
				return &"blocks_sea"
	return &""


## People must be able to walk to a door of the new building (one free door is enough), and
## it must not wall off any building, ground pile or person they could reach before (a
## sealed-off site stalls porters and builders for good).
func _access_error(def: BuildingDef, origin: Vector2i, orientation: int) -> StringName:
	var fronts: Array[Vector2i] = []
	var water := false
	for o: int in def.door_orientations(orientation):
		var front := def.door_front(origin, o)
		if nav.is_walkable(front) and grid.occupant(front) == 0:
			fronts.append(front)
		else:
			var terrain := terrain_at(front) if grid.is_inside(front) else null
			water = water or (terrain != null and terrain.is_kind(&"water"))
	if fronts.is_empty():
		return &"entrance_faces_water" if water else &"no_access"
	var blocked: Dictionary[Vector2i, bool] = {}
	var passage := def.passage_at(orientation)
	for tile: Vector2i in def.footprint_tiles(origin):
		if not passage.has(tile - origin):
			blocked[tile] = true
	var door_owner: Dictionary[Vector2i, int] = {}
	for building: BuildingState in buildings.all():
		for door: Vector2i in door_tiles(building):
			door_owner[door] = building.id
	if door_owner.is_empty():
		return &""
	var targets: Dictionary[Vector2i, bool] = {}
	for door: Vector2i in door_owner:
		targets[door] = true
	for pile: GroundPile in piles.values():
		targets[pile.tile] = true
	for agent: Agent in agents.all():
		targets[agent.tile()] = true
	# Some door must lead to the others.
	var doors: Dictionary[Vector2i, bool] = {}
	for door: Vector2i in door_owner:
		doors[door] = true
	var any_door := false
	for front: Vector2i in fronts:
		if not nav.reachable(front, doors, blocked).is_empty():
			any_door = true
			break
	if not any_door:
		return &"no_access"
	# Nothing reachable before may be cut off. Seen from one side of the building (a building
	# with doors on both sides of a gate must not join what it walls apart).
	var before := nav.reachable(fronts[0], targets)
	var after := nav.reachable(fronts[0], before, blocked)
	var reached_before: Dictionary[int, bool] = {}
	var reached_after: Dictionary[int, bool] = {}
	for tile: Vector2i in before:
		if door_owner.has(tile):
			reached_before[door_owner[tile]] = true
		elif not after.has(tile):
			return &"blocks_access"   # a pile or a person would be walled in
	for tile: Vector2i in after:
		if door_owner.has(tile):
			reached_after[door_owner[tile]] = true
	return &"" if reached_after.size() == reached_before.size() else &"blocks_access"


static func _has_any(tiles: Dictionary[Vector2i, bool], wanted: Dictionary[Vector2i, bool]) -> bool:
	for tile: Vector2i in tiles:
		if wanted.has(tile):
			return true
	return false


## The tiles people step through into [param building]: the free tiles in front of its
## doors, or, when none is free (a town from before buildings could be turned), any free side
## of its main entrance.
func door_tiles(building: BuildingState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pair: Array in door_pairs(building):
		result.append(pair[1])
	return result


## [entrance, tile in front] of every usable door of [param building].
func door_pairs(building: BuildingState) -> Array[Array]:
	var pairs: Array[Array] = []
	for o: int in building.def.door_orientations(building.orientation):
		var front := building.def.door_front(building.origin, o)
		if nav.is_walkable(front) and grid.occupant(front) == 0:
			pairs.append([building.origin + building.def.entrance_at(o), front])
	if pairs.is_empty():
		var entrance := building.entrance_tile()
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var t := entrance + step
			if nav.is_walkable(t):
				pairs.append([entrance, t])
				break
	return pairs


## The first door tile of [param building] (door_tiles), or Agent.NO_TILE.
func door_tile(building: BuildingState) -> Vector2i:
	var doors := door_tiles(building)
	return doors[0] if not doors.is_empty() else Agent.NO_TILE


## The building one of whose entrances is [param tile], or null.
func building_entered_at(tile: Vector2i) -> BuildingState:
	var owner := grid.occupant(tile) if grid.is_inside(tile) else 0
	if owner == 0:
		return null
	var building := buildings.get_building(owner)
	return building if building != null and building.is_entrance(tile) else null


## Tile path from [param from] to [param to] (both ends included, empty when unreachable).
## People go into and out of a building only through a door (M4b-1.5): a path into a
## building ends at the entrance of its door nearest to the way (the walker then counts as
## standing at [param to]), and one out of a building starts at the entrance of the door
## nearest to where they go.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return [from]
	var start := from
	var goal := to
	var head := Agent.NO_TILE
	var tail := Agent.NO_TILE
	var leaving := building_entered_at(from)
	if leaving != null:
		var pair := _nearest_door(leaving, to)
		if not pair.is_empty():
			head = pair[0]
			start = pair[1]
	var entering := building_entered_at(to)
	if entering != null:
		var pair := _nearest_door(entering, start)
		if not pair.is_empty():
			tail = pair[0]
			goal = pair[1]
	var path := nav.find_path(start, goal)
	if path.is_empty():
		return path
	if head != Agent.NO_TILE:
		path.push_front(head)
	if tail != Agent.NO_TILE:
		path.append(tail)
	return path


## Road path for a horse wagon (M4b-3) from [param from] to the road tile [param to]. A wagon
## leaving a building (its carter fetches it from the stable) starts at the door with a road
## in front nearest to the way. Empty when there is no road all the way.
func find_road_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return [from]
	var start := from
	var head := Agent.NO_TILE
	var leaving := building_entered_at(from)
	if leaving != null:
		var best_d := 1 << 30
		for pair: Array in door_pairs(leaving):
			var front: Vector2i = pair[1]
			var d := (front - to).length_squared()
			if road_nav.is_walkable(front) and d < best_d:
				best_d = d
				head = pair[0]
				start = front
		if head == Agent.NO_TILE:
			return []
	var path := road_nav.find_path(start, to)
	if path.is_empty():
		return path
	if head != Agent.NO_TILE:
		path.push_front(head)
	return path


## The road tile in front of a door of the place behind storage [param id] where a wagon
## stops (M4b-3): a building, its yard or its construction site; a paving site's next tile;
## a ground pile or the merchant's wagon when they stand on a road. Agent.NO_TILE if none.
func road_stop(id: int, near: Vector2i = Agent.NO_TILE) -> Vector2i:
	var building := buildings.get_building(absi(id))
	var site := sites.get(id) as ConstructionSite
	if site != null:
		building = buildings.get_building(site.building_id)
	var build := ship_builds.get(id) as ShipBuild
	if build != null:
		building = buildings.get_building(build.shipyard_id)
	if building != null:
		var best := Agent.NO_TILE
		var best_d := 1 << 30
		for pair: Array in door_pairs(building):
			var front: Vector2i = pair[1]
			var d := (front - near).length_squared() if near != Agent.NO_TILE else 0
			if road_nav.is_walkable(front) and d < best_d:
				best_d = d
				best = front
		return best
	var tile := access_tile(id)
	return tile if tile != Agent.NO_TILE and road_nav.is_walkable(tile) else Agent.NO_TILE


func _nearest_door(building: BuildingState, near: Vector2i) -> Array:
	var best: Array = []
	var best_d := 1 << 30
	for pair: Array in door_pairs(building):
		var d := ((pair[1] as Vector2i) - near).length_squared()
		if d < best_d:
			best_d = d
			best = pair
	return best


## The orientation suggested for a building of [param def] at [param origin] (placement
## preview, M4b-1.5). Of the turns it fits in, one with its door onto a road wins; among
## those (or when no road is next to it) one that lines it up into a row with a neighbour of
## the same kind turned the same way; then [param preferred] and the next ones in order.
## -1 when neither a road nor a neighbour decides.
func suggested_orientation(def: BuildingDef, origin: Vector2i, preferred: int = 0) -> int:
	var count := def.orientation_count()
	var best := -1
	var best_score := 0
	for i: int in count:
		var o := (preferred + i) % count
		var score := 0
		for k: int in def.door_orientations(o):
			var front := def.door_front(origin, k)
			if grid.is_inside(front) and grid.has_road(front):
				score = 2
				break
		if row_neighbours(def, origin, o) > 0:
			score += 1
		if score > best_score and placement_error(def, origin, o) == &"":
			best = o
			best_score = score
	return best


## Buildings of [param def] turned to [param orientation] standing right beside
## [param origin] along the front of one so turned (where a row of them would continue).
func row_neighbours(def: BuildingDef, origin: Vector2i, orientation: int) -> int:
	var along := Vector2i(0, def.footprint.y) if orientation % 2 == 0 else Vector2i(def.footprint.x, 0)
	var n := 0
	for at: Vector2i in [origin - along, origin + along]:
		var other := buildings.get_building(grid.occupant(at)) if grid.is_inside(at) else null
		if other != null and other.origin == at and other.def == def and other.orientation == orientation:
			n += 1
	return n


## Houses next to new road [param tiles] whose door does not open onto a road yet turn to
## the new road when they can (M4b-1.5, owner's decision): rows that already face a road
## never flip.
func turn_houses_to_road(tiles: Array[Vector2i]) -> void:
	var seen: Dictionary[int, bool] = {}
	for tile: Vector2i in tiles:
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next := tile + step
			var building := buildings.get_building(grid.occupant(next)) if grid.is_inside(next) else null
			if building == null or seen.has(building.id) or not building.def.is_house():
				continue
			seen[building.id] = true
			var front := building.door_front_tile()
			if grid.is_inside(front) and grid.has_road(front):
				continue
			var count := building.def.orientation_count()
			for i: int in range(1, count):
				var o := (building.orientation + i) % count
				var new_front := building.def.door_front(building.origin, o)
				if grid.is_inside(new_front) and grid.has_road(new_front) and can_turn(building, o):
					turn_building(building, o)
					break


## Whether [param building] may be turned to [param orientation]: one of its doors then has
## free ground in front that leads to the other buildings. The building itself is solid
## whichever way it is turned, so turning never blocks anybody else.
func can_turn(building: BuildingState, orientation: int) -> bool:
	var doors: Dictionary[Vector2i, bool] = {}
	for other: BuildingState in buildings.all():
		if other.id != building.id:
			for door: Vector2i in door_tiles(other):
				doors[door] = true
	for o: int in building.def.door_orientations(orientation):
		var front := building.def.door_front(building.origin, o)
		if not nav.is_walkable(front) or grid.occupant(front) != 0:
			continue
		if doors.is_empty() or not nav.reachable(front, doors).is_empty():
			return true
	return false


## Turns a placed building. People inside (on an old entrance) move to the new main
## entrance; those walking to it plan their way again.
func turn_building(building: BuildingState, orientation: int) -> void:
	var old := building.entrance_tiles()
	building.orientation = orientation
	var entrance := building.entrance_tile()
	for agent: Agent in agents.all():
		if old.has(agent.tile()):
			agent.pos = IsoMath.tile_center(entrance)
			agent.prev_pos = agent.pos
		if old.has(agent.path_goal) or agent.path_state == Agent.PathState.MOVING \
				and agent.path_index < agent.path.size() and old.has(agent.path[-1]):
			var goal := entrance if old.has(agent.path_goal) else agent.path_goal
			var walking := agent.path_state != Agent.PathState.NONE
			agent.clear_path()
			if walking:
				agent.path_goal = goal
				agent.path_state = Agent.PathState.WAITING
				paths.push(agent.id)
	nav.version += 1   # paths through the old doors are planned again
	nav.solid_version += 1
	events.emit(&"building_turned", {"building": building.id, "orientation": orientation})


## Turns a placed building. People inside (on the old entrance) step to the new one; those
## Whether a tile of terrain [member BuildingDef.needs_terrain_near] lies within the work
## radius of a building of [param def] placed at [param origin].
func has_terrain_near(def: BuildingDef, origin: Vector2i) -> bool:
	var area := Rect2i(origin, def.footprint).grow(def.work_radius).intersection(Rect2i(Vector2i.ZERO, grid.size))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var terrain := terrain_at(Vector2i(x, y))
			if terrain != null and terrain.is_kind(def.needs_terrain_near):
				return true
	return false


## Whether a node of def.needs_node_near (an ore vein for a mine, M7) lies within the work
## radius of a building of [param def] at [param origin].
func has_node_near(def: BuildingDef, origin: Vector2i) -> bool:
	var area := Rect2i(origin, def.footprint).grow(def.work_radius).intersection(Rect2i(Vector2i.ZERO, grid.size))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var tile := Vector2i(x, y)
			if resources.has_node(tile, def.needs_node_near) and resources.amount(tile) > 0:
				return true
	return false


## The walkable tile within the work radius of [param building], next to its
## needs_terrain_near terrain, nearest to [param from]; Agent.NO_TILE if none.
## Tiles where another worker already stands are used only when nothing else is free.
func find_shore(building: BuildingState, from: Vector2i) -> Vector2i:
	var taken: Dictionary[Vector2i, bool] = {}
	for agent: Agent in agents.all():
		if agent.task != null and agent.task.bb.has("stand") and agent.workplace_id != 0:
			taken[SimCodec.to_vec2i(agent.task.bb["stand"])] = true
	var area := Rect2i(building.origin, building.def.footprint).grow(work_radius(building)) \
			.intersection(Rect2i(Vector2i.ZERO, grid.size))
	var best := Agent.NO_TILE
	var best_d := 1 << 30
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var tile := Vector2i(x, y)
			if not nav.is_walkable(tile) or grid.occupant(tile) != 0 \
					or shore_water(tile, building.def.needs_terrain_near) == Agent.NO_TILE:
				continue
			var d := (tile - from).length_squared() + (1 << 20 if taken.has(tile) else 0)
			if d < best_d:
				best_d = d
				best = tile
	return best


## An orthogonal neighbour of [param tile] with terrain [param terrain_id]; Agent.NO_TILE if none.
func shore_water(tile: Vector2i, terrain_id: StringName) -> Vector2i:
	for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var terrain := terrain_at(tile + step) if grid.is_inside(tile + step) else null
		if terrain != null and terrain.is_kind(terrain_id):
			return tile + step
	return Agent.NO_TILE


# --- Forestry (M4b-1) -----------------------------------------------------------------------

## Where a forester of [param building] plants next (only on its marked plant_area when the
## player marked one, M4b-1.5): the nearest stump of [param node_id]
## within the work radius, else the nearest free ground there, nearest to [param from].
## Spots chosen by other foresters are skipped. Agent.NO_TILE if none. There is no limit on
## trees (M4b-2): he plants while there is room.
func find_plant_spot(building: BuildingState, node_id: StringName, from: Vector2i) -> Vector2i:
	var taken: Dictionary[Vector2i, bool] = {}
	for agent: Agent in agents.all():
		if agent.task != null and agent.task.bb.has("plant") and agent.task.bb.has("node"):
			taken[SimCodec.to_vec2i(agent.task.bb["node"])] = true
	var area := _work_area(building)
	var candidates: Array[Vector2i] = building.plant_area.duplicate()
	if candidates.is_empty():
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				candidates.append(Vector2i(x, y))
	var best := Agent.NO_TILE
	var best_d := 1 << 30
	for tile: Vector2i in candidates:
		# Distance first: the other checks cost more and only a nearer tile can win (M4b-3).
		var stump := resources.is_depleted(tile) and resources.def_at(tile).id == node_id
		var d := (tile - from).length_squared() + (0 if stump else 1 << 20)
		if d >= best_d or taken.has(tile) or not area.has_point(tile) or not can_plant(tile, node_id):
			continue
		if approach_tile(tile, from) != Agent.NO_TILE:
			best_d = d
			best = tile
	return best


## Tiles within the work radius of [param building], clipped to the map.
func _work_area(building: BuildingState) -> Rect2i:
	return Rect2i(building.origin, building.def.footprint).grow(work_radius(building)).intersection(
			Rect2i(Vector2i.ZERO, grid.size))


## Whether a finished house of [param level] or higher stands here (E4 part 2: the school).
func has_house_level(level: int) -> bool:
	for building: BuildingState in buildings.all():
		if building.house != null and building.house.level >= level:
			return true
	return false


## The work radius of [param building] with the owner's research (E4 part 2: forestry).
func work_radius(building: BuildingState) -> int:
	return building.def.work_radius + research.extra_radius(data, building.def.id)


## Field, pen or hive tiles [param building] may have, with the owner's research (E4 part 2:
## larger fields and pens).
func field_limit(building: BuildingState) -> int:
	var limit := building.def.field_limit()
	return limit + research.extra_fields(data, building.def.id) if limit > 0 else 0


## Whether a sapling may go on [param tile]: a stump of [param node_id] (old saves), or free
## buildable ground. Trees are walkable (M4b-2), so a forester plants tile by tile like the
## forest of the map; never on a road or a field and never next to a building (the tile in
## front of a door stays free).
func can_plant(tile: Vector2i, node_id: StringName = &"tree") -> bool:
	if not grid.is_inside(tile):
		return false
	if resources.def_at(tile) != null:
		if not resources.is_depleted(tile) or resources.def_at(tile).id != node_id:
			return false
	elif _free_ground_error(tile) != &"":
		return false
	if grid.is_blocked(tile) or fields.has_field(tile) or grid.has_road(tile) or grid.has_bridge(tile):
		return false
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var next := tile + Vector2i(dx, dy)
			if grid.is_inside(next) and grid.occupant(next) != 0:
				return false
	return true


## A felled tree taken with its stump leaves grass where the forest floor was (owner's
## decision 2026-11-05): cleared land turns green.
## Turns the ground under a used-up node into its ResourceNodeDef.leaves_terrain (M4b-3).
func leave_terrain(tile: Vector2i, node_def: ResourceNodeDef) -> void:
	var terrain := data.get_terrain(node_def.leaves_terrain) if node_def.leaves_terrain != &"" else null
	if terrain != null and grid.terrain(tile) != terrain.index:
		grid.set_terrain(tile, terrain.index)
		events.emit(&"terrain_changed", {"tile": tile, "terrain": terrain.id})


func clear_forest_floor(tile: Vector2i) -> void:
	var terrain := terrain_at(tile)
	if terrain == null or terrain.id != &"forest":
		return
	var grass := data.get_terrain(&"grass")
	if grass != null:
		grid.set_terrain(tile, grass.index)
		refresh_tile(tile)


func plant(tile: Vector2i, sapling: ResourceNodeDef) -> void:
	resources.plant(tile, sapling, tick + SimClock.seconds_to_ticks(sapling.grow_time))
	refresh_tile(tile)
	events.emit(&"resource_planted", {"tile": tile, "node": sapling.id})


## A market reaches houses while its stalls hold goods (M4b-2, like a tavern serving).
func _update_markets() -> void:
	for building: BuildingState in buildings.all():
		if not building.def.stall_goods.is_empty() and building.supply != null 				and building.supply.total_amount() > 0:
			building.serving_until = tick + GROW_CHECK_TICKS * 2


## The market a householder of [param house] buys [param amount] of [param good] at: the
## nearest one whose range reaches the house and whose stalls have it (M4b-2); 0 if none.
func market_source(good: StringName, amount: int, house: BuildingState) -> int:
	var best := 0
	var best_d := 1 << 30
	var doors: Array[Vector2i] = []
	for market: BuildingState in market_buildings():
		if market.def.stall_goods.is_empty() or market.supply == null 				or not market.supply.can_supply(good, amount):
			continue
		var reached := false
		if doors.is_empty():
			doors = door_tiles(house)
		for door: Vector2i in doors:
			if coverage.covers(market.def.id, door, grid.size):
				reached = true
				break
		var d := (market.entrance_tile() - house.entrance_tile()).length_squared()
		if reached and d < best_d:
			best_d = d
			best = market.id
	return best


## Herds with 2 or more animals, a worker and room breed (M4b-2): one young animal every
## breed_time seconds with 2 animals, faster in a bigger herd (the time over half the herd).
func _breed_herds() -> void:
	if not _due_pens_checked:
		_due_pens_checked = true
		_place_due_pens()
	for building: BuildingState in buildings.all():
		var good := building.def.herd_good
		if good == &"" or building.yard == null or building.paused \
				or (building.workers.is_empty() and abstract_staff.get(building.id, 0) == 0):
			continue
		var herd := building.yard.total(good)
		if herd < 2 or building.yard.free_space(good) <= 0:
			building.breed_ticks = 0
			continue
		building.breed_ticks += GROW_CHECK_TICKS
		var due := maxi(roundi(SimClock.seconds_to_ticks(building.def.breed_time) * 2.0 / herd), 1)
		if building.breed_ticks >= due:
			building.breed_ticks = 0
			building.yard.add(good, 1)
			ledger.made(good, 1, tick)
			events.emit(&"animal_born", {"building": building.id, "good": good, "herd": herd + 1})


## Nodes that grow back (fish shoals, M5) gain a unit on the ticks their regrow time divides.
func _regrow_nodes() -> void:
	for def: ResourceNodeDef in resources.regrowing_kinds():
		var every := maxi(SimClock.seconds_to_ticks(def.regrow_time), 1)
		if tick % every != 0:
			continue
		for tile: Vector2i in resources.regrow(def):
			events.emit(&"resource_regrown", {"tile": tile, "node": def.id})


## Grows due saplings into trees (walkable, so people standing there are not trapped).
func _grow_saplings() -> void:
	if resources.growing_count() == 0:
		return
	for tile: Vector2i in resources.due_to_grow(tick):
		var young := resources.def_at(tile)
		if young == null or young.grows_into == &"":
			continue
		resources.place(tile, data.get_resource_node(young.grows_into))
		refresh_tile(tile)
		events.emit(&"resource_grown", {"tile": tile, "node": young.grows_into})


## Places a building turned to [param orientation]. [param instant] finishes it at once (map start, tests); otherwise it
## becomes a construction site that porters and builders turn into the building (its gold
## cost is paid now; the command checked there is enough).
func add_building(def: BuildingDef, origin: Vector2i, instant: bool = false,
		orientation: int = 0, look: int = 0) -> BuildingState:
	var building := BuildingState.new(ids.take(), def, origin, orientation)
	building.look = look
	if def.id == first_building:
		first_building = &""
	if not instant:
		treasury.pay(def.gold_cost)
	buildings.add(building)
	if def.is_fort() or def.walk_through:
		_add_fort(building)
	for tile: Vector2i in building.tiles():
		grid.set_occupant(tile, building.id)
		resources.clear(tile)
		refresh_tile(tile)
	events.emit(&"building_placed", {"building": building.id, "def": def.id, "origin": origin,
			"orientation": orientation, "instant": instant})
	if instant or def.build_cost.is_empty():
		building.finish(data)
		events.emit(&"building_completed", {"building": building.id, "def": def.id})
	else:
		building.under_construction = true
		Construction.open_build_site(self, building)
	if def.berth_fairway:
		refresh_fairways()
	return building


## Removes a building. Stored goods and part of the materials are put on the ground,
## workers go home (their characters vanish), people living there leave.
func remove_building(id: int) -> void:
	var building := buildings.get_building(id)
	if building == null:
		return
	for worker_id: int in building.workers.duplicate():
		var worker := agents.get_agent(worker_id)
		if worker != null:
			remove_agent(worker)
	for agent: Agent in agents.all():
		if agent.home_id == id:
			remove_agent(agent)
	for tile: Vector2i in fields.tiles_of(id):
		remove_field(tile)
	var was_complete := building.is_complete()
	Construction.cancel_site(self, building)
	buildings.remove(id)
	jobs.cancel_for_entity(id)
	jobs.cancel_for_entity(yard_id(id))
	for agent: Agent in agents.all():
		if agent.task != null and (absi(int(agent.task.bb.get("_src", 0))) == id \
				or absi(int(agent.task.bb.get("_dst", 0))) == id):
			TaskRunner.fail(self, agent)
	Ships.on_building_removed(self, id)
	var tiles := building.tiles()
	if building.def.is_fort() or building.def.walk_through:
		_remove_fort(building)
	for tile: Vector2i in tiles:
		grid.set_occupant(tile, 0)
		refresh_tile(tile)
	if building.def.berth_fairway:
		refresh_fairways()
	# Goods of a building on the water go on its land tiles.
	var on_water := building.def.water_tiles_at(building.origin, building.orientation)
	var land: Array[Vector2i] = []
	for tile: Vector2i in tiles:
		if not on_water.has(tile):
			land.append(tile)
	if not land.is_empty():
		tiles = land
	var i := 0
	for store: Stockpile in [building.stock, building.supply, building.yard]:
		if store == null:
			continue
		for slot: int in store.slot_count():
			var amount := store.slot_amount[slot]
			if amount > 0:
				drop_goods(tiles[i % tiles.size()], store.slot_good[slot], amount)
				i += 1
	if was_complete:
		var refund := Construction.refund(building.def)
		for good: StringName in refund:
			drop_goods(tiles[i % tiles.size()], good, refund[good])
			i += 1
		treasury.add(floori(building.def.gold_cost * Construction.REFUND_SHARE))
	events.emit(&"building_removed", {"building": id, "def": building.def.id})


func assign_worker(agent: Agent, building: BuildingState) -> void:
	var old := buildings.get_building(agent.workplace_id)
	if old != null:
		old.workers.erase(agent.id)
	if agent.task != null and agent.task.kind == Task.KIND_RECIPE:
		TaskRunner.fail(self, agent)
		agent.cooldown = 0
	agent.workplace_id = building.id
	building.workers.append(agent.id)


# --- Fields and roads ----------------------------------------------------------------------

## &"" when [param tile] can become a field of [param farm_id], otherwise the reason. A
## building with pens (Z1) places its pen tiles the same way.
func field_error(farm_id: int, tile: Vector2i) -> StringName:
	var farm := buildings.get_building(farm_id)
	if farm == null or field_limit(farm) == 0:
		return &"not_a_farm"
	if not grid.is_inside(tile):
		return &"outside_map"
	if fields.tiles_of(farm_id).size() >= field_limit(farm):
		if farm.def.has_hives():
			return &"too_many_hives"
		return &"too_many_pens" if farm.def.has_pens() else &"too_many_fields"
	var rect := Rect2i(farm.origin, farm.def.footprint).grow(work_radius(farm))
	if not rect.has_point(tile):
		return &"out_of_range"
	var terrain := terrain_at(tile)
	if terrain != null and not terrain.farmable and not farm.def.has_tiles():
		return &"terrain_not_farmable"
	return _free_ground_error(tile)


func add_field(farm_id: int, tile: Vector2i) -> void:
	fields.add(tile, farm_id)
	refresh_tile(tile)
	var building := buildings.get_building(farm_id)
	if building != null and building.def.has_tiles():
		update_herd_room(building)
		# The first pen brings the starting pair (Z1, owner's survey 2026-11-10).
		if building.give_pair() > 0:
			events.emit(&"animal_born", {"building": building.id, "good": building.def.herd_good,
					"herd": building.yard.total(building.def.herd_good)})
	events.emit(&"field_changed", {"tile": tile, "farm": farm_id})


## Removes a field tile; a farmer working it gives up. A pen tile (Z1) shrinks the herd's room;
## animals above it stay (owner's survey 2026-11-10: nobody vanishes, the herd stops growing).
func remove_field(tile: Vector2i) -> void:
	var owner := fields.claimant(tile)
	var holder := buildings.get_building(fields.farm_of(tile))
	fields.remove(tile)
	refresh_tile(tile)
	var agent := agents.get_agent(owner)
	if agent != null and agent.task != null:
		TaskRunner.fail(self, agent)
	if holder != null and holder.def.has_tiles():
		update_herd_room(holder)
	elif holder != null:
		# The last unsown tile gone: the rest of the field starts growing (E1 part 2).
		for started: Vector2i in fields.start_if_ready(holder.id, tick):
			events.emit(&"field_changed", {"tile": started})
	events.emit(&"field_changed", {"tile": tile, "farm": 0})


## Counts the pen tiles of [param building] (Z1) and sets the herd's room from them: 2 animals
## per pen tile, the breeding reserve kept between 2 and the room.
func update_herd_room(building: BuildingState) -> void:
	if building.def.has_hives():
		building.hives = fields.tiles_of(building.id).size()
		return
	if not building.def.has_pens():
		return
	building.pens = fields.tiles_of(building.id).size()
	if building.yard != null:
		building.yard.stack_limit = maxi(building.herd_room(), 1)


## Sheep farms from saves before v33 get their pen now (Z1 part 2), apiaries before v34 their
## hives (part 3): beside them, in one piece; a pen brings the starting pair.
func _place_due_pens() -> void:
	for building: BuildingState in buildings.all():
		if building.pens_due > 0:
			Pens.auto_place(self, building, building.pens_due)
			building.pens_due = 0


## Every herd in pens counts its pen tiles again (after loading a game).
func update_herd_rooms() -> void:
	if fields.count() == 0 and not _has_pen_buildings():
		return
	var counts := fields.counts()
	for building: BuildingState in buildings.all():
		if building.def.has_hives():
			building.hives = counts.get(building.id, 0)
		if building.def.has_pens():
			building.pens = counts.get(building.id, 0)
			if building.yard != null:
				building.yard.stack_limit = maxi(building.herd_room(), 1)


func _has_pen_buildings() -> bool:
	for building: BuildingState in buildings.all():
		if building.def.has_tiles():
			return true
	return false


## Whether [param tile] is a hive tile (Z1 part 3): a field tile of an apiary.
func is_hive(tile: Vector2i) -> bool:
	if not fields.has_field(tile):
		return false
	var holder := buildings.get_building(fields.farm_of(tile))
	return holder != null and holder.def.has_hives()


## Whether [param tile] is a pen tile (Z1): a field tile of a building with pens.
func is_pen(tile: Vector2i) -> bool:
	if not fields.has_field(tile):
		return false
	var holder := buildings.get_building(fields.farm_of(tile))
	return holder != null and holder.def.has_pens()


## &"" when a dirt road can go on [param tile].
func road_error(tile: Vector2i) -> StringName:
	if not grid.is_inside(tile):
		return &"outside_map"
	if grid.has_road(tile):
		return &"already_road"
	return _free_ground_error(tile)


func set_road(tile: Vector2i, road: bool) -> void:
	grid.set_road(tile, road)
	if not road:
		_withdraw_paving(tile)
	refresh_tile(tile)
	events.emit(&"road_changed", {"tile": tile, "road": road, "paved": false})


## &"" when [param tile] can be ordered paved: a dirt road not ordered yet, or free ground
## (it becomes dirt road at once).
func paving_error(tile: Vector2i) -> StringName:
	if not grid.is_inside(tile):
		return &"outside_map"
	if grid.is_paved(tile):
		return &"already_paved"
	if paving_site_at(tile) != 0:
		return &"already_ordered"
	if grid.has_road(tile):
		return &""
	return _free_ground_error(tile)


## The paving site that still has [param tile] to pave, 0 if none.
func paving_site_at(tile: Vector2i) -> int:
	for paving_site: PavingSite in paving.values():
		if paving_site.tiles.has(tile):
			return paving_site.id
	return 0


## Orders [param tiles] paved (checked with paving_error): free ground becomes dirt road now,
## porters bring the stone and a builder lays the cobbles. Returns the site id.
func order_paving(tiles: Array[Vector2i]) -> int:
	if tiles.is_empty():
		return 0
	for tile: Vector2i in tiles:
		if not grid.has_road(tile):
			set_road(tile, true)
	var paving_site := PavingSite.new(ids.take(), tiles.duplicate(), data)
	paving[paving_site.id] = paving_site
	jobs.add(paving_site.good(), tiles.size() * paving_site.per_tile(), 0, paving_site.id)
	events.emit(&"paving_ordered", {"site": paving_site.id, "tiles": tiles.size()})
	return paving_site.id


## Lays the next tile of [param paving_site] with its material: cobbles, or a quay tile (N1).
func pave_next(paving_site: PavingSite) -> void:
	var tile := paving_site.tiles.pop_front() as Vector2i
	paving_site.stock.remove(paving_site.good(), paving_site.per_tile())
	ledger.used(paving_site.good(), paving_site.per_tile(), tick)
	paving_site.work_left = paving_site.tile_ticks()
	_lay_paving_tile(paving_site, tile)
	if paving_site.tiles.is_empty():
		_close_paving(paving_site, tile)


## Developer mode (E4 part 1): every construction, upgrade, paving, wall, bridge and quay site
## is done at once, without materials or builders. Materials already brought stay on the ground.
func finish_works_now() -> void:
	if not sites.is_empty():
		var ids_now: Array[int] = []
		ids_now.assign(sites.keys())
		ids_now.sort()
		for id: int in ids_now:
			var site := sites.get(id) as ConstructionSite
			if site != null:
				Construction.finish_now(self, site)
	if not paving.is_empty():
		var paving_ids: Array[int] = []
		paving_ids.assign(paving.keys())
		paving_ids.sort()
		for id: int in paving_ids:
			var paving_site := paving.get(id) as PavingSite
			if paving_site == null:
				continue
			var last := Agent.NO_TILE
			while not paving_site.tiles.is_empty():
				last = paving_site.tiles.pop_front() as Vector2i
				_lay_paving_tile(paving_site, last)
			_close_paving(paving_site, last)


## Lays [param tile] of [param paving_site]: a wall, a bridge, a quay or cobbles.
func _lay_paving_tile(paving_site: PavingSite, tile: Vector2i) -> void:
	if paving_site.is_wall():
		lay_wall(tile, paving_site.wall_value())
	elif paving_site.is_bridge():
		if resources.has_node(tile):
			# A tree (or sapling) on the bank goes for the ramp.
			resources.clear(tile)
			events.emit(&"resource_depleted", {"tile": tile})
		grid.set_bridge(tile, paving_site.bridge_value())
		refresh_tile(tile)
		var laid: Array[Vector2i] = [tile]
		events.emit(&"bridge_changed", {"tiles": laid, "bridge": paving_site.bridge_value()})
	elif paving_site.is_quay():
		grid.set_quay(tile, paving_site.quay_value())
		refresh_tile(tile)
		refresh_fairways()
		events.emit(&"quay_changed", {"tile": tile, "quay": paving_site.quay_value()})
	else:
		grid.set_paved(tile, true)
		refresh_tile(tile)
		events.emit(&"road_changed", {"tile": tile, "road": true, "paved": true})


## Once a second: each paving or quay site asks for exactly the material it still lacks. A
## porter who could not deliver (the builder's spot moves on with every quay tile laid) leaves
## his load on the ground; without this the site would wait for it for good.
func _top_up_paving() -> void:
	for paving_site: PavingSite in paving.values():
		var missing := paving_site.stone_missing()
		var good := paving_site.good()
		var found := false
		for request: TransportRequest in jobs.all():
			if request.dest_id == paving_site.id and request.good == good:
				found = true
				jobs.set_amount(good, request.source_id, paving_site.id, missing - request.in_flight)
				missing = 0
		if not found and missing > 0:
			jobs.add(good, missing, 0, paving_site.id)


## A road tile removed before it was paved leaves its site (stone not needed any more is
## not asked for; stone already there goes on the ground when the site closes).
func _withdraw_paving(tile: Vector2i) -> void:
	var id := paving_site_at(tile)
	if id == 0:
		return
	var paving_site := paving[id]
	var first := paving_site.next_tile() == tile
	paving_site.tiles.erase(tile)
	if paving_site.tiles.is_empty():
		_close_paving(paving_site, tile)
		return
	if first:
		paving_site.work_left = paving_site.tile_ticks()
		# Porters on the way head for the new next tile on arrival (access_tile).
	for request: TransportRequest in jobs.all():
		if request.dest_id == id:
			jobs.set_amount(paving_site.good(), request.source_id, id,
					paving_site.stone_missing() - request.in_flight)


## &"" when cobbles are ordered on [param tile] and not laid yet (review fix 2026-11-07:
## the player can cancel them).
func cancel_paving_error(tile: Vector2i) -> StringName:
	var id := paving_site_at(tile) if not paving.is_empty() else 0
	if id == 0 or paving[id].is_quay() or paving[id].is_bridge():
		return &"not_paving"
	return &""


## Cancels the cobbles ordered on [param tile] (checked with cancel_paving_error): the tile
## stays a dirt road.
func cancel_paving(tile: Vector2i) -> void:
	_withdraw_paving(tile)
	events.emit(&"paving_cancelled", {"tile": tile})


## Removes a paving site; stone left over goes on the ground at [param at] (its last tile).
func _close_paving(paving_site: PavingSite, at: Vector2i = Agent.NO_TILE) -> void:
	paving.erase(paving_site.id)
	jobs.cancel_for_entity(paving_site.id)
	for agent: Agent in agents.all():
		# Builders finish on their own when they find the site gone.
		if agent.task != null and int(agent.task.bb.get("_dst", 0)) == paving_site.id:
			TaskRunner.fail(self, agent)
	var leftovers := paving_site.stock.totals()
	for good: StringName in leftovers:
		drop_goods(at if at != Agent.NO_TILE else entry_tile, good, leftovers[good])
	events.emit(&"paving_closed", {"site": paving_site.id})


# --- Quays (N1) ----------------------------------------------------------------------------

## How far a quay may reach into the sea, in quay tiles from the shore (ROADMAP N1).
const QUAY_REACH := 8
## How far a quay may come up onto the land, in tiles from the sea (owner's request
## 2026-11-07: quays and piers reach a little onto the shore, straight or slanting).
const QUAY_LAND_REACH := 2

const _STEPS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const _STEPS8: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]


## Where the builder stands for the next tile of [param paving_site] (porters bring the
## material there): the tile itself for cobbles, a walkable neighbour for a quay tile;
## Agent.NO_TILE when none can be reached now.
func paving_stand(paving_site: PavingSite) -> Vector2i:
	var tile := paving_site.next_tile()
	if tile == Agent.NO_TILE or not paving_site.stands_beside():
		return tile
	if paving_site.is_bridge():
		# On the bridge laid so far (B1): the far bank may not be reachable yet.
		for step: Vector2i in _STEPS4:
			var t := tile + step
			if grid.has_bridge(t) and nav.is_walkable(t):
				return t
	for step: Vector2i in _STEPS4:
		var t := tile + step
		if nav.is_walkable(t):
			return t
	return Agent.NO_TILE


## Whether the next tile of [param paving_site] can be laid now (no ship lies on a quay tile).
func can_lay(paving_site: PavingSite) -> bool:
	if paving_site.is_wall():
		return wall_can_lay(paving_site)
	if paving_site.is_bridge():
		# A woodcutter felling a tree where the ramp goes finishes first.
		return resources.claimant(paving_site.next_tile()) == 0
	if not paving_site.is_quay():
		return true
	var tile := paving_site.next_tile()
	for ship: ShipUnit in ships.values():
		if ship.tile() == tile:
			return false
	return true


## Whether sea water (by terrain, quay or not) lies within [param reach] tiles (Chebyshev) of
## [param tile].
func _near_sea(tile: Vector2i, reach: int) -> bool:
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var t := tile + Vector2i(dx, dy)
			var terrain := terrain_at(t) if grid.is_inside(t) else null
			if terrain != null and terrain.sail_depth > 0:
				return true
	return false


## Whether [param tile] is land (by terrain): a quay there lies on the shore (N1).
func _is_land(tile: Vector2i) -> bool:
	var terrain := terrain_at(tile) if grid.is_inside(tile) else null
	return terrain != null and terrain.sail_depth == 0 and terrain.walkable


## Whether [param tile] is land people stand on (a quay grows from it).
func _is_shore_land(tile: Vector2i) -> bool:
	if not grid.is_inside(tile) or grid.has_quay(tile):
		return false
	var terrain := terrain_at(tile)
	return terrain != null and terrain.walkable


## &"" when a quay tile can be ordered on [param tile] on its own (open sea, nothing there);
## the reach from the shore and the way to the open sea are checked by [method quay_plan].
func quay_error(tile: Vector2i) -> StringName:
	if not grid.is_inside(tile):
		return &"outside_map"
	if grid.has_quay(tile):
		return &"already_quay"
	if not paving.is_empty() and paving_site_at(tile) != 0:
		return &"already_ordered"
	if sail_depth(tile) == 0:
		# On land: free ground at most QUAY_LAND_REACH tiles from the sea.
		var error := _free_ground_error(tile)
		if error != &"":
			return error
		return &"" if _near_sea(tile, QUAY_LAND_REACH) else &"too_far_from_sea"
	if grid.occupant(tile) != 0 or grid.is_blocked(tile) or resources.has_node(tile):
		return &"tile_occupied"
	for building: BuildingState in buildings.all():
		if building.def.has_berth() and building.berth_tile() == tile:
			return &"keeps_berth"
	if fairway.has(tile):
		return &"keeps_fairway"
	for ship: ShipUnit in ships.values():
		if ship.tile() == tile:
			return &"tile_has_ship"
	return &""


## Which of [param tiles] can be ordered as quay together: {"tiles": accepted tiles in the
## order a builder lays them (from the shore outwards), "errors": tile -> reason for the
## rest}. A tile must be within QUAY_REACH quay tiles of the shore (over existing quay,
## ordered quay and the other tiles); all of them are refused (&"blocks_sea") when they would
## cut a berth, a shoal or a ship off the open sea (the edge of the map).
func quay_plan(tiles: Array[Vector2i]) -> Dictionary:
	var errors: Dictionary[Vector2i, StringName] = {}
	var wanted: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in tiles:
		var error := quay_error(tile)
		if error == &"":
			wanted[tile] = true
		elif not errors.has(tile):
			errors[tile] = error
	# Distance from the shore over quay (existing, ordered and wanted), shore tiles first.
	var ordered: Dictionary[Vector2i, bool] = {}
	for paving_site: PavingSite in paving.values():
		if paving_site.is_quay():
			for tile: Vector2i in paving_site.tiles:
				ordered[tile] = true
	# Flood from the shore over all quay tiles (existing, ordered, wanted).
	var quay_tiles: Array[Vector2i] = []
	quay_tiles.append_array(wanted.keys())
	quay_tiles.append_array(ordered.keys())
	if grid.quay_count() > 0:
		for y: int in grid.size.y:
			for x: int in grid.size.x:
				if grid.has_quay(Vector2i(x, y)):
					quay_tiles.append(Vector2i(x, y))
	var depth: Dictionary[Vector2i, int] = {}
	var queue: Array[Vector2i] = []
	for tile: Vector2i in quay_tiles:
		# A quay on land is shore itself (it counts no reach).
		if _is_land(tile) and not depth.has(tile):
			depth[tile] = 0
			queue.append(tile)
		for step: Vector2i in _STEPS4:
			var land := tile + step
			if not depth.has(land) and _is_shore_land(land):
				depth[land] = 0
				queue.append(land)
	var shore := queue.duplicate()
	var is_quay := func(t: Vector2i) -> bool:
		return wanted.has(t) or ordered.has(t) or grid.has_quay(t)
	# A diagonal step counts as one tile of reach (8-direction quays, N1) when a tile beside it
	# is quay too, so people can walk it.
	var in_reach: Dictionary[Vector2i, bool] = {}
	var head := 0
	while head < queue.size():
		var tile := queue[head]
		head += 1
		if wanted.has(tile) and depth[tile] <= QUAY_REACH:
			in_reach[tile] = true
		for step: Vector2i in _STEPS8:
			var next := tile + step
			if depth.has(next) or not is_quay.call(next):
				continue
			if step.x != 0 and step.y != 0 and not (is_quay.call(tile + Vector2i(step.x, 0)) \
					or is_quay.call(tile + Vector2i(0, step.y))):
				continue
			depth[next] = depth[tile] + 1
			queue.append(next)
	# The order a builder lays them: each next to the shore or to quay laid before it.
	var accepted: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	queue = shore
	for t: Vector2i in queue:
		seen[t] = true
		if in_reach.has(t):
			accepted.append(t)   # on land: laid from the ground beside it
	head = 0
	while head < queue.size():
		var tile := queue[head]
		head += 1
		for step: Vector2i in _STEPS4:
			var next := tile + step
			if seen.has(next) or not (in_reach.has(next) or ordered.has(next) or grid.has_quay(next)):
				continue
			seen[next] = true
			queue.append(next)
			if in_reach.has(next):
				accepted.append(next)
	for tile: Vector2i in wanted:
		if not accepted.has(tile):
			errors[tile] = &"too_far_from_shore" if depth.has(tile) else &"not_at_shore"
	if not accepted.is_empty():
		var blocked: Dictionary[Vector2i, bool] = ordered.duplicate()
		var cut := false
		var before := _sea_reach(blocked)
		for tile: Vector2i in accepted:
			blocked[tile] = true
		var after := _sea_reach(blocked)
		for target: Vector2i in before:
			if not after.has(target):
				cut = true
				break
		if cut:
			for tile: Vector2i in accepted:
				errors[tile] = &"blocks_sea"
			accepted.clear()
	return {"tiles": accepted, "errors": errors}


## Berths, shoals and ships the open sea (water on the edge of the map) reaches, by boat and,
## for berths cogs use, by cog; [param blocked] tiles count as quay.
func _sea_reach(blocked: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var targets: Dictionary[Vector2i, int] = {}   # tile -> 1 boat, 2 cog
	for building: BuildingState in buildings.all():
		if building.def.has_berth():
			targets[building.berth_tile()] = 2 if building.def.berth_fairway else 1
	for ship: ShipUnit in ships.values():
		targets[ship.tile()] = maxi(int(targets.get(ship.tile(), 0)), 1)
	for tile: Vector2i in resources.tiles_with_nodes():
		if sail_depth(tile) > 0:
			targets[tile] = maxi(int(targets.get(tile, 0)), 1)
	var reached: Dictionary[Vector2i, bool] = {}
	if targets.is_empty():
		return reached
	for cog: bool in [false, true]:
		var seen := _sea_flood(blocked, cog)
		for tile: Vector2i in targets:
			if (targets[tile] == 2) == cog and seen[tile.y * grid.size.x + tile.x] == 1:
				reached[tile] = true
	return reached


## Flood over open sea from the edge of the map (4 neighbours); 1 = reached.
func _sea_flood(blocked: Dictionary[Vector2i, bool], cog: bool) -> PackedByteArray:
	var w := grid.size.x
	var seen := PackedByteArray()
	seen.resize(w * grid.size.y)
	var queue: Array[Vector2i] = []
	var sailable := func(t: Vector2i) -> bool:
		if not grid.is_inside(t) or blocked.has(t):
			return false
		var depth := sail_depth(t)
		if depth == 0 or grid.occupant(t) != 0 or grid.is_blocked(t):
			return false
		return not cog or depth >= 2 or fairway.has(t)
	for x: int in w:
		for t: Vector2i in [Vector2i(x, 0), Vector2i(x, grid.size.y - 1)]:
			if sailable.call(t) and seen[t.y * w + t.x] == 0:
				seen[t.y * w + t.x] = 1
				queue.append(t)
	for y: int in grid.size.y:
		for t: Vector2i in [Vector2i(0, y), Vector2i(w - 1, y)]:
			if sailable.call(t) and seen[t.y * w + t.x] == 0:
				seen[t.y * w + t.x] = 1
				queue.append(t)
	var head := 0
	while head < queue.size():
		var tile := queue[head]
		head += 1
		for step: Vector2i in _STEPS4:
			var next := tile + step
			if not grid.is_inside(next) or seen[next.y * w + next.x] == 1 or not sailable.call(next):
				continue
			seen[next.y * w + next.x] = 1
			queue.append(next)
	return seen


## Orders quay of [param quay] (TileGrid.PIER or STONE_QUAY) on [param tiles] (from
## quay_plan, in its order): porters bring planks or stone, a builder lays it tile by tile.
## Ships keep off the tiles at once. Returns the site id.
func order_quay(tiles: Array[Vector2i], quay: int) -> int:
	if tiles.is_empty():
		return 0
	var paving_site := PavingSite.new(ids.take(), tiles.duplicate(), data, PavingSite.kind_for_quay(quay))
	paving[paving_site.id] = paving_site
	jobs.add(paving_site.good(), tiles.size() * paving_site.per_tile(), 0, paving_site.id)
	for tile: Vector2i in tiles:
		refresh_tile(tile)
	events.emit(&"quay_ordered", {"site": paving_site.id, "tiles": tiles.size(), "quay": quay})
	return paving_site.id


## &"" when the quay (or the ordered quay) on [param tile] can be taken away: nothing
## stands on it, it is no door, and the rest of the quay stays joined to the shore.
func remove_quay_error(tile: Vector2i) -> StringName:
	if not grid.is_inside(tile):
		return &"outside_map"
	var ordered := not paving.is_empty() and paving_site_at(tile) != 0 \
			and (paving[paving_site_at(tile)] as PavingSite).is_quay()
	if ordered:
		return &""
	if not grid.has_quay(tile):
		return &"no_quay"
	if grid.occupant(tile) != 0 or _pile_at(tile) != 0:
		return &"tile_occupied"
	for agent: Agent in agents.all():
		if agent.tile() == tile:
			return &"tile_has_people"
	for building: BuildingState in buildings.all():
		if door_tiles(building).has(tile):
			return &"blocks_access"
	# The rest of the quay must still reach the shore (people on it, buildings on it).
	var rest: Dictionary[Vector2i, bool] = {}
	var queue: Array[Vector2i] = []
	for y: int in grid.size.y:
		for x: int in grid.size.x:
			var t := Vector2i(x, y)
			if t == tile or not grid.has_quay(t):
				continue
			rest[t] = true
	var joined: Dictionary[Vector2i, bool] = {}
	for t: Vector2i in rest:
		if _is_land(t):
			joined[t] = true
			queue.append(t)
			continue
		for step: Vector2i in _STEPS4:
			if _is_shore_land(t + step):
				joined[t] = true
				queue.append(t)
				break
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for step: Vector2i in _STEPS4:
			var next := t + step
			if rest.has(next) and not joined.has(next):
				joined[next] = true
				queue.append(next)
	return &"" if joined.size() == rest.size() else &"cuts_quay"


## Takes the quay (or the order for it) off [param tile]; checked with remove_quay_error.
func remove_quay(tile: Vector2i) -> void:
	var id := paving_site_at(tile) if not paving.is_empty() else 0
	if id != 0:
		_withdraw_paving(tile)
	else:
		grid.set_quay(tile, 0)
		refresh_fairways()
		events.emit(&"quay_changed", {"tile": tile, "quay": 0})
	refresh_tile(tile)


# --- Bridges (B1) ---------------------------------------------------------------------------

## How many tiles of water a bridge may span (ROADMAP B1; a diagonal step counts as one).
const BRIDGE_REACH := 8


## Whether a bridge may stand on [param tile] by its terrain: river water, a ford or a lake
## (no sea: quays are for the sea, N1).
func is_bridgeable(tile: Vector2i) -> bool:
	if not grid.is_inside(tile):
		return false
	var terrain := terrain_at(tile)
	if terrain == null or terrain.sail_depth > 0:
		return false
	return terrain.is_kind(&"water") or terrain.id == &"ford"


## Whether [param tile] is a bank a bridge can rest on: walkable land (or a bridge already
## there) people can step on.
func _bridge_bank(tile: Vector2i) -> bool:
	if not grid.is_inside(tile):
		return false
	if grid.has_bridge(tile):
		return true
	return not is_bridgeable(tile) and _is_land(tile) and nav.is_walkable(tile)


## The main line of a bridge dragged from [param from] to [param to]: snapped to one of 8
## directions, like quays and walls (decision 2026-11-08), without the wedges.
static func bridge_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var d := to - from
	var ax := absi(d.x)
	var ay := absi(d.y)
	var dir := Vector2i(signi(d.x), signi(d.y))
	var n := 0
	if ax >= 2 * ay:
		dir.y = 0
		n = ax
	elif ay >= 2 * ax:
		dir.x = 0
		n = ay
	else:
		n = roundi((ax + ay) / 2.0)
	var tiles: Array[Vector2i] = []
	for i: int in n + 1:
		tiles.append(from + dir * i)
	return tiles


## A bridge dragged from [param from] to [param to] (B1): {"tiles": the tiles to lay in the
## order a builder lays them (from the near bank, each diagonal step's wedges before the step),
## "line": every tile of the drag (main line and wedges), "error": &"" or why it cannot be
## built}. It starts on the last land tile before the water and must reach land again within
## BRIDGE_REACH tiles of water; all of it or nothing.
func bridge_plan(from: Vector2i, to: Vector2i) -> Dictionary:
	var main := bridge_line(from, to)
	var line: Array[Vector2i] = main.duplicate()
	var result := {"tiles": [] as Array[Vector2i], "line": line, "error": &""}
	var first := -1
	for i: int in main.size():
		if is_bridgeable(main[i]) and not grid.has_bridge(main[i]):
			first = i
			break
	if first < 0:
		result["error"] = &"no_water"
		return result
	if first == 0 or not _bridge_bank(main[first - 1]):
		result["error"] = &"bridge_needs_bank"
		return result
	var last := first
	while last + 1 < main.size() and is_bridgeable(main[last + 1]) and not grid.has_bridge(main[last + 1]):
		last += 1
	if last + 1 >= main.size():
		result["error"] = &"bridge_needs_far_bank"
		return result
	if not _bridge_bank(main[last + 1]):
		result["error"] = &"bridge_needs_far_bank"
		return result
	result["ends"] = [main[first - 1], main[last + 1]] as Array[Vector2i]
	if last - first + 1 > BRIDGE_REACH:
		result["error"] = &"bridge_too_long"
		return result
	# The bridge starts and ends on the land (owner's request 2026-11-08): a ramp tile on each
	# bank, and on a diagonal bridge the wedges beside its steps whether over water or land.
	var tiles: Array[Vector2i] = []
	var dir := main[1] - main[0] if main.size() > 1 else Vector2i.ZERO
	var add := func(t: Vector2i) -> void:
		if not line.has(t):
			line.append(t)
		if not grid.has_bridge(t) and not tiles.has(t):
			tiles.append(t)
	add.call(main[first - 1])
	for i: int in range(first - 1, last + 1):
		if dir.x != 0 and dir.y != 0:
			add.call(main[i] + Vector2i(dir.x, 0))
			add.call(main[i] + Vector2i(0, dir.y))
		add.call(main[i + 1])
	for tile: Vector2i in tiles:
		var error := bridge_tile_error(tile) if is_bridgeable(tile) else ramp_error(tile)
		if error != &"":
			result["error"] = error
	if result["error"] == &"":
		result["tiles"] = tiles
	return result


## The river crossings of a road or cobbles dragged along [param tiles] (owner's request
## 2026-11-08: a road over a river brings a timber bridge, cobbles a stone one). Each is
## {"from": land before the water, "to": land after it, "plan": bridge_plan(from, to),
## "link": land tiles leading from the bridge's far ramp back to the dragged road when the
## bridge, straightened, ends beside it}. Water a bridge stands on (or is ordered on) already
## is passed by.
func road_crossings(tiles: Array[Vector2i]) -> Array[Dictionary]:
	var crossings: Array[Dictionary] = []
	var i := 1
	while i < tiles.size():
		if not is_bridgeable(tiles[i]) or is_bridgeable(tiles[i - 1]):
			i += 1
			continue
		var j := i
		var taken := false
		while j < tiles.size() and is_bridgeable(tiles[j]):
			if grid.has_bridge(tiles[j]) or bridge_site_at(tiles[j]) != 0:
				taken = true
			j += 1
		if j >= tiles.size() or taken:
			i = j
			continue
		var from := tiles[i - 1]
		var to := tiles[j]
		var plan := bridge_plan(from, to)
		var link: Array[Vector2i] = []
		var ends: Array = plan.get("ends", [])
		if not ends.is_empty():
			var at: Vector2i = ends[1]
			while at != to:
				var d := to - at
				if absi(d.x) >= absi(d.y):
					at.x += signi(d.x)
				else:
					at.y += signi(d.y)
				if at != to:
					link.append(at)
		crossings.append({"from": from, "to": to, "plan": plan, "link": link})
		i = j
	return crossings


## &"" when a bridge tile can be ordered on [param tile] on its own (water, nothing there).
func bridge_tile_error(tile: Vector2i) -> StringName:
	if not grid.is_inside(tile):
		return &"outside_map"
	if grid.has_bridge(tile):
		return &"already_bridge"
	if not paving.is_empty() and paving_site_at(tile) != 0:
		return &"already_ordered"
	if not is_bridgeable(tile):
		return &"not_water"
	if grid.occupant(tile) != 0 or grid.is_blocked(tile) or resources.has_node(tile):
		return &"tile_occupied"
	return &""


## &"" when a bridge may come on to the land at [param tile] (a ramp, B1): walkable land with
## no building, field, pile, wall, quay or rock; a road may lie there (it stays), and a tree
## is cut down when the ramp is laid.
func ramp_error(tile: Vector2i) -> StringName:
	if not grid.is_inside(tile):
		return &"outside_map"
	if grid.has_bridge(tile):
		return &"already_bridge"
	if not paving.is_empty() and paving_site_at(tile) != 0:
		return &"already_ordered"
	var terrain := terrain_at(tile)
	if terrain == null or not terrain.walkable or terrain.sail_depth > 0:
		return &"bridge_needs_bank"
	if grid.occupant(tile) != 0 or grid.is_blocked(tile) or grid.has_quay(tile) or fields.has_field(tile) \
			or _pile_at(tile) != 0 or resources.blocks_movement(tile):
		return &"tile_occupied"
	if not walls.is_empty() and (walls.kind(tile) != Walls.NONE or walls.wedges.has(tile) \
			or walls.fort_tiles.has(tile)):
		return &"tile_occupied"
	return &""


## Orders a bridge of [param bridge] (TileGrid.TIMBER_BRIDGE or STONE_BRIDGE) on [param tiles]
## (from bridge_plan, in its order): porters bring planks or stone, a builder lays it tile by
## tile from the bank. Returns the site id.
func order_bridge(tiles: Array[Vector2i], bridge: int) -> int:
	if tiles.is_empty():
		return 0
	var paving_site := PavingSite.new(ids.take(), tiles.duplicate(), data, PavingSite.kind_for_bridge(bridge))
	paving[paving_site.id] = paving_site
	jobs.add(paving_site.good(), tiles.size() * paving_site.per_tile(), 0, paving_site.id)
	events.emit(&"bridge_ordered", {"site": paving_site.id, "tiles": tiles.size(), "bridge": bridge})
	return paving_site.id


## The laid bridge tiles joined to [param tile] (8 neighbours: diagonal bridges).
func bridge_tiles_at(tile: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if not grid.has_bridge(tile):
		return found
	var seen: Dictionary[Vector2i, bool] = {tile: true}
	found.append(tile)
	var head := 0
	while head < found.size():
		var t := found[head]
		head += 1
		for step: Vector2i in _STEPS8:
			var next := t + step
			if not seen.has(next) and grid.has_bridge(next):
				seen[next] = true
				found.append(next)
	return found


## The bridge site ordered on [param tile], or 0.
func bridge_site_at(tile: Vector2i) -> int:
	var id := paving_site_at(tile) if not paving.is_empty() else 0
	return id if id != 0 and (paving[id] as PavingSite).is_bridge() else 0


## &"" when the bridge on [param tile] (the whole bridge) or the order for it can be taken
## away: nobody stands on it and nothing lies on it.
func remove_bridge_error(tile: Vector2i) -> StringName:
	if not grid.is_inside(tile):
		return &"outside_map"
	if bridge_site_at(tile) != 0:
		return &""
	if not grid.has_bridge(tile):
		return &"no_bridge"
	var tiles := bridge_tiles_at(tile)
	for t: Vector2i in tiles:
		if _pile_at(t) != 0:
			return &"tile_occupied"
	for agent: Agent in agents.all():
		if tiles.has(agent.tile()):
			return &"tile_has_people"
	return &""


## Takes the whole bridge on [param tile] away, with any order still going on beside it, or
## only the order when [param tile] is ordered; checked with remove_bridge_error.
func remove_bridge(tile: Vector2i) -> void:
	var id := bridge_site_at(tile)
	if id != 0:
		_close_bridge_site(paving[id])
		return
	var tiles := bridge_tiles_at(tile)
	for paving_site: PavingSite in paving.values():
		if not paving_site.is_bridge():
			continue
		for t: Vector2i in paving_site.tiles:
			var beside := false
			for step: Vector2i in _STEPS8:
				if tiles.has(t + step):
					beside = true
			if beside:
				_close_bridge_site(paving_site)
				break
	for t: Vector2i in tiles:
		grid.set_bridge(t, 0)
		refresh_tile(t)
	events.emit(&"bridge_changed", {"tiles": tiles, "bridge": 0})


## Closes a bridge order; material already brought goes on the ground where the builder
## stands (on the bank).
func _close_bridge_site(paving_site: PavingSite) -> void:
	var stand := paving_stand(paving_site)
	_close_paving(paving_site, stand)


func _free_ground_error(tile: Vector2i) -> StringName:
	var terrain := terrain_at(tile)
	if terrain != null and not terrain.buildable:
		return &"terrain_not_buildable"
	if grid.is_blocked(tile) or grid.occupant(tile) != 0 or resources.has_node(tile):
		return &"tile_occupied"
	if fields.has_field(tile) or grid.has_road(tile) or _pile_at(tile) != 0:
		return &"tile_occupied"
	if grid.has_quay(tile) or grid.has_bridge(tile) or (not paving.is_empty() and paving_site_at(tile) != 0):
		return &"tile_occupied"
	if not walls.is_empty() and (walls.kind(tile) != Walls.NONE or walls.wedges.has(tile) \
			or walls.fort_tiles.has(tile)):
		return &"tile_occupied"
	return &""


# --- Walls (M7 part 2) ----------------------------------------------------------------------

## &"" when a wall of [param wall_kind] (Walls.PALISADE, STONE or STAIRS) can be ordered on
## [param tile] on its own: free buildable ground. Stairs must lean against a stone wall or
## a gatehouse or tower (or one ordered in [param planned]).
func wall_error(tile: Vector2i, wall_kind: int, planned: Dictionary[Vector2i, bool] = {}) -> StringName:
	if not grid.is_inside(tile):
		return &"outside_map"
	if walls.kind(tile) != Walls.NONE or walls.fort_tiles.has(tile):
		return &"already_wall"
	# A wedge only fills the corner of a slanting wall: a wall may take its place.
	if walls.wedges.has(tile) and wall_kind != Walls.STAIRS:
		return &""
	var error := _free_ground_error(tile)
	if error != &"":
		return error
	var terrain := terrain_at(tile)
	if terrain != null and not terrain.walkable:
		return &"terrain_not_buildable"
	if wall_kind == Walls.STAIRS and stairs_dir_for(tile, planned) < 0:
		return &"needs_stone_wall"
	return &""


## Direction index (Walls.DIRS) of stairs on [param tile]: towards a neighbouring stone wall,
## gatehouse or tower (laid, or planned in [param planned]); -1 when none.
func stairs_dir_for(tile: Vector2i, planned: Dictionary[Vector2i, bool] = {}) -> int:
	for d: int in Walls.DIRS.size():
		var t: Vector2i = tile + Walls.DIRS[d]
		if walls.is_mass(t) or planned.has(t) or _ordered_wall(t) == Walls.STONE:
			return d
	return -1


## Walls value of the wall ordered (not laid yet) on [param tile], Walls.NONE if none.
func _ordered_wall(tile: Vector2i) -> int:
	if paving.is_empty():
		return Walls.NONE
	var id := paving_site_at(tile)
	return (paving[id] as PavingSite).wall_value() if id != 0 else Walls.NONE


## Which of [param tiles] can be ordered as walls of [param wall_kind] together:
## {"tiles": accepted tiles in drag order, "errors": tile -> reason for the rest}. Stone walls
## make wedges between diagonal blocks (Walls.wedges_of): a wedge must fall on free ground.
## Nothing is accepted (&"blocks_access") when the walls, once laid, would cut a building,
## a ground pile or a person off from the rest of the town: leave a gap or a gatehouse.
func wall_plan(tiles: Array[Vector2i], wall_kind: int) -> Dictionary:
	var errors: Dictionary[Vector2i, StringName] = {}
	var accepted: Array[Vector2i] = []
	var planned: Dictionary[Vector2i, bool] = {}
	if wall_kind == Walls.STONE:
		for tile: Vector2i in tiles:
			planned[tile] = true
	for tile: Vector2i in tiles:
		if accepted.has(tile) or errors.has(tile):
			continue
		var error := wall_error(tile, wall_kind, planned)
		if error == &"":
			accepted.append(tile)
		else:
			errors[tile] = error
	# Every stone tile, laid or ordered, and the wedges they will make.
	var future := _future_mass()
	if wall_kind == Walls.STONE and not accepted.is_empty():
		for tile: Vector2i in accepted:
			future[tile] = true
		var around: Array[Vector2i] = []
		for tile: Vector2i in accepted:
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					around.append(tile + Vector2i(dx, dy))
		var wedges := Walls.wedges_of(func(t: Vector2i) -> bool: return future.has(t), around)
		for wedge: Vector2i in wedges:
			if walls.wedges.has(wedge) or _free_ground_error(wedge) == &"":
				continue
			# The blocks that make this wedge are refused.
			for tile: Vector2i in accepted.duplicate():
				if absi(tile.x - wedge.x) <= 1 and absi(tile.y - wedge.y) <= 1 and tile != wedge:
					accepted.erase(tile)
					errors[tile] = &"wedge_blocked"
	if not accepted.is_empty() and wall_kind != Walls.STAIRS:
		var blocked := _future_wall_blocks(accepted, wall_kind)
		if _walls_cut_off(blocked):
			for tile: Vector2i in accepted:
				errors[tile] = &"blocks_access"
			accepted.clear()
	return {"tiles": accepted, "errors": errors}


## Stone mass, laid and ordered: tile -> true.
func _future_mass() -> Dictionary[Vector2i, bool]:
	var mass: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in walls.tiles():
		if walls.is_stone(tile):
			mass[tile] = true
	for tile: Vector2i in walls.fort_tiles:
		mass[tile] = true
	for paving_site: PavingSite in paving.values():
		if paving_site.kind == PavingSite.KIND_STONE_WALL:
			for tile: Vector2i in paving_site.tiles:
				mass[tile] = true
	return mass


## Tiles not solid yet that will be once the ordered walls and [param tiles] are laid.
func _future_wall_blocks(tiles: Array[Vector2i], wall_kind: int) -> Dictionary[Vector2i, bool]:
	var blocked: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in tiles:
		blocked[tile] = true
	var mass := _future_mass()
	if wall_kind == Walls.STONE:
		for tile: Vector2i in tiles:
			mass[tile] = true
	for paving_site: PavingSite in paving.values():
		if paving_site.kind == PavingSite.KIND_PALISADE or paving_site.kind == PavingSite.KIND_STONE_WALL:
			for tile: Vector2i in paving_site.tiles:
				blocked[tile] = true
	var around: Array[Vector2i] = []
	around.assign(mass.keys())
	for wedge: Vector2i in Walls.wedges_of(func(t: Vector2i) -> bool: return mass.has(t), around):
		if not walls.wedges.has(wedge):
			blocked[wedge] = true
	return blocked


## Whether making [param blocked] solid cuts some door, ground pile or person off from where
## the seat (or the first building) is reached now.
func _walls_cut_off(blocked: Dictionary[Vector2i, bool]) -> bool:
	var targets: Dictionary[Vector2i, bool] = {}
	for building: BuildingState in buildings.all():
		for door: Vector2i in door_tiles(building):
			targets[door] = true
	if targets.is_empty():
		return false
	for pile: GroundPile in piles.values():
		targets[pile.tile] = true
	for agent: Agent in agents.all():
		if nav.is_walkable(agent.tile()):
			targets[agent.tile()] = true
	var start := Agent.NO_TILE
	var hall := seat()
	if hall != null:
		start = door_tile(hall)
	if start == Agent.NO_TILE or blocked.has(start):
		for door: Vector2i in targets:
			if not blocked.has(door):
				start = door
				break
	if start == Agent.NO_TILE:
		return false
	var before := nav.reachable(start, targets)
	var after := nav.reachable(start, before, blocked)
	for tile: Vector2i in before:
		if not after.has(tile) and not blocked.has(tile):
			return true
	return false


## Orders [param tiles] (checked with wall_plan) as walls of [param wall_kind]: porters bring
## the wood or stone, a builder lays one tile after another. Stairs get one site per tile
## (each has its own direction). Returns the (last) site id.
func order_walls(tiles: Array[Vector2i], wall_kind: int) -> int:
	if tiles.is_empty():
		return 0
	var site_kind := PavingSite.kind_for_wall(wall_kind)
	var groups: Array[Array] = []
	if wall_kind == Walls.STAIRS:
		for tile: Vector2i in tiles:
			groups.append([tile])
	else:
		groups.append(tiles)
	var id := 0
	for group: Array in groups:
		var list: Array[Vector2i] = []
		list.assign(group)
		var paving_site := PavingSite.new(ids.take(), list, data, site_kind)
		if wall_kind == Walls.STAIRS:
			paving_site.stairs_dir = maxi(stairs_dir_for(list[0]), 0)
		paving[paving_site.id] = paving_site
		jobs.add(paving_site.good(), list.size() * paving_site.per_tile(), 0, paving_site.id)
		for tile: Vector2i in list:
			refresh_tile(tile)
		id = paving_site.id
		events.emit(&"wall_ordered", {"site": id, "tiles": list.size(), "wall": wall_kind})
	return id


## Whether the next wall tile of [param paving_site] can be laid: no ground pile on it or on
## a wedge it makes. People standing there step aside when it is laid.
func wall_can_lay(paving_site: PavingSite) -> bool:
	var tile := paving_site.next_tile()
	if tile == Agent.NO_TILE or _pile_at(tile) != 0:
		return false
	for wedge: Vector2i in _wedges_if_laid(tile, paving_site.wall_value()):
		if _pile_at(wedge) != 0 or grid.occupant(wedge) != 0 or grid.has_road(wedge):
			return false
	return true


func _wedges_if_laid(tile: Vector2i, wall_value: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if wall_value != Walls.STONE:
		return result
	var around: Array[Vector2i] = []
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			around.append(tile + Vector2i(dx, dy))
	var mass := func(t: Vector2i) -> bool: return t == tile or walls.is_mass(t)
	for wedge: Vector2i in Walls.wedges_of(mass, around):
		if not walls.wedges.has(wedge):
			result.append(wedge)
	return result


## Lays a wall tile (a builder finished it): people on it or on its new wedges step aside.
func lay_wall(tile: Vector2i, wall_value: int) -> void:
	var newly: Array[Vector2i] = [tile]
	newly.append_array(_wedges_if_laid(tile, wall_value))
	walls.set_kind(tile, wall_value)
	_refresh_wall_tiles(tile)
	for t: Vector2i in newly:
		if walls.blocks_ground(t):
			_step_aside(t)
	events.emit(&"wall_changed", {"tile": tile, "wall": wall_value})


## Refreshes the navigation around a changed wall tile (its wedges reach 2 tiles).
func _refresh_wall_tiles(tile: Vector2i) -> void:
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var t := tile + Vector2i(dx, dy)
			if grid.is_inside(t):
				refresh_tile(t)


## Moves everybody standing on [param tile] (now solid) to the nearest walkable tile.
func _step_aside(tile: Vector2i) -> void:
	for agent: Agent in agents.all():
		if agent.tile() != tile:
			continue
		var best := Agent.NO_TILE
		var best_d := INF
		for step: Vector2i in _STEPS8:
			var t := tile + step
			if nav.is_walkable(t) and (agent.pos - IsoMath.tile_center(t)).length() < best_d:
				best_d = (agent.pos - IsoMath.tile_center(t)).length()
				best = t
		if best == Agent.NO_TILE:
			continue
		agent.pos = IsoMath.tile_center(best)
		agent.prev_pos = agent.pos
		if agent.path_state == Agent.PathState.MOVING:
			var goal := agent.path_goal
			agent.clear_path()
			agent.path_goal = goal
			agent.path_state = Agent.PathState.WAITING
			paths.push(agent.id)


## &"" when the wall tile (or stairs) at [param tile] can be pulled down.
func remove_wall_error(tile: Vector2i) -> StringName:
	if walls.kind(tile) == Walls.NONE:
		return &"no_wall"
	return &""


## Pulls down a wall tile: part of its material goes on the ground beside it.
func remove_wall(tile: Vector2i) -> void:
	var wall_value := walls.kind(tile)
	if wall_value == Walls.NONE:
		return
	walls.set_kind(tile, Walls.NONE)
	_refresh_wall_tiles(tile)
	var site_kind := PavingSite.kind_for_wall(mini(wall_value, Walls.STAIRS))
	var amount := floori(PavingSite.per_tile_of(site_kind) * Construction.REFUND_SHARE)
	if amount > 0:
		drop_goods(tile, PavingSite.good_of(site_kind), amount)
	# Stairs leaning on a wall that is gone go too.
	for d: int in Walls.DIRS.size():
		var t: Vector2i = tile - Walls.DIRS[d]
		if walls.stairs_dir(t) == d and not walls.is_mass(tile):
			remove_wall(t)
	events.emit(&"wall_changed", {"tile": tile, "wall": Walls.NONE})


## Damage to a wall tile in a fight (M7 part 2); true when it falls (it leaves no material).
func damage_wall(tile: Vector2i, amount: int) -> bool:
	if not walls.damage(tile, amount):
		return false
	for foot: Vector2i in mil.ladders.keys():
		if mil.ladders[foot] == tile:
			Troops.remove_ladder(self, foot)
	_refresh_wall_tiles(tile)
	for d: int in Walls.DIRS.size():
		var t: Vector2i = tile - Walls.DIRS[d]
		if walls.stairs_dir(t) == d:
			walls.set_kind(t, Walls.NONE)
			refresh_tile(t)
	events.emit(&"wall_changed", {"tile": tile, "wall": Walls.NONE, "destroyed": true})
	return true


## Places a finished building at once when it fits (setup code and screenshots); null if not.
func execute_place(id: StringName, origin: Vector2i, orientation: int) -> BuildingState:
	var def := data.get_building(id)
	var error := placement_error(def, origin, orientation)
	if error != &"":
		push_warning("cannot place %s at %s: %s" % [id, origin, error])
		return null
	return add_building(def, origin, true, orientation)


## A building's life ran out in a fight (M7 part 2): a gatehouse stands open to everybody.
func break_building(building: BuildingState) -> void:
	building.hp = 0
	for tile: Vector2i in building.passage_tiles():
		refresh_tile(tile)
	events.emit(&"building_broken", {"building": building.id, "def": building.def.id})


func _add_fort(building: BuildingState) -> void:
	if building.def.has_crown():
		walls.add_fort(building.tiles(), building.id)
	else:
		_clear_walls_under(building)
	for tile: Vector2i in building.passage_tiles():
		passages[tile] = building.id
	for tile: Vector2i in building.tiles():
		_refresh_wall_tiles(tile)


## A palisade gate takes the place of the palisade it stands in (it is no stone mass).
func _clear_walls_under(building: BuildingState) -> void:
	for tile: Vector2i in building.tiles():
		if walls.kind(tile) != Walls.NONE:
			walls.set_kind(tile, Walls.NONE)


func _remove_fort(building: BuildingState) -> void:
	walls.remove_fort(building.id)
	for tile: Vector2i in building.passage_tiles():
		passages.erase(tile)
	for tile: Vector2i in building.tiles():
		_refresh_wall_tiles(tile)


# --- Agents --------------------------------------------------------------------------------

func spawn_agent(kind: StringName, tile: Vector2i) -> Agent:
	var agent := Agent.new(ids.take(), kind, IsoMath.tile_center(tile))
	agents.add(agent)
	events.emit(&"agent_spawned", {"agent": agent.id, "kind": kind, "tile": tile})
	return agent


## Takes a person off the map (job lost, errand done, moved in): its task is cancelled,
## whatever it carries goes on the ground, and nothing stays reserved.
func remove_agent(agent: Agent) -> void:
	if not agents.has_agent(agent.id):
		return
	if agent.task != null:
		TaskRunner.fail(self, agent)
	release_agent(agent)
	if agent.vehicle == Ships.ABOARD:
		Ships.leave_ship(self, agent)
	drop_carried(agent)
	var workplace := buildings.get_building(agent.workplace_id)
	if workplace != null:
		workplace.workers.erase(agent.id)
	var home := buildings.get_building(agent.home_id)
	if home != null and home.house != null:
		for good: StringName in home.house.errands.keys():
			if home.house.errands[good] == agent.id:
				home.house.errands.erase(good)
	agents.remove(agent.id)
	events.emit(&"agent_removed", {"agent": agent.id, "kind": agent.kind})


## Releases every reservation and claim the agent holds.
func release_agent(agent: Agent) -> void:
	# The same stores as all_storages(), without building the dictionary (M4b-3: this runs
	# whenever a task ends early or someone leaves).
	for building: BuildingState in buildings.all():
		for store: Stockpile in [building.stock, building.supply, building.yard]:
			if store != null and store.reservation_count() > 0:
				store.release_owner(agent.id)
	for site: ConstructionSite in sites.values():
		site.stock.release_owner(agent.id)
	for paving_site: PavingSite in paving.values():
		paving_site.stock.release_owner(agent.id)
	for build: ShipBuild in ship_builds.values():
		build.stock.release_owner(agent.id)
	for ship: ShipUnit in ships.values():
		ship.hold.release_owner(agent.id)
	for pile: GroundPile in piles.values():
		pile.stock.release_owner(agent.id)
	if merchant.wagon != null:
		merchant.wagon.release_owner(agent.id)
	if departure != null and departure.wagon != null:
		departure.wagon.release_owner(agent.id)
	for wagon: RouteWagon in route_wagons.values():
		wagon.store.release_owner(agent.id)
	fields.release_owner(agent.id)
	wild.release_hunter(agent.id)
	if agent.claimed_node != Agent.NO_TILE:
		resources.release(agent.claimed_node, agent.id)
		agent.claimed_node = Agent.NO_TILE


## Puts what the agent carries on the ground at its tile.
## A worker of [param agent]'s workplace made [param amount] of [param good] (M6
## calibration): only the main output of the work cycle is measured (WorkCycle.primary).
func note_output(agent: Agent, good: StringName, amount: int) -> void:
	var workplace := buildings.get_building(agent.workplace_id)
	if workplace != null and WorkCycle.of(workplace.def, data).primary == good:
		production.note_output(workplace.id, amount, tick)


func drop_carried(agent: Agent) -> void:
	if agent.is_carrying():
		drop_goods(agent.tile(), agent.carry_good, agent.carry_amount)
		agent.carry_good = &""
		agent.carry_amount = 0


# --- Storages ------------------------------------------------------------------------------

## Storage id of the production yard of building [param building_id] (M4b-2): the negative
## building id, so a yard needs no entity id of its own.
static func yard_id(building_id: int) -> int:
	return -building_id


## Any stockpile addressed by entity id: a storage building, a house pantry, a construction
## site, a ground pile or (negative id) a workshop's production yard.
func storage(id: int) -> Stockpile:
	if id == 0:
		return null
	if id < 0:
		var owner := buildings.get_building(-id)
		return owner.yard if owner != null else null
	var building := buildings.get_building(id)
	if building != null:
		return building.stock if building.stock != null else building.supply
	var site := sites.get(id) as ConstructionSite
	if site != null:
		return site.stock
	var paving_site := paving.get(id) as PavingSite
	if paving_site != null:
		return paving_site.stock
	var pile := piles.get(id) as GroundPile
	if pile != null:
		return pile.stock
	var build := ship_builds.get(id) as ShipBuild
	if build != null:
		return build.stock
	var ship := ships.get(id) as ShipUnit
	if ship != null:
		return ship.hold
	if departure != null and departure.wagon != null and id == departure.id:
		return departure.wagon
	var route_wagon := route_wagons.get(id) as RouteWagon
	if route_wagon != null:
		return route_wagon.store
	return merchant.wagon if id == merchant.wagon_id and merchant.wagon != null else null


## Every stockpile by entity id, in a stable order (accounting, reservations).
func all_storages() -> Dictionary[int, Stockpile]:
	var result: Dictionary[int, Stockpile] = {}
	for building: BuildingState in buildings.all():
		var store := storage(building.id)
		if store != null:
			result[building.id] = store
		if building.yard != null:
			result[yard_id(building.id)] = building.yard
	for site: ConstructionSite in sites.values():
		result[site.id] = site.stock
	for paving_site: PavingSite in paving.values():
		result[paving_site.id] = paving_site.stock
	for pile: GroundPile in piles.values():
		result[pile.id] = pile.stock
	if merchant.wagon != null:
		result[merchant.wagon_id] = merchant.wagon
	for build: ShipBuild in ship_builds.values():
		result[build.id] = build.stock
	for ship: ShipUnit in ships.values():
		result[ship.id] = ship.hold
	if departure != null and departure.wagon != null:
		result[departure.id] = departure.wagon
	for wagon_id: int in route_wagons:
		result[wagon_id] = route_wagons[wagon_id].store
	return result


func accepts_deliveries(id: int) -> bool:
	if id < 0 or (id == merchant.wagon_id and merchant.wagon != null):
		return storage(id) != null
	if departure != null and departure.wagon != null and id == departure.id:
		return true
	if route_wagons.has(id):
		return route_wagons[id].accepts()
	var building := buildings.get_building(id)
	if building != null:
		return building.stock != null or building.supply != null
	return sites.has(id) or paving.has(id) or ship_builds.has(id) or Harbour.port_of(self, id) != null


func access_tile(id: int) -> Vector2i:
	var building := buildings.get_building(absi(id))
	if building != null:
		return building.entrance_tile()
	var site := sites.get(id) as ConstructionSite
	if site != null:
		var target := buildings.get_building(site.building_id)
		return target.entrance_tile() if target != null else Agent.NO_TILE
	var paving_site := paving.get(id) as PavingSite
	if paving_site != null:
		return paving_stand(paving_site)
	var pile := piles.get(id) as GroundPile
	if pile != null:
		return pile.tile
	var build := ship_builds.get(id) as ShipBuild
	if build != null:
		var shipyard := buildings.get_building(build.shipyard_id)
		return shipyard.entrance_tile() if shipyard != null else Agent.NO_TILE
	if ships.has(id):
		# Dockers go to the port entrance; the walk over the quay and the gangway is the
		# step's own (Harbour.walk_out).
		var port := Harbour.port_of(self, id)
		return port.entrance_tile() if port != null else Agent.NO_TILE
	if departure != null and departure.wagon != null and id == departure.id:
		return departure.stand
	if route_wagons.has(id):
		return route_wagons[id].stand
	return merchant.stand if id == merchant.wagon_id and merchant.wagon != null else Agent.NO_TILE


## Nearest storage (building or pile) able to give [param amount] of [param good]; 0 if none.
## [param keep_reserve] leaves each storage's reserve of the good alone (construction).
func nearest_source(good: StringName, amount: int, from: Vector2i, exclude: int = 0,
		keep_reserve: bool = false) -> int:
	var best := 0
	var best_d := 1 << 30
	for building: BuildingState in storage_buildings():
		if building.stock != null and building.id != exclude \
				and can_give(building.id, good, amount, keep_reserve):
			var d := (building.entrance_tile() - from).length_squared()
			if d < best_d:
				best_d = d
				best = building.id
	for pile: GroundPile in piles.values():
		if pile.id != exclude and pile.stock.can_supply(good, amount):
			var d := (pile.tile - from).length_squared()
			if d < best_d:
				best_d = d
				best = pile.id
	for building: BuildingState in yard_buildings(good):
		var yard := yard_id(building.id)
		# A herd always keeps its last animals for breeding (M4b-2).
		var keep := building.herd_keep if building.def.herd_good == good else 0
		if building.yard != null and yard != exclude and building.yard.can_supply(good, amount) 				and building.yard.available(good) - keep >= amount:
			var d := (building.entrance_tile() - from).length_squared()
			if d < best_d:
				best_d = d
				best = yard
	return best


## Takes [param amount] of [param good] straight out of the storages and yards nearest to
## [param near] (a purchase paid in goods, e.g. a handcart). Returns what was taken.
## [param used]: the goods go out of the economy (statistics); false when they only move
## (the simplified mode's porters). [param keep_reserve] leaves storage reserves alone.
func take_from_storages(good: StringName, amount: int, near: Vector2i, used: bool = true,
		keep_reserve: bool = false) -> int:
	var taken := 0
	while taken < amount:
		var src := nearest_source(good, 1, near, 0, keep_reserve)
		var store := storage(src)
		if store == null or src == 0:
			break
		var can := store.available(good)
		if keep_reserve:
			can = mini(can, maxi(store.available(good) - reserve_of(src, good), 1))
		var got := store.remove(good, mini(amount - taken, can))
		if got <= 0:
			break
		taken += got
	if used:
		ledger.used(good, taken, tick)
	return taken


## How many times its harvest a field tile yields here (E3 part 4: more on fertile land).
func field_yield() -> float:
	return ProvinceDef.FERTILE_YIELD if traits.has(ProvinceDef.FERTILE) else 1.0


## Whether the woods here keep more game (E3 part 4: more herds, breeding faster).
func rich_in_game() -> bool:
	return traits.has(ProvinceDef.RICH_GAME)


## Units of [param good] in storage buildings and production yards that can still be taken.
func stored(good: StringName) -> int:
	var sum := 0
	for building: BuildingState in storage_buildings():
		if building.stock != null:
			sum += building.stock.available(good)
	for building: BuildingState in yard_buildings(good):
		if building.yard != null:
			sum += building.yard.available(good)
	for building: BuildingState in market_buildings():
		if building.supply != null:
			sum += building.supply.available(good)
	return sum


## Buildings that can hold goods for others, by kind, in id order (M4b-3: searches for a
## source or a sink look only at these instead of every building). Rebuilt when buildings
## are added or removed; whether the store exists yet (a finished building) is checked by
## the caller.
func storage_buildings() -> Array[BuildingState]:
	_refresh_goods_index()
	return _storage_buildings


## Buildings whose production yard or herd can hold [param good].
func yard_buildings(good: StringName) -> Array[BuildingState]:
	_refresh_goods_index()
	return _yard_buildings.get(good, _NO_BUILDINGS)


func market_buildings() -> Array[BuildingState]:
	_refresh_goods_index()
	return _market_buildings


## The province has a finished town hall: its seat (M6 part 2). Burghers and patricians pay
## their full tax only here, and only from here settlers set out.
func has_seat() -> bool:
	if _seat_version != buildings.version:
		_seat_version = buildings.version
		_seat = 0
		for building: BuildingState in buildings.all():
			if building.def.id == SEAT:
				_seat = building.id
				break
	var hall := buildings.get_building(_seat)
	return hall != null and hall.is_complete()


## The town hall (finished or not), or null.
func seat() -> BuildingState:
	has_seat()
	return buildings.get_building(_seat)


## What attackers make for and hold (M8 part 5, owner's request 2026-11-10): the finished town
## hall, else the finished pioneer camp (a young town), else the town hall still being built;
## null when there is neither.
func stronghold() -> BuildingState:
	if has_seat():
		return seat()
	for building: BuildingState in buildings.all():
		if building.def.id == &"pioneer_camp" and building.is_complete():
			return building
	return seat()


## Whether there is a finished town hall or pioneer camp to attack (and to defend).
func has_stronghold() -> bool:
	var keep := stronghold()
	return keep != null and keep.is_complete()


func _refresh_goods_index() -> void:
	if _goods_index_version == buildings.version:
		return
	_goods_index_version = buildings.version
	_storage_buildings = []
	_market_buildings = []
	_yard_buildings = {}
	for building: BuildingState in buildings.all():
		var def := building.def
		if def.storage_slots > 0:
			_storage_buildings.append(building)
		if not def.stall_goods.is_empty():
			_market_buildings.append(building)
		if not _yard_goods_of.has(def.id):
			var goods := BuildingState.yard_goods(def, data)
			if def.herd_good != &"":
				goods = [def.herd_good]
			_yard_goods_of[def.id] = goods
		for good: StringName in _yard_goods_of[def.id]:
			if not _yard_buildings.has(good):
				_yard_buildings[good] = [] as Array[BuildingState]
			_yard_buildings[good].append(building)


## Units of [param good] the kingdom holds (the "Kingdom stocks" window, M4b-2): storages,
## production yards and herds, market stalls and ground piles; not house pantries, building
## sites or goods in hands.
func kingdom_stock(good: StringName) -> int:
	var sum := 0
	for building: BuildingState in buildings.all():
		if building.stock != null:
			sum += building.stock.total(good)
		if building.yard != null:
			sum += building.yard.total(good)
		if not building.def.stall_goods.is_empty() and building.supply != null:
			sum += building.supply.total(good)
	for pile: GroundPile in piles.values():
		sum += pile.stock.total(good)
	return sum


## Whether a workshop may take [param amount] of [param good] and still leave what the
## player keeps for building (storages and ground piles of the whole province count).
func workshop_may_take(good: StringName, amount: int) -> bool:
	var keep := int(keep_for_building.get(good, 0))
	if keep <= 0:
		return true
	var total := stored(good)
	for pile: GroundPile in piles.values():
		total += pile.stock.available(good)
	return total - amount >= keep


## Units of [param good] storage [param id] keeps back from construction (0 for piles).
func reserve_of(id: int, good: StringName) -> int:
	var building := buildings.get_building(id)
	return int(building.reserves.get(good, 0)) if building != null else 0


## Whether storage [param id] can hand out [param amount] of [param good] in one load, leaving
## its reserve in place when [param keep_reserve].
func can_give(id: int, good: StringName, amount: int, keep_reserve: bool = false) -> bool:
	var store := storage(id)
	if store == null or not store.can_supply(good, amount):
		return false
	return not keep_reserve or store.available(good) - reserve_of(id, good) >= amount


## Nearest storage building with room for [param amount] of [param good]; 0 if none. Live
## animals go to the nearest herd of their kind instead (M4b-2), never into a storage.
func nearest_sink(good: StringName, amount: int, from: Vector2i, exclude: int = 0) -> int:
	var best := 0
	var best_d := 1 << 30
	var good_def := data.get_good(good)
	if good_def != null and good_def.is_live():
		for building: BuildingState in yard_buildings(good):
			var herd := yard_id(building.id)
			if building.def.herd_good == good and building.yard != null and herd != exclude 					and building.herd_room() > 0 and building.yard.can_accept(good, amount):
				var d := (building.entrance_tile() - from).length_squared()
				if d < best_d:
					best_d = d
					best = herd
		return best
	for building: BuildingState in storage_buildings():
		if building.stock != null and building.id != exclude and building.stock.can_accept(good, amount):
			var d := (building.entrance_tile() - from).length_squared()
			if d < best_d:
				best_d = d
				best = building.id
	return best


## Puts goods on the ground (merging into a pile of the same good on that tile) and asks
## porters to bring them to a storage. Returns the pile id.
func drop_goods(tile: Vector2i, good: StringName, amount: int) -> int:
	var left := amount
	var last := 0
	for pile: GroundPile in piles.values():
		if left > 0 and pile.tile == tile and pile.good() == good:
			var before := left
			left = pile.stock.add(good, left)
			if left < before:
				jobs.add(good, before - left, pile.id, 0)
				last = pile.id
	while left > 0:
		var pile := GroundPile.new(ids.take(), tile, data)
		var before := left
		left = pile.stock.add(good, left)
		piles[pile.id] = pile
		_piles_version += 1
		jobs.add(good, before - left, pile.id, 0)
		events.emit(&"pile_created", {"pile": pile.id, "tile": tile, "good": good})
		last = pile.id
	return last


func _pile_at(tile: Vector2i) -> int:
	if _pile_index_version != _piles_version:
		# Tile -> first pile on it, rebuilt when piles come or go (M4b-3).
		_pile_index_version = _piles_version
		_pile_index.clear()
		for pile: GroundPile in piles.values():
			if not _pile_index.has(pile.tile):
				_pile_index[pile.tile] = pile.id
	return _pile_index.get(tile, 0)


func _remove_empty_piles() -> void:
	for pile: GroundPile in piles.values():
		if pile.stock.is_empty():
			piles.erase(pile.id)
			_piles_version += 1
			jobs.cancel_for_entity(pile.id)
			events.emit(&"pile_removed", {"pile": pile.id, "tile": pile.tile})


## Whether the workers of [param building] should not start a new cycle: its production yard
## is full of a good no storage has room for (M4b-2). They wait at the building.
func yard_blocked(building: BuildingState) -> bool:
	var yard := building.yard
	if yard == null or building.def.herd_good != &"":
		return false
	for slot: int in yard.slot_count():
		var good := yard.slot_good[slot]
		if good != &"" and yard.free_space(good) <= 0 				and nearest_sink(good, 1, building.entrance_tile()) == 0:
			return true
	return false


# --- Accounting (tests, debug) -------------------------------------------------------------

## Every unit of [param good] in the province: storages, piles and hands.
func goods_total(good: StringName) -> int:
	var sum := 0
	for store: Stockpile in all_storages().values():
		sum += store.total(good)
	for agent: Agent in agents.all():
		if agent.carry_good == good:
			sum += agent.carry_amount
	return sum


func reservation_count() -> int:
	var sum := 0
	for store: Stockpile in all_storages().values():
		sum += store.reservation_count()
	return sum


## Reservations and claims not backed by a running task step that knows about them.
## Must always be empty; used by tests after failure scenarios.
func dangling_holds() -> PackedStringArray:
	var problems := PackedStringArray()
	var storages := all_storages()
	for storage_id: int in storages:
		for res: Reservation in storages[storage_id].reservations():
			var agent := agents.get_agent(res.owner)
			var bb: Dictionary = agent.task.bb if agent != null and agent.task != null else {}
			var held := int(bb.get("_res", 0)) == res.id \
					and (int(bb.get("_src", 0)) == storage_id or int(bb.get("_dst", 0)) == storage_id)
			# A crane lift holds both ends at once (N1 part 2, Cranes.take_load).
			held = held or (int(bb.get("_res_in", 0)) == res.id and int(bb.get("_dst", 0)) == storage_id)
			if not held:
				problems.append("reservation %d in %d by %d" % [res.id, storage_id, res.owner])
	for tile: Vector2i in resources.tiles_with_nodes():
		var owner := resources.claimant(tile)
		if owner != 0:
			var agent := agents.get_agent(owner)
			if agent == null or agent.claimed_node != tile:
				problems.append("claim %s by %d" % [tile, owner])
	for tile: Vector2i in fields.all_tiles():
		var owner := fields.claimant(tile)
		if owner != 0:
			var agent := agents.get_agent(owner)
			var bb: Dictionary = agent.task.bb if agent != null and agent.task != null else {}
			if not bb.has("field") or SimCodec.to_vec2i(bb["field"]) != tile:
				problems.append("field %s by %d" % [tile, owner])
	return problems


func claim_count() -> int:
	var sum := 0
	for tile: Vector2i in resources.tiles_with_nodes():
		if resources.claimant(tile) != 0:
			sum += 1
	return sum


# --- Save ----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var pile_list: Array = []
	for pile: GroundPile in piles.values():
		pile_list.append(pile.to_dict())
	var site_list: Array = []
	for site: ConstructionSite in sites.values():
		site_list.append(site.to_dict())
	var paving_list: Array = []
	for paving_site: PavingSite in paving.values():
		paving_list.append(paving_site.to_dict())
	var d := {
		"grid": grid.to_dict(),
		"resources": resources.to_dict(),
		"buildings": buildings.to_dict(),
		"piles": pile_list,
		"sites": site_list,
		"paving": paving_list,
		"ships": _ships_to_list(),
		"ship_builds": _ship_builds_to_list(),
		"fields": fields.to_dict(),
		"entry": SimCodec.vec2i(entry_tile),
		"keep_for_building": _keep_to_dict(),
		"merchant": merchant.to_dict(),
		"sea_merchant": sea_merchant.to_dict(),
		"agents": agents.to_dict(),
		"jobs": jobs.to_dict(),
		"path_queue": paths.to_dict(),
	}
	if wild.populated or not wild.herds.is_empty():
		d["wild"] = wild.to_dict()
	if not production.is_empty():
		d["production"] = production.to_dict()
	if landing != null:
		d["landing"] = landing.to_dict()
	if departure != null:
		d["departure"] = departure.to_dict()
	if not route_wagons.is_empty():
		var wagons: Array = []
		var keys: Array[int] = []
		keys.assign(route_wagons.keys())
		keys.sort()
		for id: int in keys:
			wagons.append(route_wagons[id].to_dict())
		d["route_wagons"] = wagons
	if first_building != &"":
		d["first_building"] = String(first_building)
	if grace_until != 0:
		d["grace_until"] = grace_until
	if rare_resource != &"":
		d["rare"] = String(rare_resource)
	if walls.count() > 0:
		d["walls"] = walls.to_dict()
	if not mil.ladders.is_empty():
		d["military"] = mil.to_dict()
	if not arrows.is_empty():
		d["arrows"] = Troops.arrows_to_list(self)
	if raids.next_tick >= 0 or raids.count > 0:
		d["raids"] = raids.to_dict()
	return d


func _ships_to_list() -> Array:
	var list: Array = []
	for ship: ShipUnit in ships.values():
		list.append(ship.to_dict())
	return list


func _ship_builds_to_list() -> Array:
	var list: Array = []
	for build: ShipBuild in ship_builds.values():
		list.append(build.to_dict())
	return list


func _keep_to_dict() -> Dictionary:
	var result := {}
	for good: StringName in keep_for_building:
		result[String(good)] = keep_for_building[good]
	return result


static func from_dict(d: Dictionary, registry: DataRegistry, event_queue: SimEvents,
		entity_ids: EntityIds) -> ProvinceSim:
	var grid := TileGrid.from_dict(d["grid"])
	var province := ProvinceSim.new(registry, grid.size, event_queue, entity_ids)
	province.grid = grid
	province.resources = ResourceField.from_dict(d["resources"], grid.size, registry)
	province.buildings = BuildingStore.from_dict(d["buildings"], registry)
	if d.has("walls"):
		province.walls = Walls.from_dict(d["walls"], grid.size)
	for building: BuildingState in province.buildings.all():
		for tile: Vector2i in building.tiles():
			grid.set_occupant(tile, building.id)
		if building.def.is_fort() or building.def.walk_through:
			if building.def.has_crown():
				province.walls.add_fort(building.tiles(), building.id)
			for tile: Vector2i in building.passage_tiles():
				province.passages[tile] = building.id
	province.walls.rebuild_wedges()
	province.mil.load_dict(d.get("military", {}))
	if d.has("raids"):
		province.raids = Raids.from_dict(d["raids"])
	for ad: Variant in d.get("arrows", []):
		province.arrows.append(Troops.Arrow.from_dict(ad))
	if d.has("wild"):
		province.wild = WildHerds.from_dict(d["wild"])
	for pd: Variant in d.get("piles", []):
		var pile := GroundPile.from_dict(pd, registry)
		province.piles[pile.id] = pile
		province._piles_version += 1
	for sd: Variant in d.get("sites", []):
		var site := ConstructionSite.from_dict(sd, registry)
		province.sites[site.id] = site
	for pd: Variant in d.get("paving", []):
		var paving_site := PavingSite.from_dict(pd, registry)
		province.paving[paving_site.id] = paving_site
	province.fields = FieldStore.from_dict(d.get("fields", []))
	province.entry_tile = SimCodec.to_vec2i(d.get("entry", [0, 0]))
	var keep: Dictionary = d.get("keep_for_building", {})
	for good: Variant in keep:
		province.keep_for_building[StringName(String(good))] = int(keep[good])
	province.merchant = Merchant.from_dict(d.get("merchant", {}), registry)
	province.sea_merchant = SeaMerchant.from_dict(d.get("sea_merchant", {}))
	if d.has("landing"):
		province.landing = Landing.from_dict(d["landing"])
	if d.has("departure"):
		province.departure = Departure.from_dict(d["departure"], registry)
	for wd: Variant in d.get("route_wagons", []):
		var wagon := RouteWagon.from_dict(wd, registry)
		province.route_wagons[wagon.id] = wagon
	province.first_building = StringName(String(d.get("first_building", "")))
	province.grace_until = int(d.get("grace_until", 0))
	province.rare_resource = StringName(String(d.get("rare", "")))
	province.agents = AgentStore.from_dict(d["agents"])
	for agent: Agent in province.agents.all():
		if agent.task != null and not TaskRunner.restore_steps(province, agent.task):
			agent.task = null
	province.jobs = JobBoard.from_dict(d["jobs"])
	province.paths = PathRequestQueue.from_dict(d.get("path_queue", []))
	province.production = ProductionLog.from_dict(d.get("production", {}))
	for sd: Variant in d.get("ships", []):
		var ship := ShipUnit.from_dict(sd, registry)
		province.ships[ship.id] = ship
	for bd: Variant in d.get("ship_builds", []):
		var build := ShipBuild.from_dict(bd, registry)
		province.ship_builds[build.id] = build
	province.fairway = Ships.fairway_tiles(province)
	province.update_herd_rooms()
	province.rebuild_nav()
	return province

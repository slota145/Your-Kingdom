class_name SendExpeditionCommand
extends Command
## Sends an expedition of settlers from the viewed province to an empty one (ROADMAP M6
## part 2): from a province with a town hall, by sea on the player's idle cog to a coast or an
## island, or by land to a neighbour. Costs Departure.COST gold; the settlers and the start
## kit come from this province (Departure).

var target: int
var by_sea: bool


func _init(to: int, sea: bool) -> void:
	target = to
	by_sea = sea


func validate(sim: Simulation) -> StringName:
	return error_for(sim, target, by_sea)


## Why an expedition from the viewed province to [param to] cannot be sent now, or &"" (the
## expedition window shows the reason).
static func error_for(sim: Simulation, to: int, sea: bool) -> StringName:
	var province := sim.province
	var world := sim.world
	if world.is_single() or world.get_province(to) == null or to == sim.viewed_id:
		return &"unknown_province"
	if world.owner_of(to) != ProvinceDef.OWNER_NONE or sim.runtimes.has(to) or world.expedition_to(to) != null:
		return &"province_taken"
	for id: int in sim.runtimes:
		var other := sim.province_state(id)
		if other.departure != null and other.departure.target == to:
			return &"province_taken"
	if sim.data.get_map(world.get_province(to).map_id) == null:
		return &"province_not_ready"
	if sea and not world.sea_route(sim.viewed_id, to, sim.data):
		return &"no_sea_route"
	if not sea and not world.are_neighbours(sim.viewed_id, to, sim.data):
		return &"not_a_neighbour"
	if not province.has_seat():
		return &"no_town_hall"
	if province.departure != null:
		return &"expedition_gathering"
	if sea and idle_cog(province) == null:
		return &"no_cog"
	if not sim.treasury.can_pay(Departure.COST):
		return &"not_enough_gold"
	var residents := 0
	for building: BuildingState in province.buildings.all():
		if building.house != null:
			residents += building.house.residents
	if residents < Departure.SETTLERS.size():
		return &"not_enough_settlers"
	for good: StringName in Departure.KIT:
		if province.kingdom_stock(good) < Departure.KIT[good]:
			return &"not_enough_goods"
	return &""


## The player's cog waiting at anchor with a home port, or null.
static func idle_cog(province: ProvinceSim) -> ShipUnit:
	var ids: Array[int] = []
	ids.assign(province.ships.keys())
	ids.sort()
	for id: int in ids:
		var ship := province.ships[id] as ShipUnit
		if ship.voyage != null and ship.voyage.state == Voyage.State.IDLE and ship.home_id != 0 \
				and ship.hold.is_empty():
			return ship
	return null


func apply(sim: Simulation) -> void:
	sim.treasury.pay(Departure.COST)
	var cog := idle_cog(sim.province) if by_sea else null
	sim.province.departure = Departure.begin(sim.province, sim.ids.take(), target, by_sea,
			cog.id if cog != null else 0)
	sim.events.emit(&"expedition_sent", {"province": target, "by_sea": by_sea})


func get_name() -> StringName:
	return &"send_expedition"

class_name PrepareExpeditionCommand
extends Command
## Gets an expedition of settlers ready in a province of the player (ROADMAP M6 part 2, owner's
## decision 2026-11-06): only its kind is chosen, by land (a wagon) or by sea (the player's
## idle cog). The settlers and the start kit gather (Departure); where it goes is chosen on the
## world map once it is ready (SendExpeditionCommand). From the town hall or the world map, so
## also for a province nobody looks at (it gathers at once there).

var province_id: int
var by_sea: bool


func _init(id: int, sea: bool) -> void:
	province_id = id
	by_sea = sea


func validate(sim: Simulation) -> StringName:
	return error_for(sim, province_id, by_sea)


## Why an expedition cannot get ready in province [param id] now, or &"" (the town hall and the
## world map show the reason on the button).
static func error_for(sim: Simulation, id: int, sea: bool) -> StringName:
	var province := sim.province_state(id)
	if sim.world.is_single() or province == null or sim.world.owner_of(id) != ProvinceDef.OWNER_PLAYER:
		return &"unknown_province"
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
	var province := sim.province_state(province_id)
	var cog := idle_cog(province) if by_sea else null
	province.departure = Departure.begin(province, sim.ids.take(), by_sea, cog.id if cog != null else 0)
	sim.events.emit(&"expedition_prepared", {"province": province_id, "by_sea": by_sea})


func get_name() -> StringName:
	return &"prepare_expedition"

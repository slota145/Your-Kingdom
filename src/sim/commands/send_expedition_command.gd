class_name SendExpeditionCommand
extends Command
## Sends the ready expedition of settlers of province [member from_id] to an empty province
## (ROADMAP M6 part 2; on the world map: the expedition clicked, then the province right-
## clicked). By sea to a coast or an island, by land only to a neighbour. Costs Departure.COST
## gold, paid now (owner's decision 2026-11-06: a disbanded expedition costs nothing).

var from_id: int
var target: int


func _init(from: int, to: int) -> void:
	from_id = from
	target = to


func validate(sim: Simulation) -> StringName:
	if sim.world.owner_of(from_id) != ProvinceDef.OWNER_PLAYER:
		return &"not_your_province"
	return error_for(sim, from_id, target)


## Why the expedition of [param from] cannot go to [param to] now, or &"" (the world map shows
## the reason).
static func error_for(sim: Simulation, from: int, to: int) -> StringName:
	var world := sim.world
	var province := sim.province_state(from)
	if province == null or province.departure == null or province.departure.is_sent():
		return &"no_expedition"
	if not province.departure.is_ready():
		return &"expedition_not_ready"
	if world.is_single() or world.get_province(to) == null or to == from:
		return &"unknown_province"
	var owner := world.owner_of(from)
	# Another's expedition on its way does not stop it: whoever comes first takes the province
	# (M8 part 3); one already waiting or landing there does.
	if sim.runtimes.has(to) or world.is_claimed(to, owner) or world.expedition_to(to, owner) != null:
		return &"province_taken"
	if world.camp != null and world.camp.province == to:
		return &"bandit_camp"
	for id: int in sim.runtimes:
		var other := sim.province_state(id)
		if world.owner_of(id) == owner and other.departure != null and other.departure.target == to:
			return &"province_taken"
	if sim.data.get_map(world.get_province(to).map_id) == null:
		return &"province_not_ready"
	var sea := province.departure.by_sea
	if sea and not world.sea_route(from, to, sim.data):
		return &"no_sea_route"
	if not sea and not world.are_neighbours(from, to, sim.data):
		return &"not_a_neighbour"
	if not sim.treasury_of(owner).can_pay(Departure.COST):
		return &"not_enough_gold"
	return &""


func apply(sim: Simulation) -> void:
	send(sim, from_id, target)


## Sends the ready expedition of [param from] to [param to] (checked by [method error_for]),
## paid by the province's owner (the player, or an AI ruler: RulerExpansion).
static func send(sim: Simulation, from: int, to: int) -> void:
	sim.treasury_of(sim.world.owner_of(from)).pay(Departure.COST)
	var departure := sim.province_state(from).departure
	departure.target = to
	sim.events.emit(&"expedition_sent", {"province": to, "from": from,
			"by_sea": departure.by_sea})


func get_name() -> StringName:
	return &"send_expedition"

class_name Victory
extends RefCounted
## Victory and defeat of a sandbox game (ROADMAP M8 part 1, owner's survey 2026-11-09): checked
## once a second. The player loses when he holds no province. He wins by the condition chosen
## for the game: conquest (no AI ruler holds a province any more), provinces (he holds the
## number chosen), patricians (that many live in his towns), or never (a free game).

## House level of patricians (HouseState.level, 1-based).
const PATRICIAN_LEVEL := 3


## Once a second: ends the game when it is won or lost (WorldSim.result, an event).
static func update(sim: Simulation) -> void:
	var world := sim.world
	if world.settings == null or world.result != &"":
		return
	if player_provinces(world) == 0 and world.expeditions.is_empty():
		_end(sim, WorldSim.RESULT_LOST)
		return
	if is_won(sim):
		_end(sim, WorldSim.RESULT_WON)
		return
	var rich := richest_ruler(sim)
	if world.settings.victory == GameSettings.VICTORY_GOLD and rich != &"" \
			and world.rulers[rich].treasury.gold >= world.settings.gold_target:
		_end(sim, WorldSim.RESULT_LOST, rich)


static func is_won(sim: Simulation) -> bool:
	var settings := sim.world.settings
	match settings.victory:
		GameSettings.VICTORY_CONQUEST:
			return settings.rulers > 0 and Rulers.alive(sim.world).is_empty()
		GameSettings.VICTORY_PROVINCES:
			return player_provinces(sim.world) >= settings.target()
		GameSettings.VICTORY_PATRICIANS:
			return patricians(sim) >= settings.target()
		GameSettings.VICTORY_GOLD:
			return sim.treasury.gold >= settings.gold_target
		GameSettings.VICTORY_SURVIVE:
			return elapsed_minutes(sim) >= GameSettings.SURVIVE_MINUTES
	return false


## Whole minutes of play since the game began (the Invasion from the sea counts them).
static func elapsed_minutes(sim: Simulation) -> int:
	var since := sim.world.invasion.started if sim.world.invasion != null else 0
	return (sim.clock.tick - since) / SimClock.seconds_to_ticks(60.0)


## The AI ruler with the most gold (still in the game), or &"" (the Merchant islands' race).
static func richest_ruler(sim: Simulation) -> StringName:
	var best := &""
	for owner: StringName in Rulers.alive(sim.world):
		var ruler := sim.world.rulers.get(owner) as RulerState
		if ruler != null and (best == &""
				or ruler.treasury.gold > sim.world.rulers[best].treasury.gold):
			best = owner
	return best


static func player_provinces(world: WorldSim) -> int:
	var n := 0
	for id: int in world.ids():
		if world.owner_of(id) == ProvinceDef.OWNER_PLAYER:
			n += 1
	return n


## Patricians living in the player's towns.
static func patricians(sim: Simulation) -> int:
	var n := 0
	for id: int in sim.runtime_ids():
		if sim.world.owner_of(id) != ProvinceDef.OWNER_PLAYER:
			continue
		var p := sim.province_state(id)
		if p == null:
			continue
		for building: BuildingState in p.buildings.all():
			if building.house != null and building.house.level >= PATRICIAN_LEVEL:
				n += building.house.residents
	return n


## How far the player is towards the condition: [have, need] (need 0: nothing to count).
static func progress(sim: Simulation) -> Array[int]:
	var settings := sim.world.settings
	if settings == null:
		return [0, 0]
	match settings.victory:
		GameSettings.VICTORY_CONQUEST:
			return [settings.rulers - Rulers.alive(sim.world).size(), settings.rulers]
		GameSettings.VICTORY_PROVINCES:
			return [player_provinces(sim.world), settings.target()]
		GameSettings.VICTORY_PATRICIANS:
			return [patricians(sim), settings.target()]
		GameSettings.VICTORY_GOLD:
			return [sim.treasury.gold, settings.gold_target]
		GameSettings.VICTORY_SURVIVE:
			return [mini(elapsed_minutes(sim), GameSettings.SURVIVE_MINUTES), GameSettings.SURVIVE_MINUTES]
	return [0, 0]


## The survival mode's score: [waves held off, minutes held out] (a wave counts as held off once
## the next one has set out, or the game goes on after the last).
static func survived(sim: Simulation) -> Array[int]:
	var state := sim.world.invasion
	if state == null:
		return [0, 0]
	return [maxi(state.wave - 1, 0) if sim.world.result == WorldSim.RESULT_LOST else state.wave,
			elapsed_minutes(sim)]


## [param winner]: the ruler who won instead of the player (the gold race), or &"".
static func _end(sim: Simulation, result: StringName, winner: StringName = &"") -> void:
	sim.world.result = result
	var data := {"victory": String(sim.world.settings.victory)}
	if sim.world.settings.victory == GameSettings.VICTORY_ENDLESS:
		var score := survived(sim)
		data["waves"] = score[0]
		data["minutes"] = score[1]
	if winner != &"":
		data["winner"] = String(winner)
	sim.events.emit(&"game_won" if result == WorldSim.RESULT_WON else &"game_lost", data)

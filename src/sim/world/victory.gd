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


static func is_won(sim: Simulation) -> bool:
	var settings := sim.world.settings
	match settings.victory:
		GameSettings.VICTORY_CONQUEST:
			return settings.rulers > 0 and Rulers.alive(sim.world).is_empty()
		GameSettings.VICTORY_PROVINCES:
			return player_provinces(sim.world) >= settings.target()
		GameSettings.VICTORY_PATRICIANS:
			return patricians(sim) >= settings.target()
	return false


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
	return [0, 0]


static func _end(sim: Simulation, result: StringName) -> void:
	sim.world.result = result
	sim.events.emit(&"game_won" if result == WorldSim.RESULT_WON else &"game_lost",
			{"victory": String(sim.world.settings.victory)})

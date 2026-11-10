class_name AutoPlayer
extends RefCounted
## The automatic player of the M8 test games (ROADMAP M8 part 5, owner's survey 2026-11-10):
## the player's provinces are run by the same planner, expansion and commander as an AI
## ruler's (RulerPlanner, RulerExpansion, RulerWar, with a RulerState of the player that pays
## from the kingdom's treasury). It lands from the ship at once (camp and storage), settles,
## trades, recruits and attacks; its sieges and battles in the field are decided at once
## (the "automatic" button); its expeditions land at once (Simulation.autopilot). The game
## runs until it is won or lost.

## People a town needs before the Invasion's barracks go up.
const BARRACKS_PEOPLE := 10

var sim: Simulation
var state: RulerState
## Events counted by type, and a short log of what mattered (minute: what).
var counts: Dictionary[StringName, int] = {}
var log: PackedStringArray = PackedStringArray()
## Armies of the rulers and the raiders standing still away from their towns too long (as in
## the long war test): "army <id> of <owner> at <province>".
var stuck: PackedStringArray = PackedStringArray()
## A save taken at [member save_minute] loads back alike (empty: it did, or not taken yet).
var save_minute: int = -1
var save_mismatch: String = ""

## An army standing still this long away from its owner's towns counts as stuck.
const STUCK_SECONDS := 240

var _idle_since: Dictionary[int, int] = {}


func _init(simulation: Simulation) -> void:
	sim = simulation
	sim.autopilot = true
	var level := RulerPlanner.difficulty(sim)
	state = RulerState.create(ProvinceDef.OWNER_PLAYER, 0, sim.clock.tick)
	state.treasury = sim.treasury
	state.next_expedition = sim.clock.tick + SimClock.seconds_to_ticks(RulerExpansion.EXPEDITION_MINUTES[level] * 60.0)
	state.next_war = sim.clock.tick + RulerWar.first_ticks(level)
	if sim.province.landing != null and sim.province.landing.state != Landing.State.DONE:
		RulerExpansion.found(sim, sim.viewed_id, sim.province)


## Runs up to [param seconds] of game time, or until the game is decided; [param on_minute]
## is called with each whole minute. Returns the result (WorldSim.RESULT_*, or &"").
func run(seconds: int, on_minute: Callable = Callable()) -> StringName:
	for s: int in seconds:
		var second := sim.clock.tick / SimClock.TICKS_PER_SECOND
		var saving := false
		if second % RulerPlanner.EVERY == 0 and sim.world.invasion != null:
			saving = _barracks_first()
		if not saving:
			RulerPlanner.update_owner(sim, state, second)
		RulerExpansion.update_owner(sim, state)
		RulerWar.update_owner(sim, state, second, 7)
		_decide()
		for i: int in SimClock.TICKS_PER_SECOND:
			sim.step()
			for e: Dictionary in sim.events.drain():
				_note(e)
		_watch_armies()
		if second % 60 == 59:
			if second / 60 + 1 == save_minute:
				_check_save()
			if on_minute.is_valid():
				on_minute.call(second / 60 + 1)
		if sim.world.result != &"":
			break
	return sim.world.result


## The Invasion from the sea: barracks as soon as the first houses stand (the soldiers from the
## ship move in, RulerWar's commander sends them; a careful player does the same).
## Returns whether the town saves its planks and stone for them (no other new sites meanwhile).
func _barracks_first() -> bool:
	var saving := false
	for id: int in Rulers.provinces_of(sim.world, state.owner):
		var town := sim.province_state(id)
		if town == null or RulerPlanner.residents(town) < BARRACKS_PEOPLE:
			continue
		var counts := RulerPlanner.counts_of(town)
		if counts.has(&"barracks"):
			continue
		var def := sim.data.get_building(&"barracks")
		if RulerPlanner._affordable(town, state, def):
			RulerPlanner._open(sim, state, id, town, def)
		else:
			saving = true
			RulerPlanner.steward(town)
	return saving


func _watch_armies() -> void:
	for army: Army in sim.world.armies.values():
		if army.owner == ProvinceDef.OWNER_PLAYER or army.owner == Army.BANDITS or army.is_fleet() \
				or army.state != Army.State.IDLE or sim.world.owner_of(army.at) == army.owner:
			_idle_since.erase(army.id)
			continue
		if not _idle_since.has(army.id):
			_idle_since[army.id] = sim.clock.tick
		elif sim.clock.tick - _idle_since[army.id] > SimClock.seconds_to_ticks(STUCK_SECONDS):
			stuck.append("army %d of %s at %d" % [army.id, army.owner, army.at])
			_idle_since[army.id] = sim.clock.tick


func _check_save() -> void:
	var state := sim.to_dict()
	var copy := Simulation.from_dict(state, sim.data)
	var a := SimCodec.canonical(copy.to_dict())
	var b := SimCodec.canonical(state)
	if a != b:
		save_mismatch = "save at minute %d does not load back alike" % save_minute


## The player's choices, made at once: sieges at the border, battles in the field.
func _decide() -> void:
	var keys: Array[int] = []
	keys.assign(sim.world.armies.keys())
	keys.sort()
	for key: int in keys:
		var army := sim.world.armies.get(key) as Army
		if army != null and army.owner == ProvinceDef.OWNER_PLAYER and army.state == Army.State.WAITING \
				and Armies.siege_error(sim, army) == &"":
			Armies.resolve_siege(sim, army)
	keys.assign(sim.world.battles.keys())
	keys.sort()
	for key: int in keys:
		var battle := sim.world.battles.get(key) as FieldBattle
		if battle != null and battle.state == FieldBattle.State.PENDING:
			FieldBattles.resolve(sim, battle)


const LOGGED: Array[StringName] = [&"province_settled", &"settlement_joined", &"province_taken",
		&"province_captured", &"ruler_defeated", &"ruler_marched", &"invasion_wave", &"game_won", &"game_lost",
		&"expedition_turned_back", &"sea_battle", &"raiders_fled"]


func _note(e: Dictionary) -> void:
	var type: StringName = e["type"]
	counts[type] = counts.get(type, 0) + 1
	if LOGGED.has(type):
		var minute := sim.clock.tick / SimClock.seconds_to_ticks(60.0)
		var parts := PackedStringArray()
		for key: Variant in e:
			if key != "type" and key != "tick":
				parts.append("%s=%s" % [key, e[key]])
		log.append("%3d min %s %s" % [minute, type, " ".join(parts)])


## A line about the state of the game: the player's provinces, people, gold, soldiers; each
## ruler's.
func summary() -> String:
	var parts := PackedStringArray()
	var owners: Array[StringName] = [ProvinceDef.OWNER_PLAYER]
	owners.append_array(Rulers.alive(sim.world))
	for owner: StringName in owners:
		var ids := Rulers.provinces_of(sim.world, owner)
		var people := 0
		var buildings := 0
		for id: int in ids:
			var town := sim.province_state(id)
			if town != null:
				people += RulerPlanner.residents(town)
				buildings += town.buildings.all().size()
		var gold := sim.treasury_of(owner).gold
		parts.append("%s: %d prov, %d bld, %d ppl, %d gold, %d soldiers" % [owner, ids.size(), buildings, people,
				gold, RulerWar.strength(sim, owner)])
	return "; ".join(parts)

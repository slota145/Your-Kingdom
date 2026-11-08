class_name StartRaidCommand
extends Command
## Sends a bandit raid now (M7 part 2, for trying the defence: F7 in the game, and the main
## menu's "game with an early raid" sets the first one 2 minutes in).

## Seconds until the raid; 0 = now.
var in_seconds: float


func _init(seconds: float = 0.0) -> void:
	in_seconds = seconds


func validate(sim: Simulation) -> StringName:
	if not sim.province.has_seat():
		return &"no_town_hall"
	if sim.province.raids.is_active():
		return &"raid_under_way"
	return &""


func apply(sim: Simulation) -> void:
	var raids := sim.province.raids
	if in_seconds > 0.0:
		raids.next_tick = sim.clock.tick + SimClock.seconds_to_ticks(in_seconds)
		raids.state = Raids.State.WAITING
		return
	Raids.start(sim.province, sim.rng.stream(&"raids"))


func get_name() -> StringName:
	return &"start_raid"

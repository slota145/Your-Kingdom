extends Node
## Autoload "Game": owns the running simulation, the game speed and the fixed-step loop
## (ARCHITECTURE §4.2). Each frame it runs the due ticks and forwards simulation events
## to the EventBus.

const SPEEDS: PackedFloat32Array = [1.0, 2.0, 4.0]

var sim: Simulation
## Set by the main menu before opening the game scene: {"load": path} or {} for a new game.
var start_request: Dictionary = {}
var paused: bool = false
var speed_index: int = 0
## Average duration of one simulation tick in microseconds (debug HUD).
var tick_usec_avg: float = 0.0
## Seconds of a smoke run (M10 part 2): started with "-- --smoke[=<seconds>]", the game opens a
## new game by itself, plays this long at the highest speed, autosaves and quits, to check
## an exported build (tools/export_game.sh). 0 = a normal start.
var smoke_seconds: float = 0.0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--smoke":
			smoke_seconds = 20.0
		elif arg.begins_with("--smoke="):
			smoke_seconds = maxf(1.0, float(arg.trim_prefix("--smoke=")))


func start(simulation: Simulation) -> void:
	sim = simulation
	paused = false


func stop() -> void:
	sim = null


func get_speed() -> float:
	return 0.0 if paused else SPEEDS[speed_index]


func set_speed_index(index: int) -> void:
	speed_index = clampi(index, 0, SPEEDS.size() - 1)


func toggle_pause() -> void:
	paused = not paused


## Fraction of the next tick already elapsed, for interpolating positions.
func alpha() -> float:
	return sim.clock.alpha() if sim != null else 0.0


func _process(delta: float) -> void:
	if sim == null:
		return
	var due := sim.clock.consume(delta * get_speed())
	for i: int in due:
		var start := Time.get_ticks_usec()
		sim.step()
		tick_usec_avg = lerpf(tick_usec_avg, float(Time.get_ticks_usec() - start), 0.05)
	for event: Dictionary in sim.events.drain():
		EventBus.sim_event_emitted.emit(event)

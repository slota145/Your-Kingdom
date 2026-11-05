class_name Simulation
extends RefCounted
## The whole game state and its fixed-step update (ARCHITECTURE §4). No nodes, no autoloads:
## definitions come in through the DataRegistry, changes only through commands.
##
## M2 runs a single detailed province; the world layer arrives in M6.

var data: DataRegistry
var clock: SimClock = SimClock.new()
var rng: SimRng
var ids: EntityIds = EntityIds.new()
var events: SimEvents = SimEvents.new()
var province: ProvinceSim

var _commands: Array[Command] = []


func _init(registry: DataRegistry, map_size: Vector2i = Vector2i(64, 64), seed_value: int = 1) -> void:
	data = registry
	rng = SimRng.new(seed_value)
	province = ProvinceSim.new(registry, map_size, events, ids)


## A new game on a hand-made map (ROADMAP M3): terrain, trees and the start layout.
## Problems with the map (unknown colours, start buildings that do not fit) go to [param problems].
static func from_map(registry: DataRegistry, map: MapDef, seed_value: int = 1,
		problems: PackedStringArray = PackedStringArray()) -> Simulation:
	var sim := Simulation.new(registry, map.size(), seed_value)
	problems.append_array(sim.province.load_map(map))
	sim.events.drain()
	return sim


## Queues a command for the start of the next tick.
func submit(command: Command) -> void:
	_commands.append(command)


## Validates and applies a command right away (setup code and tests). Returns the reason
## it was rejected, or &"".
func execute(command: Command) -> StringName:
	var error := command.validate(self)
	if error == &"":
		command.apply(self)
	else:
		events.emit(&"command_rejected", {"command": command.get_name(), "reason": error})
	return error


## Runs one tick in the fixed system order (ARCHITECTURE §4.2).
func step() -> void:
	events.tick = clock.tick
	var commands := _commands
	_commands = []
	for command: Command in commands:
		execute(command)
	province.tick = clock.tick
	province.step()
	clock.tick += 1


func run_ticks(count: int) -> void:
	for i: int in count:
		step()


func to_dict() -> Dictionary:
	return {
		"tick": clock.tick,
		"next_id": ids.next_id,
		"rng": rng.to_dict(),
		"province": province.to_dict(),
	}


## Restores a saved state. Commands queued but not yet applied are not part of a save.
static func from_dict(d: Dictionary, registry: DataRegistry) -> Simulation:
	var sim := Simulation.new(registry, Vector2i.ONE)
	sim.clock.tick = int(d["tick"])
	sim.ids.next_id = int(d["next_id"])
	sim.rng = SimRng.from_dict(d["rng"])
	sim.province = ProvinceSim.from_dict(d["province"], registry, sim.events, sim.ids)
	sim.province.tick = sim.clock.tick
	return sim

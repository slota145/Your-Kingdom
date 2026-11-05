class_name SpawnAgentCommand
extends Command
## Creates a person on a walkable tile. Until population arrives (M3) this is how people appear.

var kind: StringName
var tile: Vector2i


func _init(agent_kind: StringName, at: Vector2i) -> void:
	kind = agent_kind
	tile = at


func validate(sim: Simulation) -> StringName:
	if kind == &"":
		return &"unknown_kind"
	return &"" if sim.province.nav.is_walkable(tile) else &"tile_blocked"


func apply(sim: Simulation) -> void:
	sim.province.spawn_agent(kind, tile)


func get_name() -> StringName:
	return &"spawn_agent"

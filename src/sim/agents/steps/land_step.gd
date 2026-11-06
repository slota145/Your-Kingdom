class_name LandStep
extends TaskStep
## A settler wades from the ship at anchor to the beach (M5 part 3, Landing): straight over
## the shallow water, slower than walking. Blackboard "from" and "to" are the tiles, "t" the
## ticks walked so far (saved, so a game saved mid-way goes on there).

## Wading is slower than walking on grass.
const WADE_FACTOR := 0.6


func run(_province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	var bb := agent.task.bb
	var from := IsoMath.tile_center(SimCodec.to_vec2i(bb["from"]))
	var to := IsoMath.tile_center(SimCodec.to_vec2i(bb["to"]))
	var ticks := maxi(ceili(from.distance_to(to) / (Movement.BASE_SPEED * WADE_FACTOR * SimClock.TICK)), 1)
	var t := int(bb.get("t", 0)) + 1
	bb["t"] = t
	agent.pos = from.lerp(to, minf(float(t) / ticks, 1.0))
	var dir := IsoMath.screen_dir(to - from)
	if dir >= 0:
		agent.facing = dir
	if t < ticks:
		agent.activity = &"walk"
		return Status.RUNNING
	agent.activity = &"idle"
	return Status.DONE

extends SceneTree
## UI-2 part 2 PROTOTYPE: the big M4b-3 city with every worker leaving his output on his yard:
## every 5 minutes the open transport requests (from yards, to sites, other), idle porters, full
## yards, workers waiting at a full yard, and bread, planks and beer made in those 5 minutes.
## "$GODOT" --headless --path . -s res://src/prototype/ui2/city_probe.gd -- [--minutes=50]


func _init() -> void:
	var minutes := 50
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			minutes = int(a.trim_prefix("--minutes="))
	var reg := DataRegistry.new()
	reg.load_from("res://data")
	var sim := BigCity.load_fixture(reg)
	var last := {}
	for minute: int in range(1, minutes + 1):
		sim.run_ticks(SimClock.TICKS_PER_SECOND * 60)
		sim.events.drain()
		if minute % 5 != 0:
			continue
		var from_yards := 0
		var to_sites := 0
		var other := 0
		var units := 0
		for r: TransportRequest in sim.province.jobs.all():
			units += r.unassigned()
			if r.source_id < 0:
				from_yards += 1
			elif JobBoard.is_for_building(sim.province, r.dest_id):
				to_sites += 1
			else:
				other += 1
		var idle := 0
		var porters := 0
		var yard_waits := 0
		for agent: Agent in sim.province.agents.all():
			if agent.kind == &"porter":
				porters += 1
				if agent.is_idle():
					idle += 1
			if agent.last_fail == &"yard_full" or (agent.task != null and agent.task.bb.has("_yard_full")):
				yard_waits += 1
		var full_yards := 0
		var yard_units := 0
		for b: BuildingState in sim.province.buildings.all():
			if b.yard != null and b.def.herd_good == &"":
				for slot: int in b.yard.slot_count():
					yard_units += b.yard.slot_amount[slot]
					if b.yard.slot_amount[slot] >= b.yard.stack_size(b.yard.slot_good[slot]) and b.yard.slot_good[slot] != &"":
						full_yards += 1
		var made := PackedStringArray()
		for g: StringName in [&"bread", &"planks", &"beer"]:
			var total := int(sim.province.ledger.made_total.get(g, 0))
			made.append("%s +%d" % [g, total - int(last.get(g, 0))])
			last[g] = total
		print("min %d: requests yards %d sites %d other %d (%d units) | porters %d idle %d | yards full %d units %d | waiting %d | %s" % [
				minute, from_yards, to_sites, other, units, porters, idle, full_yards, yard_units, yard_waits, ", ".join(made)])
	quit()

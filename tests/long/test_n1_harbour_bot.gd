extends GdUnitTestSuite
## N1 part 2 DoD: the automatic player on Coast uses the quays. The SliceBot builds its town
## from the ship as in test_slice_dod; from minute 45 the HarbourBot adds a port, a shipyard, a
## pier with a mooring and a cargo crane, and a port warehouse on a second pier, orders a cog
## and keeps sending it on voyages. Within 130 minutes: the sea merchant and the cog lie at both
## berths at once, the crane lifts cargo 3 at a time, the warehouse takes goods, and nothing
## gets stuck.

const MINUTES := 130


func test_coast_bot_uses_the_quays_and_both_berths() -> void:
	var registry := SimFixture.registry()
	var problems := PackedStringArray()
	var sim := Simulation.from_map(registry, registry.get_map(&"coast"), 1, problems)
	assert_array(Array(problems)).is_empty()
	var town := SliceBot.new(sim)
	var harbour := HarbourBot.new(sim)
	var trace := PackedStringArray()
	var watch := DeadlockWatch.new()
	for second: int in MINUTES * 60:
		town.act(second)
		harbour.act(second)
		for i: int in SimClock.TICKS_PER_SECOND:
			sim.step()
			for e: Dictionary in sim.events.drain():
				town.note(e)
				harbour.note(e)
		if second % 60 == 59:
			watch.check(sim, second / 60 + 1)
		if second % 300 == 299:
			trace.append("min %d: quays %d, ships %d, voyages %d, both berths %d s, merchant at mooring %d s, crane %d in %d lifts, warehouse %d, gold %d" % [
					second / 60 + 1, sim.province.grid.quay_count(), sim.province.ships.size(),
					harbour.voyages, harbour.both_berths_seconds, harbour.merchant_at_mooring,
					harbour.crane_lifted, harbour.crane_lifts, harbour.warehouse_stored, sim.treasury.gold])
	print("\n".join(trace))
	print("town log: ", town.log, "; harbour log: ", harbour.log)
	for b: BuildingState in sim.province.buildings.all():
		if b.def.has_berth() or b.def.crane_reach > 0 or b.def.id == &"port_warehouse":
			print(b.def.id, " at ", b.origin, " turned ", b.orientation)
	for site: PavingSite in sim.province.paving.values():
		print("unfinished site ", site.id, ": ", site.tiles)
	assert_array(Array(harbour.log)).is_empty()
	for id: StringName in [&"port", &"shipyard", &"mooring", &"crane", &"port_warehouse"]:
		assert_bool(_finished(sim, id)).override_failure_message("%s not finished" % id).is_true()
	assert_str(String(harbour.cog_home)).is_equal("mooring")
	assert_int(harbour.voyages).is_greater_equal(2)
	assert_int(harbour.both_berths_seconds).is_greater(0)
	assert_int(harbour.crane_lifted).is_greater_equal(12)
	assert_float(float(harbour.crane_lifted) / harbour.crane_lifts).is_greater(2.0)
	assert_int(harbour.warehouse_stored).is_greater(0)
	assert_array(watch.stuck).is_empty()


func _finished(sim: Simulation, id: StringName) -> bool:
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == id and b.is_complete():
			return true
	return false

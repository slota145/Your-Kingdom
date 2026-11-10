extends GdUnitTestSuite

const OWNER_A := 101
const OWNER_B := 102


func _stock(slots: int = 2) -> Stockpile:
	return Stockpile.new(slots, SimFixture.registry())


func test_reserve_and_commit_incoming() -> void:
	var stock := _stock()
	var res := stock.reserve_in(&"wood", 3, OWNER_A)
	assert_int(res).is_not_equal(0)
	assert_int(stock.total(&"wood")).is_equal(0)
	assert_int(stock.free_space(&"wood")).is_equal(2 * 20 - 3)
	assert_int(stock.commit(res)).is_equal(3)
	assert_int(stock.total(&"wood")).is_equal(3)
	assert_bool(stock.is_consistent()).is_true()


func test_two_carriers_cannot_take_the_same_unit() -> void:
	var stock := _stock()
	stock.add(&"wood", 1)
	assert_int(stock.reserve_out(&"wood", 1, OWNER_A)).is_not_equal(0)
	assert_int(stock.reserve_out(&"wood", 1, OWNER_B)).is_equal(0)
	assert_int(stock.available(&"wood")).is_equal(0)


func test_full_store_refuses_deliveries() -> void:
	var stock := _stock(1)
	assert_int(stock.add(&"wood", 25)).is_equal(5)
	assert_int(stock.reserve_in(&"wood", 1, OWNER_A)).is_equal(0)
	assert_int(stock.reserve_in(&"bread", 1, OWNER_A)).is_equal(0)
	assert_bool(stock.can_accept(&"wood", 1)).is_false()


func test_incoming_reservation_claims_an_empty_slot() -> void:
	var stock := _stock(1)
	assert_int(stock.reserve_in(&"wood", 1, OWNER_A)).is_not_equal(0)
	assert_int(stock.reserve_in(&"bread", 1, OWNER_B)).is_equal(0)


func test_cancel_restores_counters_and_frees_slot() -> void:
	var stock := _stock(1)
	var res := stock.reserve_in(&"wood", 2, OWNER_A)
	stock.cancel(res)
	assert_str(String(stock.slot_good[0])).is_equal("")
	assert_int(stock.reservation_count()).is_equal(0)
	assert_bool(stock.is_consistent()).is_true()
	assert_int(stock.commit(res)).is_equal(0)


func test_release_owner_drops_only_their_reservations() -> void:
	var stock := _stock()
	stock.add(&"wood", 5)
	stock.reserve_out(&"wood", 2, OWNER_A)
	stock.reserve_in(&"wood", 1, OWNER_A)
	stock.reserve_out(&"wood", 1, OWNER_B)
	assert_int(stock.release_owner(OWNER_A)).is_equal(2)
	assert_int(stock.reservation_count()).is_equal(1)
	assert_int(stock.available(&"wood")).is_equal(4)
	assert_bool(stock.is_consistent()).is_true()


func test_json_round_trip_keeps_reservations() -> void:
	var stock := _stock(3)
	stock.add(&"wood", 7)
	stock.add(&"bread", 2)
	stock.reserve_out(&"wood", 2, OWNER_A)
	stock.reserve_in(&"flour", 1, OWNER_B)
	var text := JSON.stringify(stock.to_dict())
	var restored := Stockpile.from_dict(JSON.parse_string(text), SimFixture.registry())
	assert_str(JSON.stringify(restored.to_dict())).is_equal(text)
	assert_bool(restored.is_consistent()).is_true()
	assert_int(restored.available(&"wood")).is_equal(5)


func test_random_operations_keep_invariants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var goods: Array[StringName] = [&"wood", &"bread", &"flour", &"grain"]
	var stock := _stock(4)
	var expected: Dictionary[StringName, int] = {}
	var open: Array[int] = []
	for i: int in 2000:
		var good := goods[rng.randi_range(0, goods.size() - 1)]
		var amount := rng.randi_range(1, 6)
		match rng.randi_range(0, 3):
			0:
				var res := stock.reserve_in(good, amount, rng.randi_range(1, 5))
				if res != 0:
					open.append(res)
			1:
				var res := stock.reserve_out(good, amount, rng.randi_range(1, 5))
				if res != 0:
					open.append(res)
			2:
				if not open.is_empty():
					var res: int = open.pop_at(rng.randi_range(0, open.size() - 1))
					var r := stock.get_reservation(res)
					var moved := stock.commit(res)
					expected[r.good] = expected.get(r.good, 0) + (moved if r.incoming else -moved)
			3:
				if not open.is_empty():
					stock.cancel(open.pop_at(rng.randi_range(0, open.size() - 1)))
		assert_bool(stock.is_consistent()).is_true()
	for good: StringName in goods:
		assert_int(stock.total(good)).is_equal(expected.get(good, 0))


func test_one_slot_per_good_keeps_a_good_to_one_stack() -> void:
	var stock := Stockpile.new(3, SimFixture.registry())
	stock.stack_limit = 6
	stock.one_slot_per_good = true
	assert_int(stock.add(&"bread", 10)).is_equal(4)
	assert_int(stock.free_space(&"bread")).is_equal(0)
	assert_bool(stock.can_accept(&"bread", 1)).is_false()
	assert_int(stock.free_space(&"fish")).is_equal(6)
	assert_bool(stock.can_accept(&"fish", 2)).is_true()


## E1 (owner 2026-11-10): the stockpile and harbour stores hold twice a stack per slot.
func test_stack_multiplier_doubles_a_slot() -> void:
	var stock := _stock(1)
	stock.stack_multiplier = 2
	assert_int(stock.stack_size(&"wood")).is_equal(40)
	assert_int(stock.add(&"wood", 45)).is_equal(5)
	assert_bool(stock.is_consistent()).is_true()


func test_stores_hold_twice_a_stack_but_the_armoury_does_not() -> void:
	var data := SimFixture.registry()
	for id: StringName in [&"stockpile", &"port_store", &"port_warehouse", &"port_warehouse_small"]:
		var building := BuildingState.new(1, data.get_building(id), Vector2i.ZERO)
		building.finish(data)
		assert_int(building.stock.stack_size(&"wood")).override_failure_message(String(id)).is_equal(40)
	var armoury := BuildingState.new(2, data.get_building(&"armoury"), Vector2i.ZERO)
	armoury.finish(data)
	assert_int(armoury.stock.stack_size(&"sword")).is_equal(data.get_good(&"sword").stack_size)


func test_stack_multiplier_survives_save_and_load() -> void:
	var data := SimFixture.registry()
	var building := BuildingState.new(1, data.get_building(&"stockpile"), Vector2i.ZERO)
	building.finish(data)
	building.stock.add(&"wood", 35)
	var loaded := BuildingState.from_dict(building.to_dict(), data)
	assert_int(loaded.stock.total(&"wood")).is_equal(35)
	assert_int(loaded.stock.stack_size(&"wood")).is_equal(40)
	assert_bool(loaded.stock.is_consistent()).is_true()

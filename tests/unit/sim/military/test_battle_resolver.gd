extends GdUnitTestSuite
## BattleResolver (ROADMAP M7 part 3): the table of battles nobody watches. Each row says who
## should win (most of the time, BattleResolver.chances over 20 fights) so that the outcomes
## stay sensible while the values are tuned.

const FIELD := BattleResolver.Kind.FIELD
const SIEGE := BattleResolver.Kind.SIEGE
const NAVAL := BattleResolver.Kind.NAVAL

## [name, side A, side B, kind, fort (none, palisade, stone), lowest and highest chance of A].
const TABLE := [
	["even lines", {"spearman": 10}, {"spearman": 10}, FIELD, "", 0.2, 0.8],
	["more men win", {"spearman": 14}, {"spearman": 10}, FIELD, "", 0.9, 1.0],
	["swordsmen beat more spearmen", {"swordsman": 10}, {"spearman": 15}, FIELD, "", 0.9, 1.0],
	["spearmen stop riders", {"knight": 8}, {"spearman": 12}, FIELD, "", 0.0, 0.1],
	["riders ride down archers", {"knight": 8}, {"archer": 12}, FIELD, "", 0.9, 1.0],
	["an army scatters a raid", {"spearman": 20}, {"spearman": 4, "archer": 2}, FIELD, "", 1.0, 1.0],
	["bare men fail at a stone wall", {"spearman": 20}, {"spearman": 8, "archer": 6}, SIEGE, "stone", 0.0, 0.1],
	["ram and ladders take a stone wall", {"swordsman": 20, "archer": 10, "ram": 1, "ladderman": 2},
			{"spearman": 8, "archer": 6}, SIEGE, "stone", 0.9, 1.0],
	["a palisade falls to a bigger army", {"spearman": 15, "archer": 5}, {"spearman": 5, "archer": 3},
			SIEGE, "palisade", 0.9, 1.0],
	["a walled garrison holds off bandits", {"spearman": 6, "archer": 2}, {"spearman": 4, "archer": 4},
			SIEGE, "stone", 0.0, 0.1],
	["an open town falls to bandits", {"spearman": 6, "archer": 2}, {"spearman": 2}, SIEGE, "", 0.9, 1.0],
	["hungry men lose an even fight", {"spearman": 11}, {"spearman": 10}, FIELD, "hungry", 0.0, 0.3],
]


func test_table_of_battles() -> void:
	var data := SimFixture.registry()
	var failures := PackedStringArray()
	for row: Array in TABLE:
		var a := BattleSide.new(_units(row[1]), row[4] != "hungry")
		var b := BattleSide.new(_units(row[2]))
		var chance := BattleResolver.chances(data, a, b, row[3], _fort(row[4]))
		if chance < row[5] or chance > row[6]:
			failures.append("%s: %.2f not in %.2f..%.2f" % [row[0], chance, row[5], row[6]])
	assert_array(Array(failures)).is_empty()


func test_the_same_seed_gives_the_same_battle() -> void:
	var data := SimFixture.registry()
	var one := _resolve(data, 5)
	var two := _resolve(data, 5)
	assert_dict(one.to_dict()).is_equal(two.to_dict())


func test_losses_and_survivors_add_up() -> void:
	var data := SimFixture.registry()
	var r := _resolve(data, 9)
	for unit: StringName in [&"swordsman", &"archer"]:
		assert_int(r.left_a[unit] + r.lost_a[unit]).is_equal({&"swordsman": 12, &"archer": 6}[unit])
	assert_int(r.left_b[&"spearman"] + r.lost_b[&"spearman"]).is_equal(14)
	assert_bool(r.report.is_empty()).is_false()
	assert_dict(BattleResult.from_dict(r.to_dict()).to_dict()).is_equal(r.to_dict())


func test_a_siege_reports_breaching_the_walls() -> void:
	var data := SimFixture.registry()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var r := BattleResolver.resolve(data, BattleSide.new(_units({"spearman": 15, "archer": 5})),
			BattleSide.new(_units({"spearman": 5, "archer": 3})), SIEGE, rng, _fort("palisade"))
	assert_int(int(r.report[0]["phase"])).is_equal(BattleResolver.Phase.BREACH)
	assert_bool(r.breached).is_true()


func test_a_sea_battle_sinks_ships_and_drowns_who_does_not_fit() -> void:
	var data := SimFixture.registry()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var r := BattleResolver.resolve(data, BattleSide.new(_units({"spearman": 20}), true, 1),
			BattleSide.new(_units({"spearman": 40, "archer": 20}), true, 3), NAVAL, rng)
	assert_bool(r.a_won()).is_false()
	assert_int(r.ships_left_b).is_greater(0)
	var left := 0
	for unit: StringName in r.left_a:
		left += r.left_a[unit]
	assert_int(left).is_less_equal(r.ships_left_a * BattleResolver.SHIP_CAPACITY)


func _resolve(data: DataRegistry, seed_value: int) -> BattleResult:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return BattleResolver.resolve(data, BattleSide.new(_units({"swordsman": 12, "archer": 6})),
			BattleSide.new(_units({"spearman": 14})), FIELD, rng)


func _units(d: Dictionary) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for unit: Variant in d:
		result[StringName(String(unit))] = int(d[unit])
	return result


func _fort(kind: String) -> BattleFort:
	match kind:
		"stone":
			return BattleFort.new(Walls.STONE, 1000, 1500)
		"palisade":
			return BattleFort.new(Walls.PALISADE, 300, 1500)
	return null

class_name GameSettings
extends RefCounted
## The settings of a sandbox game (ROADMAP M8 part 1, owner's surveys 2026-11-09): the scenario,
## the world (a generated one from its number, or a hand-made one), the AI rulers and their
## difficulty, and the victory condition. Saved with the world.

const COLONIZATION := &"colonization"

const VICTORY_CONQUEST := &"conquest"
const VICTORY_PROVINCES := &"provinces"
const VICTORY_PATRICIANS := &"patricians"
const VICTORY_FREE := &"free"
const VICTORIES: Array[StringName] = [VICTORY_CONQUEST, VICTORY_PROVINCES, VICTORY_PATRICIANS, VICTORY_FREE]

const EASY := 0
const NORMAL := 1
const HARD := 2

var scenario: StringName = COLONIZATION
## World number (seed) of a generated world; 0 = a hand-made world ([member world_def]).
var world_seed: int = 1
## A hand-made world (WorldDef id) instead of a generated one.
var world_def: StringName = &""
## Provinces of a generated world.
var province_count: int = 22
## AI rulers, 1-3 (owner's survey 2026-11-09).
var rulers: int = 2
var difficulty: int = NORMAL
var victory: StringName = VICTORY_CONQUEST
## Provinces to hold (VICTORY_PROVINCES) or patricians to house (VICTORY_PATRICIANS).
var victory_target: int = 0


func is_generated() -> bool:
	return world_def == &""


## The default target of [param kind]: half the world's provinces, or 100 patricians.
func default_target(kind: StringName) -> int:
	match kind:
		VICTORY_PROVINCES:
			return maxi(province_count / 2, 4)
		VICTORY_PATRICIANS:
			return 100
	return 0


func target() -> int:
	return victory_target if victory_target > 0 else default_target(victory)


func to_dict() -> Dictionary:
	return {"scenario": String(scenario), "seed": world_seed, "world": String(world_def),
			"provinces": province_count, "rulers": rulers, "difficulty": difficulty,
			"victory": String(victory), "target": victory_target}


static func from_dict(d: Dictionary) -> GameSettings:
	var s := GameSettings.new()
	s.scenario = StringName(String(d.get("scenario", COLONIZATION)))
	s.world_seed = int(d.get("seed", 1))
	s.world_def = StringName(String(d.get("world", "")))
	s.province_count = int(d.get("provinces", 22))
	s.rulers = clampi(int(d.get("rulers", 2)), 0, 3)
	s.difficulty = clampi(int(d.get("difficulty", NORMAL)), EASY, HARD)
	s.victory = StringName(String(d.get("victory", VICTORY_CONQUEST)))
	s.victory_target = int(d.get("target", 0))
	return s

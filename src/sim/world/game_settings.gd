class_name GameSettings
extends RefCounted
## The settings of a sandbox game (ROADMAP M8 part 1, owner's surveys 2026-11-09): the scenario,
## the world (a generated one from its number, or a hand-made one), the AI rulers and their
## difficulty, and the victory condition. Saved with the world.

## Scenarios (owner's surveys 2026-11-09 and 2026-11-10, M8 part 5): Colonization (almost every
## province empty), the Divided continent (every province held by the rulers and the neutral
## settlements, the player lands in the one left), the Merchant islands (islands only; the
## first to hold the gold target wins), the Invasion from the sea (no rulers; waves of raiders
## from over the sea, the player wins by holding out [constant SURVIVE_MINUTES] minutes).
const COLONIZATION := &"colonization"
const DIVIDED := &"divided"
const ISLANDS := &"islands"
const INVASION := &"invasion"
const SCENARIOS: Array[StringName] = [COLONIZATION, DIVIDED, ISLANDS, INVASION]

const VICTORY_CONQUEST := &"conquest"
const VICTORY_PROVINCES := &"provinces"
const VICTORY_PATRICIANS := &"patricians"
const VICTORY_FREE := &"free"
const VICTORIES: Array[StringName] = [VICTORY_CONQUEST, VICTORY_PROVINCES, VICTORY_PATRICIANS, VICTORY_FREE]
## Set by the scenario, not chosen (M8 part 5): gold in the treasury (the Merchant islands),
## holding out (the Invasion from the sea).
const VICTORY_GOLD := &"gold"
const VICTORY_SURVIVE := &"survive"
## The Invasion's survival mode (owner's request 2026-11-10): waves without end, never won;
## how long the player held out is his score.
const VICTORY_ENDLESS := &"endless"

## The gold target of the Merchant islands: chosen 2 000-100 000, 10 000 by default.
const MIN_GOLD := 2000
const MAX_GOLD := 100000
const DEFAULT_GOLD := 10000
## The Invasion from the sea is won after this many minutes.
const SURVIVE_MINUTES := 60
## Waves of the Invasion that only plunder, by default; PLUNDER_ALL: every wave (owner's request
## 2026-11-10: chosen in "New game", "only plundering waves" too).
const DEFAULT_PLUNDER := 2
const PLUNDER_ALL := 999

const MIN_PROVINCES := 9
const MAX_PROVINCES := 60
const MAX_ISLANDS := 10

const EASY := 0
const NORMAL := 1
const HARD := 2
## The AI rulers grow as on EASY, arm and fight each other and the neutral settlements, but
## never attack the player (owner's survey 2026-11-10, instead of truces).
const PEACEFUL := 3

var scenario: StringName = COLONIZATION
## World number (seed) of a generated world; 0 = a hand-made world ([member world_def]).
var world_seed: int = 1
## A hand-made world (WorldDef id) instead of a generated one.
var world_def: StringName = &""
## Provinces of a generated world, 9-60, and how many of them are islands, 0-10 (owner's
## survey 2026-11-09).
var province_count: int = 22
var islands: int = 3
## The province the player chose to start in (ProvinceDef id); empty = a random one.
var start: String = ""
## AI rulers, 1-3 (owner's survey 2026-11-09).
var rulers: int = 2
var difficulty: int = NORMAL
var victory: StringName = VICTORY_CONQUEST
## Provinces to hold (VICTORY_PROVINCES) or patricians to house (VICTORY_PATRICIANS).
var victory_target: int = 0
## The gold target of the Merchant islands (M8 part 5).
var gold_target: int = DEFAULT_GOLD
## The Invasion: the first waves that only plunder (PLUNDER_ALL: all), and the survival mode.
var plunder_waves: int = DEFAULT_PLUNDER
var endless: bool = false
## A world of islands only, as in the Merchant islands, but with the rules of Colonization or
## the Divided continent (UI-2 part 3, owner's survey 2026-11-13: free play among islands too).
var archipelago: bool = false
## Started in the developer mode (E4 part 1, the "New game" tick box). Only how the game began:
## the mode itself is Simulation.dev_mode (F12 switches it).
var dev_mode: bool = false


## Makes the settings fit the scenario: the Merchant islands are won by gold, the Invasion from
## the sea by holding out and has no rulers (owner's survey 2026-11-10).
func fit_scenario() -> void:
	match scenario:
		ISLANDS:
			victory = VICTORY_GOLD
			gold_target = clampi(gold_target, MIN_GOLD, MAX_GOLD)
		INVASION:
			victory = VICTORY_ENDLESS if endless else VICTORY_SURVIVE
			rulers = 0
			archipelago = false
		_:
			endless = false
			if victory == VICTORY_GOLD or victory == VICTORY_SURVIVE or victory == VICTORY_ENDLESS:
				victory = VICTORY_CONQUEST


## The level the rulers grow, arm and dare by: EASY, NORMAL or HARD (PEACEFUL grows as EASY).
func growth_level() -> int:
	return GameSettings.EASY if difficulty == PEACEFUL else clampi(difficulty, EASY, HARD)


func is_peaceful() -> bool:
	return difficulty == PEACEFUL


## Whether the world is islands only: the Merchant islands always, other scenarios by choice.
func is_archipelago() -> bool:
	return scenario == ISLANDS or archipelago


func is_generated() -> bool:
	return world_def == &""


## The default target of [param kind]: half the world's provinces, or 100 patricians.
func default_target(kind: StringName) -> int:
	match kind:
		VICTORY_PROVINCES:
			return maxi(province_count / 2, 4)
		VICTORY_PATRICIANS:
			return 100
		VICTORY_GOLD:
			return DEFAULT_GOLD
		VICTORY_SURVIVE:
			return SURVIVE_MINUTES
	return 0


func target() -> int:
	match victory:
		VICTORY_GOLD:
			return gold_target
		VICTORY_SURVIVE:
			return SURVIVE_MINUTES
	return victory_target if victory_target > 0 else default_target(victory)


func to_dict() -> Dictionary:
	return {"scenario": String(scenario), "seed": world_seed, "world": String(world_def),
			"provinces": province_count, "islands": islands, "start": start, "rulers": rulers, "difficulty": difficulty,
			"victory": String(victory), "target": victory_target, "gold": gold_target,
			"plunder": plunder_waves, "endless": endless, "archipelago": archipelago}.merged({"dev": true} if dev_mode else {})


static func from_dict(d: Dictionary) -> GameSettings:
	var s := GameSettings.new()
	s.scenario = StringName(String(d.get("scenario", COLONIZATION)))
	s.world_seed = int(d.get("seed", 1))
	s.world_def = StringName(String(d.get("world", "")))
	s.province_count = int(d.get("provinces", 22))
	s.islands = int(d.get("islands", 0))
	s.start = String(d.get("start", ""))
	s.rulers = clampi(int(d.get("rulers", 2)), 0, 3)
	s.difficulty = clampi(int(d.get("difficulty", NORMAL)), EASY, PEACEFUL)
	s.victory = StringName(String(d.get("victory", VICTORY_CONQUEST)))
	s.victory_target = int(d.get("target", 0))
	s.gold_target = int(d.get("gold", DEFAULT_GOLD))
	s.plunder_waves = int(d.get("plunder", DEFAULT_PLUNDER))
	s.endless = bool(d.get("endless", false))
	s.archipelago = bool(d.get("archipelago", false))
	s.dev_mode = bool(d.get("dev", false))
	return s

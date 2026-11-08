class_name BanditCamp
extends RefCounted
## The bandits' camp on the world map (GDD §9, ROADMAP M7 part 3): it stands in an empty
## province, sends a raid now and then at a province of the player (an army of bandits that
## walks there on the world map) and keeps the gold the raids bring back. The player's army can
## break it up: the hoard goes to the player and a new camp comes up later in another empty
## province.

## First raid after 40 minutes of play, then every 25 to 40 minutes (as in part 2).
const FIRST_SECONDS := 40.0 * 60.0
const GAP_MIN_SECONDS := 25.0 * 60.0
const GAP_MAX_SECONDS := 40.0 * 60.0
## A broken camp comes back after this long, somewhere else.
const RESPAWN_SECONDS := 30.0 * 60.0
## Men guarding the camp.
const GUARDS: Dictionary[StringName, int] = {&"spearman": 6, &"archer": 3}

## Province of the camp; 0 = broken (comes back at [member respawn_at]).
var province: int = 0
var guards: Dictionary[StringName, int] = {}
var next_raid: int = -1
var raids: int = 0
var respawn_at: int = 0
## The hoard: the gold the raids brought (the player gets it when he breaks the camp).
var gold: int = 0


func is_up() -> bool:
	return province != 0


func side() -> BattleSide:
	return BattleSide.new(guards)


func to_dict() -> Dictionary:
	var d := {"province": province, "guards": Expedition.goods_to_dict(guards), "next": next_raid,
			"raids": raids}
	if respawn_at != 0:
		d["respawn"] = respawn_at
	if gold != 0:
		d["gold"] = gold
	return d


static func from_dict(d: Dictionary) -> BanditCamp:
	var c := BanditCamp.new()
	c.province = int(d.get("province", 0))
	c.guards = Expedition.goods_from(d.get("guards", {}))
	c.next_raid = int(d.get("next", -1))
	c.raids = int(d.get("raids", 0))
	c.respawn_at = int(d.get("respawn", 0))
	c.gold = int(d.get("gold", 0))
	return c

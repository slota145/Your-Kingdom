class_name Rulers
extends RefCounted
## The AI rulers of a sandbox game (ROADMAP M8): owners "ruler_1".."ruler_3" of provinces on the
## world map. Part 1: they hold their start towns and wait; parts 3-4: they build, settle, trade
## and fight. Their names are translated (ruler.<owner>.name), their colours fixed here.

const PREFIX := "ruler_"
## The raiders from over the sea (M8 part 5, the Invasion): an owner like a ruler (their army
## storms towns and holds what it takes, the player can take it back), but they neither build,
## settle, recruit nor count among the rulers of the game.
const RAIDERS := &"ruler_raiders"


static func is_ruler(owner: StringName) -> bool:
	return String(owner).begins_with(PREFIX)


static func is_raiders(owner: StringName) -> bool:
	return owner == RAIDERS


## The rulers that hold at least one province, sorted (not the raiders).
static func alive(world: WorldSim) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: int in world.ids():
		var owner := world.owner_of(id)
		if is_ruler(owner) and owner != RAIDERS and not result.has(owner):
			result.append(owner)
	result.sort()
	return result


## Provinces held by [param owner].
static func provinces_of(world: WorldSim, owner: StringName) -> Array[int]:
	var result: Array[int] = []
	for id: int in world.ids():
		if world.owner_of(id) == owner:
			result.append(id)
	return result

class_name Rulers
extends RefCounted
## The AI rulers of a sandbox game (ROADMAP M8): owners "ruler_1".."ruler_3" of provinces on the
## world map. Part 1: they hold their start towns and wait; parts 3-4: they build, settle, trade
## and fight. Their names are translated (ruler.<owner>.name), their colours fixed here.

const PREFIX := "ruler_"


static func is_ruler(owner: StringName) -> bool:
	return String(owner).begins_with(PREFIX)


## The rulers that hold at least one province, sorted.
static func alive(world: WorldSim) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: int in world.ids():
		var owner := world.owner_of(id)
		if is_ruler(owner) and not result.has(owner):
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

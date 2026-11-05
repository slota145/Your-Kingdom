class_name ConstructionSite
extends RefCounted
## A building being built or a house being upgraded (GDD §5.1, ROADMAP M3): porters bring
## the materials into the site's own stock, builders use up one phase's share and work
## until the phase is done. Addressed by its own entity id, like a storage.

const KIND_BUILD := &"build"
const KIND_UPGRADE := &"upgrade"

var id: int
var building_id: int
var kind: StringName = KIND_BUILD
## 1-based current phase.
var phase: int = 1
## Goods per phase, index 0 = phase 1.
var phase_costs: Array[Dictionary] = []
## Builder ticks per phase.
var phase_ticks: int = 0
## Whether the current phase's materials were used up and building started.
var phase_started: bool = false
## Builder ticks left in the current phase.
var work_left: int = 0
## Materials delivered and not used yet.
var stock: Stockpile


func _init(entity_id: int, building: int, site_kind: StringName, costs: Array[Dictionary],
		ticks_per_phase: int, data: DataRegistry) -> void:
	id = entity_id
	building_id = building
	kind = site_kind
	phase_costs = costs
	phase_ticks = ticks_per_phase
	work_left = ticks_per_phase
	var slots := 0
	for good: StringName in total_cost():
		slots += ceili(total_cost()[good] / float(maxi(data.get_good(good).stack_size, 1)))
	stock = Stockpile.new(maxi(slots, 1), data)


func phase_count() -> int:
	return phase_costs.size()


func total_cost() -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for cost: Dictionary in phase_costs:
		for good: StringName in cost:
			result[good] = result.get(good, 0) + int(cost[good])
	return result


func current_cost() -> Dictionary:
	return phase_costs[phase - 1] if phase <= phase_count() else {}


## Materials for the current phase lie on the site.
func has_phase_materials() -> bool:
	var cost := current_cost()
	for good: StringName in cost:
		if stock.available(good) < int(cost[good]):
			return false
	return true


## A builder has something to do here right now.
func is_workable() -> bool:
	return phase_started or has_phase_materials()


## 0..1 over all phases (UI).
func progress() -> float:
	var done := float(phase - 1) + (1.0 - float(work_left) / maxi(phase_ticks, 1) if phase_started else 0.0)
	return clampf(done / maxi(phase_count(), 1), 0.0, 1.0)


func to_dict() -> Dictionary:
	var costs: Array = []
	for cost: Dictionary in phase_costs:
		var c := {}
		for good: StringName in cost:
			c[String(good)] = int(cost[good])
		costs.append(c)
	return {"id": id, "building": building_id, "kind": String(kind), "phase": phase,
			"costs": costs, "phase_ticks": phase_ticks, "started": phase_started,
			"work_left": work_left, "stock": stock.to_dict()}


static func from_dict(d: Dictionary, data: DataRegistry) -> ConstructionSite:
	var costs: Array[Dictionary] = []
	for c: Variant in d["costs"]:
		var cost: Dictionary[StringName, int] = {}
		for good: Variant in c:
			cost[StringName(String(good))] = int(c[good])
		costs.append(cost)
	var site := ConstructionSite.new(int(d["id"]), int(d["building"]), StringName(String(d["kind"])),
			costs, int(d["phase_ticks"]), data)
	site.phase = int(d["phase"])
	site.phase_started = bool(d["started"])
	site.work_left = int(d["work_left"])
	site.stock = Stockpile.from_dict(d["stock"], data)
	return site

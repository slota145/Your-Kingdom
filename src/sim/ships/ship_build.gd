class_name ShipBuild
extends RefCounted
## A ship on a shipyard's slipway (GDD §5.4, M5): the first order of the shipyard's queue.
## Porters bring all materials into its own stock at once (like a construction site); the
## shipwright uses up each stage's share and works the stage off. After the last stage the
## ship is launched at the shipyard's berth. Addressed by its own entity id, like a storage.

var id: int
var shipyard_id: int
var ship: StringName
## 0-based current stage.
var stage: int = 0
## Goods per stage.
var stage_costs: Array[Dictionary] = []
## Shipwright ticks per stage.
var stage_ticks: int = 0
## Whether the current stage's materials were used up and work started.
var stage_started: bool = false
## Shipwright ticks left in the current stage.
var work_left: int = 0
## Materials delivered and not used yet.
var stock: Stockpile


func _init(entity_id: int, shipyard: int, ship_def: ShipDef, data: DataRegistry) -> void:
	id = entity_id
	shipyard_id = shipyard
	ship = ship_def.id
	for s: int in ship_def.stages:
		stage_costs.append(ship_def.stage_cost(s))
	stage_ticks = maxi(SimClock.seconds_to_ticks(ship_def.build_time / ship_def.stages), 1)
	work_left = stage_ticks
	var slots := 0
	for good: StringName in ship_def.build_cost:
		slots += ceili(ship_def.build_cost[good] / float(maxi(data.get_good(good).stack_size, 1)))
	stock = Stockpile.new(maxi(slots, 1), data)


func stage_count() -> int:
	return stage_costs.size()


func total_cost() -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for cost: Dictionary in stage_costs:
		for good: StringName in cost:
			result[good] = result.get(good, 0) + int(cost[good])
	return result


func current_cost() -> Dictionary:
	return stage_costs[stage] if stage < stage_count() else {}


## Goods the stages not started yet still use up.
func still_needed() -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for s: int in range(stage + (1 if stage_started else 0), stage_count()):
		for good: StringName in stage_costs[s]:
			result[good] = result.get(good, 0) + int(stage_costs[s][good])
	return result


## A good of the current stage still missing on the slipway, &"" when all are there.
func missing_good() -> StringName:
	var cost := current_cost()
	for good: StringName in cost:
		if stock.available(good) < int(cost[good]):
			return good
	return &""


## Stages finished so far, as the view shows them on the slipway (0 = only the keel blocks).
func stages_done() -> int:
	return stage


## 0..1 over all stages (UI).
func progress() -> float:
	var done := float(stage) + (1.0 - float(work_left) / maxi(stage_ticks, 1) if stage_started else 0.0)
	return clampf(done / maxi(stage_count(), 1), 0.0, 1.0)


func to_dict() -> Dictionary:
	return {"id": id, "shipyard": shipyard_id, "ship": String(ship), "stage": stage,
			"started": stage_started, "work_left": work_left, "stock": stock.to_dict()}


static func from_dict(d: Dictionary, data: DataRegistry) -> ShipBuild:
	var build := ShipBuild.new(int(d["id"]), int(d["shipyard"]),
			data.get_ship(StringName(String(d["ship"]))), data)
	build.stage = int(d.get("stage", 0))
	build.stage_started = bool(d.get("started", false))
	build.work_left = int(d.get("work_left", build.stage_ticks))
	build.stock = Stockpile.from_dict(d["stock"], data)
	return build

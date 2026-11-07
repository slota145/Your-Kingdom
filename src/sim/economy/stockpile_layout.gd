class_name StockpileLayout
extends RefCounted
## Pure mapping from a stockpile slot to how its stack looks (ARCHITECTURE §6.5).

const FILL_STAGES := 4


## Fill stage 0 (empty) .. [param stages] (full stack) for [param amount] of [param stack_size].
## G2: a stack sheet with one frame per piece has stages == stack_size, so every piece shows.
static func fill_stage(amount: int, stack_size: int, stages: int = FILL_STAGES) -> int:
	if amount <= 0:
		return 0
	return clampi(ceili(float(amount) * stages / maxi(stack_size, 1)), 1, maxi(stages, 1))


## {good, amount, stack_size, fill_stage} of one slot; good is &"" for an empty slot.
static func visual_for(stock: Stockpile, slot: int) -> Dictionary:
	var good := stock.slot_good[slot]
	var amount := stock.slot_amount[slot]
	if good == &"" or amount <= 0:
		return {"good": &"", "amount": 0, "stack_size": 1, "fill_stage": 0}
	var size := stock.stack_size(good)
	return {"good": good, "amount": amount, "stack_size": size, "fill_stage": fill_stage(amount, size)}


## Tile offset of a slot inside a building footprint: row by row, skipping the entrance.
static func slot_tile(slot: int, footprint: Vector2i, entrance: Vector2i) -> Vector2i:
	var i := 0
	for y: int in footprint.y:
		for x: int in footprint.x:
			var t := Vector2i(x, y)
			if t == entrance:
				continue
			if i == slot:
				return t
			i += 1
	return Vector2i(slot % maxi(footprint.x, 1), slot / maxi(footprint.x, 1))

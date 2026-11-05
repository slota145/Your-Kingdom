class_name StockpileLayout
extends RefCounted
## Pure mapping from a stockpile slot to how its stack looks (ARCHITECTURE §6.5).

const FILL_STAGES := 4


## Fill stage 0 (empty) .. FILL_STAGES (full stack) for [param amount] of [param stack_size].
static func fill_stage(amount: int, stack_size: int) -> int:
	if amount <= 0:
		return 0
	return clampi(ceili(float(amount) * FILL_STAGES / maxi(stack_size, 1)), 1, FILL_STAGES)


## {good, amount, fill_stage} of one slot; good is &"" for an empty slot.
static func visual_for(stock: Stockpile, slot: int) -> Dictionary:
	var good := stock.slot_good[slot]
	var amount := stock.slot_amount[slot]
	if good == &"" or amount <= 0:
		return {"good": &"", "amount": 0, "fill_stage": 0}
	return {"good": good, "amount": amount, "fill_stage": fill_stage(amount, stock.stack_size(good))}


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

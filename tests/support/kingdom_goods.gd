class_name KingdomGoods
extends RefCounted
## Goods that belong to the player's kingdom in a province, for the M6 tests of switching
## modes: everything ProvinceSim.goods_total counts (stores, piles, sites, ships, hands) except
## what the merchants hold (paid for or theirs), plus a landing kit not on the beach yet.


static func of(province: ProvinceSim) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for good: GoodDef in province.data.goods():
		var sum := province.goods_total(good.id)
		if province.merchant.wagon != null:
			sum -= province.merchant.wagon.total(good.id)
		var foreign := province.ships.get(province.sea_merchant.ship_id) as ShipUnit
		if foreign != null and province.sea_merchant.ship_id != 0:
			sum -= foreign.hold.total(good.id)
		if province.landing != null and province.landing.state == Landing.State.COMING:
			sum += int(province.landing.kit.get(good.id, 0))
		if sum != 0:
			result[good.id] = sum
	return result

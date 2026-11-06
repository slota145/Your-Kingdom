class_name Treasury
extends RefCounted
## The kingdom's gold (GDD §3.5), the only global resource. Houses pay taxes a little every
## second; the fractional part is kept so nothing is lost to rounding. Some buildings cost gold.

enum TaxRate { LOW, NORMAL, HIGH }

## Tax multiplier per rate.
const RATE_FACTOR: Array[float] = [0.5, 1.0, 1.5]
## Happiness points added to every house's target per rate (GDD §3.5: the rate affects happiness).
const RATE_HAPPINESS: Array[float] = [10.0, 0.0, -15.0]

var gold: int = 0
var tax_rate: int = TaxRate.NORMAL
var _fraction: float = 0.0


func can_pay(amount: int) -> bool:
	return gold >= amount


## Takes [param amount] gold if there is enough. Returns whether it was paid.
func pay(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	return true


## Adds gold, keeping fractions for later (taxes per second are small).
func add(amount: float) -> void:
	# On a grid a save reads back exactly, so a loaded game goes on alike.
	_fraction = SimCodec.savable(_fraction + amount)
	var whole := floori(_fraction)
	gold += whole
	_fraction -= whole


func rate_factor() -> float:
	return RATE_FACTOR[tax_rate]


func rate_happiness() -> float:
	return RATE_HAPPINESS[tax_rate]


func to_dict() -> Dictionary:
	return {"gold": gold, "rate": tax_rate, "fraction": _fraction}


static func from_dict(d: Dictionary) -> Treasury:
	var t := Treasury.new()
	t.gold = int(d.get("gold", 0))
	t.tax_rate = clampi(int(d.get("rate", TaxRate.NORMAL)), TaxRate.LOW, TaxRate.HIGH)
	t._fraction = float(d.get("fraction", 0.0))
	return t

class_name SetTaxRateCommand
extends Command
## Sets the tax rate (GDD §3.5): low, normal or high. Higher taxes, less happy houses.

var rate: int


func _init(value: int) -> void:
	rate = value


func validate(_sim: Simulation) -> StringName:
	if rate < Treasury.TaxRate.LOW or rate > Treasury.TaxRate.HIGH:
		return &"invalid_value"
	return &""


func apply(sim: Simulation) -> void:
	sim.treasury.tax_rate = rate
	sim.events.emit(&"tax_rate_changed", {"rate": rate})


func get_name() -> StringName:
	return &"set_tax_rate"

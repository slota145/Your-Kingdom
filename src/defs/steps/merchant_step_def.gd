class_name MerchantStepDef
extends StepDef
## The travelling merchant's whole visit (M4b-2, Merchant): walk to the market, trade there,
## walk back to the map edge.


func get_step_kind() -> StringName:
	return &"merchant"

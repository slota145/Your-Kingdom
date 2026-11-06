class_name DisbandExpeditionCommand
extends Command
## Disbands the expedition of settlers getting ready (or ready) in province [member province_id]
## before it is sent (owner's decision 2026-11-06): the settlers move back into their houses,
## the kit goes back to the storages, the cog back to anchor. Nothing was paid yet.

var province_id: int


func _init(id: int) -> void:
	province_id = id


func validate(sim: Simulation) -> StringName:
	var province := sim.province_state(province_id)
	if province == null or province.departure == null or not province.departure.can_disband():
		return &"no_expedition"
	return &""


func apply(sim: Simulation) -> void:
	var province := sim.province_state(province_id)
	province.departure.disband(province, not sim.is_detailed(province_id))
	province.departure = null
	sim.events.emit(&"expedition_disbanded", {"province": province_id})


func get_name() -> StringName:
	return &"disband_expedition"

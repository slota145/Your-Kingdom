class_name EnterProvinceCommand
extends Command
## The player enters a settled province from the world map (ROADMAP M6): it comes to the
## detailed mode, the province viewed so far goes to the simplified one (ARCHITECTURE §7.2).

var province_id: int


func _init(id: int) -> void:
	province_id = id


func validate(sim: Simulation) -> StringName:
	if sim.world.get_province(province_id) == null:
		return &"unknown_province"
	var expedition := sim.world.expedition_to(province_id)
	if not sim.runtimes.has(province_id):
		# An expedition waiting at its border lands when the player comes (M6 part 2).
		return &"" if expedition != null and expedition.state == Expedition.State.WAITING \
				else &"unknown_province"
	if sim.world.owner_of(province_id) != ProvinceDef.OWNER_PLAYER:
		return &"not_your_province"
	return &""


func apply(sim: Simulation) -> void:
	sim.view_province(province_id)


func get_name() -> StringName:
	return &"enter_province"

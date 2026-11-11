class_name StartResearchCommand
extends Command
## Starts a research of the kingdom, or puts it in the queue while another is studied (ROADMAP
## E4 part 2): its gold is paid when it starts.

var research_id: StringName


func _init(id: StringName) -> void:
	research_id = id


func validate(sim: Simulation) -> StringName:
	if sim.research.open:
		return &"research_open"
	var error := sim.research.plan_error(sim.data, research_id)
	if error != &"":
		return error
	var def := sim.data.get_research(research_id)
	if not Researching.has_institution(sim, def.institution):
		return &"needs_school" if def.institution == ResearchDef.SCHOOL else &"needs_university"
	var starts_now := sim.research.current == &"" and sim.research.queue.is_empty()
	if starts_now and not sim.treasury.can_pay(def.gold_cost):
		return &"not_enough_gold"
	return &""


func apply(sim: Simulation) -> void:
	Researching.plan(sim, research_id)


func get_name() -> StringName:
	return &"start_research"

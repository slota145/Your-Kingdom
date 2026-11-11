class_name CancelResearchCommand
extends Command
## Stops the research being studied (its gold comes back, its progress is lost) or takes one
## out of the queue, with the queued researches that need it (ROADMAP E4 part 2).

var research_id: StringName


func _init(id: StringName) -> void:
	research_id = id


func validate(sim: Simulation) -> StringName:
	if sim.research.current != research_id and not sim.research.queue.has(research_id):
		return &"research_not_planned"
	return &""


func apply(sim: Simulation) -> void:
	Researching.cancel(sim, research_id)


func get_name() -> StringName:
	return &"cancel_research"

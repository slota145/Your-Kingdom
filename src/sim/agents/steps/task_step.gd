class_name TaskStep
extends RefCounted
## Executes one kind of StepDef for an agent, a little every tick. Executors are stateless:
## everything they remember lives in the task blackboard. Keys starting with "_" are local
## to the step and are cleared when it ends.

enum Status { RUNNING, DONE, FAILED }


func run(_province: ProvinceSim, _agent: Agent, _def: StepDef) -> Status:
	return Status.DONE


## Marks why the step failed (shown in events and debug views).
static func failed(agent: Agent, reason: StringName) -> Status:
	agent.task.bb["fail_reason"] = String(reason)
	return Status.FAILED

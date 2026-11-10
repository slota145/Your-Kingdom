class_name SurvivalRecord
extends RefCounted
## The best score of the Invasion's survival mode on this computer (owner's request 2026-11-10):
## the most waves held off (and the minutes then). Kept outside the saves, in user://.

const PATH := "user://records.cfg"
const SECTION := "invasion_endless"


## The record so far: [waves, minutes] ([0, 0] when none).
static func best(path: String = PATH) -> Array[int]:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return [0, 0]
	return [int(file.get_value(SECTION, "waves", 0)), int(file.get_value(SECTION, "minutes", 0))]


## Notes a game that held off [param waves] waves for [param minutes]; returns whether it is a
## new record (more waves, or as many in more minutes).
static func submit(waves: int, minutes: int, path: String = PATH) -> bool:
	var old := best(path)
	if waves < old[0] or (waves == old[0] and minutes <= old[1]):
		return false
	var file := ConfigFile.new()
	file.load(path)
	file.set_value(SECTION, "waves", waves)
	file.set_value(SECTION, "minutes", minutes)
	file.save(path)
	return true

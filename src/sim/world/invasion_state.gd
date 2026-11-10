class_name InvasionState
extends RefCounted
## The clock of the Invasion from the sea (M8 part 5, Invasion): when the game began (the
## player holds out from here), how many waves set out and when the next one does. Saved with
## the world (save v31).

var started: int = 0
var wave: int = 0
var next_wave: int = 0


func to_dict() -> Dictionary:
	return {"started": started, "wave": wave, "next": next_wave}


static func from_dict(d: Dictionary) -> InvasionState:
	var s := InvasionState.new()
	s.started = int(d.get("started", 0))
	s.wave = int(d.get("wave", 0))
	s.next_wave = int(d.get("next", 0))
	return s

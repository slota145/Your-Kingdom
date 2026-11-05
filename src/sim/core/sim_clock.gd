class_name SimClock
extends RefCounted
## Fixed-step simulation clock (ARCHITECTURE §4.2): 10 ticks per second of game time.
##
## The caller feeds scaled real time (delta × speed, 0 when paused) and runs the returned
## number of ticks. Only [member tick] is simulation state; the accumulator is not saved.

const TICKS_PER_SECOND := 10
const TICK := 1.0 / TICKS_PER_SECOND
## Upper bound of ticks per frame, so a slow frame cannot snowball (spiral of death).
const MAX_TICKS_PER_FRAME := 8

## Ticks simulated since the start of the game.
var tick: int = 0

var _accumulator: float = 0.0


static func seconds_to_ticks(seconds: float) -> int:
	return maxi(1, roundi(seconds * TICKS_PER_SECOND))


## Adds game time and returns how many ticks are due now (0..MAX_TICKS_PER_FRAME).
func consume(game_delta: float) -> int:
	_accumulator += maxf(game_delta, 0.0)
	# The epsilon absorbs float error, e.g. 60 frames of 1/60 s must give exactly 10 ticks.
	var due := floori(_accumulator / TICK + 1e-6)
	if due > MAX_TICKS_PER_FRAME:
		due = MAX_TICKS_PER_FRAME
		_accumulator = 0.0
	else:
		_accumulator = maxf(_accumulator - due * TICK, 0.0)
	return due


## Fraction (0..1) of the next tick already elapsed; used by the view to interpolate.
func alpha() -> float:
	return clampf(_accumulator / TICK, 0.0, 1.0)


func seconds() -> float:
	return tick * TICK

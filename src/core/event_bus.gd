extends Node
## Autoload "EventBus": broadcasts events from the simulation and app to view/UI.

## Emitted for every event drained from the simulation's event queue (from M2).
@warning_ignore("unused_signal")
signal sim_event_emitted(event: Dictionary)

## Emitted after the UI language has changed.
@warning_ignore("unused_signal")
signal language_changed(locale: String)

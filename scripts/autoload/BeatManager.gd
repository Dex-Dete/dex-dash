extends Node
## BeatManager - emits signals on musical beats for beat-synced effects.
## Watches AudioManager playback position.

signal beat(bar: int)
signal pulse(strength: float)

var _in_window := false
var bar := 0


func _process(_dt: float) -> void:
	if AudioManager._current_track == "":
		return
	var phase := AudioManager.beat_phase()
	if phase < 0.06 and not _in_window:
		_in_window = true
		bar = (bar + 1) % 4
		beat.emit(bar)
		pulse.emit(1.0)
	elif phase > 0.3:
		_in_window = false

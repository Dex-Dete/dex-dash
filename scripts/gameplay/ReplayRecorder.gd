class_name ReplayRecorder
## ReplayRecorder - records per-tick input states and packs them compactly.
## Format: "DXR2" header + u32 tick count + bit-packed jump-hold states (base64).
## Each bit is whether the jump button was HELD that tick, so press and
## release transitions can be recovered (needed for ship/wave hold input).

const HEADER := "DXR2"


static func pack(ticks: Array) -> String:
	# ticks: Array of bool (0/1), index = tick, value = held state
	var bytes := PackedByteArray()
	for i in range(0, ticks.size(), 8):
		var b := 0
		for j in range(8):
			if i + j < ticks.size() and bool(ticks[i + j]):
				b |= 1 << j
		bytes.append(b)
	var buf := PackedByteArray()
	buf.append_array(HEADER.to_utf8_buffer())
	buf.append_array(_u32(ticks.size()))
	buf.append_array(bytes)
	return Marshalls.raw_to_base64(buf)


static func unpack(data: String) -> Dictionary:
	# returns {tick_count: int, held: Array[bool]}
	if data.is_empty():
		return {}
	var buf := Marshalls.base64_to_raw(data)
	if buf.size() < 8:
		return {}
	if buf.slice(0, 4).get_string_from_utf8() != HEADER:
		return {}
	var tick_count := _read_u32(buf, 4)
	var held: Array = []
	for i in tick_count:
		var byte := buf[8 + i / 8]
		held.append((byte >> (i % 8)) & 1 == 1)
	return {"tick_count": tick_count, "held": held}


static func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray([0, 0, 0, 0])
	b.encode_u32(0, v)
	return b


static func _read_u32(buf: PackedByteArray, off: int) -> int:
	return buf.decode_u32(off)


class Recorder:
	var ticks: Array = []
	var recording := false

	func start() -> void:
		recording = true
		ticks.clear()

	func record_tick(jump_held: bool) -> void:
		if recording:
			ticks.append(jump_held)

	func stop() -> String:
		recording = false
		if ticks.is_empty():
			return ""
		return ReplayRecorder.pack(ticks)

	func tick_count() -> int:
		return ticks.size()


class Playback:
	var held: Array = []
	var tick_count := 0
	var _idx := 0

	func load(data: String) -> bool:
		var d := ReplayRecorder.unpack(data)
		if d.is_empty():
			return false
		held = d["held"]
		tick_count = int(d["tick_count"])
		_idx = 0
		return true

	func advance() -> bool:
		# returns whether the run is still alive at this tick
		var alive := _idx < tick_count
		_idx += 1
		return alive

	func held_now() -> bool:
		return _idx - 1 < held.size() and bool(held[_idx - 1])

	func pressed_this_tick() -> bool:
		# just-pressed: held now but not held on the previous tick
		if _idx - 1 >= held.size():
			return false
		if not held[_idx - 1]:
			return false
		return _idx - 2 < 0 or not held[_idx - 2]

	func jump_this_tick() -> bool:
		return pressed_this_tick()

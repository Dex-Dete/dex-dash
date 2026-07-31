class_name ReplayRecorder
## ReplayRecorder - records per-tick inputs and packs them compactly.
## Format: "DXR1" header + u32 tick count + bit-packed jump presses (base64).

const HEADER := "DXR1"


static func pack(ticks: Array) -> String:
	# ticks: Array of bool (or 0/1), index = tick
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
	# returns {tick_count: int, jumps: Array[bool]}
	if data.is_empty():
		return {}
	var buf := Marshalls.base64_to_raw(data)
	if buf.size() < 8:
		return {}
	if buf.slice(0, 4).get_string_from_utf8() != HEADER:
		return {}
	var tick_count := _read_u32(buf, 4)
	var jumps: Array = []
	for i in tick_count:
		var byte := buf[8 + i / 8]
		jumps.append((byte >> (i % 8)) & 1 == 1)
	return {"tick_count": tick_count, "jumps": jumps}


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

	func record_tick(jump_pressed: bool) -> void:
		if recording:
			ticks.append(jump_pressed)

	func stop() -> String:
		recording = false
		if ticks.is_empty():
			return ""
		return ReplayRecorder.pack(ticks)

	func tick_count() -> int:
		return ticks.size()


class Playback:
	var jumps: Array = []
	var tick_count := 0
	var _idx := 0

	func load(data: String) -> bool:
		var d := ReplayRecorder.unpack(data)
		if d.is_empty():
			return false
		jumps = d["jumps"]
		tick_count = int(d["tick_count"])
		_idx = 0
		return true

	func advance() -> bool:
		# returns whether the run is still alive at this tick
		var alive := _idx < tick_count
		_idx += 1
		return alive

	func jump_this_tick() -> bool:
		return _idx - 1 < jumps.size() and bool(jumps[_idx - 1])

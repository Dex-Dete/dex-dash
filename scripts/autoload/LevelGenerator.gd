class_name LevelGenerator
## LevelGenerator - procedural chunk generator for Endless and Daily modes.
## Produces original, difficulty-scaled gameplay segments.

static func make_chunk(kind: String, difficulty: String, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var gnd_y := -1  # ground at y=-1 means ground row occupies y=0
	match kind:
		"flat":
			_out_ground(out, 0, 16, gnd_y)
		"gap":
			var gap := rng.randi_range(2, 4)
			_out_ground(out, 0, 6, gnd_y)
			_out_ground(out, 6 + gap, 10, gnd_y)
			if difficulty in ["hard", "harder", "insane", "extreme"]:
				_out_ground(out, 6 + gap, 2, gnd_y - 3)
		"spikes":
			_out_ground(out, 0, 16, gnd_y)
			var n := rng.randi_range(1, 3)
			var start := rng.randi_range(1, 8)
			for i in n:
				out.append({"t": "spike_up", "x": start + i * 2, "y": gnd_y})
			if difficulty in ["harder", "insane", "extreme"]:
				out.append({"t": "spike_up", "x": start + n * 2 + 1, "y": gnd_y})
		"steps":
			_out_ground(out, 0, 16, gnd_y)
			var dir := 1 if rng.randi() % 2 == 0 else -1
			var h0 := gnd_y - (1 if dir == 1 else 3)
			for i in 5:
				out.append({"t": "ground", "x": 2 + i * 2, "y": h0 + i * dir})
			if difficulty in ["insane", "extreme"]:
				out.append({"t": "spike_up", "x": 4 + rng.randi_range(0, 2) * 2, "y": h0 + 1})
		"stair":
			var h := rng.randi_range(2, 4)
			for i in 6:
				_out_ground(out, i * 2, 2, gnd_y - (h - i if h >= i else 0) - 1 + 1)
			# simpler: descending staircase
			out = []
			for i in 6:
				_out_ground(out, i * 2, 3, gnd_y - i)
			_out_ground(out, 12, 6, gnd_y - 5)
		"portal_grav":
			_out_ground(out, 0, 8, gnd_y)
			_out_ground(out, 8, 10, gnd_y)
			out.append({"t": "portal_grav_up", "x": 7, "y": gnd_y - 2})
			# ceiling path
			_out_ground(out, 8, 10, gnd_y - 6)
			out.append({"t": "portal_grav_down", "x": 17, "y": gnd_y - 5})
			_out_ground(out, 18, 8, gnd_y)
		"portal_speed":
			_out_ground(out, 0, 14, gnd_y)
			out.append({"t": "portal_speed", "x": 6, "y": gnd_y - 1, "v": rng.randi_range(2, 4)})
			out.append({"t": "portal_speed", "x": 12, "y": gnd_y - 1, "v": 1})
		"coin_row":
			_out_ground(out, 0, 16, gnd_y)
			for i in 4:
				out.append({"t": "coin", "x": 3 + i * 2, "y": gnd_y - 2})
		"pad":
			_out_ground(out, 0, 16, gnd_y)
			out.append({"t": "pad", "x": 6, "y": gnd_y})
			out.append({"t": "coin", "x": 7, "y": gnd_y - 5})
			out.append({"t": "coin", "x": 9, "y": gnd_y - 4})
	return out


static func chunk_width(chunk: Array) -> int:
	var w := 0
	for o in chunk:
		w = max(w, int(o.get("x", 0)) + 2)
	return w


static func build_endless() -> Dictionary:
	# Infinite-style level: a long run of chunks with rising difficulty.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system())
	var tiers := ["easy", "normal", "hard", "harder", "insane", "extreme"]
	var chunk_count := 140
	var objs: Array = []
	var x := -2
	for i in chunk_count:
		var diff: String = tiers[mini(i / 22, tiers.size() - 1)]
		var kinds := ["flat", "gap", "spikes", "steps", "stair", "pad", "coin_row"]
		if i > 30:
			kinds.append("portal_grav")
		if i > 55:
			kinds.append("portal_speed")
		var t: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var chunk := make_chunk(t, diff, rng)
		for o in chunk:
			var copy: Dictionary = o.duplicate()
			copy["x"] = int(copy["x"]) + x
			objs.append(copy)
		x += chunk_width(chunk)
	return {
		"id": "endless", "name": "Endless Circuit", "difficulty": "hard",
		"music": "endless", "theme": "cyber", "bpm": 130,
		"length": x, "objects": objs, "start": {"x": -2, "y": 0},
	}


static func _out_ground(out: Array, x: int, w: int, y: int) -> void:
	for i in w:
		out.append({"t": "ground", "x": x + i, "y": y})

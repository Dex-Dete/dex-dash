class_name LevelData
## LevelData - level representation: object list, collision grid, validation.
## A level is a list of objects: {t: type, x: cell, y: cell, v: variant}.
## Coordinates: cells. Y grows downward (screen convention). Ground at y=0
## occupies the cell from y=0 to y=1.

const SOLID_TYPES := ["ground", "pad", "finish"]
const HAZARD_TYPES := ["spike_up", "spike_down", "spike_left", "spike_right"]
const PORTAL_TYPES := ["portal_grav_up", "portal_grav_down", "portal_speed",
	"portal_size", "portal_dash", "portal_teleport", "portal_rotate_cw",
	"portal_rotate_ccw", "portal_spin"]
const COIN_TYPES := ["coin", "coin_secret"]
const DECO_TYPES := ["deco_star", "deco_crystal", "deco_orb", "deco_gear"]
const BOSS_TYPES := ["boss_core", "boss_eye"]

var id := ""
var name := ""
var difficulty := "easy"
var music := "easy"
var theme := "cyber"
var bpm := 128.0
var objects: Array = []
var start := Vector2i(-1, 0)
var length := 40
var story := ""
var is_boss := false
var is_tutorial := false

var _ground: Dictionary = {}        # "x,y" -> true
var _hazards: Dictionary = {}       # "x,y" -> type
var _coins: Dictionary = {}         # "x,y" -> {type, taken}
var _portals: Dictionary = {}       # "x,y" -> obj dict
var _checkpoints: Dictionary = {}   # "x,y" -> obj dict
var _pads: Dictionary = {}          # "x,y" -> true
var _finish: Vector2i = Vector2i(-1, -1)
var _deco: Dictionary = {}          # "x,y" -> type
var _boss_objs: Dictionary = {}     # "x,y" -> obj dict
var _teleports: Array = []          # portal objs with pair ids


static func from_dict(d: Dictionary) -> LevelData:
	var lv := LevelData.new()
	lv.id = str(d.get("id", ""))
	lv.name = str(d.get("name", "Unnamed"))
	lv.difficulty = str(d.get("difficulty", "easy"))
	lv.music = str(d.get("music", "easy"))
	lv.theme = str(d.get("theme", "cyber"))
	lv.bpm = float(d.get("bpm", 128.0))
	lv.length = int(d.get("length", 40))
	lv.story = str(d.get("story", ""))
	var s: Dictionary = d.get("start", {"x": -1, "y": 0})
	lv.start = Vector2i(int(s.get("x", -1)), int(s.get("y", 0)))
	var objs: Array = d.get("objects", [])
	for o in objs:
		if o is Dictionary:
			lv.add_object(o)
	return lv


func add_object(o: Dictionary) -> void:
	var t: String = str(o.get("t", ""))
	if t == "":
		return
	objects.append(o)
	var key := "%d,%d" % [int(o.x), int(o.y)]
	var x := int(o.x)
	var y := int(o.y)
	if t == "ground":
		_ground[key] = true
	elif t == "pad":
		_pads[key] = true
		_ground[key] = true
	elif t in HAZARD_TYPES:
		_hazards[key] = t
	elif t in COIN_TYPES:
		_coins[key] = {"type": t, "taken": false}
	elif t in PORTAL_TYPES:
		_portals[key] = o
		if t == "portal_teleport":
			_teleports.append(o)
	elif t == "checkpoint":
		_checkpoints[key] = o
	elif t == "finish":
		_finish = Vector2i(x, y)
	elif t in DECO_TYPES:
		_deco[key] = t
	elif t in BOSS_TYPES:
		_boss_objs[key] = o


func solid_at(cx: int, cy: int) -> bool:
	return _ground.has("%d,%d" % [cx, cy])


func hazard_at(cx: int, cy: int) -> String:
	return str(_hazards.get("%d,%d" % [cx, cy], ""))


func coin_at(cx: int, cy: int) -> Dictionary:
	return _coins.get("%d,%d" % [cx, cy], {})


func take_coin(cx: int, cy: int) -> String:
	var key := "%d,%d" % [cx, cy]
	if not _coins.has(key) or bool(_coins[key]["taken"]):
		return ""
	_coins[key]["taken"] = true
	return str(_coins[key]["type"])


func portal_at(cx: int, cy: int) -> Dictionary:
	return _portals.get("%d,%d" % [cx, cy], {})


func checkpoint_at(cx: int, cy: int) -> Dictionary:
	return _checkpoints.get("%d,%d" % [cx, cy], {})


func pad_at(cx: int, cy: int) -> bool:
	return _pads.has("%d,%d" % [cx, cy])


func deco_at(cx: int, cy: int) -> String:
	return str(_deco.get("%d,%d" % [cx, cy], ""))


func boss_at(cx: int, cy: int) -> Dictionary:
	return _boss_objs.get("%d,%d" % [cx, cy], {})


func teleport_target(pair_id: String, current: Vector2 = Vector2.INF) -> Vector2:
	for o in _teleports:
		if str(o.get("pair", "")) == pair_id:
			var op := Vector2(int(o.x), int(o.y))
			if current == Vector2.INF or (op - current).length() > 0.5:
				return op
	return Vector2.ZERO


func total_coins() -> int:
	var n := 0
	for c in _coins.values():
		if str(c["type"]) == "coin":
			n += 1
	return n


func total_secret_coins() -> int:
	var n := 0
	for c in _coins.values():
		if str(c["type"]) == "coin_secret":
			n += 1
	return n


func has_finish() -> bool:
	return _finish != Vector2i(-1, -1)


func finish_pos() -> Vector2i:
	return _finish


func validate() -> Array:
	var errors: Array = []
	if objects.is_empty():
		errors.append("Level has no objects")
	if not has_finish():
		errors.append("Level has no finish")
	if start.x < -4:
		errors.append("Level has no start")
	return errors


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "difficulty": difficulty,
		"music": music, "theme": theme, "bpm": bpm, "length": length,
		"story": story, "start": {"x": start.x, "y": start.y},
		"objects": objects,
	}


func to_json() -> String:
	return JSON.stringify(to_dict())


static func from_json(text: String) -> LevelData:
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return from_dict(parsed)
	return null


func max_x() -> int:
	var mx := 0
	for o in objects:
		mx = max(mx, int(o.x))
	return mx + 2

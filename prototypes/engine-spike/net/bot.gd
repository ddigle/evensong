extends RefCounted
## Scripted player for the net spike (CLI: --script-actions=...). Pure logic: step() turns the
## player's current position into an input direction and requests, so the same bot drives a
## client (input goes to the host) or the host's own player.
##
## Actions are separated by ';'. Cell coordinates are tiles relative to the player's spawn cell.
##   move:dx,dy    walk to the centre of that cell (gives up after MOVE_TIMEOUT_TICKS)
##   break:dx,dy   ask the host to break the wall in that cell (several may share one tick)
##   wait:n        idle n physics ticks
##   patrol:s      walk left/right for s seconds (flip every PATROL_FLIP_TICKS)
##   barrier:name  report arrival, then wait until the host releases that barrier
##   burst:n       host only: n tile edits in one tick (bandwidth measurement)
##   forge:dx,dy   test only: send a fake host delta (bedrock at that cell); everyone must refuse it

const TileWorld := preload("res://net/tile_world.gd")

const TICKS_PER_SEC: int = 60
const ARRIVE_PX: float = 3.0
## Inside this distance the speed scales down (no overshoot from network lag).
const SLOW_PX: float = 24.0
const MOVE_TIMEOUT_TICKS: int = 600
const PATROL_FLIP_TICKS: int = 30
const OPS: PackedStringArray = ["move", "break", "wait", "patrol", "barrier", "burst", "forge"]

var actions: Array[Dictionary] = []
var index: int = 0
var origin: Vector2i = Vector2i.ZERO
var finished: bool = false
var notes: PackedStringArray = []
var _ticks: int = 0
var _arrived: bool = false


## Returns "" or an error message. Empty text = no actions (finished at once).
func parse(text: String) -> String:
	actions.clear()
	for raw: String in text.split(";", false):
		var item: String = raw.strip_edges()
		if item.is_empty():
			continue
		var colon: int = item.find(":")
		if colon < 0:
			return "action without ':' -> %s" % item
		var op: String = item.substr(0, colon)
		var arg: String = item.substr(colon + 1)
		var action: Dictionary = {"op": op, "text": item}
		match op:
			"move", "break", "forge":
				var parts: PackedStringArray = arg.split(",")
				if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
					return "bad cell in %s" % item
				action["cell"] = Vector2i(parts[0].to_int(), parts[1].to_int())
			"wait", "burst":
				if not arg.is_valid_int() or arg.to_int() < 0:
					return "bad count in %s" % item
				action["n"] = arg.to_int()
			"patrol":
				if not arg.is_valid_float() or arg.to_float() < 0.0:
					return "bad seconds in %s" % item
				action["n"] = int(round(arg.to_float() * TICKS_PER_SEC))
			"barrier":
				if arg.is_empty():
					return "barrier needs a name"
				action["name"] = arg
			_:
				return "unknown action %s (known: %s)" % [op, ", ".join(OPS)]
		actions.append(action)
	index = 0
	finished = actions.is_empty()
	return ""


## Names of the barriers in the script, in order.
func barrier_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for action: Dictionary in actions:
		if action["op"] == "barrier":
			out.append(str(action["name"]))
	return out


## One physics tick. `released` holds the barrier names the host has released.
## Returns {direction: Vector2, breaks: Array[Vector2i], arrive: String, burst: int,
## forge: Array[Vector2i]}.
func step(pos: Vector2, released: Dictionary) -> Dictionary:
	var breaks: Array[Vector2i] = []
	var forge: Array[Vector2i] = []
	var out: Dictionary = {"direction": Vector2.ZERO, "breaks": breaks, "arrive": "", "burst": 0,
		"forge": forge}
	while index < actions.size():
		var action: Dictionary = actions[index]
		match str(action["op"]):
			"move":
				var target: Vector2 = TileWorld.cell_center(origin + (action["cell"] as Vector2i))
				var to_target: Vector2 = target - pos
				var dist: float = to_target.length()
				if dist <= ARRIVE_PX:
					_next()
					continue
				if _ticks >= MOVE_TIMEOUT_TICKS:
					notes.append("move timeout: %s (%.1f px short)" % [action["text"], dist])
					_next()
					continue
				out["direction"] = to_target / maxf(dist, SLOW_PX)
				_ticks += 1
				return out
			"break":
				breaks.append(origin + (action["cell"] as Vector2i))
				_next()
				continue
			"forge":
				forge.append(origin + (action["cell"] as Vector2i))
				_next()
				continue
			"wait":
				if _ticks >= int(action["n"]):
					_next()
					continue
				_ticks += 1
				return out
			"patrol":
				if _ticks >= int(action["n"]):
					_next()
					continue
				var sign_x: float = 1.0 if (_ticks / PATROL_FLIP_TICKS) % 2 == 0 else -1.0
				out["direction"] = Vector2(sign_x, 0.0)
				_ticks += 1
				return out
			"barrier":
				var barrier: String = str(action["name"])
				if not _arrived:
					_arrived = true
					out["arrive"] = barrier
					return out
				if released.has(barrier):
					_next()
					continue
				return out
			"burst":
				out["burst"] = int(action["n"])
				_next()
				return out
	finished = true
	return out


func _next() -> void:
	index += 1
	_ticks = 0
	_arrived = false

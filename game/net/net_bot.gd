class_name NetBot
extends RefCounted
## Scripted input for the local player (--bot=<script>): tests drive real sessions with it, and a
## human can use it to set a scene up. One command per ";", run on physics ticks:
##   wait:<ticks>                 stand still
##   move:<dx>,<dy>,<ticks>       hold a direction (-1/0/1 per axis) for that many ticks
##   edit:<x>,<y>,<grass|soil>    host only: debug world edit (floor at cell x,y), logged and
##                                replicated like a real edit (late joiners get it)
##   mark:<name>                  write the marker file <net-out>/<net-name>.<name>.marker
##   leave                        client: leave the session (exit 0)
## A finished bot stands still. Its script starts when the host says go (session flags).

const OPS: PackedStringArray = ["wait", "move", "edit", "mark", "leave"]

class Command:
	extends RefCounted
	var op: String = ""
	var dir: Vector2i = Vector2i.ZERO
	var ticks: int = 0
	var cell: Vector2i = Vector2i.ZERO
	var terrain: int = 0
	var name: String = ""


## What the bot does this tick.
class Action:
	extends RefCounted
	var dir: Vector2i = Vector2i.ZERO
	var edit: Command
	var mark: String = ""
	var leave: bool = false


var commands: Array[Command] = []
var index: int = 0
var finished: bool = false
var _left: int = -1


## Parses `text`; returns "" or the first error.
func parse(text: String) -> String:
	commands.clear()
	index = 0
	_left = -1
	finished = false
	for part: String in text.split(";", false):
		var item: String = part.strip_edges()
		if item.is_empty():
			continue
		var colon: int = item.find(":")
		var c: Command = Command.new()
		c.op = item if colon < 0 else item.substr(0, colon)
		var args: PackedStringArray = PackedStringArray() if colon < 0 else item.substr(colon + 1).split(",")
		var error: String = _fill(c, args)
		if not error.is_empty():
			return "%s: %s" % [item, error]
		commands.append(c)
	finished = commands.is_empty()
	return ""


func _fill(c: Command, args: PackedStringArray) -> String:
	match c.op:
		"wait":
			if args.size() != 1 or not _whole(args[0], 0):
				return "expected wait:<ticks>"
			c.ticks = args[0].to_int()
		"move":
			if args.size() != 3 or not _axis(args[0]) or not _axis(args[1]) or not _whole(args[2], 1):
				return "expected move:<dx>,<dy>,<ticks> with dx, dy in -1..1"
			c.dir = Vector2i(args[0].to_int(), args[1].to_int())
			c.ticks = args[2].to_int()
		"edit":
			if args.size() != 3 or not _whole(args[0], 0) or not _whole(args[1], 0):
				return "expected edit:<x>,<y>,<grass|soil>"
			var terrain: int = Terrain.NAMES.find(args[2])
			if terrain < 0 or not EditLog.EDITABLE_TERRAINS.has(terrain):
				return "terrain must be grass or soil"
			c.cell = Vector2i(args[0].to_int(), args[1].to_int())
			c.terrain = terrain
		"mark":
			if args.size() != 1 or not args[0].is_valid_filename() or args[0].is_empty():
				return "expected mark:<name>"
			c.name = args[0]
		"leave":
			if args.size() != 0:
				return "leave takes no arguments"
		_:
			return "unknown command (%s)" % ", ".join(OPS)
	return ""


static func _whole(text: String, minimum: int) -> bool:
	return text.is_valid_int() and text.to_int() >= minimum


static func _axis(text: String) -> bool:
	return text.is_valid_int() and absi(text.to_int()) <= 1


## Advances one tick.
func step() -> Action:
	var a: Action = Action.new()
	while not finished:
		var c: Command = commands[index]
		match c.op:
			"wait", "move":
				if _left < 0:
					_left = c.ticks
				if _left > 0:
					_left -= 1
					a.dir = c.dir
					if _left == 0:
						_next()
					return a
				_next()
			"edit":
				a.edit = c
				_next()
				return a
			"mark":
				a.mark = c.name
				_next()
				return a
			"leave":
				a.leave = true
				_next()
				return a
	return a


## Total ticks of wait/move commands (how long the script runs at least).
func duration_ticks() -> int:
	var n: int = 0
	for c: Command in commands:
		n += c.ticks
	return n


func _next() -> void:
	index += 1
	_left = -1
	if index >= commands.size():
		finished = true

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
##   stall:<ms>                   test only: block the whole process that long after this tick, in
##                                the process step (NetSession._process): a long frame, the kind
##                                Godot follows with catch-up physics ticks before it polls the network
## M2b (items and actions; the mouse is the aim set here):
##   walkto:<x>,<y>[,<ticks>]     walk to the centre of tile x,y (gives up after <ticks>, default 600)
##   aim:<dx>,<dy> | aim:off      from now on aim at the feet + (dx, dy) px / stop aiming
##   aimat:<x>,<y>                from now on aim at the centre of tile x,y
##   use:<ticks>                  hold the use button (left click) that many ticks, standing
##   pick[:<times>]               press F (pick up from the target tile) on each of the next <times> ticks
##   select:<1..8>                select that hotbar slot (Q / E)
##   drop[:<count>]               debug: drop <count> (default all) of the selected stack on the target tile
##   give:<id>[:<count>[:<grade>]]  debug: items into the inventory (a client asks the host for them)
## M3b (maps; F = pick is also how a bot goes down the entrance or up the stairs):
##   waitmap:<players>,<map>[,<ticks>]  stand still until at least <players> players are on <map>
##                                (surface / dungeon / 0 / 1) as this machine knows it (the session
##                                sets map_counts each tick); gives up after <ticks> (default 1800)
## M4a (offline; M4b: in sessions too):
##   dash:<dx>,<dy>               press Space this tick, holding that direction (0,0 = the facing)
##   hold:<ticks>                 hold F that many ticks, standing (revive a downed player next to you;
##                                while down, give up)
## M4b (the heretics as this machine draws them, `foes`, and the local player's life, `life`, set by the
## session or Main before each step):
##   aimfoe                       from now on aim at the nearest live heretic (none: not aiming; M4-fix: at
##                                the middle of its figure, Combat.body_centre)
##   fight:<ticks>[,<n>[,<px>]]   hold the use button aimed at the nearest live heretic (its middle) while more than n
##                                (default 0) are there, at most that many ticks; with px, walk toward it
##                                while it is farther than px (melee)
##   closein:<px>[,<ticks>]       walk toward the nearest live heretic until within px of it (default 600)
##   waitfoe:<n>[,<ticks>]        stand until at most n live heretics are there (default 1800)
##   waitlife:<alive|down|dead>[,<ticks>]   stand until the local player is that (default 1800)
##   waitdown:<n>[,<ticks>]       stand until at least n players on this map are down (default 1800)
##   walkdown[:<ticks>]           walk next to the nearest downed player (within 12 px; default 600 ticks)
## M6a (offline: Main handles them; M6b: in sessions too, Main through NetSession.bot_ui, a craft becomes a
## CRAFT request and a throw a THROW frame):
##   tab                          press Tab this tick (the crafting panel at a station, else the inventory)
##   craft:<row>                  craft row <row> (1 = the top) of the open crafting panel
##   throw                        press the skill key 1 this tick (the herbalist throws the selected potion
##                                toward the aim)
## M5c (the fields as this machine's world has them, `world`, set by the session or Main before each step):
##   waitfield:<x>,<y>,<soil|0..4>[,<ticks>]   stand until tile x,y is tilled soil (soil) or holds a crop at that
##                                stage or later, not withered (default 1800 ticks)
## M7a (offline: Main handles them):
##   store:<n>                    click inventory slot <n> (1 = the hotbar's first) of the open chest panel: store it
##   take:<n>                     click chest slot <n> (1 = the top left) of the open chest panel: take it
##   unequip                      click the armour slot (the open inventory): take the worn armour off
## M7b (offline: Main handles it; building is a click with a piece selected = use, a door is F = pick):
##   wreck                        right-click this tick: take the built piece on the target tile down
## M7c (sessions: store / take / unequip go to Main through NetSession.bot_gear and become CHEST / ARMOR requests, wreck a
## DEMOLISH; the world as this machine has it, `world`):
##   waitwall:<x>,<y>,<none|wall|door|open>[,<ticks>]   stand until tile x,y's wall layer holds that (a built stone wall, a
##                                closed door, an open door, nothing; default 1800 ticks). M7-rf: a floor piece is no wall
##                                kind now: waitfloor
##   waitfloor:<x>,<y>,<none|stone>[,<ticks>]   M7-rf: stand until tile x,y's floor piece layer (WorldData.Layer.FLOOR_PIECE)
##                                holds that (a stone floor piece, nothing; under a wall too; default 1800 ticks)
##   heretic:<x>,<y>              test only, offline and the host: a heretic on tile x,y of the local player's map now
##   waitat:<x>,<y>[,<ticks>]     stand until another player on this map (as this machine has it, `others`) has its feet
##                                on tile x,y (default 1800 ticks)
##   waitplaced:<x>,<y>,<placeable>[,<ticks>]   stand until tile x,y holds that placeable (WorldData.PLACEABLE_NAMES:
##                                chest, anvil, stump, tree ...; default 1800 ticks)
##   waitchest:<x>,<y>,<item>[,<ticks>]   stand until the chest with a tile at x,y holds that item (default 1800 ticks)
## A finished bot stands still. Its script starts when the host says go (session flags).

const OPS: PackedStringArray = ["wait", "move", "edit", "mark", "leave", "stall", "walkto", "aim", "aimat", "use", "pick",
	"select", "drop", "give", "waitmap", "dash", "hold", "aimfoe", "fight", "closein", "waitfoe", "waitlife", "waitdown",
	"walkdown", "tab", "craft", "throw", "waitfield", "store", "take", "unequip", "wreck", "waitwall", "heretic", "waitat",
	"waitplaced", "waitchest", "waitfloor"]
## M7c: waitwall's kinds by name (Walls.KIND_*; M7-rf: "floor" left, a floor piece is waitfloor's).
const WALL_NAMES: Dictionary[String, int] = {"none": Walls.KIND_NONE, "wall": Walls.KIND_STONE, "door": Walls.KIND_DOOR,
	"open": Walls.KIND_DOOR_OPEN}
## Longest stall a script may ask for (a test hook, not a way to hang a session for good).
const MAX_STALL_MS: int = 5000
const WALK_LIMIT_TICKS: int = 600
const WAITMAP_LIMIT_TICKS: int = 1800
## walkto stops on an axis within this many px of the target (half a step: 1.2 px per tick).
const ARRIVE_PX: float = 0.6

enum Aiming { NONE, OFFSET, CELL, FOE }

class Command:
	extends RefCounted
	var op: String = ""
	var dir: Vector2i = Vector2i.ZERO
	var ticks: int = 0
	var cell: Vector2i = Vector2i.ZERO
	var terrain: int = 0
	var name: String = ""
	var stall_ms: int = 0
	var offset: Vector2 = Vector2.ZERO
	var aiming: int = Aiming.NONE
	var slot: int = 0
	var count: int = 0
	var item: StringName = &""
	var grade: int = -1
	var map: int = 0


## What the bot does this tick.
class Action:
	extends RefCounted
	var dir: Vector2i = Vector2i.ZERO
	var edit: Command
	var mark: String = ""
	var leave: bool = false
	## Test only: block the process this long after the tick (NetSession._process).
	var stall_ms: int = 0
	## M2b: where the mouse is (world px) and whether the player aims; the use button.
	var mouse: Vector2 = Vector2.ZERO
	var aiming: bool = false
	var use_pressed: bool = false
	var use_held: bool = false
	## M2b: a request this tick (op and fields; PICKUP / DROP get the target tile when the frame is built).
	var op: NetProtocol.InputFrame
	## M4a: Space this tick, F held.
	var dash: bool = false
	var interact: bool = false
	## M6a: Tab this tick, a crafting panel row to craft (0-based, -1 = none), the skill key 1 this tick.
	var tab: bool = false
	var craft_row: int = -1
	var skill: bool = false
	## M7a: a chest panel click this tick (0-based inventory / chest slot, -1 = none), the armour slot clicked.
	var store_slot: int = -1
	var take_slot: int = -1
	var unequip: bool = false
	## M7b: right-click this tick (take a built piece down).
	var demolish: bool = false
	## M7c (test only): put a heretic on this tile of the local player's map this tick (Vector2i, or null).
	var heretic: Variant = null


var commands: Array[Command] = []
## M3b: players per map as this machine knows it (set by the session before each step; waitmap).
var map_counts: Dictionary[int, int] = {}
## M4b: the live heretics' feet as this machine draws them, and the local player's life (Vitals.Life).
var foes: Array[Vector2] = []
var life: int = Vitals.Life.ALIVE
## M4b: where the players on this map that are down lie, as this machine knows it.
var downed: Array[Vector2] = []
## M5c: the local player's map's world as this machine has it (waitfield).
var world: WorldData
## M7c: the other players' feet on the local player's map as this machine has them (waitat).
var others: Array[Vector2] = []
## walkdown stops this near a downed player (well inside Config.REVIVE_REACH_PX).
const DOWN_NEAR_PX: float = 12.0
var index: int = 0
var finished: bool = false
var _left: int = -1
var _aiming: int = Aiming.NONE
var _aim: Vector2 = Vector2.ZERO
var _held_last: bool = false


## Parses `text`; returns "" or the first error.
func parse(text: String) -> String:
	commands.clear()
	index = 0
	_left = -1
	finished = false
	_aiming = Aiming.NONE
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
		"stall":
			if args.size() != 1 or not _whole(args[0], 1) or args[0].to_int() > MAX_STALL_MS:
				return "expected stall:<ms> with ms in 1..%d" % MAX_STALL_MS
			c.stall_ms = args[0].to_int()
		"walkto":
			if args.size() < 2 or args.size() > 3 or not _whole(args[0], 0) or not _whole(args[1], 0) \
					or (args.size() == 3 and not _whole(args[2], 1)):
				return "expected walkto:<x>,<y>[,<ticks>]"
			c.cell = Vector2i(args[0].to_int(), args[1].to_int())
			c.ticks = args[2].to_int() if args.size() == 3 else WALK_LIMIT_TICKS
		"aim":
			if args.size() == 1 and args[0] == "off":
				c.aiming = Aiming.NONE
			elif args.size() == 2 and args[0].is_valid_float() and args[1].is_valid_float():
				c.aiming = Aiming.OFFSET
				c.offset = Vector2(args[0].to_float(), args[1].to_float())
			else:
				return "expected aim:<dx>,<dy> or aim:off"
		"aimat":
			if args.size() != 2 or not _whole(args[0], 0) or not _whole(args[1], 0):
				return "expected aimat:<x>,<y>"
			c.aiming = Aiming.CELL
			c.cell = Vector2i(args[0].to_int(), args[1].to_int())
		"use":
			if args.size() != 1 or not _whole(args[0], 1):
				return "expected use:<ticks>"
			c.ticks = args[0].to_int()
		"pick":
			if args.size() > 1 or (args.size() == 1 and not _whole(args[0], 1)):
				return "expected pick[:<times>]"
			c.ticks = args[0].to_int() if args.size() == 1 else 1
		"select":
			if args.size() != 1 or not _whole(args[0], 1) or args[0].to_int() > Config.HOTBAR_SLOTS:
				return "expected select:<1..%d>" % Config.HOTBAR_SLOTS
			c.slot = args[0].to_int() - 1
		"drop":
			if args.size() > 1 or (args.size() == 1 and not _whole(args[0], 1)) or (args.size() == 1 and args[0].to_int() > 255):
				return "expected drop[:<count 1..255>]"
			c.count = args[0].to_int() if args.size() == 1 else 0
		"give":
			if args.size() != 1:
				return "expected give:<id>[:<count>[:<grade>]]"
			var parts: PackedStringArray = args[0].split(":")
			c.item = StringName(parts[0])
			if not ItemDB.has(c.item):
				return "unknown item %s" % parts[0]
			c.count = parts[1].to_int() if parts.size() > 1 and _whole(parts[1], 1) else 1
			if parts.size() > 1 and not _whole(parts[1], 1) or c.count > 255:
				return "count must be 1..255"
			if parts.size() > 2:
				c.grade = ItemDB.grade_from_name(parts[2])
				if not ItemDB.valid_grade(c.item, c.grade):
					return "%s takes no grade %s" % [parts[0], parts[2]]
		"dash":
			if args.size() != 2 or not _axis(args[0]) or not _axis(args[1]):
				return "expected dash:<dx>,<dy> with dx, dy in -1..1"
			c.dir = Vector2i(args[0].to_int(), args[1].to_int())
		"hold":
			if args.size() != 1 or not _whole(args[0], 1):
				return "expected hold:<ticks>"
			c.ticks = args[0].to_int()
		"aimfoe":
			if args.size() != 0:
				return "aimfoe takes no arguments"
		"tab", "throw", "unequip", "wreck":
			if args.size() != 0:
				return "%s takes no arguments" % c.op
		"store", "take":
			if args.size() != 1 or not _whole(args[0], 1):
				return "expected %s:<slot>" % c.op
			c.count = args[0].to_int() - 1
		"craft":
			if args.size() != 1 or not _whole(args[0], 1):
				return "expected craft:<row>"
			c.count = args[0].to_int() - 1
		"fight":
			if args.size() < 1 or args.size() > 3 or not _whole(args[0], 1) or (args.size() >= 2 and not _whole(args[1], 0)) \
					or (args.size() == 3 and not args[2].is_valid_float()):
				return "expected fight:<ticks>[,<n>[,<px>]]"
			c.ticks = args[0].to_int()
			c.count = args[1].to_int() if args.size() >= 2 else 0
			c.offset = Vector2(args[2].to_float() if args.size() == 3 else 0.0, 0.0)
		"walkdown":
			if args.size() > 1 or (args.size() == 1 and not _whole(args[0], 1)):
				return "expected walkdown[:<ticks>]"
			c.ticks = args[0].to_int() if args.size() == 1 else WALK_LIMIT_TICKS
		"waitdown":
			if args.size() < 1 or args.size() > 2 or not _whole(args[0], 1) or (args.size() == 2 and not _whole(args[1], 1)):
				return "expected waitdown:<n>[,<ticks>]"
			c.count = args[0].to_int()
			c.ticks = args[1].to_int() if args.size() == 2 else WAITMAP_LIMIT_TICKS
		"closein":
			if args.size() < 1 or args.size() > 2 or not args[0].is_valid_float() or (args.size() == 2 and not _whole(args[1], 1)):
				return "expected closein:<px>[,<ticks>]"
			c.offset = Vector2(args[0].to_float(), 0.0)
			c.ticks = args[1].to_int() if args.size() == 2 else WALK_LIMIT_TICKS
		"waitfoe":
			if args.size() < 1 or args.size() > 2 or not _whole(args[0], 0) or (args.size() == 2 and not _whole(args[1], 1)):
				return "expected waitfoe:<n>[,<ticks>]"
			c.count = args[0].to_int()
			c.ticks = args[1].to_int() if args.size() == 2 else WAITMAP_LIMIT_TICKS
		"waitlife":
			if args.size() < 1 or args.size() > 2 or not Vitals.LIFE_NAMES.has(args[0]) or (args.size() == 2 and not _whole(args[1], 1)):
				return "expected waitlife:<alive|down|dead>[,<ticks>]"
			c.count = Vitals.LIFE_NAMES.find(args[0])
			c.ticks = args[1].to_int() if args.size() == 2 else WAITMAP_LIMIT_TICKS
		"waitfield":
			if args.size() < 3 or args.size() > 4 or not _whole(args[0], 0) or not _whole(args[1], 0) \
					or not (args[2] == "soil" or (_whole(args[2], 0) and args[2].to_int() < Farming.STAGES)) \
					or (args.size() == 4 and not _whole(args[3], 1)):
				return "expected waitfield:<x>,<y>,<soil|0..%d>[,<ticks>]" % (Farming.STAGES - 1)
			c.cell = Vector2i(args[0].to_int(), args[1].to_int())
			c.count = -1 if args[2] == "soil" else args[2].to_int()
			c.ticks = args[3].to_int() if args.size() == 4 else WAITMAP_LIMIT_TICKS
		"waitwall":
			if args.size() < 3 or args.size() > 4 or not _whole(args[0], 0) or not _whole(args[1], 0) \
					or not WALL_NAMES.has(args[2]) or (args.size() == 4 and not _whole(args[3], 1)):
				return "expected waitwall:<x>,<y>,<%s>[,<ticks>]" % "|".join(WALL_NAMES.keys())
			c.cell = Vector2i(args[0].to_int(), args[1].to_int())
			c.count = WALL_NAMES[args[2]]
			c.ticks = args[3].to_int() if args.size() == 4 else WAITMAP_LIMIT_TICKS
		"waitfloor":
			if args.size() < 3 or args.size() > 4 or not _whole(args[0], 0) or not _whole(args[1], 0) \
					or not WorldData.FLOOR_PIECE_NAMES.has(args[2]) or (args.size() == 4 and not _whole(args[3], 1)):
				return "expected waitfloor:<x>,<y>,<%s>[,<ticks>]" % "|".join(WorldData.FLOOR_PIECE_NAMES)
			c.cell = Vector2i(args[0].to_int(), args[1].to_int())
			c.count = WorldData.FLOOR_PIECE_NAMES.find(args[2])
			c.ticks = args[3].to_int() if args.size() == 4 else WAITMAP_LIMIT_TICKS
		"heretic":
			if args.size() != 2 or not _whole(args[0], 0) or not _whole(args[1], 0):
				return "expected heretic:<x>,<y>"
			c.cell = Vector2i(args[0].to_int(), args[1].to_int())
		"waitat":
			if args.size() < 2 or args.size() > 3 or not _whole(args[0], 0) or not _whole(args[1], 0) \
					or (args.size() == 3 and not _whole(args[2], 1)):
				return "expected waitat:<x>,<y>[,<ticks>]"
			c.cell = Vector2i(args[0].to_int(), args[1].to_int())
			c.ticks = args[2].to_int() if args.size() == 3 else WAITMAP_LIMIT_TICKS
		"waitplaced":
			if args.size() < 3 or args.size() > 4 or not _whole(args[0], 0) or not _whole(args[1], 0) \
					or not WorldData.PLACEABLE_NAMES.has(args[2]) or (args.size() == 4 and not _whole(args[3], 1)):
				return "expected waitplaced:<x>,<y>,<placeable>[,<ticks>]"
			c.cell = Vector2i(args[0].to_int(), args[1].to_int())
			c.count = WorldData.PLACEABLE_NAMES.find(args[2])
			c.ticks = args[3].to_int() if args.size() == 4 else WAITMAP_LIMIT_TICKS
		"waitchest":
			if args.size() < 3 or args.size() > 4 or not _whole(args[0], 0) or not _whole(args[1], 0) \
					or not ItemDB.has(StringName(args[2])) or (args.size() == 4 and not _whole(args[3], 1)):
				return "expected waitchest:<x>,<y>,<item>[,<ticks>]"
			c.cell = Vector2i(args[0].to_int(), args[1].to_int())
			c.item = StringName(args[2])
			c.ticks = args[3].to_int() if args.size() == 4 else WAITMAP_LIMIT_TICKS
		"waitmap":
			if args.size() < 2 or args.size() > 3 or not _whole(args[0], 1) or (args.size() == 3 and not _whole(args[2], 1)):
				return "expected waitmap:<players>,<map>[,<ticks>]"
			c.count = args[0].to_int()
			c.map = Config.MAP_NAMES.find(args[1]) if not args[1].is_valid_int() else args[1].to_int()
			if not NetProtocol.valid_map(c.map):
				return "unknown map %s" % args[1]
			c.ticks = args[2].to_int() if args.size() == 3 else WAITMAP_LIMIT_TICKS
		_:
			return "unknown command (%s)" % ", ".join(OPS)
	return ""


static func _whole(text: String, minimum: int) -> bool:
	return text.is_valid_int() and text.to_int() >= minimum


static func _axis(text: String) -> bool:
	return text.is_valid_int() and absi(text.to_int()) <= 1


## Advances one tick. `feet` = the local player's feet now (walkto and the aim need it).
func step(feet: Vector2 = Vector2.ZERO) -> Action:
	var a: Action = Action.new()
	_fill_aim(a, feet)
	_advance(a, feet)
	a.use_pressed = a.use_held and not _held_last
	_held_last = a.use_held
	return a


func _advance(a: Action, feet: Vector2) -> void:
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
					return
				_next()
			"edit":
				a.edit = c
				_next()
				return
			"mark":
				a.mark = c.name
				_next()
				return
			"leave":
				a.leave = true
				_next()
				return
			"stall":
				a.stall_ms = c.stall_ms
				_next()
				return
			"walkto":
				if _left < 0:
					_left = c.ticks
				var target: Vector2 = (Vector2(c.cell) + Vector2(0.5, 0.5)) * Config.TILE
				var d: Vector2 = target - feet
				a.dir = Vector2i(_toward(d.x), _toward(d.y))
				_left -= 1
				if a.dir == Vector2i.ZERO or _left <= 0:
					_next()
				if a.dir != Vector2i.ZERO:
					return
			"aim", "aimat":
				_aiming = c.aiming
				_aim = c.offset if c.aiming == Aiming.OFFSET else (Vector2(c.cell) + Vector2(0.5, 0.5)) * Config.TILE
				_next()
				_fill_aim(a, feet)
			"use":
				if _left < 0:
					_left = c.ticks
				if _left > 0:
					_left -= 1
					a.use_held = true
					if _left == 0:
						_next()
					return
				_next()
			"pick":
				if _left < 0:
					_left = c.ticks
				_left -= 1
				a.op = NetProtocol.InputFrame.new()
				a.op.op = NetProtocol.Op.PICKUP
				if _left <= 0:
					_next()
				return
			"select":
				a.op = NetProtocol.InputFrame.new()
				a.op.op = NetProtocol.Op.SELECT
				a.op.slot = c.slot
				_next()
				return
			"drop":
				a.op = NetProtocol.InputFrame.new()
				a.op.op = NetProtocol.Op.DROP
				a.op.count = c.count
				a.op.slot = -1  # the selected slot, filled in when the frame is built
				_next()
				return
			"dash":
				a.dir = c.dir
				a.dash = true
				_next()
				return
			"tab":
				a.tab = true
				_next()
				return
			"craft":
				a.craft_row = c.count
				_next()
				return
			"throw":
				a.skill = true
				_next()
				return
			"store":
				a.store_slot = c.count
				_next()
				return
			"take":
				a.take_slot = c.count
				_next()
				return
			"unequip":
				a.unequip = true
				_next()
				return
			"wreck":
				a.demolish = true
				_next()
				return
			"hold":
				if _left < 0:
					_left = c.ticks
				if _left > 0:
					_left -= 1
					a.interact = true
					if _left == 0:
						_next()
					return
				_next()
			"waitfield":
				if _left < 0:
					_left = c.ticks
				_left -= 1
				if field_ready(world, c.cell, c.count) or _left <= 0:
					_next()
				return
			"waitwall":
				if _left < 0:
					_left = c.ticks
				_left -= 1
				if (world != null and world.in_bounds(c.cell) and Walls.kind_at(world, c.cell) == c.count) or _left <= 0:
					_next()
				return
			"waitfloor":
				if _left < 0:
					_left = c.ticks
				_left -= 1
				if (world != null and world.in_bounds(c.cell)
						and world.get_value(WorldData.Layer.FLOOR_PIECE, c.cell) == c.count) or _left <= 0:
					_next()
				return
			"heretic":
				a.heretic = c.cell
				_next()
				return
			"waitat", "waitplaced", "waitchest":
				if _left < 0:
					_left = c.ticks
				_left -= 1
				if _waited(c) or _left <= 0:
					_next()
				return
			"waitmap":
				if _left < 0:
					_left = c.ticks
				var there: int = map_counts.get(c.map, 0)
				_left -= 1
				if there >= c.count or _left <= 0:
					_next()
				return
			"aimfoe":
				_aiming = Aiming.FOE
				_next()
				_fill_aim(a, feet)
			"fight":
				if _left < 0:
					_left = c.ticks
				var target: Variant = nearest_foe(feet)
				if target == null or _left <= 0 or foes.size() <= c.count:
					_next()
				else:
					_left -= 1
					var at: Vector2 = target
					a.aiming = true
					a.mouse = Combat.body_centre(at)  # M4-fix: the middle of the figure, like a player clicking on it
					if c.offset.x > 0.0 and feet.distance_to(at) > c.offset.x:
						a.dir = Vector2i(_toward(at.x - feet.x), _toward(at.y - feet.y))
					else:
						a.use_held = true
					return
			"closein":
				if _left < 0:
					_left = c.ticks
				var foe: Variant = nearest_foe(feet)
				_left -= 1
				var near: bool = foe == null
				if not near:
					var to: Vector2 = foe
					near = feet.distance_to(to) <= c.offset.x
					if not near and _left > 0:
						a.dir = Vector2i(_toward(to.x - feet.x), _toward(to.y - feet.y))
						return
				_next()
			"waitfoe":
				if _left < 0:
					_left = c.ticks
				_left -= 1
				if foes.size() <= c.count or _left <= 0:
					_next()
				return
			"waitlife":
				if _left < 0:
					_left = c.ticks
				_left -= 1
				if life == c.count or _left <= 0:
					_next()
				return
			"waitdown":
				if _left < 0:
					_left = c.ticks
				_left -= 1
				if downed.size() >= c.count or _left <= 0:
					_next()
				return
			"walkdown":
				if _left < 0:
					_left = c.ticks
				_left -= 1
				var mate: Variant = _nearest(downed, feet)
				var near: bool = mate == null
				if not near:
					var to: Vector2 = mate
					near = feet.distance_to(to) <= DOWN_NEAR_PX
					if not near and _left > 0:
						a.dir = Vector2i(_toward(to.x - feet.x), _toward(to.y - feet.y))
						return
				_next()
			"give":
				a.op = NetProtocol.InputFrame.new()
				a.op.op = NetProtocol.Op.GIVE
				a.op.item_index = ItemDB.index_of(c.item)
				a.op.count = c.count
				a.op.grade = maxi(c.grade, 0) if c.grade >= 0 else ItemDB.normalize_grade(c.item)
				_next()
				return


## The direction (-1/0/1) that brings an axis distance `d` toward 0, 0 when within ARRIVE_PX.
static func _toward(d: float) -> int:
	if absf(d) <= ARRIVE_PX:
		return 0
	return 1 if d > 0.0 else -1


func _fill_aim(a: Action, feet: Vector2) -> void:
	a.aiming = _aiming != Aiming.NONE
	match _aiming:
		Aiming.OFFSET:
			a.mouse = feet + _aim
		Aiming.CELL:
			a.mouse = _aim
		Aiming.FOE:
			var foe: Variant = nearest_foe(feet)
			a.aiming = foe != null
			if foe != null:
				var foe_feet: Vector2 = foe
				a.mouse = Combat.body_centre(foe_feet)  # M4-fix: the middle of the figure
			else:
				a.mouse = feet
		_:
			a.mouse = feet


## M5c: tile `c` of `data` is tilled soil (`stage` -1) or holds a crop at `stage` or later, not withered.
static func field_ready(data: WorldData, c: Vector2i, stage: int) -> bool:
	if data == null or not data.in_bounds(c) or not Farming.is_tilled(data, c):
		return false
	if stage < 0:
		return true
	var f: Farming.Field = Farming.field_at(data, c)
	return f != null and f.kind != Farming.KIND_NONE and not f.withered and f.stage >= stage


## M7c: whether the condition of a waitat / waitplaced / waitchest command holds now.
func _waited(c: Command) -> bool:
	match c.op:
		"waitat":
			for o: Vector2 in others:
				if Aim.feet_cell(o) == c.cell:
					return true
			return false
		"waitplaced":
			return world != null and world.get_value(WorldData.Layer.PLACEABLE, c.cell) == c.count
		"waitchest":
			if world == null or world.get_value(WorldData.Layer.PLACEABLE, c.cell) != WorldData.PLACEABLE_CHEST:
				return false
			var key: Vector2i = world.footprint_at(c.cell).position
			if not world.chests.has(key):
				return false
			for st: ItemStack in world.chests[key].slots:
				if st != null and st.id == c.item:
					return true
	return false


## M4b: the nearest live heretic's feet to `feet` (Vector2), or null when none is there.
func nearest_foe(feet: Vector2) -> Variant:
	return _nearest(foes, feet)


static func _nearest(points: Array[Vector2], feet: Vector2) -> Variant:
	var best: Variant = null
	var best_d: float = INF
	for f: Vector2 in points:
		var d: float = f.distance_to(feet)
		if d < best_d:
			best_d = d
			best = f
	return best


## Total ticks of wait/move commands (how long the script runs at least).
func duration_ticks() -> int:
	var n: int = 0
	for c: Command in commands:
		if c.op == "wait" or c.op == "move":
			n += c.ticks
	return n


func _next() -> void:
	index += 1
	_left = -1
	if index >= commands.size():
		finished = true

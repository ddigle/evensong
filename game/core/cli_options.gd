class_name CliOptions
extends RefCounted
## Parsed user arguments (the part after "--" on the Godot command line).
##
##   --smoke                      run the smoke checks (core/smoke.gd), print one line, exit 0 / 1
##   --host[=<port>]              host a session (default port Config.DEFAULT_PORT)
##   --join=<address>[:<port>]    join a session
##   --class=<name>               local player class: paladin | miner | archer | cleric | herbalist
##                                (default Config.DEFAULT_CLASS)
##   --seed=<n>                   world seed (default Config.DEFAULT_SEED)
##   --screenshot=<file.png>      save the root viewport after --frames frames, then quit
##   --frames=<n>                 frames to wait before the screenshot (default 10)
##   --scale=<n>                  window size = 480x270 x n (ignored with --headless)
##   --keep-running               after --screenshot, keep running instead of quitting (captures
##                                of two session windows: the first one must not leave early)
##   --overlay                    start with the debug overlay on (F3 toggles it)
##   --no-evening                 start with the evening darkness and the altar light off (F4 toggles)
##   --transport=<enet|steam>     session transport (default enet; steam is a placeholder in M1)
##   --bot=<script>               scripted input for the local player (net/net_bot.gd)
## Session test flags (tests/test_net_session.gd uses them; a human does not need them):
##   --max-players=<1..9>         host: lower the player cap (a refusal test needs fewer processes)
##   --net-out=<dir>              write <dir>/<net-name>.json and marker files; quit when the
##                                session ends (without it a client that loses the host plays on alone)
##   --net-name=<name>            instance name in logs and file names (default host / client)
##   --net-start=<n>              host: start every bot when n clients have joined (default 0 = at once)
##   --net-expect=<n>             host: finish the session when n clients have finished their bots or
##                                left (default -1 = never)
##   --net-expect-refused=<n>     host: ... and the host has refused n joins
##   --net-timeout=<sec>          quit with code 6 after this long (a stuck test cannot hang)
##   --net-lag=<ms>, --net-loss=<percent>   client: simulated round trip and loss (net/link_sim.gd)
##   --test-perturb-generator     this process generates different worlds from the same seed
##                                (SurfaceGen.test_perturb): a joiner must still get the host's world
##   --test-snapshot-chunk-bytes=<1..1024>  host: cut world snapshots into chunks this small
##                                (WorldSnapshot.chunk_bytes), so a small world streams over several ticks
## Items and actions (M2a):
##   --give=<id>[:<count>[:<grade>]],...   debug: put items into the local player's inventory at the
##                                start (ids in items/item_db.gd, grade common | fine for herbs; F5 gives
##                                the debug kit in the game). M2b: a session client asks the host for
##                                them (give requests), which the host honours only in a debug build or
##                                with --test-allow-give
##   --test-allow-give            host: honour clients' debug give requests in an exported (release)
##                                build too (session tests run the exported exe with it)
## Screenshot / test flags (M2a, offline):
##   --test-select=<1..hotbar>    select this hotbar slot at the start
##   --test-inventory             open the inventory grid (Tab) at the start
##   --test-aim=<dx>,<dy>         the local player aims at this offset from its feet (px) instead of
##                                the mouse, and always aims
##   --test-action=<action>[:<frame>]   the local player shows this body action frozen at a frame
##                                (frame 1-based, default the middle one)
##   --test-action-lineup[=<frame>]     instead of the dummies, the local class doing every body
##                                action (rows facing south and east) frozen at a frame (default middle)
## M3a (offline):
##   --start-map=<surface|dungeon>  start on that map (dungeon: at its arrival point)
##   --bot=<script>               offline too: the bot drives the local player instead of the keys
## M4a (offline screenshot / test flags):
##   --test-at=<x>,<y>            put the local player on tile x,y of the start map (feet low in the tile)
##   --test-heretic=<x>,<y>[/<x>,<y>...]   heretics on those tiles of the start map at the start
##   --test-down                  the local player starts downed (0 HP)
##   --test-ally=<class>[:down]   a second player (no input) beside the local one, downed with :down
##   --test-shrine-hp=<n>         the dungeon shrine starts with n hit points (with --start-map=dungeon)
## M4b (also in sessions: the host applies them to its arenas and members):
##   --test-heretic=...           a host puts them on the surface
##   --test-dungeon-heretic=<x>,<y>[/...]   heretics on those dungeon tiles at the start (offline, host)
##   --test-shrine-hp=<n>         a host's dungeon shrine starts with n hit points
##   --test-no-spawns             no heretic spawns (offline and host; the test heretics still come)
##   --test-start-hp=<class>:<hp>[,...]   host: members of that class start with that HP (tests: one hit
##                                downs them)
##
## Unknown flags are kept in `unknown` and ignored (the test runner passes its own flags such as
## --only= through the same command line). A bad value for a known flag is an error.

const DEFAULT_FRAMES: int = 10

var smoke: bool = false
var host: bool = false
var join: bool = false
var port: int = Config.DEFAULT_PORT
var join_address: String = ""
var class_id: String = ""
var world_seed: int = Config.DEFAULT_SEED
var screenshot: String = ""
var frames: int = DEFAULT_FRAMES
var scale: int = 0
var overlay: bool = false
var no_evening: bool = false
var keep_running: bool = false
var transport: String = Transports.DEFAULT_KIND
var bot: String = ""
var max_players: int = Config.MAX_PLAYERS
var net_out: String = ""
var net_name: String = ""
var net_start: int = 0
var net_expect: int = -1
var net_expect_refused: int = 0
var net_timeout: float = 0.0
var net_lag: int = 0
var net_loss: float = 0.0
var test_perturb_generator: bool = false
var test_snapshot_chunk_bytes: int = 0
var test_allow_give: bool = false
## --give: [item id (StringName), count, grade (ItemDB.Grade, -1 = default)] per entry.
var give: Array[Array] = []
var test_select: int = 0
var test_inventory: bool = false
var test_aim: Variant = null
## --test-action: [RigData action anim, frame (0-based, -1 = middle)], empty when not given.
var test_action: Array[int] = []
## --test-action-lineup: frame (0-based, -1 = middle), -2 when not given.
var test_action_lineup: int = -2
## --start-map (M3a): Config.MAP_SURFACE or MAP_DUNGEON.
var start_map: int = Config.MAP_SURFACE
## M4a test flags: tile (Vector2i or null), heretic tiles, start downed, an ally class (and downed),
## the shrine's starting HP (0 = Config.SHRINE_HP).
var test_at: Variant = null
var test_heretics: Array[Vector2i] = []
var test_down: bool = false
var test_ally: String = ""
var test_ally_down: bool = false
var test_shrine_hp: int = 0
## M4b test flags: dungeon heretic tiles, spawns off, start HP by class (host).
var test_dungeon_heretics: Array[Vector2i] = []
var test_no_spawns: bool = false
var test_start_hp: Dictionary[String, int] = {}
var errors: PackedStringArray = []
var unknown: PackedStringArray = []

static var _current: CliOptions


## This process's flags (parsed once). Use this instead of the Cli autoload's identifier so code
## also compiles where autoloads are not registered yet (--script entry points).
static func current() -> CliOptions:
	if _current == null:
		_current = parse(OS.get_cmdline_user_args())
	return _current


static func parse(argv: PackedStringArray) -> CliOptions:
	var o: CliOptions = CliOptions.new()
	for raw: String in argv:
		if not raw.begins_with("--"):
			o.unknown.append(raw)
			continue
		var body: String = raw.substr(2)
		var eq: int = body.find("=")
		var key: String = body if eq < 0 else body.substr(0, eq)
		var value: String = "" if eq < 0 else body.substr(eq + 1)
		var has_value: bool = eq >= 0
		match key:
			"smoke":
				o.smoke = true
			"overlay":
				o.overlay = true
			"no-evening":
				o.no_evening = true
			"keep-running":
				o.keep_running = true
			"test-perturb-generator":
				o.test_perturb_generator = true
			"test-allow-give":
				o.test_allow_give = true
			"test-snapshot-chunk-bytes":
				o.test_snapshot_chunk_bytes = _parse_positive(value, raw, o.errors, 0)
				if o.test_snapshot_chunk_bytes > Config.NET_SNAPSHOT_CHUNK_BYTES:
					o.errors.append("%s: at most %d" % [raw, Config.NET_SNAPSHOT_CHUNK_BYTES])
					o.test_snapshot_chunk_bytes = 0
			"host":
				o.host = true
				if has_value:
					o.port = _parse_port(value, raw, o.errors)
			"join":
				o.join = true
				_parse_join(value, raw, o)
			"class":
				if not Config.CLASSES.has(value):
					o.errors.append("%s: class must be one of %s" % [raw, ", ".join(Config.CLASSES)])
				else:
					o.class_id = value
			"seed":
				if not value.is_valid_int():
					o.errors.append("%s: seed must be an integer" % raw)
				else:
					o.world_seed = value.to_int()
			"screenshot":
				if not value.to_lower().ends_with(".png"):
					o.errors.append("%s: screenshot must be a .png path" % raw)
				else:
					o.screenshot = value
			"frames":
				o.frames = _parse_positive(value, raw, o.errors, DEFAULT_FRAMES)
			"scale":
				o.scale = _parse_positive(value, raw, o.errors, 0)
			"transport":
				if not Transports.KINDS.has(value):
					o.errors.append("%s: transport must be one of %s" % [raw, ", ".join(Transports.KINDS)])
				else:
					o.transport = value
			"start-map":
				if value == "surface":
					o.start_map = Config.MAP_SURFACE
				elif value == "dungeon":
					o.start_map = Config.MAP_DUNGEON
				else:
					o.errors.append("%s: map must be surface or dungeon" % raw)
			"bot":
				var bot_error: String = "empty script" if value.strip_edges().is_empty() else NetBot.new().parse(value)
				if not bot_error.is_empty():
					o.errors.append("%s: %s" % [raw, bot_error])
				else:
					o.bot = value
			"max-players":
				o.max_players = _parse_positive(value, raw, o.errors, Config.MAX_PLAYERS)
				if o.max_players > Config.MAX_PLAYERS:
					o.errors.append("%s: at most %d players (● game-concept §7)" % [raw, Config.MAX_PLAYERS])
					o.max_players = Config.MAX_PLAYERS
			"net-out":
				if value.is_empty():
					o.errors.append("%s: expected a folder" % raw)
				else:
					o.net_out = value
			"net-name":
				if value.is_empty() or not value.is_valid_filename():
					o.errors.append("%s: expected a name usable as a file name" % raw)
				else:
					o.net_name = value
			"net-start":
				o.net_start = _parse_count(value, raw, o.errors, 0)
			"net-expect":
				o.net_expect = _parse_count(value, raw, o.errors, -1)
			"net-expect-refused":
				o.net_expect_refused = _parse_count(value, raw, o.errors, 0)
			"net-timeout":
				if not value.is_valid_float() or value.to_float() <= 0.0:
					o.errors.append("%s: expected seconds > 0" % raw)
				else:
					o.net_timeout = value.to_float()
			"net-lag":
				o.net_lag = _parse_count(value, raw, o.errors, 0)
			"net-loss":
				if not value.is_valid_float() or value.to_float() < 0.0 or value.to_float() > 100.0:
					o.errors.append("%s: expected a percentage 0..100" % raw)
				else:
					o.net_loss = value.to_float()
			"give":
				_parse_give(value, raw, o)
			"test-select":
				o.test_select = _parse_positive(value, raw, o.errors, 0)
				if o.test_select > Config.HOTBAR_SLOTS:
					o.errors.append("%s: the hotbar has %d slots" % [raw, Config.HOTBAR_SLOTS])
					o.test_select = 0
			"test-inventory":
				o.test_inventory = true
			"test-aim":
				var parts: PackedStringArray = value.split(",")
				if parts.size() != 2 or not parts[0].is_valid_float() or not parts[1].is_valid_float():
					o.errors.append("%s: expected --test-aim=<dx>,<dy>" % raw)
				else:
					o.test_aim = Vector2(parts[0].to_float(), parts[1].to_float())
			"test-action":
				var action_parts: PackedStringArray = value.split(":")
				var anim: int = RigData.ANIM_NAMES.find(action_parts[0])
				var action_frame: int = _parse_frame(action_parts[1] if action_parts.size() > 1 else "", anim, raw, o.errors)
				if not RigData.is_action(anim) or action_parts.size() > 2:
					o.errors.append("%s: expected --test-action=<%s>[:<frame>]" % [raw, "|".join(_action_names())])
				elif action_frame >= -1:
					o.test_action = [anim, action_frame]
			"test-action-lineup":
				o.test_action_lineup = _parse_frame(value, RigData.Anim.PICKAXE, raw, o.errors) if has_value else -1
			"test-at":
				var at: Array[Vector2i] = _parse_tiles(value, raw, o.errors)
				if at.size() == 1:
					o.test_at = at[0]
				elif not at.is_empty():
					o.errors.append("%s: expected --test-at=<x>,<y>" % raw)
			"test-heretic":
				o.test_heretics = _parse_tiles(value, raw, o.errors)
			"test-down":
				o.test_down = true
			"test-ally":
				var ally: PackedStringArray = value.split(":")
				if not Config.CLASSES.has(ally[0]) or ally.size() > 2 or (ally.size() == 2 and ally[1] != "down"):
					o.errors.append("%s: expected --test-ally=<%s>[:down]" % [raw, "|".join(Config.CLASSES)])
				else:
					o.test_ally = ally[0]
					o.test_ally_down = ally.size() == 2
			"test-shrine-hp":
				o.test_shrine_hp = _parse_positive(value, raw, o.errors, 0)
			"test-dungeon-heretic":
				o.test_dungeon_heretics = _parse_tiles(value, raw, o.errors)
			"test-no-spawns":
				o.test_no_spawns = true
			"test-start-hp":
				for part: String in value.split(",", false):
					var kv: PackedStringArray = part.split(":")
					if kv.size() != 2 or not Config.CLASSES.has(kv[0]) or not kv[1].is_valid_int() or kv[1].to_int() < 1 \
							or kv[1].to_int() > Config.PLAYER_HP_MAX:
						o.errors.append("%s: expected --test-start-hp=<class>:<1..%d>[,...]" % [raw, Config.PLAYER_HP_MAX])
						break
					o.test_start_hp[kv[0]] = kv[1].to_int()
			_:
				o.unknown.append(raw)
	if o.host and o.join:
		o.errors.append("--host and --join cannot be used together")
	return o


## "<x>,<y>[/<x>,<y>...]" -> tiles (whole numbers >= 0); an error and none if bad.
static func _parse_tiles(value: String, raw: String, errors: PackedStringArray) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for part: String in value.split("/"):
		var xy: PackedStringArray = part.split(",")
		if xy.size() != 2 or not xy[0].is_valid_int() or not xy[1].is_valid_int() or xy[0].to_int() < 0 or xy[1].to_int() < 0:
			errors.append("%s: expected tiles <x>,<y>[/<x>,<y>...]" % raw)
			return [] as Array[Vector2i]
		out.append(Vector2i(xy[0].to_int(), xy[1].to_int()))
	return out


## Whole number >= 0.
static func _parse_count(value: String, raw: String, errors: PackedStringArray, fallback: int) -> int:
	if not value.is_valid_int() or value.to_int() < 0:
		errors.append("%s: expected a whole number >= 0" % raw)
		return fallback
	return value.to_int()


static func _parse_positive(value: String, raw: String, errors: PackedStringArray, fallback: int) -> int:
	if not value.is_valid_int() or value.to_int() < 1:
		errors.append("%s: expected a whole number >= 1" % raw)
		return fallback
	return value.to_int()


static func _parse_port(value: String, raw: String, errors: PackedStringArray) -> int:
	if not value.is_valid_int() or value.to_int() < 1 or value.to_int() > 65535:
		errors.append("%s: port must be 1..65535" % raw)
		return Config.DEFAULT_PORT
	return value.to_int()


## "<id>[:<count>[:<grade>]],..." -> o.give.
static func _parse_give(value: String, raw: String, o: CliOptions) -> void:
	if value.is_empty():
		o.errors.append("%s: expected --give=<id>[:<count>[:<grade>]],..." % raw)
		return
	for entry: String in value.split(","):
		var parts: PackedStringArray = entry.split(":")
		var id: StringName = StringName(parts[0])
		if not ItemDB.has(id):
			var names: PackedStringArray = []
			for known: StringName in ItemDB.ids():
				names.append(String(known))
			o.errors.append("%s: unknown item '%s' (items: %s)" % [raw, parts[0], ", ".join(names)])
			return
		var count: int = 1
		if parts.size() > 1:
			if not parts[1].is_valid_int() or parts[1].to_int() < 1:
				o.errors.append("%s: count of %s must be a whole number >= 1" % [raw, parts[0]])
				return
			count = parts[1].to_int()
		var grade: int = -1
		if parts.size() > 2:
			grade = ItemDB.grade_from_name(parts[2])
			var def: ItemDB.ItemDef = ItemDB.get_def(id)
			if grade < ItemDB.Grade.COMMON or not def.graded or parts.size() > 3:
				o.errors.append("%s: %s takes %s" % [raw, parts[0], "a grade common | fine" if def.graded else "no grade"])
				return
		o.give.append([id, count, grade])


## A 1-based frame number of `anim` ("" = the middle one, -1) -> 0-based; -2 and an error if bad.
static func _parse_frame(value: String, anim: int, raw: String, errors: PackedStringArray) -> int:
	if value.is_empty():
		return -1
	var n: int = RigData.frame_count(anim) if RigData.is_action(anim) else 8
	if not value.is_valid_int() or value.to_int() < 1 or value.to_int() > n:
		errors.append("%s: frame must be 1..%d" % [raw, n])
		return -2
	return value.to_int() - 1


static func _action_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for anim: int in RigData.ACTION_ANIMS:
		out.append(RigData.ANIM_NAMES[anim])
	return out


## "<address>", "<address>:<port>", "[<ipv6>]" or "[<ipv6>]:<port>".
static func _parse_join(value: String, raw: String, o: CliOptions) -> void:
	if value.is_empty():
		o.errors.append("%s: expected --join=<address>[:<port>]" % raw)
		return
	var address: String = value
	var port_text: String = ""
	if value.begins_with("["):
		var close: int = value.find("]")
		if close < 0:
			o.errors.append("%s: missing ] in IPv6 address" % raw)
			return
		address = value.substr(1, close - 1)
		var rest: String = value.substr(close + 1)
		if not rest.is_empty():
			if not rest.begins_with(":"):
				o.errors.append("%s: expected :<port> after ]" % raw)
				return
			port_text = rest.substr(1)
	elif value.count(":") == 1:
		address = value.get_slice(":", 0)
		port_text = value.get_slice(":", 1)
	if address.is_empty():
		o.errors.append("%s: empty address" % raw)
		return
	o.join_address = address
	if not port_text.is_empty():
		o.port = _parse_port(port_text, raw, o.errors)

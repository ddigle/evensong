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
			_:
				o.unknown.append(raw)
	if o.host and o.join:
		o.errors.append("--host and --join cannot be used together")
	return o


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

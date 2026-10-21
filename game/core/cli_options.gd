class_name CliOptions
extends RefCounted
## Parsed user arguments (the part after "--" on the Godot command line).
##
##   --smoke                      run the smoke checks (core/smoke.gd), print one line, exit 0 / 1
##   --host[=<port>]              host a session (stage G3)
##   --join=<address>[:<port>]    join a session (stage G3)
##   --class=<name>               paladin | miner | archer | cleric | herbalist (stage G2)
##   --seed=<n>                   world seed (default Config.DEFAULT_SEED)
##   --screenshot=<file.png>      save the root viewport after --frames frames, then quit
##   --frames=<n>                 frames to wait before the screenshot (default 10)
##   --scale=<n>                  window size = 480x270 x n (ignored with --headless)
##   --overlay                    start with the debug overlay on (F3 toggles it)
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
			_:
				o.unknown.append(raw)
	if o.host and o.join:
		o.errors.append("--host and --join cannot be used together")
	return o


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

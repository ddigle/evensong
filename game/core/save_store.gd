class_name SaveStore
extends RefCounted
## M13a (● game-concept §12 R54 "저장"): the files of the saved worlds and characters on this device, under one root folder:
##   <root>/worlds/<name>.evw         a world (core/world_save.gd), the host's (offline = hosting alone)
##   <root>/characters/<name>.json    a character (core/character_save.gd), each player's own, several per device
## next to each: <file>.bak (the save before the last one) and, only while a save is being written or after a crash in the middle
## of one, <file>.tmp.
##
## The root has no default here (a test cannot fall through to the human's folder): Main gives `--save-dir=<dir>` or
## Config.SAVE_DIR_DEFAULT ("user://saves": with the project's custom user dir, %APPDATA%\Evensong\saves on Windows, README "M13a").
##
## Names (IMPL): what the human types after --world= / --character=, lowercased; 1..Config.SAVE_NAME_MAX of a-z 0-9 _ -, starting with a
## letter or digit, never a Windows device name (con, nul, com1 ...): a name is the file's name, so it can hold no folder, no dot and no
## character a file system treats differently. Case-insensitive because Windows' file names are.
##
## Writing (write_atomic): the whole file goes to <file>.tmp first (written, closed, read back and compared byte for byte); then the
## file there becomes <file>.bak (the old backup removed first) and <file>.tmp becomes <file>. Every moment between leaves a file that
## loads: before the rename the old file is whole; between the two renames <file> is missing and <file>.tmp is whole (the loaders try
## <file>, then <file>.tmp, then <file>.bak: candidates()). A file that did not load (Main loaded the backup) is not rotated into the
## backup (`rotate` false): the good backup stays until a good file replaces the broken one.

const WORLDS_DIR: String = "worlds"
const CHARACTERS_DIR: String = "characters"
const WORLD_EXT: String = ".evw"
const CHARACTER_EXT: String = ".json"
const TMP_EXT: String = ".tmp"
const BAK_EXT: String = ".bak"
## M13 review: a cut-off first write set aside (set_aside: <file>.tmp.broken).
const BROKEN_EXT: String = ".broken"
## Windows device names (with or without an extension they name a device, not a file).
const RESERVED: PackedStringArray = ["con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8",
	"com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9"]
const NAME_CHARS: String = "abcdefghijklmnopqrstuvwxyz0123456789_-"

## The root folder (a user:// or absolute path).
var root: String = ""


func _init(p_root: String) -> void:
	root = p_root


## Why `raw` cannot be a save name ("" = it can, as normalize_name gives it).
static func name_refusal(raw: String) -> String:
	var n: String = raw.to_lower()
	if n.is_empty():
		return "empty name"
	if n.length() > Config.SAVE_NAME_MAX:
		return "longer than %d characters" % Config.SAVE_NAME_MAX
	for ch: String in n:
		if not NAME_CHARS.contains(ch):
			return "only a-z, 0-9, _ and - (got '%s')" % ch
	if n.begins_with("_") or n.begins_with("-"):
		return "must start with a letter or a digit"
	if RESERVED.has(n):
		return "'%s' is a Windows device name" % n
	return ""


## `raw` as the store names it (lowercase), or "" when it cannot be a name (name_refusal).
static func normalize_name(raw: String) -> String:
	return raw.to_lower() if name_refusal(raw).is_empty() else ""


func worlds_dir() -> String:
	return root.path_join(WORLDS_DIR)


func characters_dir() -> String:
	return root.path_join(CHARACTERS_DIR)


func world_path(name: String) -> String:
	return worlds_dir().path_join(normalize_name(name) + WORLD_EXT)


func character_path(name: String) -> String:
	return characters_dir().path_join(normalize_name(name) + CHARACTER_EXT)


## The files a load tries for `path`, in order, those that exist: the file, the one being written when a save was cut off between
## its renames, the backup.
static func candidates(path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for p: String in [path, path + TMP_EXT, path + BAK_EXT]:
		if FileAccess.file_exists(p):
			out.append(p)
	return out


## Whether anything of `path` exists (the file, its .tmp or its .bak): the name is taken.
static func exists(path: String) -> bool:
	return not candidates(path).is_empty()


## M13 review: what a crash in the very first write of a name leaves: only <file>.tmp (no file, no backup: nothing was ever saved under it).
static func lone_tmp(path: String) -> bool:
	return FileAccess.file_exists(path + TMP_EXT) and not FileAccess.file_exists(path) and not FileAccess.file_exists(path + BAK_EXT)


## M13 review: moves file `path` aside as <path>.broken (an older one there replaced), out of candidates() and names_in(). Returns where it
## went ("" = it could not be moved).
static func set_aside(path: String) -> String:
	var to: String = path + BROKEN_EXT
	if FileAccess.file_exists(to) and DirAccess.remove_absolute(to) != OK:
		return ""
	return to if DirAccess.rename_absolute(path, to) == OK else ""


## The names of the saved files in `dir` with extension `ext` (a file, or only its .tmp / .bak left), sorted.
static func names_in(dir: String, ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for file: String in DirAccess.get_files_at(dir):
		var base: String = file
		for suffix: String in [TMP_EXT, BAK_EXT]:
			if base.ends_with(suffix):
				base = base.trim_suffix(suffix)
		if not base.ends_with(ext):
			continue
		var name: String = base.trim_suffix(ext)
		if normalize_name(name) == name and not out.has(name):
			out.append(name)
	out.sort()
	return out


func world_names() -> PackedStringArray:
	return names_in(worlds_dir(), WORLD_EXT)


func character_names() -> PackedStringArray:
	return names_in(characters_dir(), CHARACTER_EXT)


## The bytes of file `path`, or an empty array (missing, unreadable, or larger than `limit` bytes: refused before reading).
static func read_bytes(path: String, limit: int) -> PackedByteArray:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var n: int = f.get_length()
	if n <= 0 or n > limit:
		f.close()
		return PackedByteArray()
	var out: PackedByteArray = f.get_buffer(n)
	f.close()
	return out


## Writes `bytes` to `path` the safe way (the class comment). `rotate`: the file there becomes the backup (false: it is replaced and
## the backup stays). Returns "" or why it failed (then the files there are as they were, but for a stray .tmp).
static func write_atomic(path: String, bytes: PackedByteArray, rotate: bool = true) -> String:
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var made: Error = DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return "cannot make folder %s (error %d)" % [dir, made]
	var tmp: String = path + TMP_EXT
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()]
	f.store_buffer(bytes)
	f.flush()
	var write_error: Error = f.get_error()
	f.close()
	if write_error != OK:
		return "writing %s failed (error %d)" % [tmp, write_error]
	var back: PackedByteArray = read_bytes(tmp, bytes.size() + 1)
	if back != bytes:
		return "%s reads back differently (%d of %d bytes)" % [tmp, back.size(), bytes.size()]
	var bak: String = path + BAK_EXT
	if FileAccess.file_exists(path):
		if rotate:
			if FileAccess.file_exists(bak):
				var gone: Error = DirAccess.remove_absolute(bak)
				if gone != OK:
					return "cannot remove the old backup %s (error %d)" % [bak, gone]
			var moved: Error = DirAccess.rename_absolute(path, bak)
			if moved != OK:
				return "cannot keep %s as the backup (error %d)" % [path, moved]
		else:
			var removed: Error = DirAccess.remove_absolute(path)
			if removed != OK:
				return "cannot replace %s (error %d)" % [path, removed]
	var done: Error = DirAccess.rename_absolute(tmp, path)
	if done != OK:
		return "cannot rename %s to %s (error %d)" % [tmp, path, done]
	return ""


## The folder as the human finds it (user:// made absolute).
func shown_root() -> String:
	return ProjectSettings.globalize_path(root)

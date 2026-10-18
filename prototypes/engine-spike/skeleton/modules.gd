extends RefCounted
## Spike module discovery (static helpers, no state).
##
## A module is a top-level folder res://<module>/ whose entry scene is
## res://<module>/<module>.tscn. Reserved folders below are never modules.

const RESERVED_DIRS: PackedStringArray = ["addons", "art", "build", "notes", "skeleton", "tests"]


## Module names that have an entry scene, sorted.
static func list_modules() -> PackedStringArray:
	var out: PackedStringArray = []
	for dir_name: String in DirAccess.get_directories_at("res://"):
		if dir_name.begins_with(".") or dir_name in RESERVED_DIRS:
			continue
		if ResourceLoader.exists(scene_path(dir_name)):
			out.append(dir_name)
	out.sort()
	return out


static func scene_path(module: String) -> String:
	return "res://%s/%s.tscn" % [module, module]


## "lights" -> res://lights/lights.tscn; a res:// path is returned unchanged.
static func resolve_scene(arg: String) -> String:
	if arg.begins_with("res://"):
		return arg
	return scene_path(arg)

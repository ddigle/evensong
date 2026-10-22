extends SceneTree
## Builds res://world/tilesets/surface.tres and (M3a) res://world/tilesets/dungeon.tres from our
## PNG + JSON (world/tileset_builder.gd).
##
##   godot --headless --path game --import
##   godot --headless --path game --script res://tools/build_tileset.gd
##
## Prints "EVENSONG_TILESET <path> error=<n> sources=<n> tiles=<n> exact_keys=<n> md5=<hash>" per file
## and exits 0 when both were saved. The output only depends on the inputs, so running it again
## writes the same file (tests/test_world.gd checks the committed file against a fresh build).


func _initialize() -> void:
	var ok: bool = _save(TilesetBuilder.SURFACE_PATH, TilesetBuilder.build_surface())
	ok = _save(TilesetBuilder.DUNGEON_PATH, TilesetBuilder.build_dungeon()) and ok
	quit(0 if ok else 1)


func _save(path: String, ts: TileSet) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: Error = ResourceSaver.save(ts, path) if ts != null else ERR_CANT_CREATE
	var table: WangTable = WangTable.from_tile_set(ts) if ts != null and path == TilesetBuilder.SURFACE_PATH else null
	var exact: int = table.exact_keys if table != null else (CaveTable.from_tile_set(ts).exact_keys if ts != null else 0)
	print("EVENSONG_TILESET %s error=%d sources=%d tiles=%d exact_keys=%d md5=%s" % [
		path, err, ts.get_source_count() if ts != null else 0, TilesetBuilder.count_tiles(ts) if ts != null else 0,
		exact, FileAccess.get_md5(path)])
	return err == OK

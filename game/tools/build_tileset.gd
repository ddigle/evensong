extends SceneTree
## Builds res://world/tilesets/surface.tres from our PNG + JSON (world/tileset_builder.gd).
##
##   godot --headless --path game --import
##   godot --headless --path game --script res://tools/build_tileset.gd
##
## Prints "EVENSONG_TILESET <path> error=<n> sources=<n> tiles=<n> exact_keys=<n> md5=<hash>" and
## exits 0 when the file was saved. The output only depends on the inputs, so running it again
## writes the same file (tests/test_world.gd checks the committed file against a fresh build).


func _initialize() -> void:
	var path: String = TilesetBuilder.SURFACE_PATH
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var ts: TileSet = TilesetBuilder.build_surface()
	var err: Error = ResourceSaver.save(ts, path) if ts != null else ERR_CANT_CREATE
	var table: WangTable = WangTable.from_tile_set(ts) if ts != null else null
	print("EVENSONG_TILESET %s error=%d sources=%d tiles=%d exact_keys=%d md5=%s" % [
		path, err, ts.get_source_count() if ts != null else 0, TilesetBuilder.count_tiles(ts) if ts != null else 0,
		table.exact_keys if table != null else 0, FileAccess.get_md5(path)])
	quit(0 if err == OK else 1)

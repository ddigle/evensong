class_name GameWorld
extends Node2D
## Root of scenes/world.tscn: the surface world of one seed and what stands on it.
##   Ground        GroundView (chunked dual grid floor)
##   Entities      y-sorted by feet: the Altar (created by generate()), the gatherables and drops
##                 (ItemView, M2b) and the characters that scenes add (main.tscn adds the players)
##   Lighting      evening darkness + the altar light (F4 toggles, --no-evening starts off)
##   DebugOverlay  F3
##   FreeCamera    map viewer camera; removed when `free_camera` is off (main.tscn uses PlayerCamera)
##
## is_in_safe_zone() is the one safe-zone rule (light/safe_zone.gd); the altar light textures are
## built from the same SafeZone.
##
## M3a, maps: one GameWorld per map (`map_id`, Config.MAP_SURFACE / MAP_DUNGEON). main.tscn's World is
## the surface; offline, Main adds a second instance of world.tscn for the dungeon and shows one at a
## time (a hidden world's darkness and lights do not apply). A dungeon world generates with
## DungeonGen, draws its walls with a CaveView (Cave, in place of Ground, which stays empty), is dark
## (Config.DUNGEON_DARK_COLOR) and has no altar. Both draw their other placeables with a FixtureView
## (entrance, exit stairs, shrine, torches; ground decals in Decals, between the ground and the
## entities) and their gatherables and drops with an ItemView.
## M5a: the fields (watered soil right above the ground, crops among the entities) with a FieldView (Fields).
## M5b: purification's effects with a PurifyView (Purify, above the decals); the altar follows its footprint in the
## world: an edit that picks it up or puts it down (WorldData.refresh_altar_rect) moves the safe zone, the altar's node and
## its light here (_altar_moved) and says so (altar_moved).

signal generated
## M5b: the altar was picked up or put down (its footprint changed through world edits).
signal altar_moved

## Generate in _ready from the --seed flag (Config.DEFAULT_SEED without it). Tests turn this off
## and call generate() themselves.
@export var auto_generate: bool = true
## Keep the free camera (world.tscn on its own). main.tscn turns it off.
@export var free_camera: bool = true
## M3a: which map this world shows and generates (Config.MAP_SURFACE or MAP_DUNGEON).
@export var map_id: int = Config.MAP_SURFACE

var data: WorldData
var safe_zone: SafeZone
var altar: Altar
## M5-fix: the footprint the altar last stood on (it stays while the altar is carried; empty when this world never had
## one, e.g. a joiner's world received while it was carried). The set-downs' last fallback (AltarMove.set_down_fallback)
## and where a client playing on after losing the host puts it back (Main.restore_altar).
var last_altar_rect: Rect2i = Rect2i()
## Gatherables and drops (M2b, world/item_view.gd).
var items: ItemView
## M3a: the dungeon's walls (null on the surface), the placeables other than the altar, ground decals.
var cave: CaveView
var fixtures: FixtureView
var decals: Node2D
## M5a: the fields (watered soil over the ground, crops among the entities; world/field_view.gd).
var fields: FieldView
## M5b: purification's effects (world/purify_view.gd), above the decals, below the entities.
var purify_view: PurifyView
var generation_ms: float = 0.0
var view_ms: float = 0.0

@onready var ground: GroundView = $Ground
@onready var entities: Node2D = $Entities
@onready var lighting: Lighting = $Lighting
@onready var overlay: DebugOverlay = $DebugOverlay
@onready var camera: FreeCamera = $FreeCamera


func _ready() -> void:
	if not free_camera:
		remove_child(camera)
		camera.free()
		camera = null
	if auto_generate:
		generate(CliOptions.current().world_seed)
		overlay.visible = CliOptions.current().overlay
		lighting.set_evening(not CliOptions.current().no_evening)


## Generates this world's map from `world_seed` (`size` = the surface's; the dungeon has its own,
## Config.DUNGEON_SIZE).
func generate(world_seed: int, size: Vector2i = Config.MAP_SIZE) -> void:
	var t0: int = Time.get_ticks_usec()
	var generated_data: WorldData = DungeonGen.generate(world_seed) if map_id == Config.MAP_DUNGEON \
		else SurfaceGen.generate(world_seed, size)
	generation_ms = (Time.get_ticks_usec() - t0) / 1000.0
	load_data(generated_data)


## Shows `p_data` (generated here, or a late joiner's world received from the host): draws the
## ground, places the altar and its light, resets the free camera and the overlay.
func load_data(p_data: WorldData) -> void:
	data = p_data
	map_id = data.map_id
	var t1: int = Time.get_ticks_usec()
	if map_id == Config.MAP_DUNGEON:
		if cave == null:
			cave = CaveView.new()
			cave.name = &"Cave"
			add_child(cave)
			move_child(cave, ground.get_index() + 1)
		cave.setup(data)
		lighting.set_dark_color(Config.DUNGEON_DARK_COLOR)
	else:
		ground.setup(data)
	view_ms = (Time.get_ticks_usec() - t1) / 1000.0
	safe_zone = SafeZone.for_world(data)
	last_altar_rect = data.altar_rect  # M5-fix (empty when it is carried in the world received)
	_place_altar()
	if items == null:
		items = ItemView.new(entities)
	items.setup(data)
	if decals == null:
		decals = Node2D.new()
		decals.name = &"Decals"
		add_child(decals)
		move_child(decals, entities.get_index())
	if fields == null:
		fields = FieldView.new()
		fields.name = &"Fields"
		add_child(fields)
		move_child(fields, decals.get_index())  # right above the ground, below the decals and the entities
	fields.setup(data, ground, entities)
	if purify_view == null:
		purify_view = PurifyView.new()
		add_child(purify_view)
		move_child(purify_view, entities.get_index())  # above the decals, below the entities
	purify_view.clear()
	if fixtures == null:
		fixtures = FixtureView.new()
		fixtures.name = &"Fixtures"
		add_child(fixtures)
	fixtures.setup(data, entities, decals, lighting.torches)
	lighting.setup(safe_zone, lighting.evening_on)
	if camera != null:
		camera.bounds = map_rect_px()
		camera.position = camera.clamp_to_bounds(data.altar_center_px())
		camera.reset_smoothing()
	overlay.setup(data)
	generated.emit()


func _place_altar() -> void:
	if altar != null:
		entities.remove_child(altar)
		altar.free()
		altar = null
	if not data.altar_rect.has_area():
		return
	altar = Altar.new()
	altar.name = &"Altar"
	altar.setup(data.altar_rect)
	entities.add_child(altar)
	entities.move_child(altar, 0)


## M5b: the altar left its place or came down on a new one (WorldData.altar_rect changed through edits): the safe zone,
## the altar's node and its light (on as the evening is), the debug lines follow; `altar_moved` tells the rest (Main:
## the arena, the dummies).
func _altar_moved() -> void:
	safe_zone = SafeZone.for_world(data)
	_place_altar()
	lighting.altar_light.setup(safe_zone)
	lighting.altar_light.set_lit(lighting.evening_on)
	overlay.queue_redraw()
	altar_moved.emit()


## THE safe-zone rule for game logic (the light shows the same zone).
func is_in_safe_zone(pos: Vector2) -> bool:
	return safe_zone != null and safe_zone.is_in_safe_zone(pos)


## M3a: where a player arrives on this map from the other one (feet, px): south of the dungeon's exit
## stairs, or south of the surface's entrance.
func arrival_point() -> Vector2:
	if map_id == Config.MAP_DUNGEON:
		return DungeonGen.arrival_point(data)
	return DungeonGen.arrival_below(SurfaceGen.entrance_rect(data))


## Feet position of spawn slot i (Config.SPAWN_SLOTS, around the altar).
func spawn_point(slot: int) -> Vector2:
	return data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[slot % Config.SPAWN_SLOTS.size()])


## Sets the floor terrain at vertex v; returns the redrawn display cells (see GroundView).
func set_terrain(v: Vector2i, terrain: int) -> Array[Vector2i]:
	return ground.set_terrain(v, terrain)


## Applies a world edit the host has checked (net/edit_log.gd) and redraws what it touches. The host
## and every client apply edits through here, so the same log gives the same world. False when the
## edit does not fit the data.
func apply_edit(edit: EditLog.WorldEdit) -> bool:
	var altar_before: Rect2i = data.altar_rect
	if not EditLog.apply_to_data(data, edit):
		return false
	if data.altar_rect != altar_before:
		# M5-fix: where it stood (picked up: the place it left; put down: the new one).
		last_altar_rect = data.altar_rect if data.altar_rect.has_area() else altar_before
		_altar_moved()  # M5b: picked up (no altar now) or put down (a whole footprint again)
	match edit.kind:
		EditLog.Kind.DROP_PUT, EditLog.Kind.DROP_REMOVE:
			items.update_drop(edit.drop_id)
		_:
			if edit.layer == WorldData.Layer.FLOOR:
				if cave == null:
					ground.redraw_vertex(edit.cell)
					fields.update_floor(edit.cell)  # M5a: wet tiles take their quadrants from the redrawn cells
			elif edit.layer == WorldData.Layer.VEGETATION:
				items.update_cell(edit.cell)
				fields.update_cell(edit.cell)  # M5a: crops and wet soil
			elif edit.layer == WorldData.Layer.WALL or edit.layer == WorldData.Layer.ORE:
				if cave != null:
					cave.redraw_wall(edit.cell)
			elif edit.layer == WorldData.Layer.PLACEABLE:
				fixtures.update_cell(edit.cell)
				items.update_bag_cell(edit.cell)
	return true


## M3b: md5 of what this map draws (the surface's ground, the dungeon's cave walls and overlays).
func view_hash() -> String:
	return cave.view_hash() if cave != null and map_id == Config.MAP_DUNGEON else ground.view_hash()


## M3b: this map's drawing against its data (GroundView.verify / CaveView.verify).
func view_check() -> Dictionary[String, int]:
	return cave.verify() if cave != null and map_id == Config.MAP_DUNGEON else ground.verify()


func map_rect_px() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(data.size * Config.TILE))

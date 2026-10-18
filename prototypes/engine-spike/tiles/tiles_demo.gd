extends Node2D
## Tiles demo (res://tiles/tiles_demo.tscn, also the module entry res://tiles/tiles.tscn).
## Built at runtime from the generated TileSets: left a field (grass, tilled soil, single hoed
## cells) with a corruption edge, right a dungeon room (wall top / front face / floor, ore, a
## pillar, an alcove, a dug tunnel). A few edits run in _ready so a screenshot shows updated tiles.
##
## Keys: M switch method (b dual grid <-> a Godot terrains), C show the wall collision layer.
## Mouse: field LMB soil / RMB ash (again = grass); dungeon LMB break wall / RMB build wall.
## Command line (after --): --tiles-method=a|b
##   godot --path prototypes/engine-spike -- --scene=tiles --tiles-method=a --screenshot=build/shots/tiles_a.png

const Wang := preload("res://tiles/wang.gd")
const Maps := preload("res://tiles/maps.gd")
const Builder := preload("res://tiles/build_tilesets.gd")
const SurfaceMapScript := preload("res://tiles/surface_map.gd")
const DungeonMapScript := preload("res://tiles/dungeon_map.gd")

const FIELD_SIZE: Vector2i = Vector2i(14, 17)
const DUNGEON_SIZE: Vector2i = Vector2i(14, 17)
const DUNGEON_ORIGIN: Vector2 = Vector2(248, 0)

var method: String = "b"
var surface: Node2D
var dungeon: Node2D
var label: Label
var build_ms: float = 0.0


func _ready() -> void:
	for raw: String in OS.get_cmdline_user_args():
		if raw.begins_with("--tiles-method="):
			method = raw.get_slice("=", 1)
	if method != "a":
		method = "b"
	seed(20261018)  # Godot terrains pick variants with the global RNG
	_build()


func _build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var t0: int = Time.get_ticks_usec()
	surface = SurfaceMapScript.new()
	surface.name = "Field"
	add_child(surface)
	surface.call("setup", method, FIELD_SIZE.x, FIELD_SIZE.y, Maps.demo_surface(FIELD_SIZE.x, FIELD_SIZE.y))
	dungeon = DungeonMapScript.new()
	dungeon.name = "Dungeon"
	dungeon.position = DUNGEON_ORIGIN
	add_child(dungeon)
	var ores: Dictionary = {
		Vector2i(4, 2): Builder.OVERLAY_COPPER, Vector2i(9, 1): Builder.OVERLAY_IRON,
		Vector2i(12, 8): Builder.OVERLAY_COPPER, Vector2i(1, 13): Builder.OVERLAY_IRON,
	}
	dungeon.call("setup", method, DUNGEON_SIZE.x, DUNGEON_SIZE.y, Maps.demo_dungeon(DUNGEON_SIZE.x, DUNGEON_SIZE.y), ores)
	# Scripted edits: hoe two cells, dig a short tunnel east, mine the copper ore on the east wall.
	surface.call("set_terrain", 9, 4, Wang.SOIL)
	surface.call("set_terrain", 9, 6, Wang.SOIL)
	for x: int in [11, 12]:
		dungeon.call("break_wall", x, 10)
	dungeon.call("break_wall", 12, 8)
	build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	_add_label()


func _add_label() -> void:
	var strip: ColorRect = ColorRect.new()
	strip.color = Color(0.05, 0.04, 0.04, 0.75)
	strip.position = Vector2(0, 258)
	strip.size = Vector2(480, 12)
	strip.z_index = 10
	add_child(strip)
	label = Label.new()
	label.position = Vector2(3, 257)
	label.z_index = 11
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
	label.text = "%s  built %.1f ms   M method  C collision  LMB/RMB edit  F10 menu" % [
		"(b) dual grid" if method == "b" else "(a) Godot terrains", build_ms]
	add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_M:
			method = "a" if method == "b" else "b"
			_build()
		elif key.keycode == KEY_C:
			var layer: TileMapLayer = dungeon.get("collision_layer")
			layer.visible = not layer.visible
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse == null or not mouse.pressed:
		return
	var left: bool = mouse.button_index == MOUSE_BUTTON_LEFT
	if not left and mouse.button_index != MOUSE_BUTTON_RIGHT:
		return
	var pos: Vector2 = get_local_mouse_position()
	if pos.x < DUNGEON_ORIGIN.x - 8:
		var c: Vector2i = surface.call("cell_at", pos)
		var want: int = Wang.SOIL if left else Wang.ASH
		var current: int = surface.call("get_terrain", c.x, c.y)
		surface.call("set_terrain", c.x, c.y, Wang.GRASS if current == want else want)
	else:
		var d: Vector2i = dungeon.call("cell_at", pos - DUNGEON_ORIGIN)
		if left:
			dungeon.call("break_wall", d.x, d.y)
		else:
			dungeon.call("place_wall", d.x, d.y)

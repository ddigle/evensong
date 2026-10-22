class_name FixtureView
extends Node
## Draws a map's placeables other than the altar (M3a): the surface's dungeon entrance, the dungeon's
## exit stairs and heretic shrine, decorative wall torches and placed torches, with the torches'
## lights. Sprites go under the y-sorted Entities (node = the footprint's bottom edge, like the altar,
## so characters south of it are drawn in front), ground decals under Decals (below the entities),
## lights under Lighting's Torches node. GameWorld rebuilds it on load_data and updates the tile a
## PLACEABLE edit touches (a torch placed, a wall torch falling with its wall).
##
## Art (04-env, adoption candidates; README "그림 출처"):
##   entrance  dungeon_entrance_v02 + dungeon_entrance_stairs_v01 (steps down) on the footprint, its
##             debris (dungeon_entrance_debris_v01) as a ground decal around it
##   exit      PLACEHOLDER: the same arch with the stairs overlay flipped upside down (steps going up
##             toward the light), set into the wall face above its footprint. No exit art exists
##   shrine    heretic_shrine_v02, fire off (? the heretic fire's colour is open, brief §5.7)
##   wall torch  prop_wall_torch_a_v02 with the shared large flame (flame_large_v01 frames 1-4,
##             unshaded, at the 04-env mockup's anchor) and a small light
##   torch     prop_lantern_ground_v03_lit (the ground lantern a player sets down in the 04-env mockup;
##             no torch art exists), its glowing pixels (prop_lantern_ground_v03_emissive) unshaded

const ARCH: Texture2D = preload("res://art/env/dungeon_entrance_v02.png")
const STAIRS: Texture2D = preload("res://art/env/dungeon_entrance_stairs_v01.png")
const DEBRIS: Texture2D = preload("res://art/env/dungeon_entrance_debris_v01.png")
const SHRINE: Texture2D = preload("res://art/env/heretic_shrine_v02.png")
const WALL_TORCH: Texture2D = preload("res://art/env/prop_wall_torch_a_v02.png")
const FLAME: Texture2D = preload("res://art/env/flame_large_v01.png")
const LANTERN: Texture2D = preload("res://art/env/prop_lantern_ground_v03_lit.png")
const LANTERN_EMISSIVE: Texture2D = preload("res://art/env/prop_lantern_ground_v03_emissive.png")

## Arch art (48x48): opaque rows end at 42, the arch is centred; the stairs overlay's opaque box.
const ARCH_BOTTOM_ROW: int = 42
const STAIRS_BOX: Rect2i = Rect2i(15, 20, 18, 15)
## The debris image has the arch at (24, 12).
const DEBRIS_ARCH_AT: Vector2i = Vector2i(24, 12)
const SHRINE_BOTTOM_ROW: int = 47
## Wall torch (32x32): opaque bottom row 30, centre column 16; flame frame top-left at (9, -4) (the
## 04-env mockup's LIGHT_ANCHORS), 5 frames of 6x10, the 5th the ember (not looped).
const WALL_TORCH_BOTTOM_ROW: int = 30
const FLAME_AT: Vector2i = Vector2i(9, -4)
const FLAME_FRAMES: int = 5
const FLAME_LOOP: int = 4
const FLAME_FRAME_MS: int = 140
## Ground lantern (24x24): opaque bottom row 21, centre column 12, glass centre (12, 14).
const LANTERN_BOTTOM_ROW: int = 21
const LANTERN_GLOW_AT: Vector2i = Vector2i(12, 14)

var data: WorldData
var entities: Node2D
var decals: Node2D
var lights: Node2D
## Nodes by anchor tile (footprint top-left, or the torch's tile), lights and debris by the same.
var nodes: Dictionary[Vector2i, Node2D] = {}
var light_nodes: Dictionary[Vector2i, PointLight2D] = {}
var debris: Dictionary[Vector2i, Sprite2D] = {}
var _flames: Array[Sprite2D] = []

static var _glow: ImageTexture
static var _unshaded: CanvasItemMaterial


func setup(p_data: WorldData, p_entities: Node2D, p_decals: Node2D, p_lights: Node2D) -> void:
	clear()
	data = p_data
	entities = p_entities
	decals = p_decals
	lights = p_lights
	for rect: Rect2i in data.footprints(WorldData.PLACEABLE_ENTRANCE):
		_add_entrance(rect)
	for rect: Rect2i in data.footprints(WorldData.PLACEABLE_EXIT):
		_add_exit(rect)
	for rect: Rect2i in data.footprints(WorldData.PLACEABLE_SHRINE):
		_add_shrine(rect)
	var grid: PackedByteArray = data.layers[WorldData.Layer.PLACEABLE]
	for i: int in grid.size():
		if grid[i] == WorldData.PLACEABLE_TORCH or grid[i] == WorldData.PLACEABLE_WALL_TORCH:
			update_cell(Vector2i(i % data.size.x, i / data.size.x))


func clear() -> void:
	for c: Vector2i in nodes.keys():
		_free(nodes[c])
	for c: Vector2i in light_nodes.keys():
		_free(light_nodes[c])
	for c: Vector2i in debris.keys():
		_free(debris[c])
	nodes.clear()
	light_nodes.clear()
	debris.clear()
	_flames.clear()


## Shows what the data has on torch tile `c` now (a placed torch or a wall torch, or nothing).
func update_cell(c: Vector2i) -> void:
	var p: int = data.get_value(WorldData.Layer.PLACEABLE, c)
	if nodes.has(c) and (p == WorldData.PLACEABLE_TORCH or p == WorldData.PLACEABLE_WALL_TORCH or p == WorldData.PLACEABLE_NONE):
		var old_flame: Sprite2D = nodes[c].get_node_or_null(^"Flame") as Sprite2D
		if old_flame != null:
			_flames.erase(old_flame)
		_free(nodes[c])
		nodes.erase(c)
		if light_nodes.has(c):
			_free(light_nodes[c])
			light_nodes.erase(c)
	match p:
		WorldData.PLACEABLE_TORCH:
			_add_torch(c)
		WorldData.PLACEABLE_WALL_TORCH:
			_add_wall_torch(c)


func _process(_delta: float) -> void:
	var t: int = Time.get_ticks_msec() / FLAME_FRAME_MS
	for f: Sprite2D in _flames:
		if is_instance_valid(f):
			var phase: int = f.get_meta(&"phase", 0)
			f.frame = (t + phase) % FLAME_LOOP


## Top-left (world px) of an arch drawn on footprint `rect` with its bottom row at `bottom_y`.
static func arch_origin(rect: Rect2i, bottom_y: int) -> Vector2i:
	return Vector2i(rect.position.x * Config.TILE + rect.size.x * Config.TILE / 2 - ARCH.get_width() / 2,
		bottom_y - ARCH_BOTTOM_ROW)


func _node(anchor: Vector2i, node_name: String, foot: Vector2) -> Node2D:
	var n: Node2D = Node2D.new()
	n.name = node_name
	n.position = foot
	entities.add_child(n)
	nodes[anchor] = n
	return n


func _sprite(parent: Node, tex: Texture2D, world_pos: Vector2, origin: Vector2, mask: int) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = world_pos - origin
	s.light_mask = mask
	parent.add_child(s)
	return s


static func foot_of(rect: Rect2i) -> Vector2:
	return Vector2(rect.position.x * Config.TILE + rect.size.x * Config.TILE / 2.0, rect.end.y * Config.TILE)


func _add_entrance(rect: Rect2i) -> void:
	var foot: Vector2 = foot_of(rect)
	var n: Node2D = _node(rect.position, "Entrance", foot)
	var origin: Vector2i = arch_origin(rect, rect.end.y * Config.TILE - 1)
	_sprite(n, ARCH, Vector2(origin), foot, Config.LIGHT_LAYER_WORLD).name = &"Arch"
	_sprite(n, STAIRS, Vector2(origin), foot, Config.LIGHT_LAYER_WORLD).name = &"Stairs"
	var d: Sprite2D = _sprite(decals, DEBRIS, Vector2(origin - DEBRIS_ARCH_AT), Vector2.ZERO, Config.LIGHT_LAYER_WORLD)
	d.name = StringName("EntranceDebris_%d_%d" % [rect.position.x, rect.position.y])
	debris[rect.position] = d


func _add_exit(rect: Rect2i) -> void:
	# The footprint is the wall face; the arch stands in it with its base on the face's bottom (2 px
	# past the face tiles, where the cliff tiles' face shadow ends).
	var foot: Vector2 = foot_of(rect)
	var n: Node2D = _node(rect.position, "Exit", foot)
	var origin: Vector2i = arch_origin(rect, rect.end.y * Config.TILE + 2)
	_sprite(n, ARCH, Vector2(origin), foot, Config.LIGHT_LAYER_WORLD).name = &"Arch"
	var up: Sprite2D = _sprite(n, STAIRS, Vector2(origin + STAIRS_BOX.position), foot, Config.LIGHT_LAYER_WORLD)
	up.name = &"StairsUp"
	up.region_enabled = true
	up.region_rect = Rect2(STAIRS_BOX)
	up.flip_v = true


func _add_shrine(rect: Rect2i) -> void:
	var foot: Vector2 = foot_of(rect)
	var n: Node2D = _node(rect.position, "Shrine", foot)
	var origin: Vector2i = Vector2i(rect.position.x * Config.TILE + rect.size.x * Config.TILE / 2 - SHRINE.get_width() / 2,
		rect.end.y * Config.TILE - 1 - SHRINE_BOTTOM_ROW)
	_sprite(n, SHRINE, Vector2(origin), foot, Config.LIGHT_LAYER_WORLD).name = &"Sprite"


## A wall torch on wall tile `c` hangs on its face: sorted at the face tile's bottom edge.
static func wall_torch_origin(c: Vector2i) -> Vector2i:
	var face_bottom: int = c.y * Config.TILE + Config.TILE / 2 + Config.FACE_TOP_PX + Config.FACE_HEIGHT_PX - 1
	return Vector2i(c.x * Config.TILE + Config.TILE / 2 - WALL_TORCH.get_width() / 2, face_bottom - WALL_TORCH_BOTTOM_ROW)


func _add_wall_torch(c: Vector2i) -> void:
	var foot: Vector2 = Vector2(c.x * Config.TILE + Config.TILE / 2, (c.y + 2) * Config.TILE)
	var n: Node2D = _node(c, "WallTorch_%d_%d" % [c.x, c.y], foot)
	var origin: Vector2i = wall_torch_origin(c)
	_sprite(n, WALL_TORCH, Vector2(origin), foot, Config.LIGHT_LAYER_WORLD).name = &"Sprite"
	var f: Sprite2D = _sprite(n, FLAME, Vector2(origin + FLAME_AT), foot, Config.LIGHT_LAYER_WORLD)
	f.name = &"Flame"
	f.hframes = FLAME_FRAMES
	f.material = unshaded_material()
	f.set_meta(&"phase", posmod(c.x * 7 + c.y * 3, FLAME_LOOP))
	_flames.append(f)
	var l: PointLight2D = TorchLight.make(Config.WALL_TORCH_LIGHT_RADIUS_PX, Config.WALL_TORCH_LIGHT_ENERGY,
		Vector2(origin + FLAME_AT + Vector2i(3, 6)))
	l.name = StringName("WallTorchLight_%d_%d" % [c.x, c.y])
	lights.add_child(l)
	light_nodes[c] = l


static func torch_origin(c: Vector2i) -> Vector2i:
	return Vector2i(c.x * Config.TILE + Config.TILE / 2 - LANTERN.get_width() / 2, (c.y + 1) * Config.TILE - 1 - LANTERN_BOTTOM_ROW)


func _add_torch(c: Vector2i) -> void:
	var foot: Vector2 = Vector2(c.x * Config.TILE + Config.TILE / 2, (c.y + 1) * Config.TILE)
	var n: Node2D = _node(c, "Torch_%d_%d" % [c.x, c.y], foot)
	var origin: Vector2i = torch_origin(c)
	_sprite(n, LANTERN, Vector2(origin), foot, Config.LIGHT_LAYER_ACTORS).name = &"Sprite"
	var g: Sprite2D = _sprite(n, glow_texture(), Vector2(origin), foot, Config.LIGHT_LAYER_ACTORS)
	g.name = &"Glow"
	g.material = unshaded_material()
	var l: PointLight2D = TorchLight.make(Config.TORCH_LIGHT_RADIUS_PX, Config.TORCH_LIGHT_ENERGY, Vector2(origin + LANTERN_GLOW_AT))
	l.name = StringName("TorchLight_%d_%d" % [c.x, c.y])
	lights.add_child(l)
	light_nodes[c] = l


## The lit lantern's glowing pixels (where the emissive mask is opaque), drawn unshaded.
static func glow_texture() -> ImageTexture:
	if _glow == null:
		var lit: Image = LightGen.to_rgba8(LANTERN.get_image())
		var em: Image = LightGen.to_rgba8(LANTERN_EMISSIVE.get_image())
		var out: Image = Image.create_empty(lit.get_width(), lit.get_height(), false, Image.FORMAT_RGBA8)
		for y: int in lit.get_height():
			for x: int in lit.get_width():
				if em.get_pixel(x, y).a8 >= 128:
					out.set_pixel(x, y, lit.get_pixel(x, y))
		_glow = ImageTexture.create_from_image(out)
	return _glow


static func unshaded_material() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


## Nodes against the data: every footprint and torch tile drawn, nothing extra.
func verify() -> Dictionary[String, int]:
	var bad: int = 0
	var want: int = 0
	for p: int in [WorldData.PLACEABLE_ENTRANCE, WorldData.PLACEABLE_EXIT, WorldData.PLACEABLE_SHRINE]:
		for rect: Rect2i in data.footprints(p):
			want += 1
			if not nodes.has(rect.position) or nodes[rect.position].position != foot_of(rect):
				bad += 1
	var torches: int = 0
	var grid: PackedByteArray = data.layers[WorldData.Layer.PLACEABLE]
	for i: int in grid.size():
		if grid[i] == WorldData.PLACEABLE_TORCH or grid[i] == WorldData.PLACEABLE_WALL_TORCH:
			want += 1
			torches += 1
			var c: Vector2i = Vector2i(i % data.size.x, i / data.size.x)
			if not nodes.has(c) or not light_nodes.has(c):
				bad += 1
	bad += maxi(nodes.size() - want, 0)
	return {"fixtures": nodes.size(), "torches": torches, "lights": light_nodes.size(), "mismatches": bad}


func _free(n: Node) -> void:
	if is_instance_valid(n):
		n.get_parent().remove_child(n)
		n.free()

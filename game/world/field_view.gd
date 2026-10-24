class_name FieldView
extends Node2D
## Draws the fields (M5a): the watered soil and the crops. GameWorld puts it right above the Ground (below the decals,
## the target marker and the entities), sets it up on load_data and updates the tile an edit touches.
##
## Watered soil (● brief §5.7 R29 "물 준 흙은 칸별 덧칠", no second soil tileset): a wet tile is drawn over the ground with
## the 04-env watered copies of the soil tiles (tiles_grass-soil_v03_watered.png, tiles_soil_var_{1,2}_v01_watered.png,
## the same layout as the dry ones; only the soil pixels differ). The ground is a dual grid (world/ground_view.gd): world
## tile v is the four quadrants around vertex v of the four display cells that have v as a corner, so a wet tile is those
## four 8x8 quadrants taken from the watered copy of the tile each display cell shows (GroundView.drawn_at). One WetPatch
## node per wet tile (a canvas item takes at most 15 lights; the ground's light layer, LIGHT_LAYER_WORLD). A floor edit
## redraws the wet tiles around it (their display cells may show other tiles now).
##
## Crops: one Sprite2D per crop under the y-sorted Entities, on the tile's bottom edge like a gatherable (ItemView): the
## 04-env crops_v03_sheet.png (rows healing / buff / poison; columns stages 0..4, the harvest bunch, withered), the
## actors' hard light like the gatherables. A withered crop shows the withered picture at any stage (the sheet has one,
## of a grown plant: placeholder for the young ones, README). The sheet's soil mound is drawn in its own browns; 04-env
## prompts.md says to recolour the mound to the soil it stands on ("작물 흙더미 색은 이 흙 색에 맞춰 바꿔 쓴다(물 준 칸에서는
## 물 준 색으로)"), so the sheet is used in two recoloured copies, dry and wet (MOUND_*: the mound's browns to the dry /
## watered soil tile's colours, measured from those tiles; the harvest column is left as it is).

const CROPS_PATH: String = "res://art/env/crops_v03_sheet.png"
## Watered copies of the ground's soil sources (TilesetBuilder source ids).
const WET_PATHS: Dictionary[int, String] = {
	TilesetBuilder.SRC_GRASS_SOIL: "res://art/tiles/tiles_grass-soil_v03_watered.png",
	TilesetBuilder.SRC_SOIL_VARIANTS: "res://art/tiles/tiles_soil_var_1_v01_watered.png",
	TilesetBuilder.SRC_SOIL_VARIANTS + 1: "res://art/tiles/tiles_soil_var_2_v01_watered.png",
}
const CELL: int = 16
const QUAD: int = 8
## Sheet columns: stages 0..4, then the harvest bunch and the withered plant.
const COLUMN_HARVEST: int = 5
const COLUMN_WITHERED: int = 6
## IMPL (M5a, the 04-env note above): the mound's browns in crops_v03 (outline, fill, top light) -> the soil tile's dark
## rim, fill and light colours (tiles_grass-soil_v03), and -> the watered tile's (tiles_grass-soil_v03_watered: the
## soil fill 6a4528 becomes 4b3021 there, the dark 56321b becomes 331f16, the light bits 5c3c27). The seed mound (column
## 0) also has a mid and a light brown.
const MOUND_DRY: Dictionary[int, int] = {0x5b2e15: 0x56321b, 0x723f0e: 0x6a4528, 0x83501c: 0x7f5531}
const MOUND_WET: Dictionary[int, int] = {0x5b2e15: 0x331f16, 0x723f0e: 0x4b3021, 0x83501c: 0x5c3c27}
const SEED_MOUND_DRY: Dictionary[int, int] = {0x8c5a2c: 0x6a4528, 0xb0814e: 0x7f5531}
const SEED_MOUND_WET: Dictionary[int, int] = {0x8c5a2c: 0x4b3021, 0xb0814e: 0x84603f}


## One wet tile: four quadrants of watered tiles.
class WetPatch:
	extends Node2D
	var textures: Array[Texture2D] = []
	var sources: Array[Rect2] = []
	var targets: Array[Vector2] = []

	func _draw() -> void:
		for i: int in textures.size():
			draw_texture_rect_region(textures[i], Rect2(targets[i], Vector2(FieldView.QUAD, FieldView.QUAD)), sources[i])


var data: WorldData
var ground: GroundView
var entities: Node2D
var wet: Dictionary[Vector2i, WetPatch] = {}
var crops: Dictionary[Vector2i, Sprite2D] = {}
## Quadrants a wet tile could not take from a watered tile (its display cell shows no soil tile): 0 in a valid world.
var missing_quads: int = 0

static var _wet_textures: Dictionary[int, Texture2D] = {}
static var _sheets: Dictionary[bool, Texture2D] = {}


## Everything for `p_data` (the old drawing removed).
func setup(p_data: WorldData, p_ground: GroundView, p_entities: Node2D) -> void:
	clear()
	data = p_data
	ground = p_ground
	entities = p_entities
	for c: Vector2i in Farming.field_cells(data):
		update_cell(c)


func clear() -> void:
	for patch: WetPatch in wet.values():
		_remove(patch)
	for s: Sprite2D in crops.values():
		_remove(s)
	wet.clear()
	crops.clear()
	missing_quads = 0


## Shows tile `c` as the data has it now (a VEGETATION edit: planted, grown, watered, dried, withered, harvested).
func update_cell(c: Vector2i) -> void:
	var f: Farming.Field = Farming.field_at(data, c)
	_update_wet(c, f != null and f.wet)
	if crops.has(c):
		_remove(crops[c])
		crops.erase(c)
	if f == null or f.kind == Farming.KIND_NONE:
		return
	var s: Sprite2D = Sprite2D.new()
	s.name = StringName("Crop_%d_%d" % [c.x, c.y])
	s.texture = crop_sheet(f.wet)
	s.region_enabled = true
	s.region_rect = Rect2(crop_region(f))
	s.centered = false
	s.offset = Vector2(-CELL / 2, -CELL)
	s.position = crop_position(c)
	s.light_mask = Config.LIGHT_LAYER_ACTORS
	entities.add_child(s)
	crops[c] = s


## A floor edit at vertex `v` (tilled): the wet tiles whose quadrants come from the display cells around it.
func update_floor(v: Vector2i) -> void:
	for y: int in range(v.y - 1, v.y + 2):
		for x: int in range(v.x - 1, v.x + 2):
			var c: Vector2i = Vector2i(x, y)
			if wet.has(c):
				_update_wet(c, true)


func _update_wet(c: Vector2i, on: bool) -> void:
	if wet.has(c):
		_remove(wet[c])
		wet.erase(c)
	if not on:
		return
	var patch: WetPatch = WetPatch.new()
	patch.name = StringName("Wet_%d_%d" % [c.x, c.y])
	patch.position = Vector2(c * CELL)
	patch.light_mask = Config.LIGHT_LAYER_WORLD
	for q: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var quad: Array = wet_quad(ground, c, q)
		if quad.is_empty():
			missing_quads += 1
			continue
		var tex: Texture2D = quad[0]
		var src: Rect2 = quad[1]
		patch.textures.append(tex)
		patch.sources.append(src)
		patch.targets.append(Vector2(q * QUAD))
	add_child(patch)
	wet[c] = patch


## The quadrant `q` (0/1, 0/1 = the tile's NW / NE / SW / SE quarter) of wet tile `c`: [watered texture, source rect], or
## empty when that display cell shows no soil tile. Quarter q of tile c is the quadrant of display cell c + q - (1, 1)
## at its corner c (the corner opposite q).
static func wet_quad(p_ground: GroundView, c: Vector2i, q: Vector2i) -> Array:
	var d: Vector2i = c + q - Vector2i.ONE
	var drawn: Vector3i = p_ground.drawn_at(d)
	var tex: Texture2D = wet_texture(drawn.x)
	if tex == null:
		return []
	var local: Vector2i = (Vector2i.ONE - q) * QUAD
	return [tex, Rect2(Vector2(drawn.y * CELL + local.x, drawn.z * CELL + local.y), Vector2(QUAD, QUAD))]


## The watered copy of ground source `source` (null: that source has no soil).
static func wet_texture(source: int) -> Texture2D:
	if not WET_PATHS.has(source):
		return null
	if not _wet_textures.has(source):
		_wet_textures[source] = load(WET_PATHS[source]) as Texture2D
	return _wet_textures[source]


## The crop sheet with its mounds in the dry or the watered soil's colours (see the class comment).
static func crop_sheet(is_wet: bool) -> Texture2D:
	if _sheets.has(is_wet):
		return _sheets[is_wet]
	var img: Image = LightGen.to_rgba8((load(CROPS_PATH) as Texture2D).get_image())
	var map: Dictionary[int, int] = MOUND_WET if is_wet else MOUND_DRY
	var seed_map: Dictionary[int, int] = SEED_MOUND_WET if is_wet else SEED_MOUND_DRY
	for y: int in img.get_height():
		for x: int in img.get_width():
			var col: int = x / CELL
			if col == COLUMN_HARVEST:
				continue
			var px: Color = img.get_pixel(x, y)
			if px.a8 == 0:
				continue
			var rgb: int = (px.r8 << 16) | (px.g8 << 8) | px.b8
			var to: int = map.get(rgb, -1)
			if to < 0 and col == 0:
				to = seed_map.get(rgb, -1)
			if to >= 0:
				img.set_pixel(x, y, Color8((to >> 16) & 0xff, (to >> 8) & 0xff, to & 0xff, px.a8))
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_sheets[is_wet] = tex
	return tex


## The sheet cell a field's crop shows (row = crop, column = stage, or the withered plant).
static func crop_region(f: Farming.Field) -> Rect2i:
	var col: int = COLUMN_WITHERED if f.withered else f.stage
	return Rect2i(col * CELL, (f.kind - 1) * CELL, CELL, CELL)


## A crop sprite's node position: the bottom middle of its tile (y-sorted like the feet).
static func crop_position(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL / 2, (c.y + 1) * CELL)


func _remove(n: Node) -> void:
	if is_instance_valid(n):
		n.get_parent().remove_child(n)
		n.free()


## The drawing against the data: every wet tile has its patch (four quadrants), every crop its sprite (sheet, cell,
## place), nothing extra. 0 mismatches = the view shows the data.
func verify() -> Dictionary[String, int]:
	var bad: int = 0
	var wet_cells: int = 0
	var crop_cells: int = 0
	for c: Vector2i in Farming.field_cells(data):
		var f: Farming.Field = Farming.field_at(data, c)
		if f.wet:
			wet_cells += 1
			var patch: WetPatch = wet.get(c, null)
			if patch == null or patch.textures.size() != 4 or patch.position != Vector2(c * CELL):
				bad += 1
		if f.kind != Farming.KIND_NONE:
			crop_cells += 1
			var s: Sprite2D = crops.get(c, null)
			if s == null or s.texture != crop_sheet(f.wet) or s.region_rect != Rect2(crop_region(f)) \
					or s.position != crop_position(c):
				bad += 1
	bad += maxi(wet.size() - wet_cells, 0) + maxi(crops.size() - crop_cells, 0)
	return {"wet": wet.size(), "crops": crops.size(), "missing_quads": missing_quads, "mismatches": bad}

class_name CreatureView
extends Node2D
## The picture of one creature (combat/creature_sim.gd, M11a). M11 creature art: the 03-pixel sheets of PixelLab 16차 (art/creatures/, byte
## copies of assets/concept/03-pixel/<kind>_v02_rotations.png and <kind>_v02_walk.png: adoption candidates the human has not confirmed yet,
## README "M11 생물 그림"). They replaced the M11a placeholder drawn in code (character maps) the way M8 replaced the merchant's.
## Every kind has one cell size (CELLS, multiples of 4, art at 1x): its rotations sheet is one row of four cells (south, east, north, west),
## its walk sheet three rows (south, east, north) of WALK_FRAMES frames. In every cell the feet are on the bottom row and the body is centred
## on the cell's middle column (the art step's clean-up, creatures.py). Standing = the rotation's cell (CreatureSim.STAND), walking = the
## six-frame cycle (CreatureSim.frame: the walk's frame time, faster while it flees, Config.CREATURE_FLEE_FRAME_TICKS). West = the east
## cells mirrored by the Rig's scale.x = -1 (● R19 as for the players; the sheet's own west cell is that mirror and is never drawn).
## The node sits on the feet (the cell's bottom row just above it, like Character), so the y-sorted Entities sorts it with the characters;
## the light layer is the actors' (hard), like a heretic.
##
## Shows: the walk, the hit flash and the HP bar once hurt (the heretic's colours and rule, Heretic.bar_fill; drawn in code, unshaded) BAR_GAP
## px over the kind's tallest picture (height_of: every cell of its two sheets, so the bar holds still while it turns and walks), the marks of
## a poison, a stun or a slow (EffectMarks) over the bar, and the corpse (corpse_image: its south standing picture turned a quarter clockwise,
## lying on its side with the head east, west mirrored by the Rig like the rest; its lowest row on the feet row. M11a turned the picture
## upside down: with the sheets that stood the deer on its head and the stag on its antlers).
## M11b (PLACEHOLDERS drawn in code, unshaded so they read at dusk): a rare creature's HP bar has a notch at the capture threshold
## (Config.CAPTURE_HP_PCT); a creature a snare can take has a blinking gold ring at its feet (glow_pixels); one a snare holds has a dashed
## rope back to where it was thrown from (rope_pixels); a blow that did nothing to it shows the refused cross (EffectMarks).
## The sheets are read into Images once (_measure: the tops, the corpses, the CPU pictures image() and icon() give), never while it
## walks: the body is a Sprite2D region of the imported sheet.

## IMPL (M11 creature art): every kind's cell (W x H), as the art step packed the sheets (03-pixel prompts.md "PixelLab 16차").
const CELLS: Dictionary[StringName, Vector2i] = {
	&"hare": Vector2i(24, 24),
	&"deer": Vector2i(40, 36),
	&"lamp_fox": Vector2i(36, 24),
	&"silver_stag": Vector2i(44, 44),
	&"ash_owl": Vector2i(16, 24),
}
## The rotations sheets: one row, ROTATION_CELLS cells (south, east, north, west).
const ROTATIONS: Dictionary[StringName, Texture2D] = {
	&"hare": preload("res://art/creatures/hare_v02_rotations.png"),
	&"deer": preload("res://art/creatures/deer_v02_rotations.png"),
	&"lamp_fox": preload("res://art/creatures/lamp_fox_v02_rotations.png"),
	&"silver_stag": preload("res://art/creatures/silver_stag_v02_rotations.png"),
	&"ash_owl": preload("res://art/creatures/ash_owl_v02_rotations.png"),
}
## The walk sheets: rows south, east, north (RigData.sheet_row), WALK_FRAMES columns.
const WALKS: Dictionary[StringName, Texture2D] = {
	&"hare": preload("res://art/creatures/hare_v02_walk.png"),
	&"deer": preload("res://art/creatures/deer_v02_walk.png"),
	&"lamp_fox": preload("res://art/creatures/lamp_fox_v02_walk.png"),
	&"silver_stag": preload("res://art/creatures/silver_stag_v02_walk.png"),
	&"ash_owl": preload("res://art/creatures/ash_owl_v02_walk.png"),
}
const ROTATION_CELLS: int = 4
const WALK_FRAMES: int = CreatureSim.WALK_FRAMES
## IMPL: HP bar height and how far above the picture's top row it sits, and the gap between the bar and the marks.
const BAR_HEIGHT: int = 2
const BAR_GAP: int = 2
const MARK_GAP: int = 6
## IMPL (M11b): the ring's dots and how often they swap, how far it reaches past the hit box and how tall it is, its and the rope's colours
## (§4 faith gold; cream), the notch's (§4 faith ivory), the rope's dash (lit of each DASH px).
const GLOW_DOTS: int = 20
const GLOW_STEP_TICKS: int = 15
const GLOW_MARGIN_PX: int = 3
const GLOW_HALF_HEIGHT_PX: int = 3
const GLOW_COLOUR: Color = Color8(0xf4, 0xc9, 0x5d)
const ROPE_COLOUR: Color = Color8(0xdc, 0xc4, 0x9a)
const NOTCH_COLOUR: Color = Color8(0xef, 0xe3, 0xc6)
const ROPE_DASH: int = 4
const ROPE_LIT: int = 2

## The sheets as RGBA8 Images (key "<kind>/rot" or "<kind>/walk"), each kind's first opaque row over all its cells, and its corpse.
## Filled once by _measure.
static var _sheets: Dictionary[String, Image] = {}
static var _tops: Dictionary[StringName, int] = {}
static var _corpses: Dictionary[StringName, ImageTexture] = {}

var rig: Node2D
var body: Sprite2D
var bar: Node2D
## M11b: the ring and the rope, under the body.
var halo: Node2D
var marks: EffectMarks
var sim_id: int = 0
## What is shown (tests read it): the kind, the sheet row (0 south, 1 east, 2 north), the frame (CreatureSim.STAND or a walk frame).
var kind: StringName = &""
var row: int = 0
var frame: int = CreatureSim.STAND
var hp_ratio: float = 1.0
## M11b: the ring's phase (-1 = no ring), the rope's far end from the feet (zero = no rope).
var glow_phase: int = -1
var rope_to: Vector2i = Vector2i.ZERO
var _bar_top: int = 0


func _init() -> void:
	_measure()
	halo = Node2D.new()
	halo.name = &"Halo"
	halo.material = FixtureView.unshaded_material()
	halo.visible = false
	halo.draw.connect(_draw_halo)
	add_child(halo)
	rig = Node2D.new()
	rig.name = &"Rig"
	add_child(rig)
	body = Sprite2D.new()
	body.name = &"Body"
	body.centered = false
	body.region_enabled = true
	body.light_mask = Config.LIGHT_LAYER_ACTORS
	rig.add_child(body)
	bar = Node2D.new()
	bar.name = &"HpBar"
	bar.material = FixtureView.unshaded_material()
	bar.visible = false
	bar.draw.connect(_draw_bar)
	add_child(bar)
	light_mask = Config.LIGHT_LAYER_ACTORS
	marks = EffectMarks.new()
	add_child(marks)


## The cell size of kind `k` (all its cells, both sheets).
static func cell_size(k: StringName) -> Vector2i:
	return CELLS[k]


## The sheet that holds frame `f` of kind `k`: the rotations for CreatureSim.STAND, else the walk.
static func sheet(k: StringName, f: int) -> Texture2D:
	return ROTATIONS[k] if f == CreatureSim.STAND else WALKS[k]


## The cell of kind `k` in sheet row `r` (RigData.sheet_row: 0 south, 1 east, 2 north) and frame `f` on sheet(k, f).
static func region(k: StringName, r: int, f: int) -> Rect2i:
	var s: Vector2i = CELLS[k]
	if f == CreatureSim.STAND:
		return Rect2i(Vector2i(r * s.x, 0), s)
	return Rect2i(Vector2i(f * s.x, r * s.y), s)


## The picture (the whole cell, RGBA8) of `k` in sheet row `r`, frame `f`, read from the sheet (no texture is read: _measure keeps it).
static func image(k: StringName, r: int, f: int) -> Image:
	_measure()
	var img: Image = _sheets["%s/%s" % [k, "rot" if f == CreatureSim.STAND else "walk"]]
	return img.get_region(region(k, r, f))


## Where the cell's top-left goes relative to the feet: bottom middle on the feet (every cell's width is even).
static func picture_offset(k: StringName) -> Vector2i:
	var s: Vector2i = CELLS[k]
	return Vector2i(-s.x / 2, -s.y)


## How tall kind `k` stands: from its feet row to the first opaque row of the tallest of all its cells (the HP bar's place).
static func height_of(k: StringName) -> int:
	_measure()
	return CELLS[k].y - _tops[k]


## The corpse of `k`: its south standing picture turned a quarter clockwise (on its side, the head east), cropped to what is drawn.
static func corpse_image(k: StringName) -> Image:
	var img: Image = image(k, RigData.sheet_row(RigData.Dir.SOUTH), CreatureSim.STAND)
	img.rotate_90(CLOCKWISE)
	return img.get_region(img.get_used_rect())


static func corpse_texture(k: StringName) -> ImageTexture:
	_measure()
	return _corpses[k]


## Where the corpse's top-left goes relative to the feet: bottom middle on the feet.
static func corpse_offset(k: StringName) -> Vector2i:
	var s: Vector2i = corpse_texture(k).get_size()
	return Vector2i(-s.x / 2, -s.y)


## The collection panel's picture of `k`: its east standing picture, cropped to what is drawn.
static func icon(k: StringName) -> Image:
	var img: Image = image(k, RigData.sheet_row(RigData.Dir.EAST), CreatureSim.STAND)
	return img.get_region(img.get_used_rect())


## The first row of `img` with an opaque pixel (alpha >= 128), or its height when none.
static func first_opaque_row(img: Image) -> int:
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a8 >= 128:
				return y
	return img.get_height()


## Reads every sheet once and keeps the tops (the bar) and the corpses.
static func _measure() -> void:
	if not _sheets.is_empty():
		return
	for k: StringName in CELLS:
		_sheets["%s/rot" % k] = LightGen.to_rgba8(ROTATIONS[k].get_image())
		_sheets["%s/walk" % k] = LightGen.to_rgba8(WALKS[k].get_image())
	for k2: StringName in CELLS:
		var top: int = CELLS[k2].y
		for r: int in RigData.ROWS:
			top = mini(top, first_opaque_row(image(k2, r, CreatureSim.STAND)))
			for f: int in WALK_FRAMES:
				top = mini(top, first_opaque_row(image(k2, r, f)))
		_tops[k2] = top
		_corpses[k2] = ImageTexture.create_from_image(corpse_image(k2))


func show_sim(c: CreatureSim) -> void:
	sim_id = c.id
	kind = c.kind
	position = c.pos.round()
	row = RigData.sheet_row(c.facing)
	frame = c.frame()
	rig.scale = Vector2(-1.0 if RigData.is_mirrored(c.facing) else 1.0, 1.0)
	var dead: bool = not c.alive()
	var tex: Texture2D = corpse_texture(kind) if dead else sheet(kind, frame)
	if body.texture != tex:
		body.texture = tex
	body.region_enabled = not dead
	var cell: Rect2 = Rect2(region(kind, row, frame))
	if not dead and body.region_rect != cell:
		body.region_rect = cell
	body.position = Vector2(corpse_offset(kind) if dead else picture_offset(kind))
	body.modulate = Player.HIT_FLASH if c.flash_ticks > 0 else Color.WHITE
	var top: int = -height_of(kind) - BAR_GAP - BAR_HEIGHT - 2
	var ratio: float = float(c.hp) / c.hp_max()
	bar.visible = c.alive() and c.hp < c.hp_max()
	if ratio != hp_ratio or top != _bar_top:
		hp_ratio = ratio
		_bar_top = top
		bar.queue_redraw()
	var kinds: Array[int] = []
	if c.poisoned():
		kinds.append(EffectMarks.Kind.POISON)
	if c.stunned():
		kinds.append(EffectMarks.Kind.STUN)
	if c.slowed():
		kinds.append(EffectMarks.Kind.SLOW)
	if c.refused_ticks > 0 and c.alive():
		kinds.append(EffectMarks.Kind.REFUSED)  # M11b
	marks.show_kinds(kinds)
	marks.position = Vector2(0.0, top - MARK_GAP - EffectMarks.SIZE - EffectMarks.MARK_Y)
	var phase: int = (c.clock / GLOW_STEP_TICKS) % 2 if c.can_be_taken() else -1
	var rope: Vector2i = Vector2i((c.held_from - c.pos).round()) if c.held() else Vector2i.ZERO
	if phase != glow_phase or rope != rope_to:
		glow_phase = phase
		rope_to = rope
		halo.queue_redraw()
	halo.visible = phase >= 0 or rope != Vector2i.ZERO


## M11b: the ring's dots of kind `k` in `phase` (0, 1: every other dot), relative to the feet: an ellipse GLOW_MARGIN_PX past its hit box,
## GLOW_HALF_HEIGHT_PX tall, centred a px above the feet.
static func glow_pixels(k: StringName, phase: int) -> Array[Vector2i]:
	var row_of: Dictionary = Config.CREATURES[k]
	var half_x: float = row_of["hit_radius_px"]
	half_x += GLOW_MARGIN_PX
	var out: Array[Vector2i] = []
	for i: int in GLOW_DOTS:
		if i % 2 != phase:
			continue
		var a: float = TAU * i / GLOW_DOTS
		var p: Vector2i = Vector2i(roundi(half_x * cos(a)), roundi(GLOW_HALF_HEIGHT_PX * sin(a)) - 1)
		if not out.has(p):
			out.append(p)
	return out


## M11b: the rope's lit px, relative to the feet, from 4 px above the feet to `to`.
static func rope_pixels(to: Vector2i) -> Array[Vector2i]:
	var from: Vector2i = Vector2i(0, -4)
	var out: Array[Vector2i] = []
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	for k: int in steps + 1:
		if k % ROPE_DASH < ROPE_LIT:
			var t: float = float(k) / maxi(steps, 1)
			out.append(Vector2i(Vector2(from).lerp(Vector2(to), t).round()))
	return out


func _draw_halo() -> void:
	if glow_phase >= 0:
		for p: Vector2i in glow_pixels(kind, glow_phase):
			halo.draw_rect(Rect2(Vector2(p), Vector2.ONE), GLOW_COLOUR)
	if rope_to != Vector2i.ZERO:
		for p: Vector2i in rope_pixels(rope_to):
			halo.draw_rect(Rect2(Vector2(p), Vector2.ONE), ROPE_COLOUR)


## M11b: the notch's column in the HP bar's fill: the capture threshold's share of its width.
static func notch_x() -> int:
	return Heretic.BAR_SIZE.x * Config.CAPTURE_HP_PCT / 100


func _draw_bar() -> void:
	var w: int = Heretic.BAR_SIZE.x
	var left: Vector2 = Vector2(-w / 2 - 1, _bar_top)
	bar.draw_rect(Rect2(left, Vector2(w + 2, BAR_HEIGHT + 2)), Heretic.BAR_BACK)
	bar.draw_rect(Rect2(left + Vector2.ONE, Vector2(Heretic.bar_fill(hp_ratio), BAR_HEIGHT)), Heretic.BAR_FILL)
	if Creatures.is_rare(kind):
		bar.draw_rect(Rect2(left + Vector2(1 + notch_x(), 1), Vector2(1, BAR_HEIGHT)), NOTCH_COLOUR)

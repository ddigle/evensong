class_name BossView
extends Node2D
## M12a: the heretic leader's picture (combat/boss_sim.gd), a CODE-DRAWN PLACEHOLDER built on our heretic sheets (03-pixel heretic_v02, the
## same frames: HereticSim.SHEET_PATHS) until a sheet of its own exists (PixelLab was not approved for the boss). One data-driven class: the
## LOOK constants below decide everything it adds, and a real sheet replaces it by pointing SOURCE_SHEETS at it and turning the additions
## off (README "M12a" boss view row). Every sheet is derived once at load (derived_sheet), deterministically:
##   - each cell padded PAD px all round (room for the mitre and the outline) and drawn at SCALE (an integer: crisp, nearest)
##   - the heretic's neutral greys recoloured by brightness onto ROBE (brief §4 demon row: clotted blood, scarlet) so the leader is not grey
##   - a tall dark mitre (MITRE_MAP: clotted blood with a gold band and a demon-orange stone) stamped on the hood's top in every standing
##     frame (the hood's top row and middle found per cell), sunk MITRE_SINK rows into it
##   - a heavier silhouette: a second outline ring (OUTLINE) round everything
## and, drawn live: a ground shadow (SHADOW_*), a brazier staff on its side (STAFF_*, per facing, mirrored west) whose bowl burns with the
## heretic-side flame (● brief §5.7 R49 candB demon orange, 04-env flame_heretic_small_candB_v01 and its glow) and an orange light
## (Config.BOSS_FIRE_LIGHT_*), the hit flash, an exposed tint on the shadow and the effect marks (stun, slow, taunt, poison) raised over the
## mitre. The node sits on the feet in the y-sorted entities, on the actors' light layer like a heretic.

## The heretic sheets it is built on (HereticSim.Anim order).
const SOURCE_SHEETS: Array[Texture2D] = [
	preload("res://art/enemies/heretic_v02_walk.png"), preload("res://art/enemies/heretic_v02_idle.png"),
	preload("res://art/enemies/heretic_v02_attack.png"), preload("res://art/enemies/heretic_v02_hurt.png"),
	preload("res://art/enemies/heretic_v02_death.png"),
]
## --- LOOK (PLACEHOLDER values, IMPL) ---
## Integer picture scale (1 = the heretic's own size; 2 = twice, still crisp) and the padding round each derived cell (source px).
const SCALE: int = 1
const PAD: int = 12
## The recolour: a neutral grey pixel (saturation under ROBE_MAX_SAT, brightness in ROBE_LUMA) takes ROBE[k] by its brightness band
## (ROBE_BANDS: upper edges of the bands, darkest first).
const ROBE_MAX_SAT: float = 0.18
const ROBE_LUMA: Vector2 = Vector2(40.0, 230.0)
const ROBE_BANDS: PackedFloat32Array = [70.0, 100.0, 130.0, 165.0, 230.0]
const ROBE: Array[Color] = [Color8(0x2a, 0x08, 0x08), Color8(0x45, 0x0d, 0x0d), Color8(0x5c, 0x10, 0x10), Color8(0x8f, 0x1a, 0x1a),
	Color8(0xb0, 0x3a, 0x26)]
## The second outline ring.
const OUTLINE: Color = Color8(0x12, 0x0b, 0x09)
## The mitre (rows top first; "k" outline, "d" clotted blood, "b" blood, "g" gold, "F" demon orange, "." nothing), its bottom row sunk
## MITRE_SINK rows into the hood's top, centred on the hood's middle; only on cells whose figure is at least MITRE_MIN_HEIGHT tall (not
## the lying death frames).
const MITRE_MAP: Array = [
	"...kk...",
	"..kddk..",
	"..kdbk..",
	"..kdbk..",
	".kddbdk.",
	".kdbbdk.",
	".kdFFdk.",
	".kdFFdk.",
	"kddbbddk",
	"kddddddk",
	"kggggggk",
	"kkkkkkkk",
]
const MITRE_COLOURS: Dictionary[String, Color] = {
	"k": Color8(0x1a, 0x17, 0x14), "d": Color8(0x2a, 0x08, 0x08), "b": Color8(0x5c, 0x10, 0x10), "g": Color8(0xc9, 0x93, 0x2b),
	"F": Color8(0xff, 0x7a, 0x1a),
}
const MITRE_SINK: int = 3
const MITRE_MIN_HEIGHT: int = 18
## The ground shadow (an ellipse of SHADOW_SIZE under the feet) and its tint while exposed.
const SHADOW_SIZE: Vector2i = Vector2i(22, 6)
const SHADOW: Color = Color(0.06, 0.05, 0.04, 0.6)
const SHADOW_EXPOSED: Color = Color(0.70, 0.22, 0.06, 0.7)
## The brazier staff: its foot's x from the feet by sheet row (south, east, north; west = east mirrored), its height (px above the feet),
## colours (wood dark / light, the bowl iron), the flame's frame top-left from the staff's top.
const STAFF_X: PackedInt32Array = [11, 7, -11]
const STAFF_HEIGHT: int = 34
const STAFF_DARK: Color = Color8(0x1a, 0x17, 0x14)
const STAFF_WOOD: Color = Color8(0x40, 0x2c, 0x25)
const STAFF_BOWL: Color = Color8(0x4a, 0x42, 0x3a)
const STAFF_FLAME_AT: Vector2i = Vector2i(-2, -8)
const FLAME_FRAME_MS: int = 140
## The effect marks' lift above a heretic's (over the mitre).
const MARKS_LIFT: int = 10

static var _sheets: Dictionary[int, ImageTexture] = {}

var rig: Node2D
var body: Sprite2D
var shadow: Node2D
var staff: Node2D
var flame: Sprite2D
var flame_glow: Sprite2D
var light: PointLight2D
var marks: EffectMarks
## What is shown (tests read it).
var anim: int = HereticSim.Anim.IDLE
var frame: int = 0
var exposed: bool = false


func _init() -> void:
	name = &"Boss"
	light_mask = Config.LIGHT_LAYER_ACTORS
	shadow = Node2D.new()
	shadow.name = &"Shadow"
	shadow.draw.connect(_draw_shadow)
	add_child(shadow)
	rig = Node2D.new()
	rig.name = &"Rig"
	add_child(rig)
	staff = Node2D.new()
	staff.name = &"Staff"
	staff.light_mask = Config.LIGHT_LAYER_ACTORS
	staff.draw.connect(_draw_staff)
	rig.add_child(staff)
	body = Sprite2D.new()
	body.name = &"Body"
	body.centered = false
	body.region_enabled = true
	body.light_mask = Config.LIGHT_LAYER_ACTORS
	body.scale = Vector2(SCALE, SCALE)
	rig.add_child(body)
	flame = Sprite2D.new()
	flame.name = &"Flame"
	flame.centered = false
	flame.texture = FixtureView.HERETIC_FLAME_SMALL
	flame.hframes = FixtureView.FLAME_FRAMES
	flame.light_mask = Config.LIGHT_LAYER_ACTORS
	rig.add_child(flame)
	flame_glow = Sprite2D.new()
	flame_glow.name = &"FlameGlow"
	flame_glow.centered = false
	flame_glow.texture = FixtureView.heretic_glow_texture(false)
	flame_glow.hframes = FixtureView.FLAME_FRAMES
	flame_glow.material = FixtureView.unshaded_material()
	rig.add_child(flame_glow)
	light = TorchLight.make(Config.BOSS_FIRE_LIGHT_RADIUS_PX, Config.BOSS_FIRE_LIGHT_ENERGY, Vector2.ZERO)
	light.color = Config.HERETIC_FIRE_LIGHT_COLOR
	light.name = &"FireLight"
	add_child(light)
	marks = EffectMarks.new()
	marks.position = Vector2(0, -MARKS_LIFT)
	add_child(marks)


## The derived cell size of animation `a` (source px).
static func cell(a: int) -> int:
	return HereticSim.CELLS[a] + 2 * PAD


## Source rect of frame `f` of animation `a` in sheet row `row` of the derived sheet.
static func frame_rect(a: int, row: int, f: int) -> Rect2i:
	var c: int = cell(a)
	return Rect2i(Vector2i((HereticSim.FIRST_COLUMN[a] + f) * c, row * c), Vector2i(c, c))


## Where the derived cell's top-left goes relative to the feet (source px, before SCALE).
static func cell_offset(a: int) -> Vector2i:
	return Heretic.cell_offset(a) - Vector2i(PAD, PAD)


## Every derived sheet now (BossFightView.setup, when the dungeon's fight gets its view): the attack sheet alone takes about 110 ms to
## derive (measured, this desktop), which would hitch the boss's first attack mid-fight.
static func warm() -> void:
	for a: int in SOURCE_SHEETS.size():
		sheet(a)


## The derived sheet of animation `a` (see the class comment), cached.
static func sheet(a: int) -> ImageTexture:
	if not _sheets.has(a):
		_sheets[a] = ImageTexture.create_from_image(derived_sheet(a))
	return _sheets[a]


static func derived_sheet(a: int) -> Image:
	var src: Image = LightGen.to_rgba8(SOURCE_SHEETS[a].get_image())
	var c: int = HereticSim.CELLS[a]
	var cols: int = src.get_width() / c
	var rows: int = src.get_height() / c
	var dc: int = cell(a)
	var out: Image = Image.create_empty(cols * dc, rows * dc, false, Image.FORMAT_RGBA8)
	for r: int in rows:
		for k: int in cols:
			var cell_img: Image = Image.create_empty(dc, dc, false, Image.FORMAT_RGBA8)
			var top: int = c
			var bottom: int = -1
			for y: int in c:
				for x: int in c:
					var p: Color = src.get_pixel(k * c + x, r * c + y)
					if p.a8 == 0:
						continue
					top = mini(top, y)
					bottom = maxi(bottom, y)
					cell_img.set_pixel(PAD + x, PAD + y, recolour(p))
			if bottom >= 0 and bottom - top + 1 >= MITRE_MIN_HEIGHT:
				_stamp_mitre(cell_img, src, Vector2i(k * c, r * c), c, top)
			_outline(cell_img)
			out.blit_rect(cell_img, Rect2i(0, 0, dc, dc), Vector2i(k * dc, r * dc))
	return out


## The leader's colour for heretic pixel `p`: a neutral grey onto ROBE by its brightness, anything else (outline, eyes, the red sash, the
## knife) as it is.
static func recolour(p: Color) -> Color:
	if p.s > ROBE_MAX_SAT:
		return p
	var luma: float = LightGen.luma8(p)
	if luma < ROBE_LUMA.x or luma > ROBE_LUMA.y:
		return p
	for i: int in ROBE_BANDS.size():
		if luma <= ROBE_BANDS[i]:
			return ROBE[i]
	return p


## The mitre over the hood of the cell at `at` (source px) whose figure's top row is `top`: centred on the middle of the top three rows'
## opaque pixels.
static func _stamp_mitre(img: Image, src: Image, at: Vector2i, c: int, top: int) -> void:
	var sum: int = 0
	var n: int = 0
	for y: int in range(top, mini(top + 3, c)):
		for x: int in c:
			if src.get_pixel(at.x + x, at.y + y).a8 > 0:
				sum += x
				n += 1
	if n == 0:
		return
	var mid: int = roundi(float(sum) / n)
	var first: String = MITRE_MAP[0]
	var w: int = first.length()
	var h: int = MITRE_MAP.size()
	var left: int = PAD + mid - w / 2
	var up: int = PAD + top + MITRE_SINK - h
	for y: int in h:
		var row: String = MITRE_MAP[y]
		for x: int in row.length():
			var ch: String = row[x]
			if MITRE_COLOURS.has(ch):
				var q: Vector2i = Vector2i(left + x, up + y)
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
					img.set_pixelv(q, MITRE_COLOURS[ch])


## A second outline: every transparent pixel next to an opaque one (4 ways) takes OUTLINE.
static func _outline(img: Image) -> void:
	var ring: Array[Vector2i] = []
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a8 > 0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() and img.get_pixelv(q).a8 > 0:
					ring.append(Vector2i(x, y))
					break
	for q: Vector2i in ring:
		img.set_pixelv(q, OUTLINE)


## Shows `b` as it is now.
func show_sim(b: BossSim) -> void:
	position = b.pos.round()
	anim = b.anim()
	frame = b.frame()
	var row: int = RigData.sheet_row(b.facing)
	rig.scale = Vector2(-1.0 if RigData.is_mirrored(b.facing) else 1.0, 1.0)
	var tex: ImageTexture = sheet(anim)
	if body.texture != tex:
		body.texture = tex
	body.region_rect = Rect2(frame_rect(anim, row, frame))
	body.position = Vector2(cell_offset(anim) * SCALE)
	body.modulate = Player.HIT_FLASH if b.flash_ticks > 0 and b.alive() else Color.WHITE
	var alive: bool = b.alive()
	staff.visible = alive
	flame.visible = alive
	flame_glow.visible = alive
	light.visible = alive
	light.enabled = alive
	var sx: int = STAFF_X[row] * SCALE
	var top: Vector2 = Vector2(sx, -STAFF_HEIGHT * SCALE)
	staff.position = Vector2.ZERO
	staff.set_meta(&"x", sx)
	staff.queue_redraw()
	var f: int = (Time.get_ticks_msec() / FLAME_FRAME_MS) % FixtureView.FLAME_LOOP
	flame.frame = f
	flame_glow.frame = f
	flame.position = top + Vector2(STAFF_FLAME_AT)
	flame_glow.position = flame.position
	light.position = Vector2(sx * rig.scale.x, top.y - 4.0)
	if exposed != b.exposed():
		exposed = b.exposed()
		shadow.queue_redraw()
	var kinds: Array[int] = []
	if b.poisoned():
		kinds.append(EffectMarks.Kind.POISON)
	if b.taunted():
		kinds.append(EffectMarks.Kind.TAUNT)
	if b.stunned():
		kinds.append(EffectMarks.Kind.STUN)
	if b.slowed():
		kinds.append(EffectMarks.Kind.SLOW)
	if not alive:
		kinds.clear()
	marks.show_kinds(kinds)


func _draw_shadow() -> void:
	var c: Color = SHADOW_EXPOSED if exposed else SHADOW
	var half: Vector2 = Vector2(SHADOW_SIZE) * SCALE / 2.0
	for y: int in range(-roundi(half.y), roundi(half.y) + 1):
		var t: float = float(y) / maxf(half.y, 1.0)
		var w: int = roundi(half.x * sqrt(maxf(1.0 - t * t, 0.0)))
		shadow.draw_rect(Rect2(Vector2(-w, y - 1), Vector2(2 * w + 1, 1)), c)


func _draw_staff() -> void:
	var sx: int = staff.get_meta(&"x", 0)
	var h: int = STAFF_HEIGHT * SCALE
	var s: int = SCALE
	staff.draw_rect(Rect2(Vector2(sx - s, -h), Vector2(3 * s, h)), STAFF_DARK)
	staff.draw_rect(Rect2(Vector2(sx, -h + s), Vector2(s, h - 2 * s)), STAFF_WOOD)
	staff.draw_rect(Rect2(Vector2(sx - 3 * s, -h - 2 * s), Vector2(7 * s, 3 * s)), STAFF_DARK)
	staff.draw_rect(Rect2(Vector2(sx - 2 * s, -h - s), Vector2(5 * s, s)), STAFF_BOWL)

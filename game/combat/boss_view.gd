class_name BossView
extends Node2D
## M12a: the heretic leader's picture (combat/boss_sim.gd). M12 boss art (README "M12 보스 그림"): its own sheets, 03-pixel PixelLab 17차
## boss_leader_v02 (byte copies in art/enemies/, an adoption candidate the human has not checked yet), in place of M12a's code-drawn
## placeholder (the heretic sheets recoloured with a mitre and a second outline, a staff and a candB flame sprite drawn beside them: all
## gone, the sheet has its own staff and fire). Six sheets (BossSim.Anim): idle (asleep too), walk, hurt (the stun holds
## Config.SKILL_STUN_FRAME), death (held on its last frame), attack (the cleave) and cast (the fire volley and the burning ground), rows
## south / east / north, west = east mirrored (● R19: the rig's scale.x, as the heretics and the players). BossSim.anim() / frame() pick
## the sheet and frame; this draws them:
##   - the body: the sheet's cell on the feet (body cells BODY_CELL with the feet on the bottom row's middle, action cells ACTION_CELL
##     holding a body cell at ACTION_AT so the feet row is the same), on the actors' light layer like a heretic
##   - the fire: the sheet's own flame pixels (its _emissive mask, demon orange: ● brief §5.7 R49 the heretic-side fire) drawn once more
##     unshaded over the body (the heretic shrine's flames' way, FixtureView.heretic_glow_texture) so the brazier, the jet, the pillar and
##     the ring of fire read in the dark dungeon; and the orange point light (Config.BOSS_FIRE_LIGHT_*, HERETIC_FIRE_LIGHT_COLOR) on the
##     flame of the frame shown (the centroid of its mask pixels, mirrored west; kept where it was on a frame without fire)
##   - dead: the light goes out (as M12a); the lying frames' brazier still shows its flame pixels unshaded (an ember, no light) - IMPL
##     "M12 보스 그림 죽음", README
##   - the ground shadow (SHADOW_SIZE: the new robe's hem; ember-tinted while exposed), the hit flash on the body and its fire, the effect
##     marks (stun, slow, taunt, poison) MARKS_GAP rows over the tallest picture
## The node sits on the feet in the y-sorted entities.

## The sheets (BossSim.Anim order) and their flame masks (A=255 where a pixel burns, RGB its glow strength: the 04-env candB format).
const SHEETS: Array[Texture2D] = [
	preload("res://art/enemies/boss_leader_v02_walk.png"), preload("res://art/enemies/boss_leader_v02_idle.png"),
	preload("res://art/enemies/boss_leader_v02_attack.png"), preload("res://art/enemies/boss_leader_v02_hurt.png"),
	preload("res://art/enemies/boss_leader_v02_death.png"), preload("res://art/enemies/boss_leader_v02_cast.png"),
]
const EMISSIVE: Array[Texture2D] = [
	preload("res://art/enemies/boss_leader_v02_walk_emissive.png"), preload("res://art/enemies/boss_leader_v02_idle_emissive.png"),
	preload("res://art/enemies/boss_leader_v02_attack_emissive.png"), preload("res://art/enemies/boss_leader_v02_hurt_emissive.png"),
	preload("res://art/enemies/boss_leader_v02_death_emissive.png"), preload("res://art/enemies/boss_leader_v02_cast_emissive.png"),
]
## --- the sheets' layout (IMPL "M12 보스 그림 시트": the art step's, 03-pixel prompts.md 17차 "game/에 넘길 것") ---
## The body cell (idle, walk, hurt, death: the feet on the bottom row y 47, the body's middle line x 27.5) and the feet point in it (the
## node sits there: the bottom row is drawn just above it, the middle line half a pixel left of it, like a heretic's (16, 32) of 32).
const BODY_CELL: Vector2i = Vector2i(56, 48)
const BODY_FEET: Vector2i = Vector2i(28, 48)
## The action cell (attack, cast) and where a body cell sits in it (feet row y 53, middle line x 31.5; ten rows under the feet for the
## fire on the ground).
const ACTION_CELL: Vector2i = Vector2i(64, 64)
const ACTION_AT: Vector2i = Vector2i(4, 6)
## The tallest picture of the six sheets (px from the feet up, the walk north's hood tip; test_boss_art measures it) and the effect marks'
## gap over it (rows), their lift over a heretic's (EffectMarks.MARK_Y): the icons' bottom row MARKS_GAP rows clear of the hood.
const TALLEST_PX: int = 45
const MARKS_GAP: int = 2
const MARKS_LIFT: int = TALLEST_PX + MARKS_GAP + EffectMarks.MARK_Y + EffectMarks.SIZE
## A mask pixel at least this opaque burns (FixtureView's rule).
const GLOW_MIN_ALPHA: int = 128
## The ground shadow (an ellipse of SHADOW_SIZE under the feet: the robe's hem is 20-26 px wide, its body 26-27) and its tint while exposed.
const SHADOW_SIZE: Vector2i = Vector2i(28, 7)
const SHADOW: Color = Color(0.06, 0.05, 0.04, 0.6)
const SHADOW_EXPOSED: Color = Color(0.70, 0.22, 0.06, 0.7)
## The HUD boss bar's icon (Hud.show_boss: M12a's placeholder mitre, kept as it was: the sheet's leader wears a tall pointed hood; README
## "M12 보스 그림" known issues). Rows top first: "k" outline, "d" clotted blood, "b" blood, "g" gold, "F" demon orange, "." nothing.
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

## Per sheet: its glow texture (the sheet's pixels where the mask burns, the same layout) and, per frame (row x columns + column), the
## flame's middle from the feet (unmirrored, whole px) or NO_FIRE.
static var _glows: Dictionary[int, ImageTexture] = {}
static var _fire: Dictionary[int, PackedVector2Array] = {}
const NO_FIRE: Vector2 = Vector2(INF, INF)

var rig: Node2D
var body: Sprite2D
var glow: Sprite2D
var shadow: Node2D
var light: PointLight2D
var marks: EffectMarks
## What is shown (tests read it).
var anim: int = BossSim.Anim.IDLE
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
	body = Sprite2D.new()
	body.name = &"Body"
	body.centered = false
	body.region_enabled = true
	body.light_mask = Config.LIGHT_LAYER_ACTORS
	rig.add_child(body)
	glow = Sprite2D.new()
	glow.name = &"Glow"
	glow.centered = false
	glow.region_enabled = true
	glow.material = FixtureView.unshaded_material()
	rig.add_child(glow)
	light = TorchLight.make(Config.BOSS_FIRE_LIGHT_RADIUS_PX, Config.BOSS_FIRE_LIGHT_ENERGY, Vector2.ZERO)
	light.color = Config.HERETIC_FIRE_LIGHT_COLOR
	light.name = &"FireLight"
	add_child(light)
	marks = EffectMarks.new()
	marks.position = Vector2(0, -MARKS_LIFT)
	add_child(marks)


## The cell size of sheet `a` (BossSim.Anim).
static func cell(a: int) -> Vector2i:
	return ACTION_CELL if is_action(a) else BODY_CELL


static func is_action(a: int) -> bool:
	return a == BossSim.Anim.ATTACK or a == BossSim.Anim.CAST


## The feet point in a cell of sheet `a`.
static func feet_in_cell(a: int) -> Vector2i:
	return BODY_FEET + ACTION_AT if is_action(a) else BODY_FEET


## Where a cell's top-left goes relative to the feet.
static func cell_offset(a: int) -> Vector2i:
	return -feet_in_cell(a)


## The columns of sheet `a` (the start picture's column, then its frames).
static func columns(a: int) -> int:
	return BossSim.FIRST_COLUMN[a] + BossSim.FRAME_COUNTS[a]


## Source rect of frame `f` (played frame) of sheet `a` in sheet row `row`.
static func frame_rect(a: int, row: int, f: int) -> Rect2i:
	var c: Vector2i = cell(a)
	return Rect2i(Vector2i((BossSim.FIRST_COLUMN[a] + f) * c.x, row * c.y), c)


## Every glow texture and flame point now (BossFightView.setup, when the dungeon's fight gets its view: 22-27 ms of pixel loops measured
## headless on this desktop, which would hitch the boss's first frame mid-fight).
static func warm() -> void:
	for a: int in SHEETS.size():
		glow_texture(a)


## Sheet `a`'s glow: its pixels where its mask burns, nothing else (cached).
static func glow_texture(a: int) -> ImageTexture:
	if not _glows.has(a):
		_build(a)
	return _glows[a]


## The flame's middle in frame `f` of sheet `a`, row `row`, from the feet (whole px, unmirrored), or NO_FIRE.
static func fire_point(a: int, row: int, f: int) -> Vector2:
	if not _fire.has(a):
		_build(a)
	return _fire[a][row * BossSim.FRAME_COUNTS[a] + f]


static func _build(a: int) -> void:
	var lit: Image = LightGen.to_rgba8(SHEETS[a].get_image())
	var em: Image = LightGen.to_rgba8(EMISSIVE[a].get_image())
	var out: Image = Image.create_empty(lit.get_width(), lit.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in lit.get_height():
		for x: int in lit.get_width():
			if em.get_pixel(x, y).a8 >= GLOW_MIN_ALPHA:
				out.set_pixel(x, y, lit.get_pixel(x, y))
	_glows[a] = ImageTexture.create_from_image(out)
	var points: PackedVector2Array = PackedVector2Array()
	var feet: Vector2i = feet_in_cell(a)
	for row: int in RigData.ROWS:
		for f: int in BossSim.FRAME_COUNTS[a]:
			var r: Rect2i = frame_rect(a, row, f)
			var sum: Vector2 = Vector2.ZERO
			var n: int = 0
			for y2: int in range(r.position.y, r.end.y):
				for x2: int in range(r.position.x, r.end.x):
					if em.get_pixel(x2, y2).a8 >= GLOW_MIN_ALPHA:
						sum += Vector2(x2 - r.position.x, y2 - r.position.y) + Vector2(0.5, 0.5)
						n += 1
			points.append(NO_FIRE if n == 0 else (sum / n - Vector2(feet)).round())
	_fire[a] = points


## Shows `b` as it is now.
func show_sim(b: BossSim) -> void:
	position = b.pos.round()
	anim = b.anim()
	frame = b.frame()
	var row: int = RigData.sheet_row(b.facing)
	var mirror: float = -1.0 if RigData.is_mirrored(b.facing) else 1.0
	rig.scale = Vector2(mirror, 1.0)
	if body.texture != SHEETS[anim]:
		body.texture = SHEETS[anim]
		glow.texture = glow_texture(anim)
	var r: Rect2 = Rect2(frame_rect(anim, row, frame))
	body.region_rect = r
	glow.region_rect = r
	body.position = Vector2(cell_offset(anim))
	glow.position = body.position
	var alive: bool = b.alive()
	body.modulate = Player.HIT_FLASH if b.flash_ticks > 0 and alive else Color.WHITE
	glow.modulate = body.modulate
	light.visible = alive
	light.enabled = alive
	var at: Vector2 = fire_point(anim, row, frame)
	if at != NO_FIRE:
		light.position = Vector2(at.x * mirror, at.y)
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
	var half: Vector2 = Vector2(SHADOW_SIZE) / 2.0
	for y: int in range(-roundi(half.y), roundi(half.y) + 1):
		var t: float = float(y) / maxf(half.y, 1.0)
		var w: int = roundi(half.x * sqrt(maxf(1.0 - t * t, 0.0)))
		shadow.draw_rect(Rect2(Vector2(-w, y - 1), Vector2(2 * w + 1, 1)), c)

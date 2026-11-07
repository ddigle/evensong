class_name CreatureView
extends Node2D
## The picture of one creature (combat/creature_sim.gd, M11a). PLACEHOLDER drawn in code: no creature art exists (the human has
## not approved generating any), so every kind is a set of character maps here, the one data-driven place: south, east and north
## per kind (MAPS, west = east mirrored by the Rig's scale.x = -1, ● R19 as for the players), a second walk frame (STEPS: the leg
## rows that change) and a palette (PALETTE: warm browns, the brief §4 ash black outline). A sprite sheet replaces them later by
## changing image() alone. The node sits on the feet so the y-sorted Entities sorts it with the characters; the light layer is the
## actors' (hard), like a heretic.
##
## Shows: the walk (the second frame every CreatureSim.WALK_FRAME_TICKS, a px of bob), the hit flash and the HP bar once hurt (the
## heretic's colours and rule, Heretic.bar_fill; drawn in code, unshaded), the marks of a poison, a stun or a slow (EffectMarks) and
## the corpse (the picture upside down, legs up).

## The palette of the maps (ItemIcons.PALETTE's outline; brown, silver and ash ramps of their own, warm like the brief §4 base row;
## the fox's copper and the lamp gold are ItemIcons' 04-env copper and faith gold).
const PALETTE: Dictionary[String, Color] = {
	"k": Color8(0x1a, 0x17, 0x14),  # outline (§4 base)
	"B": Color8(0x4a, 0x33, 0x22),  # deep brown (hooves)
	"N": Color8(0x6f, 0x4a, 0x2c),  # brown dark
	"T": Color8(0x96, 0x67, 0x3a),  # brown
	"L": Color8(0xb9, 0x8a, 0x56),  # tan
	"C": Color8(0xdc, 0xc4, 0x9a),  # cream
	"O": Color8(0x8c, 0x4a, 0x22),  # copper dark
	"F": Color8(0xc0, 0x6a, 0x2e),  # copper
	"H": Color8(0xdf, 0x90, 0x3f),  # copper light
	"G": Color8(0xf4, 0xc9, 0x5d),  # faith gold
	"I": Color8(0xef, 0xe3, 0xc6),  # ivory
	"S": Color8(0x8f, 0x89, 0x7e),  # silver dark
	"M": Color8(0xb9, 0xb3, 0xa6),  # silver
	"W": Color8(0xdc, 0xd6, 0xc6),  # silver light
	"A": Color8(0x3b, 0x35, 0x30),  # ash dark
	"D": Color8(0x5c, 0x53, 0x4b),  # ash
	"E": Color8(0x85, 0x7a, 0x6e),  # ash light
	"R": Color8(0xa3, 0x49, 0x2c),  # rust (noses, beaks)
}

## [south, east, north] maps per kind: rows of one length, the last row on the ground, feet = bottom middle. Plain Arrays on purpose
## (ItemIcons.MAPS: a const Dictionary of PackedStringArray reads back garbage in Godot 4.7.2).
const MAPS: Dictionary[StringName, Array] = {
	&"hare": [
		[
			"..kk...kk..",
			".kLTk.kTLk.",
			".kLTk.kTLk.",
			".kLTkkkTLk.",
			"..kTTTTTk..",
			".kTkTTTkTk.",
			".kTTTRTTTk.",
			"..kTCCCTk..",
			".kTTCCCTTk.",
			".kTTCCCTTk.",
			".kTTTTTTTk.",
			"..kNk.kNk..",
			"...k...k...",
		],
		[
			"..........kk...",
			".........kLTk..",
			"........kLTk...",
			"......kkkTTkk..",
			".....kTTTTkTTk.",
			"..kkkTTTTTTTTRk",
			".kCTTTTTTTTTkk.",
			"kCCTTTTTTTTk...",
			"kCCTTLTTTTk....",
			".kkTLLkTTTk....",
			"..kNNk.kNNk....",
			"...kk...kk.....",
		],
		[
			"..kk...kk..",
			".kTTk.kTTk.",
			".kTTk.kTTk.",
			".kTTkkkTTk.",
			"..kTTTTTk..",
			".kTTTTTTTk.",
			".kTTTTTTTk.",
			".kTTTTTTTk.",
			".kTTLLLTTk.",
			".kTLCCCLTk.",
			".kTTCCCTTk.",
			"..kNk.kNk..",
			"...k...k...",
		],
	],
	&"deer": [
		[
			"..k.k...k.k..",
			".kLkLk.kLkLk.",
			"..kLLk.kLLk..",
			"...kLkkkLk...",
			"kkk.kTTTk.kkk",
			"kTTkkTTTkkTTk",
			".kkkTkTkTkkk.",
			"....kTTTk....",
			"....kTRTk....",
			".....kkk.....",
			"....kTTTk....",
			"...kTCCCTk...",
			"..kTTCCCTTk..",
			"..kTTCCCTTk..",
			"..kTTTTTTTk..",
			"..kTTTTTTTk..",
			"..kTk...kTk..",
			"..kNk...kNk..",
			"..kNk...kNk..",
			"..kNk...kNk..",
			"..kNk...kNk..",
			"..kBk...kBk..",
			"..kBk...kBk..",
			"..kkk...kkk..",
		],
		[
			"................k.k.k...",
			"...............kLkLkLk..",
			"................kLLLk...",
			".................kLk.k..",
			"................kTTkkTk.",
			"................kTTTTk..",
			"...............kTTTTTTk.",
			"...............kTTkTTTRk",
			"...............kTTTTTkk.",
			"..............kTTTTkk...",
			"....kkkkkkkkkkTTTTk.....",
			"..kkTTTTTTTTTTTTTk......",
			".kCTTTTTTTTTTTTTTTk.....",
			".kCTTLLLLLLLLTTTTTk.....",
			".kCTTTTTTTTTTTTTTTk.....",
			"..kTTTTTTTTTTTTTTk......",
			"..kTTkkkkkkkkkTTTk......",
			"..kNTk.......kNTk.......",
			"..kNk.........kNk.......",
			"..kNk.........kNk.......",
			"..kNk.........kNk.......",
			"..kBk.........kBk.......",
			"..kBk.........kBk.......",
			"..kkk.........kkk.......",
		],
		[
			"..k.k...k.k..",
			".kLkLk.kLkLk.",
			"..kLLk.kLLk..",
			"...kLkkkLk...",
			"kkk.kTTTk.kkk",
			"kTTkkTTTkkTTk",
			".kkkTTTTTkkk.",
			"....kTTTk....",
			"....kTTTk....",
			".....kTk.....",
			"....kTTTk....",
			"...kTTTTTk...",
			"..kTTTTTTTk..",
			"..kTTTTTTTk..",
			"..kTTCCCTTk..",
			"..kTCCCCCTk..",
			"..kTk...kTk..",
			"..kNk...kNk..",
			"..kNk...kNk..",
			"..kNk...kNk..",
			"..kNk...kNk..",
			"..kBk...kBk..",
			"..kBk...kBk..",
			"..kkk...kkk..",
		],
	],
	&"lamp_fox": [
		[
			"..k.......k..",
			".kFk.....kFk.",
			".kFFkkkkkFFk.",
			".kFFFFFFFFFk.",
			"..kFkFFFkFk..",
			"..kCCFRFCCk..",
			"...kCCCCCk...",
			"....kkkkk....",
			"...kFCCCFk...",
			"..kFFCCCFFk..",
			"..kFFCCCFFk..",
			"..kOk...kOk..",
			"..kOk...kOk..",
			"..kk.....kk..",
		],
		[
			"..............k.k...",
			".............kFkFk..",
			".............kFFFk..",
			"kk..........kFFkFFk.",
			"kGk.........kFFFFFRk",
			"kGGk...kkkkkkFFCCkk.",
			".kHHk.kFFFFFFFFCk...",
			".kHFFkFFFFFFFFFk....",
			"..kFFFFFFFFFFFFk....",
			"...kkFFFFFFFFFk.....",
			".....kFFCCFFFFk.....",
			".....kOk.kk.kOk.....",
			".....kOk....kOk.....",
			".....kk.....kk......",
		],
		[
			"..k.......k..",
			".kFk.....kFk.",
			".kFFkkkkkFFk.",
			".kFFFFFFFFFk.",
			"..kFFFFFFFk..",
			"...kFFFFFk...",
			"....kkkkk....",
			"...kFFFFFk...",
			"..kFFkGkFFk..",
			"..kFFkGkFFk..",
			"..kFFkHkFFk..",
			"..kOkkkkkOk..",
			"..kOk...kOk..",
			"..kk.....kk..",
		],
	],
	&"silver_stag": [
		[
			"k...k.....k...k",
			"kW.kWk...kWk.Wk",
			".kWkWk...kWkWk.",
			".kWWWk...kWWWk.",
			"..kkWk...kWkk..",
			"...kWkkkkkWk...",
			".kkk.kMMMk.kkk.",
			".kMMkkMMMkkMMk.",
			"..kkkMkMkMkkk..",
			".....kMMMk.....",
			".....kMSMk.....",
			"......kkk......",
			".....kMMMk.....",
			"....kMWWWMk....",
			"...kMMWWWMMk...",
			"...kMMWWWMMk...",
			"...kMMMMMMMk...",
			"...kMMMMMMMk...",
			"...kMk...kMk...",
			"...kSk...kSk...",
			"...kSk...kSk...",
			"...kSk...kSk...",
			"...kSk...kSk...",
			"...kAk...kAk...",
			"...kAk...kAk...",
			"...kkk...kkk...",
		],
		[
			"..............k...k.k.....",
			"..............kW.kWkWk....",
			"...............kWkWWk.....",
			"................kWWk.k....",
			".................kWkkWk...",
			"................kWMkWk....",
			".................kMMMk....",
			"................kMMMMkkMk.",
			"................kMMMMMMk..",
			"...............kMMMMMMMMk.",
			"...............kMMkMMMMSk.",
			"...............kMMMMMMkk..",
			"..............kMMMMkk.....",
			"....kkkkkkkkkkMMMMk.......",
			"..kkMMMMMMMMMMMMMk........",
			".kWMMMMMMMMMMMMMMMk.......",
			".kWMMWWWWWWWWMMMMMk.......",
			".kWMMMMMMMMMMMMMMMk.......",
			"..kMMMMMMMMMMMMMMk........",
			"..kMMkkkkkkkkkMMMk........",
			"..kSMk.......kSMk.........",
			"..kSk.........kSk.........",
			"..kSk.........kSk.........",
			"..kAk.........kAk.........",
			"..kAk.........kAk.........",
			"..kkk.........kkk.........",
		],
		[
			"k...k.....k...k",
			"kW.kWk...kWk.Wk",
			".kWkWk...kWkWk.",
			".kWWWk...kWWWk.",
			"..kkWk...kWkk..",
			"...kWkkkkkWk...",
			".kkk.kMMMk.kkk.",
			".kMMkkMMMkkMMk.",
			"..kkkMMMMMkkk..",
			".....kMMMk.....",
			".....kMMMk.....",
			"......kMk......",
			".....kMMMk.....",
			"....kMMMMMk....",
			"...kMMMMMMMk...",
			"...kMMMMMMMk...",
			"...kMMWWWMMk...",
			"...kMWWWWWMk...",
			"...kMk...kMk...",
			"...kSk...kSk...",
			"...kSk...kSk...",
			"...kSk...kSk...",
			"...kSk...kSk...",
			"...kAk...kAk...",
			"...kAk...kAk...",
			"...kkk...kkk...",
		],
	],
	&"ash_owl": [
		[
			"...kk....kk...",
			"..kAAkkkkAAk..",
			"..kAAAAAAAAk..",
			".kAGGkAAkGGAk.",
			".kAGkGAAGkGAk.",
			".kAAAARRAAAAk.",
			".kDAAAAAAAADk.",
			"kDDkEDEDEDkDDk",
			"kDDkDEDEDEkDDk",
			"kDDkEDEDEDkDDk",
			"kAAkDEDEDEkAAk",
			".kkkEDEDEDkkk.",
			"...kDEDEDEk...",
			"....kkkkkk....",
			"....kGk.kGk...",
			"....kk...kk...",
		],
		[
			"...kk........",
			"..kAAkkkk....",
			"..kAAAAAAk...",
			".kAAAAkGGk...",
			".kAAAAGkGk...",
			".kAAAAAAARk..",
			".kDDAAAAAk...",
			"kDDDDAEDEk...",
			"kDDDDDDEDk...",
			"kDDDDDEDEk...",
			"kADDDDDEDk...",
			"kAADDDEDEk...",
			".kkADDDEk....",
			"...kkkkk.....",
			"....kGk......",
			"....kk.......",
		],
		[
			"...kk....kk...",
			"..kAAkkkkAAk..",
			"..kAAAAAAAAk..",
			".kAAAAAAAAAAk.",
			".kAAAAAAAAAAk.",
			".kAAAAAAAAAAk.",
			".kDAAAAAAAADk.",
			"kDDDDDDDDDDDDk",
			"kDDDEDDDDEDDDk",
			"kDDDDEDDEDDDDk",
			"kADDDDEEDDDDAk",
			".kkDDDDDDDDkk.",
			"...kDDDDDDk...",
			"....kkkkkk....",
			"....kGk.kGk...",
			"....kk...kk...",
		],
	],
}
## The second walk frame: the bottom rows of the [south, east, north] maps that change (they replace as many rows from the bottom).
const STEPS: Dictionary[StringName, Array] = {
	&"hare": [
		["...k.kNk...", ".......k..."],
		["...kNk.kNk.....", "....kk...kk...."],
		["..kNk.k....", "...k......."],
	],
	&"deer": [
		["..kNk...kNk..", "..kBk...kNk..", "..kBk...kNk..", "..kkk...kBk..", ".........kBk.", ".........kkk."],
		["...kNk.....kNk.........", "...kNk.....kNk.........", "....kNk...kNk..........", "....kBk...kBk..........",
			"....kBk...kBk..........", "....kkk...kkk.........."],
		["..kNk...kNk..", "..kNk...kBk..", "..kNk...kBk..", "..kBk...kkk..", "..kBk........", "..kkk........"],
	],
	&"lamp_fox": [
		["..kk.....kOk.", ".........kk.."],
		[".......kOk.kOk......", ".......kk...kk......"],
		["..kOk.....kk.", "..kk........."],
	],
	&"silver_stag": [
		["...kSk...kSk...", "...kAk...kSk...", "...kkk...kAk...", "..........kAk..", "..........kkk.."],
		["...kSk.....kSk...........", "....kSk...kSk.............", "....kAk...kAk.............",
			"....kAk...kAk.............", "....kkk...kkk............."],
		["...kSk...kSk...", "...kSk...kAk...", "...kAk...kkk...", "...kAk.........", "...kkk........."],
	],
	&"ash_owl": [
		["....kGk.......", "....kk........"],
		[".....kGk.....", ".....kk......"],
		[".........kGk..", ".........kk..."],
	],
}
## IMPL: HP bar height and how far above the picture's top row it sits, and the gap between the picture (or the bar) and the marks.
const BAR_HEIGHT: int = 2
const BAR_GAP: int = 2
const MARK_GAP: int = 6

static var _textures: Dictionary[String, ImageTexture] = {}

var rig: Node2D
var body: Sprite2D
var bar: Node2D
var marks: EffectMarks
var sim_id: int = 0
## What is shown (tests read it).
var kind: StringName = &""
var row: int = 0
var frame: int = 0
var hp_ratio: float = 1.0
var _bar_top: int = 0


func _init() -> void:
	rig = Node2D.new()
	rig.name = &"Rig"
	add_child(rig)
	body = Sprite2D.new()
	body.name = &"Body"
	body.centered = false
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


## The rows of `k` in sheet row `r` (RigData.sheet_row: 0 south, 1 east, 2 north), walk frame `f` (0, 1).
static func rows_of(k: StringName, r: int, f: int) -> Array:
	var base: Array = MAPS[k][r]
	if f == 0:
		return base
	var out: Array = base.duplicate()
	var legs: Array = STEPS[k][r]
	for i: int in legs.size():
		var at: int = out.size() - legs.size() + i
		var line: String = legs[i]
		var was: String = out[at]
		out[at] = line + was.substr(line.length())
	return out


## The picture of `k` in sheet row `r`, walk frame `f`. Replace this (and frame_size) with a sheet's region when art exists.
static func image(k: StringName, r: int, f: int) -> Image:
	var rows: Array = rows_of(k, r, f)
	var first: String = rows[0]
	var img: Image = Image.create_empty(first.length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		var line: String = rows[y]
		for x: int in line.length():
			var ch: String = line[x]
			if PALETTE.has(ch):
				img.set_pixel(x, y, PALETTE[ch])
	return img


static func texture(k: StringName, r: int, f: int) -> ImageTexture:
	var key: String = "%s/%d/%d" % [k, r, f]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(image(k, r, f))
	return _textures[key]


## The picture's size of `k` in sheet row `r`.
static func frame_size(k: StringName, r: int) -> Vector2i:
	var rows: Array = MAPS[k][r]
	var first: String = rows[0]
	return Vector2i(first.length(), rows.size())


## How tall the picture of `k` stands: the tallest of its three.
static func height_of(k: StringName) -> int:
	var h: int = 0
	for r: int in 3:
		h = maxi(h, frame_size(k, r).y)
	return h


## Where the picture's top-left goes relative to the feet: bottom middle on the feet. A corpse lies on the same box, turned.
static func picture_offset(k: StringName, r: int) -> Vector2i:
	var s: Vector2i = frame_size(k, r)
	return Vector2i(-s.x / 2, -s.y)


func show_sim(c: CreatureSim) -> void:
	sim_id = c.id
	kind = c.kind
	position = c.pos.round()
	row = RigData.sheet_row(c.facing)
	frame = c.frame()
	rig.scale = Vector2(-1.0 if RigData.is_mirrored(c.facing) else 1.0, 1.0)
	var tex: ImageTexture = texture(kind, row, frame)
	if body.texture != tex:
		body.texture = tex
	body.flip_v = not c.alive()
	body.position = Vector2(picture_offset(kind, row)) - Vector2(0.0, 1.0 if frame == 1 else 0.0)
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
	marks.show_kinds(kinds)
	marks.position = Vector2(0.0, top - MARK_GAP - EffectMarks.SIZE - EffectMarks.MARK_Y)


func _draw_bar() -> void:
	var w: int = Heretic.BAR_SIZE.x
	var left: Vector2 = Vector2(-w / 2 - 1, _bar_top)
	bar.draw_rect(Rect2(left, Vector2(w + 2, BAR_HEIGHT + 2)), Heretic.BAR_BACK)
	bar.draw_rect(Rect2(left + Vector2.ONE, Vector2(Heretic.bar_fill(hp_ratio), BAR_HEIGHT)), Heretic.BAR_FILL)

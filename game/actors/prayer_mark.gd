class_name PrayerMark
extends Node2D
## M10a: the prayer's marks over a player's head (PLACEHOLDERS drawn in code from character maps in the ItemIcons palette: no art
## exists for them, and the stage 5 prayer screen waits for the faith symbol). Main sets them every tick from the prayer
## (items/prayer.gd):
##   TURN      the direction the player must enter now (its turn's window open): a faith-gold arrow over the head, seen by the
##             others (the player itself sees the larger one on its HUD, Hud.show_prayer_prompt)
##   JOINED    a participant who just joined: a small gold ring (the prayer circle's), for Config.PRAYER_JOINED_MARK_TICKS
##   LEFT      a participant who left (hit, quit): the same ring in iron grey, for Config.PRAYER_LEFT_MARK_TICKS
##   MEDITATE  meditating: the gold ring and a progress bar over it (ivory over ash black)
## Rings and arrows, not flames: a player standing just south of the altar has them over the altar's lamps. Unshaded so they read
## in the evening. The node is a child of the Player (on the feet); the marks sit just above the head, in the effect marks' rows
## (EffectMarks.MARK_Y), and RAISE higher while the player shows effect marks. Layout values are IMPL.

enum Kind { NONE, JOINED, TURN, LEFT, MEDITATE }

## The arrow pointing up (W); the other three are it turned (arrow_image).
const ARROW_MAP: PackedStringArray = [
	"....k....",
	"...kgk...",
	"..kgggk..",
	".kgggggk.",
	"kkkgggkkk",
	"..kgggk..",
	"..kgggk..",
	"..kgggk..",
	"..kkkkk..",
]
const RING_MAP: PackedStringArray = [
	".kkk.",
	"kgggk",
	"kg.gk",
	"kgggk",
	".kkk.",
]
## Top of the arrow and of the ring above the feet (the effect marks' rows, EffectMarks.MARK_Y: just above the head); the meditation
## bar's row (over the ring); the bar's width; how much higher all of it goes while the player shows effect marks (above them).
const ARROW_Y: int = -45
const RING_Y: int = -43
const BAR_Y: int = -45
const RAISE: int = 14
const BAR_W: int = 7
const BAR_BACK: Color = Color8(0x1a, 0x17, 0x14)
const BAR_FILL: Color = Color8(0xef, 0xe3, 0xc6)
## The left ring's colour in place of gold (iron).
const LEFT_SWAP: Dictionary[String, String] = {"g": "m"}

static var _arrows: Array[ImageTexture] = []
static var _ring: ImageTexture
static var _left_ring: ImageTexture

## What is shown (tests read it): the kind, the arrow's direction (Prayer.Dir), the bar's lit px (0..BAR_W), raised.
var kind: int = Kind.NONE
var dir: int = -1
var fill: int = 0
var raised: bool = false


func _init() -> void:
	name = &"PrayerMark"
	material = FixtureView.unshaded_material()
	light_mask = Config.LIGHT_LAYER_ACTORS
	visible = false


static func _image(rows: PackedStringArray, swap: Dictionary[String, String] = {}) -> Image:
	var w: int = rows[0].length()
	var img: Image = Image.create_empty(w, rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in w:
			var ch: String = swap.get(row[x], row[x])
			if ItemIcons.PALETTE.has(ch):
				img.set_pixel(x, y, ItemIcons.PALETTE[ch])
	return img


## The arrow for direction `d` (Prayer.Dir: up, left, down, right), the up map turned.
static func arrow_image(d: int) -> Image:
	var up: Image = _image(ARROW_MAP)
	var n: int = up.get_width()
	var img: Image = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y: int in n:
		for x: int in n:
			var src: Vector2i = Vector2i(x, y)
			match d:
				Prayer.Dir.LEFT:
					src = Vector2i(y, x)
				Prayer.Dir.DOWN:
					src = Vector2i(x, n - 1 - y)
				Prayer.Dir.RIGHT:
					src = Vector2i(y, n - 1 - x)
			img.set_pixelv(Vector2i(x, y), up.get_pixelv(src))
	return img


static func arrow_texture(d: int) -> ImageTexture:
	if _arrows.is_empty():
		for k: int in 4:
			_arrows.append(ImageTexture.create_from_image(arrow_image(k)))
	return _arrows[clampi(d, 0, 3)]


static func ring_image(left: bool) -> Image:
	if left:
		return _image(RING_MAP, LEFT_SWAP)
	return _image(RING_MAP)


static func ring_texture(left: bool) -> ImageTexture:
	if _ring == null:
		_ring = ImageTexture.create_from_image(ring_image(false))
		_left_ring = ImageTexture.create_from_image(ring_image(true))
	return _left_ring if left else _ring


## Top-left (relative to the feet) of the arrow / the ring; the bar's left end; `raised_up`: above the effect marks.
static func arrow_at(raised_up: bool = false) -> Vector2i:
	return Vector2i(-ARROW_MAP[0].length() / 2, ARROW_Y - (RAISE if raised_up else 0))


static func ring_at(raised_up: bool = false) -> Vector2i:
	return Vector2i(-RING_MAP[0].length() / 2, RING_Y - (RAISE if raised_up else 0))


static func bar_at(raised_up: bool = false) -> Vector2i:
	return Vector2i(-BAR_W / 2, BAR_Y - (RAISE if raised_up else 0))


## The meditation bar's lit px for `ticks` of Config.MEDITATE_TICKS (at least 1 once begun).
static func bar_fill(ticks: int) -> int:
	if ticks <= 0:
		return 0
	return clampi(ceili(float(ticks) / Config.MEDITATE_TICKS * BAR_W), 1, BAR_W)


## Shows mark `k` (TURN: with direction `d`; MEDITATE: `bar` px lit); `up` = above the effect marks (the player shows some).
func show_mark(k: int, d: int = -1, bar: int = 0, up: bool = false) -> void:
	if k == kind and d == dir and bar == fill and up == raised:
		return
	kind = k
	dir = d
	fill = bar
	raised = up
	visible = k != Kind.NONE
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.TURN:
			draw_texture(arrow_texture(dir), Vector2(arrow_at(raised)))
		Kind.JOINED, Kind.LEFT:
			draw_texture(ring_texture(kind == Kind.LEFT), Vector2(ring_at(raised)))
		Kind.MEDITATE:
			draw_texture(ring_texture(false), Vector2(ring_at(raised)))
			var at: Vector2i = bar_at(raised)
			draw_rect(Rect2(Vector2(at), Vector2(BAR_W, 1)), BAR_BACK)
			if fill > 0:
				draw_rect(Rect2(Vector2(at), Vector2(fill, 1)), BAR_FILL)

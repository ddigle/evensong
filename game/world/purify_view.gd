class_name PurifyView
extends Node2D
## M5b: what purification looks like (PLACEHOLDERS: no purification art exists; drawn in code and from 04-env decals).
##   Ash    for each purified tile, an ash smear (04-env decal_ashcreep_1..3, the grass-side ash smears) on the tile for
##          Config.PURIFY_ASH_TICKS: the world is grass at once (items/purify.gd), the screen shows the ash going away.
##          On the ground's light layer (the evening darkens it like the ground).
##   Glow   unshaded (it reads in the dark, like the thrown bottle): a gold outline on each purified tile that shrinks a
##          pixel per Config.PURIFY_FLASH_TICKS / 8 ticks and is gone after Config.PURIFY_FLASH_TICKS; and for each
##          channel under way Config.PURIFY_MOTES gold motes (2x2) on a ring at the radius it will purify, one more lit
##          per 1 / PURIFY_MOTES of the channel (its progress).
## GameWorld puts it above the decals, below the entities (characters cover it). Ages advance one per physics tick
## (`auto_tick`; tests advance() by hand). The rules for the pixels are the static functions below.

const ASH_PATHS: PackedStringArray = ["res://art/env/decal_ashcreep_1_v01.png", "res://art/env/decal_ashcreep_2_v01.png",
	"res://art/env/decal_ashcreep_3_v01.png"]
const GOLD: Color = Color8(0xf4, 0xc9, 0x5d)   # brief §4 faith gold
const IVORY: Color = Color8(0xef, 0xe3, 0xc6)  # brief §4 ivory (the motes' lit centre pixel)
const MOTE: int = 2

static var _ash: Array[Texture2D] = []

## A purified tile being shown: its tile and age (ticks since it was purified).
class Flash:
	extends RefCounted
	var cell: Vector2i
	var age: int = 0
	var ash: Sprite2D


## A channel under way: its centre tile and ticks so far (PlayerSim.channel_tick).
class Channel:
	extends RefCounted
	var centre: Vector2i
	var ticks: int = 0

	func _init(p_centre: Vector2i = Vector2i.ZERO, p_ticks: int = 0) -> void:
		centre = p_centre
		ticks = p_ticks


var auto_tick: bool = true
var flashes: Array[Flash] = []
var channels: Array[Channel] = []
var ash_layer: Node2D
var glow: GlowDraw


## The unshaded drawing (a child so the ash smears keep the ground's light).
class GlowDraw:
	extends Node2D
	var view: PurifyView

	func _draw() -> void:
		for f: PurifyView.Flash in view.flashes:
			for p: Vector2i in PurifyView.flash_pixels(f.age):
				draw_rect(Rect2(Vector2(f.cell * Config.TILE + p), Vector2.ONE), PurifyView.GOLD)
		for ch: PurifyView.Channel in view.channels:
			var pts: Array[Vector2i] = PurifyView.mote_points(ch.centre)
			var lit: int = PurifyView.motes_lit(ch.ticks)
			for i: int in lit:
				draw_rect(Rect2(Vector2(pts[i]), Vector2(PurifyView.MOTE, PurifyView.MOTE)), PurifyView.GOLD)
				draw_rect(Rect2(Vector2(pts[i]), Vector2.ONE), PurifyView.IVORY)


func _init() -> void:
	name = &"Purify"
	ash_layer = Node2D.new()
	ash_layer.name = &"Ash"
	add_child(ash_layer)
	glow = GlowDraw.new()
	glow.name = &"Glow"
	glow.view = self
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = mat
	add_child(glow)


func _physics_process(_delta: float) -> void:
	if auto_tick:
		advance(1)


## Shows `cells` as just purified.
func flash(cells: Array[Vector2i]) -> void:
	for c: Vector2i in cells:
		var f: Flash = Flash.new()
		f.cell = c
		var tex: Texture2D = ash_texture(ash_index(c))
		var s: Sprite2D = Sprite2D.new()
		s.name = StringName("Ash_%d_%d" % [c.x, c.y])
		s.texture = tex
		s.centered = false
		s.position = Vector2(c * Config.TILE + ash_offset(ash_index(c)))
		s.light_mask = Config.LIGHT_LAYER_WORLD
		ash_layer.add_child(s)
		f.ash = s
		flashes.append(f)
	glow.queue_redraw()


## The channels under way now (Main sets them every tick from the players).
func show_channels(list: Array[Channel]) -> void:
	channels = list
	glow.queue_redraw()


## `n` ticks pass: flashes age, the ash goes after Config.PURIFY_ASH_TICKS.
func advance(n: int) -> void:
	if flashes.is_empty():
		return
	var keep: Array[Flash] = []
	for f: Flash in flashes:
		f.age += n
		if f.age >= Config.PURIFY_ASH_TICKS:
			if is_instance_valid(f.ash):
				f.ash.get_parent().remove_child(f.ash)
				f.ash.free()
			continue
		keep.append(f)
	flashes = keep
	glow.queue_redraw()


func clear() -> void:
	advance(Config.PURIFY_ASH_TICKS)
	channels.clear()
	glow.queue_redraw()


## Which of the three ash smears tile `c` shows (a hash of the tile: the same tile, the same smear).
static func ash_index(c: Vector2i) -> int:
	return posmod(c.x * 7 + c.y * 13, ASH_PATHS.size())


static func ash_texture(i: int) -> Texture2D:
	if _ash.is_empty():
		for p: String in ASH_PATHS:
			_ash.append(load(p) as Texture2D)
	return _ash[i]


## Where smear `i` sits in its tile (centred, whole pixels).
static func ash_offset(i: int) -> Vector2i:
	var size: Vector2i = Vector2i(ash_texture(i).get_size())
	return (Vector2i(Config.TILE, Config.TILE) - size) / 2


## The gold pixels (inside the tile, 0..15) of a purified tile's flash at `age`: a 1 px square outline inset by
## age * 8 / Config.PURIFY_FLASH_TICKS (0..7), none once the flash is over.
static func flash_pixels(age: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if age < 0 or age >= Config.PURIFY_FLASH_TICKS:
		return out
	var k: int = age * 8 / Config.PURIFY_FLASH_TICKS
	var lo: int = k
	var hi: int = Config.TILE - 1 - k
	for x: int in range(lo, hi + 1):
		out.append(Vector2i(x, lo))
		if hi != lo:
			out.append(Vector2i(x, hi))
	for y: int in range(lo + 1, hi):
		out.append(Vector2i(lo, y))
		if hi != lo:
			out.append(Vector2i(hi, y))
	return out


## The top-left world pixels of the channel's motes around tile `centre`: Config.PURIFY_MOTES on a circle of
## (Config.PURIFY_RADIUS_TILES + 0.5) tiles around the tile's centre, the first at the top, clockwise.
static func mote_points(centre: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c: Vector2 = (Vector2(centre) + Vector2(0.5, 0.5)) * Config.TILE
	var r: float = (Config.PURIFY_RADIUS_TILES + 0.5) * Config.TILE
	for i: int in Config.PURIFY_MOTES:
		var a: float = TAU * i / Config.PURIFY_MOTES - PI / 2.0
		out.append(Vector2i((c + Vector2(cos(a), sin(a)) * r).round()) - Vector2i(MOTE / 2, MOTE / 2))
	return out


## How many motes a channel `ticks` in shows (1 at its start, all of them on its last tick).
static func motes_lit(ticks: int) -> int:
	return clampi(1 + ticks * (Config.PURIFY_MOTES - 1) / maxi(1, Config.PURIFY_CHANNEL_TICKS - 1), 0, Config.PURIFY_MOTES)

class_name Heretic
extends Node2D
## The picture of one heretic (combat/heretic_sim.gd): the 03-pixel heretic_v02 sheet for its state and
## frame (feet origin like the players: a 32 cell's (16, 32), a 64 cell's (32, 48)), west = east
## mirrored (Rig scale.x = -1, ● R19 as for the players), the hit flash, and a small HP bar above the
## head once it has been hurt (drawn in code, unshaded; PLACEHOLDER: no HP art exists). The node sits
## on the feet so the y-sorted Entities sorts it with the characters. Light layer: the actors' (hard). M6a: a
## poison mark above the head while it is poisoned (EffectMarks, a code-drawn PLACEHOLDER).

const SHEETS: Array[Texture2D] = [
	preload("res://art/enemies/heretic_v02_walk.png"), preload("res://art/enemies/heretic_v02_idle.png"),
	preload("res://art/enemies/heretic_v02_attack.png"), preload("res://art/enemies/heretic_v02_hurt.png"),
	preload("res://art/enemies/heretic_v02_death.png"),
]
## IMPL: HP bar size and place (above the head, the frame top is 32 px above the feet).
const BAR_SIZE: Vector2i = Vector2i(14, 2)
const BAR_Y: int = -34
const BAR_BACK: Color = Color8(0x1a, 0x17, 0x14)
const BAR_FILL: Color = Color8(0xa3, 0x49, 0x2c)

var rig: Node2D
var body: Sprite2D
var bar: Node2D
## M6a: the poison mark above the head (EffectMarks).
var marks: EffectMarks
var sim_id: int = 0
## What is shown (tests read it).
var anim: int = HereticSim.Anim.IDLE
var frame: int = 0
var hp_ratio: float = 1.0


func _init() -> void:
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


## Source rect of frame `f` of heretic animation `a` in sheet row `row`.
static func frame_rect(a: int, row: int, f: int) -> Rect2i:
	var c: int = HereticSim.CELLS[a]
	return Rect2i(Vector2i((HereticSim.FIRST_COLUMN[a] + f) * c, row * c), Vector2i(c, c))


## Where the cell's top-left goes relative to the feet: (16, 32) of a 32 frame, plus the 64 cell's pad.
static func cell_offset(a: int) -> Vector2i:
	var pad: int = (HereticSim.CELLS[a] - Config.CHAR_FRAME.x) / 2
	return -RigData.FRAME_ORIGIN - Vector2i(pad, pad)


func show_sim(h: HereticSim) -> void:
	sim_id = h.id
	position = h.pos.round()
	anim = h.anim()
	frame = h.frame()
	var row: int = RigData.sheet_row(h.facing)
	rig.scale = Vector2(-1.0 if RigData.is_mirrored(h.facing) else 1.0, 1.0)
	if body.texture != SHEETS[anim]:
		body.texture = SHEETS[anim]
	body.region_rect = Rect2(frame_rect(anim, row, frame))
	body.position = Vector2(cell_offset(anim))
	body.modulate = Player.HIT_FLASH if h.flash_ticks > 0 else Color.WHITE
	var ratio: float = float(h.hp) / Config.HERETIC_HP
	bar.visible = h.alive() and h.hp < Config.HERETIC_HP
	var kinds: Array[int] = []
	if h.alive() and h.poisoned():
		kinds.append(EffectMarks.Kind.POISON)
	marks.show_kinds(kinds)
	if ratio != hp_ratio:
		hp_ratio = ratio
		bar.queue_redraw()


## The bar's filled width (px) for an HP ratio (at least 1 px while alive).
static func bar_fill(ratio: float) -> int:
	return clampi(ceili(ratio * BAR_SIZE.x), 1 if ratio > 0.0 else 0, BAR_SIZE.x)


func _draw_bar() -> void:
	var left: Vector2 = Vector2(-BAR_SIZE.x / 2 - 1, BAR_Y - 1)
	bar.draw_rect(Rect2(left, Vector2(BAR_SIZE + Vector2i(2, 2))), BAR_BACK)
	bar.draw_rect(Rect2(left + Vector2.ONE, Vector2(bar_fill(hp_ratio), BAR_SIZE.y)), BAR_FILL)

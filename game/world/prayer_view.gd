class_name PrayerView
extends Node2D
## M10a: the prayer circle on the ground (● R45 "제단 둘레 원"; Config.PRAYER_CIRCLE_RADIUS_PX), shown while a group prayer is under way:
## a dashed ring round the altar's centre, a faith-gold line at the radius between two ash-dark lines (one px inside and outside),
## so it reads on the lit grass and its yellow flecks; DASH of every DASH + GAP of RING_STEPS points round it are drawn. The dashes
## creep round during the gather (joining is open: one step every CREEP_TICKS) and stand still during the turns. A PLACEHOLDER drawn
## in code (no art), unshaded. Main puts it between the ground and the entities of the surface world (like the AllyMark) and shows
## it from the prayer every tick (offline). Layout values are IMPL.

const RING_STEPS: int = 512
const DASH: int = 24
const GAP: int = 8
const CREEP_TICKS: int = 5
const GOLD: Color = Color8(0xf4, 0xc9, 0x5d)
const SHADOW: Color = Color8(0x1a, 0x17, 0x14)

## What is drawn (tests read it): the centre (world px), on, and the dashes' shift (steps round the ring).
var centre: Vector2 = Vector2.ZERO
var shown: bool = false
var shift: int = 0


func _init() -> void:
	name = &"PrayerView"
	material = FixtureView.unshaded_material()
	light_mask = Config.LIGHT_LAYER_ACTORS
	visible = false


## The ring's pixels round `at` with the dashes shifted `s` steps (world px -> colour): the dark lines first, the gold over them.
static func ring_pixels(at: Vector2, s: int) -> Dictionary[Vector2i, Color]:
	var out: Dictionary[Vector2i, Color] = {}
	var r: float = Config.PRAYER_CIRCLE_RADIUS_PX
	for pass_i: int in 2:
		for k: int in RING_STEPS:
			if posmod(k + s, DASH + GAP) >= DASH:
				continue
			var ang: float = TAU * k / RING_STEPS
			var dir: Vector2 = Vector2(cos(ang), sin(ang))
			if pass_i == 0:
				out[Vector2i((at + dir * (r - 1.0)).round())] = SHADOW
				out[Vector2i((at + dir * (r + 1.0)).round())] = SHADOW
			else:
				out[Vector2i((at + dir * r).round())] = GOLD
	return out


## The dashes' shift `gather_ticks` into the gather (0 during the turns).
static func shift_for(phase: int, gather_ticks: int) -> int:
	return (gather_ticks / CREEP_TICKS) % (DASH + GAP) if phase == Prayer.Phase.GATHER else 0


## Shows the circle round `at` with the dashes shifted `s` (on), or hides it.
func show_circle(on: bool, at: Vector2 = Vector2.ZERO, s: int = 0) -> void:
	if on == shown and at == centre and s == shift:
		return
	shown = on
	centre = at
	shift = s
	visible = on
	queue_redraw()


func _draw() -> void:
	if not shown:
		return
	var px: Dictionary[Vector2i, Color] = ring_pixels(centre, shift)
	for p: Vector2i in px:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), px[p])

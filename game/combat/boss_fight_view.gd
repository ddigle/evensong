class_name BossFightView
extends Node
## M12a: draws the boss fight (combat/boss_fight.gd) of one map: the boss (combat/boss_view.gd), the cracked pillars (world/pillar_art.gd: a
## node per pillar in the y-sorted entities, its state's picture on the world light, the hit flash, the refused mark over it), and in
## code (PLACEHOLDERS, unshaded so they read in the dark dungeon, colours of brief §4: the demon row for the boss's fire, the base row's
## dust) on a ground layer under every figure: the cleave's wedge (its edge, the two sides and a fill coming out over the telegraph), the
## volley's aim lines (dots marching out along each bolt's way), the burning ground's warning circles (a ring and an inner ring growing to
## it) and their eruption (a ring of flame), a breaking pillar's dust ring over its fall circle (an inner ring closing in), the dust a
## landed debris raises, the rubble left round a broken pillar; above every figure: the fire bolts (a ball with a tail, drawn
## Config.SHOT_DRAW_LIFT_PX up like a shot) and the pebbles coming down on a breaking pillar's circle. CombatView owns it (sync after every
## step).

## IMPL colours (brief §4).
const ORANGE: Color = Color8(0xff, 0x7a, 0x1a)
const SCARLET: Color = Color8(0xc8, 0x32, 0x1f)
const BLOOD: Color = Color8(0x8f, 0x1a, 0x1a)
const CLOTTED: Color = Color8(0x5c, 0x10, 0x10)
const DUST: Color = Color8(0xa6, 0x97, 0x82)
const DUST_DARK: Color = Color8(0x6b, 0x5e, 0x4f)
const ASH: Color = Color8(0x1a, 0x17, 0x14)
## IMPL: a fire bolt's tail, nearest first.
const TAIL: Array[Color] = [SCARLET, BLOOD, CLOTTED]
## IMPL: dots along a ring or a line one per this many px; a burning circle's flames (dots per ring); how high the pebbles start over a
## breaking pillar's circle (px) and where they fall (offsets from its middle, fixed); the rubble round a broken pillar ([offset from the
## tile's bottom middle, size, colour index: 0 light stone, 1 stone, 2 dark]); the pillar's refused mark's height over its feet.
const DOT_PX: float = 4.0
## M12b (IMPL): the dots of a breaking pillar's fall ring, one per this many px.
const DUST_RING_STEP_PX: float = 2.0
const PEBBLE_HEIGHT_PX: float = 44.0
const PEBBLES: Array[Vector2i] = [Vector2i(-14, -6), Vector2i(9, -12), Vector2i(-4, 10), Vector2i(17, 4), Vector2i(-19, 8), Vector2i(2, -20),
	Vector2i(12, 15), Vector2i(-10, -16)]
const RUBBLE: Array[Array] = [
	[Vector2i(-13, -2), Vector2i(4, 3), 1], [Vector2i(10, -1), Vector2i(5, 3), 0], [Vector2i(-6, 3), Vector2i(3, 2), 2],
	[Vector2i(15, 4), Vector2i(3, 2), 1], [Vector2i(-18, 5), Vector2i(2, 2), 0], [Vector2i(4, 6), Vector2i(4, 2), 1],
	[Vector2i(-2, -6), Vector2i(3, 2), 0], [Vector2i(19, -4), Vector2i(2, 2), 2], [Vector2i(-11, 8), Vector2i(2, 1), 0],
]
const RUBBLE_COLOURS: Array[Color] = [Color8(0xb6, 0xaa, 0x9d), Color8(0x94, 0x82, 0x6f), Color8(0x6a, 0x5d, 0x4e)]
const PILLAR_MARK_Y: int = -22

var fight: BossFight
var entities: Node2D
var boss: BossView
var pillar_nodes: Array[Node2D] = []
var ground: Node2D
var above: Node2D
## What is drawn (tests read it): the pillars' looks.
var looks: PackedInt32Array = PackedInt32Array()


func setup(p_fight: BossFight, p_entities: Node2D) -> void:
	clear()
	fight = p_fight
	entities = p_entities
	if fight == null or fight.sim == null:
		return
	BossView.warm()  # the glow textures and flame points now, not on the boss's first frame (README "M12 보스 그림")
	for k: int in 4:
		PillarArt.texture(k)
		PillarArt.glint_texture(k)
	ground = Node2D.new()
	ground.name = &"BossGround"
	ground.material = FixtureView.unshaded_material()
	ground.draw.connect(_draw_ground)
	var parent: Node = entities.get_parent()
	if parent != null:
		parent.add_child(ground)
		parent.move_child(ground, entities.get_index())
	else:
		entities.add_child(ground)
	above = Node2D.new()
	above.name = &"BossAbove"
	above.material = FixtureView.unshaded_material()
	above.z_index = 1
	above.draw.connect(_draw_above)
	if parent != null:
		parent.add_child(above)
	else:
		entities.add_child(above)
	boss = BossView.new()
	entities.add_child(boss)
	for i: int in fight.pillars.size():
		var p: BossFight.Pillar = fight.pillars[i]
		var n: Node2D = Node2D.new()
		n.name = StringName("Pillar_%d" % i)
		n.position = Vector2(p.tile.x * Config.TILE + Config.TILE / 2, (p.tile.y + 1) * Config.TILE)
		var s: Sprite2D = Sprite2D.new()
		s.name = &"Sprite"
		s.centered = false
		s.light_mask = Config.LIGHT_LAYER_WORLD
		s.position = Vector2(PillarArt.origin(p.tile)) - n.position
		n.add_child(s)
		var g: Sprite2D = Sprite2D.new()  # M12c-fix: the crack glints, unshaded (PillarArt.GLINT_ALPHA), so its state reads in the dark
		g.name = &"Glints"
		g.centered = false
		g.material = FixtureView.unshaded_material()
		g.position = s.position
		n.add_child(g)
		var m: EffectMarks = EffectMarks.new()
		m.name = &"Marks"
		m.position = Vector2(0, PILLAR_MARK_Y)
		n.add_child(m)
		entities.add_child(n)
		pillar_nodes.append(n)
		looks.append(-1)
	sync()


func clear() -> void:
	for n: Node2D in pillar_nodes:
		_free(n)
	pillar_nodes.clear()
	looks.clear()
	_free(boss)
	boss = null
	_free(ground)
	ground = null
	_free(above)
	above = null


## Shows the fight as it is now.
func sync() -> void:
	if fight == null or fight.sim == null or boss == null:
		return
	boss.show_sim(fight.sim)
	for i: int in pillar_nodes.size():
		var p: BossFight.Pillar = fight.pillars[i]
		var n: Node2D = pillar_nodes[i]
		var s: Sprite2D = n.get_node(^"Sprite") as Sprite2D
		var look: int = p.look()
		if looks[i] != look:
			looks[i] = look
			s.texture = PillarArt.texture(look)
			(n.get_node(^"Glints") as Sprite2D).texture = PillarArt.glint_texture(look) if look > 0 else null
		s.modulate = Player.HIT_FLASH if p.flash_ticks > 0 else Color.WHITE
		var m: EffectMarks = n.get_node(^"Marks") as EffectMarks
		var kinds: Array[int] = []
		if p.refused_ticks > 0:
			kinds.append(EffectMarks.Kind.REFUSED)
		m.show_kinds(kinds)
	ground.queue_redraw()
	above.queue_redraw()


# --- the ground layer ---------------------------------------------------------------------------------------------------

func _draw_ground() -> void:
	if fight == null or fight.sim == null:
		return
	for p: BossFight.Pillar in fight.pillars:
		if p.fallen:
			_rubble(p)
		elif p.falling >= 0:
			var c: Vector2 = p.centre()
			var r: float = Config.BOSS_PILLARS["fall_radius_px"]
			# M12b: the fall circle's ring twice as dense and the ring closing in pale dust too (M12a's grey dots every 4 px read weaker
			# than the orange telegraphs, and this one hurts friends as well)
			_ring(ground, c, r, DUST, DUST_RING_STEP_PX)
			var left: float = float(p.falling) / maxf(Config.BOSS_PILLARS["telegraph_ticks"], 1.0)
			_ring(ground, c, r * left, DUST, DOT_PX)
	for d: BossFight.Debris in fight.debris:
		var grow: float = d.radius * (0.6 + 0.6 * float(d.age) / BossFight.DEBRIS_SHOW_TICKS)
		_ring(ground, d.pos, grow, DUST if d.age % 4 < 2 else DUST_DARK, DOT_PX * 0.75)
	var b: BossSim = fight.sim
	if b.state == BossSim.State.ATTACK and not b.stunned():
		var t: int = b.state_ticks
		match b.attack:
			BossSim.Attack.CLEAVE:
				if t < BossSim.strike_tick(b.attack):
					_wedge(b, float(t) / BossSim.strike_tick(b.attack))
			BossSim.Attack.VOLLEY:
				if t < BossSim.strike_tick(b.attack):
					_aim_lines(b, t)
	for c: BossFight.Circle in fight.circles:
		_circle(c)


## The cleave's wedge in front of the boss: dots on its edge and its two sides, and its fill out to `progress` of its reach.
func _wedge(b: BossSim, progress: float) -> void:
	var reach: float = BossSim.attack_num(BossSim.Attack.CLEAVE, "reach_px")
	var arc: float = deg_to_rad(BossSim.attack_num(BossSim.Attack.CLEAVE, "arc_deg"))
	var base: float = b.attack_dir.angle()
	var from: Vector2 = b.pos
	var steps: int = maxi(ceili(reach * arc / DOT_PX), 6)
	for i: int in steps + 1:
		var a: float = base - arc / 2.0 + arc * i / steps
		var edge: Vector2 = from + Vector2.from_angle(a) * reach
		_dot(ground, edge, ORANGE)
		_dot(ground, edge - Vector2.from_angle(a), SCARLET)  # a second, inner row: the edge reads at 1x in the dark
		if progress > 0.05:
			_dot(ground, from + Vector2.from_angle(a) * reach * progress, SCARLET)
	for side: float in [-arc / 2.0, arc / 2.0]:
		var d: float = 6.0
		while d < reach:
			_dot(ground, from + Vector2.from_angle(base + side) * d, ORANGE)
			d += DOT_PX
	var fill: float = reach * progress
	var r: float = 8.0
	while r < fill:
		var n: int = maxi(ceili(r * arc / DOT_PX), 3)
		for i: int in n + 1:
			var a2: float = base - arc / 2.0 + arc * i / n
			_dot(ground, from + Vector2.from_angle(a2) * r, BLOOD)
		r += DOT_PX


## The volley's aim lines: from the boss's body point along each bolt's way, the dots marching out with the telegraph.
func _aim_lines(b: BossSim, t: int) -> void:
	var from: Vector2 = Combat.body_point(b.pos)
	var shift: float = fmod(float(t) * 0.5, DOT_PX * 2.0)
	for dir: Vector2 in b.volley_dirs:
		var d: float = 8.0 + shift
		while d < 72.0:
			_dot(ground, from + dir * d, ORANGE if int(d / DOT_PX) % 2 == 0 else SCARLET)
			d += DOT_PX * 2.0


## A burning circle: before it erupts its ring and an inner ring growing to it, a cross on its middle; erupting, a ring of flame tongues.
func _circle(c: BossFight.Circle) -> void:
	if not c.erupted:
		_ring(ground, c.pos, c.radius, ORANGE, DOT_PX * 0.75)
		var grow: float = c.radius * clampf(float(c.age) / maxi(c.telegraph, 1), 0.0, 1.0)
		if grow > 2.0:
			_ring(ground, c.pos, grow, SCARLET, DOT_PX)
		for off: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			_dot(ground, c.pos + Vector2(off), ORANGE)
		return
	var after: int = c.age - c.telegraph
	var flick: int = after % 4
	_ring(ground, c.pos, c.radius * 0.5, SCARLET, DOT_PX * 0.6)
	var n: int = maxi(ceili(TAU * c.radius / DOT_PX), 8)
	for i: int in n:
		var a: float = TAU * i / n + flick * 0.2
		var at: Vector2 = c.pos + Vector2.from_angle(a) * c.radius * (0.7 + 0.3 * ((i + flick) % 3) / 2.0)
		_dot(ground, at, ORANGE)
		_dot(ground, at + Vector2(0, -1), SCARLET if (i + flick) % 2 == 0 else BLOOD)


## The rubble round a broken pillar (its own stone colours, dark outlines).
func _rubble(p: BossFight.Pillar) -> void:
	var foot: Vector2i = Vector2i(p.tile.x * Config.TILE + Config.TILE / 2, (p.tile.y + 1) * Config.TILE - 2)
	for spec: Array in RUBBLE:
		var off: Vector2i = spec[0]
		var size: Vector2i = spec[1]
		var k: int = spec[2]
		var at: Vector2i = foot + off
		ground.draw_rect(Rect2(Vector2(at - Vector2i.ONE), Vector2(size + Vector2i(2, 2))), ASH)
		ground.draw_rect(Rect2(Vector2(at), Vector2(size)), RUBBLE_COLOURS[k])


# --- above the figures --------------------------------------------------------------------------------------------------

func _draw_above() -> void:
	if fight == null or fight.sim == null:
		return
	var lift: Vector2 = Vector2(0, -Config.SHOT_DRAW_LIFT_PX)
	for bolt: BossFight.Bolt in fight.bolts:
		var at: Vector2 = (bolt.pos + lift).round()
		for k: int in 3:
			_dot(above, at - bolt.dir * (3.0 + 2.0 * k), TAIL[k])
		above.draw_rect(Rect2(at - Vector2(2, 1), Vector2(5, 3)), SCARLET)
		above.draw_rect(Rect2(at - Vector2(1, 2), Vector2(3, 5)), SCARLET)
		above.draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), ORANGE)
	for p: BossFight.Pillar in fight.pillars:
		if p.falling < 0:
			continue
		var left: float = float(p.falling) / maxf(Config.BOSS_PILLARS["telegraph_ticks"], 1.0)
		var r: float = Config.BOSS_PILLARS["fall_radius_px"]
		for i: int in PEBBLES.size():
			var off: Vector2 = Vector2(PEBBLES[i]) * (r / 22.0)
			var h: float = PEBBLE_HEIGHT_PX * clampf(left - 0.08 * (i % 3), 0.0, 1.0)
			var at2: Vector2 = (p.centre() + off - Vector2(0, h)).round()
			above.draw_rect(Rect2(at2 - Vector2.ONE, Vector2(3, 3)), ASH)
			above.draw_rect(Rect2(at2, Vector2(1 + i % 2, 1)), DUST)


# --- helpers ------------------------------------------------------------------------------------------------------------

static func _dot(ci: CanvasItem, at: Vector2, c: Color) -> void:
	ci.draw_rect(Rect2(at.floor(), Vector2.ONE), c)


## A ring of 1 px dots of radius `r` round `centre`, one every `step` px.
static func _ring(ci: CanvasItem, centre: Vector2, r: float, c: Color, step: float) -> void:
	if r < 1.0:
		_dot(ci, centre, c)
		return
	var n: int = maxi(ceili(TAU * r / step), 6)
	for i: int in n:
		_dot(ci, centre + Vector2.from_angle(TAU * i / n) * r, c)


func _free(n: Node) -> void:
	if n != null and is_instance_valid(n):
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.free()

class_name CombatView
extends Node
## Draws one map's arena (combat/arena.gd, M4a): a Heretic node per heretic, a sprite per shot in flight
## (PLACEHOLDERS drawn in code: no arrow or bolt art exists), the shrine's HP bar and hit flash once it is
## hurt, and over each downed player its bleed-out and revive bars. Nodes go under the map's y-sorted
## Entities (shots sort by their ground point and are drawn Config.SHOT_DRAW_LIFT_PX higher); bars are
## unshaded so they read in the dark. sync() after every arena step. M6a: thrown potions and their splashes
## (_sync_flasks). M9a: the skills' bursts (_sync_bursts: the taunt's and the slam's rings, the heal's sparks over the healed
## ally; PLACEHOLDERS drawn in code, unshaded) and the piercing arrow (the arrow with a gold tail).
## M9b (PLACEHOLDERS drawn in code, unshaded): more bursts (the oath's and the holy burst's rings, where a strike landed, the
## melee weapon skills' arcs in front of the attacker), the strikes (_sync_strikes: a warning ring on the ground that fills in
## as the strike comes, then its arrows or rocks seen falling for its last Config.SKILL_FALL_TICKS) and the healing zones
## (_sync_zones: the blessing's turning ring around the cleric, the mist's puffs). The flat ground pictures (a strike's ring, a
## zone) go on a ground layer just before the entities (like the AllyMark: under every figure); the falling shapes and the
## bursts sort with the entities.
## M11a: the surface's creatures (sync_creatures: a CreatureView per creature of Arena.herd, under the entities like a heretic).

## IMPL: bars over a downed player: width, place above the feet, colours (bleed-out = rust, revive = the
## faith gold, background ash black).
const DOWN_BAR_WIDTH: int = 16
const DOWN_BAR_Y: int = -22
const BAR_BACK: Color = Color8(0x1a, 0x17, 0x14)
const BLEED: Color = Color8(0xa3, 0x49, 0x2c)
const REVIVE: Color = Color8(0xf4, 0xc9, 0x5d)
## Arrow (10 x 3): shaft wood, iron head, ivory fletching. Bolt (6 x 6): gold with an ivory core.
const ARROW_MAP: Array = ["s.wwwwwwhm", "sswwwwwwmh", "s.wwwwwwhm"]
## M9a: the piercing arrow (12 x 3): the arrow with a gold streak behind it (IMPL, a PLACEHOLDER).
const PIERCE_MAP: Array = ["gg.wwwwwwwhm", "ggswwwwwwwmh", "gg.wwwwwwwhm"]
const BOLT_MAP: Array = [".gggg.", "gglsgg", "glsssg", "glsssg", "gglsgg", ".gggg."]
const SHRINE_BAR_Y: int = -40
## IMPL (named in M4-fix): the shrine's HP bar width (px).
const SHRINE_BAR_WIDTH: int = 30

var arena: Arena
var entities: Node2D
var heretics: Dictionary[int, Heretic] = {}
var shots: Dictionary[int, Node2D] = {}
var shrine_bar: Node2D
## M6a: thrown potions (the potion's icon, PLACEHOLDER composed from the 04-env items strip: no flying bottle
## art exists; M6-fix: unshaded, so it reads in the evening and the dark dungeon) and splashes (PLACEHOLDER drawn
## in code: droplets in the potion's colour spreading to the splash radius over Config.SPLASH_SHOW_TICKS,
## unshaded).
var flasks: Dictionary[int, Node2D] = {}
var splashes: Dictionary[int, Node2D] = {}
## M9a: a node per skill burst (Arena.bursts).
var bursts: Dictionary[int, Node2D] = {}
## M9b: per strike its ring (ground layer) and its falling shapes (entities); per zone its picture (ground layer); the ground layer
## (a Node2D just before the entities in their parent, or under them when they have none).
var strike_rings: Dictionary[int, Node2D] = {}
var strike_falls: Dictionary[int, Node2D] = {}
var zones: Dictionary[int, Node2D] = {}
var ground: Node2D
## M11a: a node per creature (Arena.herd).
var creatures: Dictionary[int, CreatureView] = {}
var _bars: Dictionary[int, Node2D] = {}
var _shrine_ratio: float = 1.0
## M4-fix: the shrine's fixture node found once for its footprint (not a walk over every entity per sync).
var _shrine_node_ref: Node2D = null
var _shrine_node_rect: Rect2i = Rect2i()

## IMPL (M6a): the splash picture's half size (px, a little more than Config.THROW_SPLASH_RADIUS_PX), its
## frames, droplets per frame, colours per effect [colour, its dark corner, (poison) the rust spot] (● brief
## §5.7 R29: healing red, buff amber, poison yellow + rust; the values of ItemIcons.PALETTE) and the shards.
const SPLASH_HALF: int = 27
const SPLASH_FRAMES: int = 3
const SPLASH_DROPS: int = 10
## IMPL (named in M6-fix): the inner ring of droplets (from the second frame) at this part of the outer ring's
## radius, the rings turned this much (radians) per frame and the inner one this much more (so drops do not line up).
const SPLASH_INNER_RING: float = 0.55
const SPLASH_TURN_PER_FRAME: float = 0.3
const SPLASH_INNER_TURN: float = 0.4
const SPLASH_COLOURS: Array[Array] = [
	[Color8(0xb8, 0x2e, 0x24), Color8(0x6e, 0x1c, 0x16)],
	[Color8(0xe0, 0x86, 0x1a), Color8(0x8c, 0x4a, 0x22)],
	[Color8(0xd5, 0xce, 0x40), Color8(0x6e, 0x66, 0x20), Color8(0xc4, 0x42, 0x1c)],
]
const SHARD: Color = Color8(0xef, 0xe3, 0xc6)
## IMPL (M9a): a burst's frames over Config.SKILL_BURST_TICKS; its colours by Arena.BurstKind [dot, its dark corner] (the taunt
## faith gold, the slam copper dust, the heal gold with an ivory core); the heal's sparks float this far above the feet (the
## middle of the figure) and rise a px a frame; a ring's dots: one per this many px of its circumference, at least BURST_MIN_DOTS.
const BURST_FRAMES: int = 3
## M9b rows (by Arena.BurstKind): the oath ivory with a gold corner, the holy burst gold with an ivory corner, the arrow rain's
## landing buff amber on dark wood, the rocks iron on ash black, the crushing blow's arc gold on wood, the heavy strike's copper
## light on copper dark, the sweep's iron light on iron. M11b: a snare's catch ivory with a gold corner on a ring of its own size.
const BURST_COLOURS: Array[Array] = [
	[Color8(0xf4, 0xc9, 0x5d), Color8(0x9c, 0x6a, 0x1f)],
	[Color8(0xc0, 0x6a, 0x2e), Color8(0x8c, 0x4a, 0x22)],
	[Color8(0xf4, 0xc9, 0x5d), Color8(0xef, 0xe3, 0xc6)],
	[Color8(0xef, 0xe3, 0xc6), Color8(0xf4, 0xc9, 0x5d)],
	[Color8(0xf4, 0xc9, 0x5d), Color8(0xef, 0xe3, 0xc6)],
	[Color8(0xe0, 0x86, 0x1a), Color8(0x6f, 0x55, 0x22)],
	[Color8(0xa3, 0x9d, 0x92), Color8(0x1a, 0x17, 0x14)],
	[Color8(0xf4, 0xc9, 0x5d), Color8(0x9c, 0x6a, 0x1f)],
	[Color8(0xdf, 0x90, 0x3f), Color8(0x8c, 0x4a, 0x22)],
	[Color8(0xd2, 0xcb, 0xb8), Color8(0xa3, 0x9d, 0x92)],
	[Color8(0xdc, 0xc4, 0x9a), Color8(0xf4, 0xc9, 0x5d)],
]
const HEAL_BURST_LIFT_PX: int = 14
const BURST_DOT_SPACING_PX: float = 6.0
const BURST_MIN_DOTS: int = 8
## IMPL (M9b): a strike's warning: STRIKE_FRAMES steps of its inner ring over the delay (the ring at frame / STRIKE_FRAMES of the
## radius), the outer ring's 1 px dots one per STRIKE_DOT_SPACING_PX of the circumference, a 3x3 plus in the middle; its colours
## by Arena.StrikeKind [the ring and the plus, the inner ring] (arrows buff amber and dark wood, rocks rust and ash black); its
## falling shapes (STRIKE_SHAPES of the map below, at golden-angle spots within STRIKE_SHAPE_SPREAD of the radius, each shape's
## bottom middle on its spot).
const STRIKE_FRAMES: int = 4
const STRIKE_DOT_SPACING_PX: float = 4.0
const STRIKE_COLOURS: Array[Array] = [
	[Color8(0xe0, 0x86, 0x1a), Color8(0x6f, 0x55, 0x22)],
	[Color8(0xb8, 0x43, 0x2f), Color8(0x1a, 0x17, 0x14)],
]
const STRIKE_SHAPES: int = 7
const STRIKE_SHAPE_SPREAD: float = 0.8
const GOLDEN_ANGLE: float = 2.399963
const ARROW_FALL_MAP: Array = ["s.s", "sws", ".w.", ".w.", ".h."]
const ROCK_FALL_MAP: Array = [".kk.", "kmhk", "kmmk", ".kk."]
## IMPL (M9b): a zone's frames (ZONE_FRAMES, one per ZONE_FRAME_TICKS, looping): the blessing's ring of 2x2 dots (ivory, a gold
## corner) one per BURST_DOT_SPACING_PX of its circumference turned half a dot a frame; the mist's MIST_PUFFS puffs (the 5x5 map
## below: healing red with an ivory heart; later ones over earlier ones) at golden-angle spots within MIST_SPREAD of the radius turned a sixteenth of a turn a
## frame, inside a ring of 1 px healing-red dots (one per STRIKE_DOT_SPACING_PX).
const ZONE_FRAMES: int = 4
const ZONE_FRAME_TICKS: int = 8
const BLESSING_COLOURS: Array[Color] = [Color8(0xef, 0xe3, 0xc6), Color8(0xf4, 0xc9, 0x5d)]
const MIST_PUFFS: int = 9
const MIST_SPREAD: float = 0.8
const MIST_PUFF_MAP: Array = [".rrr.", "rrsrr", "rsssr", "rrsrr", ".rrr."]
const MIST_EDGE: Color = Color8(0xb8, 0x2e, 0x24)

static var _splash: Dictionary[int, ImageTexture] = {}
static var _arrow: ImageTexture
static var _bolt: ImageTexture
static var _pierce: ImageTexture
static var _burst: Dictionary[String, ImageTexture] = {}
static var _strike: Dictionary[String, ImageTexture] = {}
static var _zone: Dictionary[String, ImageTexture] = {}


func setup(p_arena: Arena, p_entities: Node2D) -> void:
	clear()
	arena = p_arena
	entities = p_entities


func clear() -> void:
	for h: Heretic in heretics.values():
		_free(h)
	for s: Node2D in shots.values():
		_free(s)
	for b: Node2D in _bars.values():
		_free(b)
	for f: Node2D in flasks.values():
		_free(f)
	for sp: Node2D in splashes.values():
		_free(sp)
	for b: Node2D in bursts.values():
		_free(b)
	_free_all(strike_rings)  # M9b
	_free_all(strike_falls)
	_free_all(zones)
	for v: CreatureView in creatures.values():  # M11a
		_free(v)
	creatures.clear()
	flasks.clear()
	splashes.clear()
	bursts.clear()
	heretics.clear()
	shots.clear()
	_bars.clear()
	if shrine_bar != null:
		_free(shrine_bar)
		shrine_bar = null
	if ground != null:
		_free(ground)
		ground = null


## Shows the arena as it is now; `players` = the players on this map (their down bars).
func sync(players: Array[Player] = []) -> void:
	if arena == null:
		return
	var seen: Dictionary[int, bool] = {}
	for h: HereticSim in arena.heretics:
		seen[h.id] = true
		var node: Heretic = heretics.get(h.id, null)
		if node == null:
			node = Heretic.new()
			node.name = StringName("Heretic_%d" % h.id)
			entities.add_child(node)
			heretics[h.id] = node
		node.show_sim(h)
	for id: int in heretics.keys():
		if not seen.has(id):
			_free(heretics[id])
			heretics.erase(id)
	var flying: Dictionary[int, bool] = {}
	for s: Arena.Shot in arena.shots:
		flying[s.id] = true
		var n: Node2D = shots.get(s.id, null)
		if n == null:
			n = _shot_node(s)
			shots[s.id] = n
		n.position = s.pos.round()
	for id: int in shots.keys():
		if not flying.has(id):
			_free(shots[id])
			shots.erase(id)
	_sync_flasks()
	_sync_bursts()
	_sync_strikes()  # M9b
	_sync_zones()
	_sync_shrine()
	_sync_down_bars(players)
	sync_creatures()  # M11a


## M11a: the herd as it is now (Main after its step: the creatures' clock runs with nobody on the map too).
func sync_creatures() -> void:
	if arena == null or arena.herd == null:
		return
	var seen: Dictionary[int, bool] = {}
	for c: CreatureSim in arena.herd.list:
		seen[c.id] = true
		var node: CreatureView = creatures.get(c.id, null)
		if node == null:
			node = CreatureView.new()
			node.name = StringName("Creature_%d" % c.id)
			entities.add_child(node)
			creatures[c.id] = node
		node.show_sim(c)
	for id: int in creatures.keys():
		if not seen.has(id):
			_free(creatures[id])
			creatures.erase(id)


func _shot_node(s: Arena.Shot) -> Node2D:
	var n: Node2D = Node2D.new()
	n.name = StringName("Shot_%d" % s.id)
	var sp: Sprite2D = Sprite2D.new()
	sp.name = &"Sprite"
	sp.texture = arrow_texture() if s.kind == Combat.Kind.ARROW else bolt_texture()
	if s.pierce:
		sp.texture = pierce_texture()  # M9a
	sp.position = Vector2(0, -Config.SHOT_DRAW_LIFT_PX)
	sp.rotation = s.dir.angle() if s.kind == Combat.Kind.ARROW else 0.0
	sp.light_mask = Config.LIGHT_LAYER_ACTORS
	if s.kind == Combat.Kind.BOLT:
		sp.material = FixtureView.unshaded_material()
	n.add_child(sp)
	entities.add_child(n)
	return n


static func arrow_texture() -> ImageTexture:
	if _arrow == null:
		_arrow = ImageTexture.create_from_image(_image(ARROW_MAP))
	return _arrow


static func bolt_texture() -> ImageTexture:
	if _bolt == null:
		_bolt = ImageTexture.create_from_image(_image(BOLT_MAP))
	return _bolt


static func pierce_texture() -> ImageTexture:
	if _pierce == null:
		_pierce = ImageTexture.create_from_image(_image(PIERCE_MAP))
	return _pierce


## M9a: a node per skill burst (its picture for its age; it follows its player, Arena._age_bursts).
func _sync_bursts() -> void:
	var seen: Dictionary[int, bool] = {}
	for b: Arena.Burst in arena.bursts:
		seen[b.id] = true
		var n: Node2D = bursts.get(b.id, null)
		if n == null:
			n = Node2D.new()
			n.name = StringName("Burst_%d" % b.id)
			var sp: Sprite2D = Sprite2D.new()
			sp.name = &"Sprite"
			sp.centered = false
			sp.material = FixtureView.unshaded_material()
			sp.light_mask = Config.LIGHT_LAYER_ACTORS
			n.add_child(sp)
			entities.add_child(n)
			bursts[b.id] = n
		n.position = b.pos.round()
		var frame: int = burst_frame(b.age)
		var tex: ImageTexture = burst_texture(b.kind, frame, b.radius, b.aim, b.arc_deg)
		var sprite: Sprite2D = n.get_node(^"Sprite") as Sprite2D
		if sprite.texture != tex:
			sprite.texture = tex
		sprite.position = Vector2(burst_offset(b.kind, frame, b.radius))
	for id: int in bursts.keys():
		if not seen.has(id):
			_free(bursts[id])
			bursts.erase(id)


## M9a: the burst frame for a burst `age` ticks old (BURST_FRAMES over Config.SKILL_BURST_TICKS).
static func burst_frame(age: int) -> int:
	return clampi(age * BURST_FRAMES / maxi(Config.SKILL_BURST_TICKS, 1), 0, BURST_FRAMES - 1)


## M9a: half the burst picture's size for a ring reaching `radius` px (a px more than the ring and its 2x2 dots).
static func burst_half(radius: float) -> int:
	return ceili(radius) + 2


## M9a: the top-left of a burst's picture relative to its feet: centred on the feet (the rings), or on the middle of the figure
## and rising a px a frame (the heal).
static func burst_offset(kind: int, frame: int, radius: float) -> Vector2i:
	var half: int = burst_half(radius)
	if kind == Arena.BurstKind.HEAL:
		return Vector2i(-half, -half - HEAL_BURST_LIFT_PX - frame)
	return Vector2i(-half, -half)


static func burst_texture(kind: int, frame: int, radius: float, aim: int = 0, arc_deg: float = 360.0) -> ImageTexture:
	var arc: bool = is_arc(kind)
	var key: String = "%d/%d/%d/%d/%d" % [kind, frame, roundi(radius), aim if arc else 0, roundi(arc_deg) if arc else 360]
	if not _burst.has(key):
		_burst[key] = ImageTexture.create_from_image(burst_image(kind, frame, radius, aim, arc_deg))
	return _burst[key]


## M9b: a melee weapon skill's arc (drawn only inside its arc around its aim).
static func is_arc(kind: int) -> bool:
	return kind == Arena.BurstKind.CRUSH or kind == Arena.BurstKind.HEAVY or kind == Arena.BurstKind.SWEEP


## M9a: burst frame `frame` of `kind` (Arena.BurstKind) reaching `radius` px, a (2 * burst_half + 1) square with the burst's
## point in the middle. The taunt and the slam: a ring of 2x2 dots (colour, the dark corner) at (frame + 1) / BURST_FRAMES of the
## radius, one dot per BURST_DOT_SPACING_PX of its circumference (at least BURST_MIN_DOTS), turned half a dot each frame. The
## heal: four plus signs (3x3, gold arms, an ivory middle) on a circle of the radius, turned a quarter of the way between them
## each frame. M9b: the other rings like the taunt's; an arc (is_arc) = the ring's dots whose angle is within half of `arc_deg` of
## aim code `aim` (the dot count is the whole ring's).
static func burst_image(kind: int, frame: int, radius: float, aim: int = 0, arc_deg: float = 360.0) -> Image:
	var half: int = burst_half(radius)
	var size: int = half * 2 + 1
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var colours: Array = BURST_COLOURS[clampi(kind, 0, BURST_COLOURS.size() - 1)]
	var c0: Color = colours[0]
	var c1: Color = colours[1]
	if kind == Arena.BurstKind.HEAL:
		for k: int in 4:
			var a: float = TAU * k / 4.0 + frame * TAU / 16.0
			var at: Vector2i = Vector2i(roundi(half + radius * cos(a)), roundi(half + radius * sin(a)))
			for o: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				_put(img, at + o, c0)
			_put(img, at, c1)
		return img
	var r: float = radius * (frame + 1) / BURST_FRAMES
	var dots: int = maxi(BURST_MIN_DOTS, ceili(TAU * r / BURST_DOT_SPACING_PX))
	var arc: bool = is_arc(kind)
	var mid: Vector2 = Combat.aim_vector(aim)
	for k2: int in dots:
		var a2: float = TAU * (k2 + 0.5 * frame) / dots
		if arc and absf(mid.angle_to(Vector2.from_angle(a2))) > deg_to_rad(arc_deg) / 2.0 + 0.0001:
			continue  # M9b: an arc draws only its part of the ring
		var p: Vector2i = Vector2i(roundi(half + r * cos(a2)), roundi(half + r * sin(a2)))
		for dy: int in 2:
			for dx: int in 2:
				_put(img, p + Vector2i(dx, dy), c1 if dx == 1 and dy == 1 else c0)
	return img


# --- M9b: the strikes and the zones ---------------------------------------------------------------------------

## M9b: the ground layer (made once: a Node2D just before the entities in their parent, else under them).
func _ground_layer() -> Node2D:
	if ground != null and is_instance_valid(ground):
		return ground
	ground = Node2D.new()
	ground.name = &"SkillGround"
	var parent: Node = entities.get_parent()
	if parent != null:
		parent.add_child(ground)
		parent.move_child(ground, entities.get_index())
	else:
		entities.add_child(ground)
	return ground


## M9b: an unshaded sprite node named `node_name` (its picture's top-left set later) under `parent`.
func _sprite_node(node_name: String, parent: Node2D) -> Node2D:
	var n: Node2D = Node2D.new()
	n.name = StringName(node_name)
	var sp: Sprite2D = Sprite2D.new()
	sp.name = &"Sprite"
	sp.centered = false
	sp.material = FixtureView.unshaded_material()
	sp.light_mask = Config.LIGHT_LAYER_ACTORS
	n.add_child(sp)
	parent.add_child(n)
	return n


static func _set_texture(n: Node2D, tex: Texture2D, at: Vector2) -> void:
	var sprite: Sprite2D = n.get_node(^"Sprite") as Sprite2D
	if sprite.texture != tex:
		sprite.texture = tex
	sprite.position = at


## M9b: a ring node per strike waiting (ground layer, its warning frame) and its falling shapes (entities, seen only in its last
## Config.SKILL_FALL_TICKS, coming down from Config.SKILL_FALL_HEIGHT_PX).
func _sync_strikes() -> void:
	var seen: Dictionary[int, bool] = {}
	for s: Arena.Strike in arena.strikes:
		seen[s.id] = true
		var ring: Node2D = strike_rings.get(s.id, null)
		if ring == null:
			ring = _sprite_node("Strike_%d" % s.id, _ground_layer())
			strike_rings[s.id] = ring
		ring.position = s.pos.round()
		var half: int = burst_half(s.radius)
		_set_texture(ring, strike_texture(s.kind, strike_frame(s.age, s.delay), s.radius), Vector2(-half, -half))
		var fall: Node2D = strike_falls.get(s.id, null)
		if fall == null:
			fall = _sprite_node("Fall_%d" % s.id, entities)
			strike_falls[s.id] = fall
		fall.position = s.pos.round()
		var drop: int = fall_offset(s.left())
		fall.visible = drop >= 0
		_set_texture(fall, fall_texture(s.kind, s.radius), Vector2(-half, -half - maxi(drop, 0)))
	for id: int in strike_rings.keys():
		if not seen.has(id):
			_free(strike_rings[id])
			strike_rings.erase(id)
			if strike_falls.has(id):
				_free(strike_falls[id])
				strike_falls.erase(id)


## M9b: the warning frame of a strike `age` ticks into a `delay` (STRIKE_FRAMES over the delay).
static func strike_frame(age: int, delay: int) -> int:
	return clampi(age * STRIKE_FRAMES / maxi(delay, 1), 0, STRIKE_FRAMES - 1)


## M9b: how far above the ground (px) a strike's shapes are with `left` ticks before it lands; -1 = not seen yet.
static func fall_offset(left: int) -> int:
	if left > Config.SKILL_FALL_TICKS:
		return -1
	return Config.SKILL_FALL_HEIGHT_PX * left / maxi(Config.SKILL_FALL_TICKS, 1)


static func strike_texture(kind: int, frame: int, radius: float) -> ImageTexture:
	var key: String = "ring/%d/%d/%d" % [kind, frame, roundi(radius)]
	if not _strike.has(key):
		_strike[key] = ImageTexture.create_from_image(strike_image(kind, frame, radius))
	return _strike[key]


static func fall_texture(kind: int, radius: float) -> ImageTexture:
	var key: String = "fall/%d/%d" % [kind, roundi(radius)]
	if not _strike.has(key):
		_strike[key] = ImageTexture.create_from_image(fall_image(kind, radius))
	return _strike[key]


## M9b: a ring of 1 px dots of colour `c` at radius `r` around (half, half), one per STRIKE_DOT_SPACING_PX of its circumference.
static func _dot_ring(img: Image, half: int, r: float, c: Color) -> void:
	if r <= 0.0:
		return
	var dots: int = maxi(BURST_MIN_DOTS, ceili(TAU * r / STRIKE_DOT_SPACING_PX))
	for k: int in dots:
		var a: float = TAU * k / dots
		_put(img, Vector2i(roundi(half + r * cos(a)), roundi(half + r * sin(a))), c)


## M9b: a strike's warning frame `frame` of `kind` (Arena.StrikeKind) for a circle of `radius` (a (2 * burst_half + 1) square, the
## point in the middle): the outer ring (1 px dots, the ring colour), the inner ring at frame / STRIKE_FRAMES of the radius (the
## inner colour; none on frame 0) and a 3x3 plus in the middle (the ring colour).
static func strike_image(kind: int, frame: int, radius: float) -> Image:
	var half: int = burst_half(radius)
	var img: Image = Image.create_empty(half * 2 + 1, half * 2 + 1, false, Image.FORMAT_RGBA8)
	var colours: Array = STRIKE_COLOURS[clampi(kind, 0, STRIKE_COLOURS.size() - 1)]
	var c0: Color = colours[0]
	var c1: Color = colours[1]
	_dot_ring(img, half, radius, c0)
	_dot_ring(img, half, radius * frame / STRIKE_FRAMES, c1)
	for o: Vector2i in [Vector2i(0, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		_put(img, Vector2i(half, half) + o, c0)
	return img


## M9b: the spots (relative to the circle's middle) of the STRIKE_SHAPES falling shapes of a circle of `radius`: golden-angle spots
## within STRIKE_SHAPE_SPREAD of the radius (the k-th at sqrt((k + 0.5) / n) of it), whole px.
static func fall_spots(radius: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k: int in STRIKE_SHAPES:
		var rr: float = radius * STRIKE_SHAPE_SPREAD * sqrt((k + 0.5) / STRIKE_SHAPES)
		var a: float = k * GOLDEN_ANGLE
		out.append(Vector2i(roundi(rr * cos(a)), roundi(rr * sin(a))))
	return out


## M9b: a strike's falling shapes for a circle of `radius` (the same square as its ring): the arrow or the rock map with its bottom
## middle on each spot (fall_spots).
static func fall_image(kind: int, radius: float) -> Image:
	var half: int = burst_half(radius)
	var img: Image = Image.create_empty(half * 2 + 1, half * 2 + 1, false, Image.FORMAT_RGBA8)
	var shape: Array = ARROW_FALL_MAP if kind == Arena.StrikeKind.ARROWS else ROCK_FALL_MAP
	var first: String = shape[0]
	var w: int = first.length()
	for spot: Vector2i in fall_spots(radius):
		var top_left: Vector2i = Vector2i(half, half) + spot - Vector2i(w / 2, shape.size() - 1)
		for y: int in shape.size():
			var row: String = shape[y]
			for x: int in w:
				if ItemIcons.PALETTE.has(row[x]):
					_put(img, top_left + Vector2i(x, y), ItemIcons.PALETTE[row[x]])
	return img


## M9b: a picture node per zone (ground layer) at its point, its frame for its age.
func _sync_zones() -> void:
	var seen: Dictionary[int, bool] = {}
	for z: Arena.Zone in arena.zones:
		seen[z.id] = true
		var n: Node2D = zones.get(z.id, null)
		if n == null:
			n = _sprite_node("Zone_%d" % z.id, _ground_layer())
			zones[z.id] = n
		n.position = z.pos.round()
		var half: int = burst_half(z.radius)
		_set_texture(n, zone_texture(z.kind, zone_frame(z.age), z.radius), Vector2(-half, -half))
	for id: int in zones.keys():
		if not seen.has(id):
			_free(zones[id])
			zones.erase(id)


## M9b: a zone's frame for its age (one per ZONE_FRAME_TICKS, looping over ZONE_FRAMES).
static func zone_frame(age: int) -> int:
	return (maxi(age, 0) / ZONE_FRAME_TICKS) % ZONE_FRAMES


static func zone_texture(kind: int, frame: int, radius: float) -> ImageTexture:
	var key: String = "%d/%d/%d" % [kind, frame, roundi(radius)]
	if not _zone.has(key):
		_zone[key] = ImageTexture.create_from_image(zone_image(kind, frame, radius))
	return _zone[key]


## M9b: the mist's puff spots (relative to its middle) on frame `frame` for a circle of `radius`: MIST_PUFFS golden-angle spots
## within MIST_SPREAD of it, turned frame / 16 of a turn, whole px.
static func mist_spots(frame: int, radius: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k: int in MIST_PUFFS:
		var rr: float = radius * MIST_SPREAD * sqrt((k + 0.5) / MIST_PUFFS)
		var a: float = k * GOLDEN_ANGLE + frame * TAU / 16.0
		out.append(Vector2i(roundi(rr * cos(a)), roundi(rr * sin(a))))
	return out


## M9b: zone frame `frame` of `kind` (Arena.ZoneKind) for a circle of `radius` (a (2 * burst_half + 1) square, the point in the
## middle). The blessing: a ring of 2x2 dots (ivory, a gold corner at (1, 1)) at the radius, one per BURST_DOT_SPACING_PX of the
## circumference, turned half a dot a frame. The mist: its edge (1 px healing-red dots, one per STRIKE_DOT_SPACING_PX) and its
## puffs (MIST_PUFF_MAP centred on each mist_spots spot).
static func zone_image(kind: int, frame: int, radius: float) -> Image:
	var half: int = burst_half(radius)
	var img: Image = Image.create_empty(half * 2 + 1, half * 2 + 1, false, Image.FORMAT_RGBA8)
	if kind == Arena.ZoneKind.BLESSING:
		var dots: int = maxi(BURST_MIN_DOTS, ceili(TAU * radius / BURST_DOT_SPACING_PX))
		for k: int in dots:
			var a: float = TAU * (k + 0.5 * frame) / dots
			var p: Vector2i = Vector2i(roundi(half + radius * cos(a)), roundi(half + radius * sin(a)))
			for dy: int in 2:
				for dx: int in 2:
					_put(img, p + Vector2i(dx, dy), BLESSING_COLOURS[1] if dx == 1 and dy == 1 else BLESSING_COLOURS[0])
		return img
	_dot_ring(img, half, radius, MIST_EDGE)
	var size: int = MIST_PUFF_MAP.size()
	for spot: Vector2i in mist_spots(frame, radius):
		for y: int in size:
			var row: String = MIST_PUFF_MAP[y]
			for x: int in size:
				if ItemIcons.PALETTE.has(row[x]):
					_put(img, Vector2i(half, half) + spot + Vector2i(x - size / 2, y - size / 2), ItemIcons.PALETTE[row[x]])
	return img


static func _put(img: Image, p: Vector2i, c: Color) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
		img.set_pixelv(p, c)


static func _image(rows: Array) -> Image:
	var first: String = rows[0]
	var img: Image = Image.create_empty(first.length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			var ch: String = row[x]
			if ItemIcons.PALETTE.has(ch):
				img.set_pixel(x, y, ItemIcons.PALETTE[ch])
	return img


## M6a: a node per thrown potion (its icon on the arc) and per splash (the frame for its age).
func _sync_flasks() -> void:
	var seen: Dictionary[int, bool] = {}
	for f: Arena.Flask in arena.flasks:
		seen[f.id] = true
		var n: Node2D = flasks.get(f.id, null)
		if n == null:
			n = Node2D.new()
			n.name = StringName("Flask_%d" % f.id)
			var sp: Sprite2D = Sprite2D.new()
			sp.name = &"Sprite"
			sp.texture = ItemIcons.texture_for(f.item)
			sp.centered = false
			sp.light_mask = Config.LIGHT_LAYER_ACTORS
			sp.material = FixtureView.unshaded_material()  # M6-fix: it reads in the dark like its splash (it was shaded)
			n.add_child(sp)
			entities.add_child(n)
			flasks[f.id] = n
		n.position = f.pos.round()
		var bottle: Sprite2D = n.get_node(^"Sprite") as Sprite2D
		bottle.position = Vector2(flask_offset(f.progress()))
	for id: int in flasks.keys():
		if not seen.has(id):
			_free(flasks[id])
			flasks.erase(id)
	var shown: Dictionary[int, bool] = {}
	for s: Arena.Splash in arena.splashes:
		shown[s.id] = true
		var n2: Node2D = splashes.get(s.id, null)
		if n2 == null:
			n2 = Node2D.new()
			n2.name = StringName("Splash_%d" % s.id)
			n2.position = s.pos.round()
			var sp2: Sprite2D = Sprite2D.new()
			sp2.name = &"Sprite"
			sp2.centered = false
			sp2.position = -Vector2(SPLASH_HALF, SPLASH_HALF)
			sp2.material = FixtureView.unshaded_material()
			sp2.light_mask = Config.LIGHT_LAYER_ACTORS
			n2.add_child(sp2)
			entities.add_child(n2)
			splashes[s.id] = n2
		var tex: ImageTexture = splash_texture(Potions.effect_of(s.item), splash_frame(s.age))
		var sprite: Sprite2D = n2.get_node(^"Sprite") as Sprite2D
		if sprite.texture != tex:
			sprite.texture = tex
	for id: int in splashes.keys():
		if not shown.has(id):
			_free(splashes[id])
			splashes.erase(id)


## M6a: the top-left of a thrown potion's 16x16 icon relative to its ground point, `t` (0..1) of the way: lifted
## Config.SHOT_DRAW_LIFT_PX like a shot plus an arc of Config.THROW_ARC_PX at the middle.
static func flask_offset(t: float) -> Vector2i:
	var lift: int = Config.SHOT_DRAW_LIFT_PX + roundi(Config.THROW_ARC_PX * sin(clampf(t, 0.0, 1.0) * PI))
	return Vector2i(-8, -8 - lift)


## M6a: the splash frame for a splash `age` ticks old (SPLASH_FRAMES frames over Config.SPLASH_SHOW_TICKS).
static func splash_frame(age: int) -> int:
	return clampi(age * SPLASH_FRAMES / maxi(Config.SPLASH_SHOW_TICKS, 1), 0, SPLASH_FRAMES - 1)


static func splash_texture(effect: int, frame: int) -> ImageTexture:
	var key: int = maxi(effect, 0) * SPLASH_FRAMES + frame
	if not _splash.has(key):
		_splash[key] = ImageTexture.create_from_image(splash_image(effect, frame))
	return _splash[key]


## M6a: splash frame `frame` of a potion with effect `effect` (Potions.Effect): SPLASH_DROPS droplets (2x2 in
## the potion colour, a dark corner) on a ring that grows to Config.THROW_SPLASH_RADIUS_PX, glass shards
## (ivory) in the middle on the first frame, the poison's droplets with rust spots. (SPLASH_HALF * 2 + 1)
## square, the splash point in the middle.
static func splash_image(effect: int, frame: int) -> Image:
	var size: int = SPLASH_HALF * 2 + 1
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var colours: Array = SPLASH_COLOURS[clampi(effect, 0, SPLASH_COLOURS.size() - 1)]
	var r: float = Config.THROW_SPLASH_RADIUS_PX * (frame + 1) / SPLASH_FRAMES
	# The outer ring of droplets, and (after the first frame) half as many on a ring half way out.
	var rings: Array[Vector2] = [Vector2(r, SPLASH_DROPS)]
	if frame > 0:
		rings.append(Vector2(r * SPLASH_INNER_RING, SPLASH_DROPS / 2))
	for ring: Vector2 in rings:
		var drops: int = int(ring.y)
		for k: int in drops:
			var a: float = TAU * k / drops + frame * SPLASH_TURN_PER_FRAME + (0.0 if ring.x == r else SPLASH_INNER_TURN)
			var at: Vector2i = Vector2i(roundi(SPLASH_HALF + ring.x * cos(a)), roundi(SPLASH_HALF + ring.x * sin(a)))
			for dy: int in 2:
				for dx: int in 2:
					var p: Vector2i = at + Vector2i(dx, dy)
					if p.x >= 0 and p.y >= 0 and p.x < size and p.y < size:
						var c: Color = colours[1] if dx == 1 and dy == 1 else colours[0]
						if colours.size() > 2 and k % 3 == 0 and dx == 0 and dy == 0:
							c = colours[2]
						img.set_pixelv(p, c)
	if frame == 0:
		for o: Vector2i in [Vector2i(0, 0), Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-1, 2), Vector2i(1, 1)]:
			img.set_pixelv(Vector2i(SPLASH_HALF, SPLASH_HALF) + o, SHARD)
	return img


func _sync_shrine() -> void:
	var rect: Rect2i = arena.shrine_rect()
	var hurt: bool = rect.has_area() and arena.shrine_hp < Config.SHRINE_HP
	if not hurt:
		if shrine_bar != null:
			_free(shrine_bar)
			shrine_bar = null
		return
	if shrine_bar == null:
		shrine_bar = Node2D.new()
		shrine_bar.name = &"ShrineBar"
		shrine_bar.material = FixtureView.unshaded_material()
		shrine_bar.draw.connect(_draw_shrine_bar)
		entities.add_child(shrine_bar)
		_shrine_ratio = -1.0
	shrine_bar.position = FixtureView.foot_of(rect)
	var ratio: float = float(arena.shrine_hp) / Config.SHRINE_HP
	if ratio != _shrine_ratio:
		_shrine_ratio = ratio
		shrine_bar.queue_redraw()
	var node: Node2D = _shrine_node(rect)
	if node != null:
		node.modulate = Player.HIT_FLASH if arena.shrine_flash > 0 else Color.WHITE


func _shrine_node(rect: Rect2i) -> Node2D:
	if _shrine_node_rect == rect and is_instance_valid(_shrine_node_ref) and _shrine_node_ref.get_parent() == entities:
		return _shrine_node_ref
	_shrine_node_ref = null
	_shrine_node_rect = rect
	for child: Node in entities.get_children():
		if child is Node2D and child.name == &"Shrine":
			var n: Node2D = child as Node2D
			if n.has_meta(&"shrine_rect") and n.get_meta(&"shrine_rect") == rect:
				_shrine_node_ref = n
				return n
	return null


func _draw_shrine_bar() -> void:
	var w: int = SHRINE_BAR_WIDTH
	var left: Vector2 = Vector2(-w / 2 - 1, SHRINE_BAR_Y - 1)
	shrine_bar.draw_rect(Rect2(left, Vector2(w + 2, 4)), BAR_BACK)
	shrine_bar.draw_rect(Rect2(left + Vector2.ONE, Vector2(ceili(_shrine_ratio * w), 2)), Heretic.BAR_FILL)


func _sync_down_bars(players: Array[Player]) -> void:
	var seen: Dictionary[int, bool] = {}
	for p: Player in players:
		if p.vitals.life != Vitals.Life.DOWN:
			continue
		var key: int = p.get_instance_id()
		seen[key] = true
		var b: Node2D = _bars.get(key, null)
		if b == null:
			b = Node2D.new()
			b.name = StringName("DownBar_%s" % p.name)
			b.material = FixtureView.unshaded_material()
			b.draw.connect(_draw_down_bar.bind(b))
			entities.add_child(b)
			_bars[key] = b
		b.position = p.sim_position.round()
		b.set_meta(&"bleed", 1.0 - float(p.vitals.life_ticks) / Config.DOWN_TICKS)
		var need: int = Config.REVIVE_TICKS
		var reviver: Player = Arena.reviver_for(p, players)
		if reviver != null:
			need = maxi(Arena.revive_needed(reviver), 1)
		b.set_meta(&"revive", clampf(float(p.vitals.revive_ticks) / need, 0.0, 1.0))
		b.queue_redraw()
	for key: int in _bars.keys():
		if not seen.has(key):
			_free(_bars[key])
			_bars.erase(key)


## Two bars over a downed player: the time left before it dies (rust), the revive so far (gold).
func _draw_down_bar(b: Node2D) -> void:
	var bleed: float = b.get_meta(&"bleed", 0.0)
	var revive: float = b.get_meta(&"revive", 0.0)
	var left: Vector2 = Vector2(-DOWN_BAR_WIDTH / 2 - 1, DOWN_BAR_Y - 1)
	b.draw_rect(Rect2(left, Vector2(DOWN_BAR_WIDTH + 2, 6)), BAR_BACK)
	b.draw_rect(Rect2(left + Vector2(1, 1), Vector2(ceili(bleed * DOWN_BAR_WIDTH), 2)), BLEED)
	b.draw_rect(Rect2(left + Vector2(1, 3), Vector2(ceili(revive * DOWN_BAR_WIDTH), 2)), REVIVE)


func _free(n: Node) -> void:
	if is_instance_valid(n):
		n.get_parent().remove_child(n)
		n.free()


## M9b: frees every node of `nodes` and empties it.
func _free_all(nodes: Dictionary[int, Node2D]) -> void:
	for n: Node2D in nodes.values():
		_free(n)
	nodes.clear()

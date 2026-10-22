class_name CombatView
extends Node
## Draws one map's arena (combat/arena.gd, M4a): a Heretic node per heretic, a sprite per shot in flight
## (PLACEHOLDERS drawn in code: no arrow or bolt art exists), the shrine's HP bar and hit flash once it is
## hurt, and over each downed player its bleed-out and revive bars. Nodes go under the map's y-sorted
## Entities (shots sort by their ground point and are drawn Config.SHOT_DRAW_LIFT_PX higher); bars are
## unshaded so they read in the dark. sync() after every arena step. M6a: thrown potions and their splashes
## (_sync_flasks).

## IMPL: bars over a downed player: width, place above the feet, colours (bleed-out = rust, revive = the
## faith gold, background ash black).
const DOWN_BAR_WIDTH: int = 16
const DOWN_BAR_Y: int = -22
const BAR_BACK: Color = Color8(0x1a, 0x17, 0x14)
const BLEED: Color = Color8(0xa3, 0x49, 0x2c)
const REVIVE: Color = Color8(0xf4, 0xc9, 0x5d)
## Arrow (10 x 3): shaft wood, iron head, ivory fletching. Bolt (6 x 6): gold with an ivory core.
const ARROW_MAP: Array = ["s.wwwwwwhm", "sswwwwwwmh", "s.wwwwwwhm"]
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
## art exists) and splashes (PLACEHOLDER drawn in code: droplets in the potion's colour spreading to the
## splash radius over Config.SPLASH_SHOW_TICKS, unshaded).
var flasks: Dictionary[int, Node2D] = {}
var splashes: Dictionary[int, Node2D] = {}
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
const SPLASH_COLOURS: Array[Array] = [
	[Color8(0xb8, 0x2e, 0x24), Color8(0x6e, 0x1c, 0x16)],
	[Color8(0xe0, 0x86, 0x1a), Color8(0x8c, 0x4a, 0x22)],
	[Color8(0xd5, 0xce, 0x40), Color8(0x6e, 0x66, 0x20), Color8(0xc4, 0x42, 0x1c)],
]
const SHARD: Color = Color8(0xef, 0xe3, 0xc6)

static var _splash: Dictionary[int, ImageTexture] = {}
static var _arrow: ImageTexture
static var _bolt: ImageTexture


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
	flasks.clear()
	splashes.clear()
	heretics.clear()
	shots.clear()
	_bars.clear()
	if shrine_bar != null:
		_free(shrine_bar)
		shrine_bar = null


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
	_sync_shrine()
	_sync_down_bars(players)


func _shot_node(s: Arena.Shot) -> Node2D:
	var n: Node2D = Node2D.new()
	n.name = StringName("Shot_%d" % s.id)
	var sp: Sprite2D = Sprite2D.new()
	sp.name = &"Sprite"
	sp.texture = arrow_texture() if s.kind == Combat.Kind.ARROW else bolt_texture()
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
		rings.append(Vector2(r * 0.55, SPLASH_DROPS / 2))
	for ring: Vector2 in rings:
		var drops: int = int(ring.y)
		for k: int in drops:
			var a: float = TAU * k / drops + frame * 0.3 + (0.0 if ring.x == r else 0.4)
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

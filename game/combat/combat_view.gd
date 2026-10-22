class_name CombatView
extends Node
## Draws one map's arena (combat/arena.gd, M4a): a Heretic node per heretic, a sprite per shot in flight
## (PLACEHOLDERS drawn in code: no arrow or bolt art exists), the shrine's HP bar and hit flash once it is
## hurt, and over each downed player its bleed-out and revive bars. Nodes go under the map's y-sorted
## Entities (shots sort by their ground point and are drawn Config.SHOT_DRAW_LIFT_PX higher); bars are
## unshaded so they read in the dark. sync() after every arena step.

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
var _bars: Dictionary[int, Node2D] = {}
var _shrine_ratio: float = 1.0
## M4-fix: the shrine's fixture node found once for its footprint (not a walk over every entity per sync).
var _shrine_node_ref: Node2D = null
var _shrine_node_rect: Rect2i = Rect2i()

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

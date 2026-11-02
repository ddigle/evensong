extends "res://tests/base_test.gd"
## M10a, the group prayer at the altar (items/prayer.gd), offline first: the lamp constants against the art, the zeal formula at
## its edges (0 and 9 lamps, one and many participants, the cap, the floor: never a debuff), the directions (seeded, the same seed
## the same nine, no run longer than PRAYER_MAX_SAME_RUN), the start refusals in every listed state, joining, the turns' rotation
## with 1 / 2 / 3 / 9 participants and with one leaving, answer judging (right, wrong, late, two keys at once, a key held from
## before, a press outside one's turn, a second press), the lamps (count, order, the flicker's look), the interruptions (a
## participant hit or quitting, the cleric hit, quitting, down, dead, gone, the altar gone), the end (zeal for those still in,
## faith spent only on completion, too little = nothing), the zeal's time and its removal on death and what it blocks,
## meditation (anyone, the cleric alone, broken by moving, a dash, an action, a hit, a prayer starting), zeal on every damage
## path chosen (basic attacks: melee, arrow, bolt, the shrine, a tier-1 weapon; the nine damaging skills; not a thrown poison),
## a praying player's frames (no move, the refusals) and the drawn pieces' rules. main.tscn's side is tests/test_prayer_main.gd.
## M10-fix (the review): whose zeal blocks (a prayer's, not a meditation's), "alone" (company that could join), a gather that ends
## with the cleric alone (no prayer: it stops, he meditates), joining in the host's lag allowance, the HUD's lamps for who is at
## the altar.

const TICK: float = 1.0 / 60.0
## The window tick the scripted answers press on.
const ANSWER_AT: int = 10

var _nodes: Array[Node] = []
var _world: WorldData


func run() -> Array[String]:
	_world = SurfaceGen.generate(Config.DEFAULT_SEED, Config.MAP_SIZE)
	_check_lamp_constants()
	_check_formula()
	_check_directions()
	_check_circle_and_spots()
	_check_start_refusals()
	_check_tap_dispatch()
	_check_join_rules()
	_check_rotation()
	_check_answers()
	_check_lamps()
	_check_interruptions()
	_check_end_and_faith()
	_check_zeal_time()
	_check_meditation()
	_check_praying_frames()
	_check_zeal_damage()
	_check_zeal_skills()
	_check_views()
	_check_determinism()
	_check_review_rules()  # M10-fix
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


# --- helpers ---------------------------------------------------------------------------------------------------

## Spots (feet) inside the seed-1 circle: south and north of the altar.
func spot(i: int) -> Vector2:
	var tiles: Array[Vector2i] = [Vector2i(63, 49), Vector2i(61, 49), Vector2i(65, 49), Vector2i(62, 50), Vector2i(64, 50),
		Vector2i(63, 45), Vector2i(61, 45), Vector2i(65, 45), Vector2i(60, 49), Vector2i(66, 49), Vector2i(62, 44),
		Vector2i(64, 44)]
	return Arena.spawn_feet(tiles[i])


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	p.skills_on = true
	p.potions_on = true
	p.gear_on = true
	_nodes.append(p)
	return p


## A fresh prayer on `d` (seed 1).
static func prayer_on(d: WorldData) -> Prayer:
	var pr: Prayer = Prayer.new()
	pr.setup(d, Config.DEFAULT_SEED)
	return pr


## A cleric with faith and `n - 1` others (paladin, archer, miner, herbalist, ...) on the circle's spots.
func party(n: int, d: WorldData = null) -> Array[Player]:
	var w: WorldData = d if d != null else _world
	var out: Array[Player] = []
	var classes: PackedStringArray = ["cleric", "paladin", "archer", "miner", "herbalist", "paladin", "archer", "miner",
		"herbalist", "paladin", "archer", "miner"]
	for i: int in n:
		var p: Player = player(w, classes[i], spot(i))
		p.name = StringName("P%d_%s" % [i, classes[i]])
		out.append(p)
	out[0].skills.resource = 100
	return out


## Every player steps a tick (its keys from `keys`, else none), then the prayer.
static func tick(pr: Prayer, players: Array[Player], keys: Dictionary[Player, Vector2i] = {}) -> void:
	for p: Player in players:
		p.begin_tick()
		var key: Vector2i = keys.get(p, Vector2i.ZERO)
		p.step_frame(NetProtocol.InputFrame.new(0, key), TICK)
	pr.step(players)


static func ticks(pr: Prayer, players: Array[Player], n: int) -> void:
	for i: int in n:
		tick(pr, players)


## Starts with players[0] and lets every other one join; returns them all.
static func gather(pr: Prayer, players: Array[Player]) -> void:
	pr.start(players[0])
	for i: int in range(1, players.size()):
		pr.join(players[i])


## Runs the prayer to its end: turn i's owner presses `plan[i]` (c right, w wrong (the opposite), 2 two keys, l none) ANSWER_AT
## into its window. Returns each turn's owner (node id).
func run_out(pr: Prayer, players: Array[Player], plan: String = "ccccccccc") -> Array[int]:
	var owners: Array[int] = []
	var n: int = 0
	while pr.running() and n < 5000:
		var keys: Dictionary[Player, Vector2i] = {}
		var lamp: int = pr.current_lamp()
		if lamp >= 0 and pr.turn_ticks + 1 == ANSWER_AT:
			var owner: Player = Prayer._find(players, pr.turn_owner)
			var letter: String = plan[lamp] if lamp < plan.length() else "c"
			var d: int = pr.directions[lamp]
			if owner != null:
				match letter:
					"c":
						keys[owner] = Prayer.DIR_VECTORS[d]
					"w":
						keys[owner] = Prayer.DIR_VECTORS[(d + 2) % 4]
					"2":
						keys[owner] = Vector2i(1, -1)
		tick(pr, players, keys)
		for e: Prayer.Event in pr.events:
			if e.what == "turn":
				owners.append(e.who)
		n += 1
	return owners


static func count_of(list: Array[int], id: int) -> int:
	var n: int = 0
	for x: int in list:
		if x == id:
			n += 1
	return n


## Ticks until the turns begin (the gather's end).
static func to_turns(pr: Prayer, players: Array[Player]) -> void:
	var n: int = 0
	while pr.phase == Prayer.Phase.GATHER and n < Config.PRAYER_GATHER_TICKS + 5:
		tick(pr, players)
		n += 1


# --- the lamps' constants ---------------------------------------------------------------------------------------------

func _check_lamp_constants() -> void:
	var lit: Image = Altar.LIT.get_image()
	var unlit: Image = Altar.UNLIT.get_image()
	lit.convert(Image.FORMAT_RGBA8)
	unlit.convert(Image.FORMAT_RGBA8)
	var flames: Image = Altar.flame_image()
	check_eq(Config.PRAYER_LAMP_FLAMES.size(), Config.PRAYER_TURNS, "nine lamps, one per turn (● R45)")
	var boxes: Array[Rect2i] = []
	for i: int in Config.PRAYER_LAMP_FLAMES.size():
		boxes.append(Altar.lamp_box(i))
	var overlaps: int = 0
	for i: int in boxes.size():
		for j: int in range(i + 1, boxes.size()):
			if boxes[i].intersects(boxes[j]):
				overlaps += 1
	check_eq(overlaps, 0, "the lamp boxes do not overlap")
	# Every pixel the lit and unlit pictures differ in lies in exactly one lamp's box; every flame pixel in its flame's 2 x 5.
	var outside: int = 0
	var per_box: PackedInt32Array = PackedInt32Array()
	per_box.resize(boxes.size())
	per_box.fill(0)
	var flame_total: int = 0
	var flame_out: int = 0
	for y: int in lit.get_height():
		for x: int in lit.get_width():
			var q: Vector2i = Vector2i(x, y)
			if lit.get_pixelv(q) != unlit.get_pixelv(q):
				var inside: int = 0
				for i: int in boxes.size():
					if boxes[i].has_point(q):
						inside += 1
						per_box[i] += 1
				if inside != 1:
					outside += 1
			if flames.get_pixelv(q).a8 > 0:
				flame_total += 1
				var in_flame: bool = false
				for f: Vector2i in Config.PRAYER_LAMP_FLAMES:
					if Rect2i(f, Altar.FLAME_SIZE).has_point(q):
						in_flame = true
				if not in_flame:
					flame_out += 1
	check_eq(outside, 0, "every differing pixel is in one lamp box (the constants match the art)")
	check_eq(flame_total, 81, "81 flame pixels (9 lamps x 9)")
	check_eq(flame_out, 0, "every flame pixel in its lamp's 2 x 5 flame")
	for i: int in boxes.size():
		check(per_box[i] >= 20, "lamp %d's box holds its flame and glow (%d px)" % [i, per_box[i]])
		var f0: Vector2i = Config.PRAYER_LAMP_FLAMES[i]
		var n: int = 0
		for dy: int in Altar.FLAME_SIZE.y:
			for dx: int in Altar.FLAME_SIZE.x:
				if flames.get_pixelv(f0 + Vector2i(dx, dy)).a8 > 0:
					n += 1
		check_eq(n, 9, "lamp %d's flame has 9 px" % i)
	# Reading order: row by row from the top left.
	for i: int in range(1, Config.PRAYER_LAMP_FLAMES.size()):
		var a: Vector2i = Config.PRAYER_LAMP_FLAMES[i - 1]
		var b: Vector2i = Config.PRAYER_LAMP_FLAMES[i]
		check(b.y > a.y or (b.y == a.y and b.x > a.x), "lamp %d follows lamp %d in reading order" % [i, i - 1])


# --- the formula ---------------------------------------------------------------------------------------------------

func _check_formula() -> void:
	check_eq(Prayer.zeal_pct(Config.PRAYER_ZEAL_PAR_LAMPS, 1), Config.PRAYER_ZEAL_BASE_PCT, "par lamps alone = the base")
	check_eq(Prayer.zeal_pct(0, 1), 5, "0 lamps alone: 15 - 10 = 5 (the floor)")
	check_eq(Prayer.zeal_pct(9, 1), 23, "9 lamps alone: 15 + 8")
	check_eq(Prayer.zeal_pct(9, 2), 25, "two: + 2")
	check_eq(Prayer.zeal_pct(9, 5), 31, "five: + 8 (the cap)")
	check_eq(Prayer.zeal_pct(9, 6), 31, "six: the cap holds")
	check_eq(Prayer.zeal_pct(9, 9), 31, "nine: the cap holds")
	check_eq(Prayer.zeal_pct(0, 9), 13, "0 lamps with nine: 5 + 8")
	check_eq(Prayer.zeal_pct(4, 1), 13, "one lamp under par: below the base (● R45)")
	check_eq(Prayer.zeal_pct(6, 1), 17, "one over par: above it")
	var never_below: bool = true
	var never_debuff: bool = true
	for lit: int in range(0, Config.PRAYER_TURNS + 1):
		for n: int in range(1, Config.MAX_PLAYERS + 1):
			var pct: int = Prayer.zeal_pct(lit, n)
			never_below = never_below and pct >= Config.PRAYER_ZEAL_FLOOR_PCT
			for amount: int in range(1, 40):
				never_debuff = never_debuff and Prayer.zeal_hit(amount, pct) > amount
			if lit > 0:
				check(pct >= Prayer.zeal_pct(lit - 1, n), "more lamps never less zeal (%d, %d)" % [lit, n])
			if n > 1:
				check(pct >= Prayer.zeal_pct(lit, n - 1), "more participants never less zeal (%d, %d)" % [lit, n])
	check(never_below, "never below the floor (any lamps, any head count)")
	check(never_debuff, "never a debuff: every hit gains at least ZEAL_MIN_BONUS")
	check_eq(Prayer.zeal_hit(12, 21), 15, "12 at 21%: + 3 (2.52 rounded)")
	check_eq(Prayer.zeal_hit(6, 5), 7, "6 at 5%: + 1 (0.3, the least bonus)")
	check_eq(Prayer.zeal_hit(14, 20), 17, "14 at 20%: + 3 (2.8)")
	check_eq(Prayer.zeal_hit(10, 25), 13, "10 at 25%: + 3 (2.5 rounds up)")
	check_eq(Prayer.zeal_hit(0, 20), 0, "no damage stays none")
	check_eq(Prayer.zeal_hit(9, 0), 9, "no zeal: the damage as it was")


# --- the directions ---------------------------------------------------------------------------------------------

func _check_directions() -> void:
	var a: PackedInt32Array = Prayer.directions_for(Prayer.seed_for(1, 1))
	var b: PackedInt32Array = Prayer.directions_for(Prayer.seed_for(1, 1))
	check_eq(a, b, "the same seed, the same nine directions")
	check_eq(a.size(), Config.PRAYER_TURNS, "nine")
	var differ: int = 0
	var longest: int = 0
	var seen: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for s: int in 400:
		var d: PackedInt32Array = Prayer.directions_for(Prayer.seed_for(1, s + 1))
		if d != a:
			differ += 1
		var run: int = 1
		for i: int in d.size():
			seen[d[i]] += 1
			if i > 0:
				run = run + 1 if d[i] == d[i - 1] else 1
			longest = maxi(longest, run)
	check(differ >= 395, "other prayers draw other directions (%d of 400 differ)" % differ)
	check_eq(longest, Config.PRAYER_MAX_SAME_RUN, "no run longer than PRAYER_MAX_SAME_RUN (and runs of it do come)")
	for k: int in 4:
		check(seen[k] > 600, "every direction comes (%s: %d of 3600)" % [Prayer.DIR_KEYS[k], seen[k]])
	check_eq(Prayer.run_at_end(PackedInt32Array([1, 2, 2])), 2, "run_at_end")
	check_eq(Prayer.run_at_end(PackedInt32Array()), 0, "run_at_end of none")
	# The press: a key down from rest; two at once = SEVERAL; held = none.
	check_eq(Prayer.answer_of(Vector2i(0, -1), Vector2i.ZERO), Prayer.Dir.UP, "W")
	check_eq(Prayer.answer_of(Vector2i(-1, 0), Vector2i.ZERO), Prayer.Dir.LEFT, "A")
	check_eq(Prayer.answer_of(Vector2i(0, 1), Vector2i.ZERO), Prayer.Dir.DOWN, "S")
	check_eq(Prayer.answer_of(Vector2i(1, 0), Vector2i.ZERO), Prayer.Dir.RIGHT, "D")
	check_eq(Prayer.answer_of(Vector2i(1, 1), Vector2i.ZERO), Prayer.SEVERAL, "two keys in one tick")
	check_eq(Prayer.answer_of(Vector2i(1, 0), Vector2i(1, 0)), Prayer.NO_PRESS, "a key held from the last tick")
	check_eq(Prayer.answer_of(Vector2i(1, -1), Vector2i(0, -1)), Prayer.NO_PRESS, "another key while one is held")
	check_eq(Prayer.answer_of(Vector2i.ZERO, Vector2i.ZERO), Prayer.NO_PRESS, "nothing")
	check_eq(Prayer.keys_of(PackedInt32Array([0, 1, 2, 3])), "w,a,s,d", "keys_of")


# --- the circle ---------------------------------------------------------------------------------------------------

func _check_circle_and_spots() -> void:
	var c: Vector2 = _world.altar_center_px()
	for i: int in 12:
		check(Prayer.in_circle(_world, spot(i)), "test spot %d is in the circle" % i)
	check(Prayer.in_circle(_world, c + Vector2(Config.PRAYER_CIRCLE_RADIUS_PX, 0)), "the circle's edge counts")
	check(not Prayer.in_circle(_world, c + Vector2(Config.PRAYER_CIRCLE_RADIUS_PX + 0.5, 0)), "just past it does not")
	# Anyone who can aim at an altar tile (feet in a tile next to the footprint) stands in it.
	var r: Rect2i = _world.altar_rect
	var far: float = 0.0
	for y: int in range(r.position.y - 1, r.end.y + 1):
		for x: int in range(r.position.x - 1, r.end.x + 1):
			if r.has_point(Vector2i(x, y)):
				continue
			for corner: Vector2 in [Vector2(x * 16 + Config.FEET_HALF_WIDTH, y * 16 + Config.FEET_HEIGHT),
					Vector2(x * 16 + 16 - Config.FEET_HALF_WIDTH, y * 16 + 16)]:
				far = maxf(far, corner.distance_to(c))
	check(far <= Config.PRAYER_CIRCLE_RADIUS_PX, "every feet spot next to the footprint is in the circle (%.1f px)" % far)
	var merchant: Vector2i = Merchant.tile_of(_world)
	if merchant == Walls.NO_CELL:
		merchant = Merchant.spot_for(_world)
	check(not Prayer.in_circle(_world, Merchant.feet_of(merchant)), "the merchant stands outside the circle (seed 1)")
	var none: WorldData = WorldData.new(Vector2i(20, 20))
	none.map_id = Config.MAP_DUNGEON
	check(not Prayer.in_circle(none, Vector2(160, 160)), "no altar (the dungeon): no circle")


# --- starting ---------------------------------------------------------------------------------------------------

func _check_start_refusals() -> void:
	var pr: Prayer = prayer_on(_world)
	var ps: Array[Player] = party(3)
	var cleric: Player = ps[0]
	var none: Array[HereticSim] = []
	check_eq(pr.start_refusal(cleric, ps, none), "", "a cleric with faith in the circle, others there: it may start")
	check_eq(pr.start_refusal(ps[1], ps, none), Prayer.WHY_NOT_CLERIC, "not a cleric")
	var away: Player = player(_world, "cleric", _world.altar_center_px() + Vector2(0, 90))
	away.skills.resource = 100
	check_eq(pr.start_refusal(away, ps, none), Prayer.WHY_OUTSIDE, "outside the circle")
	cleric.skills.resource = Config.PRAYER_FAITH_COST - 1
	check_eq(pr.start_refusal(cleric, ps, none), Prayer.WHY_FAITH, "faith short of the cost")
	cleric.skills.resource = Config.PRAYER_FAITH_COST
	check_eq(pr.start_refusal(cleric, ps, none), "", "faith exactly the cost")
	# In combat: the cleric hurt within PRAYER_COMBAT_HURT_TICKS.
	pr.on_hurt(cleric)
	check_eq(pr.start_refusal(cleric, ps, none), Prayer.WHY_COMBAT, "in combat: hurt just now")
	ticks(pr, ps, Config.PRAYER_COMBAT_HURT_TICKS - 1)
	check_eq(pr.start_refusal(cleric, ps, none), Prayer.WHY_COMBAT, "still a tick short")
	ticks(pr, ps, 1)
	check_eq(pr.start_refusal(cleric, ps, none), "", "the combat time is over")
	pr.on_hurt(ps[1])
	check_eq(pr.start_refusal(cleric, ps, none), "", "another player hurt does not count")
	# In combat: a heretic engaged near the altar.
	var h: HereticSim = HereticSim.new()
	h.pos = _world.altar_center_px() + Vector2(150, 0)
	var hs: Array[HereticSim] = [h]
	check_eq(pr.start_refusal(cleric, ps, hs), "", "a heretic idle near the altar: not combat")
	h.has_target = true
	check_eq(pr.start_refusal(cleric, ps, hs), Prayer.WHY_COMBAT, "a heretic chasing someone near the altar")
	h.pos = _world.altar_center_px() + Vector2(Config.PRAYER_COMBAT_REACH_PX + 1.0, 0)
	check_eq(pr.start_refusal(cleric, ps, hs), "", "farther than PRAYER_COMBAT_REACH_PX: not combat")
	h.pos = _world.altar_center_px() + Vector2(Config.PRAYER_COMBAT_REACH_PX, 0)
	check_eq(pr.start_refusal(cleric, ps, hs), Prayer.WHY_COMBAT, "at the reach: combat")
	h.has_target = false
	h.state = HereticSim.State.EDGE
	check_eq(pr.start_refusal(cleric, ps, hs), Prayer.WHY_COMBAT, "a heretic watching the light's edge")
	h.state = HereticSim.State.DEAD
	h.has_target = true
	check_eq(pr.start_refusal(cleric, ps, hs), "", "a dead one does not count")
	# The altar carried (no altar), the cleric carrying it.
	var home: Rect2i = _world.altar_rect
	for e: EditLog.WorldEdit in AltarMove.pickup_edits(_world):
		EditLog.apply_to_data(_world, e)
	check(not _world.altar_rect.has_area(), "the altar lifted")
	check_eq(pr.start_refusal(cleric, ps, none), Prayer.WHY_NO_ALTAR, "the altar carried: no prayer")
	cleric.carrying_altar = true
	check_eq(pr.start_refusal(cleric, ps, none), Prayer.WHY_CARRYING, "the cleric carrying it")
	cleric.carrying_altar = false
	for e2: EditLog.WorldEdit in AltarMove.place_edits(home):
		EditLog.apply_to_data(_world, e2)
	check_eq(_world.altar_rect, home, "the altar back")
	# Zeal still on; a prayer under way; down, dead, a panel, mid-action, a downed player in revive reach.
	cleric.skills.add_zeal(10, 100, true)
	check_eq(pr.start_refusal(cleric, ps, none), Prayer.WHY_ZEAL, "his zeal (a prayer's) still lasts")
	cleric.skills.zeal_pct = 0
	cleric.skills.zeal_ticks = 0
	var other: Player = player(_world, "cleric", spot(5))
	other.skills.resource = 100
	pr.start(cleric)
	check_eq(pr.start_refusal(other, ps, none), Prayer.WHY_RUNNING, "a prayer already under way")
	check_eq(pr.start_refusal(cleric, ps, none), Prayer.WHY_RUNNING, "his own under way")
	pr.stop("test")
	cleric.ui_locked = true
	check_eq(pr.start_refusal(cleric, ps, none), Prayer.WHY_PANEL, "a panel open")
	cleric.ui_locked = false
	cleric.action_anim = RigData.Anim.MAGIC
	cleric.action_tick = 0
	check_eq(pr.start_refusal(cleric, ps, none), Prayer.WHY_BUSY, "mid-action")
	cleric.action_anim = -1
	ps[1].take_hit(Config.PLAYER_HP_MAX)
	ps[1].teleport(cleric.sim_position + Vector2(Config.REVIVE_REACH_PX - 2.0, 0))
	check_eq(pr.start_refusal(cleric, ps, none), Prayer.WHY_REVIVE, "a downed player in revive reach (F revives)")
	ps[1].revive_now()
	ps[1].teleport(spot(1))
	cleric.take_hit(Config.PLAYER_HP_MAX)
	check_eq(pr.start_refusal(cleric, ps, none), Prayer.WHY_DOWN, "the cleric down")
	cleric.vitals.life = Vitals.Life.DEAD
	check_eq(pr.start_refusal(cleric, ps, none), Prayer.WHY_DEAD, "dead")


func _check_tap_dispatch() -> void:
	var pr: Prayer = prayer_on(_world)
	var ps: Array[Player] = party(3)
	var none: Array[HereticSim] = []
	# A cleric with others in the circle starts; a non-cleric's tap with no prayer meditates; a cleric alone meditates.
	var t: Prayer.Tapped = pr.tap(ps[1], ps, none)
	check(t.ok() and t.what == "meditate" and pr.is_meditating(ps[1].get_instance_id()), "a paladin's tap: meditation")
	t = pr.tap(ps[1], ps, none)
	check(t.ok() and t.what == "quit" and not pr.is_meditating(ps[1].get_instance_id()), "tapped again: meditation stopped")
	check_eq(ps[1].prayer_role, Prayer.Role.NONE, "its role back to none")
	t = pr.tap(ps[0], ps, none)
	check(t.ok() and t.what == "start" and pr.phase == Prayer.Phase.GATHER, "the cleric's tap with others there: it starts")
	check_eq(pr.members, [ps[0].get_instance_id()] as Array[int], "the cleric is the first participant")
	check_eq(ps[0].prayer_role, Prayer.Role.PRAYING, "praying")
	check_eq(ps[0].prayer_face, RigData.facing_toward(ps[0].sim_position, _world.altar_center_px()), "facing the altar")
	t = pr.tap(ps[2], ps, none)
	check(t.ok() and t.what == "join", "another's tap in the gather: join")
	t = pr.tap(ps[2], ps, none)
	check(t.ok() and t.what == "leave" and not pr.is_member(ps[2].get_instance_id()), "a participant's tap: leaves")
	check(pr.running(), "the prayer goes on")
	t = pr.tap(ps[0], ps, none)
	check(t.ok() and t.what == "stop" and not pr.running(), "the cleric's tap: the prayer stops")
	# A cleric alone (the others out of the circle, or down) meditates.
	var pr2: Prayer = prayer_on(_world)
	var solo: Array[Player] = party(2)
	solo[1].teleport(_world.altar_center_px() + Vector2(0, 100))
	t = pr2.tap(solo[0], solo, none)
	check(t.ok() and t.what == "meditate", "a cleric alone in the circle meditates")
	pr2.break_meditation(solo[0].get_instance_id(), "test")
	solo[1].teleport(spot(9))
	solo[1].take_hit(Config.PLAYER_HP_MAX)
	check(solo[1].sim_position.distance_to(solo[0].sim_position) > Config.REVIVE_REACH_PX, "the downed one out of revive reach")
	check(pr2.alone(solo[0], solo), "a downed player in the circle does not count (alone)")
	t = pr2.tap(solo[0], solo, none)
	check(t.ok() and t.what == "meditate", "so he meditates")
	check(pr2.stat("refused_start") == 0, "no start was refused")


func _check_join_rules() -> void:
	var pr: Prayer = prayer_on(_world)
	var ps: Array[Player] = party(11)
	var none: Array[HereticSim] = []
	check_eq(pr.join_refusal(ps[1], ps), Prayer.WHY_NO_PRAYER, "no prayer to join")
	pr.start(ps[0])
	check_eq(pr.join_refusal(ps[1], ps), "", "in the gather: may join")
	pr.join(ps[1])
	check_eq(pr.join_refusal(ps[1], ps), Prayer.WHY_JOINED, "already in")
	ps[2].skills.add_zeal(5, 10, true)
	check_eq(pr.join_refusal(ps[2], ps), Prayer.WHY_ZEAL, "a prayer's zeal still on: no join")
	ps[2].skills.zeal_ticks = 0
	ps[2].skills.zeal_pct = 0
	var away: Player = player(_world, "archer", _world.altar_center_px() + Vector2(90, 0))
	check_eq(pr.join_refusal(away, ps), Prayer.WHY_OUTSIDE, "outside the circle")
	for i: int in range(2, 9):
		check(pr.tap(ps[i], ps, none).ok(), "joins %d" % i)
	check_eq(pr.members.size(), Config.MAX_PLAYERS, "nine in")
	check_eq(pr.join_refusal(ps[9], ps), Prayer.WHY_FULL, "the tenth: full")
	pr.leave(ps[8].get_instance_id(), "quit")
	check_eq(pr.join_refusal(ps[8], ps), "", "who left may join again in the gather")
	to_turns(pr, ps)
	check_eq(pr.phase, Prayer.Phase.TURNS, "after PRAYER_GATHER_TICKS the turns")
	check_eq(pr.join_refusal(ps[9], ps), Prayer.WHY_CLOSED, "the turns have begun: no join")
	var t: Prayer.Tapped = pr.tap(ps[10], ps, none)
	check(t.what == "join" and t.why == Prayer.WHY_CLOSED, "a tap then is a refused join")
	check_eq(pr.meditate_refusal(ps[10], ps, none), Prayer.WHY_RUNNING, "nor may one meditate during it")


# --- the turns ------------------------------------------------------------------------------------------------------

func _check_rotation() -> void:
	for n: int in [2, 3, 9]:  # M10-fix: one alone is no prayer (Config.PRAYER_MIN_PARTICIPANTS; _check_review_rules)
		var pr: Prayer = prayer_on(_world)
		var ps: Array[Player] = party(n)
		gather(pr, ps)
		var owners: Array[int] = run_out(pr, ps)
		check_eq(owners.size(), Config.PRAYER_TURNS, "%d participants: nine turns (fixed, ● R45)" % n)
		for i: int in n:
			var want: int = Config.PRAYER_TURNS / n + (1 if i < Config.PRAYER_TURNS % n else 0)
			check_eq(count_of(owners, ps[i].get_instance_id()), want, "%d participants: player %d's share" % [n, i])
		for k: int in owners.size():
			check_eq(owners[k], ps[k % n].get_instance_id(), "%d participants: turn %d goes round in join order" % [n, k])
		check_eq(pr.last.lit, 9, "%d participants: all answered right, nine lamps" % n)
	# One leaves after its first turn: its later turns go to the others (skipped).
	var pr3: Prayer = prayer_on(_world)
	var ps3: Array[Player] = party(3)
	gather(pr3, ps3)
	to_turns(pr3, ps3)
	var owners3: Array[int] = []
	var left_once: bool = false
	var guard: int = 0
	while pr3.running() and guard < 3000:
		var keys: Dictionary[Player, Vector2i] = {}
		if pr3.current_lamp() >= 0 and pr3.turn_ticks + 1 == ANSWER_AT:
			keys[Prayer._find(ps3, pr3.turn_owner)] = Prayer.DIR_VECTORS[pr3.directions[pr3.turn]]
		tick(pr3, ps3, keys)
		for e: Prayer.Event in pr3.events:
			if e.what == "turn":
				owners3.append(e.who)
		if pr3.turn == 1 and pr3.answered and not left_once:
			pr3.leave(ps3[1].get_instance_id(), "quit")
			left_once = true
		guard += 1
	var a: int = ps3[0].get_instance_id()
	var b: int = ps3[1].get_instance_id()
	var c: int = ps3[2].get_instance_id()
	owners3.push_front(a)  # turn 0 opened at the gather's end, before this loop
	check_eq(owners3, [a, b, c, a, c, a, c, a, c] as Array[int], "the one who left is skipped: C A B C B C B C B")
	check_eq(pr3.last.participants, 2, "two still in at the end")
	check(ps3[1].skills.zeal_ticks == 0 and ps3[0].skills.zealous() and ps3[2].skills.zealous(), "who left gets no zeal")
	# One leaves in the gather and joins again: it goes to the end of the order, once (C B A, three turns each).
	var pr4: Prayer = prayer_on(_world)
	var ps4: Array[Player] = party(3)
	gather(pr4, ps4)
	pr4.leave(ps4[1].get_instance_id(), "quit")
	pr4.join(ps4[1])
	check_eq(pr4.order.size(), 3, "rejoined: still three in the order")
	var owners4: Array[int] = run_out(pr4, ps4)
	var c4: int = ps4[0].get_instance_id()
	var b4: int = ps4[2].get_instance_id()
	var a4: int = ps4[1].get_instance_id()
	check_eq(owners4, [c4, b4, a4, c4, b4, a4, c4, b4, a4] as Array[int], "the rejoined one at the end: C B A x3")


func _check_answers() -> void:
	var pr: Prayer = prayer_on(_world)
	var ps: Array[Player] = party(2)
	gather(pr, ps)
	to_turns(pr, ps)
	var owner: Player = ps[0]
	var mate: Player = ps[1]
	check_eq(pr.turn, 0, "turn 0 open")
	check_eq(pr.prompt_for(owner.get_instance_id()), pr.directions[0], "the owner's prompt")
	check_eq(pr.prompt_for(mate.get_instance_id()), -1, "no prompt for the other")
	# A press by the other during the window: nothing; then the owner's right key on window tick 1.
	var d0: int = pr.directions[0]
	var k: Dictionary[Player, Vector2i] = {mate: Prayer.DIR_VECTORS[d0]}
	tick(pr, ps, k)
	check(not pr.answered and pr.lamps[0] == Prayer.Lamp.UNLIT, "an answer outside one's turn is ignored")
	k = {owner: Prayer.DIR_VECTORS[d0]}
	tick(pr, ps, k)
	check(pr.answered and pr.lamps[0] == Prayer.Lamp.LIT, "the right key: lit")
	check(owner.sim_position == spot(0), "the answer did not move the owner")
	# A second press after answering changes nothing.
	tick(pr, ps)
	k = {owner: Prayer.DIR_VECTORS[(d0 + 2) % 4]}
	tick(pr, ps, k)
	check_eq(pr.lamps[0], Prayer.Lamp.LIT, "one answer per turn: a later wrong key changes nothing")
	_to_turn(pr, ps, 1)
	# Turn 1 (mate): a wrong key.
	var d1: int = pr.directions[1]
	k = {mate: Prayer.DIR_VECTORS[(d1 + 1) % 4]}
	tick(pr, ps, k)
	check_eq(pr.lamps[1], Prayer.Lamp.OUT, "a wrong key: out")
	_to_turn(pr, ps, 2)
	# Turn 2 (owner): two keys at once = wrong.
	k = {owner: Vector2i(-1, 1)}
	tick(pr, ps, k)
	check_eq(pr.lamps[2], Prayer.Lamp.OUT, "two keys in one tick: wrong")
	_to_turn(pr, ps, 3)
	# Turn 3 (mate): late. Undecided on window tick 89, out on 90; a press in the gap is ignored.
	for t: int in Config.PRAYER_ANSWER_WINDOW_TICKS - 1:
		tick(pr, ps)
	check(not pr.answered and pr.lamps[3] == Prayer.Lamp.UNLIT, "window tick 89: still open")
	tick(pr, ps)
	check(pr.answered and pr.lamps[3] == Prayer.Lamp.OUT, "window tick 90 with no answer: late, out")
	k = {mate: Prayer.DIR_VECTORS[pr.directions[3]]}
	tick(pr, ps, k)
	check_eq(pr.lamps[3], Prayer.Lamp.OUT, "a press after the window (in the gap) is ignored")
	_to_turn(pr, ps, 4)
	# Turn 4 (owner): the right key exactly on window tick 90 counts.
	for t2: int in Config.PRAYER_ANSWER_WINDOW_TICKS - 1:
		tick(pr, ps)
	k = {owner: Prayer.DIR_VECTORS[pr.directions[4]]}
	tick(pr, ps, k)
	check_eq(pr.lamps[4], Prayer.Lamp.LIT, "the right key on the window's last tick counts")
	# Turn 5 (mate): a key held from before the turn opened (pressed in turn 4's gap) does not count; let go and pressed again it
	# does.
	var gap_end: int = Config.PRAYER_ANSWER_WINDOW_TICKS + Config.PRAYER_TURN_GAP_TICKS
	var guard: int = 0
	while not (pr.turn == 4 and pr.turn_ticks >= gap_end - 3) and guard < 400:
		tick(pr, ps)
		guard += 1
	var d5: int = pr.directions[5]
	k = {mate: Prayer.DIR_VECTORS[d5]}
	for t3: int in 8:
		tick(pr, ps, k)
	check(pr.turn == 5 and pr.turn_ticks == 5, "turn 5 opened while the key was held")
	check(not pr.answered, "a key held from before the turn opened: no answer")
	tick(pr, ps)
	tick(pr, ps, k)
	check_eq(pr.lamps[5], Prayer.Lamp.LIT, "let go and pressed again: the answer")
	# The prompt: its owner, the direction, the window's ticks left.
	_to_turn(pr, ps, 6)
	check_eq(pr.window_left(), Config.PRAYER_ANSWER_WINDOW_TICKS, "the window opens full")
	tick(pr, ps)
	check_eq(pr.window_left(), Config.PRAYER_ANSWER_WINDOW_TICKS - 1, "and drains a tick a tick")


## Ticks until turn `i` opens (its window tick 0).
func _to_turn(pr: Prayer, ps: Array[Player], i: int) -> void:
	var n: int = 0
	while not (pr.turn == i and pr.turn_ticks == 0) and n < 3000:
		tick(pr, ps)
		n += 1
	check(pr.turn == i and pr.turn_ticks == 0, "turn %d opened" % i)


func _check_lamps() -> void:
	var pr: Prayer = prayer_on(_world)
	var ps: Array[Player] = party(3)
	gather(pr, ps)
	check_eq(pr.lamps, PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0]), "all nine unlit as it starts")
	check(pr.showing(), "the lamps show during the prayer")
	var plan: String = "cwlc2cwcl"
	var decided_at: PackedInt32Array = PackedInt32Array()
	var n: int = 0
	while pr.running() and n < 3000:
		var keys: Dictionary[Player, Vector2i] = {}
		var lamp: int = pr.current_lamp()
		if lamp >= 0 and pr.turn_ticks + 1 == ANSWER_AT:
			var o: Player = Prayer._find(ps, pr.turn_owner)
			match plan[lamp]:
				"c":
					keys[o] = Prayer.DIR_VECTORS[pr.directions[lamp]]
				"w":
					keys[o] = Prayer.DIR_VECTORS[(pr.directions[lamp] + 3) % 4]
				"2":
					keys[o] = Vector2i(1, 1)
		tick(pr, ps, keys)
		for e: Prayer.Event in pr.events:
			if e.what == "answer":
				decided_at.append(e.turn)
				for later: int in range(e.turn + 1, Config.PRAYER_TURNS):
					check_eq(pr.lamps[later], Prayer.Lamp.UNLIT, "lamp %d still unlit when lamp %d is decided" % [later, e.turn])
		n += 1
	check_eq(decided_at, PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8]), "turn i decides lamp i, in order")
	var want: PackedInt32Array = PackedInt32Array([1, 2, 2, 1, 2, 1, 2, 1, 2])
	check_eq(pr.last.lamps, want, "lit for c, out for w / l / two keys")
	check_eq(pr.last.lit, 4, "four lit")
	check_eq(pr.last.zeal_pct, Prayer.zeal_pct(4, 3), "the zeal follows the lamps and the head count")
	check(pr.showing(), "the result shows a while after the end")
	ticks(pr, ps, Config.PRAYER_RESULT_SHOW_TICKS)
	check(not pr.showing(), "then the altar's own picture again")
	# How a lamp looks.
	check_eq(Altar.lamp_look(Prayer.Lamp.LIT, 0, false), Altar.Look.LIT, "lit")
	check_eq(Altar.lamp_look(Prayer.Lamp.UNLIT, 0, false), Altar.Look.UNLIT, "unlit yet")
	check_eq(Altar.lamp_look(Prayer.Lamp.UNLIT, 0, true), Altar.Look.EMBER, "being answered: the ember")
	var flicker: Array[int] = []
	for age: int in Config.PRAYER_FLICKER_TICKS + 2:
		flicker.append(Altar.lamp_look(Prayer.Lamp.OUT, age, false))
	for age2: int in Config.PRAYER_FLICKER_TICKS:
		var on: bool = (age2 / Config.PRAYER_FLICKER_STEP) % 2 == 0
		check_eq(flicker[age2], Altar.Look.GUTTER if on else Altar.Look.UNLIT, "a failed lamp flickers (age %d)" % age2)
	check_eq(flicker[Config.PRAYER_FLICKER_TICKS], Altar.Look.SOOT, "then it is out (soot)")
	check(flicker.has(Altar.Look.GUTTER) and flicker.has(Altar.Look.UNLIT) and not flicker.has(Altar.Look.LIT), "a low guttering flame on and off while it flickers")


# --- interruptions ---------------------------------------------------------------------------------------------

func _check_interruptions() -> void:
	# A participant hit (a real hit through Player.take_hit and the hurt hook) leaves alone; the prayer goes on.
	var pr: Prayer = prayer_on(_world)
	var ps: Array[Player] = party(3)
	for q: Player in ps:
		q.hurt.connect(func(_a: int, _d: bool) -> void: pr.on_hurt(q))
	gather(pr, ps)
	to_turns(pr, ps)
	ps[2].take_hit(5)
	check(not pr.is_member(ps[2].get_instance_id()) and pr.running(), "a participant hit leaves; the prayer goes on")
	check_eq(ps[2].prayer_role, Prayer.Role.NONE, "it may move again")
	check(pr.left_at.has(ps[2].get_instance_id()), "its left mark")
	# The turn owner hit on its own turn: that turn fails at once.
	var owner_turn: int = pr.turn
	var owner: Player = Prayer._find(ps, pr.turn_owner)
	if owner == ps[1]:
		ps[1].take_hit(5)
		check_eq(pr.lamps[owner_turn], Prayer.Lamp.OUT, "the owner hit on its turn: that lamp goes out")
	else:
		_to_turn(pr, ps, 1)
		ps[1].vitals.invuln_ticks = 0
		ps[1].take_hit(5)
		check_eq(pr.lamps[1], Prayer.Lamp.OUT, "the owner hit on its turn: that lamp goes out")
	check_eq(pr.members, [ps[0].get_instance_id()] as Array[int], "the cleric alone still prays")
	var faith: int = ps[0].skills.resource
	# The cleric hit: it all stops, nothing given, no faith spent.
	ps[0].take_hit(5)
	check(not pr.running(), "the cleric hit: the prayer stops")
	check_eq(ps[0].skills.resource, faith, "no faith spent")
	check(pr.last.stopped and pr.last.zeal_pct == 0, "nothing given")
	for q2: Player in ps:
		check(not q2.skills.zealous() and q2.prayer_role == Prayer.Role.NONE, "%s: no zeal, free" % q2.name)
	# The cleric quits (a tap).
	var none: Array[HereticSim] = []
	var pr2: Prayer = prayer_on(_world)
	var ps2: Array[Player] = party(2)
	gather(pr2, ps2)
	to_turns(pr2, ps2)
	pr2.tap(ps2[0], ps2, none)
	check(not pr2.running() and pr2.last.stopped, "the cleric quits: it stops")
	# A participant quits: alone.
	var pr3: Prayer = prayer_on(_world)
	var ps3: Array[Player] = party(3)
	gather(pr3, ps3)
	pr3.tap(ps3[1], ps3, none)
	check(pr3.running() and pr3.members.size() == 2, "a participant quits: only it leaves")
	# The cleric down (no hit: set straight) and dead stop it at the next step; a participant down / dead / gone leaves.
	var pr4: Prayer = prayer_on(_world)
	var ps4: Array[Player] = party(4)
	gather(pr4, ps4)
	to_turns(pr4, ps4)
	ps4[1].vitals.life = Vitals.Life.DOWN
	ps4[2].vitals.life = Vitals.Life.DEAD
	var fewer: Array[Player] = [ps4[0], ps4[1], ps4[2]]
	tick(pr4, fewer)
	check_eq(pr4.members, [ps4[0].get_instance_id()] as Array[int], "a participant down, one dead, one gone: all three leave")
	var whys: PackedStringArray = []
	for e: Prayer.Event in pr4.events:
		if e.what == "leave":
			whys.append(e.why)
	check_eq(whys, PackedStringArray(["down", "dead", "gone"]), "why each left")
	ps4[0].vitals.life = Vitals.Life.DOWN
	tick(pr4, fewer)
	check(not pr4.running() and pr4.last.why.contains("down"), "the cleric down: it stops")
	var pr5: Prayer = prayer_on(_world)
	var ps5: Array[Player] = party(2)
	gather(pr5, ps5)
	ps5[0].vitals.life = Vitals.Life.DEAD
	tick(pr5, ps5)
	check(not pr5.running() and pr5.last.why.contains("dead"), "the cleric dead: it stops")
	var ps5b: Array[Player] = [ps5[1]]
	var pr6: Prayer = prayer_on(_world)
	var ps6: Array[Player] = party(2)
	gather(pr6, ps6)
	tick(pr6, ps5b)
	check(not pr6.running(), "the cleric gone from the map: it stops")
	# The altar gone (lifted by edits, a test: the game refuses the lift meanwhile): it stops.
	var pr7: Prayer = prayer_on(_world)
	var ps7: Array[Player] = party(2)
	gather(pr7, ps7)
	var home: Rect2i = _world.altar_rect
	for e2: EditLog.WorldEdit in AltarMove.pickup_edits(_world):
		EditLog.apply_to_data(_world, e2)
	tick(pr7, ps7)
	check(not pr7.running() and pr7.last.why.contains("altar"), "the altar gone: it stops")
	for e3: EditLog.WorldEdit in AltarMove.place_edits(home):
		EditLog.apply_to_data(_world, e3)
	check(pr7.blocks_lift() == false, "nothing blocks the lift once it is over")
	var pr8: Prayer = prayer_on(_world)
	var ps8: Array[Player] = party(2)
	gather(pr8, ps8)
	check(pr8.blocks_lift(), "a prayer under way blocks the lift")
	check(not AltarMove.hold_counts(ps8[1], ps8), "a praying player's F never counts toward lifting")


# --- the end, faith ---------------------------------------------------------------------------------------------

func _check_end_and_faith() -> void:
	var pr: Prayer = prayer_on(_world)
	var ps: Array[Player] = party(4)
	ps[0].skills.resource = 70
	gather(pr, ps)
	run_out(pr, ps, "ccccccccc")
	check_eq(ps[0].skills.resource, 70 - Config.PRAYER_FAITH_COST, "completed: the cost spent once")
	check_eq(pr.last.faith, Config.PRAYER_FAITH_COST, "logged")
	var pct: int = Prayer.zeal_pct(9, 4)
	check_eq(pct, 29, "nine lamps, four: 15 + 8 + 6")
	for q: Player in ps:
		check_eq(q.skills.zeal_pct, pct, "%s: zeal %d%%" % [q.name, pct])
		check_eq(q.skills.zeal_ticks, Config.PRAYER_ZEAL_TICKS, "%s: for PRAYER_ZEAL_TICKS" % q.name)
		check_eq(q.prayer_role, Prayer.Role.NONE, "%s: free again" % q.name)
	check_eq(pr.phase, Prayer.Phase.IDLE, "over")
	check_eq(pr.stat("completed"), 1, "counted")
	# All wrong: the floor, never a debuff, the faith still spent (it completed). M10-fix: the cleric alone only once the other
	# left during the turns (a gather that ends with him alone is no prayer); the prayer goes on (● R45).
	var pr2: Prayer = prayer_on(_world)
	var ps2: Array[Player] = party(2)
	gather(pr2, ps2)
	to_turns(pr2, ps2)
	pr2.leave(ps2[1].get_instance_id(), "quit")
	run_out(pr2, ps2, "wwwwwwwww")
	check_eq(pr2.last.lit, 0, "nothing lit")
	check_eq(ps2[0].skills.zeal_pct, Config.PRAYER_ZEAL_FLOOR_PCT, "0 lamps alone: the floor, still a buff")
	check_eq(ps2[0].skills.resource, 100 - Config.PRAYER_FAITH_COST, "faith spent: it completed")
	# Faith gone by the end (a test sets it): nothing given, nothing spent.
	var pr3: Prayer = prayer_on(_world)
	var ps3: Array[Player] = party(2)
	gather(pr3, ps3)
	to_turns(pr3, ps3)
	ps3[0].skills.resource = Config.PRAYER_FAITH_COST - 1
	run_out(pr3, ps3)
	check_eq(pr3.last.why, Prayer.WHY_FAITH, "too little faith at the end: nothing given")
	check(not ps3[0].skills.zealous() and not ps3[1].skills.zealous(), "no zeal")
	check_eq(ps3[0].skills.resource, Config.PRAYER_FAITH_COST - 1, "nothing spent")
	# Stopped in the gather and in the last turn: nothing spent.
	for when: int in 2:
		var pr4: Prayer = prayer_on(_world)
		var ps4: Array[Player] = party(2)
		gather(pr4, ps4)
		if when == 1:
			_to_turn(pr4, ps4, 8)
		pr4.on_hurt(ps4[0])
		check_eq(ps4[0].skills.resource, 100, "stopped (%s): no faith spent" % ["in the gather", "in the last turn"][when])


func _check_zeal_time() -> void:
	var p: Player = player(_world, "paladin", spot(1))
	p.skills.add_zeal(20, 10)
	for t: int in 9:
		p.begin_tick()
		p.step_frame(NetProtocol.InputFrame.new(), TICK)
	check(p.skills.zealous(), "9 of 10 ticks: still zealous")
	check(p.effect_marks.shown.has(EffectMarks.Kind.ZEAL), "the zeal mark over the head")
	p.begin_tick()
	p.step_frame(NetProtocol.InputFrame.new(), TICK)
	check(not p.skills.zealous() and p.skills.zeal_pct == 0, "it runs out on the game clock")
	check(not p.effect_marks.shown.has(EffectMarks.Kind.ZEAL), "the mark gone")
	# Down keeps it; death removes it.
	p.skills.add_zeal(20, 1000)
	p.take_hit(Config.PLAYER_HP_MAX)
	check(p.vitals.life == Vitals.Life.DOWN and p.skills.zealous(), "down: the zeal stays (down is no death)")
	p.begin_tick()
	p.step_frame(NetProtocol.InputFrame.new(), TICK)
	check(p.skills.zeal_ticks == 1000 - 1, "and runs on while down")
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
	f.interact = true
	for t2: int in Config.GIVE_UP_HOLD_TICKS + 1:
		p.begin_tick()
		p.step_frame(f, TICK)
	check_eq(p.vitals.life, Vitals.Life.DEAD, "gave up: dead")
	check(not p.skills.zealous() and p.skills.zeal_ticks == 0, "death removes the zeal (● R45)")
	# What it blocks: a zealous cleric may not start, a zealous player may not join or meditate; once over they may.
	var pr: Prayer = prayer_on(_world)
	var ps: Array[Player] = party(3)
	var none: Array[HereticSim] = []
	for q: Player in ps:
		q.skills.add_zeal(10, 3, true)
	check_eq(pr.start_refusal(ps[0], ps, none), Prayer.WHY_ZEAL, "start blocked")
	check_eq(pr.meditate_refusal(ps[1], ps, none), Prayer.WHY_ZEAL, "meditation blocked")
	ticks(pr, ps, 3)
	check_eq(pr.start_refusal(ps[0], ps, none), "", "over: may start")
	pr.start(ps[0])
	ps[1].skills.add_zeal(10, 3, true)
	check_eq(pr.join_refusal(ps[1], ps), Prayer.WHY_ZEAL, "join blocked while it lasts")
	check_eq(pr.join_refusal(ps[2], ps), "", "the other may join")
	check_eq(SkillState.new().describe(), "cd=[0, 0, 0, 0] res=0 ward=0/0", "describe unchanged without zeal")


# --- M10-fix: the review's rules --------------------------------------------------------------------------------

func _check_review_rules() -> void:
	var none: Array[HereticSim] = []
	# The zeal's source: a meditation's, a prayer's; a prayer's over a meditation's makes it a prayer's; death and running out clear it.
	var sk: SkillState = SkillState.new()
	sk.add_zeal(Config.MEDITATE_ZEAL_PCT, 50)
	check(sk.zealous() and not sk.zeal_from_prayer, "a meditation's zeal")
	sk.add_zeal(Prayer.zeal_pct(5, 2), Config.PRAYER_ZEAL_TICKS, true)
	check(sk.zeal_from_prayer and sk.zeal_pct == Prayer.zeal_pct(5, 2) and sk.zeal_ticks == Config.PRAYER_ZEAL_TICKS,
		"a prayer's over it: a prayer's, its % and time")
	check(sk.copy().zeal_from_prayer and sk.copy().same_as(sk), "copied and compared")
	var other: SkillState = sk.copy()
	other.zeal_from_prayer = false
	check(not other.same_as(sk), "the source is part of the state")
	sk.on_death()
	check(not sk.zealous() and not sk.zeal_from_prayer, "death clears it")
	sk.add_zeal(10, 1, true)
	sk.tick("paladin", false, true)
	check(not sk.zealous() and not sk.zeal_from_prayer, "run out: cleared")
	# Whose zeal blocks: a meditation's blocks a meditation, not a prayer (start or join); a prayer's blocks all three.
	var pr: Prayer = prayer_on(_world)
	var ps: Array[Player] = party(3)
	ps[0].skills.add_zeal(Config.MEDITATE_ZEAL_PCT, 500)
	ps[1].skills.add_zeal(Config.MEDITATE_ZEAL_PCT, 500)
	check_eq(pr.meditate_refusal(ps[1], ps, none), Prayer.WHY_ZEAL, "a meditation's zeal: no new meditation")
	check_eq(pr.start_refusal(ps[0], ps, none), "", "a cleric with a meditation's zeal may start a prayer")
	var t: Prayer.Tapped = pr.tap(ps[0], ps, none)
	check(t.ok() and t.what == "start", "and does (the others are company)")
	check_eq(pr.join_refusal(ps[1], ps), "", "a meditation's zeal does not keep one from joining")
	pr.join(ps[1])
	pr.join(ps[2])
	run_out(pr, ps)
	for q: Player in ps:
		check(q.skills.zeal_from_prayer and q.skills.zeal_pct == Prayer.zeal_pct(9, 3) and q.skills.zeal_ticks
			== Config.PRAYER_ZEAL_TICKS, "%s: the prayer's zeal replaced the meditation's (%d%%)" % [q.name, q.skills.zeal_pct])
	check_eq(pr.meditate_refusal(ps[2], ps, none), Prayer.WHY_ZEAL, "a prayer's zeal: no meditation")
	# Walking (the host's view of a client mid-step, no key this tick): no meditation.
	ps[2].skills.zeal_pct = 0
	ps[2].skills.zeal_ticks = 0
	ps[2].walking = true
	check_eq(pr.meditate_refusal(ps[2], ps, none), Prayer.WHY_MOVING, "walking: no meditation")
	ps[2].walking = false
	# Alone: only company that could join counts (up, in the circle, no prayer's zeal).
	var pr2: Prayer = prayer_on(_world)
	var ps2: Array[Player] = party(3)
	ps2[1].skills.add_zeal(20, 500, true)
	ps2[2].skills.add_zeal(20, 500, true)
	check(pr2.alone(ps2[0], ps2), "two in the circle with a prayer's zeal: the cleric is alone (they may not join)")
	t = pr2.tap(ps2[0], ps2, none)
	check(t.ok() and t.what == "meditate" and not pr2.running(), "so his tap meditates, no prayer for nobody (%s)" % t.what)
	check_eq(ps2[0].skills.resource, 100, "no faith spent")
	pr2.break_meditation(ps2[0].get_instance_id(), "test")
	ps2[2].skills.zeal_from_prayer = false  # a meditation's zeal: it may join, so it is company
	check(not pr2.alone(ps2[0], ps2), "one with a meditation's zeal is company")
	ps2[2].skills.zeal_pct = 0
	ps2[2].skills.zeal_ticks = 0
	ps2[2].take_hit(Config.PLAYER_HP_MAX)
	check(pr2.alone(ps2[0], ps2), "a downed one is no company (M10a)")
	# A gather that ends with the cleric alone: no prayer; it stops (nobody joined), no faith spent, and he meditates instead.
	var pr3: Prayer = prayer_on(_world)
	var ps3: Array[Player] = party(2)
	t = pr3.tap(ps3[0], ps3, none)
	check(t.ok() and t.what == "start", "a cleric with one beside him starts")
	var stopped: Array[String] = []
	var meditated: int = 0
	for i: int in Config.PRAYER_GATHER_TICKS + 1:
		tick(pr3, ps3)
		for e: Prayer.Event in pr3.events:
			if e.what == "stop":
				stopped.append(e.why)
			elif e.what == "meditate":
				meditated += 1
	check_eq(stopped, [Prayer.WHY_NOBODY] as Array[String], "nobody joined: the gather's end stops it")
	check(pr3.last.stopped and pr3.last.why == Prayer.WHY_NOBODY and pr3.last.participants == 1, "its result: stopped, alone")
	check(not pr3.running() and pr3.turn == -1, "no turns")
	check_eq(ps3[0].skills.resource, 100, "no faith spent")
	check(meditated == 1 and pr3.is_meditating(ps3[0].get_instance_id()) and ps3[0].prayer_role == Prayer.Role.MEDITATING,
		"the cleric meditates instead")
	ticks(pr3, ps3, Config.MEDITATE_TICKS)
	check(ps3[0].skills.zeal_pct == Config.MEDITATE_ZEAL_PCT and not ps3[0].skills.zeal_from_prayer,
		"a meditation's small zeal (%d%%), not the prayer's" % ps3[0].skills.zeal_pct)
	check(not ps3[1].skills.zealous(), "the one who did not join: nothing")
	# One who joined and left in the gather: the same; a cleric pressing a move key at the gather's end only stops.
	var pr4: Prayer = prayer_on(_world)
	var ps4: Array[Player] = party(2)
	gather(pr4, ps4)
	pr4.tap(ps4[1], ps4, none)
	check(not pr4.is_member(ps4[1].get_instance_id()), "the other left in the gather")
	var keys: Dictionary[Player, Vector2i] = {ps4[0]: Vector2i(1, 0)}
	for i2: int in Config.PRAYER_GATHER_TICKS:
		tick(pr4, ps4, keys)
	check(pr4.last != null and pr4.last.why == Prayer.WHY_NOBODY and not pr4.is_meditating(ps4[0].get_instance_id()),
		"alone again at the gather's end, a key held: it stops, no meditation (moving)")
	check(ps4[0].sim_position.distance_to(spot(0)) < 0.01, "the cleric did not move while praying")
	# Two at the gather's end: the turns (the prayer goes on even if the other leaves later: ● R45).
	var pr5: Prayer = prayer_on(_world)
	var ps5: Array[Player] = party(2)
	gather(pr5, ps5)
	to_turns(pr5, ps5)
	check_eq(pr5.phase, Prayer.Phase.TURNS, "two: the turns")
	# Joining in the host's lag allowance (offline: never).
	var pr6: Prayer = prayer_on(_world)
	var ps6: Array[Player] = party(4)
	gather(pr6, [ps6[0], ps6[1]] as Array[Player])
	to_turns(pr6, ps6)
	check_eq(pr6.join_refusal(ps6[2], ps6), Prayer.WHY_CLOSED, "offline: the turns have begun at once (no allowance)")
	pr6.join_lag_ticks = Config.PRAYER_JOIN_LAG_TICKS
	check_eq(pr6.join_refusal(ps6[2], ps6), "", "the host: turn 0 just opened, inside its allowance")
	pr6.join(ps6[2])
	check_eq(pr6.order[pr6.order.size() - 1], ps6[2].get_instance_id(), "the late joiner goes last in the order")
	check_eq(pr6.turn_owner, ps6[0].get_instance_id(), "turn 0 stays the cleric's")
	pr6.leave(ps6[2].get_instance_id(), "quit")
	check_eq(pr6.join_refusal(ps6[2], ps6), Prayer.WHY_CLOSED, "one who left this prayer may not come back in it")
	for i3: int in Config.PRAYER_JOIN_LAG_TICKS:
		tick(pr6, ps6)
	check_eq(pr6.join_refusal(ps6[3], ps6), Prayer.WHY_CLOSED, "past the allowance: the turns have begun")
	# The HUD's lamps: for who prays or meditates there or stands near the altar.
	var pr7: Prayer = prayer_on(_world)
	var near: Player = player(_world, "miner", _world.altar_center_px() + Vector2(0, Config.PRAYER_HUD_LAMPS_REACH_PX - 1))
	var far: Player = player(_world, "miner", _world.altar_center_px() + Vector2(0, Config.PRAYER_HUD_LAMPS_REACH_PX + 1))
	check(Main.at_altar(pr7, _world, near) and not Main.at_altar(pr7, _world, far), "the lamps' grid within PRAYER_HUD_LAMPS_REACH_PX")
	check(not Main.at_altar(pr7, _world, null), "none for no player")


# --- meditation -------------------------------------------------------------------------------------------------

func _check_meditation() -> void:
	var none: Array[HereticSim] = []
	var pr: Prayer = prayer_on(_world)
	var ps: Array[Player] = party(2)
	var p: Player = ps[1]
	check(pr.tap(p, ps, none).ok(), "a paladin meditates")
	check_eq(p.prayer_role, Prayer.Role.MEDITATING, "its role")
	check(pr.blocks_lift(), "a meditation at the altar blocks the lift")
	check(not AltarMove.hold_counts(p, ps), "and its own F never counts toward lifting")
	ticks(pr, ps, Config.MEDITATE_TICKS - 1)
	check(pr.is_meditating(p.get_instance_id()) and not p.skills.zealous(), "a tick short: no zeal yet")
	check_eq(pr.meditation_ticks(p.get_instance_id()), Config.MEDITATE_TICKS - 1, "its progress")
	ticks(pr, ps, 1)
	check(not pr.is_meditating(p.get_instance_id()), "done after MEDITATE_TICKS")
	check_eq(p.skills.zeal_pct, Config.MEDITATE_ZEAL_PCT, "the small zeal")
	check_eq(p.skills.zeal_ticks, Config.MEDITATE_ZEAL_TICKS, "for MEDITATE_ZEAL_TICKS")
	check(Config.MEDITATE_ZEAL_PCT <= Prayer.zeal_pct(0, 1) and Config.MEDITATE_ZEAL_TICKS < Config.PRAYER_ZEAL_TICKS,
		"smaller than any prayer's (● R45 작은 버프)")
	check_eq(p.prayer_role, Prayer.Role.NONE, "free again")
	check_eq(pr.meditate_refusal(p, ps, none), Prayer.WHY_ZEAL, "no second one while the zeal lasts")
	# Broken: moving, a dash, an action, a hit; and a prayer starting. Nothing given.
	for how: String in ["move", "dash", "action", "hit", "prayer"]:
		var pr2: Prayer = prayer_on(_world)
		var ps2: Array[Player] = party(3)
		var m: Player = ps2[2]
		check(pr2.tap(m, ps2, none).ok(), "%s: meditating" % how)
		ticks(pr2, ps2, 10)
		var keys: Dictionary[Player, Vector2i] = {}
		match how:
			"move":
				keys[m] = Vector2i(1, 0)
				tick(pr2, ps2, keys)
			"dash":
				var fd: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
				fd.dash = true
				m.begin_tick()
				m.step_frame(fd, TICK)
				pr2.step(ps2)
			"action":
				m.start_action(RigData.Anim.MAGIC, &"debug")
				tick(pr2, ps2)
			"hit":
				pr2.on_hurt(m)
			"prayer":
				pr2.start(ps2[0])
		check(not pr2.is_meditating(m.get_instance_id()), "%s breaks the meditation" % how)
		ticks(pr2, ps2, Config.MEDITATE_TICKS)
		check(not m.skills.zealous(), "%s: no zeal" % how)
		check(m.prayer_role != Prayer.Role.MEDITATING, "%s: its role cleared" % how)
	# Refused while moving, in combat, outside the circle.
	var pr3: Prayer = prayer_on(_world)
	var ps3: Array[Player] = party(2)
	ps3[1].last_input = Vector2i(0, 1)
	check_eq(pr3.meditate_refusal(ps3[1], ps3, none), Prayer.WHY_MOVING, "moving: no meditation")
	ps3[1].last_input = Vector2i.ZERO
	pr3.on_hurt(ps3[1])
	check_eq(pr3.meditate_refusal(ps3[1], ps3, none), Prayer.WHY_COMBAT, "in combat: none")
	var out: Player = player(_world, "miner", _world.altar_center_px() + Vector2(-90, 0))
	check_eq(pr3.meditate_refusal(out, ps3, none), Prayer.WHY_OUTSIDE, "outside the circle: none")
	# Several meditate at once.
	var pr4: Prayer = prayer_on(_world)
	var ps4: Array[Player] = party(4)
	for i: int in range(1, 4):
		pr4.tap(ps4[i], ps4, none)
	ticks(pr4, ps4, Config.MEDITATE_TICKS)
	check(ps4[1].skills.zealous() and ps4[2].skills.zealous() and ps4[3].skills.zealous(), "three meditate side by side")


# --- a praying player's frames ----------------------------------------------------------------------------------

func _check_praying_frames() -> void:
	var pr: Prayer = prayer_on(_world)
	var ps: Array[Player] = party(2)
	gather(pr, ps)
	var p: Player = ps[1]
	p.inventory.add(&"sword", 1)
	p.inventory.select(0)
	var before: Vector2 = p.sim_position
	var refused: Array[String] = []
	p.prayer_refused.connect(func(what: String) -> void: refused.append(what))
	# Walking keys: no move, the frame keeps them (last_input), it faces the altar.
	for t: int in 20:
		p.begin_tick()
		var f: NetProtocol.InputFrame = p.make_frame(Vector2i(1, 0), p.sim_position + Vector2(30, 0), true, false, false)
		check_eq(f.dir, Vector2i(1, 0), "the frame carries the key (the answer)")
		p.step_frame(f, TICK)
	check_eq(p.sim_position, before, "praying: the move keys do not move")
	check_eq(p.last_input, Vector2i(1, 0), "they are the answer keys")
	check(not p.walking, "standing")
	check_eq(p.facing, p.prayer_face, "facing the altar")
	# A click, a throw, Space: nothing starts (logged); a skill key: its HUD mark (praying).
	p.begin_tick()
	var fu: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, p.sim_position + Vector2(30, 0), true, true, true, true)
	check(fu.op == NetProtocol.Op.NONE and fu.anim < 0 and not fu.dash, "no use, no dash")
	p.step_frame(fu, TICK)
	check(p.action_anim < 0 and not p.vitals.dashing(), "nothing started")
	check(refused.has("use"), "the click said why")
	p.begin_tick()
	var fs: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, p.sim_position, true, false, false, false, false, false,
		Skills.Slot.WEAPON)
	check(fs.skill.is_empty() and p.skills.shows_refusal(Skills.Slot.WEAPON), "a skill key: refused with its mark")
	check_eq(p.skills.refused_why, Skills.WHY_PRAYING, "why: praying")
	check_eq(Skills.refusal(p, Skills.Slot.IDENTITY), Skills.WHY_PRAYING, "Skills.refusal says so too (the host's rule)")
	# Even a frame that carries a use or a dash (the host's path) does not start it while praying.
	var forced: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, Vector2i(0, 1))
	forced.anim = RigData.Anim.SWORD
	forced.dash = true
	p.begin_tick()
	p.step_frame(forced, TICK)
	check(p.action_anim < 0 and not p.vitals.dashing() and p.sim_position == before, "step_frame refuses them too")
	# Out of the prayer the same keys move again.
	pr.leave(p.get_instance_id(), "quit")
	p.begin_tick()
	p.step_frame(NetProtocol.InputFrame.new(0, Vector2i(1, 0)), TICK)
	check(p.sim_position.x > before.x, "out of it, the keys move")


# --- zeal on the damage paths ------------------------------------------------------------------------------------

static func open_world() -> WorldData:
	var d: WorldData = WorldData.new(Vector2i(40, 30))
	d.map_id = Config.MAP_DUNGEON
	return d


static func arena_for(d: WorldData) -> Arena:
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	a.threat_on = true
	return a


func _check_zeal_damage() -> void:
	var east: int = Combat.aim_code(Vector2.RIGHT)
	# Basic attacks at 20%: melee arcs, the arrow and the bolt (on the shot as it leaves the hand), a tier-1 weapon's damage.
	var table: Dictionary[StringName, Array] = {
		&"sword": ["paladin", 14, 17], &"pickaxe": ["miner", 10, 12], &"sickle": ["herbalist", 8, 10],
		&"bow": ["archer", 12, 14], &"holy_light": ["cleric", 10, 12],
	}
	for item: StringName in table:
		var spec: Array = table[item]
		var cls: String = spec[0]
		var base: int = spec[1]
		var want: int = spec[2]
		check_eq(Combat.attack_for(item).damage, base, "%s: its base damage" % item)
		for zeal: int in [0, 20]:
			var d: WorldData = open_world()
			var a: Arena = arena_for(d)
			var p: Player = player(d, cls, Vector2(200, 200))
			if zeal > 0:
				p.skills.add_zeal(zeal, 100)
			var h: HereticSim = a.spawn_heretic(Vector2(218, 200))
			var players: Array[Player] = [p]
			a.player_attack(p, item, east, players)
			if Combat.attack_for(item).kind != Combat.Kind.MELEE:
				var shot: Arena.Shot = a.shots.back()
				check_eq(shot.damage, want if zeal > 0 else base, "%s at %d%%: the shot's damage" % [item, zeal])
				for t: int in 30:
					a.step(players)
			check_eq(Config.HERETIC_HP - h.hp, want if zeal > 0 else base, "%s at %d%%: the hit" % [item, zeal])
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var p2: Player = player(d2, "paladin", Vector2(200, 200))
	p2.skills.add_zeal(20, 100)
	var h2: HereticSim = a2.spawn_heretic(Vector2(218, 200))
	var t1: int = Gear.attack_damage(ItemStack.new(&"sword_t1", 1, ItemDB.Grade.NONE), 14)
	check_eq(t1, 21, "a tier-1 sword: 150%")
	a2.player_attack(p2, &"sword_t1", east, [p2] as Array[Player], 255, t1)
	check_eq(Config.HERETIC_HP - h2.hp, 25, "a tier-1 sword at 20%: 21 + 4")
	# The heretic shrine (a dungeon): a sword hit at 20% takes 17.
	var dungeon: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var a3: Arena = Arena.new()
	a3.setup(dungeon, 1)
	var rect: Rect2i = a3.shrine_rect()
	var below: Vector2 = Vector2(FixtureView.foot_of(rect).x, (rect.end.y + 1) * Config.TILE - 4.0)
	var p3: Player = player(dungeon, "paladin", below)
	p3.skills.add_zeal(20, 100)
	var hp: int = a3.shrine_hp
	a3.player_attack(p3, &"sword", Combat.aim_code(Vector2.UP))
	check_eq(hp - a3.shrine_hp, 17, "the shrine: a sword hit at 20% takes 17")
	# A thrown poison is not raised (ZEAL_COUNTS_POISON off).
	var d4: WorldData = open_world()
	var a4: Arena = arena_for(d4)
	var herb: Player = player(d4, "herbalist", Vector2(200, 200))
	herb.skills.add_zeal(20, 100)
	var h4: HereticSim = a4.spawn_heretic(Vector2(260, 200))
	var flask: Arena.Flask = a4.throw_potion(herb, &"potion_poison", ItemDB.Grade.COMMON, Vector2(260, 200))
	check_eq(flask.zeal_pct, 0, "the bottle carries no zeal")
	for t2: int in 40:
		a4.step([herb] as Array[Player])
	check_eq(h4.poison_damage, Potions.poison_damage(ItemDB.Grade.COMMON), "a thrown poison ticks as before (not zeal)")


func _check_zeal_skills() -> void:
	var east: int = Combat.aim_code(Vector2.RIGHT)
	# [class, skill, resource, damage at 0%, damage at 20%] for the nine damaging skills (base numbers: Config.SKILLS).
	var rows: Array[Array] = [
		["archer", Skills.PIERCING_ARROW, 0, 16, 19], ["miner", Skills.GROUND_SLAM, 0, 6, 7],
		["paladin", Skills.CRUSHING_BLOW, 0, 20, 24], ["archer", Skills.FAN_SHOT, 0, 8, 10],
		["cleric", Skills.HOLY_BURST, 0, 14, 17], ["miner", Skills.HEAVY_STRIKE, 0, 22, 26],
		["herbalist", Skills.SWEEP, 0, 8, 10], ["archer", Skills.ARROW_RAIN, 30, 12, 14], ["miner", Skills.ROCKFALL, 40, 24, 29],
	]
	for row: Array in rows:
		var cls: String = row[0]
		var id: StringName = row[1]
		var res: int = row[2]
		for zeal: int in [0, 20]:
			var want: int = row[3] if zeal == 0 else row[4]
			var d: WorldData = open_world()
			var a: Arena = arena_for(d)
			var p: Player = player(d, cls, Vector2(200, 200))
			if zeal > 0:
				p.skills.add_zeal(zeal, 1000)
			p.skills.resource = res
			# The fan's side arrows miss a heretic this far (only the middle one hits); the others stand close.
			var h: HereticSim = a.spawn_heretic(Vector2(290 if id == Skills.FAN_SHOT else 218, 200))
			p.action_aim = east
			p.action_target = h.pos
			p.action_slot = 0
			p.action_skill_slot = Skills.slot_of(cls, id)
			var team: Array[Player] = [p]
			var r: Skills.Landed = Skills.land(p, id, a, team)
			check(r.ok(), "%s at %d%%: landed (%s)" % [id, zeal, r.why])
			if r.shot != null:
				check_eq(r.shot.damage, want, "%s at %d%%: the arrow's damage" % [id, zeal])
			for s: Arena.Shot in r.shots:
				check_eq(s.damage, want, "%s at %d%%: each arrow's damage" % [id, zeal])
			if r.strike != null:
				check_eq(r.strike.damage, want, "%s at %d%%: the strike's damage" % [id, zeal])
			if id != Skills.PIERCING_ARROW and id != Skills.GROUND_SLAM:
				check_eq(r.damage, want, "%s at %d%%: Landed.damage" % [id, zeal])
			for t: int in 90:
				a.step(team)
			check_eq(Config.HERETIC_HP - h.hp, want, "%s at %d%%: the heretic took it" % [id, zeal])


# --- the drawn pieces' rules ----------------------------------------------------------------------------------

func _check_views() -> void:
	var up: Image = PrayerMark.arrow_image(Prayer.Dir.UP)
	var down: Image = PrayerMark.arrow_image(Prayer.Dir.DOWN)
	var left: Image = PrayerMark.arrow_image(Prayer.Dir.LEFT)
	var right: Image = PrayerMark.arrow_image(Prayer.Dir.RIGHT)
	var n: int = up.get_width()
	check_eq(n, 9, "the arrow is 9 x 9")
	var opaque: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var turned: int = 0
	for y: int in n:
		for x: int in n:
			var imgs: Array[Image] = [up, left, down, right]
			for k: int in 4:
				if imgs[k].get_pixel(x, y).a8 > 0:
					opaque[k] += 1
			if up.get_pixel(x, y) != down.get_pixel(x, n - 1 - y) or up.get_pixel(x, y) != left.get_pixel(y, x) \
					or up.get_pixel(x, y) != right.get_pixel(n - 1 - y, x):
				turned += 1
	check(opaque[0] > 30 and opaque[0] == opaque[1] and opaque[1] == opaque[2] and opaque[2] == opaque[3],
		"four arrows, the same picture turned (%s)" % opaque)
	check_eq(turned, 0, "down = up flipped, left = up transposed, right = left mirrored")
	check(up.get_pixel(4, 0).a8 > 0 and up.get_pixel(4, 8).a8 > 0 and up.get_pixel(0, 0).a8 == 0, "up points up")
	check(left.get_pixel(0, 4).a8 > 0 and right.get_pixel(8, 4).a8 > 0, "left and right point that way")
	var spark_img: Image = PrayerMark.spark_image(false)
	var gone: Image = PrayerMark.spark_image(true)
	check(spark_img.get_pixel(2, 2) == ItemIcons.PALETTE["g"] and gone.get_pixel(2, 2) == ItemIcons.PALETTE["m"]
			and spark_img.get_pixel(2, 1) == ItemIcons.PALETTE["g"] and spark_img.get_pixel(0, 0).a8 == 0
			and spark_img.get_pixel(1, 1) == ItemIcons.PALETTE["k"],
		"the joined spark gold (filled in the middle: no ring, the cleric's halo is one), the left one iron grey")
	check_eq(PrayerMark.bar_fill(0), 0, "no meditation: no bar")
	check_eq(PrayerMark.bar_fill(1), 1, "begun: one px")
	check_eq(PrayerMark.bar_fill(Config.MEDITATE_TICKS / 2), 4, "half: 4 of 7")
	check_eq(PrayerMark.bar_fill(Config.MEDITATE_TICKS), PrayerMark.BAR_W, "done: full")
	var mark: PrayerMark = PrayerMark.new()
	_nodes.append(mark)
	mark.show_mark(PrayerMark.Kind.TURN, Prayer.Dir.LEFT)
	check(mark.visible and mark.kind == PrayerMark.Kind.TURN and mark.dir == Prayer.Dir.LEFT, "the turn mark")
	mark.show_mark(PrayerMark.Kind.NONE)
	check(not mark.visible, "none: hidden")
	# Low: in the effect marks' rows just above the head (the head's top is Config.HEAD_ROOM_PX up); raised: above those marks.
	check(PrayerMark.arrow_at().y + 9 <= -Config.HEAD_ROOM_PX - 8, "the arrow clear of the head (and the cleric's halo)")
	check(PrayerMark.spark_at().y + 5 <= -Config.HEAD_ROOM_PX - 8, "the spark too")
	check(PrayerMark.bar_at().y < PrayerMark.spark_at().y, "the meditation bar over the spark")
	check(PrayerMark.arrow_at(true).y + 9 <= EffectMarks.MARK_Y, "raised: the arrow above the effect marks")
	check(PrayerMark.spark_at(true).y + 5 <= EffectMarks.MARK_Y, "raised: the spark above them")
	mark.show_mark(PrayerMark.Kind.JOINED, -1, 0, true)
	check(mark.raised and mark.visible, "a raised mark")
	# The circle: a dashed gold ring at the radius between two dark lines.
	var c: Vector2 = Vector2(500, 500)
	var ring: Dictionary[Vector2i, Color] = PrayerView.ring_pixels(c, 0)
	var golds: int = 0
	var darks: int = 0
	var off_ring: int = 0
	for q: Vector2i in ring:
		var dist: float = Vector2(q).distance_to(c)
		if ring[q] == PrayerView.GOLD:
			golds += 1
			if absf(dist - Config.PRAYER_CIRCLE_RADIUS_PX) > 0.75:
				off_ring += 1
		else:
			darks += 1
			if absf(absf(dist - Config.PRAYER_CIRCLE_RADIUS_PX) - 1.0) > 0.75:
				off_ring += 1
	check_eq(off_ring, 0, "gold on the radius, dark one px inside and out")
	check(golds > 250 and darks > golds, "a ring of %d gold px and %d dark" % [golds, darks])
	var lit_steps: int = 0
	for k2: int in PrayerView.RING_STEPS:
		if posmod(k2, PrayerView.DASH + PrayerView.GAP) < PrayerView.DASH:
			lit_steps += 1
	check_eq(lit_steps, PrayerView.RING_STEPS / (PrayerView.DASH + PrayerView.GAP) * PrayerView.DASH, "dashed: 16 dashes")
	check(PrayerView.ring_pixels(c, 5) != ring, "shifted dashes differ")
	check_eq(PrayerView.shift_for(Prayer.Phase.GATHER, PrayerView.CREEP_TICKS * 5), 5, "creeping in the gather")
	check_eq(PrayerView.shift_for(Prayer.Phase.TURNS, 55), 0, "still in the turns")
	var view: PrayerView = PrayerView.new()
	_nodes.append(view)
	check(not view.visible, "hidden until a prayer")
	view.show_circle(true, c, 2)
	check(view.visible and view.shown and view.centre == c and view.shift == 2, "shown")
	view.show_circle(false)
	check(not view.visible, "hidden")
	# The altar's lamps.
	var altar: Altar = Altar.new()
	_nodes.append(altar)
	altar.setup(_world.altar_rect)
	var looks: PackedInt32Array = PackedInt32Array([0, 1, 2, 3, 1, 1, 1, 1, 1])
	altar.show_lamps(looks)
	check(not altar.flames.visible and altar.looks == looks, "during a prayer the lamps show their states, the mask hidden")
	altar.show_lamps(PackedInt32Array())
	check(altar.flames.visible and altar.looks.is_empty(), "after it the altar's own picture (all lit)")
	# The HUD's prayer pieces.
	check_eq(Hud.prompt_fill(Config.PRAYER_ANSWER_WINDOW_TICKS), Hud.PROMPT_BAR.x, "the window bar full")
	check_eq(Hud.prompt_fill(1), 1, "a tick left: one px")
	check_eq(Hud.prompt_fill(0), 0, "none")
	check_eq(Hud.zeal_fill(Config.PRAYER_ZEAL_TICKS), EffectMarks.SIZE, "the zeal bar full")
	check_eq(Hud.zeal_fill(0), -1, "no zeal: none")
	var hp: Player = player(_world, "cleric", spot(0))
	hp.skills.add_zeal(10, 100)
	hp.apply_potion(&"potion_buff", ItemDB.Grade.COMMON)
	check_eq(Hud.effect_kinds(hp), [EffectMarks.Kind.BUFF, EffectMarks.Kind.ZEAL] as Array[int], "the HUD's effects: the zeal last")
	var o: Vector2i = Hud.prompt_origin(Config.VIEW_SIZE)
	check_eq(o, Vector2i((480 - 27) / 2, Hud.PROMPT_TOP), "the prompt at the top centre")
	check(Hud.prompt_bar_at(Config.VIEW_SIZE).y > o.y + 27, "its bar under it")
	var hud: Hud = Hud.new()
	_nodes.append(hud)
	hud.bind_player(hp)
	var k0: String = hud.prayer_key()
	hud.show_prayer_prompt(Prayer.Dir.DOWN, 45)
	check(hud.prayer_key() != k0 and hud.prayer_dir == Prayer.Dir.DOWN, "the prompt changes what the HUD draws")
	hud.show_prayer_prompt(-1, 45)
	check_eq(hud.prayer_left, 0, "no prompt: no bar")


# --- determinism -------------------------------------------------------------------------------------------------

func _check_determinism() -> void:
	var results: Array[String] = []
	for k: int in 2:
		var pr: Prayer = prayer_on(_world)
		var ps: Array[Player] = party(4)
		gather(pr, ps)
		var owners: Array[int] = run_out(pr, ps, "cwlcc2wcl")
		var names: PackedStringArray = []
		for id: int in owners:
			names.append(str(Prayer._find(ps, id).name))
		results.append("%s|%s|%s|%d|%d|%s" % [pr.directions, pr.last.lamps, ",".join(names), pr.last.zeal_pct, pr.clock,
			ps[0].skills.describe()])
	check_eq(results[0], results[1], "the same prayer twice: the same directions, lamps, owners, zeal and clock")
	var pr2: Prayer = prayer_on(_world)
	var ps2: Array[Player] = party(2)
	gather(pr2, ps2)
	var first: PackedInt32Array = pr2.directions
	pr2.stop("test")
	gather(pr2, ps2)
	check(pr2.directions != first, "the next prayer at the altar draws new ones")
	check_eq(pr2.directions, Prayer.directions_for(Prayer.seed_for(Config.DEFAULT_SEED, 2)), "from the world seed and the count")

class_name Combat
extends RefCounted
## Combat rules (M4a, pure functions): the basic attacks of the weapon items, aim codes, hit tests
## (melee arc, line of sight, what stops a shot), the light rule for enemies and the miner's pickaxe
## rule. combat/arena.gd applies them each tick; the offline game (core/main.gd) calls it. Values are
## PROVISIONAL (Config "M4a", README "임시값").
##
## ● gameplay-design §2.1: real-time, aimed at the mouse (skill shots). A basic attack is a weapon
## item's use (left click, M2's rule: the held hotbar item plays its body action; Config.CLASS_WEAPONS
## names each class's). It lands on the weapon's hit frame (Config.WEAPON_ATTACKS) toward the aim the
## action started with (PlayerSim.action_aim, an angle code 0..255 from the feet to the mouse):
## - melee (sword, pickaxe, sickle): every enemy whose feet are within the reach of the attacker's feet,
##   inside the arc around the aim, with no wall or blocking placeable between (body points, line_clear);
## - arrow (bow) and bolt (holy light): a shot from the attacker's body point along the aim at the
##   weapon's speed; it stops at the first blocking tile (walls, wall faces, the altar, the entrance, the
##   stairs, the shrine: what blocks walking, Movement.is_blocked) or enemy, or after its reach.
## Friendly fire is off (Config.FRIENDLY_FIRE): attacks never hurt players.
## The miner's pickaxe is also the mining tool: a swing whose target tile is a wall or a wall's face
## mines it (items/mining.gd) and hits nobody; any other swing is a melee attack and mines nothing.

enum Kind { MELEE, ARROW, BOLT }

const KIND_NAMES: PackedStringArray = ["melee", "arrow", "bolt"]
## Aim codes per full turn (one byte on a future wire, M4b).
const AIM_STEPS: int = 256


## One weapon's basic attack (Config.WEAPON_ATTACKS).
class Attack:
	extends RefCounted
	var item: StringName
	var kind: int = Kind.MELEE
	var damage: int = 0
	var reach: float = 0.0
	var arc_deg: float = 0.0
	var hit_frame: int = 0
	var speed: float = 0.0

	## Ticks a shot flies before it is gone (reach / speed).
	func life_ticks() -> int:
		return ceili(reach / speed * Config.NET_TICK_RATE) if speed > 0.0 else 0


static var _attacks: Dictionary[StringName, Attack] = {}


## The basic attack of weapon item `item`, or null (not a weapon).
static func attack_for(item: StringName) -> Attack:
	if _attacks.is_empty():
		for id: StringName in Config.WEAPON_ATTACKS:
			var row: Array = Config.WEAPON_ATTACKS[id]
			var a: Attack = Attack.new()
			a.item = id
			a.kind = row[0]
			a.damage = row[1]
			a.reach = row[2]
			a.arc_deg = row[3]
			a.hit_frame = row[4]
			a.speed = row[5]
			_attacks[id] = a
	return _attacks.get(item, null)


## The class's weapon item (Config.CLASS_WEAPONS).
static func class_weapon(class_id: String) -> StringName:
	return Config.CLASS_WEAPONS.get(class_id, &"")


## The tick of a body action played with `item` on which it lands: a weapon's hit frame, else (and for
## the pickaxe, whose swing both mines and attacks: one impact) the mining frame (Mining.impact_tick,
## the M3a impact for every tool).
static func impact_tick(item: StringName) -> int:
	var a: Attack = attack_for(item)
	if a == null or item == Mining.PICKAXE:
		return Mining.impact_tick()
	return a.hit_frame * Config.ACTION_FRAME_TICKS


## Aim code (0..255, 0 = east, clockwise on screen) of direction `v`; south for a zero vector.
static func aim_code(v: Vector2) -> int:
	if v == Vector2.ZERO:
		return AIM_STEPS / 4
	return posmod(roundi(atan2(v.y, v.x) / TAU * AIM_STEPS), AIM_STEPS)


## Unit vector of aim code `code`.
static func aim_vector(code: int) -> Vector2:
	return Vector2.from_angle(float(posmod(code, AIM_STEPS)) * TAU / AIM_STEPS)


## The point hit tests measure from: the middle of the feet box (Aim.feet_cell's point).
static func body_point(feet: Vector2) -> Vector2:
	return feet - Vector2(0.0, Config.FEET_HEIGHT / 2.0)


## Whether tile `c` stops a shot and a melee line: outside the map, or what blocks walking (walls and
## faces, the blocking placeables).
static func blocks_line(data: WorldData, c: Vector2i) -> bool:
	return not data.in_bounds(c) or Movement.is_blocked(data, c)


## No blocking tile between `a` and `b` (every tile the segment passes through, both ends' included;
## a grid walk, exact), tiles inside `ignore` not counted (a target's own footprint).
static func line_clear(data: WorldData, a: Vector2, b: Vector2, ignore: Rect2i = Rect2i()) -> bool:
	for c: Vector2i in cells_on_line(a, b):
		if ignore.has_area() and ignore.has_point(c):
			continue
		if blocks_line(data, c):
			return false
	return true


## The tiles segment `a`-`b` passes through, in order (Amanatides & Woo grid traversal).
static func cells_on_line(a: Vector2, b: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var t: float = float(Config.TILE)
	var c: Vector2i = Aim.cell_of(a)
	var end: Vector2i = Aim.cell_of(b)
	out.append(c)
	var d: Vector2 = b - a
	var step: Vector2i = Vector2i(signi(roundi(signf(d.x))), signi(roundi(signf(d.y))))
	var t_max: Vector2 = Vector2(INF, INF)
	var t_delta: Vector2 = Vector2(INF, INF)
	if d.x != 0.0:
		var next_x: float = (c.x + (1 if step.x > 0 else 0)) * t
		t_max.x = (next_x - a.x) / d.x
		t_delta.x = t / absf(d.x)
	if d.y != 0.0:
		var next_y: float = (c.y + (1 if step.y > 0 else 0)) * t
		t_max.y = (next_y - a.y) / d.y
		t_delta.y = t / absf(d.y)
	var guard: int = absi(end.x - c.x) + absi(end.y - c.y) + 2
	while c != end and guard > 0 and minf(t_max.x, t_max.y) < 1.0:
		guard -= 1
		if t_max.x < t_max.y:
			c.x += step.x
			t_max.x += t_delta.x
		else:
			c.y += step.y
			t_max.y += t_delta.y
		out.append(c)
	if c != end:
		out.append(end)  # a segment ending exactly on a tile edge: its end tile is the one under the end point
	return out


## `point` within `reach` of `origin` and inside the `arc_deg` arc around `dir` (a point on the origin
## is inside).
static func in_arc(origin: Vector2, dir: Vector2, point: Vector2, reach: float, arc_deg: float) -> bool:
	var d: Vector2 = point - origin
	if d.length_squared() > reach * reach:
		return false
	if d.length_squared() < 0.0001:
		return true
	return absf(dir.angle_to(d)) <= deg_to_rad(arc_deg) / 2.0 + 0.0001


## A melee hit from feet `from` along `dir` on a target at feet `to`: in the arc and the line between
## the two body points clear.
static func melee_hits(data: WorldData, from: Vector2, dir: Vector2, to: Vector2, reach: float, arc_deg: float) -> bool:
	if not in_arc(from, dir, to, reach, arc_deg):
		return false
	return line_clear(data, body_point(from), body_point(to))


## A melee hit on footprint `rect` (tiles, the shrine): its nearest point to the attacker's body point
## is in the arc and the line to it is clear (the footprint's own tiles not counted).
static func melee_hits_rect(data: WorldData, from: Vector2, dir: Vector2, rect: Rect2i, reach: float, arc_deg: float) -> bool:
	var px: Rect2 = Rect2(Vector2(rect.position * Config.TILE), Vector2(rect.size * Config.TILE))
	var o: Vector2 = body_point(from)
	var near: Vector2 = Vector2(clampf(o.x, px.position.x, px.end.x), clampf(o.y, px.position.y, px.end.y))
	if not in_arc(o, dir, near, reach, arc_deg):
		return false
	return line_clear(data, o, near, rect)


## The miner's rule: a pickaxe swing whose target tile is a wall or a wall's face mines (and hits
## nobody); every other weapon swing is an attack.
static func is_mining_swing(data: WorldData, item: StringName, target: Vector2i) -> bool:
	return item == Mining.PICKAXE and Walls.owner_of(data, target) != Walls.NO_CELL


## The light enemies keep out of (Config.HERETIC_ENTERS_LIGHT false): the altar's safe zone, plus every
## torch's light with Config.TORCH_LIGHT_IS_SAFE (off).
static func in_safe_light(data: WorldData, safe: SafeZone, pos: Vector2) -> bool:
	if safe != null and safe.is_in_safe_zone(pos):
		return true
	if not Config.TORCH_LIGHT_IS_SAFE:
		return false
	var r: float = float(Config.TORCH_LIGHT_RADIUS_PX)
	var c0: Vector2i = Aim.cell_of(pos)
	var reach: int = ceili(r / Config.TILE) + 1
	for y: int in range(c0.y - reach, c0.y + reach + 1):
		for x: int in range(c0.x - reach, c0.x + reach + 1):
			if data.get_value(WorldData.Layer.PLACEABLE, Vector2i(x, y)) == WorldData.PLACEABLE_TORCH:
				var centre: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * Config.TILE
				if centre.distance_squared_to(pos) <= r * r:
					return true
	return false


## The feet box at `feet` lies wholly outside the enemies' light (its four corners and the feet).
static func box_outside_light(data: WorldData, safe: SafeZone, feet: Vector2) -> bool:
	var box: Rect2 = Movement.feet_box(feet)
	for p: Vector2 in [feet, box.position, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), box.end]:
		if in_safe_light(data, safe, p):
			return false
	return true

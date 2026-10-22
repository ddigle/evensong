class_name WorldItems
extends RefCounted
## What lies in the world for F to pick up, and the rules for picking up, dropping, using and giving
## (M2b). Pure functions on WorldData + Inventory: they check a request, change the inventory and
## return the world edits it causes; the caller applies, logs and sends those (the host:
## net/session_host.gd; offline: core/main.gd), so the same rules run on the host and alone.
##
## Gatherables live in the VEGETATION layer: value = 1 + index in GATHERABLES (0 = nothing). Picking
## one up clears the cell (an ordinary layer edit). There is no regrowth (not in the docs).
## Drops are WorldData.drops: any player may pick up any drop and it is theirs (PROVISIONAL, ○
## gameplay-design §5 "드롭은 주운 사람 것"); a drop that does not fit the inventory whole is taken in
## part and the rest stays.
## Grade (● gameplay-design §3.4 / §3.0): a herb the herbalist picks is FINE (상급), anyone else's
## COMMON (일반); other gatherables have no grade (ItemDB).
## Reach (PROVISIONAL, Config.REACH_TILES): pick up, use and drop act on the target tile, one of the
## tiles around the feet tile (not the feet tile itself, ○ gameplay-design §3.2 "인접 타일").
## M3b: going to another map (F on the surface entrance or the dungeon's exit stairs) is travel(): the
## same reach, and the way on that tile names the map (portal_destination). Offline Main and the host
## (net/session_host.gd) both use it; in a session the host moves the player and sends it the map.
## M4a: the death penalty (● gameplay-design §2.6 R12, the partial drop; durability is M7) is
## death_drop(): part of the materials and consumables (every kind but tools) falls in a bag on the
## death spot. The bag is a PLACEABLE_BAG tile (it does not block) holding ordinary drops: the world's
## layers, drops and edits carry it as they are (M4b can send it as it sends the rest). F on a bag tile
## takes every drop on it (anyone may; the bag never goes away by itself: PROVISIONAL, README "임시값").

## Gatherable item ids by VEGETATION value - 1. The wire and the snapshot carry the value, so the
## order only grows at the end.
const GATHERABLES: Array[StringName] = [
	&"wild_healing", &"wild_buff", &"wild_poison", &"herb_clump",
	&"mushroom_a", &"mushroom_b", &"mushroom_c", &"mushroom_d", &"mushroom_ash",
	&"stone_a", &"stone_b", &"stone_c", &"stone_mossy", &"stone_veined", &"stone_mould",
]
## The class whose herbs come out FINE (● gameplay-design §3.4).
const HERB_CLASS: String = "herbalist"
## A give request for this item index gives ItemDB.debug_kit() (F5).
const GIVE_KIT: int = 255

## Why a request was refused (names are what logs and test results count).
const WHY_OUTSIDE: String = "outside the map"
const WHY_REACH: String = "out of reach"
const WHY_NOTHING: String = "nothing there"
const WHY_FULL: String = "inventory full"
const WHY_EMPTY: String = "empty slot"
const WHY_NOT_TOOL: String = "not a tool"
const WHY_BLOCKED: String = "blocked"
const WHY_TOO_MANY: String = "too many drops"
const WHY_BAD_ITEM: String = "unknown item"
const WHY_BAD_SLOT: String = "no such slot"
const WHY_BAD_COUNT: String = "bad count"
## M3a: a torch needs open floor (no wall or wall face, no placeable, no gatherable).
const WHY_NOT_OPEN: String = "not open floor"
const WHY_NOT_PLACEABLE: String = "not placeable"
## M3b: F (pick up) on an entrance or stairs tile: that is a way, not a thing (the F key travels there;
## a PICKUP request on it is refused).
const WHY_PORTAL: String = "a way to another map"
## M3b: a TRAVEL request on a tile with no way to another map.
const WHY_NOT_PORTAL: String = "no way there"
## M3b: a tile request aimed on another map than the one the player is on (frames made before the
## sender heard it had moved, or a forged map id).
const WHY_WRONG_MAP: String = "wrong map"
## M3b: a TRAVEL while the host is still sending the player the map it went to.
const WHY_LOADING: String = "still loading"
## M4a: a death left nothing to drop / no free tile for the bag near the death spot.
const WHY_NOTHING_TO_DROP: String = "nothing to drop"
const WHY_NO_ROOM: String = "no room for a bag"
## M4a: how far (tiles, rings around the death tile) the bag looks for a free tile.
const BAG_SEARCH_TILES: int = 3
## Most of one item a single give request carries (its count is one byte on the wire); a bigger
## debug give from a client goes out as several requests (Main.give_requests).
const GIVE_COUNT_MAX: int = 255


## What a request did: ok, or why not; the world edits to apply (in order) and what moved.
class Outcome:
	extends RefCounted
	var why: String = ""
	var edits: Array[EditLog.WorldEdit] = []
	var item: StringName = &""
	var count: int = 0
	var grade: int = 0

	func ok() -> bool:
		return why.is_empty()

	static func refused(reason: String) -> Outcome:
		var o: Outcome = Outcome.new()
		o.why = reason
		return o


## VEGETATION value of gatherable `id` (0 if it is not one).
static func value_of(id: StringName) -> int:
	return GATHERABLES.find(id) + 1


## The gatherable a VEGETATION value stands for (&"" for 0 or an unknown value).
static func gatherable_for(value: int) -> StringName:
	return GATHERABLES[value - 1] if value >= 1 and value <= GATHERABLES.size() else &""


## The gatherable on tile `c` (&"" for none).
static func gatherable_at(data: WorldData, c: Vector2i) -> StringName:
	return gatherable_for(data.get_value(WorldData.Layer.VEGETATION, c))


## Every gatherable tile, row by row.
static func gatherable_cells(data: WorldData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var plants: PackedByteArray = data.layers[WorldData.Layer.VEGETATION]
	for i: int in plants.size():
		if plants[i] != 0 and not gatherable_for(plants[i]).is_empty():
			out.append(Vector2i(i % data.size.x, i / data.size.x))
	return out


## Grade of `id` picked by a player of `class_id` (● §3.4: the herbalist's herbs are FINE).
static func pick_grade(id: StringName, class_id: String) -> int:
	var def: ItemDB.ItemDef = ItemDB.get_def(id)
	if def == null or not def.graded:
		return ItemDB.Grade.NONE
	return ItemDB.Grade.FINE if class_id == HERB_CLASS else ItemDB.Grade.COMMON


## Whether tile `c` is a target tile for feet at `feet`: within Config.REACH_TILES of the feet tile
## (Aim.feet_cell, Chebyshev) and not the feet tile itself.
static func in_reach(feet: Vector2, c: Vector2i) -> bool:
	var d: Vector2i = (c - Aim.feet_cell(feet)).abs()
	var n: int = maxi(d.x, d.y)
	return n >= 1 and n <= Config.REACH_TILES


## F on tile `c`: the gatherable there, else the lowest-id drop there, into `inv`. M4a: on a death bag
## tile, every drop there (as much as fits; the bag goes when it is empty).
static func pickup(data: WorldData, feet: Vector2, class_id: String, inv: Inventory, c: Vector2i) -> Outcome:
	if not data.in_bounds(c):
		return Outcome.refused(WHY_OUTSIDE)
	if not in_reach(feet, c):
		return Outcome.refused(WHY_REACH)
	if is_portal(data, c):
		return Outcome.refused(WHY_PORTAL)
	if data.get_value(WorldData.Layer.PLACEABLE, c) == WorldData.PLACEABLE_BAG:
		return open_bag(data, inv, c)
	var o: Outcome = Outcome.new()
	var plant: StringName = gatherable_at(data, c)
	if not plant.is_empty():
		var grade: int = pick_grade(plant, class_id)
		if inv.room_for(plant, grade) < 1:
			return Outcome.refused(WHY_FULL)
		inv.add(plant, 1, grade)
		o.item = plant
		o.count = 1
		o.grade = grade
		o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, c, 0))
		return o
	var here: Array[WorldData.Drop] = data.drops_at(c)
	if here.is_empty():
		return Outcome.refused(WHY_NOTHING)
	var d: WorldData.Drop = here[0]
	var n: int = mini(d.count, inv.room_for(d.item, d.grade))
	if n < 1:
		return Outcome.refused(WHY_FULL)
	inv.add(d.item, n, d.grade)
	o.item = d.item
	o.count = n
	o.grade = d.grade
	if n == d.count:
		o.edits.append(EditLog.WorldEdit.drop_remove(d.id))
	else:
		var rest: WorldData.Drop = d.copy()
		rest.count -= n
		o.edits.append(EditLog.WorldEdit.drop_put(rest))
	return o


## M4a: F on the death bag on tile `c`: every drop there into `inv` (lowest id first, each as much as
## fits; the rest stays). The bag tile clears when nothing is left. `item` / `count` = the first item
## taken and how many items in all.
static func open_bag(data: WorldData, inv: Inventory, c: Vector2i) -> Outcome:
	var o: Outcome = Outcome.new()
	var here: Array[WorldData.Drop] = data.drops_at(c)
	var left: int = here.size()
	for d: WorldData.Drop in here:
		var n: int = mini(d.count, inv.room_for(d.item, d.grade))
		if n < 1:
			continue
		inv.add(d.item, n, d.grade)
		if o.item.is_empty():
			o.item = d.item
			o.grade = d.grade
		o.count += n
		if n == d.count:
			o.edits.append(EditLog.WorldEdit.drop_remove(d.id))
			left -= 1
		else:
			var rest: WorldData.Drop = d.copy()
			rest.count -= n
			o.edits.append(EditLog.WorldEdit.drop_put(rest))
	if left == 0:
		o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, c, WorldData.PLACEABLE_NONE))
	elif o.count == 0:
		return Outcome.refused(WHY_FULL)
	return o


## M4a: a free tile for a death bag: on the map, nothing blocking, no placeable, no gatherable, no drop.
static func bag_spot_ok(data: WorldData, c: Vector2i) -> bool:
	return data.in_bounds(c) and not Movement.is_blocked(data, c) \
		and data.get_value(WorldData.Layer.PLACEABLE, c) == WorldData.PLACEABLE_NONE \
		and data.get_value(WorldData.Layer.VEGETATION, c) == 0 and data.drops_at(c).is_empty()


## M4a: the tile the bag of a player dying with feet at `feet` lies on: the feet tile, else the nearest
## free tile within BAG_SEARCH_TILES rings (row by row in a ring), else Walls.NO_CELL.
static func bag_cell(data: WorldData, feet: Vector2) -> Vector2i:
	var f: Vector2i = Aim.feet_cell(feet)
	for r: int in BAG_SEARCH_TILES + 1:
		for y: int in range(f.y - r, f.y + r + 1):
			for x: int in range(f.x - r, f.x + r + 1):
				if maxi(absi(x - f.x), absi(y - f.y)) == r and bag_spot_ok(data, Vector2i(x, y)):
					return Vector2i(x, y)
	return Walls.NO_CELL


## M4a, the death penalty (● gameplay-design §2.6: "인벤토리의 재료·소모품 중 일부가 죽은 자리에 가방으로
## 떨어지고 되찾을 수 있다"; tools, i.e. every weapon and tool, stay): takes part of `inv`'s non-tool stacks
## by `rule` (Config.DEATH_DROP_RULE: half of every stack rounded up, or every stack of
## Config.DEATH_DROP_RANDOM_KINDS item kinds picked with `seed`) and returns the edits that put them in
## a bag on the death tile (bag_cell): the bag tile first, then one drop per stack at the tile's centre.
## At most Config.MAX_DROPS drops lie on a map; what does not fit stays in the inventory, and when not one
## fits there is no bag at all (M4-fix: refused, nothing lost).
static func death_drop(data: WorldData, feet: Vector2, inv: Inventory, rule: int = Config.DEATH_DROP_RULE,
		seed_value: int = 0) -> Outcome:
	var want: Dictionary[int, int] = death_drop_counts(inv, rule, seed_value)
	if want.is_empty():
		return Outcome.refused(WHY_NOTHING_TO_DROP)
	if data.drops.size() >= Config.MAX_DROPS:
		return Outcome.refused(WHY_TOO_MANY)  # M4-fix: not even one drop fits: no empty bag, nothing lost
	var c: Vector2i = bag_cell(data, feet)
	if c == Walls.NO_CELL:
		return Outcome.refused(WHY_NO_ROOM)
	var o: Outcome = Outcome.new()
	o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, c, WorldData.PLACEABLE_BAG))
	var center: Vector2i = c * Config.TILE + Vector2i(Config.TILE / 2, Config.TILE / 2)
	var room: int = Config.MAX_DROPS - data.drops.size()
	var slots: Array[int] = []
	slots.assign(want.keys())
	slots.sort()
	for slot: int in slots:
		if room <= 0:
			break
		var stack: ItemStack = inv.stack_at(slot)
		var n: int = want[slot]
		o.edits.append(EditLog.WorldEdit.drop_put(WorldData.Drop.new(data.new_drop_id(), stack.id, n, stack.grade, center)))
		room -= 1
		if o.item.is_empty():
			o.item = stack.id
			o.grade = stack.grade
		o.count += n
		inv.remove(slot, n)
	return o


## M4a: how many of each inventory slot a death drops (slot -> count, only non-tool stacks), by `rule`.
static func death_drop_counts(inv: Inventory, rule: int, seed_value: int) -> Dictionary[int, int]:
	var out: Dictionary[int, int] = {}
	var kinds: Array[StringName] = []
	for slot: int in inv.size():
		var stack: ItemStack = inv.stack_at(slot)
		if stack == null or stack.def() == null or stack.def().is_tool():
			continue
		if rule == Config.DEATH_DROP_HALF:
			out[slot] = (stack.count + 1) / 2
		elif not kinds.has(stack.id):
			kinds.append(stack.id)
	if rule == Config.DEATH_DROP_HALF:
		return out
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var picked: Array[StringName] = []
	while not kinds.is_empty() and picked.size() < Config.DEATH_DROP_RANDOM_KINDS:
		var k: StringName = kinds.pop_at(rng.randi_range(0, kinds.size() - 1))
		picked.append(k)
	for slot: int in inv.size():
		var stack: ItemStack = inv.stack_at(slot)
		if stack != null and picked.has(stack.id):
			out[slot] = stack.count
	return out


## Debug drop: `count` (0 = all) of the stack in `slot` onto tile `c`, at its centre. Not onto a
## placeable, nor (M3-fix) into a wall or onto a wall's face tile (Walls.blocks, like place()).
static func drop(data: WorldData, feet: Vector2, inv: Inventory, slot: int, count: int, c: Vector2i) -> Outcome:
	if slot < 0 or slot >= inv.size():
		return Outcome.refused(WHY_BAD_SLOT)
	var stack: ItemStack = inv.stack_at(slot)
	if stack == null:
		return Outcome.refused(WHY_EMPTY)
	if not data.in_bounds(c):
		return Outcome.refused(WHY_OUTSIDE)
	if not in_reach(feet, c):
		return Outcome.refused(WHY_REACH)
	if data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_NONE or Walls.blocks(data, c):
		return Outcome.refused(WHY_BLOCKED)
	if data.drops.size() >= Config.MAX_DROPS:
		return Outcome.refused(WHY_TOO_MANY)
	var n: int = stack.count if count <= 0 else mini(count, stack.count)
	var o: Outcome = Outcome.new()
	o.item = stack.id
	o.count = n
	o.grade = stack.grade
	inv.remove(slot, n)
	var center: Vector2i = c * Config.TILE + Vector2i(Config.TILE / 2, Config.TILE / 2)
	o.edits.append(EditLog.WorldEdit.drop_put(WorldData.Drop.new(data.new_drop_id(), o.item, n, o.grade, center)))
	return o


## "Use" with hotbar slot `slot` toward tile `c`: the body action it plays (RigData anim), or -1 and
## `why` set. No world effect yet (mining and farming are later stages).
static func use_action(feet: Vector2, inv: Inventory, slot: int, c: Vector2i, out_why: Array[String] = []) -> int:
	var why: String = ""
	var anim: int = -1
	if slot < 0 or slot >= inv.hotbar_size:
		why = WHY_BAD_SLOT
	elif inv.stack_at(slot) == null:
		why = WHY_EMPTY
	else:
		var def: ItemDB.ItemDef = inv.stack_at(slot).def()
		if def == null or def.action < 0:
			why = WHY_NOT_TOOL
		elif not in_reach(feet, c):
			why = WHY_REACH
		else:
			anim = def.action
	if not why.is_empty():
		out_why.append(why)
	return anim


## M3a: whether tile `c` is a way between maps (the surface entrance or the dungeon's exit stairs).
static func is_portal(data: WorldData, c: Vector2i) -> bool:
	var p: int = data.get_value(WorldData.Layer.PLACEABLE, c)
	return p == WorldData.PLACEABLE_ENTRANCE or p == WorldData.PLACEABLE_EXIT


## M3b: the map the way on tile `c` leads to (the entrance down to the dungeon, the exit stairs up to
## the surface), -1 for no way.
static func portal_destination(data: WorldData, c: Vector2i) -> int:
	match data.get_value(WorldData.Layer.PLACEABLE, c):
		WorldData.PLACEABLE_ENTRANCE:
			return Config.MAP_DUNGEON
		WorldData.PLACEABLE_EXIT:
			return Config.MAP_SURFACE
	return -1


## M3b: F on tile `c` to go to another map: the map it leads to, or -1 and `why` set (outside the map,
## out of reach (PROVISIONAL Config.REACH_TILES: the entrance / stairs must be next to the feet), no
## way there).
static func travel(data: WorldData, feet: Vector2, c: Vector2i, out_why: Array[String] = []) -> int:
	if not data.in_bounds(c):
		out_why.append(WHY_OUTSIDE)
		return -1
	if not in_reach(feet, c):
		out_why.append(WHY_REACH)
		return -1
	var to: int = portal_destination(data, c)
	if to < 0:
		out_why.append(WHY_NOT_PORTAL)
	return to


## M3a: the placeable the stack in `slot` puts down (WorldData.PLACEABLE_NONE: not a placeable item).
static func placeable_in(inv: Inventory, slot: int) -> int:
	if slot < 0 or slot >= inv.size() or inv.stack_at(slot) == null:
		return WorldData.PLACEABLE_NONE
	var def: ItemDB.ItemDef = inv.stack_at(slot).def()
	return def.place if def != null else WorldData.PLACEABLE_NONE


## M3a: "use" with a placeable (the torch) in hotbar slot `slot` on tile `c`: one of it from the
## stack onto the tile (PROVISIONAL rule: in reach, open floor: no wall, no wall face, no placeable,
## no gatherable; drops may lie there).
static func place(data: WorldData, feet: Vector2, inv: Inventory, slot: int, c: Vector2i) -> Outcome:
	if slot < 0 or slot >= inv.hotbar_size:
		return Outcome.refused(WHY_BAD_SLOT)
	var stack: ItemStack = inv.stack_at(slot)
	if stack == null:
		return Outcome.refused(WHY_EMPTY)
	var value: int = placeable_in(inv, slot)
	if value == WorldData.PLACEABLE_NONE:
		return Outcome.refused(WHY_NOT_PLACEABLE)
	if not data.in_bounds(c):
		return Outcome.refused(WHY_OUTSIDE)
	if not in_reach(feet, c):
		return Outcome.refused(WHY_REACH)
	if Walls.blocks(data, c) or data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_NONE \
			or data.get_value(WorldData.Layer.VEGETATION, c) != 0:
		return Outcome.refused(WHY_NOT_OPEN)
	var o: Outcome = Outcome.new()
	o.item = stack.id
	o.count = 1
	inv.remove(slot, 1)
	o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, c, value))
	return o


## Debug give: `count` of item `index` (GIVE_KIT = the debug kit) at `grade` (-1 = default).
static func give(inv: Inventory, index: int, count: int, grade: int) -> Outcome:
	var o: Outcome = Outcome.new()
	if index == GIVE_KIT:
		for entry: Array in ItemDB.debug_kit():
			var id: StringName = entry[0]
			var n: int = entry[1]
			var g: int = entry[2] if entry.size() > 2 else -1
			inv.add(id, n, g)
			o.count += n
		o.item = &"debug_kit"
		return o
	var item: StringName = ItemDB.id_at(index)
	if item.is_empty():
		return Outcome.refused(WHY_BAD_ITEM)
	if count < 1:
		return Outcome.refused(WHY_BAD_COUNT)
	var g2: int = ItemDB.normalize_grade(item, grade)
	o.item = item
	o.grade = g2
	o.count = count - inv.add(item, count, g2)
	if o.count == 0:
		return Outcome.refused(WHY_FULL)
	return o

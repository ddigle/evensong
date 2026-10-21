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


## F on tile `c`: the gatherable there, else the lowest-id drop there, into `inv`.
static func pickup(data: WorldData, feet: Vector2, class_id: String, inv: Inventory, c: Vector2i) -> Outcome:
	if not data.in_bounds(c):
		return Outcome.refused(WHY_OUTSIDE)
	if not in_reach(feet, c):
		return Outcome.refused(WHY_REACH)
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


## Debug drop: `count` (0 = all) of the stack in `slot` onto tile `c`, at its centre.
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
	if data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_NONE:
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

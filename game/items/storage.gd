class_name Storage
extends RefCounted
## M7a: the shared storage chest (○ gameplay-design §5 "공유 창고: 제단 옆. 개인 인벤토리는 각자"; PROVISIONAL README "임시값"
## M7a 공유 창고). Pure functions on WorldData + Inventory, like items/world_items.gd.
##
## The chest is a placeable (WorldData.PLACEABLE_CHEST, Config.CHEST_FOOTPRINT, it blocks) put down like the alchemy table
## (WorldItems.place: open floor, nobody's feet, not where players appear, not touching another chest) and, with
## Config.CHEST_ONLY_IN_LIGHT, only with its whole footprint inside the altar's light (in_light: the field rule). It stays
## where it is when the altar moves; nothing takes it away again (like the stations). Its contents are the map's
## (WorldData.chests by footprint), Config.CHEST_SLOTS slots, stacks keeping their durability.
## F aimed at a chest tile in reach opens it (Main: the chest panel next to the inventory); while open the player stands.
## A click on an inventory slot stores that stack, a click on a chest slot takes it (store / take): onto stacks of the
## same item and grade first (items with durability never stack), then the first empty slots; what does not fit stays
## where it was (a partial move); nothing fits = refused, nothing changes. Walking away is impossible while it is open;
## going down, another map or the chest gone closes it (still_at).

const WHY_NO_CHEST: String = "no chest there"
const WHY_LIGHT: String = "outside the light"
const WHY_CHEST_FULL: String = "chest full"
const WHY_FULL: String = "inventory full"
const WHY_EMPTY: String = "empty slot"
const WHY_REACH: String = "out of reach"
## M7a: a session refuses the chest until M7c.
const WHY_OFFLINE: String = "storage offline only"


## What a move did: how many of which item went over (0 = refused, `why` says why).
class Moved:
	extends RefCounted
	var why: String = ""
	var item: StringName = &""
	var count: int = 0
	var left: int = 0

	func ok() -> bool:
		return why.is_empty()


## Whether footprint `rect` lies wholly in the altar's light on `data` (every tile's four corners in the safe zone,
## Farming.in_light; no altar = no light).
static func in_light(data: WorldData, rect: Rect2i) -> bool:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if not Farming.in_light(data, Vector2i(x, y)):
				return false
	return true


## The chest footprint F on tile `c` opens for feet at `feet` (an empty rect when `c` is no chest tile or not in reach).
static func chest_for(data: WorldData, feet: Vector2, c: Vector2i) -> Rect2i:
	if data == null or data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_CHEST:
		return Rect2i()
	if not WorldItems.in_reach(feet, c):
		return Rect2i()
	return data.footprint_at(c)


## Whether the chest on footprint `rect` is still there and feet `feet` within Config.STATION_REACH_TILES of it.
static func still_at(data: WorldData, feet: Vector2, rect: Rect2i) -> bool:
	if data == null or not rect.has_area() or data.get_value(WorldData.Layer.PLACEABLE, rect.position) != WorldData.PLACEABLE_CHEST:
		return false
	if data.footprint_at(rect.position) != rect:
		return false
	return Crafting.tiles_to(Aim.feet_cell(feet), rect) <= Config.STATION_REACH_TILES


## How many of `stack` fit into `slots` (same item and grade stacks with room, then empty slots).
static func room_in(slots: Array[ItemStack], stack: ItemStack) -> int:
	if stack == null or stack.def() == null:
		return 0
	var n: int = 0
	for s: ItemStack in slots:
		if s == null:
			n += stack.max_count()
		elif stack.max_durability() <= 0 and s.same_kind(stack.id, stack.grade):
			n += s.room()
	return n


## Puts `count` of `stack` into `slots` (merging first, durability kept). Returns how many went in.
static func put_in(slots: Array[ItemStack], stack: ItemStack, count: int) -> int:
	var left: int = count
	if stack.max_durability() <= 0:
		for s: ItemStack in slots:
			if left == 0:
				break
			if s != null and s.same_kind(stack.id, stack.grade) and s.room() > 0:
				var n: int = mini(left, s.room())
				s.count += n
				left -= n
	for i: int in slots.size():
		if left == 0:
			break
		if slots[i] == null:
			var n2: int = mini(left, stack.max_count())
			slots[i] = ItemStack.new(stack.id, n2, stack.grade, stack.durability)
			left -= n2
	return count - left


## Stores inventory slot `slot` of `inv` in `chest` (as much as fits; the rest stays in the slot).
static func store(chest: WorldData.Chest, inv: Inventory, slot: int) -> Moved:
	var m: Moved = Moved.new()
	if chest == null:
		m.why = WHY_NO_CHEST
		return m
	var s: ItemStack = inv.stack_at(slot)
	if s == null:
		m.why = WHY_EMPTY
		return m
	var n: int = mini(s.count, room_in(chest.slots, s))
	if n < 1:
		m.why = WHY_CHEST_FULL
		return m
	put_in(chest.slots, s, n)
	m.item = s.id
	m.count = n
	m.left = s.count - n
	inv.remove(slot, n)
	return m


## Takes chest slot `chest_slot` of `chest` into `inv` (as much as fits; the rest stays in the chest).
static func take(chest: WorldData.Chest, inv: Inventory, chest_slot: int) -> Moved:
	var m: Moved = Moved.new()
	if chest == null:
		m.why = WHY_NO_CHEST
		return m
	var s: ItemStack = chest.slots[chest_slot] if chest_slot >= 0 and chest_slot < chest.slots.size() else null
	if s == null:
		m.why = WHY_EMPTY
		return m
	var n: int = mini(s.count, inv.room_for_stack(s))
	if n < 1:
		m.why = WHY_FULL
		return m
	var part: ItemStack = ItemStack.new(s.id, n, s.grade, s.durability)
	var left: int = inv.add_stack(part)
	assert(left == 0, "room_for_stack checked the room")
	m.item = s.id
	m.count = n
	s.count -= n
	m.left = s.count
	if s.count == 0:
		chest.slots[chest_slot] = null
	return m

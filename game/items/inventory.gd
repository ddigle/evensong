class_name Inventory
extends RefCounted
## One player's inventory (M2a, local: not sent over the network yet). Slots hold ItemStacks or
## null; the first `hotbar_size` slots are the hotbar (gameplay-design §1 ○: weapons and tools are
## switched on the hotbar, Q / E left / right). Sizes: Config.INVENTORY_SLOTS / HOTBAR_SLOTS
## (PROVISIONAL, not in the docs).
##
## Rules (IMPL):
## - add: fills stacks of the same item and grade first (slot order, so the hotbar first), then the
##   first empty slots; returns what did not fit. Ungraded items ignore the grade, graded ones default
##   to COMMON (ItemDB.normalize_grade).
## - split: moves part of a stack to the first empty slot; nothing happens when the inventory is full.
## - move: onto an empty slot moves, onto the same item and grade merges what fits, otherwise swaps.

signal changed

var slots: Array[ItemStack] = []
var hotbar_size: int
## Selected hotbar slot (0..hotbar_size - 1).
var selected: int = 0


func _init(size: int = Config.INVENTORY_SLOTS, hotbar: int = Config.HOTBAR_SLOTS) -> void:
	slots.resize(maxi(size, 1))
	hotbar_size = clampi(hotbar, 1, slots.size())


func size() -> int:
	return slots.size()


## The stack in `slot`, or null (empty or out of range).
func stack_at(slot: int) -> ItemStack:
	if slot < 0 or slot >= slots.size():
		return null
	return slots[slot]


func is_empty_slot(slot: int) -> bool:
	return stack_at(slot) == null


func free_slots() -> int:
	var n: int = 0
	for s: ItemStack in slots:
		if s == null:
			n += 1
	return n


## How many of `id` at `grade` would still fit.
func room_for(id: StringName, grade: int = -1) -> int:
	var def: ItemDB.ItemDef = ItemDB.get_def(id)
	if def == null:
		return 0
	var g: int = ItemDB.normalize_grade(id, grade)
	var n: int = 0
	for s: ItemStack in slots:
		if s == null:
			n += def.stack_max
		elif s.same_kind(id, g):
			n += s.room()
	return n


## Adds `count` of `id`; returns how many did not fit (unknown items: all of them).
func add(id: StringName, count: int, grade: int = -1) -> int:
	var def: ItemDB.ItemDef = ItemDB.get_def(id)
	if def == null:
		return maxi(count, 0)
	if count <= 0:
		return 0
	var g: int = ItemDB.normalize_grade(id, grade)
	var left: int = count
	for s: ItemStack in slots:
		if left == 0:
			break
		if s != null and s.same_kind(id, g) and s.room() > 0:
			var n: int = mini(left, s.room())
			s.count += n
			left -= n
	for i: int in slots.size():
		if left == 0:
			break
		if slots[i] == null:
			var n: int = mini(left, def.stack_max)
			slots[i] = ItemStack.new(id, n, g)
			left -= n
	if left != count:
		changed.emit()
	return left


## Removes up to `count` from `slot`; returns how many were removed.
func remove(slot: int, count: int) -> int:
	var s: ItemStack = stack_at(slot)
	if s == null or count <= 0:
		return 0
	var n: int = mini(count, s.count)
	s.count -= n
	if s.count == 0:
		slots[slot] = null
	changed.emit()
	return n


## Moves `amount` (1 .. count - 1) of the stack in `slot` to the first empty slot. Returns that
## slot, or -1 (nothing changed: empty slot, bad amount, no empty slot).
func split(slot: int, amount: int) -> int:
	var s: ItemStack = stack_at(slot)
	if s == null or amount < 1 or amount >= s.count:
		return -1
	var to: int = slots.find(null)
	if to < 0:
		return -1
	s.count -= amount
	slots[to] = ItemStack.new(s.id, amount, s.grade)
	changed.emit()
	return to


## Splits off half (rounded down) of the stack in `slot`.
func split_half(slot: int) -> int:
	var s: ItemStack = stack_at(slot)
	return split(slot, s.count / 2) if s != null else -1


## Moves the stack in `from` onto `to` (see the class comment). False if nothing changed.
func move(from: int, to: int) -> bool:
	var a: ItemStack = stack_at(from)
	if a == null or from == to or to < 0 or to >= slots.size():
		return false
	var b: ItemStack = slots[to]
	if b == null:
		slots[to] = a
		slots[from] = null
	elif b.same_kind(a.id, a.grade):
		var n: int = mini(a.count, b.room())
		if n == 0:
			return false
		b.count += n
		a.count -= n
		if a.count == 0:
			slots[from] = null
	else:
		slots[to] = a
		slots[from] = b
	changed.emit()
	return true


## Total count of `id` (any grade when `grade` is -1).
func count_of(id: StringName, grade: int = -1) -> int:
	var n: int = 0
	for s: ItemStack in slots:
		if s != null and s.id == id and (grade < 0 or s.grade == grade):
			n += s.count
	return n


func clear() -> void:
	for i: int in slots.size():
		slots[i] = null
	changed.emit()


## Selects hotbar slot `slot` (ignored outside the hotbar).
func select(slot: int) -> void:
	if slot < 0 or slot >= hotbar_size or slot == selected:
		return
	selected = slot
	changed.emit()


## Moves the selection by `step` slots, wrapping around the hotbar (Q = -1, E = +1).
func select_offset(step: int) -> void:
	select(posmod(selected + step, hotbar_size))


func selected_stack() -> ItemStack:
	return stack_at(selected)


## Body action of the selected item (RigData anim), or -1.
func selected_action() -> int:
	var s: ItemStack = selected_stack()
	if s == null:
		return -1
	var d: ItemDB.ItemDef = s.def()
	return d.action if d != null else -1


## Takes every slot and the selection from elsewhere (a client: its inventory as the host sent it,
## M2b). Stacks are copied; slots beyond `stacks` become empty.
func load_state(stacks: Array[ItemStack], p_selected: int) -> void:
	for i: int in slots.size():
		var st: ItemStack = stacks[i] if i < stacks.size() else null
		slots[i] = st.copy() if st != null else null
	selected = clampi(p_selected, 0, hotbar_size - 1)
	changed.emit()


## One line per used slot, for logs and tests.
func describe() -> String:
	var parts: PackedStringArray = []
	for i: int in slots.size():
		if slots[i] != null:
			parts.append("%d:%s" % [i, str(slots[i])])
	return ", ".join(parts)

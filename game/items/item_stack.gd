class_name ItemStack
extends RefCounted
## Some of one item in one inventory slot: id, count (1..stack_max) and grade (ItemDB.Grade).
## M7a: `durability` = the points an item with durability has left (ItemDB.ItemDef.durability is its full value: the
## tier-1 gear, Config.GEAR_DURABILITY; 0 for every other item). Such items stack one to a slot, so stacks never mix
## two durabilities. Not on the wire yet (M7c): a session has no wear in M7a.

var id: StringName
var count: int
var grade: int
var durability: int = 0


## `p_durability` -1 = full (the item's ItemDef.durability).
func _init(p_id: StringName, p_count: int, p_grade: int, p_durability: int = -1) -> void:
	id = p_id
	count = p_count
	grade = p_grade
	var full: int = max_durability()
	durability = full if p_durability < 0 else clampi(p_durability, 0, full)


func def() -> ItemDB.ItemDef:
	return ItemDB.get_def(id)


func max_count() -> int:
	var d: ItemDB.ItemDef = def()
	return d.stack_max if d != null else 1


## M7a: the item's full durability (0 = it has none).
func max_durability() -> int:
	var d: ItemDB.ItemDef = def()
	return d.durability if d != null else 0


## M7a: the item has durability and less than full.
func worn() -> bool:
	return max_durability() > 0 and durability < max_durability()


## M7a: the item has durability and none left.
func broken() -> bool:
	return max_durability() > 0 and durability <= 0


## More of `p_id` at `p_grade` may join this stack (same item and grade).
func same_kind(p_id: StringName, p_grade: int) -> bool:
	return id == p_id and grade == p_grade


func room() -> int:
	return max_count() - count


func copy() -> ItemStack:
	return ItemStack.new(id, count, grade, durability)


func _to_string() -> String:
	var dur: String = "" if max_durability() <= 0 or not worn() else " [%d/%d]" % [durability, max_durability()]
	return "%s x%d%s%s" % [id, count, "" if grade == ItemDB.Grade.NONE else " (%s)" % ItemDB.GRADE_NAMES[grade], dur]

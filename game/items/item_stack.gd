class_name ItemStack
extends RefCounted
## Some of one item in one inventory slot: id, count (1..stack_max) and grade (ItemDB.Grade).

var id: StringName
var count: int
var grade: int


func _init(p_id: StringName, p_count: int, p_grade: int) -> void:
	id = p_id
	count = p_count
	grade = p_grade


func def() -> ItemDB.ItemDef:
	return ItemDB.get_def(id)


func max_count() -> int:
	var d: ItemDB.ItemDef = def()
	return d.stack_max if d != null else 1


## More of `p_id` at `p_grade` may join this stack (same item and grade).
func same_kind(p_id: StringName, p_grade: int) -> bool:
	return id == p_id and grade == p_grade


func room() -> int:
	return max_count() - count


func copy() -> ItemStack:
	return ItemStack.new(id, count, grade)


func _to_string() -> String:
	return "%s x%d%s" % [id, count, "" if grade == ItemDB.Grade.NONE else " (%s)" % ItemDB.GRADE_NAMES[grade]]

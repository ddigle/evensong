class_name Crafting
extends RefCounted
## M6a: crafting (○ gameplay-design §3.5 "작업대 근처에서 Tab"): stations, recipes and the craft rule, pure
## functions on WorldData + Inventory like items/world_items.gd, so M6b's host and M7's workbench, anvil and
## relic bench use the same frame (a station kind per placeable fixture, recipes per station). M6b: a session's
## craft is a CRAFT request (the recipe's index, recipe_at) that the host checks with station_near on its own
## data and position of the player and craft() on the player's inventory (net/session_host.gd).
##
## Station: a placeable fixture whose WorldData value is in STATION_OF; a player is at it while its feet tile
## is within Config.STATION_REACH_TILES (Chebyshev) of the footprint (station_near). M6a has one, the alchemy
## table (○ game-concept §9.7, gameplay-design §3.8 "조제대"), WorldData.PLACEABLE_ALCHEMY.
## Recipe: inputs (item, count, grade: an exact grade, or -1 = any) -> one output stack (item, count, grade),
## and the classes that may craft it (empty = anyone). M6a's recipes are the three potions (● game-concept
## §12 R28: one per crop) from the wild herbs (farmed crops are M5), Config.POTION_HERBS of one herb for one
## potion, one recipe per grade: COMMON herbs make a COMMON potion, FINE herbs a FINE one (the grade follows
## the inputs). Who may brew (● gameplay-design §3.0 R11 herbalist row "상급·최상급 약제, 상태이상 약제" are
## the herbalist's): every FINE potion and the poison potion (the status potion) only the herbalist; the
## COMMON healing and buff potions anyone (Config.COMMON_POTIONS_ANYONE, PROVISIONAL).
## Unlock (○ §3.5 "레시피는 재료를 처음 획득했을 때 해금"): with Config.RECIPES_UNLOCK_ON_FIRST_GET a recipe shows
## once the player has had each of its input items (any grade) in its inventory (Inventory.seen).
## A craft is atomic (craft): the class may, every input is there, and the output fits once the inputs are
## out; then the inputs leave (from the last slots first, so hotbar stacks stay longest) and the output goes
## in. Anything missing refuses it and changes nothing (PROVISIONAL: no room = refused, nothing dropped).

## Station kinds (M7 adds the workbench, the anvil, the relic bench).
const ALCHEMY: StringName = &"alchemy"
## The station each placeable fixture is.
const STATION_OF: Dictionary[int, StringName] = {WorldData.PLACEABLE_ALCHEMY: ALCHEMY}
## The class the ● §3.0 herbalist-only potions need.
const HERB_CLASS: String = "herbalist"

const WHY_NO_STATION: String = "no station"
const WHY_LOCKED: String = "locked"
const WHY_CLASS: String = "herbalist only"
const WHY_MISSING: String = "missing inputs"
const WHY_NO_ROOM: String = "no room"
const WHY_BAD_RECIPE: String = "no such recipe"


## One input of a recipe: `count` of `item` at `grade` (-1 = any grade).
class Ingredient:
	extends RefCounted
	var item: StringName
	var count: int
	var grade: int

	func _init(p_item: StringName, p_count: int, p_grade: int = -1) -> void:
		item = p_item
		count = p_count
		grade = p_grade


class Recipe:
	extends RefCounted
	var id: StringName
	var station: StringName
	var inputs: Array[Ingredient] = []
	var output: StringName
	var out_count: int = 1
	var out_grade: int = ItemDB.Grade.NONE
	## Classes that may craft it (empty = anyone).
	var classes: PackedStringArray = []

	func allows(class_id: String) -> bool:
		return classes.is_empty() or classes.has(class_id)

	func describe() -> String:
		var parts: PackedStringArray = []
		for i: Ingredient in inputs:
			parts.append("%s x%d%s" % [i.item, i.count, "" if i.grade < 0 else " (%s)" % ItemDB.GRADE_NAMES[i.grade]])
		return "%s: %s -> %s x%d (%s)" % [id, ", ".join(parts), output, out_count, ItemDB.GRADE_NAMES[out_grade]]


## A station a player stands at: its kind and footprint.
class StationAt:
	extends RefCounted
	var kind: StringName
	var rect: Rect2i
	var map: int = Config.MAP_SURFACE

	func same_as(o: StationAt) -> bool:
		return o != null and kind == o.kind and rect == o.rect and map == o.map


## What a craft did: ok, or why not; the output it made.
class Outcome:
	extends RefCounted
	var why: String = ""
	var item: StringName = &""
	var count: int = 0
	var grade: int = 0

	func ok() -> bool:
		return why.is_empty()


static var _recipes: Array[Recipe] = []


## Every recipe, in panel order (per station: healing, buff, poison; COMMON then FINE).
static func recipes() -> Array[Recipe]:
	if _recipes.is_empty():
		var herbs: Array[StringName] = [&"wild_healing", &"wild_buff", &"wild_poison"]
		var potions: Array[StringName] = [&"potion_healing", &"potion_buff", &"potion_poison"]
		for i: int in herbs.size():
			for grade: int in [ItemDB.Grade.COMMON, ItemDB.Grade.FINE]:
				var r: Recipe = Recipe.new()
				r.id = StringName("%s_%s" % [potions[i], ItemDB.GRADE_NAMES[grade]])
				r.station = ALCHEMY
				r.inputs.append(Ingredient.new(herbs[i], Config.POTION_HERBS, grade))
				r.output = potions[i]
				r.out_grade = grade
				r.classes = herbalist_only(potions[i], grade)
				_recipes.append(r)
	return _recipes.duplicate()


## ● gameplay-design §3.0 R11 herbalist row: FINE potions and the status (poison) potion are the herbalist's;
## the COMMON healing and buff potions anyone's while Config.COMMON_POTIONS_ANYONE (PROVISIONAL).
static func herbalist_only(potion: StringName, grade: int) -> PackedStringArray:
	if grade == ItemDB.Grade.FINE or Potions.effect_of(potion) == Potions.Effect.POISON or not Config.COMMON_POTIONS_ANYONE:
		return PackedStringArray([HERB_CLASS])
	return PackedStringArray()


static func recipe(id: StringName) -> Recipe:
	for r: Recipe in recipes():
		if r.id == id:
			return r
	return null


## M6b: how many recipes there are (a CRAFT request's index is below it) and recipe `id`'s index (-1 = none).
static func recipe_count() -> int:
	if _recipes.is_empty():
		recipes()
	return _recipes.size()


static func index_of(id: StringName) -> int:
	if _recipes.is_empty():
		recipes()
	for i: int in _recipes.size():
		if _recipes[i].id == id:
			return i
	return -1


## M6b: recipe number `index` (a CRAFT request's), or null.
static func recipe_at(index: int) -> Recipe:
	if _recipes.is_empty():
		recipes()
	return _recipes[index] if index >= 0 and index < _recipes.size() else null


## The recipes of station `kind`, in order.
static func recipes_for(kind: StringName) -> Array[Recipe]:
	var out: Array[Recipe] = []
	for r: Recipe in recipes():
		if r.station == kind:
			out.append(r)
	return out


## Whether `inv`'s player has unlocked recipe `r` (Config.RECIPES_UNLOCK_ON_FIRST_GET: had every input item).
static func unlocked(r: Recipe, inv: Inventory) -> bool:
	if not Config.RECIPES_UNLOCK_ON_FIRST_GET:
		return true
	for i: Ingredient in r.inputs:
		if not inv.has_seen(i.item):
			return false
	return true


## The recipes of station `kind` the panel shows for `inv` (the unlocked ones, in order).
static func shown_recipes(kind: StringName, inv: Inventory) -> Array[Recipe]:
	var out: Array[Recipe] = []
	for r: Recipe in recipes_for(kind):
		if unlocked(r, inv):
			out.append(r)
	return out


## The station value of placeable `p` (&"" for none).
static func station_kind(p: int) -> StringName:
	return STATION_OF.get(p, &"")


## Chebyshev distance in tiles from tile `c` to footprint `rect` (0 = inside).
static func tiles_to(c: Vector2i, rect: Rect2i) -> int:
	var dx: int = maxi(maxi(rect.position.x - c.x, c.x - (rect.end.x - 1)), 0)
	var dy: int = maxi(maxi(rect.position.y - c.y, c.y - (rect.end.y - 1)), 0)
	return maxi(dx, dy)


## The nearest station a player with feet at `feet` stands at (its feet tile within
## Config.STATION_REACH_TILES of the footprint), or null.
static func station_near(data: WorldData, feet: Vector2) -> StationAt:
	if data == null:
		return null
	var f: Vector2i = Aim.feet_cell(feet)
	var reach: int = Config.STATION_REACH_TILES
	var best: StationAt = null
	var best_d: int = reach + 1
	var big: int = maxi(Config.ALCHEMY_FOOTPRINT.x, Config.ALCHEMY_FOOTPRINT.y)
	for y: int in range(f.y - reach - big, f.y + reach + big + 1):
		for x: int in range(f.x - reach - big, f.x + reach + big + 1):
			var c: Vector2i = Vector2i(x, y)
			var kind: StringName = station_kind(data.get_value(WorldData.Layer.PLACEABLE, c))
			if kind.is_empty():
				continue
			var rect: Rect2i = data.footprint_at(c)
			if rect.position != c:
				continue  # one look per footprint, from its top-left tile
			var d: int = tiles_to(f, rect)
			if d < best_d:
				best_d = d
				best = StationAt.new()
				best.kind = kind
				best.rect = rect
				best.map = data.map_id
	return best


## Whether the station `at` is still there and `feet` still at it (the panel closes otherwise).
static func still_at(data: WorldData, feet: Vector2, at: StationAt) -> bool:
	var now: StationAt = station_near(data, feet)
	return now != null and data.map_id == at.map and now.kind == at.kind and now.rect == at.rect


## How many of `item` at `grade` (-1 = any) `inv` holds.
static func have(inv: Inventory, item: StringName, grade: int) -> int:
	return inv.count_of(item, grade)


## Why a player of `class_id` with `inv` may not craft `r` now ("" = it may). Checks the class, the inputs
## and the room for the output after the inputs are out.
static func refusal(r: Recipe, class_id: String, inv: Inventory) -> String:
	if r == null:
		return WHY_BAD_RECIPE
	if not unlocked(r, inv):
		return WHY_LOCKED
	if not r.allows(class_id):
		return WHY_CLASS
	for i: Ingredient in r.inputs:
		if have(inv, i.item, i.grade) < i.count:
			return WHY_MISSING
	var trial: Inventory = copy_of(inv)
	_take_inputs(r, trial)
	if trial.room_for(r.output, r.out_grade) < r.out_count:
		return WHY_NO_ROOM
	return ""


## Crafts `r` for a player of `class_id` from `inv`, all or nothing (see the class comment).
static func craft(r: Recipe, class_id: String, inv: Inventory) -> Outcome:
	var o: Outcome = Outcome.new()
	o.why = refusal(r, class_id, inv)
	if not o.ok():
		return o
	_take_inputs(r, inv)
	var left: int = inv.add(r.output, r.out_count, r.out_grade)
	assert(left == 0, "refusal() checked the room")
	o.item = r.output
	o.count = r.out_count
	o.grade = r.out_grade
	return o


## Takes `r`'s inputs out of `inv` (checked before): each from the last matching slot first.
static func _take_inputs(r: Recipe, inv: Inventory) -> void:
	for i: Ingredient in r.inputs:
		var need: int = i.count
		for slot: int in range(inv.size() - 1, -1, -1):
			if need == 0:
				break
			var s: ItemStack = inv.stack_at(slot)
			if s != null and s.id == i.item and (i.grade < 0 or s.grade == i.grade):
				need -= inv.remove(slot, mini(need, s.count))


## A detached copy of `inv` (stacks, selection, what it has seen) to try a craft on.
static func copy_of(inv: Inventory) -> Inventory:
	var c: Inventory = Inventory.new(inv.size(), inv.hotbar_size)
	c.load_state(inv.slots, inv.selected)
	c.seen = inv.seen.duplicate()
	return c

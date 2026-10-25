class_name Crafting
extends RefCounted
## M6a: crafting (○ gameplay-design §3.5 "작업대 근처에서 Tab"): stations, recipes and the craft rule, pure
## functions on WorldData + Inventory like items/world_items.gd, so M6b's host and M7's workbench, anvil and
## relic bench use the same frame (a station kind per placeable fixture, recipes per station). M6b: a session's
## craft is a CRAFT request (the recipe's index, recipe_at) that the host checks with station_of_kind_near (M6-fix:
## a station of the recipe's kind within reach, whatever is nearer) on its own data and position of the player and
## craft() on the player's inventory (net/session_host.gd).
## M6-fix, what a new station still needs besides its STATION_OF / STATION_ICON / WorldItems.FOOTPRINT_OF entries and
## its recipes (README "제작 틀"): its art in world/fixture_view.gd (tables only so far), the panel's rows
## (ui/crafting_panel.gd draws one input per row and one class mark, the herbalist's pouch) and its place / scroll.
## (M7a did all three: FixtureView draws every station, the panel draws up to three inputs a row and scrolls.)
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
##
## M7a, the workbench chain (○ gameplay-design §3.5 "기본 작업대 → 모루(대장간) → 성물 제작대"; the slice's "2~3단계" ●
## game-concept §12; PROVISIONAL README "임시값" M7a 작업대 체인): three more stations, the basic workbench, the anvil and the
## relic bench (WorldData.PLACEABLE_WORKBENCH / ANVIL / RELIC), and hand recipes (HAND: no station; Main opens them with Tab
## away from every station once one is unlocked, offline). Their recipes are Config.STATION_RECIPES (anyone may craft
## them: ● §3.5 tier 1 is anyone's at the anvil, and nothing else in the chain is a class's), appended after the potions so
## a CRAFT request's index (M6b) keeps its meaning. Each station is made at the one before it (the workbench by hand).
## Repair recipes (one per item with durability, at the anvil, Config.GEAR_REPAIR_MATERIAL): one material gives the most
## worn one of that item the player carries its full durability back (Gear.most_worn; nothing worn = refused, "nothing to
## repair"); they show only while there is something to repair. A session refuses every M7 recipe until M7c (WHY_OFFLINE).
## M7b: the build pieces at the basic workbench and the axe by hand (Config.BUILD_RECIPES, PROVISIONAL README "임시값" M7b),
## appended after the repairs (26..30), anyone's.

## Station kinds. M7a: the workbench, the anvil, the relic bench, and HAND (no station).
const ALCHEMY: StringName = &"alchemy"
const WORKBENCH: StringName = &"workbench"
const ANVIL: StringName = &"anvil"
const RELIC: StringName = &"relic"
const HAND: StringName = &"hand"
## The station each placeable fixture is (its footprint: WorldItems.FOOTPRINT_OF).
const STATION_OF: Dictionary[int, StringName] = {WorldData.PLACEABLE_ALCHEMY: ALCHEMY,
	WorldData.PLACEABLE_WORKBENCH: WORKBENCH, WorldData.PLACEABLE_ANVIL: ANVIL, WorldData.PLACEABLE_RELIC: RELIC}
## M6-fix: the item whose icon heads each station's crafting panel (ui/crafting_panel.gd). M7a: the hand panel's is the log.
const STATION_ICON: Dictionary[StringName, StringName] = {ALCHEMY: &"alchemy_table", WORKBENCH: &"workbench",
	ANVIL: &"anvil", RELIC: &"relic_bench", HAND: &"log"}
## The class the ● §3.0 herbalist-only potions need.
const HERB_CLASS: String = "herbalist"

const WHY_NO_STATION: String = "no station"
const WHY_LOCKED: String = "locked"
## The refusal of a recipe only the herbalist may craft (M6-fix: Recipe.class_refusal makes it from the classes).
const WHY_CLASS: String = "herbalist only"
const WHY_MISSING: String = "missing inputs"
const WHY_NO_ROOM: String = "no room"
const WHY_BAD_RECIPE: String = "no such recipe"
## M7a: a repair recipe with no worn item of its kind; a session's M7 recipe or station (until M7c).
const WHY_NOTHING_TO_REPAIR: String = "nothing to repair"
const WHY_OFFLINE: String = "workbench chain offline only"


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
	## M7a: a repair recipe's item (&"" = an ordinary recipe): its input is the material, its output that item restored.
	var repair: StringName = &""

	func allows(class_id: String) -> bool:
		return classes.is_empty() or classes.has(class_id)

	func is_repair() -> bool:
		return not repair.is_empty()

	## M6-fix: why another class may not craft it ("<class>[/<class>...] only"; WHY_CLASS for the herbalist's).
	func class_refusal() -> String:
		return "%s only" % "/".join(classes)

	func describe() -> String:
		var parts: PackedStringArray = []
		for i: Ingredient in inputs:
			parts.append("%s x%d%s" % [i.item, i.count, "" if i.grade < 0 else " (%s)" % ItemDB.GRADE_NAMES[i.grade]])
		if is_repair():
			return "%s: %s -> %s repaired" % [id, ", ".join(parts), repair]
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


## Every recipe, in panel order (per station: healing, buff, poison; COMMON then FINE). M7a: then the workbench chain's
## (Config.STATION_RECIPES order) and the repairs.
static func recipes() -> Array[Recipe]:
	if _recipes.is_empty():
		_build_potions()
		_build_chain()
	return _recipes.duplicate()


static func _build_potions() -> void:
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


## M7a: the workbench chain's recipes (Config.STATION_RECIPES, anyone's), then one repair recipe per item with durability
## (at the anvil, Config.GEAR_REPAIR_MATERIAL), after the potions (a CRAFT index of M6b keeps its meaning).
static func _build_chain() -> void:
	_add_rows(Config.STATION_RECIPES)
	for item: StringName in Config.GEAR_REPAIR_MATERIAL:
		var rr: Recipe = Recipe.new()
		rr.id = StringName("repair_%s" % item)
		rr.station = ANVIL
		rr.repair = item
		rr.inputs.append(Ingredient.new(Config.GEAR_REPAIR_MATERIAL[item], 1))
		rr.output = item
		_recipes.append(rr)
	_add_rows(Config.BUILD_RECIPES)  # M7b


## Recipes from rows [station, output, count, [[input, count], ...]] (Config.STATION_RECIPES, BUILD_RECIPES), anyone's.
static func _add_rows(rows: Array) -> void:
	for row: Array in rows:
		var r: Recipe = Recipe.new()
		var station_name: String = row[0]
		var out_item: StringName = row[1]
		var out_count: int = row[2]
		r.station = StringName(station_name)
		r.output = out_item
		r.out_count = out_count
		r.id = out_item
		var pairs: Array = row[3]
		for pair: Array in pairs:
			var in_item: StringName = pair[0]
			var in_count: int = pair[1]
			r.inputs.append(Ingredient.new(in_item, in_count))
		_recipes.append(r)


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


## Whether `inv`'s player has unlocked recipe `r` (Config.RECIPES_UNLOCK_ON_FIRST_GET: had every input item). M7a: a
## repair recipe also needs its item seen.
static func unlocked(r: Recipe, inv: Inventory) -> bool:
	if not Config.RECIPES_UNLOCK_ON_FIRST_GET:
		return true
	for i: Ingredient in r.inputs:
		if not inv.has_seen(i.item):
			return false
	return not r.is_repair() or inv.has_seen(r.repair)


## The recipes of station `kind` the panel shows for `inv` (the unlocked ones, in order). M7a: a repair recipe only while
## `inv` holds a worn one of its item.
static func shown_recipes(kind: StringName, inv: Inventory) -> Array[Recipe]:
	var out: Array[Recipe] = []
	for r: Recipe in recipes_for(kind):
		if unlocked(r, inv) and (not r.is_repair() or Gear.most_worn(inv, r.repair) != null):
			out.append(r)
	return out


## M7a: whether recipe `r` belongs to the workbench chain (a station other than the alchemy table, or a repair): a session
## refuses it until M7c.
static func is_m7(r: Recipe) -> bool:
	return r != null and r.station != ALCHEMY


## M7a: the hand "station" on map `map_id` (no fixture: Tab away from every station opens it, offline).
static func hand_station(map_id: int) -> StationAt:
	var at: StationAt = StationAt.new()
	at.kind = HAND
	at.rect = Rect2i()
	at.map = map_id
	return at


## The station value of placeable `p` (&"" for none).
static func station_kind(p: int) -> StringName:
	return STATION_OF.get(p, &"")


## M6-fix: the item whose icon stands for station `kind` (&"" for none).
static func station_icon(kind: StringName) -> StringName:
	return STATION_ICON.get(kind, &"")


## Chebyshev distance in tiles from tile `c` to footprint `rect` (0 = inside).
static func tiles_to(c: Vector2i, rect: Rect2i) -> int:
	var dx: int = maxi(maxi(rect.position.x - c.x, c.x - (rect.end.x - 1)), 0)
	var dy: int = maxi(maxi(rect.position.y - c.y, c.y - (rect.end.y - 1)), 0)
	return maxi(dx, dy)


## The nearest station a player with feet at `feet` stands at (its feet tile within
## Config.STATION_REACH_TILES of the footprint), or null. Tab opens its panel.
static func station_near(data: WorldData, feet: Vector2) -> StationAt:
	return _nearest(data, feet, &"")


## M6-fix: the nearest station of kind `kind` a player with feet at `feet` stands at, or null: the host's check of a
## CRAFT (a recipe's station within reach counts, whatever other station is nearer). M7a: HAND is always "there".
static func station_of_kind_near(data: WorldData, feet: Vector2, kind: StringName) -> StationAt:
	if kind == HAND:
		return hand_station(data.map_id) if data != null else null
	return _nearest(data, feet, kind)


## The nearest station (of kind `kind`, &"" = any) within reach of feet `feet`; between two as near, the one whose
## footprint's top-left tile comes first row by row. M6-fix: every tile within reach of the feet tile is looked at
## and a station tile there names its whole footprint (WorldData.footprint_at), so a footprint of any size counts
## (the tile of a footprint nearest the feet tile is within reach when the footprint is); before, the window was
## sized for the alchemy table's 3 tiles and looked only at each footprint's top-left tile.
static func _nearest(data: WorldData, feet: Vector2, kind: StringName) -> StationAt:
	if data == null:
		return null
	var f: Vector2i = Aim.feet_cell(feet)
	var reach: int = Config.STATION_REACH_TILES
	var best: StationAt = null
	var best_d: int = reach + 1
	for y: int in range(f.y - reach, f.y + reach + 1):
		for x: int in range(f.x - reach, f.x + reach + 1):
			var c: Vector2i = Vector2i(x, y)
			var k: StringName = station_kind(data.get_value(WorldData.Layer.PLACEABLE, c))
			if k.is_empty() or (not kind.is_empty() and k != kind):
				continue
			var rect: Rect2i = data.footprint_at(c)
			var d: int = tiles_to(f, rect)
			if d > reach:
				continue
			if best == null or d < best_d or (d == best_d and _before(rect.position, best.rect.position)):
				best_d = d
				best = StationAt.new()
				best.kind = k
				best.rect = rect
				best.map = data.map_id
	return best


static func _before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


## Whether the station `at` is still there (the same kind on the same footprint, on the same map) and `feet` still
## within reach of it (the panel closes otherwise). M6-fix: that station, not the nearest one (another station
## coming nearer does not close the panel). M7a: the hand panel goes wherever the player stands (same map).
static func still_at(data: WorldData, feet: Vector2, at: StationAt) -> bool:
	if data == null or at == null or data.map_id != at.map:
		return false
	if at.kind == HAND:
		return true
	if station_kind(data.get_value(WorldData.Layer.PLACEABLE, at.rect.position)) != at.kind \
			or data.footprint_at(at.rect.position) != at.rect:
		return false
	return tiles_to(Aim.feet_cell(feet), at.rect) <= Config.STATION_REACH_TILES


## How many of `item` at `grade` (-1 = any) `inv` holds.
static func have(inv: Inventory, item: StringName, grade: int) -> int:
	return inv.count_of(item, grade)


## Why a player of `class_id` with `inv` may not craft `r` now ("" = it may). Checks the class, the inputs
## and the room for the output after the inputs are out. M7a: a repair needs a worn one of its item (no room needed).
static func refusal(r: Recipe, class_id: String, inv: Inventory) -> String:
	if r == null:
		return WHY_BAD_RECIPE
	if not unlocked(r, inv):
		return WHY_LOCKED
	if not r.allows(class_id):
		return r.class_refusal()
	for i: Ingredient in r.inputs:
		if have(inv, i.item, i.grade) < i.count:
			return WHY_MISSING
	if r.is_repair():
		return "" if Gear.most_worn(inv, r.repair) != null else WHY_NOTHING_TO_REPAIR
	var trial: Inventory = copy_of(inv)
	_take_inputs(r, trial)
	if trial.room_for(r.output, r.out_grade) < r.out_count:
		return WHY_NO_ROOM
	return ""


## Crafts `r` for a player of `class_id` from `inv`, all or nothing (see the class comment). M7a: a repair takes its
## material and gives the most worn one of its item (Gear.most_worn) its full durability; nothing is added.
static func craft(r: Recipe, class_id: String, inv: Inventory) -> Outcome:
	var o: Outcome = Outcome.new()
	o.why = refusal(r, class_id, inv)
	if not o.ok():
		return o
	if r.is_repair():
		var target: ItemStack = Gear.most_worn(inv, r.repair)
		_take_inputs(r, inv)
		target.durability = target.max_durability()
		inv.changed.emit()
		o.item = r.repair
		o.count = 1
		o.grade = target.grade
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


## A detached copy of `inv` (stacks, selection, what it has seen; M7a: the worn armour) to try a craft on.
static func copy_of(inv: Inventory) -> Inventory:
	var c: Inventory = Inventory.new(inv.size(), inv.hotbar_size)
	c.load_state(inv.slots, inv.selected)
	c.seen = inv.seen.duplicate()
	c.armor = inv.armor.copy() if inv.armor != null else null
	return c

class_name Collection
extends RefCounted
## M11b: the world's collection (● game-concept §2, §4: 월드마다 독립, 달성 단위 자원·생물·업적, 베네핏 범위 클래스 / 전체 / 월드; which entries,
## thresholds and benefits are PROVISIONAL, Config "M11b", one table each). One per world: WorldData.collection, the same object on the
## surface's and the dungeon's data (offline Main puts it there), so every rule reaches it from a player's own data on either map. A
## world with none (a session until M11c, a test's bare map) simply has no benefits. There is no save until M13; M11c puts it in the
## snapshot.
##
## It belongs to the world, not to a player: a death loses nothing, a new world starts empty, and whoever does the thing registers the
## entry for everyone (the rare ones are archers' by construction). Registered entries stay. What triggers an entry: a kill of a prey
## kind (by anyone), a capture of a rare kind, the first time any player of the world holds an item (note_inventory reads
## Inventory.seen, so every way into an inventory counts), and a count of kills.
##
## The benefits (Config.COLLECTION_BENEFITS lights each at its count): arrow_damage (the archer's arrows), defence_bonus (everyone's
## armour defence, also with no armour on), restock_ticks and world_benefit (the merchant, and the flag M12 can read).

## Entries since the caller last took them (Main's log).
var fresh: Array[StringName] = []
## Creatures killed so far (the "kills" rows).
var kills: int = 0
## Moves whenever something a panel shows changed.
var revision: int = 0
var _done: Dictionary[StringName, bool] = {}


## The Config row of entry `id` ({} = none).
static func row_of(id: StringName) -> Dictionary:
	for row: Dictionary in Config.COLLECTION_ENTRIES:
		if row["id"] == id:
			return row
	return {}


## How many entries there are.
static func total() -> int:
	return Config.COLLECTION_ENTRIES.size()


## The collection of the world `d` belongs to (null: none).
static func of(d: WorldData) -> Collection:
	return d.collection if d != null else null


## How many entries are registered.
func count() -> int:
	return _done.size()


func has(id: StringName) -> bool:
	return _done.has(id)


## Registers entry `id` (a known one, once). Returns whether it was new.
func register(id: StringName) -> bool:
	if _done.has(id) or row_of(id).is_empty():
		return false
	_done[id] = true
	fresh.append(id)
	revision += 1
	return true


## Registers the entries of rule `how` on `what`.
func _note(how: String, what: StringName) -> void:
	for row: Dictionary in Config.COLLECTION_ENTRIES:
		if row["how"] == how and row["what"] == what:
			var id: StringName = row["id"]
			register(id)


## A creature of `kind` was killed, by anyone (a capture is no kill). A rare kind's own entry takes a capture, so its kill only counts.
func note_kill(kind: StringName) -> void:
	kills += 1
	revision += 1
	_note("hunt", kind)
	for row: Dictionary in Config.COLLECTION_ENTRIES:
		var need: int = row["count"]
		if row["how"] == "kills" and kills >= need:
			var id: StringName = row["id"]
			register(id)


## A creature of `kind` was captured.
func note_capture(kind: StringName) -> void:
	_note("capture", kind)


## Whoever holds `inv` has held what it has seen: the "item" rows.
func note_inventory(inv: Inventory) -> void:
	for row: Dictionary in Config.COLLECTION_ENTRIES:
		var id: StringName = row["id"]
		var what: StringName = row["what"]
		if row["how"] == "item" and not has(id) and inv.has_seen(what):
			register(id)


## The entries registered since the last call, oldest first (emptied).
func take_fresh() -> Array[StringName]:
	var out: Array[StringName] = fresh
	fresh = []
	return out


## How far entry `id` has come, of its row's `count` (a registered one is full).
func progress_of(id: StringName) -> int:
	var row: Dictionary = row_of(id)
	if row.is_empty():
		return 0
	var need: int = row["count"]
	if has(id):
		return need
	return mini(kills, need) if row["how"] == "kills" else 0


## Whether benefit `which` (&"class", &"all", &"world") is lit.
func benefit(which: StringName) -> bool:
	var at: int = Config.COLLECTION_BENEFITS[which]
	return count() >= at


## The world benefit (M12 can read this; M11b's effect is restock_ticks).
func world_benefit() -> bool:
	return benefit(&"world")


## The merchant's restock period from `base` (the shop's own): Config.COLLECTION_RESTOCK_TICKS while the world benefit is lit, never longer
## than `base` (a test's short period stays, and a shop that does not restock, 0, still does not).
func restock_ticks(base: int) -> int:
	return mini(base, Config.COLLECTION_RESTOCK_TICKS) if world_benefit() else base


## `amount` of arrow damage with the class benefit: Config.COLLECTION_ARROW_PCT more, rounded to nearest, at least 1 (0 stays 0).
static func arrow_hit(amount: int) -> int:
	if amount <= 0:
		return amount
	return amount + maxi((amount * Config.COLLECTION_ARROW_PCT + 50) / 100, 1)


## The damage arrows of player `p` deal, from `amount` (after the tier-1 rule, before the zeal): raised while the class benefit is lit
## and `p` is its class. The caller knows it is an arrow (a basic attack of kind ARROW, one of the class's arrow skills).
static func arrow_damage(amount: int, p: Player) -> int:
	if p == null or p.class_id() != Config.COLLECTION_CLASS:
		return amount
	var c: Collection = of(p.data)
	return arrow_hit(amount) if c != null and c.benefit(&"class") else amount


## The armour defence the world `d` belongs to gives everyone (Gear.after_armor adds it to the worn armour's, or to none).
static func defence_bonus(d: WorldData) -> int:
	var c: Collection = of(d)
	return Config.COLLECTION_DEFENCE if c != null and c.benefit(&"all") else 0


## One line for logs and tests ("3/8 kills=2 hunt_hare,hunt_deer,...").
func describe() -> String:
	var parts: PackedStringArray = []
	for row: Dictionary in Config.COLLECTION_ENTRIES:
		var id: StringName = row["id"]
		if has(id):
			parts.append(String(id))
	return "%d/%d kills=%d %s" % [count(), total(), kills, ",".join(parts)]

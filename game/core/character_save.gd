class_name CharacterSave
extends RefCounted
## M13a (● game-concept §2 역할 R54, §12 "저장": a character lives on its player's own device apart from the worlds, several of them, any
## of them taken into any world, Terraria style; ● §2 the class is fixed, no swapping): one character as one small text (JSON) file a friend
## may open and change (● R54 "친구끼리라 손댄 파일을 막지는 않는다": no checksum, no signature; read() checks only what keeps a broken or
## hostile file from crashing the game or putting impossible things into a world: a known class, known items in counts their stacks allow,
## grades they can have, durability up to full, armour in the armour slot, numbers that are whole numbers).
##
## What belongs to the character (saved; README "M13a 캐릭터"): its class, the 24 inventory slots (the hotbar is the first 8) with each
## stack's grade and durability, the selected hotbar slot, the armour worn and its durability, its money (an item, ItemDB.MONEY), and
## what it has ever held (Inventory.seen: recipes unlock on it, ○ gameplay-design §3.5, and the collection reads it). Not saved, each with
## its reason in the README: HP, stamina, down / dead (a character comes into a world up and full, at the altar: ● gameplay-design §5
## "부활 지점: 제단"), a buff or poison running, the class meter, zeal, the ward and the cooldowns (a fresh spawn's), where it stood and
## on which map (the world's altar), a carried altar (the world's: put back in the world file).
##
## File (README "M13a 파일 형식"), one JSON object, ASCII:
##   {"format": "evensong-character", "version": 1, "name": "<name>", "class": "<class>", "saved": "<date time>",
##    "selected": <0..7>, "slots": [<stack or null> x <= 24], "armor": <stack or null>, "seen": ["<item id>", ...]}
##   stack = {"item": "<id>", "count": <n>, "grade": "<none|common|fine>", "durability": <points: only for items that wear>}
## A missing "grade" is the item's default, a missing "durability" full, a missing "selected" 0, fewer than 24 slots the rest empty;
## other keys are ignored (the game writes only its own keys when it saves). An unknown id in "seen" is skipped.

const FORMAT: String = "evensong-character"
## The file format's version (an older or newer file is refused with both numbers).
const VERSION: int = 1


## One character as the game holds it between the file and a Player (a sheet: `Character` is the rig, actors/character.gd).
class Sheet:
	extends RefCounted
	var name: String = ""
	var class_id: String = ""
	## Config.INVENTORY_SLOTS stacks (null = empty).
	var stacks: Array[ItemStack] = []
	var selected: int = 0
	var armor: ItemStack = null
	var seen: Array[StringName] = []
	var saved_unix: int = 0

	func _init() -> void:
		stacks.resize(Config.INVENTORY_SLOTS)

	## The money it carries (ItemDB.MONEY in its slots).
	func money() -> int:
		var n: int = 0
		for st: ItemStack in stacks:
			if st != null and st.id == ItemDB.MONEY:
				n += st.count
		return n

	func item_count() -> int:
		var n: int = 0
		for st: ItemStack in stacks:
			if st != null:
				n += 1
		return n

	## One line for the log and `--list-characters`.
	func describe() -> String:
		return "class=%s slots=%d money=%d armor=%s seen=%d" % [class_id, item_count(), money(),
			armor.id if armor != null else "none", seen.size()]

	## Puts this character's things into `inv` (its slots, selection, armour, what it has seen; nothing else of `inv` stays).
	func to_inventory(inv: Inventory) -> void:
		inv.load_state(stacks, selected)
		inv.armor = armor.copy() if armor != null else null
		inv.seen.clear()
		for id: StringName in seen:
			inv.seen[id] = true
		inv.changed.emit()


## What read() gives: the character, or `error` (then character is null).
class Result:
	extends RefCounted
	var character: Sheet = null
	var error: String = ""
	## Which file it came from (load_from: the file, its .tmp or its .bak).
	var path: String = ""
	## Why the files tried before it did not read ("" = it was the first: the file itself).
	var skipped: String = ""

	func ok() -> bool:
		return error.is_empty()


static func _refused(why: String) -> Result:
	var r: Result = Result.new()
	r.error = why
	return r


## Character `name` of class `class_id` holding what `inv` holds now (a copy).
static func from_inventory(name: String, class_id: String, inv: Inventory) -> Sheet:
	var c: Sheet = Sheet.new()
	c.name = name
	c.class_id = class_id
	for i: int in mini(inv.size(), Config.INVENTORY_SLOTS):
		var st: ItemStack = inv.stack_at(i)
		c.stacks[i] = st.copy() if st != null else null
	c.selected = inv.selected
	c.armor = inv.armor.copy() if inv.armor != null else null
	var ids: Array[StringName] = []
	ids.assign(inv.seen.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	c.seen = ids
	return c


static func _stack_json(st: ItemStack) -> Variant:
	if st == null:
		return null
	var d: Dictionary = {"item": String(st.id), "count": st.count, "grade": ItemDB.GRADE_NAMES[clampi(st.grade, 0,
		ItemDB.GRADE_NAMES.size() - 1)]}
	if st.max_durability() > 0:
		d["durability"] = clampi(st.durability, 0, st.max_durability())
	return d


## The file of character `c` (the class comment's form), stamped with the time now.
static func encode(c: Sheet) -> PackedByteArray:
	var slots: Array = []
	for st: ItemStack in c.stacks:
		slots.append(_stack_json(st))
	var seen: Array = []
	for id: StringName in c.seen:
		seen.append(String(id))
	var root: Dictionary = {
		"format": FORMAT, "version": VERSION, "name": c.name, "class": c.class_id,
		"saved": Time.get_datetime_string_from_system(true), "selected": c.selected,
		"slots": slots, "armor": _stack_json(c.armor), "seen": seen,
	}
	return (JSON.stringify(root, "\t", false) + "\n").to_ascii_buffer()


## Whether `v` is a whole number (JSON numbers come as floats) within lo..hi.
static func _whole(v: Variant, lo: int, hi: int) -> bool:
	if typeof(v) == TYPE_INT:
		var i: int = v
		return i >= lo and i <= hi
	if typeof(v) != TYPE_FLOAT:
		return false
	var f: float = v
	return is_finite(f) and f == floorf(f) and f >= lo and f <= hi


static func _int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		var i: int = v
		return i
	var f: float = v
	return int(f)


## [the stack in JSON value `v` (null = an empty slot), why it is none ("" = fine)].
static func _read_stack(v: Variant, where: String) -> Array:
	if v == null:
		return [null, ""]
	if typeof(v) != TYPE_DICTIONARY:
		return [null, "%s is not a stack" % where]
	var d: Dictionary = v
	var item_v: Variant = d.get("item", null)
	if typeof(item_v) != TYPE_STRING:
		return [null, "%s has no item id" % where]
	var item_s: String = item_v
	var id: StringName = StringName(item_s)
	var def: ItemDB.ItemDef = ItemDB.get_def(id)
	if def == null:
		return [null, "%s: unknown item '%s'" % [where, item_s]]
	var count_v: Variant = d.get("count", null)
	if not _whole(count_v, 1, def.stack_max):
		return [null, "%s: %s count must be 1..%d" % [where, item_s, def.stack_max]]
	var grade: int = ItemDB.normalize_grade(id)
	if d.has("grade"):
		var grade_v: Variant = d["grade"]
		var grade_s: String = grade_v if typeof(grade_v) == TYPE_STRING else ""
		grade = ItemDB.grade_from_name(grade_s)
		if not ItemDB.valid_grade(id, grade):
			return [null, "%s: %s cannot have grade '%s'" % [where, item_s, grade_s]]
	var st: ItemStack = ItemStack.new(id, _int(count_v), grade)
	if def.durability > 0:
		st.durability = def.durability
		if d.has("durability"):
			if not _whole(d["durability"], 0, def.durability):
				return [null, "%s: %s durability must be 0..%d" % [where, item_s, def.durability]]
			st.durability = _int(d["durability"])
	return [st, ""]


## The character in file bytes `bytes`, or a Result with `error` (the class comment's checks).
static func read(bytes: PackedByteArray) -> Result:
	if bytes.is_empty() or bytes.size() > Config.CHARACTER_FILE_MAX_BYTES:
		return _refused("empty or larger than %d bytes" % Config.CHARACTER_FILE_MAX_BYTES)
	for b: int in bytes:
		if (b < 0x20 and b != 0x09 and b != 0x0a and b != 0x0d) or b > 0x7e:
			return _refused("not plain ASCII text (byte %d)" % b)
	var json: JSON = JSON.new()
	if json.parse(bytes.get_string_from_ascii()) != OK:
		return _refused("not JSON (line %d: %s)" % [json.get_error_line(), json.get_error_message()])
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return _refused("not a JSON object")
	var root: Dictionary = parsed
	var format_v: Variant = root.get("format", null)
	if typeof(format_v) != TYPE_STRING or str(format_v) != FORMAT:
		return _refused("not a character file (format is not '%s')" % FORMAT)
	var version_v: Variant = root.get("version", null)
	if not _whole(version_v, 0, 1 << 30):
		return _refused("no version")
	if _int(version_v) != VERSION:
		return _refused("character file version %d, this game reads %d" % [_int(version_v), VERSION])
	var c: Sheet = Sheet.new()
	var class_v: Variant = root.get("class", null)
	if typeof(class_v) != TYPE_STRING or not Config.CLASSES.has(str(class_v)):
		return _refused("class must be one of %s" % ", ".join(Config.CLASSES))
	c.class_id = str(class_v)
	var name_v: Variant = root.get("name", "")
	c.name = str(name_v) if typeof(name_v) == TYPE_STRING else ""
	var selected_v: Variant = root.get("selected", 0)
	if not _whole(selected_v, 0, Config.HOTBAR_SLOTS - 1):
		return _refused("selected must be 0..%d" % (Config.HOTBAR_SLOTS - 1))
	c.selected = _int(selected_v)
	var slots_v: Variant = root.get("slots", [])
	if typeof(slots_v) != TYPE_ARRAY:
		return _refused("slots is not a list")
	var slots: Array = slots_v
	if slots.size() > Config.INVENTORY_SLOTS:
		return _refused("%d slots, at most %d" % [slots.size(), Config.INVENTORY_SLOTS])
	for i: int in slots.size():
		var got: Array = _read_stack(slots[i], "slot %d" % (i + 1))
		var why: String = got[1]
		if not why.is_empty():
			return _refused(why)
		c.stacks[i] = got[0]
	var armor_got: Array = _read_stack(root.get("armor", null), "armor")
	var armor_why: String = armor_got[1]
	if not armor_why.is_empty():
		return _refused(armor_why)
	var armor: ItemStack = armor_got[0]
	if armor != null and (not Gear.is_armor(armor.id) or armor.count != 1):
		return _refused("armor holds %s, which is no armour" % armor.id)
	c.armor = armor
	var seen_v: Variant = root.get("seen", [])
	if typeof(seen_v) != TYPE_ARRAY:
		return _refused("seen is not a list")
	var seen: Array = seen_v
	if seen.size() > 4 * ItemDB.count():
		return _refused("seen has %d entries" % seen.size())
	for v: Variant in seen:
		if typeof(v) == TYPE_STRING and ItemDB.has(StringName(str(v))) and not c.seen.has(StringName(str(v))):
			c.seen.append(StringName(str(v)))
	var r: Result = Result.new()
	r.character = c
	return r


## The character in file `path` and, when it does not read, the next of SaveStore.candidates (its .tmp, its .bak): the first that reads,
## with `path` set to that file; else a Result with every file's refusal. A missing file: error "missing".
static func load_from(path: String) -> Result:
	var tried: PackedStringArray = []
	for p: String in SaveStore.candidates(path):
		var r: Result = read(SaveStore.read_bytes(p, Config.CHARACTER_FILE_MAX_BYTES))
		if r.ok():
			r.path = p
			r.skipped = "; ".join(tried)
			return r
		tried.append("%s: %s" % [p.get_file(), r.error])
	return _refused("missing" if tried.is_empty() else "; ".join(tried))

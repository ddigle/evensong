extends "res://tests/base_test.gd"
## Items (M2a): the item table (kinds, stacks, grades, the tool -> body action map, icons: art files
## are 16x16 and code-drawn ones use only warm palette colours), the inventory (stacking, grades,
## overflow, full, remove, split, move / merge / swap, counts), the hotbar (select, Q / E wrap, the
## selected item's action), the HUD layout, the --give flag and the debug kit, and in main.tscn the
## hotbar keys, Tab and F5.

const TOOLS: Dictionary[StringName, int] = {
	&"pickaxe": RigData.Anim.PICKAXE, &"hoe": RigData.Anim.HOE, &"sickle": RigData.Anim.SICKLE,
	&"watering_can": RigData.Anim.WATERING, &"sword": RigData.Anim.SWORD, &"bow": RigData.Anim.BOW,
}
## M4a: the cleric's basic attack, a tool kind item playing the magic action (not in the debug kit).
const M4_TOOLS: Dictionary[StringName, int] = {&"holy_light": RigData.Anim.MAGIC}
## Item -> [icon file, world file] (04-env "본 제작" names), written out here on purpose.
const ART: Dictionary[StringName, Array] = {
	&"stone_block": ["item_stone_block_v02.png", "item_stone_block_v02.png"],
	&"wild_healing": ["item_sprig_healing_v02.png", "item_wild_healing_v02.png"],
	&"wild_buff": ["item_sprig_buff_v02.png", "item_wild_buff_v02.png"],
	&"wild_poison": ["item_sprig_poison_v02.png", "item_wild_poison_v02.png"],
	&"herb_clump": ["item_wild_herb_clump_v02.png", "item_wild_herb_clump_v02.png"],
	&"mushroom_a": ["item_mushroom_a_v02.png", "item_mushroom_a_v02.png"],
	&"mushroom_b": ["item_mushroom_b_v02.png", "item_mushroom_b_v02.png"],
	&"mushroom_c": ["item_mushroom_c_v02.png", "item_mushroom_c_v02.png"],
	&"mushroom_d": ["item_mushroom_d_v02.png", "item_mushroom_d_v02.png"],
	&"mushroom_ash": ["item_mushroom_ash_v02.png", "item_mushroom_ash_v02.png"],
	&"stone_a": ["item_stone_a_v02.png", "item_stone_a_v02.png"],
	&"stone_b": ["item_stone_b_v02.png", "item_stone_b_v02.png"],
	&"stone_c": ["item_stone_c_v02.png", "item_stone_c_v02.png"],
	&"stone_mossy": ["item_stone_mossy_v02.png", "item_stone_mossy_v02.png"],
	&"stone_veined": ["item_stone_veined_v02.png", "item_stone_veined_v02.png"],
	&"stone_mould": ["item_stone_mould_v02.png", "item_stone_mould_v02.png"],
	&"ore_copper": ["item_ore_copper_a_v02.png", "item_ore_copper_a_v02.png"],
	&"ore_iron": ["item_ore_iron_a_v02.png", "item_ore_iron_a_v02.png"],
}
## M3a: materials (the rest of ART are gatherables) and placeables (code icon, the placeable they put).
const MATERIALS: Array[StringName] = [&"stone_block", &"ore_copper", &"ore_iron"]
const PLACEABLES: Dictionary[StringName, int] = {&"torch": WorldData.PLACEABLE_TORCH}
const HERBS: Array[StringName] = [&"wild_healing", &"wild_buff", &"wild_poison", &"herb_clump"]


func run() -> Array[String]:
	_check_table()
	_check_icons()
	_check_add_and_stack()
	_check_grades()
	_check_full()
	_check_remove_split_move()
	_check_hotbar()
	_check_hud_layout()
	_check_give_flag()
	await _check_main_keys()
	return failures


func _check_table() -> void:
	var ids: Array[StringName] = ItemDB.ids()
	check_eq(ids.size(), TOOLS.size() + M4_TOOLS.size() + ART.size() + PLACEABLES.size(),
		"item count = 6 tools (M4a: + holy_light) + 3 materials (M3a: 2 ores) + 15 gatherables + 1 placeable (M3a: the torch)")
	var kinds: Dictionary[int, int] = {}
	for id: StringName in ids:
		var def: ItemDB.ItemDef = ItemDB.get_def(id)
		if not check(def != null and def.id == id, "%s has a definition" % id):
			continue
		var seen: int = kinds.get(def.kind, 0)
		kinds[def.kind] = seen + 1
		if TOOLS.has(id) or M4_TOOLS.has(id):
			var want_action: int = TOOLS[id] if TOOLS.has(id) else M4_TOOLS[id]
			check_eq(def.kind, ItemDB.Kind.TOOL, "%s is a tool" % id)
			check_eq(def.action, want_action, "%s plays the %s action" % [id, RigData.ANIM_NAMES[want_action]])
			check_eq(def.stack_max, Config.STACK_TOOL, "%s stacks to STACK_TOOL" % id)
			check(not def.graded, "%s has no grade" % id)
			check_eq(String(def.icon_code), String(id), "%s icon is drawn in code" % id)
		elif PLACEABLES.has(id):
			check_eq(def.kind, ItemDB.Kind.PLACEABLE, "%s is a placeable" % id)
			check_eq(def.place, PLACEABLES[id], "%s puts its placeable down" % id)
			check_eq(def.action, -1, "%s plays no action" % id)
			check_eq(def.stack_max, Config.STACK_MATERIAL, "%s stack size" % id)
			check_eq(String(def.icon_code), String(id), "%s icon is drawn in code" % id)
		else:
			check_eq(def.action, -1, "%s plays no action" % id)
			check(def.icon_code.is_empty(), "%s icon is art" % id)
			var files: Array = ART.get(id, ["?", "?"])
			check_eq(def.icon_path, ItemDB.ART_DIR + str(files[0]), "%s icon file" % id)
			check_eq(def.world_path, ItemDB.ART_DIR + str(files[1]), "%s world file" % id)
			var want_kind: int = ItemDB.Kind.MATERIAL if MATERIALS.has(id) else ItemDB.Kind.GATHERABLE
			check_eq(def.kind, want_kind, "%s kind" % id)
			check_eq(def.stack_max, Config.STACK_MATERIAL if want_kind == ItemDB.Kind.MATERIAL else Config.STACK_GATHERABLE,
				"%s stack size" % id)
			check_eq(def.graded, HERBS.has(id), "%s graded only if a herb" % id)
	check_eq([kinds.get(ItemDB.Kind.TOOL, 0), kinds.get(ItemDB.Kind.MATERIAL, 0), kinds.get(ItemDB.Kind.GATHERABLE, 0),
		kinds.get(ItemDB.Kind.PLACEABLE, 0)], [7, 3, 15, 1], "items per kind (tool (M4a: 7), material, gatherable, placeable)")
	# Every action with a hand tool has exactly one tool; throw has none (README). M4a: magic has the
	# cleric's holy light.
	var actions: Array[int] = []
	for id: StringName in ids:
		var a: int = ItemDB.get_def(id).action
		if a >= 0:
			check(not actions.has(a), "one tool per action (%s)" % RigData.ANIM_NAMES[a])
			actions.append(a)
	check(not actions.has(RigData.Anim.THROW), "no item plays throw")
	check_eq(ItemDB.get_def(&"holy_light").action, RigData.Anim.MAGIC, "M4a: the holy light plays magic")
	check(ItemDB.get_def(&"nothing") == null and not ItemDB.has(&"nothing"), "unknown id")
	check_eq(ItemDB.normalize_grade(&"stone_a", ItemDB.Grade.FINE), ItemDB.Grade.NONE, "ungraded items drop the grade")
	check_eq(ItemDB.normalize_grade(&"wild_buff"), ItemDB.Grade.COMMON, "herbs default to common")
	check_eq(ItemDB.normalize_grade(&"wild_buff", ItemDB.Grade.FINE), ItemDB.Grade.FINE, "fine herb")
	check_eq(ItemDB.normalize_grade(&"nothing"), -1, "unknown item has no grade")


## Art icons: 16x16 files that load (and the world pictures); code-drawn tool icons: 16x16, only
## palette colours, outline present, no cool grey (B > R) anywhere.
func _check_icons() -> void:
	for id: StringName in ItemDB.ids():
		var tex: Texture2D = ItemIcons.texture_for(id)
		if not check(tex != null, "%s has an icon" % id):
			continue
		check_eq(Vector2i(tex.get_size()), Vector2i(16, 16), "%s icon is 16x16" % id)
		var def: ItemDB.ItemDef = ItemDB.get_def(id)
		if not def.world_path.is_empty():
			var world: Texture2D = load(def.world_path) as Texture2D
			check(world != null and Vector2i(world.get_size()) == Vector2i(16, 16), "%s world picture 16x16" % id)
		check(ItemIcons.texture_for(id) == tex, "%s icon cached" % id)
	check(ItemIcons.texture_for(&"nothing") == null, "no icon for an unknown item")
	for code: StringName in ItemIcons.MAPS:
		var rows: Array = ItemIcons.MAPS[code]
		check_eq(rows.size(), 16, "%s map has 16 rows" % code)
		var opaque: int = 0
		var cool: int = 0
		var outline: int = 0
		var unknown: int = 0
		for row_v: Variant in rows:
			var row: String = row_v
			check_eq(row.length(), 16, "%s map row is 16 wide" % code)
			for ch: String in row:
				if ch == ".":
					continue
				if not ItemIcons.PALETTE.has(ch):
					unknown += 1
					continue
				var c: Color = ItemIcons.PALETTE[ch]
				opaque += 1
				if c.b8 > c.r8:
					cool += 1
				if ch == "k":
					outline += 1
		check_eq(unknown, 0, "%s map uses palette letters only" % code)
		check_eq(cool, 0, "%s icon has no cool colour" % code)
		check(opaque >= 30 and outline >= opaque / 3, "%s icon is a solid outlined shape (%d px, %d outline)" % [code, opaque, outline])
		var img: Image = ItemIcons.image_from_map(code)
		check_eq(LightGen.count_opaque(img), opaque, "%s image = map" % code)


func _check_add_and_stack() -> void:
	var inv: Inventory = Inventory.new(6, 3)
	var emitted: Array[int] = [0]
	inv.changed.connect(func() -> void: emitted[0] += 1)
	check_eq(inv.size(), 6, "inventory size")
	check_eq(inv.free_slots(), 6, "empty inventory")
	check_eq(inv.add(&"stone_a", 30), 0, "30 stones fit")
	check_eq(emitted[0], 1, "add emits changed")
	check_eq(inv.add(&"stone_a", 80), 0, "80 more fit")
	check_eq([inv.stack_at(0).count, inv.stack_at(1).count], [99, 11], "stones fill slot 0 to 99, then slot 1")
	check_eq(inv.add(&"pickaxe", 2), 0, "two pickaxes fit")
	check(inv.stack_at(2).id == &"pickaxe" and inv.stack_at(3).id == &"pickaxe", "tools do not stack (one per slot)")
	check_eq([inv.stack_at(2).count, inv.stack_at(3).count], [1, 1], "one pickaxe each")
	check_eq(inv.add(&"stone_a", 5), 0, "5 more stones")
	check_eq(inv.stack_at(1).count, 16, "joined the partial stack, not a new slot")
	check_eq(inv.count_of(&"stone_a"), 115, "count_of")
	check_eq(inv.add(&"nothing", 4), 4, "unknown items do not fit")
	check_eq(inv.add(&"stone_a", 0), 0, "adding 0 does nothing")
	var before: int = emitted[0]
	inv.add(&"stone_a", -3)
	check_eq(emitted[0], before, "adding a negative count changes nothing")
	check_eq(inv.room_for(&"stone_a"), 83 + 2 * 99, "room for stones: partial stack + 2 empty slots")
	check_eq(inv.room_for(&"sword"), 2, "room for swords: 2 empty slots")
	check(inv.describe().contains("0:stone_a x99"), "describe lists the slots")


func _check_grades() -> void:
	var inv: Inventory = Inventory.new(4, 2)
	inv.add(&"wild_healing", 10)
	inv.add(&"wild_healing", 3, ItemDB.Grade.FINE)
	inv.add(&"wild_healing", 2, ItemDB.Grade.COMMON)
	check_eq(inv.stack_at(0).grade, ItemDB.Grade.COMMON, "herbs default to common")
	check_eq(inv.stack_at(0).count, 12, "common herbs stack together")
	check_eq([inv.stack_at(1).grade, inv.stack_at(1).count], [ItemDB.Grade.FINE, 3], "fine herbs get their own stack")
	check_eq(inv.count_of(&"wild_healing"), 15, "count of all grades")
	check_eq(inv.count_of(&"wild_healing", ItemDB.Grade.FINE), 3, "count of fine")
	inv.add(&"stone_b", 4, ItemDB.Grade.FINE)
	check_eq(inv.stack_at(2).grade, ItemDB.Grade.NONE, "a grade on an ungraded item is dropped")
	inv.add(&"stone_b", 4)
	check_eq(inv.stack_at(2).count, 8, "and it stacks with the rest")
	# Moving fine onto common swaps instead of merging.
	check(inv.move(1, 0), "move fine onto common")
	check_eq([inv.stack_at(0).grade, inv.stack_at(1).grade], [ItemDB.Grade.FINE, ItemDB.Grade.COMMON], "different grades swap")


func _check_full() -> void:
	var inv: Inventory = Inventory.new(3, 3)
	check_eq(inv.add(&"sword", 1), 0, "sword")
	check_eq(inv.add(&"bow", 1), 0, "bow")
	check_eq(inv.add(&"mushroom_a", 150), 51, "150 mushrooms: 99 fit in the last slot, 51 left over")
	check_eq(inv.free_slots(), 0, "full")
	check_eq(inv.add(&"hoe", 1), 1, "a tool does not fit a full inventory")
	check_eq(inv.add(&"mushroom_a", 1), 1, "a full stack takes no more")
	check_eq(inv.room_for(&"mushroom_a"), 0, "no room")
	inv.remove(2, 10)
	check_eq(inv.add(&"mushroom_a", 25), 15, "room for 10 again")
	check_eq(inv.split(2, 5), -1, "no split into a full inventory")
	check_eq(inv.stack_at(2).count, 99, "the stack is unchanged after a refused split")
	inv.clear()
	check_eq(inv.free_slots(), 3, "clear")


func _check_remove_split_move() -> void:
	var inv: Inventory = Inventory.new(5, 2)
	inv.add(&"stone_c", 20)
	check_eq(inv.remove(0, 5), 5, "remove 5")
	check_eq(inv.stack_at(0).count, 15, "15 left")
	check_eq(inv.remove(0, 50), 15, "remove more than there is")
	check(inv.is_empty_slot(0), "the emptied slot is free")
	check_eq(inv.remove(0, 1), 0, "remove from an empty slot")
	check_eq(inv.remove(9, 1), 0, "remove from a slot out of range")
	inv.add(&"stone_c", 20)
	var to: int = inv.split(0, 7)
	check_eq(to, 1, "split goes to the first empty slot")
	check_eq([inv.stack_at(0).count, inv.stack_at(1).count], [13, 7], "13 + 7")
	check(inv.stack_at(1) != inv.stack_at(0) and inv.stack_at(1).id == &"stone_c", "a new stack of the same item")
	check_eq(inv.split(0, 0), -1, "split 0 is refused")
	check_eq(inv.split(0, 13), -1, "split of the whole stack is refused")
	check_eq(inv.split(4, 1), -1, "split of an empty slot is refused")
	check_eq(inv.split_half(0), 2, "split half")
	check_eq([inv.stack_at(0).count, inv.stack_at(2).count], [7, 6], "13 -> 7 + 6")
	inv.add(&"pickaxe", 1)
	check_eq(inv.stack_at(3).id, &"pickaxe", "pickaxe in slot 3")
	check_eq(inv.split_half(3), -1, "a single item does not split")
	# Merge, partial merge, move to empty, swap, no-ops.
	check(inv.move(2, 1), "merge 6 onto 7")
	check(inv.is_empty_slot(2) and inv.stack_at(1).count == 13, "merged into 13, source emptied")
	inv.stack_at(0).count = 95
	check(inv.move(1, 0), "partial merge")
	check_eq([inv.stack_at(0).count, inv.stack_at(1).count], [99, 9], "merge fills to 99, the rest stays")
	check(inv.move(3, 4), "move to an empty slot")
	check(inv.is_empty_slot(3) and inv.stack_at(4).id == &"pickaxe", "moved")
	check(inv.move(4, 0), "swap different items")
	check(inv.stack_at(0).id == &"pickaxe" and inv.stack_at(4).id == &"stone_c", "swapped")
	inv.stack_at(1).count = 99
	check(not inv.move(4, 1), "merge onto a full stack changes nothing")
	check(not inv.move(2, 0), "move from an empty slot")
	check(not inv.move(0, 0), "move onto itself")
	check(not inv.move(0, 7), "move out of range")


func _check_hotbar() -> void:
	var inv: Inventory = Inventory.new(Config.INVENTORY_SLOTS, Config.HOTBAR_SLOTS)
	check_eq(inv.hotbar_size, Config.HOTBAR_SLOTS, "hotbar size")
	check_eq(inv.selected, 0, "slot 0 selected at first")
	check(inv.selected_stack() == null and inv.selected_action() == -1, "empty hand: no action")
	for id: StringName in TOOLS:
		inv.add(id, 1)
	inv.add(&"wild_healing", 4)
	for i: int in TOOLS.size():
		inv.select(i)
		var id: StringName = inv.selected_stack().id
		check_eq(inv.selected_action(), TOOLS[id], "slot %d (%s) plays its action" % [i, id])
	inv.select(6)
	check_eq(inv.selected_action(), -1, "a gatherable plays no action")
	inv.select(0)
	inv.select_offset(-1)
	check_eq(inv.selected, Config.HOTBAR_SLOTS - 1, "Q from the first slot wraps to the last")
	inv.select_offset(1)
	check_eq(inv.selected, 0, "E from the last slot wraps to the first")
	inv.select_offset(3)
	check_eq(inv.selected, 3, "E three times")
	inv.select(Config.HOTBAR_SLOTS)
	check_eq(inv.selected, 3, "slots past the hotbar cannot be selected")
	inv.select(-1)
	check_eq(inv.selected, 3, "negative slot ignored")
	var emitted: Array[int] = [0]
	inv.changed.connect(func() -> void: emitted[0] += 1)
	inv.select(3)
	check_eq(emitted[0], 0, "selecting the same slot emits nothing")
	inv.select(4)
	check_eq(emitted[0], 1, "selecting another slot emits changed")
	# The items go to the hotbar first.
	var fresh: Inventory = Inventory.new()
	fresh.add(&"sword", 1)
	check_eq(fresh.stack_at(0).id, &"sword", "first item lands in hotbar slot 0")


## Slots: the hotbar centred at the bottom, the inventory rows above it, all inside the view.
func _check_hud_layout() -> void:
	for view: Vector2i in [Vector2i(480, 270), Vector2i(480, 336), Vector2i(581, 270)]:
		var h: int = Config.HOTBAR_SLOTS
		var first: Vector2i = Hud.slot_origin(0, h, view)
		var last: Vector2i = Hud.slot_origin(h - 1, h, view)
		check_eq(first.y + Hud.SLOT + Hud.BOTTOM, view.y, "hotbar sits %d px above the bottom (%s)" % [Hud.BOTTOM, view])
		check(absi(first.x - (view.x - (last.x + Hud.SLOT))) <= 1, "hotbar centred (%s)" % view)
		var rects: Array[Rect2i] = []
		for i: int in Config.INVENTORY_SLOTS:
			var r: Rect2i = Rect2i(Hud.slot_origin(i, h, view), Vector2i(Hud.SLOT, Hud.SLOT))
			check(Rect2i(Vector2i.ZERO, view).encloses(r), "slot %d inside the view %s" % [i, view])
			for other: Rect2i in rects:
				check(not other.intersects(r), "slot %d does not overlap another" % i)
			rects.append(r)
		check(Hud.slot_origin(h, h, view).y < first.y - Hud.SLOT, "inventory rows above the hotbar")
	var hud: Hud = Hud.new()
	add_node(hud)
	var inv: Inventory = Inventory.new()
	hud.bind(inv)
	check(inv.changed.is_connected(hud.canvas.queue_redraw), "the HUD redraws when the inventory changes")
	var other: Inventory = Inventory.new()
	hud.bind(other)
	check(not inv.changed.is_connected(hud.canvas.queue_redraw), "rebinding disconnects the old inventory")
	check_eq(hud.layer, 10, "HUD on its own canvas layer (no camera, no evening)")
	hud.toggle_open()
	check(hud.open, "toggle opens")
	hud.toggle_open()
	check(not hud.open, "toggle closes")
	check_eq(Hud.DIGITS.size(), 10, "ten digits")


func _check_give_flag() -> void:
	var o: CliOptions = CliOptions.parse(PackedStringArray(["--give=pickaxe,stone_a:30,wild_healing:3:fine,wild_buff:2:common"]))
	check_eq(o.errors.size(), 0, "--give parses (%s)" % str(o.errors))
	check_eq(o.give.size(), 4, "four entries")
	if o.give.size() == 4:
		check_eq(o.give[0], [&"pickaxe", 1, -1], "count defaults to 1")
		check_eq(o.give[1], [&"stone_a", 30, -1], "count")
		check_eq(o.give[2], [&"wild_healing", 3, ItemDB.Grade.FINE], "grade fine")
		check_eq(o.give[3], [&"wild_buff", 2, ItemDB.Grade.COMMON], "grade common")
	for bad: String in ["--give=", "--give=nothing", "--give=stone_a:0", "--give=stone_a:x", "--give=stone_a:3:fine",
			"--give=wild_healing:3:best", "--give=wild_healing:3:fine:x", "--give=pickaxe,,hoe"]:
		check_eq(CliOptions.parse(PackedStringArray([bad])).errors.size(), 1, "%s is one error" % bad)
	var o2: CliOptions = CliOptions.parse(PackedStringArray(["--test-select=3", "--test-inventory", "--test-aim=20,-4",
		"--test-action=sword:2", "--test-action-lineup"]))
	check_eq(o2.errors.size(), 0, "test flags parse (%s)" % str(o2.errors))
	check_eq([o2.test_select, o2.test_inventory, o2.test_aim], [3, true, Vector2(20, -4)], "select, inventory, aim")
	check_eq(o2.test_action, [RigData.Anim.SWORD, 1] as Array[int], "--test-action=sword:2 = frame index 1")
	check_eq(o2.test_action_lineup, -1, "--test-action-lineup without a frame = middle")
	check_eq(CliOptions.parse(PackedStringArray(["--test-action=throw"])).test_action, [RigData.Anim.THROW, -1] as Array[int],
		"--test-action without a frame = middle")
	check_eq(CliOptions.parse(PackedStringArray(["--test-action-lineup=6"])).test_action_lineup, 5, "lineup frame 6")
	for bad: String in ["--test-select=0", "--test-select=%d" % (Config.HOTBAR_SLOTS + 1), "--test-aim=3", "--test-aim=a,b",
			"--test-action=walk", "--test-action=dance", "--test-action=pickaxe:7", "--test-action=sword:0",
			"--test-action-lineup=7"]:
		check_eq(CliOptions.parse(PackedStringArray([bad])).errors.size(), 1, "%s is one error" % bad)
	var kit: Inventory = Inventory.new()
	var lost: int = 0
	for entry: Array in ItemDB.debug_kit():
		var id: StringName = entry[0]
		var count: int = entry[1]
		var grade: int = entry[2] if entry.size() > 2 else -1
		check(ItemDB.has(id), "debug kit item %s exists" % id)
		lost += kit.add(id, count, grade)
	check_eq(lost, 0, "the debug kit fits an empty inventory")
	check_eq(kit.free_slots(), ItemDB.DEBUG_KIT_FREE_SLOTS, "M3-fix: the debug kit leaves %d slots free" % ItemDB.DEBUG_KIT_FREE_SLOTS)
	# A herbalist with the kit picks the two herbs the kit holds only as common: both FINE stacks find a
	# slot (with the kit filling all 24 slots, M3a, both were refused as "inventory full").
	var field: WorldData = WorldData.new(Vector2i(8, 8))
	field.set_value(WorldData.Layer.VEGETATION, Vector2i(5, 4), WorldItems.value_of(&"wild_buff"))
	field.set_value(WorldData.Layer.VEGETATION, Vector2i(3, 4), WorldItems.value_of(&"wild_poison"))
	var feet: Vector2 = Vector2(4 * Config.TILE + 8, 4 * Config.TILE + 12)
	var buff: WorldItems.Outcome = WorldItems.pickup(field, feet, WorldItems.HERB_CLASS, kit, Vector2i(5, 4))
	var poison: WorldItems.Outcome = WorldItems.pickup(field, feet, WorldItems.HERB_CLASS, kit, Vector2i(3, 4))
	check(buff.ok() and buff.grade == ItemDB.Grade.FINE and poison.ok() and poison.grade == ItemDB.Grade.FINE,
		"a herbalist with the debug kit picks wild_buff and wild_poison as FINE (%s, %s)" % [buff.why, poison.why])
	for i: int in TOOLS.size():
		check_eq(kit.stack_at(i).def().kind, ItemDB.Kind.TOOL, "debug kit: hotbar slot %d holds a tool" % i)


## main.tscn: Q / E move the hotbar selection, Tab opens the inventory grid, F5 gives the debug kit,
## the HUD shows the local player's inventory.
func _check_main_keys() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var player: Player = main.player
	if not check(player != null and main.hud != null, "main has a player and a HUD"):
		return
	check(main.hud.inventory == player.inventory, "HUD shows the local player's inventory")
	check(player.controls, "the offline local player has controls")
	check_eq(player.inventory.free_slots(), Config.INVENTORY_SLOTS - _given_slots() - 1,
		"starts with the --give items and (M4a) the class weapon only")
	check_eq(player.inventory.stack_at(Config.START_WEAPON_SLOT).id, Combat.class_weapon(player.class_id()),
		"M4a: the class weapon in its hotbar slot")
	_press(&"debug_give")
	await await_frames(1)
	check_eq(player.inventory.stack_at(0).id, &"pickaxe", "F5 gives the debug kit (pickaxe first)")
	_press(&"hotbar_next")
	await await_frames(1)
	check_eq(player.inventory.selected, 1, "E selects the next slot")
	_press(&"hotbar_prev")
	_press(&"hotbar_prev")
	await await_frames(1)
	check_eq(player.inventory.selected, Config.HOTBAR_SLOTS - 1, "Q twice wraps to the last slot")
	_press(&"toggle_inventory")
	await await_frames(1)
	check(main.hud.open, "Tab opens the inventory")
	_press(&"toggle_inventory")
	await await_frames(1)
	check(not main.hud.open, "Tab closes it")
	main.spawn("archer")
	check(main.hud.inventory == main.player.inventory, "respawn rebinds the HUD")


func _given_slots() -> int:
	var inv: Inventory = Inventory.new()
	for entry: Array in CliOptions.current().give:
		var id: StringName = entry[0]
		var count: int = entry[1]
		var grade: int = entry[2]
		inv.add(id, count, grade)
	return Config.INVENTORY_SLOTS - inv.free_slots()


static func _press(action: StringName) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up: InputEventAction = InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)

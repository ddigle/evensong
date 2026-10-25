class_name ItemDB
extends RefCounted
## Item definitions (M2a): one typed table of every item the slice has so far. Constants and pure
## functions only; per-player state is in items/inventory.gd.
##
## Kinds: TOOL (held in the hotbar, "use" plays its body action, gameplay-design §1 ○ "좌클릭 = 들고
## 있는 도구 사용"), MATERIAL (made or bought, kept), GATHERABLE (picked up in the world, §3.4 ○).
## M6a: POTION (brewed at the alchemy table, items/crafting.gd; drunk or thrown, items/potions.gd) and the
## alchemy table, a PLACEABLE like the torch.
## M2a has no gathering, crafting or world effect: items come from the debug give (--give, F5).
##
## Tools = the hand tools that have a body action of their own (● brief §5.6 R25: the tool is drawn
## into the action). The magic and throw actions have no hand tool (cleric prayer / heal, herbalist
## potion throw: skills and potions, not M2), so no item plays them (README "임시값"). M4a: the cleric's
## basic attack is a tool kind item too, `holy_light` (PROVISIONAL, Config.CLASS_WEAPONS), which plays
## the magic action and lets a bolt go (combat/combat.gd); its icon is drawn in code. Throw still has none.
## Tool icons: no art exists, so they are PROVISIONAL placeholders drawn in code (items/item_icons.gd).
## Gatherable and material art: 04-env "본 제작" candidates (not yet adopted), copied to art/items/.
##
## Grade (● gameplay-design §3.4 / §3.0: a herb the herbalist picks is 상급, anyone else's 일반): only
## herbs are graded. Whether mushrooms, stones or tools have grades is not in the docs (PROVISIONAL:
## no). Stacks of different grades do not merge.

## M3a: PLACEABLE = put on a floor tile by "use" (the torch; M6a: the alchemy table).
## M6a: POTION = drunk with "use" (left click), thrown with the herbalist's skill (items/potions.gd).
## M5b: CONSUMABLE = used up on a target tile with "use" (holy water purifies the corrupted tiles around it,
## items/purify.gd).
## M7a: ARMOR = worn in the inventory's armour slot (items/gear.gd; a click while it is selected puts it on).
## M7a also adds the wood and the ingots (MATERIAL), the three stations and the storage chest (PLACEABLE, items/crafting.gd,
## items/storage.gd) and the tier-1 weapons (TOOL: each plays its base weapon's action, Config.GEAR_T1_BASE), all at the
## end of the table (the wire sends items by index).
enum Kind { TOOL, MATERIAL, GATHERABLE, PLACEABLE, POTION, SEED, CONSUMABLE, ARMOR }
## NONE = the item has no grade. COMMON = 일반, FINE = 상급.
enum Grade { NONE, COMMON, FINE }

const KIND_NAMES: PackedStringArray = ["tool", "material", "gatherable", "placeable", "potion", "seed", "consumable", "armor"]
## M7a: the icons of the wood and the ingots (04-env 묶음 2 #62 log, #46 planks, #42 / #44 ingots: the 3/4 icons v02, like the
## stone block and the ores; whether material icons are 3/4 v02 or front v03 is ○ brief §5.7).
const WOOD_ICONS: Dictionary[StringName, String] = {
	&"log": "item_log_v02.png", &"planks": "item_planks_a_v02.png",
	&"ingot_copper": "item_ingot_copper_a_v02.png", &"ingot_iron": "item_ingot_iron_a_v02.png",
}
## M7a: the placeable stations and the chest, by item, with the 04-env picture their inventory icon is shrunk from
## (ItemIcons.fit_icon: a PLACEHOLDER composed from the placed picture; no icon art exists).
const STATION_ITEMS: Dictionary[StringName, Array] = {
	&"workbench": [WorldData.PLACEABLE_WORKBENCH, "res://art/env/workbench_v03.png"],
	&"anvil": [WorldData.PLACEABLE_ANVIL, "res://art/env/anvil_v03.png"],
	&"relic_bench": [WorldData.PLACEABLE_RELIC, "res://art/env/relic_bench_v03.png"],
	&"storage_chest": [WorldData.PLACEABLE_CHEST, "res://art/env/storage_chest_v02.png"],
}
## M5b: holy water's icon (04-env 묶음 2 #58 "a small glass vial of holy water", 판정 좋음; the a / b / c vials are
## candidates, a is the first of the two marked good).
const HOLY_WATER_ICON: String = "item_holy_water_a_v02.png"
## M6a: the 04-env items strip (items_v04_strip.png, 18 icons of 16x16 in a row) holds the potion icons:
## its 4th, 5th and 6th icons are the red, amber and poison potions (04-env/prompts.md "1차 판정 뒤 손질"
## 작은 것 #21, #22, #23; v04 = the last touch-up, the poison cork rust). The file is copied whole
## (byte-identical) and an icon is a region of it.
const ITEMS_STRIP: String = "items_v04_strip.png"
const STRIP_POTIONS: Dictionary[StringName, int] = {&"potion_healing": 3, &"potion_buff": 4, &"potion_poison": 5}
## M5a: the strip's first three icons are the seed bags of the three crops (04-env prompts.md 1차 시험 #18~#20 "씨앗
## 봉투", bands in the crop colours: healing red, buff amber, poison yellow with rust; v03/v04 손질).
const STRIP_SEEDS: Dictionary[StringName, int] = {&"seed_healing": 0, &"seed_buff": 1, &"seed_poison": 2}
## IMPL (M3-fix): inventory slots the debug kit leaves free (debug_kit()). M4a: 3 on an empty inventory,
## so the offline player's start weapon (Config.START_WEAPON_SLOT) still leaves the M3-fix two.
const DEBUG_KIT_FREE_SLOTS: int = 3
const GRADE_NAMES: PackedStringArray = ["none", "common", "fine"]
const ART_DIR: String = "res://art/items/"


## One item kind.
class ItemDef:
	extends RefCounted
	var id: StringName
	var kind: int
	## Inventory icon (16x16). Empty for code-drawn icons (`icon_code`).
	var icon_path: String
	## Placeholder icon drawn in code (items/item_icons.gd), for items without art.
	var icon_code: StringName
	## How a gatherable looks where it grows or lies in the world (empty: same as the icon / none).
	var world_path: String
	var stack_max: int
	var graded: bool
	## RigData body action played by "use" (-1: none).
	var action: int
	## M3a: WorldData placeable value "use" puts on the target tile (PLACEABLE_NONE: none).
	var place: int = WorldData.PLACEABLE_NONE
	## M6a: the icon is this region of the icon file (an empty rect: the whole file).
	var icon_region: Rect2i = Rect2i()
	## M6a: a potion's effect (Potions.Effect; -1: not a potion).
	var effect: int = -1
	## M7a: full durability (0 = none: only the tier-1 gear has it, Config.GEAR_DURABILITY), the base item a tier-1 weapon
	## stands for (&"" = itself; Gear.base), its tier (0 = the basic items), and whether the icon is the placed picture
	## shrunk to 16x16 (icon_path then names that picture; ItemIcons.fit_icon).
	var durability: int = 0
	var base: StringName = &""
	var tier: int = 0
	var icon_fit: bool = false

	func _init(p_id: StringName, p_kind: int, p_stack: int, p_graded: bool = false, p_action: int = -1) -> void:
		id = p_id
		kind = p_kind
		stack_max = p_stack
		graded = p_graded
		action = p_action

	func is_tool() -> bool:
		return kind == Kind.TOOL

	func is_potion() -> bool:
		return kind == Kind.POTION

	## M7a: worn in the armour slot.
	func is_armor() -> bool:
		return kind == Kind.ARMOR


static var _table: Dictionary[StringName, ItemDef] = {}
static var _order: Array[StringName] = []


## Every item id in table order (tools, material, gatherables).
static func ids() -> Array[StringName]:
	_build()
	return _order.duplicate()


static func has(id: StringName) -> bool:
	_build()
	return _table.has(id)


## Number of items (the wire sends an item as its index in table order, M2b).
static func count() -> int:
	_build()
	return _order.size()


## Index of `id` in table order, or -1.
static func index_of(id: StringName) -> int:
	_build()
	return _order.find(id)


## Item id at table index `index`, or &"" outside the table.
static func id_at(index: int) -> StringName:
	_build()
	return _order[index] if index >= 0 and index < _order.size() else &""


## Whether `grade` is a grade an item `id` can be stored with (ungraded: NONE; graded: COMMON / FINE).
static func valid_grade(id: StringName, grade: int) -> bool:
	var def: ItemDef = get_def(id)
	if def == null:
		return false
	return grade == Grade.NONE if not def.graded else (grade == Grade.COMMON or grade == Grade.FINE)


## The definition of `id`, or null.
static func get_def(id: StringName) -> ItemDef:
	_build()
	return _table.get(id, null)


## The stored grade of `id` for a requested grade (-1 = default): ungraded items are always NONE,
## graded ones COMMON unless FINE was asked for. An unknown item gives -1.
static func normalize_grade(id: StringName, grade: int = -1) -> int:
	var def: ItemDef = get_def(id)
	if def == null:
		return -1
	if not def.graded:
		return Grade.NONE
	return Grade.FINE if grade == Grade.FINE else Grade.COMMON


## Grade from its name in GRADE_NAMES ("--give=wild_healing:3:fine"), -1 if unknown.
static func grade_from_name(text: String) -> int:
	return GRADE_NAMES.find(text)


## Debug kit (F5): every tool, (M3a) ten torches right after them (in the hotbar, slot 7), a few of most
## gatherable kinds, the material. It leaves DEBUG_KIT_FREE_SLOTS of the Config.INVENTORY_SLOTS slots
## free (M3-fix: with the torches it had filled all 24, so a herbalist's first FINE herb of a kind and
## every ore from mining found no slot): the two ash-side stones (stone_veined, stone_mould, which lie
## on the surface's ash zones) are left out for that. M4a: the mossy stone (it lies on the surface's
## grass) is left out too, for the offline start weapon's slot. The cleric's holy light is not in it
## (the cleric starts with it; --give=holy_light gives it to anyone).
static func debug_kit() -> Array[Array]:
	return [
		[&"pickaxe", 1], [&"hoe", 1], [&"sickle", 1], [&"watering_can", 1], [&"sword", 1], [&"bow", 1], [&"torch", 10],
		[&"wild_healing", 12], [&"mushroom_a", 5], [&"stone_a", 30], [&"stone_block", 8],
		[&"wild_healing", 3, Grade.FINE], [&"wild_buff", 4], [&"wild_poison", 2], [&"herb_clump", 6],
		[&"mushroom_b", 3], [&"mushroom_c", 2], [&"mushroom_d", 1], [&"mushroom_ash", 2],
		[&"stone_b", 4], [&"stone_c", 4],
	]


static func _build() -> void:
	if not _table.is_empty():
		return
	# Tools: one per body action that draws a hand tool (● brief §5.6 R25, 03-pixel/prompts.md 10차).
	_tool(&"pickaxe", RigData.Anim.PICKAXE)
	_tool(&"hoe", RigData.Anim.HOE)
	_tool(&"sickle", RigData.Anim.SICKLE)
	_tool(&"watering_can", RigData.Anim.WATERING)
	_tool(&"sword", RigData.Anim.SWORD)
	_tool(&"bow", RigData.Anim.BOW)
	# Material: the cut stone block (04-env 묶음 2 #61, "건설 재료 덤"), the 3/4 icon v02 (whether
	# material icons are 3/4 v02 or front v03 is ○ brief §5.7).
	_art(&"stone_block", Kind.MATERIAL, Config.STACK_MATERIAL, false, "item_stone_block_v02.png")
	# Gatherables (04-env 묶음 2, size 16): wild herbs grow as item_wild_* and are carried as the
	# picked sprig item_sprig_*; the herb clump, mushrooms and stones look the same in the world and
	# in the inventory.
	_art(&"wild_healing", Kind.GATHERABLE, Config.STACK_GATHERABLE, true, "item_sprig_healing_v02.png",
		"item_wild_healing_v02.png")
	_art(&"wild_buff", Kind.GATHERABLE, Config.STACK_GATHERABLE, true, "item_sprig_buff_v02.png",
		"item_wild_buff_v02.png")
	_art(&"wild_poison", Kind.GATHERABLE, Config.STACK_GATHERABLE, true, "item_sprig_poison_v02.png",
		"item_wild_poison_v02.png")
	_art(&"herb_clump", Kind.GATHERABLE, Config.STACK_GATHERABLE, true, "item_wild_herb_clump_v02.png")
	for m: String in ["a", "b", "c", "d", "ash"]:
		_art(StringName("mushroom_" + m), Kind.GATHERABLE, Config.STACK_GATHERABLE, false, "item_mushroom_%s_v02.png" % m)
	for s: String in ["a", "b", "c", "mossy", "veined", "mould"]:
		_art(StringName("stone_" + s), Kind.GATHERABLE, Config.STACK_GATHERABLE, false, "item_stone_%s_v02.png" % s)
	# M3a (appended: the wire sends items by index). Ores from mining (04-env 묶음 2 item_ore_*_a, the
	# ones the 04-env dungeon mockup uses), materials like the stone block.
	_art(&"ore_copper", Kind.MATERIAL, Config.STACK_MATERIAL, false, "item_ore_copper_a_v02.png")
	_art(&"ore_iron", Kind.MATERIAL, Config.STACK_MATERIAL, false, "item_ore_iron_a_v02.png")
	# The torch (gameplay-design §3.0 ● R11: "기본 키트 (횃불, 발판)"; the merchant who sells it is M8): the
	# debug kit and --give hand it out. No torch item art exists: the icon is drawn in code
	# (items/item_icons.gd) and the placed torch is the 04-env ground lantern (lit), the only floor
	# light a player puts down in the 04-env art (world/fixture_view.gd). PROVISIONAL stack size (99, the
	# materials' Config.STACK_MATERIAL) and kind PLACEABLE (README "임시값" M3a 횃불).
	var torch: ItemDef = ItemDef.new(&"torch", Kind.PLACEABLE, Config.STACK_MATERIAL)
	torch.icon_code = &"torch"
	torch.place = WorldData.PLACEABLE_TORCH
	_add(torch)
	# M4a (appended): the cleric's basic attack (Config.CLASS_WEAPONS, PROVISIONAL): plays the magic action
	# (03-pixel base_body_v02_magic, no hand tool drawn) and lets a holy-light bolt go (Combat).
	_tool(&"holy_light", RigData.Anim.MAGIC)
	# M6a (appended): the three potions (● game-concept §12 R28: one per crop, healing / buff / status = poison;
	# ● brief §5.7 R29: their colours follow the crops). Graded like the herbs they are brewed from (COMMON /
	# FINE). Icons: regions of the 04-env items strip (STRIP_POTIONS). Kind POTION: "use" drinks, the
	# herbalist's skill throws (items/potions.gd); they play no tool action (def.action -1).
	var potions: Array[StringName] = [&"potion_healing", &"potion_buff", &"potion_poison"]
	var effects: Array[int] = [Potions.Effect.HEAL, Potions.Effect.BUFF, Potions.Effect.POISON]
	for i: int in potions.size():
		var def: ItemDef = ItemDef.new(potions[i], Kind.POTION, Config.STACK_POTION, true)
		def.icon_path = ART_DIR + ITEMS_STRIP
		def.icon_region = Rect2i(STRIP_POTIONS[potions[i]] * 16, 0, 16, 16)
		def.effect = effects[i]
		_add(def)
	# M6a: the alchemy table (○ game-concept §9.7: the herbalist brews at it), a crafting station put down like
	# the torch (PROVISIONAL README "M6a 조제대 얻기": a debug item, --give=alchemy_table; nothing else makes
	# one yet). No item art: the icon is drawn in code; the placed table is 04-env alchemy_table_v05.
	var table: ItemDef = ItemDef.new(&"alchemy_table", Kind.PLACEABLE, Config.STACK_MATERIAL)
	table.icon_code = &"alchemy_table"
	table.place = WorldData.PLACEABLE_ALCHEMY
	_add(table)
	# M5a (appended): the three crops' seeds (● game-concept §12 R28 crops; who may plant which is ● R37, Farming).
	# Kind SEED, no grade (PROVISIONAL: the grade is the harvest's, Config.CROP_GRADE_BY_HARVESTER), stack
	# Config.STACK_SEED. Icons: the items strip's seed bags (STRIP_SEEDS). No action: a click plants (like the torch).
	for seed_id: StringName in STRIP_SEEDS:
		var s: ItemDef = ItemDef.new(seed_id, Kind.SEED, Config.STACK_SEED)
		s.icon_path = ART_DIR + ITEMS_STRIP
		s.icon_region = Rect2i(STRIP_SEEDS[seed_id] * 16, 0, 16, 16)
		_add(s)
	# M5b (appended): holy water (● gameplay-design §3.0 R11 paladin row: anyone purifies a few tiles with it; the shop
	# that sells it is M8). Kind CONSUMABLE, no grade, stack Config.STACK_HOLY_WATER. No action of its own: a click pours it
	# (Config.HOLY_WATER_ANIM, items/purify.gd). How it is had is PROVISIONAL (README "M5b 성수 얻기": --give only).
	_art(&"holy_water", Kind.CONSUMABLE, Config.STACK_HOLY_WATER, false, HOLY_WATER_ICON)
	# M7a (appended): wood (logs: the tree is M7b, until then --give; planks are sawn at the workbench) and the ingots
	# smelted at the anvil (README "임시값" M7a 작업대 체인), materials like the ores.
	for wood_id: StringName in WOOD_ICONS:
		_art(wood_id, Kind.MATERIAL, Config.STACK_MATERIAL, false, WOOD_ICONS[wood_id])
	# M7a: the three stations and the storage chest, put down like the alchemy table (PROVISIONAL: made at the previous
	# station, the workbench by hand; --give gives them too). Icons: the placed 04-env picture shrunk (PLACEHOLDER).
	for station_id: StringName in STATION_ITEMS:
		var st: ItemDef = ItemDef.new(station_id, Kind.PLACEABLE, Config.STACK_MATERIAL)
		st.place = STATION_ITEMS[station_id][0]
		st.icon_path = STATION_ITEMS[station_id][1]
		st.icon_fit = true
		_add(st)
	# M7a: the tier-1 weapons (● gameplay-design §3.5: tier 1 anyone's at the anvil): each plays its base weapon's body
	# action and attacks like it, harder (Config.GEAR_T1_BASE, GEAR_T1_DAMAGE_PCT), and wears (Config.GEAR_DURABILITY).
	# Icons: the base weapon's code icon with a gold tier mark (PLACEHOLDER, ItemIcons). No new looks (● R21).
	for t1_id: StringName in Config.GEAR_T1_BASE:
		var base_def: ItemDef = _table[Config.GEAR_T1_BASE[t1_id]]
		var w: ItemDef = ItemDef.new(t1_id, Kind.TOOL, Config.STACK_TOOL, false, base_def.action)
		w.icon_code = base_def.icon_code
		w.base = base_def.id
		w.tier = 1
		w.durability = Config.GEAR_DURABILITY.get(t1_id, 0)
		_add(w)
	# M7a: the one armour piece (○ gameplay-design §2.4 "방어력"; README "임시값" M7a 갑옷), worn in the armour slot.
	var armor: ItemDef = ItemDef.new(&"armor_t1", Kind.ARMOR, Config.STACK_TOOL)
	armor.icon_code = &"armor_t1"
	armor.tier = 1
	armor.durability = Config.GEAR_DURABILITY.get(&"armor_t1", 0)
	_add(armor)


static func _tool(id: StringName, action: int) -> void:
	var def: ItemDef = ItemDef.new(id, Kind.TOOL, Config.STACK_TOOL, false, action)
	def.icon_code = id
	_add(def)


static func _art(id: StringName, kind: int, stack: int, graded: bool, icon: String, world: String = "") -> void:
	var def: ItemDef = ItemDef.new(id, kind, stack, graded)
	def.icon_path = ART_DIR + icon
	def.world_path = ART_DIR + (world if not world.is_empty() else icon)
	_add(def)


static func _add(def: ItemDef) -> void:
	_table[def.id] = def
	_order.append(def.id)

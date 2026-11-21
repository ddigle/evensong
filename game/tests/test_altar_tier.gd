extends "res://tests/base_test.gd"
## M12a, the relic and the altar's tier 1 (● game-concept §9.3 R49: the boss drop is the one thing the altar's next tier needs, ● brief §5.7
## R49: its picture is candA; ○ §9.3 the safe radius grows; every number PROVISIONAL, README "임시값" M12a): the relic item (a code icon,
## kept out of the death bag, the merchant neither sells nor buys it, the chest takes it), the relic bench's upgrade (unlocked by the
## first relic, exactly one relic and nothing else, tier 0 -> 1, refused with nothing spent at the maximum and without a world's progress,
## anyone's, its CRAFT index after every older recipe), the light = safe radius 7 -> 9 tiles and every rule that reads it (heretic spawn
## tiles and the light rule, fields, building costs, the creatures' spawns, the merchant's tile, the prayer circle as it was, the
## carried altar keeping the tier), the candA picture (its 9 lamps on the prayer's lamps, its candles), the heretic shrine's demon-orange
## fire (lit while it stands, out when broken, its light no safety; the faith flames still candle gold), the pillar's four pictures and
## the boss's code-drawn view.

const TICK: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_relic()
	_check_upgrade()
	_check_radius_rules()
	_check_carry_keeps_tier()
	_check_altar_picture()
	await _check_world_view()
	await _check_shrine_fire()
	_check_pillar_art()
	_check_boss_view()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	_nodes.append(p)
	return p


# --- the relic -----------------------------------------------------------------------------------------------------------------

func _check_relic() -> void:
	var def: ItemDB.ItemDef = ItemDB.get_def(Config.BOSS_RELIC)
	check(def != null, "the relic is an item")
	check(def.is_relic() and def.kind == ItemDB.Kind.RELIC, "of its own kind")
	check_eq(ItemDB.KIND_NAMES[ItemDB.Kind.RELIC], "relic", "named")
	check_eq(ItemDB.index_of(Config.BOSS_RELIC), ItemDB.count() - 1, "appended at the table's end (older indices kept)")
	check_eq(def.stack_max, Config.STACK_RELIC, "its stack")
	var icon: Texture2D = ItemIcons.texture_for(Config.BOSS_RELIC)
	check(icon != null and icon.get_width() == 16 and icon.get_height() == 16, "a 16x16 code icon")
	check(ItemIcons.texture_for(Config.ALTAR_UPGRADE) != null, "the upgrade row's picture (no item)")
	check(not ItemDB.has(Config.ALTAR_UPGRADE), "the upgrade is no item")
	# The death bag keeps it (○ §2.6 "퀘스트 아이템 제외").
	var d: WorldData = WorldData.new(Vector2i(30, 20))
	var inv: Inventory = Inventory.new(Config.INVENTORY_SLOTS, Config.HOTBAR_SLOTS)
	inv.add(Config.BOSS_RELIC, 2)
	inv.add(&"stone_a", 10)
	var o: WorldItems.Outcome = WorldItems.death_drop(d, Vector2(200, 160), inv, Config.DEATH_DROP_HALF)
	check(o.ok(), "a bag drops")
	check_eq(inv.count_of(Config.BOSS_RELIC), 2, "the relics stay in the inventory")
	check_eq(inv.count_of(&"stone_a"), 5, "half the stones go")
	var only: Inventory = Inventory.new(Config.INVENTORY_SLOTS, Config.HOTBAR_SLOTS)
	only.add(Config.BOSS_RELIC, 1)
	check_eq(WorldItems.death_drop(WorldData.new(Vector2i(30, 20)), Vector2(200, 160), only, Config.DEATH_DROP_KINDS, 7).why,
		WorldItems.WHY_NOTHING_TO_DROP, "relics alone: no bag (the random-kinds rule too)")
	# The merchant neither sells nor buys it.
	check(Shop.offer_of(Config.BOSS_RELIC) == null, "not for sale")
	check_eq(Shop.pays_for(Config.BOSS_RELIC), 0, "not bought")
	var sell: Inventory = Inventory.new(Config.INVENTORY_SLOTS, Config.HOTBAR_SLOTS)
	sell.add(Config.BOSS_RELIC, 1)
	check_eq(Shop.sell_refusal(sell, 0, false), Shop.WHY_NOT_BOUGHT, "selling it is refused")
	# The chest takes it.
	var chest: WorldData.Chest = WorldData.Chest.new()
	var m: Storage.Moved = Storage.store(chest, sell, 0)
	check(m.ok(), "the chest takes it")
	check_eq(sell.count_of(Config.BOSS_RELIC), 0, "out of the inventory")
	var held: int = 0
	for st: ItemStack in chest.slots:
		if st != null and st.id == Config.BOSS_RELIC:
			held += st.count
	check_eq(held, 1, "in the chest")


# --- the upgrade ---------------------------------------------------------------------------------------------------------------

func _check_upgrade() -> void:
	var r: Crafting.Recipe = Crafting.recipe(Config.ALTAR_UPGRADE)
	check(r != null, "the altar upgrade is a recipe")
	check(r.is_upgrade() and r.upgrade == Config.ALTAR_UPGRADE, "an upgrade (no item out)")
	check_eq(r.station, Crafting.RELIC, "at the relic bench")
	check_eq(r.inputs.size(), 1, "one input")
	check_eq(r.inputs[0].item, Config.BOSS_RELIC, "the relic")
	check_eq(r.inputs[0].count, 1, "exactly one")
	check(r.inputs[0].others.is_empty(), "nothing does instead")
	check(r.classes.is_empty(), "anyone's (● R49: no class contribution)")
	check_eq(Crafting.index_of(Config.ALTAR_UPGRADE), Crafting.recipe_count() - 1, "after every older recipe (CRAFT indices kept)")
	var before: int = 6 + Config.STATION_RECIPES.size() + Config.GEAR_REPAIR_MATERIAL.size() + Config.BUILD_RECIPES.size() \
		+ Config.COLLECTION_RECIPES.size() + Config.GEAR_REPAIR_RARE.size()
	check_eq(Crafting.recipe_count(), before + Config.ALTAR_UPGRADE_RECIPES.size(), "one recipe more")
	check(Crafting.recipes_for(Crafting.RELIC).has(r), "the relic bench shows it")
	# Locked until a relic has been held.
	var inv: Inventory = Inventory.new(Config.INVENTORY_SLOTS, Config.HOTBAR_SLOTS)
	inv.add(&"stone_a", 5)
	inv.add(&"ingot_copper", 3)
	check(not Crafting.shown_recipes(Crafting.RELIC, inv).has(r), "locked before the first relic")
	inv.add(Config.BOSS_RELIC, 2)
	check(Crafting.shown_recipes(Crafting.RELIC, inv).has(r), "unlocked by the first relic")
	# No world progress (a session host until M12c, a bare inventory): refused, nothing spent.
	check_eq(Crafting.refusal(r, "paladin", inv), Crafting.WHY_NO_ALTAR, "no progress to raise: refused")
	var o0: Crafting.Outcome = Crafting.craft(r, "paladin", inv)
	check(not o0.ok() and inv.count_of(Config.BOSS_RELIC) == 2, "and nothing spent")
	# With the world's progress: one relic and nothing else, tier 0 -> 1.
	var progress: WorldProgress = WorldProgress.new()
	var slots_before: Array[String] = _slots(inv)
	for class_id: String in Config.CLASSES:
		check_eq(Crafting.refusal(r, class_id, inv, progress), "", "%s may" % class_id)
	var o: Crafting.Outcome = Crafting.craft(r, "herbalist", inv, progress)
	check(o.ok(), "crafted")
	check_eq(o.item, Config.ALTAR_UPGRADE, "it raised the altar")
	check_eq(progress.altar_tier, 1, "tier 1")
	check_eq(inv.count_of(Config.BOSS_RELIC), 1, "exactly one relic spent")
	var slots_after: Array[String] = _slots(inv)
	var changed: int = 0
	for i: int in slots_before.size():
		if slots_before[i] != slots_after[i]:
			changed += 1
	check_eq(changed, 1, "nothing else changed")
	check_eq(inv.count_of(&"stone_a") + inv.count_of(&"ingot_copper"), 8, "the stones and the ingots untouched")
	# At the slice's maximum: refused, nothing spent.
	check_eq(Crafting.refusal(r, "paladin", inv, progress), Crafting.WHY_TIER_MAX, "at tier 1: refused")
	var o2: Crafting.Outcome = Crafting.craft(r, "paladin", inv, progress)
	check(not o2.ok(), "refused")
	check_eq(inv.count_of(Config.BOSS_RELIC), 1, "nothing spent")
	check_eq(progress.altar_tier, Config.ALTAR_TIER_MAX, "still the maximum")
	# Without a relic: missing.
	var none: Inventory = Inventory.new(Config.INVENTORY_SLOTS, Config.HOTBAR_SLOTS)
	none.add(Config.BOSS_RELIC, 1)
	none.remove(0, 1)
	check_eq(Crafting.refusal(r, "paladin", none, WorldProgress.new()), Crafting.WHY_MISSING, "no relic: missing")
	# The merchant's no-profit rule over every recipe still holds: the upgrade sells for nothing.
	check_eq(Shop.pays_for(r.output), 0, "its output is worth nothing to the merchant")


static func _slots(inv: Inventory) -> Array[String]:
	var out: Array[String] = []
	for i: int in inv.size():
		var s: ItemStack = inv.stack_at(i)
		out.append("" if s == null else "%s:%d:%d" % [s.id, s.count, s.grade])
	return out


# --- the radius and the rules that read it ---------------------------------------------------------------------------------------

func _check_radius_rules() -> void:
	check_eq(Config.ALTAR_TIER_RADIUS_TILES[0], Config.SAFE_RADIUS_TILES, "tier 0 is the old radius")
	check_eq(Config.safe_radius_px_at(0), Config.safe_radius_px(), "the same px")
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	check_eq(SafeZone.for_world(data).radius, Config.safe_radius_px(), "no progress: as before")
	data.progress = WorldProgress.new()
	check_eq(SafeZone.for_world(data).radius, Config.safe_radius_px(), "tier 0: as before")
	var centre: Vector2 = data.altar_center_px()
	var ring_tile: Vector2i = Aim.cell_of(centre + Vector2(8.0 * Config.TILE, 0))
	var ring_px: Vector2 = (Vector2(ring_tile) + Vector2(0.5, 0.5)) * Config.TILE
	# Before the raise: the arena's spawn tiles, the light rule, a field, a building cost, the creatures' clearance.
	var a: Arena = Arena.new()
	a.setup(data, Config.DEFAULT_SEED)
	var spawn_before: int = a.spawn_cells.size()
	var herd: Creatures = Creatures.new()
	herd.setup(data, Config.DEFAULT_SEED, false)
	check(not a.in_light(ring_px), "8 tiles out: outside the light at tier 0")
	check(not Farming.in_light(data, ring_tile), "no field there")
	check_eq(Building.cost_at(data, ring_tile), Config.BUILD_COST_OUTSIDE_LIGHT, "the outside cost")
	var merchant_before: Vector2i = Merchant.spot_for(data)
	data.progress.raise_altar()
	check_eq(SafeZone.for_world(data).radius, float(9 * Config.TILE), "tier 1: 9 tiles")
	check(a.sync_world(), "the arena sees the raise")
	check(a.in_light(ring_px), "8 tiles out: in the light at tier 1 (heretics keep out)")
	check(a.spawn_cells.size() <= spawn_before, "spawn tiles: none inside the wider light (%d -> %d)" % [spawn_before, a.spawn_cells.size()])
	for c: Vector2i in a.spawn_cells:
		if not Combat.box_outside_light(data, a.safe, Arena.spawn_feet(c)):
			fail("a spawn tile inside the wider light: %s" % c)
			break
	check(Farming.in_light(data, ring_tile), "a field there now")
	check_eq(Building.cost_at(data, ring_tile), Config.BUILD_COST_IN_LIGHT, "the light's cost there")
	herd.step([] as Array[Player])
	check_eq(herd.safe.radius, float(9 * Config.TILE), "the creatures' light follows")
	check_eq(Merchant.spot_for(data), merchant_before, "the merchant's tile stays")
	check_eq(Config.PRAYER_CIRCLE_RADIUS_PX, 64.0, "the prayer circle stays 64 px")
	check_eq(AltarGhost.light_dots(data.altar_rect, WorldProgress.radius_px(data)).size(), 360 / AltarGhost.DOT_STEP, "the ghost's dots")
	check(AltarGhost.light_dots(data.altar_rect, WorldProgress.radius_px(data))[0].x > AltarGhost.light_dots(data.altar_rect)[0].x,
		"farther out at tier 1")


func _check_carry_keeps_tier() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	data.progress = WorldProgress.new()
	data.progress.raise_altar()
	var home: Rect2i = data.altar_rect
	for e: EditLog.WorldEdit in AltarMove.pickup_edits(data):
		EditLog.apply_to_data(data, e)
	check(not data.altar_rect.has_area(), "carried")
	check_eq(SafeZone.for_world(data).radius, 0.0, "no light while carried")
	check_eq(data.progress.altar_tier, 1, "the tier stays with the world")
	var to: Rect2i = Rect2i(home.position + Vector2i(-12, 2), home.size)
	check_eq(AltarMove.place_refusal(data, to), "", "a free place")
	for e2: EditLog.WorldEdit in AltarMove.place_edits(to):
		EditLog.apply_to_data(data, e2)
	check_eq(data.altar_rect, to, "put down")
	check_eq(SafeZone.for_world(data).radius, float(9 * Config.TILE), "its light is tier 1's there")


# --- the picture ----------------------------------------------------------------------------------------------------------------

func _check_altar_picture() -> void:
	check_eq(Altar.LIT_UP1.get_size(), Vector2(56, 64), "candA is 56x64")
	check_eq(Altar.tier_shift(1), Vector2i(-4, -7), "placed (-4, -7) from altar_v04 (the art notes)")
	check_eq(Altar.lamp_shift(1), Vector2i(4, 7), "its lamps (4, 7) into the picture")
	var mask0: Image = Altar.tier_flame_image(0)
	var mask1: Image = Altar.tier_flame_image(1)
	check_eq(LightGen.count_opaque(mask0), 81, "tier 0: 81 flame px (nine lamps)")
	var candles: int = LightGen.count_opaque(mask1) - 81
	check(candles > 0, "tier 1: the nine lamps and the four candles' flames (%d px)" % candles)
	for y0: int in mask1.get_height():
		for x0: int in mask1.get_width():
			if mask1.get_pixel(x0, y0).a8 > 0 and not ((x0 >= 5 and x0 <= 8) or (x0 >= 46 and x0 <= 49)):
				var on_lamp: bool = false
				for k: int in Config.PRAYER_LAMP_FLAMES.size():
					on_lamp = on_lamp or Rect2i(Altar.lamp_flame(k, 1), Altar.FLAME_SIZE).has_point(Vector2i(x0, y0))
				if not on_lamp:
					fail("a tier-1 flame pixel on neither a lamp nor a candle: %d,%d" % [x0, y0])
	var lamp_px: int = 0
	for i: int in Config.PRAYER_LAMP_FLAMES.size():
		var f: Vector2i = Altar.lamp_flame(i, 1)
		var here: int = 0
		for dy: int in Altar.FLAME_SIZE.y:
			for dx: int in Altar.FLAME_SIZE.x:
				if mask1.get_pixel(f.x + dx, f.y + dy).a8 > 0:
					here += 1
		check_eq(here, 9, "lamp %d sits on candA's lamp (9 px)" % i)
		lamp_px += here
		check(Rect2i(Vector2i.ZERO, Vector2i(56, 64)).encloses(Altar.lamp_box(i, 1)), "lamp %d's box inside the picture" % i)
	check_eq(lamp_px, 81, "all nine")
	# A lamp box on candA covers its flame with candA's unlit picture (no flame left there).
	var unlit: Image = LightGen.to_rgba8(Altar.UNLIT_UP1.get_image())
	var lit: Image = LightGen.to_rgba8(Altar.LIT_UP1.get_image())
	var b: Rect2i = Altar.lamp_box(0, 1)
	var differ: int = 0
	for y: int in range(b.position.y, b.end.y):
		for x: int in range(b.position.x, b.end.x):
			if lit.get_pixel(x, y) != unlit.get_pixel(x, y):
				differ += 1
	check(differ > 0, "the lit and unlit candA differ on lamp 0's box")
	var view: Altar = Altar.new()
	view.setup(Rect2i(10, 10, 3, 3))
	check(view.sprite.texture == Altar.LIT, "tier 0: altar_v04")
	view.set_tier(1)
	check(view.sprite.texture == Altar.LIT_UP1, "tier 1: candA")
	check(view.flames.texture == Altar.tier_flame_texture(1), "its flames")
	check_eq(Vector2i(view.sprite.position + view.position), Vector2i(160, 160) + Vector2i(-4, -7), "drawn (-4, -7) from v04's place")
	view.free()


func _check_world_view() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	w.data.progress = WorldProgress.new()
	var heard: Array[int] = [0]
	w.tier_changed.connect(func() -> void: heard[0] += 1)
	var tex0: Texture2D = w.lighting.altar_light.actor_light.texture
	w.data.progress.raise_altar()
	w.altar_tier_changed()
	check_eq(heard[0], 1, "tier_changed heard")
	check_eq(w.safe_zone.radius, float(9 * Config.TILE), "the world's zone: 9 tiles")
	check(w.altar != null and w.altar.tier == 1, "the altar shows tier 1")
	check(w.altar.sprite.texture == Altar.LIT_UP1, "candA")
	var tex1: Texture2D = w.lighting.altar_light.actor_light.texture
	check(tex1 != tex0, "a wider light")
	check_eq(tex1.get_width(), LightGen.texture_size(w.safe_zone), "its texture: the zone's size")
	check(w.lighting.altar_light.zone.radius == w.safe_zone.radius, "the light is the zone")
	w.data.progress.altar_tier = 0
	w.altar_tier_changed()
	check(w.altar.sprite.texture == Altar.LIT, "back at tier 0 (a test): altar_v04")


# --- the heretic fire ---------------------------------------------------------------------------------------------------------

func _check_shrine_fire() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	w.map_id = Config.MAP_DUNGEON
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	var rect: Rect2i = DungeonGen.shrine_rect(w.data)
	var n: Node2D = w.fixtures.nodes[rect.position]
	for flame_name: String in ["FlameLeft", "FlameRight", "FlameTop"]:
		var f: Sprite2D = n.get_node_or_null(NodePath(flame_name)) as Sprite2D
		var g: Sprite2D = n.get_node_or_null(NodePath(flame_name + "Glow")) as Sprite2D
		check(f != null and g != null, "the standing shrine burns: %s" % flame_name)
		if f != null:
			check(f.texture == FixtureView.HERETIC_FLAME_LARGE or f.texture == FixtureView.HERETIC_FLAME_SMALL, "demon orange (candB)")
			check_eq(f.hframes, FixtureView.FLAME_FRAMES, "its frames")
		if g != null:
			check(g.material == FixtureView.unshaded_material(), "its glow unshaded")
	var light: PointLight2D = n.get_node_or_null(^"FireLight") as PointLight2D
	check(light != null, "an orange light")
	if light != null:
		check_eq(light.color, Config.HERETIC_FIRE_LIGHT_COLOR, "orange")
	check_eq(w.fixtures.verify()["mismatches"], 0, "fixtures = data")
	check_eq(w.fixtures.verify()["lights"], w.fixtures.verify()["torches"], "the fire's light is no torch light (not counted)")
	# Its light is no safety: the light rule does not see it.
	var near: Vector2 = Vector2(FixtureView.foot_of(rect).x, (rect.end.y + 1) * Config.TILE - 4.0)
	check(not Combat.in_safe_light(w.data, SafeZone.for_world(w.data), near), "the fire's light is not safety")
	# The large flame's colours are the demon row (no candle gold), the glow only where the emissive mask is.
	var img: Image = LightGen.to_rgba8(FixtureView.HERETIC_FLAME_LARGE.get_image())
	var orange: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var p: Color = img.get_pixel(x, y)
			if p.a8 > 0 and p.r8 == 0xff and p.g8 == 0x7a and p.b8 == 0x1a:
				orange += 1
	check(orange > 0, "the large flame's core is #ff7a1a")
	check(LightGen.count_opaque(LightGen.to_rgba8(FixtureView.heretic_glow_texture(true).get_image())) > 0, "the glow has pixels")
	# Faith-side flames stay candle gold.
	check(FixtureView.FLAME.resource_path.ends_with("flame_large_v01.png"), "the wall torches' flame is the gold one")
	check(FixtureView.SMALL_FLAME.resource_path.ends_with("flame_small_v01.png"), "the relic bench's candle too")
	check(Altar.LIT.resource_path.ends_with("altar_v04.png"), "the altar's lamps too")
	# Broken: out.
	for y2: int in range(rect.position.y, rect.end.y):
		for x2: int in range(rect.position.x, rect.end.x):
			w.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(x2, y2), WorldData.PLACEABLE_SHRINE_BROKEN))
	var broken: Node2D = w.fixtures.nodes[rect.position]
	check_eq(broken.name, &"ShrineBroken", "the broken shrine")
	check(broken.get_node_or_null(^"FlameLeft") == null and broken.get_node_or_null(^"FireLight") == null, "its fire is out")


# --- the pillar and the boss's pictures ----------------------------------------------------------------------------------------

func _check_pillar_art() -> void:
	var src: Image = LightGen.to_rgba8(PillarArt.PICTURE.get_image())
	var imgs: Array[Image] = []
	for k: int in 4:
		var img: Image = PillarArt.image(k)
		imgs.append(img)
		check_eq(img.get_size(), Vector2i(32, 64), "state %d: 32x64" % k)
		var half: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				var a: int = img.get_pixel(x, y).a8
				if a != 0 and a != 255:
					half += 1
		check_eq(half, 0, "state %d: no half-transparent pixel" % k)
	check(imgs[0].get_data() == src.get_data(), "intact = the 04-env picture")
	for k2: int in range(1, 4):
		check(imgs[k2].get_data() != imgs[k2 - 1].get_data(), "state %d differs from %d" % [k2, k2 - 1])
	var top3: int = 64
	for y3: int in 64:
		for x3: int in 32:
			if imgs[3].get_pixel(x3, y3).a8 > 0:
				top3 = mini(top3, y3)
	check(top3 >= 38, "broken: only the stub (top row %d)" % top3)
	check(PillarArt.texture(2) == PillarArt.texture(2), "cached")
	check_eq(PillarArt.origin(Vector2i(10, 10)), Vector2i(10 * 16 + 8 - PillarArt.CENTRE_X, 11 * 16 - 1 - PillarArt.BOTTOM_ROW),
		"stands on its tile's bottom row")


func _check_boss_view() -> void:
	for a: int in HereticSim.SHEET_PATHS.size():
		var src: Texture2D = BossView.SOURCE_SHEETS[a]
		var tex: ImageTexture = BossView.sheet(a)
		var c: int = HereticSim.CELLS[a]
		check_eq(tex.get_width(), src.get_width() / c * BossView.cell(a), "anim %d: cells padded" % a)
		check_eq(tex.get_height(), 3 * BossView.cell(a), "anim %d: three rows" % a)
	# The idle frame south: the mitre's gold band and stone are drawn, the outline ring is there, the robe recoloured.
	var img: Image = BossView.sheet(HereticSim.Anim.IDLE).get_image()
	var r: Rect2i = BossView.frame_rect(HereticSim.Anim.IDLE, 0, 0)
	var gold: int = 0
	var stone: int = 0
	var ring: int = 0
	var robe: int = 0
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			var p: Color = img.get_pixel(x, y)
			if p.a8 == 0:
				continue
			if p == BossView.MITRE_COLOURS["g"]:
				gold += 1
			if p == BossView.MITRE_COLOURS["F"]:
				stone += 1
			if p == BossView.OUTLINE:
				ring += 1
			if BossView.ROBE.has(p):
				robe += 1
	check(gold >= 6, "the mitre's gold band (%d px)" % gold)
	check(stone >= 4, "its demon-orange stone (%d px)" % stone)
	check(ring > 40, "a second outline (%d px)" % ring)
	check(robe > 40, "the robe recoloured (%d px)" % robe)
	check_eq(BossView.recolour(Color8(0x1a, 0x17, 0x14)), Color8(0x1a, 0x17, 0x14), "the outline colour stays")
	# The M11a hit-box rule on its picture: box height = the tallest standing picture +-2, 2r <= its widest standing picture + 2.
	var tallest: int = 0
	var widest: int = 0
	for a2: int in [HereticSim.Anim.WALK, HereticSim.Anim.IDLE]:
		var sheet_img: Image = BossView.sheet(a2).get_image()
		for row: int in 3:
			for f: int in HereticSim.FRAME_COUNTS[a2]:
				var cr: Rect2i = BossView.frame_rect(a2, row, f)
				var feet: Vector2i = cr.position - BossView.cell_offset(a2)
				var lo: Vector2i = Vector2i(9999, 9999)
				var hi: Vector2i = Vector2i(-9999, -9999)
				for y2: int in range(cr.position.y, cr.end.y):
					for x2: int in range(cr.position.x, cr.end.x):
						if sheet_img.get_pixel(x2, y2).a8 > 0:
							lo = lo.min(Vector2i(x2, y2))
							hi = hi.max(Vector2i(x2, y2))
				tallest = maxi(tallest, (feet.y - lo.y) * BossView.SCALE)
				widest = maxi(widest, (hi.x - lo.x + 1) * BossView.SCALE)
	note("boss picture: tallest standing %d px, widest %d px; box %d tall, %d wide" % [tallest, widest,
		roundi(Config.BOSS["hit_height_px"]), roundi(2.0 * Config.BOSS["hit_radius_px"])])
	check(absi(roundi(Config.BOSS["hit_height_px"]) - tallest) <= 2, "the box's height is the picture's (+-2)")
	check(roundi(2.0 * Config.BOSS["hit_radius_px"]) <= widest + 2, "its width within the picture's")
	check(BossView.SCALE >= 1, "an integer scale")
	# The view shows a sim.
	var v: BossView = BossView.new()
	_nodes.append(v)
	var b: BossSim = BossSim.new()
	b.pos = Vector2(100, 100)
	b.facing = RigData.Dir.WEST
	b.state = BossSim.State.CHASE
	b.walking = true
	b.clock = 7
	v.show_sim(b)
	check_eq(v.anim, HereticSim.Anim.WALK, "walking")
	check_eq(v.rig.scale.x, -1.0, "west mirrored")
	check_eq(v.position, Vector2(100, 100), "on its feet")
	b.state = BossSim.State.DEAD
	b.state_ticks = 999
	v.show_sim(b)
	check_eq(v.anim, HereticSim.Anim.DEATH, "dead: the death frames")
	check_eq(v.frame, HereticSim.FRAME_COUNTS[HereticSim.Anim.DEATH] - 1, "lying")
	check(not v.flame.visible and not v.light.enabled, "its fire out")

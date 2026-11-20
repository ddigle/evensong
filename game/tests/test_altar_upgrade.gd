extends "res://tests/base_test.gd"
## M12b, the altar upgrade and what its light reaches (● game-concept §9.3 R49: the boss drop is the only thing the next tier needs; ● brief §5.7
## R49: candA, the heretic-side fire demon orange, the faith-side flames candle gold; ○ §9.3 the safe radius grows; every number PROVISIONAL,
## README "임시값" M12a / M12b): the relic bench recipe (unlocked by the first relic and kept unlocked, one relic and nothing else for every
## class with an empty collection and no archer, exactly one of three spent, refused with nothing spent at tier 1) and, through main.tscn,
## only at the relic bench (not the workbench's, the anvil's or the hand's list; away from it the panel closes and a row press does nothing;
## the heretic the raise lights is counted); the light's old and new edge (tilling, planting, a crop withering at tier 0 and coming back at
## tier 1 - the Farm kept its M5-fix causes over the raise before M12b - the building cost), the heretics (the spawn tiles exactly those
## outside the wider light, one standing where the light now reaches walks straight out of it, one beyond is left alone), the light's
## texels (= the safe zone at 9 tiles, its dithered edge inside it), the creatures (one in the ring walks out, a spawn spot just past the
## old clearance refused), the merchant's tile and the prayer circle as they were, the world's view through a raise and a carry (candA and
## the 9-tile light where the altar is put down), the flames' colours (demon orange only on the heretic side, candle gold only on the faith
## side, the faith pictures byte for byte main's) and the shrine's fire through combat (lit, then out when the arena breaks it).

const TICK: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_recipe()
	await _check_bench_main()
	_check_edges_and_fields()
	_check_heretics()
	_check_light_texels()
	_check_creatures()
	_check_merchant_and_prayer()
	await _check_world_follows()
	_check_flame_colours()
	await _check_shrine_fire_combat()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


static func slots(inv: Inventory) -> Array[String]:
	var out: Array[String] = []
	for i: int in inv.size():
		var s: ItemStack = inv.stack_at(i)
		out.append("" if s == null else "%s:%d:%d:%d" % [s.id, s.count, s.grade, s.durability])
	return out


static func slot_of(inv: Inventory, id: StringName) -> int:
	for i: int in inv.size():
		if inv.stack_at(i) != null and inv.stack_at(i).id == id:
			return i
	return -1


## The surface of seed 1 with the world's progress (tier 0).
static func surface() -> WorldData:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	d.progress = WorldProgress.new()
	return d


## Tile `k` tiles east of the altar's middle tile.
static func east(d: WorldData, k: int) -> Vector2i:
	return Aim.cell_of(d.altar_center_px()) + Vector2i(k, 0)


static func tile_middle(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * Config.TILE


# --- the recipe ------------------------------------------------------------------------------------------------------------------

func _check_recipe() -> void:
	var r: Crafting.Recipe = Crafting.recipe(Config.ALTAR_UPGRADE)
	var inv: Inventory = Inventory.new(Config.INVENTORY_SLOTS, Config.HOTBAR_SLOTS)
	check(not Crafting.unlocked(r, inv), "locked before any relic")
	inv.add(Config.BOSS_RELIC, 1)
	check(Crafting.unlocked(r, inv), "the first relic held unlocks it")
	inv.remove(slot_of(inv, Config.BOSS_RELIC), 1)
	check(Crafting.unlocked(r, inv) and Crafting.shown_recipes(Crafting.RELIC, inv).has(r), "and it stays unlocked once the relic is gone")
	check_eq(Crafting.refusal(r, "cleric", inv, WorldProgress.new()), Crafting.WHY_MISSING, "but with no relic: missing")
	# One relic and nothing else, every class but the archer, an empty collection (● R49: an archer-less party is never blocked).
	var col: Collection = Collection.new()
	check_eq(col.count(), 0, "an empty collection")
	for class_id: String in ["paladin", "miner", "cleric", "herbalist"]:
		var only: Inventory = Inventory.new(Config.INVENTORY_SLOTS, Config.HOTBAR_SLOTS)
		only.add(Config.BOSS_RELIC, 1)
		var progress: WorldProgress = WorldProgress.new()
		check_eq(Crafting.refusal(r, class_id, only, progress), "", "%s with a relic and nothing else may" % class_id)
		var o: Crafting.Outcome = Crafting.craft(r, class_id, only, progress)
		check(o.ok() and progress.altar_tier == 1, "%s raised it" % class_id)
		var left: int = 0
		for s: String in slots(only):
			if not s.is_empty():
				left += 1
		check_eq(left, 0, "%s: the relic gone, nothing else there" % class_id)
	# Exactly one of three; everything else held stays as it was.
	var three: Inventory = Inventory.new(Config.INVENTORY_SLOTS, Config.HOTBAR_SLOTS)
	three.add(&"pickaxe", 1)
	three.add(Config.BOSS_RELIC, 3)
	three.add(&"money", 40)
	three.add(&"ingot_copper", 5)
	three.add(&"hide_fine", 2)
	var before: Array[String] = slots(three)
	var prog: WorldProgress = WorldProgress.new()
	check(Crafting.craft(r, "paladin", three, prog).ok(), "crafted with three")
	check_eq(three.count_of(Config.BOSS_RELIC), 2, "exactly one spent")
	var after: Array[String] = slots(three)
	var changed: int = 0
	for i: int in before.size():
		if before[i] != after[i]:
			changed += 1
			check(before[i].begins_with(String(Config.BOSS_RELIC)), "only the relic's slot changed (%s -> %s)" % [before[i], after[i]])
	check_eq(changed, 1, "one slot changed")
	# At tier 1: refused, nothing at all spent.
	var held: Array[String] = slots(three)
	check_eq(Crafting.refusal(r, "paladin", three, prog), Crafting.WHY_TIER_MAX, "tier 1: refused")
	check(not Crafting.craft(r, "paladin", three, prog).ok(), "not crafted")
	check_eq(slots(three), held, "nothing spent")
	check_eq(prog.altar_tier, 1, "still tier 1 (the slice's maximum)")
	check_eq(prog.revision, 1, "one change only")


## Through main.tscn: only the relic bench lists it, away from the bench nothing happens, at the bench one relic raises the world's tier
## with an empty collection; the heretic the wider light reaches is counted.
func _check_bench_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.arenas[Config.MAP_SURFACE].spawning = false
	main.arenas[Config.MAP_DUNGEON].spawning = false
	main.spawn("herbalist")
	var p: Player = main.player
	p.local_input = false
	check(main.world_collection() != null and main.world_collection().count() == 0, "main: the world's collection is empty")
	check_eq(main.world_progress().altar_tier, 0, "main: tier 0")
	p.inventory.add(Config.BOSS_RELIC, 1)
	var data: WorldData = main.world.data
	var at: Vector2i = data.altar_rect.position + Vector2i(-1, 5)
	var stations: Array[Array] = [[WorldData.PLACEABLE_WORKBENCH, Config.WORKBENCH_FOOTPRINT, Crafting.WORKBENCH],
		[WorldData.PLACEABLE_ANVIL, Config.ANVIL_FOOTPRINT, Crafting.ANVIL], [WorldData.PLACEABLE_RELIC, Config.RELIC_BENCH_FOOTPRINT, Crafting.RELIC]]
	for spec: Array in stations:
		var value: int = spec[0]
		var size: Vector2i = spec[1]
		var kind: StringName = spec[2]
		for x: int in 3:
			main.world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, at + Vector2i(x, 0), WorldData.PLACEABLE_NONE))
		for x2: int in size.x:
			main.world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, at + Vector2i(x2, 0), value))
		p.teleport(Arena.spawn_feet(at + Vector2i(1, 1)))
		var st: Crafting.StationAt = Crafting.station_near(data, p.sim_position)
		check(st != null and st.kind == kind, "main: at the %s" % kind)
		main.open_crafting(st)
		var listed: bool = false
		for rec: Crafting.Recipe in main.hud.crafting.recipes:
			listed = listed or rec.is_upgrade()
		check_eq(listed, kind == Crafting.RELIC, "main: the %s %s the upgrade" % [kind, "lists" if kind == Crafting.RELIC else "does not list"])
		if kind != Crafting.RELIC:
			main.close_crafting()
	check(not Crafting.shown_recipes(Crafting.HAND, p.inventory).any(func(x: Crafting.Recipe) -> bool: return x.is_upgrade()),
		"main: the hand's list does not have it")
	var row: int = -1
	for i: int in main.hud.crafting.recipes.size():
		if main.hud.crafting.recipes[i].is_upgrade():
			row = i
	# A heretic where the wider light will reach (8 tiles east, outside today's light).
	var ring: Vector2 = _ring_spot(data)
	var h: HereticSim = main.arenas[Config.MAP_SURFACE].spawn_heretic(ring)
	# Away from the bench: the panel closes, a row press does nothing.
	p.teleport(Arena.spawn_feet(at + Vector2i(1, 8)))
	check(Crafting.station_near(data, p.sim_position) == null, "main: 7 tiles away, no station near")
	main._check_crafting()
	check(not main.crafting_open(), "main: away from the bench the panel closes")
	main.craft_row(row)
	check_eq(main.world_progress().altar_tier, 0, "main: a row pressed away from it does nothing")
	check_eq(p.inventory.count_of(Config.BOSS_RELIC), 1, "main: the relic kept")
	# Back at the bench: one relic, tier 1.
	p.teleport(Arena.spawn_feet(at + Vector2i(1, 1)))
	main.open_crafting(Crafting.station_near(data, p.sim_position))
	main.craft_row(row)
	check_eq(main.world_progress().altar_tier, 1, "main: tier 1 at the bench")
	check_eq(p.inventory.count_of(Config.BOSS_RELIC), 0, "main: the one relic spent")
	check_eq(main.world_collection().count(), 0, "main: no collection entry needed")
	check_eq(main.world.safe_zone.radius, float(9 * Config.TILE), "main: the zone 9 tiles")
	check(h.lit_out, "main: the heretic the wider light reached walks out of it")
	check_eq(main.arenas[Config.MAP_SURFACE].stat("lit_out"), 1, "main: counted once")
	p.inventory.add(Config.BOSS_RELIC, 1)
	main.craft_row(row)
	check_eq(p.inventory.count_of(Config.BOSS_RELIC), 1, "main: at tier 1 a second relic is not spent")
	check_eq(main.world_progress().altar_tier, 1, "main: still tier 1")
	main.close_crafting()


## A standable feet spot whose heretic box is outside the tier-0 light but inside the tier-1 one (8 tiles from the altar, first angle that
## works).
static func _ring_spot(d: WorldData) -> Vector2:
	var c: Vector2 = d.altar_center_px()
	var zone0: SafeZone = SafeZone.new(c, Config.safe_radius_px_at(0))
	var zone1: SafeZone = SafeZone.new(c, Config.safe_radius_px_at(1))
	for deg: int in range(0, 360, 15):
		var at: Vector2 = (c + Vector2.from_angle(deg_to_rad(float(deg))) * 8.0 * Config.TILE).round()
		if Movement.can_stand(d, at) and Combat.box_outside_light(d, zone0, at) and not Combat.box_outside_light(d, zone1, at):
			return at
	return c + Vector2(8.0 * Config.TILE, 0)


# --- the edges, the fields, building -------------------------------------------------------------------------------------------

func _check_edges_and_fields() -> void:
	var d: WorldData = surface()
	# Tiles east of the altar's middle tile: 6 = the old edge (in both lights), 7 and 8 = the ring (out, then in), 9 = beyond (out of both).
	var want0: Dictionary[int, bool] = {6: true, 7: false, 8: false, 9: false}
	var want1: Dictionary[int, bool] = {6: true, 7: true, 8: true, 9: false}
	for k: int in want0:
		var c: Vector2i = east(d, k)
		d.set_value(WorldData.Layer.VEGETATION, c, 0)
		d.set_value(WorldData.Layer.PLACEABLE, c, WorldData.PLACEABLE_NONE)
		d.set_terrain(c, Terrain.GRASS)
		check_eq(Farming.in_light(d, c), want0[k], "tile +%d: in the light at tier 0 = %s" % [k, want0[k]])
		check_eq(Building.cost_at(d, c), Config.BUILD_COST_IN_LIGHT if want0[k] else Config.BUILD_COST_OUTSIDE_LIGHT, "tile +%d: tier 0's cost" % k)
	var feet7: Vector2 = Arena.spawn_feet(east(d, 7) + Vector2i(0, 1))
	check_eq(Farming.till_refusal(d, feet7, east(d, 7)), Farming.WHY_DARK, "tier 0: no tilling in the ring")
	# Crops on all four (put there: the light moved away from them, M5b's case), wet.
	var farm: Farm = Farm.new(d)
	for k2: int in want0:
		var c2: Vector2i = east(d, k2)
		d.set_terrain(c2, Terrain.SOIL)
		d.set_value(WorldData.Layer.VEGETATION, c2, Farming.Field.new(Farming.KIND_HEALING, 1, true).value())
		farm.sync_cell(c2)
	for e: EditLog.WorldEdit in farm.step():
		EditLog.apply_to_data(d, e)
	for k3: int in want0:
		check_eq(Farming.field_at(d, east(d, k3)).withered, not want0[k3], "tier 0: the crop at +%d withered = %s" % [k3, not want0[k3]])
	d.progress.raise_altar()
	for e2: EditLog.WorldEdit in farm.step():
		EditLog.apply_to_data(d, e2)
	for k4: int in want1:
		var c4: Vector2i = east(d, k4)
		check_eq(Farming.in_light(d, c4), want1[k4], "tile +%d: in the light at tier 1 = %s" % [k4, want1[k4]])
		check_eq(Farming.field_at(d, c4).withered, not want1[k4], "tier 1: the crop at +%d withered = %s" % [k4, not want1[k4]])
		check_eq(Building.cost_at(d, c4), Config.BUILD_COST_IN_LIGHT if want1[k4] else Config.BUILD_COST_OUTSIDE_LIGHT, "tile +%d: tier 1's cost" % k4)
	check_eq(farm.stat("revived"), 2, "the two ring crops came back the tick after the raise")
	# They grow again (wet, not withered): a stage's ticks later the ring crops are a stage on.
	for t: int in Farming.stage_ticks(false):
		for e3: EditLog.WorldEdit in farm.step():
			EditLog.apply_to_data(d, e3)
	check_eq(Farming.field_at(d, east(d, 7)).stage, 2, "the ring crop grows again")
	check_eq(Farming.field_at(d, east(d, 9)).stage, 1, "the one beyond does not")
	# Tilling and planting in the ring now.
	var fresh: Vector2i = east(d, 7) + Vector2i(0, 2)
	d.set_value(WorldData.Layer.VEGETATION, fresh, 0)
	d.set_value(WorldData.Layer.PLACEABLE, fresh, WorldData.PLACEABLE_NONE)
	d.set_terrain(fresh, Terrain.GRASS)
	var feet_f: Vector2 = Arena.spawn_feet(fresh + Vector2i(0, 1))
	if Farming.in_light(d, fresh):
		check_eq(Farming.till_refusal(d, feet_f, fresh), "", "tier 1: tilling in the ring")
		d.set_terrain(fresh, Terrain.SOIL)
		check_eq(Farming.plant_refusal(d, feet_f, "herbalist", Farming.KIND_HEALING, fresh), "", "and planting")
	else:
		fail("the tile two south of +7 is not in the tier-1 light")


# --- heretics ------------------------------------------------------------------------------------------------------------------

## Moves the altar of `d` (tier 0) next to a corruption zone so that some of the surface's heretic spawn tiles lie where tier 1's light
## will reach (seed 1's generated altar keeps them all farther: no spawn tile is within 9 tiles of it): the first place AltarMove allows
## whose middle is 8 tiles from a spawn tile (4 ways, every 5th spawn tile in order). Returns whether it found one.
static func _altar_by_spawns(d: WorldData) -> bool:
	var cells: Array[Vector2i] = Arena.surface_spawn_cells(d, SafeZone.for_world(d))
	for e: EditLog.WorldEdit in AltarMove.pickup_edits(d):
		EditLog.apply_to_data(d, e)
	for i: int in range(0, cells.size(), 5):
		for dir: Vector2i in [Vector2i(-8, 0), Vector2i(8, 0), Vector2i(0, -8), Vector2i(0, 8)]:
			var rect: Rect2i = Rect2i(cells[i] + dir - Vector2i.ONE, Config.ALTAR_FOOTPRINT)
			if AltarMove.place_refusal(d, rect).is_empty():
				for e2: EditLog.WorldEdit in AltarMove.place_edits(rect):
					EditLog.apply_to_data(d, e2)
				return true
	return false


func _check_heretics() -> void:
	var d: WorldData = surface()
	var gen_cells: Array[Vector2i] = Arena.surface_spawn_cells(d, SafeZone.for_world(d))
	var gen_ring: int = 0
	var gen_zone1: SafeZone = SafeZone.new(d.altar_center_px(), Config.safe_radius_px_at(1))
	for gc: Vector2i in gen_cells:
		if not Combat.box_outside_light(d, gen_zone1, Arena.spawn_feet(gc)):
			gen_ring += 1
	note("seed 1's generated altar: %d heretic spawn tiles, %d of them within the tier-1 light" % [gen_cells.size(), gen_ring])
	if not check(_altar_by_spawns(d), "the altar put down 8 tiles from a spawn tile"):
		return
	note("the altar moved to %s for the heretic checks" % d.altar_rect)
	var a: Arena = Arena.new()
	a.setup(d, Config.DEFAULT_SEED)
	a.spawning = false
	a.threat_on = true
	var before: Array[Vector2i] = a.spawn_cells.duplicate()
	var zone1: SafeZone = SafeZone.new(d.altar_center_px(), Config.safe_radius_px_at(1))
	var lit_now: int = 0
	for c: Vector2i in before:
		if not Combat.box_outside_light(d, zone1, Arena.spawn_feet(c)):
			lit_now += 1
	check(lit_now > 0, "tier 0 has spawn tiles the wider light will cover (%d)" % lit_now)
	var ring: Vector2 = _ring_spot(d)
	var far: Vector2 = d.altar_center_px() + Vector2(0, 12.0 * Config.TILE)
	check(Movement.can_stand(d, far), "a spot 12 tiles south")
	var h: HereticSim = a.spawn_heretic(ring)
	var other: HereticSim = a.spawn_heretic(far)
	# A player standing in the light (no heretic goes for him) and one outside both lights, west.
	var safe_p: Player = Player.new()
	safe_p.setup(d, "paladin", d.altar_center_px() + Vector2(0, 40))
	_nodes.append(safe_p)
	var players: Array[Player] = [safe_p]
	for t: int in 30:
		a.step(players)
	check_eq(h.pos, ring, "tier 0: the heretic 8 tiles out stands (nobody to go for)")
	d.progress.raise_altar()
	check(a.sync_world(), "the arena sees the raise")
	# The spawn tiles: exactly those whose box is outside the wider light.
	var want: Array[Vector2i] = []
	for c2: Vector2i in before:
		if Combat.box_outside_light(d, zone1, Arena.spawn_feet(c2)):
			want.append(c2)
	check_eq(a.spawn_cells, want, "the spawn tiles: tier 0's minus the %d the wider light covers" % lit_now)
	check(h.lit_out, "the one the light reached walks out")
	check(not other.lit_out, "the one 12 tiles out is left alone")
	check_eq(a.stat("lit_out"), 1, "counted once")
	var centre: Vector2 = d.altar_center_px()
	var dist: float = h.pos.distance_to(centre)
	var out_at: int = -1
	var never_in: bool = true
	for t2: int in 240:
		a.step(players)
		var nd: float = h.pos.distance_to(centre)
		if nd < dist - 0.001:
			never_in = false
		dist = nd
		if out_at < 0 and not h.lit_out:
			out_at = t2 + 1
	check(never_in, "it never went nearer the altar")
	check(out_at > 0 and out_at < 120, "out within 2 s (%d ticks)" % out_at)
	check(Combat.box_outside_light(d, a.safe, h.pos), "its box outside the wider light")
	check_eq(h.home, h.pos, "its home where it got out")
	check_eq(h.state, HereticSim.State.IDLE, "idle there")
	check_eq(a.stat("knife_swings"), 0, "it swung at nobody")
	check_eq(safe_p.vitals.hp, Config.PLAYER_HP_MAX, "the player in the light untouched")
	check_eq(a.stat("walked_out"), 1, "counted out")
	# Afterwards an ordinary heretic: it goes for a player outside the light.
	var outside: Player = Player.new()
	outside.setup(d, "archer", h.pos + Vector2(48, 0))
	_nodes.append(outside)
	players.append(outside)
	for t3: int in 20:
		a.step(players)
	check(h.has_target and h.target_id == outside.get_instance_id(), "then it hunts as before")
	# Tier 0 again and the light moved by nothing: no heretic is flagged by a sync that is no raise.
	var d2: WorldData = surface()
	var a2: Arena = Arena.new()
	a2.setup(d2, Config.DEFAULT_SEED)
	a2.spawning = false
	var h2: HereticSim = a2.spawn_heretic(_ring_spot(d2))
	d2.progress.altar_tier = 0
	a2.sync_world()
	check(not h2.lit_out, "no raise, no walk out")


# --- the light's texels -------------------------------------------------------------------------------------------------------

func _check_light_texels() -> void:
	var d: WorldData = surface()
	var z0: SafeZone = SafeZone.for_world(d)
	d.progress.raise_altar()
	var z1: SafeZone = SafeZone.for_world(d)
	check_eq(z1.radius, 144.0, "9 tiles = 144 px")
	check_eq(LightGen.texture_size(z0), 226, "tier 0's texture 226")
	check_eq(LightGen.texture_size(z1), 290, "tier 1's texture 290")
	var hard: Image = AltarLight.image_for(z1, LightGen.Edge.HARD, 0)
	var dither: Image = AltarLight.image_for(z1, LightGen.Edge.DITHER, Config.SAFE_EDGE_BAND_PX)
	var origin: Vector2i = LightGen.texture_origin(z1)
	var hard_wrong: int = 0
	var dither_out: int = 0
	var dither_hole: int = 0
	var lit: int = 0
	for y: int in hard.get_height():
		for x: int in hard.get_width():
			var px: Vector2 = Vector2(origin + Vector2i(x, y)) + Vector2(0.5, 0.5)
			var inside: bool = z1.is_in_safe_zone(px)
			if (hard.get_pixel(x, y).a8 == 255) != inside:
				hard_wrong += 1
			var dl: bool = dither.get_pixel(x, y).a8 == 255
			if dl:
				lit += 1
			if dl and not inside:
				dither_out += 1
			if not dl and px.distance_to(z1.center) <= z1.radius - Config.SAFE_EDGE_BAND_PX:
				dither_hole += 1
	check_eq(hard_wrong, 0, "the actor light's texels = the 9-tile zone")
	check_eq(dither_out, 0, "the ground light lights nothing outside it")
	check_eq(dither_hole, 0, "and everything within its band")
	note("tier-1 light: %d x %d texels, %d lit on the ground light" % [hard.get_width(), hard.get_height(), lit])
	var probe: Vector2i = Vector2i(roundi(z1.center.x) + 120, roundi(z1.center.y))
	check_eq(LightGen.light_at(z0, LightGen.Edge.DITHER, Config.SAFE_EDGE_BAND_PX, probe), 0.0, "120 px out: dark at tier 0")
	check_eq(LightGen.light_at(z1, LightGen.Edge.DITHER, Config.SAFE_EDGE_BAND_PX, probe), 1.0, "lit at tier 1")


# --- creatures ----------------------------------------------------------------------------------------------------------------

func _check_creatures() -> void:
	var d: WorldData = surface()
	var herd: Creatures = Creatures.new()
	herd.setup(d, Config.DEFAULT_SEED, false)
	var spot: Vector2 = Vector2.ZERO
	var c: Vector2 = d.altar_center_px()
	var zone1: SafeZone = SafeZone.new(c, Config.safe_radius_px_at(1))
	for deg: int in range(0, 360, 15):
		var at: Vector2 = (c + Vector2.from_angle(deg_to_rad(float(deg))) * 8.5 * Config.TILE).round()
		if herd.can_walk(at) and Movement.can_stand(d, at) and not Combat.box_outside_light(d, zone1, at):
			spot = at
			break
	if not check(spot != Vector2.ZERO, "a spot in the ring a creature may stand on at tier 0"):
		return
	var deer: CreatureSim = herd.spawn(&"deer", spot)
	for t: int in 10:
		herd.step([] as Array[Player])
	check(herd.can_walk(deer.pos), "tier 0: it stands in the ring")
	d.progress.raise_altar()
	var out_at: int = -1
	for t2: int in 240:
		herd.step([] as Array[Player])
		if out_at < 0 and herd.can_walk(deer.pos):
			out_at = t2 + 1
	check_eq(herd.safe.radius, 144.0, "the herd's light is tier 1's")
	check(out_at > 0 and out_at < 120, "the creature the wider light reached walked out (%d ticks)" % out_at)
	check(Combat.box_outside_light(d, herd.safe, deer.pos), "its box outside the wider light")
	# A spawn spot just past the old clearance: allowed at tier 0, refused at tier 1.
	var d2: WorldData = surface()
	var h2: Creatures = Creatures.new()
	h2.setup(d2, Config.DEFAULT_SEED, false)
	var c2: Vector2 = d2.altar_center_px()
	var clear0: float = Config.safe_radius_px_at(0) + Config.CREATURE_SPAWN_LIGHT_CLEARANCE_TILES * Config.TILE
	var found: Vector2 = Vector2.ZERO
	for deg2: int in range(0, 360, 5):
		var at2: Vector2 = (c2 + Vector2.from_angle(deg_to_rad(float(deg2))) * (clear0 + 6.0)).round()
		if h2.spawn_ok(at2, [] as Array[Player]):
			found = at2
			break
	if check(found != Vector2.ZERO, "a spawn spot 6 px past tier 0's clearance"):
		d2.progress.raise_altar()
		h2.step([] as Array[Player])
		check(not h2.spawn_ok(found, [] as Array[Player]), "refused at tier 1 (the clearance from the wider light)")


func _check_merchant_and_prayer() -> void:
	var d: WorldData = surface()
	var tile: Vector2i = Merchant.spot_for(d)
	check_ne(tile, Walls.NO_CELL, "the merchant has a tile")
	d.progress.raise_altar()
	check_eq(Merchant.spot_for(d), tile, "the same tile at tier 1")
	check_eq(Merchant.spot_refusal(d, tile), "", "still a good tile (in the light)")
	var edge: Vector2 = d.altar_center_px() + Vector2(Config.PRAYER_CIRCLE_RADIUS_PX, 0)
	check(Prayer.in_circle(d, edge) and not Prayer.in_circle(d, edge + Vector2(1, 0)), "the prayer circle stays 64 px")


# --- the world's view: the raise and a carry ---------------------------------------------------------------------------------

func _check_world_follows() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	w.data.progress = WorldProgress.new()
	w.data.progress.raise_altar()
	w.altar_tier_changed()
	check(w.altar.tier == 1 and w.altar.sprite.texture == Altar.LIT_UP1, "candA")
	var home: Rect2i = w.data.altar_rect
	for e: EditLog.WorldEdit in AltarMove.pickup_edits(w.data):
		w.apply_edit(e)
	check(not w.data.altar_rect.has_area(), "carried")
	check(not w.lighting.altar_light.is_lit(), "no light while carried")
	var to: Rect2i = Rect2i(home.position + Vector2i(-12, 2), home.size)
	check_eq(AltarMove.place_refusal(w.data, to), "", "a free place")
	for e2: EditLog.WorldEdit in AltarMove.place_edits(to):
		w.apply_edit(e2)
	check_eq(w.data.altar_rect, to, "put down")
	check(w.altar != null and w.altar.tier == 1 and w.altar.sprite.texture == Altar.LIT_UP1, "the altar put down is candA")
	check_eq(w.safe_zone.radius, 144.0, "its zone 9 tiles there")
	check_eq(w.safe_zone.center, AltarMove.centre_px(to), "around its new middle")
	check(w.lighting.altar_light.is_lit() and w.lighting.altar_light.zone.radius == 144.0, "its light 9 tiles")
	check(w.lighting.altar_light.actor_light.texture == AltarLight.texture_for(w.safe_zone, LightGen.Edge.HARD, 0), "the tier-1 texture")
	check_eq(w.altar.art_origin(), to.position * Config.TILE + Vector2i(-4, -7), "candA drawn at the new place")


# --- the flames' colours -------------------------------------------------------------------------------------------------------

## The hue (degrees) of an opaque pixel.
static func hue(c: Color) -> float:
	return c.h * 360.0


## Opaque pixels of `img` whose hue is not within [lo, hi].
static func off_hue(img: Image, lo: float, hi: float) -> int:
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a8 > 0 and (hue(c) < lo or hue(c) > hi):
				n += 1
	return n


func _check_flame_colours() -> void:
	# The heretic side: hues 0..30 (blood, scarlet, the orange core #ff7a1a), its glow too.
	for tex: Texture2D in [FixtureView.HERETIC_FLAME_LARGE, FixtureView.HERETIC_FLAME_SMALL]:
		var img: Image = LightGen.to_rgba8(tex.get_image())
		check_eq(off_hue(img, 0.0, 30.0), 0, "%s: demon orange and blood only" % tex.resource_path.get_file())
	for large: bool in [true, false]:
		check_eq(off_hue(LightGen.to_rgba8(FixtureView.heretic_glow_texture(large).get_image()), 0.0, 30.0), 0, "its glow too")
	check(hue(Config.HERETIC_FIRE_LIGHT_COLOR) < 30.0, "the shrine's light orange (%d deg)" % roundi(hue(Config.HERETIC_FIRE_LIGHT_COLOR)))
	check(hue(BossFightView.ORANGE) < 30.0 and hue(BossFightView.SCARLET) < 30.0, "the boss's fire the same row")
	var staff: BossView = BossView.new()
	_nodes.append(staff)
	check(staff.flame.texture == FixtureView.HERETIC_FLAME_SMALL, "the boss's staff burns with the small candB flame")
	# The faith side: candle gold, hues 30..60 (the torches, the relic bench's candle, the altar's lamps at both tiers).
	for tex2: Texture2D in [FixtureView.FLAME, FixtureView.SMALL_FLAME]:
		check_eq(off_hue(LightGen.to_rgba8(tex2.get_image()), 30.0, 60.0), 0, "%s: candle gold" % tex2.resource_path.get_file())
	for t: int in 2:
		var mask: Image = Altar.tier_flame_image(t)
		var lit: Image = LightGen.to_rgba8((Altar.LIT if t == 0 else Altar.LIT_UP1).get_image())
		var flames: Image = Image.create_empty(lit.get_width(), lit.get_height(), false, Image.FORMAT_RGBA8)
		for y: int in lit.get_height():
			for x: int in lit.get_width():
				if mask.get_pixel(x, y).a8 > 0:
					flames.set_pixel(x, y, lit.get_pixel(x, y))
		check_eq(off_hue(flames, 30.0, 60.0), 0, "tier %d altar's flames: candle gold" % t)
	check_eq(Config.TORCH_LIGHT_COLOR, Color(1.0, 0.86, 0.62), "the torches' light as main had it")
	check_eq(Config.ALTAR_LIGHT_COLOR, Color(1.0, 0.97, 0.91), "the altar's light as main had it")
	# The faith-side pictures are main's (cde5717) byte for byte.
	var main_md5: Dictionary[String, String] = {
		"flame_large_v01.png": "c60613343da6776d502410ee3762ac06", "flame_small_v01.png": "0c0f5e9cb111a73217bf0dfb33f15777",
		"altar_v04.png": "24c6282aa7960283cdd352eb38733212", "altar_v04_unlit.png": "01fb9aabb6a725c3234f69109ed40827",
		"prop_lantern_ground_v03_lit.png": "481ed0852cd806be7acfb57df9ac45ea",
		"prop_lantern_ground_v03_emissive.png": "a0b80bce5a65039933f71bb4580f1743",
		"prop_lantern_post_c_v03_lit.png": "477ead1cfdd4adfa71e2fc473710a106",
		"prop_lantern_post_c_v03_emissive.png": "082015d50f53fd21f0be633453de86e8",
		"prop_wall_torch_a_v02.png": "a26a0a08f5d1f114a93d26de5367a210", "relic_bench_v03.png": "470e84388aa634ee9e5a9810a60c7310",
	}
	for f: String in main_md5:
		check_eq(FileAccess.get_md5("res://art/env/" + f), main_md5[f], "%s as on main" % f)
	check(FixtureView.FLAME.resource_path.ends_with("flame_large_v01.png") and FixtureView.SMALL_FLAME.resource_path.ends_with(
		"flame_small_v01.png") and FixtureView.LANTERN.resource_path.ends_with("prop_lantern_ground_v03_lit.png"), "the faith pictures in use")


func _check_shrine_fire_combat() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	w.map_id = Config.MAP_DUNGEON
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	var a: Arena = Arena.new()
	a.setup(w.data, Config.DEFAULT_SEED)
	a.spawning = false
	var rect: Rect2i = a.shrine_rect()
	var n: Node2D = w.fixtures.nodes[rect.position]
	var light: PointLight2D = n.get_node_or_null(^"FireLight") as PointLight2D
	check(light != null and light.enabled and light.color == Config.HERETIC_FIRE_LIGHT_COLOR, "standing: it burns orange")
	check(light != null and light.color != Config.TORCH_LIGHT_COLOR, "not the torches' gold")
	var flames: int = 0
	for child: Node in n.get_children():
		if child is Sprite2D and (child as Sprite2D).texture in [FixtureView.HERETIC_FLAME_LARGE, FixtureView.HERETIC_FLAME_SMALL]:
			flames += 1
	check_eq(flames, 3, "three flames")
	var hits: int = 0
	while a.shrine_rect().has_area() and hits < 100:
		for e: EditLog.WorldEdit in a.damage_shrine(25):
			w.apply_edit(e)
		hits += 1
	check(not a.shrine_rect().has_area(), "the arena broke it (%d blows)" % hits)
	var broken: Node2D = w.fixtures.nodes[rect.position]
	check(broken.get_node_or_null(^"FireLight") == null, "its light is out")
	var left: int = 0
	for child2: Node in broken.get_children():
		if child2 is Sprite2D and (child2 as Sprite2D).texture in [FixtureView.HERETIC_FLAME_LARGE, FixtureView.HERETIC_FLAME_SMALL]:
			left += 1
	check_eq(left, 0, "no flame on the broken shrine")
	check_eq(w.fixtures.verify()["mismatches"], 0, "fixtures = data")

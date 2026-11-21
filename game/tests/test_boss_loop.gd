extends "res://tests/base_test.gd"
## M12b, the whole loop through main.tscn offline (the task's "enter the dungeon, break pillars on the boss with a miner, kill it, get
## relics, craft the upgrade, see the radius grow"; every number PROVISIONAL, README "임시값" M12a): a miner (and a cleric beside him) go down
## the surface's entrance with F, walk into the boss's room (it wakes for two: x1.6 HP), the miner's pick breaks two pillars over it (each
## nine swings through Main's action path, the dust, then the debris: 12% of its max HP, the long stun, the exposure; the HUD bar shows),
## the pick kills it (one relic each, the world's flag, the bar gone), F on the exit stairs takes him up, the relic bench's upgrade takes
## his one relic, and the light grows: the zone, the light's texture, candA, and the rules reading it (the surface arena's light, the
## herd's, a field tile and a building cost in the ring).

const TICK: float = 1.0 / 60.0
## Ticks per swing (a pick's whole action and a little: the next press starts a new one).
const SWING_TICKS: int = 60


func run() -> Array[String]:
	await _check_loop()
	return failures


## Steps Main like a physics tick with the local player's input (`mouse` aimed, `use` pressed on the first tick of a swing).
static func step(main: Main, p: Player, dir: Vector2i, mouse: Vector2, use_pressed: bool, use_held: bool) -> void:
	p.begin_tick()
	p.tick_controls(dir, mouse, true, use_pressed, use_held, TICK)
	main.step_combat(TICK)
	main.step_creatures()
	main._show_boss_bar()


## `n` swings of the held item at `mouse`.
static func swing(main: Main, p: Player, mouse: Vector2, n: int) -> void:
	for s: int in n:
		for t: int in SWING_TICKS:
			step(main, p, Vector2i.ZERO, mouse, t == 0, t == 0)


func _check_loop() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.arenas[Config.MAP_SURFACE].spawning = false
	main.arenas[Config.MAP_DUNGEON].spawning = false
	main.spawn("miner")
	var p: Player = main.player
	p.local_input = false
	var cleric: Player = main.add_ally("cleric", false)
	var surface: GameWorld = main.world
	var zone0: float = surface.safe_zone.radius
	check_eq(zone0, 112.0, "the light starts at 7 tiles")
	check_eq(surface.lighting.altar_light.actor_light.texture.get_width(), 226, "its texture 226")
	# F on the entrance.
	var entrance: Rect2i = SurfaceGen.entrance_rect(surface.data)
	p.teleport(DungeonGen.arrival_below(entrance))
	step(main, p, Vector2i.ZERO, p.sim_position + Vector2(0, -24), false, false)
	check(WorldItems.is_portal(surface.data, p.aim_cell), "aiming at the entrance")
	check(main.pick_up(), "F taken")
	check_eq(main.current_map, Config.MAP_DUNGEON, "down in the dungeon")
	var dungeon: GameWorld = main.worlds[Config.MAP_DUNGEON]
	cleric.get_parent().remove_child(cleric)
	dungeon.entities.add_child(cleric)
	cleric.set_world(dungeon.data, p.sim_position + Vector2(18, 0))  # the cleric follows him down (as --test-ally does)
	var f: BossFight = main.boss_fight()
	if not check(f != null and f.sim != null, "the dungeon has the boss fight"):
		return
	# Into its room: it wakes for the two on the map.
	f.test_hp = 600  # its HP when it wakes (the fight in a few hundred swings' time); its max HP is still the two players'
	var outside: Vector2i = Main.outside_door(f.room, dungeon.data)
	var door: Vector2i = Vector2i(-1, -1)
	for d: Vector2i in f.room.doors:
		if BossRoom.cheb(d, outside) == 1 and (d - outside).length_squared() == 1:
			door = d
	check(door.x >= 0, "a doorway beside the spot outside")
	p.teleport(Arena.spawn_feet(outside))
	cleric.teleport(Arena.spawn_feet(outside) + Vector2(0, 0.5))
	var walk_in: Vector2i = door - outside
	var woke_at: int = -1
	for t: int in 120:
		step(main, p, walk_in, p.sim_position + Vector2(walk_in) * 20.0, false, false)
		if f.sim.awake():
			woke_at = t
			break
	check(woke_at >= 0 and f.room.holds(p.sim_position), "walked in: it woke (%d ticks)" % woke_at)
	check_eq(f.sim.woke_with, 2, "two on the map")
	check_eq(f.sim.hp_max, BossSim.hp_for(2), "x1.6: %d" % BossSim.hp_for(2))
	check(main.hud.boss_ratio > 0.0, "the HUD's boss bar")
	f.frozen = true  # it stands where it is put (its attacks are test_boss.gd's)
	f.sim.adds_called = true  # and phase 2 calls no heretic (test_boss.gd's too): 600 HP is already below its half
	# Two pillars broken over it with the pick, through Main's swing path.
	var pick: int = -1
	for s: int in p.inventory.size():
		if p.inventory.stack_at(s) != null and p.inventory.stack_at(s).id == &"pickaxe":
			pick = s
	check(pick >= 0, "the miner's pick")
	p.inventory.select(pick)
	var debris_dmg: int = maxi(ceili(f.sim.hp_max * Config.BOSS["debris_damage_pct"] / 100.0), 1)
	for k: int in 2:
		var pil: BossFight.Pillar = f.pillars[k]
		f.sim.pos = pil.centre() + Vector2(0, 14)  # just south of it, inside its fall circle
		p.teleport(Arena.spawn_feet(pil.tile + Vector2i(-1, 0)))
		cleric.teleport(pil.centre() + Vector2(-60, 40))
		var hp: int = f.sim.hp
		swing(main, p, pil.centre(), BossFight.Pillar.hits_per_state() * 3)
		check(pil.falling >= 0 or pil.fallen, "pillar %d: nine swings broke it" % k)
		p.teleport(Arena.spawn_feet(pil.tile + Vector2i(-2, 1)))  # he steps back out of its dust circle (still in the room)
		var boss_before_debris: int = f.sim.hp
		for t2: int in roundi(Config.BOSS_PILLARS["telegraph_ticks"]) + 2:
			step(main, p, Vector2i.ZERO, pil.centre(), false, false)
		check(pil.fallen, "pillar %d: its debris fell" % k)
		check_eq(boss_before_debris - f.sim.hp, debris_dmg, "pillar %d: the debris took 12%% of its max HP" % k)
		check(f.sim.stunned() and f.sim.exposed(), "pillar %d: stunned and exposed" % k)
		check(hp > f.sim.hp, "pillar %d: it lost HP" % k)
		check(main.hud.boss_exposed, "pillar %d: the bar shows it exposed" % k)
	check_eq(f.stat("debris_boss"), 2, "two debris on the boss")
	check(p.vitals.alive() and p.vitals.hp == Config.PLAYER_HP_MAX, "the miner stepped clear of his debris")
	# The pick finishes it.
	p.teleport(f.sim.pos + Vector2(-16, 0))
	var swings: int = 0
	while f.sim.alive() and swings < 60:
		swing(main, p, f.aim_point(), 1)
		swings += 1
	check(not f.sim.alive(), "the pick killed it (%d swings)" % swings)
	check_eq(p.inventory.count_of(Config.BOSS_RELIC), 1, "a relic for the miner")
	check_eq(cleric.inventory.count_of(Config.BOSS_RELIC), 1, "and for the cleric on the map")
	check(main.world_progress().boss_defeated, "the world's flag")
	check(main.hud.boss_ratio < 0.0, "no bar now")
	check_eq(dungeon.data.content_hash(), DungeonGen.GOLDEN_HASH, "the dungeon's tiles as generated (the fight edited none)")
	# Up the stairs with F.
	p.teleport(dungeon.arrival_point())
	step(main, p, Vector2i.ZERO, p.sim_position + Vector2(0, -24), false, false)
	check(main.pick_up(), "F on the stairs")
	check_eq(main.current_map, Config.MAP_SURFACE, "back on the surface")
	# The relic bench's upgrade.
	var at: Vector2i = surface.data.altar_rect.position + Vector2i(-1, 5)
	for x: int in Config.RELIC_BENCH_FOOTPRINT.x:
		surface.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, at + Vector2i(x, 0), WorldData.PLACEABLE_RELIC))
	p.teleport(Arena.spawn_feet(at + Vector2i(1, 1)))
	var st: Crafting.StationAt = Crafting.station_near(surface.data, p.sim_position)
	check(st != null and st.kind == Crafting.RELIC, "at the relic bench")
	main.open_crafting(st)
	var row: int = -1
	for i: int in main.hud.crafting.recipes.size():
		if main.hud.crafting.recipes[i].is_upgrade():
			row = i
	check(row >= 0, "the upgrade row (the relic was held)")
	main.craft_row(row)
	main.close_crafting()
	check_eq(main.world_progress().altar_tier, 1, "tier 1")
	check_eq(p.inventory.count_of(Config.BOSS_RELIC), 0, "his one relic spent")
	# The light grew, and what reads it follows.
	check_eq(surface.safe_zone.radius, 144.0, "the zone 7 -> 9 tiles")
	check_eq(surface.lighting.altar_light.actor_light.texture.get_width(), 290, "the light's texture 290")
	check(surface.altar.sprite.texture == Altar.LIT_UP1, "candA")
	for t3: int in 2:
		step(main, p, Vector2i.ZERO, p.sim_position, false, false)
	check_eq(main.arenas[Config.MAP_SURFACE].safe.radius, 144.0, "the surface arena's light rule")
	var herd: Creatures = main.arenas[Config.MAP_SURFACE].herd
	check(herd != null and herd.safe.radius == 144.0, "the herd's")
	var ring: Vector2i = Aim.cell_of(surface.data.altar_center_px()) + Vector2i(7, 0)
	check(Farming.in_light(surface.data, ring), "a field tile 7 east in the light now")
	check_eq(Building.cost_at(surface.data, ring), Config.BUILD_COST_IN_LIGHT, "the light's building cost there")

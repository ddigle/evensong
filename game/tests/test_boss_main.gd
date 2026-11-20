extends "res://tests/base_test.gd"
## M12a through main.tscn offline: the dungeon's arena has the boss fight from the world seed (the surface's none), the world's progress is one
## object on both maps' data, the fight's view (the boss, a node per pillar), --test-boss next to the arena (asleep) and inside it (awake),
## the HUD's boss bar (in its room while it is awake, else none), a kill through the local player's sword (the relic in the inventory,
## the world's flag, the log), the relic bench's altar upgrade through the crafting panel (tier 1: the light, the zone, candA, the row
## refused after), --test-pillar-hits and --test-altar-tier, the new flags' and bot commands' parsing, the bot's boss commands.

const TICK: float = 1.0 / 60.0


func run() -> Array[String]:
	_check_cli_and_bot()
	await _check_main()
	return failures


func _check_cli_and_bot() -> void:
	var o: CliOptions = CliOptions.parse(PackedStringArray(["--test-boss", "--test-boss-hp=5", "--test-boss-attack=burn",
		"--test-pillar-hits=1:4,3:9", "--test-altar-tier=1"]))
	check(o.errors.is_empty(), "good flags: %s" % ", ".join(o.errors))
	var outside: bool = o.test_boss_at == null
	check(o.test_boss and outside, "--test-boss: next to the arena")
	check_eq(o.test_boss_hp, 5, "--test-boss-hp")
	check_eq(o.test_boss_attack, "burn", "--test-boss-attack")
	check_eq(o.test_pillar_hits, {0: 4, 2: 9} as Dictionary[int, int], "--test-pillar-hits")
	check_eq(o.test_altar_tier, 1, "--test-altar-tier")
	var o2: CliOptions = CliOptions.parse(PackedStringArray(["--test-boss=0,3"]))
	var at_off: bool = o2.test_boss_at == Vector2i(0, 3)
	check(o2.errors.is_empty() and at_off, "--test-boss=dx,dy")
	for bad: String in ["--test-boss=1", "--test-boss=x,2", "--test-boss-hp=0", "--test-boss-hp=x", "--test-boss-attack=bite",
			"--test-pillar-hits=0:1", "--test-pillar-hits=1", "--test-pillar-hits=9:1", "--test-altar-tier=2", "--test-altar-tier=-1"]:
		check(not CliOptions.parse(PackedStringArray([bad])).errors.is_empty(), "%s is refused" % bad)
	check_eq(NetBot.new().parse("aimboss;bossfight:60;bossfight:60,20;waitboss:awake;waitboss:dead,300"), "", "the bot's boss commands parse")
	for bad2: String in ["aimboss:1", "bossfight", "bossfight:0", "bossfight:x", "waitboss", "waitboss:angry", "waitboss:dead,0"]:
		check_ne(NetBot.new().parse(bad2), "", "%s is refused" % bad2)
	var bot: NetBot = NetBot.new()
	bot.parse("waitboss:awake,30;aimboss;bossfight:5,20")
	bot.boss_state = "sleep"
	bot.step(Vector2.ZERO)
	check(bot.index == 0, "waitboss waits")
	bot.boss_state = "awake"
	bot.boss_aim = Vector2(100, 0)
	bot.step(Vector2.ZERO)
	check_eq(bot.index, 1, "awake: waitboss is over")
	var b: NetBot.Action = bot.step(Vector2.ZERO)
	check(b.aiming and b.mouse == Vector2(100, 0), "aimboss aims at it")
	check_eq(b.dir, Vector2i(1, 0), "bossfight walks up past its px")
	var c: NetBot.Action = bot.step(Vector2(90, 0))
	check(c.use_held, "and swings within it")
	bot.boss_aim = null
	bot.step(Vector2(90, 0))
	check(bot.finished, "dead: on to the next (the end)")


func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.arenas[Config.MAP_SURFACE].spawning = false
	main.arenas[Config.MAP_DUNGEON].spawning = false
	var f: BossFight = main.boss_fight()
	check(f != null and f.sim != null, "offline: the dungeon's arena has the boss fight")
	check(main.arenas[Config.MAP_SURFACE].boss == null, "the surface's none")
	check_eq(f.room.describe(), BossRoom.for_seed(CliOptions.current().world_seed).describe(), "its room from the world seed")
	check(main.world.data.progress != null and main.world.data.progress == main.worlds[Config.MAP_DUNGEON].data.progress,
		"one progress on both maps")
	var view: CombatView = main.combat_views[Config.MAP_DUNGEON]
	check(view.boss_view != null, "the dungeon's view draws the fight")
	check_eq(view.boss_view.pillar_nodes.size(), f.pillars.size(), "a node per pillar")
	check(view.boss_view.boss != null and view.boss_view.boss.get_parent() == main.worlds[Config.MAP_DUNGEON].entities,
		"the boss among the dungeon's entities")
	check_eq(main.worlds[Config.MAP_DUNGEON].data.content_hash(), DungeonGen.GOLDEN_HASH, "the dungeon still hashes golden")
	# --test-boss: next to the arena, asleep.
	main.spawn("paladin")
	var p: Player = main.player
	p.local_input = false
	main.put_test_boss(CliOptions.parse(PackedStringArray(["--test-boss"])))
	check_eq(main.current_map, Config.MAP_DUNGEON, "in the dungeon")
	check(not f.room.holds(p.sim_position), "outside its room")
	var near_door: int = 99
	for d: Vector2i in f.room.doors:
		near_door = mini(near_door, BossRoom.cheb(d, Aim.feet_cell(p.sim_position)))
	check_eq(near_door, 1, "beside a doorway")
	for t: int in 30:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, p.sim_position, false, false, false, TICK)
		main.step_combat(TICK)
		main._show_boss_bar()
	check_eq(f.sim.state, BossSim.State.SLEEP, "it sleeps")
	check(main.hud.boss_ratio < 0.0, "no boss bar")
	# Inside: it wakes; the bar shows.
	main.put_test_boss(CliOptions.parse(PackedStringArray(["--test-boss=0,3"])))
	check(f.room.holds(p.sim_position), "in its room")
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, p.sim_position, false, false, false, TICK)
	main.step_combat(TICK)
	main._show_boss_bar()
	check(f.sim.awake(), "awake")
	check_eq(main.hud.boss_ratio, 1.0, "the bar: full")
	check_eq(main.hud.boss_phase, 1, "phase 1")
	# A tier-1 sword through Main: its damage on the boss and its wear (the M7a swing rule, as on a heretic).
	f.frozen = true
	p.teleport(f.sim.pos + Vector2(0, 18))
	p.inventory.add(&"sword_t1", 1)
	var t1_slot: int = -1
	for s1: int in p.inventory.size():
		var st1: ItemStack = p.inventory.stack_at(s1)
		if st1 != null and st1.id == &"sword_t1":
			t1_slot = s1
	p.inventory.select(t1_slot)
	var t1: ItemStack = p.inventory.stack_at(t1_slot)
	var dur: int = t1.durability
	var hp_before: int = f.sim.hp
	for t1t: int in 60:  # the swing's whole action (0.8 s), so the next press starts a new one
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, f.aim_point(), true, t1t == 0, t1t == 0, TICK)
		main.step_combat(TICK)
	check_eq(hp_before - f.sim.hp, Gear.attack_damage(t1, Combat.attack_for(&"sword_t1").damage), "main: a tier-1 sword's damage on the boss")
	check_eq(t1.durability, dur - Config.GEAR_WEAR_PER_ATTACK, "main: it wears one swing's wear")
	# A kill through the local player's sword: the relic, the flag.
	f.sim.hp = 1
	var sword: int = -1
	for s: int in p.inventory.size():
		var st: ItemStack = p.inventory.stack_at(s)
		if st != null and st.id == &"sword":
			sword = s
	p.inventory.select(sword)
	for t2: int in 60:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, f.aim_point(), true, t2 == 0, t2 == 0, TICK)
		main.step_combat(TICK)
		main._show_boss_bar()
		if not f.sim.alive():
			break
	check(not f.sim.alive(), "main: the sword killed it")
	check_eq(p.inventory.count_of(Config.BOSS_RELIC), 1, "main: the relic in the inventory")
	check(main.world_progress().boss_defeated, "main: the world's flag")
	check(main.hud.boss_ratio < 0.0, "main: dead, no bar")
	# The relic bench's upgrade through the panel.
	main.travel(Config.MAP_SURFACE)
	var at: Vector2i = main.world.data.altar_rect.position + Vector2i(-1, 5)
	for x: int in Config.RELIC_BENCH_FOOTPRINT.x:
		main.world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, at + Vector2i(x, 0), WorldData.PLACEABLE_RELIC))
	p.teleport(Arena.spawn_feet(at + Vector2i(1, 1)))
	var station: Crafting.StationAt = Crafting.station_near(main.world.data, p.sim_position)
	check(station != null and station.kind == Crafting.RELIC, "at the relic bench")
	main.open_crafting(station)
	var row: int = -1
	for i: int in main.hud.crafting.recipes.size():
		if main.hud.crafting.recipes[i].is_upgrade():
			row = i
	check(row >= 0, "the upgrade row shows (the relic was held)")
	check(main.hud.crafting.progress == main.world_progress(), "the panel checks it against the world's progress")
	var zone_before: float = main.world.safe_zone.radius
	main.craft_row(row)
	check_eq(main.world_progress().altar_tier, 1, "main: tier 1")
	check_eq(p.inventory.count_of(Config.BOSS_RELIC), 0, "main: the relic spent")
	check_eq(main.world.safe_zone.radius, float(9 * Config.TILE), "main: the zone 9 tiles (was %d)" % roundi(zone_before))
	check(main.world.altar.tier == 1 and main.world.altar.sprite.texture == Altar.LIT_UP1, "main: candA")
	check_eq(main.world.lighting.altar_light.zone.radius, float(9 * Config.TILE), "main: the light is the zone")
	check_eq(Crafting.refusal(main.hud.crafting.recipes[row], "paladin", p.inventory, main.world_progress()), Crafting.WHY_TIER_MAX,
		"main: the row is refused now")
	main.close_crafting()
	# --test-pillar-hits and --test-altar-tier on the world as Main has it.
	main.put_test_boss(CliOptions.parse(PackedStringArray(["--test-pillar-hits=1:3,2:9"])))
	check_eq(f.pillars[0].look(), 1, "--test-pillar-hits: cracked")
	check(f.pillars[1].fallen and not main.worlds[Config.MAP_DUNGEON].data.blockers.has(f.pillars[1].tile), "--test-pillar-hits: 9 = rubble")

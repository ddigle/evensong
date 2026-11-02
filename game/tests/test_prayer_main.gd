extends "res://tests/base_test.gd"
## M10a in main.tscn (offline): the prayer is the surface's (Main.prayer, its circle under the entities); F (PROVISIONAL README
## "M10a F"): a tap (let go within PRAYER_TAP_MAX_TICKS, nothing else took the press) prays or meditates, a hold does not and
## still lifts the altar after ALTAR_PICKUP_HOLD_TICKS unless a prayer or a meditation is under way; the merchant's F, a pick up
## next to the altar and a revive in reach take the press; while praying the panels, the skills and the move keys are refused;
## --test-ally with several and their --test-pray scripts give a prayer of four in one process (joins, right, wrong, late, quit),
## the bot's pray and answer:auto drive the local cleric, the pictures follow (the lamps, the circle, the marks, the HUD prompt,
## the zeal marks), a death takes the zeal off, the zeal raises Main's own attack, a session refuses the tap (M10b), and the new
## flags and bot commands parse (and refuse bad values).
## M10-fix: the merchant's F from inside the circle takes the press (no tap tried); in a session (a client) F aimed from inside the
## circle at the merchant, a drop or a door is the PICKUP request only (no PRAY), F held past PRAYER_TAP_MAX_TICKS (the session
## reads the key itself) sends no PRAY, a short press exactly one; the HUD's lamps grid shows the altar's lamps while praying.

const TICK: float = 1.0 / 60.0


func run() -> Array[String]:
	_check_cli_and_bot()
	await _check_main()
	return failures


# --- helpers ---------------------------------------------------------------------------------------------------

static func step_main(main: Main, n: int) -> void:
	for i: int in n:
		main._physics_process(TICK)


## Steps until `done` says so (at most `limit` ticks); returns whether it did.
static func step_until(main: Main, done: Callable, limit: int) -> bool:
	for i: int in limit:
		if done.call():
			return true
		main._physics_process(TICK)
	return done.call()


static func set_bot(main: Main, script: String) -> String:
	main.bot = NetBot.new()
	return main.bot.parse(script)


static func clear_allies(main: Main) -> void:
	for a: Player in main.allies:
		if is_instance_valid(a):
			a.get_parent().remove_child(a)
			a.free()
	main.allies.clear()
	main._ally_scripts.clear()


static func fresh_prayer(main: Main) -> void:
	main.prayer = null
	main.setup_prayer()


## The local player as `class_id` on tile `c` with `faith`, no allies, a fresh prayer.
static func place(main: Main, class_id: String, c: Vector2i, faith: int = 0) -> Player:
	clear_allies(main)
	main.spawn(class_id)
	var p: Player = main.player
	p.local_input = false
	p.teleport(Arena.spawn_feet(c))
	p.skills.resource = faith
	fresh_prayer(main)
	return p


# --- the flags and the bot ---------------------------------------------------------------------------------------

func _check_cli_and_bot() -> void:
	var o: CliOptions = CliOptions.parse(PackedStringArray(["--test-ally=paladin,archer:down,miner", "--test-pray=cwl,q,c"]))
	check(o.errors.is_empty(), "several allies and their scripts parse: %s" % [o.errors])
	check_eq(o.test_allies.size(), 3, "three allies")
	check_eq(o.test_allies[1], ["archer", true], "the second downed")
	check_eq(o.test_ally, "paladin", "test_ally = the first (M4a's single flag)")
	check_eq(o.test_pray, PackedStringArray(["cwl", "q", "c"]), "the scripts")
	var single: CliOptions = CliOptions.parse(PackedStringArray(["--test-ally=cleric:down"]))
	check(single.errors.is_empty() and single.test_ally == "cleric" and single.test_ally_down and single.test_allies.size() == 1,
		"one ally parses as before")
	for bad: String in ["--test-ally=wizard", "--test-ally=paladin:up", "--test-ally=", "--test-pray=cx", "--test-pray=",
			"--test-ally=paladin,archer,miner,cleric,herbalist,paladin,archer,miner,cleric"]:
		check(not CliOptions.parse(PackedStringArray([bad])).errors.is_empty(), "%s is refused" % bad)
	var bot: NetBot = NetBot.new()
	check_eq(bot.parse("pray;answer:w;answer:D;answer:auto;answer:auto,45;waitturn;waitturn:60;waitprayer:turns,10"), "",
		"the M10a bot commands parse")
	for bad2: String in ["pray:1", "answer:x", "answer", "answer:auto,0", "answer:auto,500", "answer:w,1", "waitprayer:soon",
			"waitturn:0"]:
		check(not bot.parse(bad2).is_empty(), "bot %s is refused" % bad2)
	# The commands step as written.
	bot.parse("pray;answer:s;answer:auto,5")
	var a: NetBot.Action = bot.step()
	check(a.f_tap and a.dir == Vector2i.ZERO, "pray: F pressed and let go this tick")
	a = bot.step()
	check(not a.f_tap and a.dir == Vector2i(0, 1), "answer:s: S this tick")
	bot.prayer_member = true
	bot.prayer_dir = Prayer.Dir.LEFT
	bot.prayer_window = 4
	a = bot.step()
	check_eq(a.dir, Vector2i.ZERO, "answer:auto waits for its window tick")
	bot.prayer_window = 5
	a = bot.step()
	check_eq(a.dir, Vector2i(-1, 0), "then presses the shown direction")
	bot.prayer_dir = -1
	a = bot.step()
	check(a.dir == Vector2i.ZERO and not bot.finished, "between its turns it stands")
	bot.prayer_member = false
	bot.step()
	check(bot.finished, "out of the prayer: done")
	bot.parse("waitprayer:gather,100;pray")
	bot.prayer_phase = Prayer.Phase.IDLE
	check(not bot.step().f_tap, "waitprayer waits")
	bot.prayer_phase = Prayer.Phase.GATHER
	check(not bot.step().f_tap, "the phase came: on to the next command next tick")
	check(bot.step().f_tap, "pray")


# --- main.tscn ---------------------------------------------------------------------------------------------------

func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.arenas[Config.MAP_SURFACE].spawning = false
	check(main.prayer_on and main.prayer != null and main.prayer.data == main.world.data, "offline: the surface's prayer")
	check(main.prayer_view != null and main.prayer_view.get_parent() == main.world
		and main.prayer_view.get_index() < main.world.entities.get_index(), "its circle between the ground and the entities")
	var r: Rect2i = main.world.data.altar_rect
	var south: Vector2i = Vector2i(r.position.x + 1, r.end.y)  # the middle tile just south of the altar
	_check_tap_and_hold(main, r, south)
	_check_lift_blocked(main, south)
	_check_conflicts(main, south)
	_check_prayer_of_four(main, south)
	_check_session_refusal(main, south)
	_check_session_f(main, south)
	_check_zeal_in_main(main)


func _check_tap_and_hold(main: Main, r: Rect2i, south: Vector2i) -> void:
	var p: Player = place(main, "cleric", south, 100)
	check(Prayer.in_circle(main.world.data, p.sim_position), "the cleric stands in the circle")
	var aim_altar: String = "aimat:%d,%d" % [south.x, south.y - 1]
	# A hold past PRAYER_TAP_MAX_TICKS is no tap (and short of the lift's 2 s nothing at all).
	set_bot(main, "%s;hold:%d" % [aim_altar, Config.PRAYER_TAP_MAX_TICKS + 5])
	step_main(main, 1)
	main._f_press()
	step_main(main, Config.PRAYER_TAP_MAX_TICKS + 10)
	check(not main.prayer.is_meditating(p.get_instance_id()) and not main.prayer.running(), "a hold is no tap")
	check(main.world.data.altar_rect.has_area(), "nor a lift yet")
	# A tap: the cleric alone meditates.
	set_bot(main, "%s;hold:%d" % [aim_altar, Config.PRAYER_TAP_MAX_TICKS])
	step_main(main, 1)
	main._f_press()
	step_main(main, Config.PRAYER_TAP_MAX_TICKS + 2)
	check(main.prayer.is_meditating(p.get_instance_id()), "a tap (held PRAYER_TAP_MAX_TICKS): the cleric alone meditates")
	check_eq(p.prayer_mark.kind, PrayerMark.Kind.MEDITATE, "the meditation's mark over him")
	check(p.prayer_mark.fill > 0, "its bar filling")
	# F held 2 s aimed at the altar meanwhile: no lift (the meditation blocks it).
	set_bot(main, "%s;hold:%d" % [aim_altar, Config.ALTAR_PICKUP_HOLD_TICKS + 5])
	main._f_press()
	step_main(main, Config.ALTAR_PICKUP_HOLD_TICKS / 2)
	check(main.world.data.altar_rect.has_area() and p.altar_hold_ticks == 0, "a meditation under way: F held does not lift")
	step_main(main, Config.MEDITATE_TICKS)
	check(p.skills.zealous() and p.skills.zeal_pct == Config.MEDITATE_ZEAL_PCT, "the meditation's zeal")
	check(main.world.data.altar_rect.has_area(), "still no lift")
	check(p.effect_marks.shown.has(EffectMarks.Kind.ZEAL), "the zeal mark over him")
	check(main.hud.effect_kinds(p).has(EffectMarks.Kind.ZEAL), "and on the HUD")
	# With nothing under way the hold lifts the altar again (M5b): then a tap is nothing (no altar, no circle).
	p.skills.zeal_pct = 0
	p.skills.zeal_ticks = 0
	set_bot(main, "%s;hold:%d" % [aim_altar, Config.ALTAR_PICKUP_HOLD_TICKS + 2])
	main._f_press()
	step_main(main, Config.ALTAR_PICKUP_HOLD_TICKS + 3)
	check(p.carrying_altar and not main.world.data.altar_rect.has_area(), "no prayer: F held 2 s lifts the altar as before")
	set_bot(main, "pray")
	step_main(main, 2)
	check(not main.prayer.running() and main.prayer.meditators.is_empty(), "carried: a tap prays nothing")
	check_eq(main.place_altar(p, Vector2i(south.x, south.y - 1)), "", "put back down")
	check(main.world.data.altar_rect.has_area(), "the altar stands again")


## M10-fix: a tile next to `target` (8 around it, nearest the altar first) whose feet stand inside the prayer circle and that is
## free to stand on; NO_CELL when none.
static func beside_in_circle(d: WorldData, target: Vector2i) -> Vector2i:
	var best: Vector2i = Walls.NO_CELL
	var best_d: float = INF
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var c: Vector2i = target + Vector2i(dx, dy)
			var feet: Vector2 = Arena.spawn_feet(c)
			if c == target or d.altar_rect.has_point(c) or not Movement.can_stand(d, feet):
				continue
			var dist: float = feet.distance_to(d.altar_center_px())
			if Prayer.in_circle(d, feet) and dist < best_d:
				best = c
				best_d = dist
	return best


func _check_conflicts(main: Main, _south: Vector2i) -> void:
	# The merchant's F takes the press: his shop opens, no prayer. M10-fix: from a tile inside the circle (M10a stood outside it, so
	# "no prayer" held whatever F did): the press is taken (pick_up said so) and no tap is even tried.
	var m: Vector2i = Merchant.tile_of(main.world.data)
	var stand: Vector2i = beside_in_circle(main.world.data, m)
	check(stand != Walls.NO_CELL, "a tile next to the merchant inside the circle (%s)" % stand)
	var p: Player = place(main, "paladin", stand, 0)
	check(Prayer.in_circle(main.world.data, p.sim_position), "the paladin stands in the circle, beside the merchant")
	set_bot(main, "aimat:%d,%d;wait:1;pray" % [m.x, m.y])
	step_main(main, 3)
	check(main.shop_open(), "F at the merchant: his shop")
	check(main._f_consumed, "the merchant took the press (no tap)")
	check(main.prayer.meditators.is_empty() and not main.prayer.running() and main.prayer.stat("refused_meditate") == 0,
		"no prayer tap tried (none refused either)")
	main.close_shop()
	# A drop on the tile next to the altar, in the circle: the first F picks it up, the second (nothing left) meditates.
	var r: Rect2i = main.world.data.altar_rect
	var at: Vector2i = Vector2i(r.position.x + 1, r.end.y + 1)
	p = place(main, "archer", at, 0)
	check(Prayer.in_circle(main.world.data, p.sim_position), "the archer stands in the circle")
	p.inventory.add(&"stone_a", 3)
	p.inventory.select(p.inventory.size() - 1)
	for i: int in p.inventory.size():
		if p.inventory.stack_at(i) != null and p.inventory.stack_at(i).id == &"stone_a":
			p.inventory.select(i)
	var drop_at: Vector2i = at + Vector2i(1, 0)
	set_bot(main, "aimat:%d,%d;drop" % [drop_at.x, drop_at.y])
	step_main(main, 3)
	check_eq(main.world.data.drops_at(drop_at).size(), 1, "a drop next to the altar, in the circle")
	set_bot(main, "aimat:%d,%d;wait:1;pray" % [drop_at.x, drop_at.y])
	step_main(main, 3)
	check(main.world.data.drops_at(drop_at).is_empty(), "F picks the drop up")
	check(main.prayer.meditators.is_empty(), "the pick up took the press: no meditation")
	set_bot(main, "pray")
	step_main(main, 2)
	check(main.prayer.is_meditating(p.get_instance_id()), "nothing there: the tap meditates")
	main.prayer.break_meditation(p.get_instance_id(), "test")
	# A downed player in revive reach: the tap is refused (F there revives), F held revives as before.
	var ally: Player = main.add_ally("miner", true)
	ally.teleport(p.sim_position + Vector2(14, 0))
	set_bot(main, "pray")
	step_main(main, 2)
	check(main.prayer.meditators.is_empty(), "a downed player in reach: no meditation")
	check_eq(main.prayer.stat("refused_meditate"), 1, "refused (F there revives)")
	set_bot(main, "hold:%d" % (Config.REVIVE_TICKS + 5))
	step_main(main, Config.REVIVE_TICKS + 3)
	check(ally.vitals.alive(), "F held revives as before")


func _check_prayer_of_four(main: Main, south: Vector2i) -> void:
	var p: Player = place(main, "cleric", south, 100)
	var classes: PackedStringArray = ["paladin", "archer", "miner"]
	var scripts: PackedStringArray = ["c", "wl", "q"]
	var allies: Array[Player] = []
	for i: int in 3:
		var a: Player = main.add_ally(classes[i], false)
		main._ally_scripts[a.get_instance_id()] = scripts[i]
		allies.append(a)
		check(Prayer.in_circle(main.world.data, a.sim_position), "%s stands in the circle" % a.name)
	var starts: Array[Vector2] = [p.sim_position]
	for a2: Player in allies:
		starts.append(a2.sim_position)
	check_eq(set_bot(main, "wait:2;pray;answer:auto"), "", "the cleric's bot")
	var pr: Prayer = main.prayer
	check(step_until(main, func() -> bool: return pr.running(), 10), "the cleric's tap starts it (others in the circle)")
	check(main.prayer_view.visible and main.prayer_view.centre == main.world.data.altar_center_px(), "the circle shows")
	check_eq(main.world.altar.looks, PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1, 1]), "the lamps go dark (unlit) as it starts")
	check(not main.world.altar.flames.visible, "the altar's own flames hidden")
	check(step_until(main, func() -> bool: return pr.is_member(allies[2].get_instance_id()), Config.PRAYER_GATHER_TICKS), "the miner joins")
	main._physics_process(TICK)
	check_eq(allies[2].prayer_mark.kind, PrayerMark.Kind.JOINED, "the joined flame over who just joined")
	check(step_until(main, func() -> bool: return pr.phase == Prayer.Phase.TURNS, Config.PRAYER_GATHER_TICKS + 5), "the turns")
	check_eq(pr.members.size(), 4, "the three allies joined in the gather")
	# Turn 0 is the cleric's: his HUD prompt, the arrow over him, the ember on lamp 0.
	step_main(main, 4)
	check_eq(pr.turn, 0, "turn 0")
	check_eq(main.hud.prayer_dir, pr.directions[0], "the cleric's HUD prompt shows the direction")
	check(main.hud.prayer_left > 0 and main.hud.prayer_left < Config.PRAYER_ANSWER_WINDOW_TICKS, "its window draining")
	check_eq(p.prayer_mark.kind, PrayerMark.Kind.NONE, "no arrow over this machine's own player: its HUD prompt instead (the others see it)")
	check_eq(allies[0].prayer_mark.kind, PrayerMark.Kind.NONE, "the others show nothing then (their joined flames were for a while)")
	check_eq(main.world.altar.looks[0], Altar.Look.EMBER, "lamp 0 being answered: the ember")
	check_eq(main.hud.prayer_lamps, main.world.altar.looks, "M10-fix: the HUD's lamps grid shows the altar's lamps (the cleric prays)")
	check(step_until(main, func() -> bool: return pr.answered, Config.PRAYER_ANSWER_WINDOW_TICKS), "answered")
	check_eq(pr.lamps[0], Prayer.Lamp.LIT, "the bot's answer:auto: right")
	check_eq(main.hud.prayer_dir, -1, "the prompt gone once answered")
	main._physics_process(TICK)
	check_eq(main.world.altar.looks[0], Altar.Look.LIT, "lamp 0 lit on the altar")
	# Turn 1 is the paladin's: the arrow over the ally, none on the cleric's HUD.
	check(step_until(main, func() -> bool: return pr.turn == 1 and pr.turn_ticks == 3, 200), "turn 1")
	main._physics_process(TICK)
	check(allies[0].prayer_mark.kind == PrayerMark.Kind.TURN and allies[0].prayer_mark.dir == pr.directions[1],
		"the arrow over the paladin (seen by everyone)")
	check_eq(main.hud.prayer_dir, -1, "not the cleric's turn: no HUD prompt")
	# Turn 3: the miner quits as it opens (q): it leaves, its turn fails, its left mark shows.
	check(step_until(main, func() -> bool: return pr.turn == 3 and pr.answered, 600), "turn 3 decided")
	check(not pr.is_member(allies[2].get_instance_id()), "the miner left")
	main._physics_process(TICK)
	check_eq(allies[2].prayer_mark.kind, PrayerMark.Kind.LEFT, "the left mark over it")
	check_eq(allies[2].prayer_role, Prayer.Role.NONE, "free again")
	# A lamp that failed flickers on the altar, then shows its soot.
	check(step_until(main, func() -> bool: return pr.clock - pr.lamp_ticks[3] == 7, 30), "a few ticks after lamp 3 failed")
	check_eq(main.world.altar.looks[3], Altar.Look.UNLIT, "flickering (off)")
	check(step_until(main, func() -> bool: return pr.clock - pr.lamp_ticks[3] >= Config.PRAYER_FLICKER_TICKS, 60), "flicker over")
	main._physics_process(TICK)
	check_eq(main.world.altar.looks[3], Altar.Look.SOOT, "out: soot")
	# While praying: no move, no panel, no skill.
	main.open_crafting(Crafting.hand_station(Config.MAP_SURFACE))
	check(not main.crafting_open(), "a panel does not open while praying")
	main.open_shop(Merchant.tile_of(main.world.data))
	check(not main.shop_open(), "nor the shop")
	check(step_until(main, func() -> bool: return not pr.running(), Config.PRAYER_TURNS * 120), "it ends")
	check_eq(pr.last.lamps, PackedInt32Array([1, 1, 2, 2, 1, 1, 2, 1, 1]), "c c w q c c l c c: six lit")
	check_eq(pr.last.participants, 3, "three still in")
	var pct: int = Prayer.zeal_pct(6, 3)
	check_eq(pct, 21, "15 + 2 + 4")
	for q: Player in [p, allies[0], allies[1]]:
		check_eq(q.skills.zeal_pct, pct, "%s: zeal %d%%" % [q.name, pct])
	check(not allies[2].skills.zealous(), "the miner who quit: none")
	check_eq(p.skills.resource, 100 - Config.PRAYER_FAITH_COST, "the cleric's faith spent")
	for k: int in 4:
		var who: Player = p if k == 0 else allies[k - 1]
		check(who.sim_position.distance_to(starts[k]) < 0.01, "%s did not move while praying" % who.name)
	main._physics_process(TICK)
	check(not main.prayer_view.visible, "the circle gone")
	var shown: PackedInt32Array = PackedInt32Array()
	for s: int in pr.last.lamps:
		shown.append(Altar.Look.LIT if s == Prayer.Lamp.LIT else Altar.Look.SOOT)
	check_eq(main.world.altar.looks, shown, "the lamps show the result a while (lit, out)")
	check_eq(main.hud.prayer_lamps, shown, "M10-fix: the HUD's grid shows the result too (the cleric still at the altar)")
	step_main(main, Config.PRAYER_RESULT_SHOW_TICKS)
	check(main.world.altar.looks.is_empty() and main.world.altar.flames.visible, "then the altar's own picture (○ R45)")
	check(main.hud.prayer_lamps.is_empty(), "M10-fix: and no grid")
	check(p.effect_marks.shown.has(EffectMarks.Kind.ZEAL) and allies[0].effect_marks.shown.has(EffectMarks.Kind.ZEAL),
		"the zeal marks over the buffed")
	# A second prayer is refused while the cleric's zeal lasts; meditation too.
	set_bot(main, "pray")
	step_main(main, 2)
	check(not pr.running() and pr.stat("refused_start") >= 1, "zeal still on: no new prayer")
	# A death takes the zeal off (Main: down, give up, dead).
	p.take_hit(Config.PLAYER_HP_MAX)
	set_bot(main, "hold:%d" % (Config.GIVE_UP_HOLD_TICKS + 5))
	step_main(main, Config.GIVE_UP_HOLD_TICKS + 3)
	check_eq(p.vitals.life, Vitals.Life.DEAD, "the cleric gave up")
	check(not p.skills.zealous(), "dead: the zeal is gone (● R45)")
	check(allies[0].skills.zealous(), "the others keep theirs")


func _check_session_refusal(main: Main, south: Vector2i) -> void:
	var p: Player = place(main, "cleric", south, 100)
	main.add_ally("paladin", false)
	var role: int = main.net.role
	main.net.role = NetSession.Role.CLIENT
	main.net.local_ops.clear()
	var t: Prayer.Tapped = main.prayer_tap(p)
	var sent: Array[NetProtocol.InputFrame] = main.net.local_ops.duplicate()
	main.net.local_ops.clear()
	main.net.role = role
	check(t == null and not main.prayer.running() and sent.size() == 1 and sent[0].op == NetProtocol.Op.PRAY,
		"in a session the tap is the host's (M10b): one PRAY request, nothing starts here")


## M10-fix: F aimed at `target` by the local player `p` as a session client, held `held` ticks (Input's F: the session reads the
## key, not the frame) and let go; returns the requests it queued.
static func session_press(main: Main, p: Player, target: Vector2i, held: int) -> Array[int]:
	var centre: Vector2 = Vector2(target * Config.TILE) + Vector2.ONE * (Config.TILE / 2.0)
	p.aim_sector = Aim.sector(centre - p.sim_position, p.aim_sector)
	main.net.local_ops.clear()
	main._f_press()
	Input.action_press(&"interact")
	for i: int in held:
		main._track_f_tap()
	Input.action_release(&"interact")
	main._track_f_tap()
	var ops: Array[int] = []
	for f: NetProtocol.InputFrame in main.net.local_ops:
		ops.append(f.op)
	main.net.local_ops.clear()
	return ops


## M10-fix (M10b's session F, as a client): the PICKUP goes as before; a PRAY only for a tap nothing on this machine took.
func _check_session_f(main: Main, south: Vector2i) -> void:
	var d: WorldData = main.world.data
	var role: int = main.net.role
	var pickup: int = NetProtocol.Op.PICKUP
	var pray: int = NetProtocol.Op.PRAY
	# The merchant, from inside the circle.
	var m: Vector2i = Merchant.tile_of(d)
	var p: Player = place(main, "paladin", beside_in_circle(d, m), 0)
	main.net.role = NetSession.Role.CLIENT
	check_eq(Aim.target_cell(p.sim_position, Aim.sector(Vector2(m * Config.TILE) + Vector2.ONE * 8.0 - p.sim_position)), m,
		"session: it aims at the merchant")
	check_eq(session_press(main, p, m, 3), [pickup] as Array[int], "session: F tapped at the merchant inside the circle: PICKUP, no PRAY")
	# A drop on the tile next to the altar.
	main.net.role = role
	var r: Rect2i = d.altar_rect
	var at: Vector2i = Vector2i(r.position.x + 1, r.end.y + 1)
	p = place(main, "archer", at, 0)
	p.inventory.add(&"stone_a", 3)
	for i: int in p.inventory.size():
		if p.inventory.stack_at(i) != null and p.inventory.stack_at(i).id == &"stone_a":
			p.inventory.select(i)
	var drop_at: Vector2i = at + Vector2i(1, 0)
	set_bot(main, "aimat:%d,%d;drop" % [drop_at.x, drop_at.y])
	step_main(main, 3)
	check_eq(d.drops_at(drop_at).size(), 1, "session: a drop next to the altar, in the circle")
	main.bot = null
	main.net.role = NetSession.Role.CLIENT
	check_eq(session_press(main, p, drop_at, 3), [pickup] as Array[int], "session: F tapped at the drop: PICKUP, no PRAY")
	# Nothing there: the tap is the prayer's (one PRAY after the PICKUP).
	var empty: Vector2i = at + Vector2i(0, 1)
	check_eq(session_press(main, p, empty, 3), [pickup, pray] as Array[int], "session: F tapped at nothing in the circle: PICKUP, PRAY")
	# Held past PRAYER_TAP_MAX_TICKS (to lift the altar, revive, give up): no PRAY, on release either.
	check_eq(session_press(main, p, empty, Config.PRAYER_TAP_MAX_TICKS + 1), [pickup] as Array[int],
		"session: F held %d ticks: no PRAY" % (Config.PRAYER_TAP_MAX_TICKS + 1))
	check_eq(session_press(main, p, empty, Config.PRAYER_TAP_MAX_TICKS), [pickup, pray] as Array[int],
		"session: F held %d ticks: a tap, one PRAY" % Config.PRAYER_TAP_MAX_TICKS)
	# A door next to it.
	main.net.role = role
	var door: Vector2i = south + Vector2i(1, 1)
	p = place(main, "miner", south + Vector2i(0, 1), 0)
	main.world.apply_edit(Building.edit_for(Building.DOOR, door))
	check(Building.door_cell(d, door) != Walls.NO_CELL and Prayer.in_circle(d, p.sim_position), "session: a door beside a miner in the circle")
	main.net.role = NetSession.Role.CLIENT
	check_eq(session_press(main, p, door, 3), [pickup] as Array[int], "session: F tapped at the door: PICKUP, no PRAY")
	main.net.role = role
	main.world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.WALL, door, 0))
	check_eq(Building.door_cell(d, door), Walls.NO_CELL, "the door taken away again")


func _check_zeal_in_main(main: Main) -> void:
	var p: Player = place(main, "paladin", Vector2i(30, 80), 0)
	var a: Arena = main.arenas[Config.MAP_SURFACE]
	var h: HereticSim = a.spawn_heretic(p.sim_position + Vector2(18, 0))
	p.skills.add_zeal(20, 1000)
	p.action_slot = Config.START_WEAPON_SLOT
	p.action_aim = Combat.aim_code(Vector2.RIGHT)
	main._attack(p, &"sword")
	check_eq(Config.HERETIC_HP - h.hp, 17, "Main's attack with the start sword at 20% zeal: 14 + 3")
	p.skills.zeal_pct = 0
	p.skills.zeal_ticks = 0
	main._attack(p, &"sword")
	check_eq(Config.HERETIC_HP - h.hp, 17 + 14, "without zeal: 14 as before")


## A prayer or a meditation under way at the altar blocks the lift for everyone, not only its participants (Prayer.blocks_lift,
## Main.step_altar_hold); once over, F held lifts it again.
func _check_lift_blocked(main: Main, south: Vector2i) -> void:
	var p: Player = place(main, "paladin", south, 0)
	var aim_altar: String = "aimat:%d,%d" % [south.x, south.y - 1]
	var cleric: Player = main.add_ally("cleric", false)
	cleric.skills.resource = 100
	var t: Prayer.Tapped = main.prayer_tap(cleric)
	check(t != null and t.ok() and t.what == "start", "an ally cleric starts a prayer (the paladin in the circle)")
	check(not main.prayer.is_member(p.get_instance_id()), "the paladin does not join")
	set_bot(main, "%s;hold:%d" % [aim_altar, Config.ALTAR_PICKUP_HOLD_TICKS + 5])
	step_main(main, 1)
	main._f_press()
	step_main(main, Config.ALTAR_PICKUP_HOLD_TICKS + 3)
	check(main.world.data.altar_rect.has_area() and not p.carrying_altar, "a prayer under way: an outsider's F held does not lift")
	main.prayer_tap(cleric)
	check(not main.prayer.running(), "the cleric stops it")
	var miner: Player = main.add_ally("miner", false)
	t = main.prayer_tap(miner)
	check(t != null and t.ok() and t.what == "meditate", "an ally meditates")
	set_bot(main, "%s;hold:%d" % [aim_altar, Config.ALTAR_PICKUP_HOLD_TICKS + 5])
	step_main(main, 1)
	main._f_press()
	step_main(main, Config.ALTAR_PICKUP_HOLD_TICKS / 2)
	check(main.world.data.altar_rect.has_area() and p.altar_hold_ticks == 0, "a meditation under way: an outsider's F held does not lift")
	step_main(main, Config.MEDITATE_TICKS)
	check(not main.prayer.blocks_lift(), "the meditation done")
	set_bot(main, "%s;hold:%d" % [aim_altar, Config.ALTAR_PICKUP_HOLD_TICKS + 5])
	step_main(main, 1)
	main._f_press()
	step_main(main, Config.ALTAR_PICKUP_HOLD_TICKS + 3)
	check(p.carrying_altar, "nothing under way: F held lifts it")
	check_eq(main.place_altar(p, Vector2i(south.x, south.y - 1)), "", "put back down")

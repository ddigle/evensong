extends "res://tests/base_test.gd"
## M2b: gatherables, drops, requests and body actions over the network, in one process.
##   - the gatherable table and the grade rule (● gameplay-design §3.4: the herbalist's herbs FINE)
##   - the rules (items/world_items.gd): reach, pick up a gatherable or a drop (whole, in part, full
##     inventory), drop, use, give
##   - the feet tile when the feet stand on a tile line; a client give over 255 split in requests
##   - the host's request checks through SessionHost.run_frame (a real NetSession, no transport):
##     out of reach, wrong tile, empty slot, not a tool, busy, spam (rate), give off, drop off,
##     selects never rate limited, a refused select sends the inventory back, a use faces its tile;
##     two players picking up the same gatherable / drop in the same tick -> exactly one gets it, by
##     hand and through SessionHost.tick (the lower slot)
##   - drops in WorldData, the content hash, the snapshot (round trip, refusals, MAX_DROPS) and the
##     edit log (drop edits, a late joiner = snapshot + catch-up edits = the host's world), ItemView = data
##   - inventory and request wire format (round trips, every truncation, malformed ones)
##   - the client's prediction of body actions against a host running run_frame over a delayed,
##     lossy link (no error, no action correction), and a host that refuses a use (corrected); a
##     standing client turned by its look alone (the frame is recorded, the host turns too); the own
##     inventory from the host with pending and queued selects laid on top (SessionClient.on_inventory)
##   - interpolation of another player's action (shown from its start tick)
##   - offline main.tscn: F picks up the gatherable on the target tile, F7 drops, F again picks it up

const Runner := preload("res://tests/run_all.gd")


func run() -> Array[String]:
	_check_table_and_grades()
	_check_rules()
	await _check_host_requests()
	await _check_races()
	await _check_tick_order()
	_check_drops_in_world()
	_check_max_drops()
	await _check_edit_log_and_view()
	_check_inventory_codec()
	await _check_prediction_with_actions()
	await _check_look_turns()
	await _check_inventory_rebase()
	_check_interpolated_actions()
	await _check_offline_main()
	return failures


# --- table, grades ---------------------------------------------------------------------------

func _check_table_and_grades() -> void:
	check_eq(WorldItems.GATHERABLES.size(), 15, "15 gatherables (M2a item table)")
	for i: int in WorldItems.GATHERABLES.size():
		var id: StringName = WorldItems.GATHERABLES[i]
		var def: ItemDB.ItemDef = ItemDB.get_def(id)
		check(def != null and def.kind == ItemDB.Kind.GATHERABLE, "%s is a gatherable item" % id)
		check_eq(WorldItems.value_of(id), i + 1, "%s: VEGETATION value %d" % [id, i + 1])
		check_eq(WorldItems.gatherable_for(i + 1), id, "value %d -> %s" % [i + 1, id])
	check_eq(WorldItems.gatherable_for(0), &"", "0 = nothing")
	check_eq(WorldItems.gatherable_for(99), &"", "an unknown value = nothing")
	check_eq(WorldItems.value_of(&"pickaxe"), 0, "a tool is no gatherable")
	for id: StringName in Config.GATHER_ON_GRASS.keys() + Config.GATHER_ON_ASH.keys():
		check(WorldItems.value_of(id) > 0, "the generator's %s is a gatherable" % id)
	# ● gameplay-design §3.4: a herb the herbalist picks is FINE, anyone else's COMMON; others no grade.
	for id: StringName in WorldItems.GATHERABLES:
		var graded: bool = ItemDB.get_def(id).graded
		for class_id: String in Config.CLASSES:
			var want: int = ItemDB.Grade.NONE
			if graded:
				want = ItemDB.Grade.FINE if class_id == "herbalist" else ItemDB.Grade.COMMON
			check_eq(WorldItems.pick_grade(id, class_id), want, "%s picked by %s" % [id, class_id])


# --- rules -----------------------------------------------------------------------------------

## A tiny world: grass, the altar, a few gatherables; feet at the centre of tile `at`.
static func _world() -> WorldData:
	var data: WorldData = WorldData.new(Vector2i(20, 16))
	data.altar_rect = Rect2i(8, 6, 3, 3)
	for y: int in range(6, 9):
		for x: int in range(8, 11):
			data.set_value(WorldData.Layer.PLACEABLE, Vector2i(x, y), WorldData.PLACEABLE_ALTAR)
	data.set_value(WorldData.Layer.VEGETATION, Vector2i(4, 4), WorldItems.value_of(&"wild_healing"))
	data.set_value(WorldData.Layer.VEGETATION, Vector2i(6, 4), WorldItems.value_of(&"stone_a"))
	return data


static func _feet(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * Config.TILE


func _check_rules() -> void:
	var data: WorldData = _world()
	var feet: Vector2 = _feet(Vector2i(5, 5))
	# Reach: the 8 tiles around the feet tile only.
	var reach_ok: int = 0
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			if WorldItems.in_reach(feet, Vector2i(5 + dx, 5 + dy)):
				reach_ok += 1
				check(maxi(absi(dx), absi(dy)) == 1, "in reach only next to the feet tile (%d, %d)" % [dx, dy])
	check_eq(reach_ok, 8, "8 tiles in reach")
	# Feet exactly on a tile line (y = 96 = 6 x 16) stand on row 5, where they are drawn: row 6 is in
	# reach, row 7 is not.
	var on_line: Vector2 = Vector2(5 * 16 + 8, 6 * 16)
	check(WorldItems.in_reach(on_line, Vector2i(5, 6)) and WorldItems.in_reach(on_line, Vector2i(6, 5))
		and not WorldItems.in_reach(on_line, Vector2i(5, 5)) and not WorldItems.in_reach(on_line, Vector2i(5, 7)),
		"feet on a tile line: the feet tile is the row above the line")
	var inv: Inventory = Inventory.new()
	check_eq(WorldItems.pickup(data, feet, "cleric", inv, Vector2i(5, 5)).why, WorldItems.WHY_REACH, "the feet tile is no target")
	check_eq(WorldItems.pickup(data, feet, "cleric", inv, Vector2i(3, 3)).why, WorldItems.WHY_REACH, "two tiles away: out of reach")
	check_eq(WorldItems.pickup(data, _feet(Vector2i(0, 0)), "cleric", inv, Vector2i(-1, -1)).why, WorldItems.WHY_OUTSIDE,
		"outside the map")
	check_eq(WorldItems.pickup(data, feet, "cleric", inv, Vector2i(5, 4)).why, WorldItems.WHY_NOTHING, "nothing there")
	var o: WorldItems.Outcome = WorldItems.pickup(data, feet, "cleric", inv, Vector2i(4, 4))
	check(o.ok() and o.item == &"wild_healing" and o.count == 1 and o.grade == ItemDB.Grade.COMMON, "the cleric picks a common herb")
	check(o.edits.size() == 1 and o.edits[0].kind == EditLog.Kind.CELL and o.edits[0].layer == WorldData.Layer.VEGETATION
		and o.edits[0].cell == Vector2i(4, 4) and o.edits[0].value == 0, "-> one edit: that tile's gatherable = 0")
	check_eq(inv.count_of(&"wild_healing", ItemDB.Grade.COMMON), 1, "-> in the inventory")
	check_eq(WorldItems.gatherable_at(data, Vector2i(4, 4)), &"wild_healing", "the rules leave the world to the caller")
	# A full inventory: refused, the gatherable stays.
	var full: Inventory = Inventory.new(2, 2)
	full.add(&"sword", 1)
	full.add(&"bow", 1)
	check_eq(WorldItems.pickup(data, feet, "herbalist", full, Vector2i(6, 4)).why, WorldItems.WHY_FULL, "full inventory")
	# Drops: drop 5 of 12 stones, pick them up whole, then in part.
	var me: Inventory = Inventory.new()
	me.add(&"stone_a", 12)
	check_eq(WorldItems.drop(data, feet, me, 3, 0, Vector2i(5, 6)).why, WorldItems.WHY_EMPTY, "drop from an empty slot")
	check_eq(WorldItems.drop(data, feet, me, 99, 0, Vector2i(5, 6)).why, WorldItems.WHY_BAD_SLOT, "drop from no slot")
	check_eq(WorldItems.drop(data, feet, me, 0, 5, Vector2i(5, 8)).why, WorldItems.WHY_REACH, "drop out of reach")
	check_eq(WorldItems.drop(data, _feet(Vector2i(7, 7)), me, 0, 5, Vector2i(8, 7)).why, WorldItems.WHY_BLOCKED,
		"drop onto the altar")
	var d: WorldItems.Outcome = WorldItems.drop(data, feet, me, 0, 5, Vector2i(5, 6))
	check(d.ok() and d.count == 5 and me.count_of(&"stone_a") == 7, "dropped 5, 7 left")
	if check(d.edits.size() == 1 and d.edits[0].kind == EditLog.Kind.DROP_PUT, "-> one drop edit"):
		var put: WorldData.Drop = d.edits[0].drop
		check(put.item == &"stone_a" and put.count == 5 and put.pos == Vector2i(5 * 16 + 8, 6 * 16 + 8) and put.cell() == Vector2i(5, 6),
			"the drop lies at the centre of the target tile (%s)" % put.describe())
		EditLog.apply_to_data(data, d.edits[0])
	var all: WorldItems.Outcome = WorldItems.drop(data, feet, me, 0, 0, Vector2i(4, 6))
	check(all.ok() and all.count == 7 and me.stack_at(0) == null, "count 0 drops the whole stack")
	EditLog.apply_to_data(data, all.edits[0])
	check(all.edits[0].drop.id > d.edits[0].drop.id, "drop ids rise")
	var small: Inventory = Inventory.new(1, 1)
	small.add(&"stone_a", 97)
	var part: WorldItems.Outcome = WorldItems.pickup(data, feet, "miner", small, Vector2i(5, 6))
	check(part.ok() and part.count == 2 and small.count_of(&"stone_a") == 99, "a drop that does not fit is taken in part (2 of 5)")
	check(part.edits.size() == 1 and part.edits[0].kind == EditLog.Kind.DROP_PUT and part.edits[0].drop.count == 3,
		"-> the rest stays (3)")
	EditLog.apply_to_data(data, part.edits[0])
	var whole: WorldItems.Outcome = WorldItems.pickup(data, feet, "miner", Inventory.new(), Vector2i(5, 6))
	check(whole.ok() and whole.count == 3 and whole.edits[0].kind == EditLog.Kind.DROP_REMOVE, "the rest picked whole: removed")
	# Use: the selected tool toward the target tile.
	var u: Inventory = Inventory.new()
	u.add(&"pickaxe", 1)
	u.add(&"stone_a", 3)
	var why: Array[String] = []
	check_eq(WorldItems.use_action(feet, u, 0, Vector2i(6, 5), why), RigData.Anim.PICKAXE, "a pickaxe use plays the pickaxe action")
	check_eq(WorldItems.use_action(feet, u, 0, Vector2i(7, 5), why), -1, "a use two tiles away is refused")
	check_eq(WorldItems.use_action(feet, u, 1, Vector2i(6, 5), why), -1, "stones are no tool")
	check_eq(WorldItems.use_action(feet, u, 2, Vector2i(6, 5), why), -1, "an empty slot")
	check_eq(WorldItems.use_action(feet, u, Config.HOTBAR_SLOTS, Vector2i(6, 5), why), -1, "a slot beyond the hotbar")
	check_eq(why, [WorldItems.WHY_REACH, WorldItems.WHY_NOT_TOOL, WorldItems.WHY_EMPTY, WorldItems.WHY_BAD_SLOT] as Array[String],
		"with those reasons")
	# Give.
	var g: Inventory = Inventory.new()
	check(WorldItems.give(g, WorldItems.GIVE_KIT, 0, 0).ok() and g.count_of(&"pickaxe") == 1, "give the debug kit")
	g = Inventory.new()
	check(WorldItems.give(g, ItemDB.index_of(&"wild_buff"), 3, ItemDB.Grade.FINE).ok()
		and g.count_of(&"wild_buff", ItemDB.Grade.FINE) == 3, "give 3 fine wild buffs")
	check_eq(WorldItems.give(g, 200, 1, 0).why, WorldItems.WHY_BAD_ITEM, "give an unknown item")
	check_eq(WorldItems.give(g, ItemDB.index_of(&"stone_a"), 0, 0).why, WorldItems.WHY_BAD_COUNT, "give 0: bad count")
	# A client's --give=stone_a:300 goes out as 255 + 45 (one byte per count on the wire) and gives 300.
	var reqs: Array[NetProtocol.InputFrame] = Main.give_requests(ItemDB.index_of(&"stone_a"), 300, 0)
	var counts: Array[int] = []
	var given: Inventory = Inventory.new()
	for f: NetProtocol.InputFrame in reqs:
		var wire: NetProtocol.InputFrame = NetProtocol.InputFrame.new(1)
		wire.op = f.op
		wire.item_index = f.item_index
		wire.count = f.count
		wire.grade = f.grade
		var back: NetProtocol.InputPacket = NetProtocol.decode_inputs(NetProtocol.encode_inputs([wire] as Array[NetProtocol.InputFrame]))
		if back.ok and back.frames.size() == 1:
			counts.append(back.frames[0].count)
			WorldItems.give(given, back.frames[0].item_index, back.frames[0].count, back.frames[0].grade)
	check_eq(counts, [255, 45] as Array[int], "a give of 300 travels as 255 + 45")
	check_eq(given.count_of(&"stone_a"), 300, "and gives 300 like offline")
	check_eq(Main.give_requests(ItemDB.index_of(&"stone_a"), 255, 0).size(), 1, "255 is one request")


# --- host request checks -------------------------------------------------------------------

## A host session without a transport: world, NetSession (role host), SessionHost, members.
class Rig:
	extends RefCounted
	var world: GameWorld
	var s: NetSession
	var host: SessionHost


func _rig() -> Rig:
	var r: Rig = Rig.new()
	r.world = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	r.world.auto_generate = false
	r.world.free_camera = false
	add_node(r.world)
	r.world.generate(Config.DEFAULT_SEED)
	r.s = NetSession.new()
	r.s.name = &"TestNet"
	add_node(r.s)
	r.s.world = r.world
	r.s.options = CliOptions.new()
	r.s.role = NetSession.Role.HOST
	r.s.give_allowed = NetSession.gives_allowed(OS.is_debug_build(), false)  # as start() would: a debug build
	r.host = SessionHost.new(r.s)
	r.s.host = r.host
	return r


## A member on slot `slot` (peer 1 = the host's own) standing at the centre of tile `cell`.
func _member(r: Rig, slot: int, peer: int, class_id: String, cell: Vector2i) -> NetMember:
	var m: NetMember = r.s.add_member(slot, peer, class_id, _feet(cell), RigData.Dir.SOUTH)
	if peer != 1:
		m.gate = InputGate.new()
	return m


static func _frame(op: int, cell: Vector2i = Vector2i.ZERO, slot: int = 0) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(1, Vector2i.ZERO)
	f.op = op
	f.cell = cell
	f.slot = slot
	return f


## A gatherable tile of the seed-1 world with a free walkable tile west of it (feet there).
static func _herb_spot(data: WorldData) -> Vector2i:
	for c: Vector2i in WorldItems.gatherable_cells(data):
		if data.get_value(WorldData.Layer.PLACEABLE, c + Vector2i(-1, 0)) == 0:
			return c
	return Vector2i(-1, -1)


func _check_host_requests() -> void:
	var r: Rig = _rig()
	await await_frames(1)
	var data: WorldData = r.world.data
	var herb: Vector2i = _herb_spot(data)
	var c1: NetMember = _member(r, 1, 100, "cleric", herb + Vector2i(-1, 0))
	var before: int = WorldItems.gatherable_cells(data).size()
	# Out of reach / wrong tile / nothing there.
	r.host.run_frame(c1, _frame(NetProtocol.Op.PICKUP, herb + Vector2i(1, 0)))
	r.host.run_frame(c1, _frame(NetProtocol.Op.PICKUP, herb + Vector2i(-1, 0)))
	r.host.run_frame(c1, _frame(NetProtocol.Op.PICKUP, herb + Vector2i(-1, -1)))
	check_eq(c1.ops_refused, {WorldItems.WHY_REACH: 2, WorldItems.WHY_NOTHING: 1} as Dictionary[String, int],
		"two tiles away and the feet tile: out of reach; an empty neighbour: nothing there")
	check_eq(WorldItems.gatherable_cells(data).size(), before, "nothing picked")
	# Empty slot / not a tool / wrong tile for use, busy.
	c1.op_budget = NetMember.OP_BUDGET_MAX
	r.host.run_frame(c1, _frame(NetProtocol.Op.USE, herb, 0))
	r.host.run_frame(c1, _frame(NetProtocol.Op.DROP, herb, 0))
	check_eq(c1.ops_refused.get(WorldItems.WHY_EMPTY, 0), 2, "use and drop with an empty slot")
	c1.player.inventory.add(&"stone_a", 3)
	c1.player.inventory.add(&"pickaxe", 1)
	r.host.run_frame(c1, _frame(NetProtocol.Op.USE, herb, 0))
	check_eq(c1.ops_refused.get(WorldItems.WHY_NOT_TOOL, 0), 1, "use with stones: not a tool")
	r.host.run_frame(c1, _frame(NetProtocol.Op.USE, herb + Vector2i(2, 0), 1))
	check_eq(c1.ops_refused.get(WorldItems.WHY_REACH, 0), 3, "use toward a tile beyond the next: refused")
	check_eq(c1.player.action_anim, -1, "no action from a refused use")
	r.host.run_frame(c1, _frame(NetProtocol.Op.USE, herb, 1))
	check_eq(c1.player.action_anim, RigData.Anim.PICKAXE, "a valid use starts the pickaxe action")
	check_eq(c1.player.action_cell, herb, "toward the target tile")
	r.host.run_frame(c1, _frame(NetProtocol.Op.USE, herb, 1))
	check_eq(c1.ops_refused.get("busy", 0), 1, "a use while the action plays: busy")
	check_eq(c1.player.action_tick, 1, "the action went on")
	check(c1.player.sim_position == _feet(herb + Vector2i(-1, 0)), "uses do not move the player")
	# Spam: twenty pickups in one tick -> the burst, then "rate"; a token every NET_OP_INTERVAL_TICKS.
	var c2: NetMember = _member(r, 2, 101, "herbalist", herb + Vector2i(-1, 0))
	var herb_id: StringName = WorldItems.gatherable_at(data, herb)
	for i: int in 20:
		r.host.run_frame(c2, _frame(NetProtocol.Op.PICKUP, herb + Vector2i(-1, 1)))
	check_eq(c2.ops_refused.get("rate", 0), 20 - Config.NET_OP_BURST, "spam: %d refused as rate" % (20 - Config.NET_OP_BURST))
	check_eq(c2.ops_refused.get(WorldItems.WHY_NOTHING, 0), Config.NET_OP_BURST, "the burst went through (nothing there)")
	for t: int in Config.NET_OP_INTERVAL_TICKS:
		c2.refill_ops()
	r.host.run_frame(c2, _frame(NetProtocol.Op.PICKUP, herb))
	check_eq(c2.ops_done.get("pickup", 0), 1, "after NET_OP_INTERVAL_TICKS ticks one more request")
	check_eq(c2.player.inventory.count_of(herb_id, WorldItems.pick_grade(herb_id, "herbalist")), 1,
		"the herbalist got it (%s, grade %d)" % [herb_id, WorldItems.pick_grade(herb_id, "herbalist")])
	check_eq(WorldItems.gatherable_at(data, herb), &"", "and it is gone from the world")
	check_eq(r.s.edit_log.size(), 1, "one edit logged")
	check(c2.inventory_dirty, "the owner's inventory goes out after the tick")
	# Give: a client's only when the host allows it; the host's own always.
	var me: NetMember = _member(r, 0, 1, "paladin", herb + Vector2i(-2, 0))
	var give: NetProtocol.InputFrame = _frame(NetProtocol.Op.GIVE)
	give.item_index = ItemDB.index_of(&"bow")
	give.count = 1
	r.s.give_allowed = false
	r.host.run_frame(c1, give)
	check_eq(c1.ops_refused.get("give off", 0), 1, "a client's give is refused without a debug build / --test-allow-give")
	r.host.run_frame(me, give)
	check_eq(me.player.inventory.count_of(&"bow"), 1, "the host's own give works")
	r.s.give_allowed = true
	for t: int in Config.NET_OP_INTERVAL_TICKS:
		c1.refill_ops()
	r.host.run_frame(c1, give)
	check_eq(c1.player.inventory.count_of(&"bow"), 1, "allowed: the client gets it")
	check(NetSession.gives_allowed(true, false) and NetSession.gives_allowed(false, true) and not NetSession.gives_allowed(false, false),
		"gives allowed = debug build or --test-allow-give")
	check(OS.is_debug_build(), "tests run a debug build (the session tests' hosts honour gives)")
	# Select: a request that changes the held item.
	var sel: NetProtocol.InputFrame = _frame(NetProtocol.Op.SELECT, Vector2i.ZERO, 1)
	for t: int in Config.NET_OP_INTERVAL_TICKS:
		c1.refill_ops()
	r.host.run_frame(c1, sel)
	check_eq(c1.state().held, &"pickaxe", "select slot 2: the state's held item")
	# Debug drop: a client's only where the host allows it (like give); the host's own always.
	r.s.give_allowed = false
	c1.op_budget = NetMember.OP_BUDGET_MAX
	r.host.run_frame(c1, _frame(NetProtocol.Op.DROP, herb + Vector2i(-1, 1), 0))
	check_eq(c1.ops_refused.get("drop off", 0), 1, "a client's debug drop is refused without a debug build / --test-allow-give")
	var drops_before: int = data.drops.size()
	r.host.run_frame(me, _frame(NetProtocol.Op.DROP, herb + Vector2i(-2, 1), 0))
	var host_drops: int = me.ops_done.get("drop", 0)
	check(host_drops == 1 and data.drops.size() == drops_before + 1, "the host's own debug drop works")
	r.s.give_allowed = true
	# Selects are not rate limited (the client predicted them; a "rate" refusal would leave its hotbar
	# wrong): ten in a row with an empty budget all go through, and need no inventory back.
	c1.op_budget = 0
	c1.inventory_dirty = false
	var selects_before: int = c1.ops_done.get("select", 0)
	for i: int in 10:
		r.host.run_frame(c1, _frame(NetProtocol.Op.SELECT, Vector2i.ZERO, i % 2))
	check_eq(c1.ops_done.get("select", 0), selects_before + 10, "ten selects in ten frames: all handled")
	check_eq(c1.ops_refused.get("rate", 0), 0, "none refused as rate")
	check(not c1.inventory_dirty, "an accepted select sends no inventory (predicted; the state carries the held item)")
	# A refused select sends the owner its inventory, which carries the host's selection and ack.
	r.host.run_frame(c1, _frame(NetProtocol.Op.SELECT, Vector2i.ZERO, Config.HOTBAR_SLOTS))
	var bad_slots: int = c1.ops_refused.get(WorldItems.WHY_BAD_SLOT, 0)
	check(bad_slots == 1 and c1.inventory_dirty and c1.player.inventory.selected == 1,
		"a refused select: the inventory goes back to the owner, the host's selection stays")
	# A use whose look points away from its tile: the action faces the tile (the host decides).
	for i: int in PlayerSim.action_ticks(RigData.Anim.PICKAXE):
		r.host.run_frame(c1, NetProtocol.InputFrame.new())
	check_eq(c1.player.action_anim, -1, "c1's pickaxe action ended")
	var away: NetProtocol.InputFrame = _frame(NetProtocol.Op.USE, herb, 1)
	away.look = RigData.Dir.WEST
	r.host.run_frame(c1, away)
	check(c1.player.action_anim == RigData.Anim.PICKAXE and c1.player.facing == RigData.Dir.EAST and c1.player.action_cell == herb,
		"a use east with a west look: the action faces east, toward its tile (facing %s)" % RigData.DIR_NAMES[c1.player.facing])
	note("request checks: c1 refused %s, c2 refused %s" % [c1.ops_refused, c2.ops_refused])


## Two players picking up the same thing in the same tick: exactly one gets it (members in slot
## order, edits applied at once), for a gatherable and for a drop.
func _check_races() -> void:
	var r: Rig = _rig()
	await await_frames(1)
	var data: WorldData = r.world.data
	var herb: Vector2i = _herb_spot(data)
	var a: NetMember = _member(r, 1, 100, "miner", herb + Vector2i(-1, 0))
	var b: NetMember = _member(r, 2, 101, "archer", herb + Vector2i(0, -1))
	var c: NetMember = _member(r, 3, 102, "herbalist", herb + Vector2i(1, 1))
	# Same tick: every member's frame in slot order, like SessionHost.tick.
	for m: NetMember in [a, b, c]:
		r.host.run_frame(m, _frame(NetProtocol.Op.PICKUP, herb))
	var got: Array[String] = []
	for m: NetMember in [a, b, c]:
		var picked: int = m.ops_done.get("pickup", 0)
		if picked == 1:
			got.append(m.class_id)
	check_eq(got, ["miner"] as Array[String], "the gatherable: exactly one (the lowest slot) gets it")
	var b_nothing: int = b.ops_refused.get(WorldItems.WHY_NOTHING, 0)
	var c_nothing: int = c.ops_refused.get(WorldItems.WHY_NOTHING, 0)
	check(b_nothing == 1 and c_nothing == 1, "the others find nothing")
	# A drop: the host drops 7 stones; three pick in the same tick.
	var me: NetMember = _member(r, 0, 1, "paladin", herb + Vector2i(0, 1))
	me.player.inventory.add(&"stone_b", 7)
	r.host.run_frame(me, _frame(NetProtocol.Op.DROP, herb, 0))
	check_eq(data.drops.size(), 1, "the host's drop lies there")
	for m: NetMember in [c, b, a]:
		m.op_budget = NetMember.OP_BUDGET_MAX
	for m: NetMember in [a, b, c]:
		r.host.run_frame(m, _frame(NetProtocol.Op.PICKUP, herb))
	var counts: Array[int] = []
	for m: NetMember in [a, b, c]:
		counts.append(m.player.inventory.count_of(&"stone_b"))
	check_eq(counts, [7, 0, 0] as Array[int], "the drop: exactly one gets all 7")
	check_eq(data.drops.size(), 0, "and it is gone")
	check_eq(r.s.edit_log.size(), 3, "edits: gatherable, drop put, drop removed")


## The same race through SessionHost.tick itself: pickups of one gatherable from slots 2 and 1 wait in
## their input gates (slot 2's member and frame added first); the tick handles members in slot order,
## so slot 1 gets it and slot 2 finds nothing.
func _check_tick_order() -> void:
	var r: Rig = _rig()
	await await_frames(1)
	var data: WorldData = r.world.data
	var herb: Vector2i = _herb_spot(data)
	r.s.local = _member(r, 0, 1, "paladin", herb + Vector2i(-3, 0))
	var late: NetMember = _member(r, 2, 102, "archer", herb + Vector2i(0, -1))
	var early: NetMember = _member(r, 1, 101, "miner", herb + Vector2i(-1, 0))
	for m: NetMember in [late, early]:
		var f: NetProtocol.InputFrame = _frame(NetProtocol.Op.PICKUP, herb)
		m.gate.receive(NetProtocol.decode_inputs(NetProtocol.encode_inputs([f] as Array[NetProtocol.InputFrame])))
	var id: StringName = WorldItems.gatherable_at(data, herb)
	r.s.tick = 1
	r.host.tick(NetBot.Action.new(), Time.get_ticks_msec())
	var early_picked: int = early.ops_done.get("pickup", 0)
	var late_picked: int = late.ops_done.get("pickup", 0)
	var late_nothing: int = late.ops_refused.get(WorldItems.WHY_NOTHING, 0)
	check(early_picked == 1 and early.player.inventory.count_of(id) == 1,
		"SessionHost.tick: slot 1 gets the gatherable (%s)" % id)
	check(late_picked == 0 and late_nothing == 1, "slot 2, whose frame came first, finds nothing there")
	check(early.gate.last_seq == 1 and late.gate.last_seq == 1, "both frames handled in that tick")


# --- drops in the world, snapshot, edit log, view ------------------------------------------

func _check_drops_in_world() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var plain: String = data.content_hash()
	var drop: WorldData.Drop = WorldData.Drop.new(data.new_drop_id(), &"wild_poison", 4, ItemDB.Grade.FINE, Vector2i(800, 600))
	data.drops[drop.id] = drop
	check_ne(data.content_hash(), plain, "a drop changes the content hash")
	drop.count = 3
	var three: String = data.content_hash()
	drop.count = 4
	check_ne(three, data.content_hash(), "so does its count")
	var second: WorldData.Drop = WorldData.Drop.new(data.new_drop_id(), &"pickaxe", 1, ItemDB.Grade.NONE, Vector2i(5, 5))
	data.drops[second.id] = second
	check(second.id > drop.id, "new_drop_id rises")
	var raw: PackedByteArray = WorldSnapshot.raw_bytes(data)
	check_eq(raw.size(), WorldSnapshot.HEADER_SIZE + WorldData.LAYER_COUNT * data.size.x * data.size.y + 2 + 2 * WorldData.DROP_BYTES + 2,
		"raw snapshot = header + layers + 2 + 11 B per drop + the chest count (M7c)")
	var back: WorldData = WorldSnapshot.decode_raw(raw)
	check(back != null and back.content_hash() == data.content_hash() and back.drops.size() == 2
		and back.drops[drop.id].same_as(drop) and back.drops[second.id].same_as(second), "drops round trip in the snapshot")
	var gather_cells: int = WorldItems.gatherable_cells(data).size()
	check(back != null and WorldItems.gatherable_cells(back).size() == gather_cells and gather_cells > 0,
		"gatherables (VEGETATION) round trip (%d)" % gather_cells)
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(data)
	var rx: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
	for i: int in packed.chunk_count():
		rx.add(packed.chunk(i))
	var got: WorldData = rx.finish(packed.chunk_count(), packed.bytes.size(), packed.packed_md5, packed.raw_size, packed.world_md5)
	check(got != null and got.content_hash() == data.content_hash(), "a joiner's checked world has the drops (%s)" % rx.error)
	var drops_at: int = WorldSnapshot.HEADER_SIZE + WorldData.LAYER_COUNT * data.size.x * data.size.y
	var bad: Dictionary[String, PackedByteArray] = {}
	var b: PackedByteArray = raw.duplicate()
	b[drops_at + 2 + 4] = ItemDB.count()
	bad["unknown item"] = b
	b = raw.duplicate()
	b[drops_at + 2 + 5] = 0
	bad["count 0"] = b
	b = raw.duplicate()
	b[drops_at + 2 + 5] = 100
	bad["count above the stack size"] = b
	b = raw.duplicate()
	b[drops_at + 2 + 6] = ItemDB.Grade.NONE  # a herb without a grade
	bad["a grade the item cannot have"] = b
	b = raw.duplicate()
	b.encode_u16(drops_at + 2 + 7, data.size.x * Config.TILE)
	bad["outside the map"] = b
	b = raw.duplicate()
	b.encode_u32(drops_at + 2 + WorldData.DROP_BYTES, drop.id)
	bad["the same id twice"] = b
	b = raw.duplicate()
	b.encode_u16(drops_at, 3)
	bad["more drops than bytes"] = b
	b = raw.duplicate()
	b.append(0)
	bad["a byte after the drops"] = b
	b = raw.duplicate()
	b.encode_u16(drops_at, Config.MAX_DROPS + 1)
	bad["over MAX_DROPS"] = b
	for label: String in bad:
		check(WorldSnapshot.decode_raw(bad[label]) == null, "snapshot refused: drop with %s" % label)


## The host's drop bound: with MAX_DROPS on the ground a drop is refused ("too many drops"), and the
## world at the bound still makes a snapshot a late joiner accepts (decode_raw refuses more).
func _check_max_drops() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	for i: int in Config.MAX_DROPS:
		var at: Vector2i = Vector2i(i % data.size.x, i / data.size.x) * Config.TILE + Vector2i(8, 8)
		var d: WorldData.Drop = WorldData.Drop.new(data.new_drop_id(), &"stone_a", 1, ItemDB.Grade.NONE, at)
		data.drops[d.id] = d
	var feet: Vector2 = _feet(Vector2i(10, 20))
	var inv: Inventory = Inventory.new()
	inv.add(&"stone_a", 3)
	check_eq(WorldItems.drop(data, feet, inv, 0, 1, Vector2i(11, 20)).why, WorldItems.WHY_TOO_MANY,
		"a drop with %d on the ground: too many drops" % Config.MAX_DROPS)
	check_eq(inv.count_of(&"stone_a"), 3, "the stones stay in the inventory")
	var back: WorldData = WorldSnapshot.decode_raw(WorldSnapshot.raw_bytes(data))
	check(back != null and back.drops.size() == Config.MAX_DROPS and back.content_hash() == data.content_hash(),
		"a world with %d drops round trips in the snapshot" % Config.MAX_DROPS)
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(data)
	check(packed.bytes.size() > 0 and packed.bytes.size() <= WorldSnapshot.MAX_PACKED, "and packs (%d B)" % packed.bytes.size())


func _check_edit_log_and_view() -> void:
	var host: GameWorld = _new_world()
	var joiner: GameWorld = _new_world()
	await await_frames(1)
	var data: WorldData = host.data
	check_eq(host.items.verify()["mismatches"], 0, "items drawn = data after generating")
	check_eq(host.items.plants.size(), WorldItems.gatherable_cells(data).size(), "one sprite per gatherable")
	var cell: Vector2i = WorldItems.gatherable_cells(data)[0]
	var sprite: Sprite2D = host.items.plants[cell]
	check(sprite.get_parent() == host.entities and sprite.position == Vector2(cell.x * 16 + 8, (cell.y + 1) * 16)
		and sprite.offset == Vector2(-8, -16) and sprite.light_mask == Config.LIGHT_LAYER_ACTORS,
		"a gatherable stands in the y-sorted entities on its tile's bottom edge, actor light")
	# Host edits: a gatherable picked, two drops, one changed, one removed. Snapshot after the first two.
	var log: EditLog = EditLog.new()
	var edits: Array[EditLog.WorldEdit] = [
		EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, cell, 0),
		EditLog.WorldEdit.drop_put(WorldData.Drop.new(data.new_drop_id(), &"stone_c", 9, ItemDB.Grade.NONE, Vector2i(808, 600))),
	]
	for e: EditLog.WorldEdit in edits:
		check(host.apply_edit(e), "host applies %s" % e.describe())
		log.append(e)
	var snapshot: WorldSnapshot.Packed = WorldSnapshot.encode(data)
	var position: int = log.size()
	var put: WorldData.Drop = WorldData.Drop.new(data.new_drop_id(), &"wild_buff", 2, ItemDB.Grade.FINE, Vector2i(840, 616))
	var later: Array[EditLog.WorldEdit] = [EditLog.WorldEdit.drop_put(put)]
	var changed: WorldData.Drop = put.copy()
	changed.count = 1
	later.append(EditLog.WorldEdit.drop_put(changed))
	later.append(EditLog.WorldEdit.drop_remove(edits[1].drop_id))
	for e: EditLog.WorldEdit in later:
		host.apply_edit(e)
		log.append(e)
	check(host.items.plants.size() == WorldItems.gatherable_cells(data).size() and not host.items.plants.has(cell),
		"the picked gatherable's sprite is gone")
	check(host.items.drops.size() == 1 and host.items.drops.has(put.id), "one drop sprite left")
	check_eq(host.items.verify()["mismatches"], 0, "items drawn = data after the edits")
	# The joiner: snapshot (taken mid-way), then the later edits through the wire.
	var rx: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
	for i: int in snapshot.chunk_count():
		rx.add(snapshot.chunk(i))
	var received: WorldData = rx.finish(snapshot.chunk_count(), snapshot.bytes.size(), snapshot.packed_md5, snapshot.raw_size,
		snapshot.world_md5)
	if not check(received != null, "the snapshot arrives (%s)" % rx.error):
		return
	joiner.load_data(received)
	check(joiner.data.drops.size() == 1 and joiner.items.drops.size() == 1, "the joiner sees the drop of its snapshot")
	for i: int in range(position, log.size()):
		var wire: Array = EditLog.decode_one(EditLog.encode_one(log.edit_at(i), i))
		var index: int = wire[0]
		var e: EditLog.WorldEdit = wire[1]
		check_eq(index, i, "edit %d keeps its index on the wire" % i)
		check(joiner.apply_edit(e) and joiner.apply_edit(e), "edit %d applied twice (absolute)" % i)
	check_eq(joiner.data.content_hash(), host.data.content_hash(), "snapshot + later drop edits = the host's world")
	check_eq(joiner.items.verify()["mismatches"], 0, "the joiner draws its items = data")
	check(joiner.items.drops.has(put.id) and joiner.items.drops[put.id].texture == ItemIcons.texture_for(&"wild_buff"),
		"a drop shows its item's icon")
	# Edit wire format: sizes, refusals.
	check_eq(EditLog.encode_one(later[0], 7).size(), 17, "drop put edit = 17 B (M3b: + map)")
	check_eq(EditLog.encode_one(later[2], 7).size(), 10, "drop removed edit = 10 B (M3b: + map)")
	check_eq(EditLog.encode_one(edits[0], 7).size(), 11, "cell edit = 11 B (M1's 10 + map, M3b)")
	var bad_put: PackedByteArray = EditLog.encode_one(later[0], 7)
	bad_put[EditLog.HEADER_SIZE + 1 + 4] = ItemDB.count()
	var r1: Array = EditLog.decode_one(bad_put)
	var r1_index: int = r1[0]
	check_eq(r1_index, -1, "a drop edit with an unknown item is malformed")
	var long_rm: PackedByteArray = EditLog.encode_one(later[2], 7)
	long_rm.append(0)
	var r2: Array = EditLog.decode_one(long_rm)
	var r2_index: int = r2[0]
	check_eq(r2_index, -1, "a drop removal with a byte too many is malformed")
	var outside: WorldData.Drop = put.copy()
	outside.pos = Vector2i(data.size.x * Config.TILE + 3, 0)
	check(not joiner.apply_edit(EditLog.WorldEdit.drop_put(outside)), "a drop outside the map is not applied")
	check_ne(EditLog.check(data, edits[0]), "", "a gatherable edit is no debug edit (EditLog.check: floor only)")


func _new_world() -> GameWorld:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	return w


func _check_inventory_codec() -> void:
	var inv: Inventory = Inventory.new()
	inv.add(&"pickaxe", 1)
	inv.add(&"wild_poison", 7, ItemDB.Grade.FINE)
	inv.add(&"stone_a", 99)
	inv.move(2, 20)
	inv.select(5)
	var bytes: PackedByteArray = NetProtocol.encode_inventory(inv, 4000000001)
	check_eq(bytes.size(), NetProtocol.INVENTORY_HEADER + 3 * (Config.INVENTORY_SLOTS + 1),
		"inventory = 6 + 3 B x 24 slots + the empty armour slot (M7c; no item with durability here)")
	var back: NetProtocol.InventoryState = NetProtocol.decode_inventory(bytes)
	check(back.ok and back.ack == 4000000001 and back.selected == 5 and back.stacks.size() == Config.INVENTORY_SLOTS,
		"inventory decodes")
	var copy: Inventory = Inventory.new()
	if back.ok:
		copy.load_state(back.stacks, back.selected)
	check(copy.describe() == inv.describe() and copy.selected == 5, "inventory round trips (%s)" % copy.describe())
	var short_ok: int = 0
	for n: int in bytes.size():
		if NetProtocol.decode_inventory(bytes.slice(0, n)).ok:
			short_ok += 1
	check_eq(short_ok, 0, "every truncated inventory is refused")
	var cases: Dictionary[String, PackedByteArray] = {}
	var b: PackedByteArray = bytes.duplicate()
	b[4] = Config.HOTBAR_SLOTS
	cases["selection outside the hotbar"] = b
	b = bytes.duplicate()
	b[5] = Config.INVENTORY_SLOTS - 1
	cases["another slot count"] = b
	b = bytes.duplicate()
	b[NetProtocol.INVENTORY_HEADER + 1] = 2
	cases["2 pickaxes in a stack of 1"] = b
	b = bytes.duplicate()
	b[NetProtocol.INVENTORY_HEADER + 3 + 2] = ItemDB.Grade.NONE
	cases["a herb without a grade"] = b
	b = bytes.duplicate()
	b[NetProtocol.INVENTORY_HEADER + 3 * 10 + 1] = 1
	cases["an empty slot with a count"] = b
	b = bytes.duplicate()
	b[NetProtocol.INVENTORY_HEADER] = ItemDB.count() + 1
	cases["an unknown item"] = b
	for label: String in cases:
		check(not NetProtocol.decode_inventory(cases[label]).ok, "inventory refused: %s" % label)


# --- prediction and interpolation of actions -----------------------------------------------

## The client predicts its use and the following action frames; the host (run_frame) handles the
## same frames over a delayed lossy link: never an error or an action correction. Then a host whose
## copy of the inventory lacks the tool refuses the use: the client is corrected and ends on the
## host's state.
func _check_prediction_with_actions() -> void:
	for link_case: Array in [[0, 0.0], [6, 0.2]]:
		var delay: int = link_case[0]
		var loss: float = link_case[1]
		var r: Rig = _rig()
		await await_frames(1)
		var data: WorldData = r.world.data
		var start: Vector2 = data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[1])
		var m: NetMember = r.s.add_member(1, 100, "miner", start, RigData.Dir.SOUTH)
		m.gate = InputGate.new()
		m.player.inventory.add(&"pickaxe", 1)
		m.player.inventory.add(&"sword", 1)
		var me: Player = Player.new()  # the client's own player (its inventory copy)
		me.local_input = false
		me.setup(data, "miner", start, RigData.Dir.SOUTH)
		add_node(me)
		me.inventory.add(&"pickaxe", 1)
		me.inventory.add(&"sword", 1)
		var client: Prediction = Prediction.new()
		client.setup(data, start, RigData.Dir.SOUTH, 0)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 11 + delay
		var to_host: Array[Array] = []
		var to_client: Array[Array] = []
		var actions: int = 0
		for t: int in 800:
			# Walk, aim, swing the pickaxe (held: repeats), switch to the sword, swing, walk on; idle at the end.
			var phase: int = (t / 70) % 5
			var dir: Vector2i = [Vector2i(1, 0), Vector2i.ZERO, Vector2i(0, 1), Vector2i.ZERO, Vector2i(-1, -1)][phase]
			var use: bool = phase == 1 or phase == 3
			if t >= 700:
				dir = Vector2i.ZERO
				use = false
			if t == 200:
				me.inventory.select(1)  # the sword (like Q / E: predicted at once, request on a frame)
			var mouse: Vector2 = client.pos + Vector2(20, -6) if use else client.pos
			me.load_sim(client.sim)
			var f: NetProtocol.InputFrame = me.make_frame(dir, mouse, use, use, use)
			if t == 200:
				f.op = NetProtocol.Op.SELECT if f.op == NetProtocol.Op.NONE else f.op
				f.slot = 1
			var frame: NetProtocol.InputFrame = client.step_frame(f)
			if f.anim >= 0:
				actions += 1
			if client.has_unacked() and (t % 2 == 0 or (frame != null and client.pending.size() == 1)) and rng.randf() >= loss:
				to_host.append([t + delay, NetProtocol.encode_inputs(client.frames_to_send())])
			while not to_host.is_empty() and _due(to_host) <= t:
				var item: Array = to_host.pop_front()
				var bytes: PackedByteArray = item[1]
				m.gate.receive(NetProtocol.decode_inputs(bytes))
			m.refill_ops()
			for hf: NetProtocol.InputFrame in m.gate.take():
				r.host.run_frame(m, hf)
			if t % 3 == 0 and rng.randf() >= loss:
				to_client.append([t + delay, NetProtocol.encode_states(t, [m.state()] as Array[NetProtocol.PlayerState])])
			while not to_client.is_empty() and _due(to_client) <= t:
				var item: Array = to_client.pop_front()
				var bytes: PackedByteArray = item[1]
				client.reconcile(NetProtocol.decode_states(bytes).states[0])
		var label: String = "delay %d ticks, loss %d%%" % [delay, roundi(loss * 100.0)]
		var swings: int = 0
		for k: String in m.actions_seen:
			swings += m.actions_seen[k]
		check(actions >= 4 and swings == actions and m.actions_seen.has("pickaxe") and m.actions_seen.has("sword"),
			"the host ran every predicted swing (%d: %s) (%s)" % [actions, m.actions_seen, label])
		check_eq(client.max_error_px, 0.0, "position never corrected (%s)" % label)
		check_eq(client.action_corrections, 0, "actions never corrected (%s)" % label)
		check_eq(client.facing_corrections, 0, "facing (look) never corrected (%s)" % label)
		check(client.sim.same_as(m.player.to_sim()) and not client.has_unacked(), "both end in the same state (%s)" % label)
		check_eq(m.player.inventory.selected, 1, "the selection request arrived (%s)" % label)
		note("action prediction over a %s link: %d frames, %d swings, %d reconciles" % [label, client.frames, actions,
			client.reconciles])
	# A host that refuses the use (its inventory has no tool): corrected to no action.
	var r2: Rig = _rig()
	await await_frames(1)
	var start2: Vector2 = r2.world.data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[1])
	var hm: NetMember = r2.s.add_member(1, 100, "miner", start2, RigData.Dir.SOUTH)
	hm.gate = InputGate.new()
	var p2: Prediction = Prediction.new()
	p2.setup(r2.world.data, start2, RigData.Dir.SOUTH, 0)
	var use: NetProtocol.InputFrame = _frame(NetProtocol.Op.USE, Aim.feet_cell(start2) + Vector2i(1, 0), 0)
	use.look = RigData.Dir.EAST
	use.anim = RigData.Anim.PICKAXE
	var sent: NetProtocol.InputFrame = p2.step_frame(use)
	for i: int in 5:
		p2.step_frame(NetProtocol.InputFrame.new())
	check(sent != null and p2.sim.action == RigData.Anim.PICKAXE and p2.pending.size() == 6, "the client predicted its swing")
	hm.gate.receive(NetProtocol.decode_inputs(NetProtocol.encode_inputs(p2.frames_to_send())))
	for i: int in 6:
		for hf: NetProtocol.InputFrame in hm.gate.take():
			r2.host.run_frame(hm, hf)
	check_eq(hm.ops_refused.get(WorldItems.WHY_EMPTY, 0), 1, "the host refused it (no tool in its copy)")
	p2.reconcile(hm.state())
	check(p2.action_corrections == 1 and p2.sim.action == -1 and p2.sim.same_as(hm.player.to_sim()),
		"the client is corrected: no action, the host's state")


## A client standing still that only aims: the tick its look turns it records a frame (no request,
## no movement), the host gets it and turns the same way; the following ticks with the same look, and
## dropping the look, record nothing.
func _check_look_turns() -> void:
	var r: Rig = _rig()
	await await_frames(1)
	var data: WorldData = r.world.data
	var start: Vector2 = data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[1])
	var m: NetMember = r.s.add_member(1, 100, "archer", start, RigData.Dir.SOUTH)
	m.gate = InputGate.new()
	var client: Prediction = Prediction.new()
	client.setup(data, start, RigData.Dir.SOUTH, 0)
	var recorded: Array[int] = []
	for look: int in [RigData.Dir.WEST, RigData.Dir.NORTH, RigData.Dir.EAST, -1]:
		var n: int = 0
		for t: int in 10:
			var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
			f.look = look
			if client.step_frame(f) != null:
				n += 1
		recorded.append(n)
		if client.has_unacked():
			m.gate.receive(NetProtocol.decode_inputs(NetProtocol.encode_inputs(client.frames_to_send())))
		for i: int in 4:
			for hf: NetProtocol.InputFrame in m.gate.take():
				r.host.run_frame(m, hf)
		client.reconcile(m.state())
		var want: int = look if look >= 0 else RigData.Dir.EAST
		check(client.facing == want and m.player.facing == want,
			"look %s while standing: client and host face %s" % [look, RigData.DIR_NAMES[want]])
	check_eq(recorded, [1, 1, 1, 0] as Array[int], "one frame per turn, none for the same look or no look")
	check(client.facing_corrections == 0 and client.max_error_px == 0.0 and not client.has_unacked(),
		"no correction, nothing left unacknowledged")


## The client's own inventory comes from the host with the ack of the last frame the host handled; the
## hotbar selections the host has not handled yet (on later frames, or still queued) stay on top, and
## a selection the host handled (and kept or refused) is the host's.
func _check_inventory_rebase() -> void:
	var w: GameWorld = _new_world()
	var s: NetSession = NetSession.new()
	s.name = &"TestClientNet"
	add_node(s)
	s.set_physics_process(false)  # no client ticks (nothing to send to): only on_inventory is under test
	s.set_process(false)
	s.world = w
	s.options = CliOptions.new()
	s.role = NetSession.Role.CLIENT
	s.client = SessionClient.new(s)
	var start: Vector2 = w.data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[1])
	s.local = s.add_member(1, 0, "miner", start, RigData.Dir.SOUTH)
	s.active = true
	var c: SessionClient = s.client
	c.prediction = Prediction.new()
	c.prediction.setup(w.data, start, RigData.Dir.SOUTH, 0)
	var mine: Inventory = s.local.player.inventory
	var host_copy: Inventory = Inventory.new()
	for inv: Inventory in [mine, host_copy]:
		inv.add(&"pickaxe", 1)
		inv.add(&"sword", 1)
		inv.add(&"stone_a", 4)
	# Q / E on frame 1: predicted at once, the request still unacknowledged.
	var sel: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
	sel.op = NetProtocol.Op.SELECT
	sel.slot = 2
	mine.select(2)
	check(c.prediction.step_frame(sel) != null and c.prediction.pending_ops(NetProtocol.Op.SELECT, 0).size() == 1,
		"the select rides on recorded frame 1")
	# A pickup's inventory arrives with ack 0 (before the select): new items, the selection stays.
	host_copy.add(&"wild_buff", 1, ItemDB.Grade.COMMON)
	c.on_inventory(NetProtocol.encode_inventory(host_copy, 0))
	check(mine.selected == 2 and mine.count_of(&"wild_buff", ItemDB.Grade.COMMON) == 1,
		"inventory with an older ack: the picked herb arrives, the pending selection stays (slot %d)" % mine.selected)
	# A select still queued (not on a frame yet; the client applied it at once) also stays.
	s.queue_op(Main.request(NetProtocol.Op.SELECT, 4))
	check_eq(mine.selected, 4, "a queued select applies at once")
	c.on_inventory(NetProtocol.encode_inventory(host_copy, 0))
	check_eq(mine.selected, 4, "and stays on top of the host's inventory")
	# A select needs no request token: it goes on the next frame even with the budget spent.
	s.local_budget = 0
	var f2: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
	SessionHost.attach_local_op(s, s.local.player, f2, NetBot.Action.new())
	check(f2.op == NetProtocol.Op.SELECT and f2.slot == 4 and s.local_ops.is_empty(), "a queued select is not paced by the budget")
	# The host handled frame 1 (ack 1) and kept its own selection (it refused it): the host's wins.
	host_copy.select(0)
	c.on_inventory(NetProtocol.encode_inventory(host_copy, 1))
	check_eq(mine.selected, 0, "an inventory whose ack covers the select: the host's selection")
	check_eq(c.inventories, 3, "three inventories taken")


static func _due(queue: Array[Array]) -> int:
	var due: int = queue[0][0]
	return due


func _check_interpolated_actions() -> void:
	var it: Interpolation = Interpolation.new()
	var s: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	s.pos = Vector2(10, 10)
	s.held = &"bow"
	it.push(30, s)
	s.action = RigData.Anim.BOW
	s.action_tick = 2  # started at tick 31
	it.push(33, s)
	s.action_tick = 5
	it.push(36, s)
	check_eq(it.sample(30.5).action, -1, "before the action started: none")
	var at31: Interpolation.Snap = it.sample(31.0)
	check(at31.action == RigData.Anim.BOW and at31.action_tick == 0, "shown from its start tick (between two states)")
	check_eq(it.sample(34.5).action_tick, 3, "counted on between states")
	check_eq(it.sample(34.5).held, &"bow", "held item from the state")
	var late: Interpolation.Snap = it.sample(31.0 + PlayerSim.action_ticks(RigData.Anim.BOW) + 1)
	check_eq(late.action, -1, "over after its length, with no newer state")


# --- offline main.tscn ---------------------------------------------------------------------

func _check_offline_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var player: Player = main.player
	var data: WorldData = main.world.data
	var herb: Vector2i = _herb_spot(data)
	player.teleport(_feet(herb + Vector2i(-1, 0)))
	player.test_aim = Vector2(16, 0)  # aim at the tile east of the feet: the herb
	await _physics(2)
	check_eq(player.aim_cell, herb, "aiming at the gatherable")
	var id: StringName = WorldItems.gatherable_at(data, herb)
	var before: int = player.inventory.count_of(id)
	_press(&"interact")
	await _physics(2)
	check_eq(player.inventory.count_of(id), before + 1, "F picks it up (%s)" % id)
	check_eq(WorldItems.gatherable_at(data, herb), &"", "gone from the world")
	check(not main.world.items.plants.has(herb), "and from the picture")
	var held: StringName = player.held_id()
	_press(&"debug_drop")
	await _physics(2)
	check(data.drops.size() == 1 and data.drops_at(herb).size() == 1 and data.drops_at(herb)[0].item == held,
		"F7 drops the selected stack on the target tile (%s)" % held)
	check_eq(main.world.items.verify()["mismatches"], 0, "the drop is drawn")
	_press(&"interact")
	await _physics(2)
	check(data.drops.is_empty() and player.held_id() == held, "F picks the drop up again")


func _physics(n: int) -> void:
	for i: int in n:
		await tree.physics_frame


static func _press(action: StringName) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up: InputEventAction = InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)

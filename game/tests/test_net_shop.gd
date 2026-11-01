extends "res://tests/test_net_build.gd"
## M8b: the merchant and his shop in sessions, in one process: the real SessionHost and SessionClient flows on the rig of
## tests/test_net_combat.gd (the host's messages captured and delivered in order, the clients' packets back, an optional
## fixed one-way delay). tests/test_net_market.gd runs real sessions.
##   - the wire (protocol v10): BUY and SELL round trips, sizes, every truncation, every field out of range; the shop stock
##     edit (round trip, refusals, where it may apply); the snapshot's shop (round trip = the same world hash, the merchant's
##     tile, every malformed shop refused; a generated world still hashes to the golden hash)
##   - the host opens with the merchant beside the altar and the world's shop at full stock, straight into the world (no
##     edit); a joiner gets both with its snapshot and draws him
##   - the host against a malicious client: buying without money, out of reach, at a tile that is no merchant, an offer that
##     does not exist, from the dungeon, on another map, while down; selling an empty slot, a slot that does not exist, an
##     item he does not buy; negative and huge counts on a forged frame (one at a time, always); spam beyond the request
##     budget; the decoder refusing an offer or a slot out of range on the wire
##   - flows: the host and a client buy and sell in the same ticks; two clients buy the last holy water in one tick (exactly
##     one gets it, no money lost, nothing doubled) and one sells while the other buys; a late joiner and a player coming
##     back from the dungeon get the merchant and the stock as they are now; a restock reaches every client on the surface;
##     a client carries the altar away and puts it down, and the merchant follows on the host and both clients (he waits
##     while it is carried, a buy at his old tile is refused); a client dies with money and the other picks the bag up;
##     four players with a delay buy, race and sell and agree
##   - a hello of version 9 (an M7-rf build) is refused with `version` and the client ends "refused: version"
##   - traffic: a shop session (README "측정")

## Seed 1: the merchant's tile (the altar (62, 46) + Config.MERCHANT_OFFSET) and tiles around him within
## Config.STATION_REACH_TILES; FAR is three tiles east (out of reach).
const MERCHANT: Vector2i = Vector2i(67, 50)
const WEST: Vector2i = Vector2i(66, 50)
const EAST: Vector2i = Vector2i(68, 50)
const SOUTH: Vector2i = Vector2i(67, 51)
const SOUTH_WEST: Vector2i = Vector2i(66, 51)
const SOUTH_EAST: Vector2i = Vector2i(68, 51)
const FAR: Vector2i = Vector2i(70, 50)
## Where the merchant goes when the altar is put down at test_net_fields.gd's ALTAR_NEW (49, 45): its top-left + (5, 4).
const MERCHANT_MOVED: Vector2i = Vector2i(54, 49)
## Offer indices (Config.SHOP_SELLS order).
const POTION: int = 0
const BUFF: int = 1
const HOLY: int = 2
const TORCH: int = 3
const ORE: int = 4
const SWORD: int = 5


func run() -> Array[String]:
	_check_shop_codec()
	_check_shop_edit_codec()
	_check_snapshot_shop()
	await _check_host_opens()
	await _check_shop_requests()
	await _check_two_at_once()
	await _check_last_item_race()
	await _check_late_and_map_entry()
	await _check_restock()
	await _check_merchant_follows()
	await _check_stale_sell()
	await _check_merchant_clearance()
	_check_bot_bounds()
	await _check_death_bag_money()
	await _check_four_shoppers()
	await _check_version_9_refused()
	await _measure_shop_traffic()
	return failures


# --- helpers -----------------------------------------------------------------------------------------------------------

## A BUY of offer `offer` aimed at the merchant's tile `at` on map `map`.
static func buy_req(offer: int, at: Vector2i = MERCHANT, map: int = Config.MAP_SURFACE) -> NetProtocol.InputFrame:
	return _op(NetProtocol.Op.BUY, map, at, offer)


## A SELL of inventory slot `slot` (`whole`: the whole stack) aimed at the merchant's tile `at`. M8 review: it names what `inv`
## (the sender's inventory as its own machine has it) shows in that slot (NetProtocol.seen_in; no inventory or an empty slot:
## item 0, grade 0).
static func sell_req(slot: int, whole: bool, at: Vector2i = MERCHANT, inv: Inventory = null) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = _op(NetProtocol.Op.SELL, Config.MAP_SURFACE, at, slot)
	f.sell_all = whole
	NetProtocol.seen_in(f, inv.stack_at(slot) if inv != null else null)
	return f


## The open panel's click as a request on an action this tick (Main._shop_request: SessionHost.attach_local_op puts it on
## the frame), for the host's own player or a client.
static func buy_click(offer: int, at: Vector2i = MERCHANT) -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.op = buy_req(offer, at)
	return a


static func sell_click(slot: int, whole: bool, inv: Inventory = null) -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.op = sell_req(slot, whole, MERCHANT, inv)
	return a


static func money_of(m: NetMember) -> int:
	return Shop.money_in(m.player.inventory)


## Every client on the surface holds the host's shop stock (and has a shop).
static func shops_agree(r: Rig) -> bool:
	for c: Client in r.clients:
		if not c.s.active or c.s.local == null or c.s.local.map_id != Config.MAP_SURFACE:
			continue
		if c.surface.data.shop == null or c.surface.data.shop.stock_bytes() != r.surface.data.shop.stock_bytes():
			return false
	return true


## Every client's own inventory = the host's copy of it.
static func inventories_agree(r: Rig) -> bool:
	for c: Client in r.clients:
		if not c.s.active or c.s.local == null:
			continue
		if c.s.local.player.inventory.describe() != hm(r, c).player.inventory.describe():
			return false
	return true


## Shop stock edits in the surface's log from index `from` on.
static func shop_edits_since(r: Rig, from: int) -> int:
	var log: EditLog = r.s.log_for(Config.MAP_SURFACE)
	var n: int = 0
	for i: int in range(from, log.size()):
		if log.edit_at(i).kind == EditLog.Kind.SHOP:
			n += 1
	return n


## The money in every member's inventory on the host (and in every bag or drop on the surface).
static func money_total(r: Rig) -> int:
	var n: int = 0
	for slot: int in r.s.members:
		n += money_of(r.s.members[slot])
	for id: int in r.surface.data.drops:
		var d: WorldData.Drop = r.surface.data.drops[id]
		if d.item == ItemDB.MONEY:
			n += d.count
	return n


## Member `m`'s inventory emptied and filled with `money` money (and the extra stacks [id, count]).
func stock_up(m: NetMember, money: int, extra: Array = []) -> void:
	m.player.inventory.clear()
	if money > 0:
		give(m, ItemDB.MONEY, money)
	for e: Array in extra:
		var id: StringName = e[0]
		var n: int = e[1]
		give(m, id, n)
	m.inventory_dirty = true


# --- the wire (protocol v10) ------------------------------------------------------------------------------------------

func _check_shop_codec() -> void:
	check_eq(NetProtocol.VERSION, 10, "protocol version 10 (M8b: the shop)")
	check_eq([NetProtocol.OP_SIZES[NetProtocol.Op.BUY], NetProtocol.OP_SIZES[NetProtocol.Op.SELL]], [6, 9],
		"BUY 6 B (map, the merchant's tile, the offer), SELL 9 B (+ the whole byte; M8 review: + the item and grade seen)")
	check(NetProtocol.op_has_map(NetProtocol.Op.BUY) and NetProtocol.op_has_map(NetProtocol.Op.SELL), "both name their map")
	var shown: Inventory = Inventory.new()
	shown.add(&"wild_healing", 4, 2)
	var b: NetProtocol.InputFrame = buy_req(HOLY)
	b.seq = 5
	var s1: NetProtocol.InputFrame = sell_req(0, false, MERCHANT, shown)
	s1.seq = 6
	var s2: NetProtocol.InputFrame = sell_req(Config.INVENTORY_SLOTS - 1, true)
	s2.seq = 7
	var frames: Array[NetProtocol.InputFrame] = [b, s1, s2]
	var bytes: PackedByteArray = NetProtocol.encode_inputs(frames)
	check_eq(bytes.size(), NetProtocol.INPUT_HEADER + 3 + 1 + (2 + 6) + (2 + 9) + (2 + 9), "three requests on three frames")
	var p: NetProtocol.InputPacket = NetProtocol.decode_inputs(bytes)
	check(p.ok and p.frames.size() == 3 and p.frames[0].same_request(b) and p.frames[1].same_request(s1)
		and p.frames[2].same_request(s2) and not p.frames[1].sell_all and p.frames[2].sell_all and p.frames[0].slot == HOLY
		and p.frames[0].cell == MERCHANT, "BUY and SELL round trip")
	check(p.ok and p.frames[1].item_index == ItemDB.index_of(&"wild_healing") and p.frames[1].grade == 2
		and NetProtocol.shows(p.frames[1], shown.stack_at(0)), "the SELL names the item and grade its sender showed (M8 review)")
	var other: NetProtocol.InputFrame = sell_req(0, true, MERCHANT, shown)
	check(not other.same_request(s1), "a SELL of the whole stack is another request than a SELL of one")
	var plain: Inventory = Inventory.new()
	plain.add(&"wild_healing", 4, 1)
	check(not sell_req(0, false, MERCHANT, plain).same_request(s1) and not NetProtocol.shows(s1, plain.stack_at(0)),
		"a SELL naming another grade is another request, and does not match that stack")
	var cut: int = 0
	for n: int in range(NetProtocol.INPUT_HEADER + 3 + 1, bytes.size()):
		if not NetProtocol.decode_inputs(bytes.slice(0, n)).ok:
			cut += 1
	check_eq(cut, bytes.size() - (NetProtocol.INPUT_HEADER + 3 + 1), "every truncation refused")
	# One request per packet, its fields out of range: the whole packet is refused.
	var at: int = NetProtocol.INPUT_HEADER + 1 + 1  # frame index, op, map, x, y, ...
	var one_buy: PackedByteArray = NetProtocol.encode_inputs([buy_req(TORCH)] as Array[NetProtocol.InputFrame])
	var one_sell: PackedByteArray = NetProtocol.encode_inputs([sell_req(2, false)] as Array[NetProtocol.InputFrame])
	check(NetProtocol.decode_inputs(one_buy).ok and NetProtocol.decode_inputs(one_sell).ok, "the two single requests decode")
	var bad: Array = [
		[one_buy, at + 7, Shop.offers().size(), "an offer past the last (%d)" % Shop.offers().size()],
		[one_buy, at + 7, 255, "offer 255"],
		[one_buy, at + 2, Config.MAP_COUNT, "an unknown map"],
		[one_sell, at + 7, Config.INVENTORY_SLOTS, "inventory slot %d" % Config.INVENTORY_SLOTS],
		[one_sell, at + 8, 2, "a whole byte of 2"],
		[one_sell, at + 8, 255, "a whole byte of 255"],
		[one_sell, at + 9, ItemDB.count(), "an item index past the last (%d)" % ItemDB.count()],
		[one_sell, at + 10, ItemDB.GRADE_NAMES.size(), "a grade past the last (%d)" % ItemDB.GRADE_NAMES.size()],
	]
	for row: Array in bad:
		var src: PackedByteArray = row[0]
		var w: PackedByteArray = src.duplicate()
		var where: int = row[1]
		var value: int = row[2]
		w[where] = value
		check(not NetProtocol.decode_inputs(w).ok, "refused on the wire: %s" % row[3])
	check(not NetProtocol.decode_inputs(one_buy + PackedByteArray([0])).ok, "a byte after the request refused")
	check_eq(buy_req(HOLY).describe_op(), "buy map=0 at=67,50 offer=2 item=holy_water", "a BUY describes itself")
	var logs: Inventory = Inventory.new()
	logs.add(&"log", 3)
	check_eq(sell_req(0, true, MERCHANT, logs).describe_op(), "sell map=0 at=67,50 slot=0 all saw=log:none", "a SELL too")


func _check_shop_edit_codec() -> void:
	var e: EditLog.WorldEdit = EditLog.WorldEdit.shop_stock(HOLY, 1)
	var wire: PackedByteArray = EditLog.encode_one(e, 7, Config.MAP_SURFACE)
	check_eq(wire.size(), 8, "a shop stock edit is 8 B (index, map, code 0x43, offer, count left)")
	var got: Array = EditLog.decode_one(wire)
	var ge: EditLog.WorldEdit = got[1]
	var gi: int = got[0]
	var gm: int = got[2]
	check(gi == 7 and gm == Config.MAP_SURFACE and ge != null and ge.kind == EditLog.Kind.SHOP and ge.offer == HOLY
		and ge.value == 1, "it round trips")
	check_eq(ge.describe(), "shop holy_water=1", "and describes itself")
	var bad: Array = [[6, Shop.offers().size(), "an offer past the last"], [7, Shop.offer_at(HOLY).cap + 1, "a count above the cap"],
		[6, 255, "offer 255"]]
	for row: Array in bad:
		var w: PackedByteArray = wire.duplicate()
		var where: int = row[0]
		var value: int = row[1]
		w[where] = value
		var d: Array = EditLog.decode_one(w)
		check_eq(d[0], -1, "refused: %s" % row[2])
	var d2: Array = EditLog.decode_one(wire + PackedByteArray([0]))
	var d3: Array = EditLog.decode_one(wire.slice(0, 7))
	var i2: int = d2[0]
	var i3: int = d3[0]
	check(i2 == -1 and i3 == -1, "a byte too many or too few refused")
	var data: WorldData = SurfaceGen.generate(SEED)
	check(not EditLog.apply_to_data(data, e), "a world without a shop takes no shop stock edit")
	data.shop = Shop.new()
	check(EditLog.apply_to_data(data, e) and data.shop.left_at(HOLY) == 1, "a world with one does")
	check(EditLog.apply_to_data(data, e) and data.shop.left_at(HOLY) == 1, "twice: the same (absolute)")
	var over: EditLog.WorldEdit = EditLog.WorldEdit.shop_stock(HOLY, 9)
	var none: EditLog.WorldEdit = EditLog.WorldEdit.shop_stock(-1, 0)
	check(not EditLog.apply_to_data(data, over) and not EditLog.apply_to_data(data, none) and data.shop.left_at(HOLY) == 1,
		"a count above the cap or no such offer does not apply")


func _check_snapshot_shop() -> void:
	var data: WorldData = SurfaceGen.generate(SEED)
	check_eq(data.content_hash(), SurfaceGen.GOLDEN_HASH, "a generated world still hashes to the golden hash (no shop)")
	var plain: PackedByteArray = WorldSnapshot.raw_bytes(data)
	check_eq(plain[plain.size() - 1], 0, "a world without a shop: its snapshot ends with the shop byte 0")
	var back0: WorldData = WorldSnapshot.decode_raw(plain)
	check(back0 != null and back0.shop == null and back0.content_hash() == data.content_hash(), "and comes back without one")
	var plain_hash: String = data.content_hash()
	data.shop = Shop.new()
	check(data.content_hash() != plain_hash, "a shop changes the world hash")
	for e: EditLog.WorldEdit in Merchant.settle_edits(data):
		EditLog.apply_to_data(data, e)
	data.shop.set_left(HOLY, 1)
	var full_hash: String = data.content_hash()
	data.shop.set_left(TORCH, 4)
	check(data.content_hash() != full_hash, "so does a count left")
	var raw: PackedByteArray = WorldSnapshot.raw_bytes(data)
	check_eq(raw.size(), plain.size() + Shop.offers().size(), "the shop adds one byte per offer (%d)" % Shop.offers().size())
	var back: WorldData = WorldSnapshot.decode_raw(raw)
	check(back != null and back.content_hash() == data.content_hash() and back.shop != null
		and back.shop.stock_bytes() == data.shop.stock_bytes() and back.shop.clock == 0 and Merchant.tile_of(back) == MERCHANT,
		"the snapshot carries the stock (not the clock) and the merchant's tile: the same world")
	var shop_at: int = raw.size() - Shop.offers().size() - 1
	var bad: Array = []
	var w1: PackedByteArray = raw.duplicate()
	w1[shop_at] = 5
	bad.append([w1, "an offer count that is neither 0 nor %d" % Shop.offers().size()])
	var w2: PackedByteArray = raw.duplicate()
	w2[shop_at + 1 + HOLY] = Shop.offer_at(HOLY).cap + 1
	bad.append([w2, "a count above its offer's cap"])
	bad.append([raw.slice(0, raw.size() - 1), "one byte short"])
	bad.append([raw + PackedByteArray([0]), "a byte after the shop"])
	bad.append([plain.slice(0, plain.size() - 1), "no shop byte at all (a version 9 snapshot)"])
	for row: Array in bad:
		var bytes: PackedByteArray = row[0]
		check(WorldSnapshot.decode_raw(bytes) == null, "snapshot refused: %s" % row[1])
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(data)
	var rx: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
	for i: int in packed.chunk_count():
		rx.add(packed.chunk(i))
	var got: WorldData = rx.finish(packed.chunk_count(), packed.bytes.size(), packed.packed_md5, packed.raw_size, packed.world_md5)
	check(got != null and got.shop != null and got.shop.left_at(TORCH) == 4, "through the chunks: the joiner's checks pass (%s)" % rx.error)


# --- the host -----------------------------------------------------------------------------------------------------------

func _check_host_opens() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var data: WorldData = r.surface.data
	check(data.shop != null and data.shop.describe() == Shop.new().describe(), "the host's surface has the shop, every offer at its cap")
	check_eq(Merchant.tile_of(data), MERCHANT, "the merchant beside the altar (the offline rule)")
	check_eq(Merchant.tile_of(data), Merchant.spot_for(data, r.host.bodies_on(Config.MAP_SURFACE)), "= Merchant.spot_for")
	check_eq(r.s.log_for(Config.MAP_SURFACE).size(), 0, "put in straight when the host opened: no edit in the log")
	check(r.dungeon.data.shop == null and Merchant.tile_of(r.dungeon.data) == Walls.NO_CELL, "the dungeon has neither")
	check(r.surface.fixtures.merchant_at(MERCHANT) != null, "the host draws him")
	var res: Dictionary = r.host.shop_result()
	var res_at: String = res["merchant"]
	var res_buys: int = res["buys"]
	var res_moves: int = res["merchant_moves"]
	check(res_at == "67,50" and res_buys == 0 and res_moves == 1, "the host's results (%s)" % res)
	var c: Client = _join(r, 101, "miner", feet_in(WEST), false)
	check(c.s.active and c.surface.data.content_hash() == data.content_hash(), "a joiner has the host's world")
	check(c.surface.data.shop != null and c.surface.data.shop.stock_bytes() == data.shop.stock_bytes()
		and Merchant.tile_of(c.surface.data) == MERCHANT, "with the merchant and the shop in its snapshot")
	var drawn: int = c.surface.fixtures.verify().get("merchants", 0)
	check(c.surface.fixtures.merchant_at(MERCHANT) != null and drawn == 1,
		"and draws him once (%s)" % c.surface.fixtures.verify())
	check(Movement.is_blocked(c.surface.data, MERCHANT), "he blocks its walking as on the host")
	_free_rig(r)


## Requests handed straight to run_frame (no wire): the host judges from its own state.
func _check_shop_requests() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var data: WorldData = r.surface.data
	var c: Client = await _join_quiet(r, 101, "miner", feet_in(WEST))
	var m: NetMember = hm(r, c)
	var inv: Inventory = m.player.inventory
	stock_up(m, 0)
	var stock0: PackedByteArray = data.shop.stock_bytes()
	var edits0: int = r.s.log_for(Config.MAP_SURFACE).size()
	refill(m)
	run_one(r, m, buy_req(POTION))
	check(m.refused(Shop.WHY_MONEY) == 1 and inv.free_slots() == inv.size(), "no money: %s, nothing given" % Shop.WHY_MONEY)
	give(m, ItemDB.MONEY, 100)
	m.player.teleport(feet_in(FAR))
	refill(m)
	run_one(r, m, buy_req(POTION))
	check_eq(m.refused(WorldItems.WHY_REACH), 1, "three tiles away: out of reach")
	m.player.teleport(feet_in(WEST))
	refill(m)
	run_one(r, m, buy_req(POTION, Vector2i(60, 50)))
	check_eq(m.refused(Shop.WHY_NO_MERCHANT), 1, "a tile that is no merchant: %s" % Shop.WHY_NO_MERCHANT)
	refill(m)
	run_one(r, m, buy_req(Shop.offers().size()))
	refill(m)
	run_one(r, m, buy_req(-1))
	check_eq(m.refused(Shop.WHY_NOT_SOLD), 2, "an offer that does not exist (past the last, -1): %s" % Shop.WHY_NOT_SOLD)
	give(m, &"sword", 1)
	refill(m)
	run_one(r, m, sell_req(slot_of(inv, &"sword"), false, MERCHANT, inv))
	check_eq(m.refused(Shop.WHY_NOT_BOUGHT), 1, "selling the basic sword: %s" % Shop.WHY_NOT_BOUGHT)
	refill(m)
	run_one(r, m, sell_req(20, false))
	check_eq(m.refused(Shop.WHY_EMPTY), 1, "selling an empty slot (something it does not have): %s" % Shop.WHY_EMPTY)
	refill(m)
	run_one(r, m, sell_req(99, false))
	refill(m)
	run_one(r, m, sell_req(-1, true))
	check_eq(m.refused(WorldItems.WHY_BAD_SLOT), 2, "a slot that does not exist (99, -1): %s" % WorldItems.WHY_BAD_SLOT)
	check(money_of(m) == 100 and data.shop.stock_bytes() == stock0 and r.s.log_for(Config.MAP_SURFACE).size() == edits0,
		"none of it changed the money, the stock or the world")
	# Counts ride nowhere: a forged frame's count is ignored, one at a time.
	var neg: NetProtocol.InputFrame = buy_req(POTION)
	neg.count = -5
	refill(m)
	run_one(r, m, neg)
	var huge: NetProtocol.InputFrame = buy_req(POTION)
	huge.count = 100000
	refill(m)
	run_one(r, m, huge)
	check(inv.count_of(&"potion_healing") == 2 and money_of(m) == 100 - 2 * Shop.price_of(&"potion_healing")
		and data.shop.left_of(&"potion_healing") == Shop.offer_of(&"potion_healing").cap - 2,
		"a BUY with count -5, then 100000: one healing potion each (%s)" % inv.describe())
	give(m, &"stone_a", 30)
	var sell_huge: NetProtocol.InputFrame = sell_req(slot_of(inv, &"stone_a"), false, MERCHANT, inv)
	sell_huge.count = 100000
	refill(m)
	run_one(r, m, sell_huge)
	check_eq(inv.count_of(&"stone_a"), 29, "a SELL of one with count 100000: one stone sold")
	# M8 review: a SELL names what its sender showed in that slot; the host sells only that (a stale click never sells what
	# came into the slot meanwhile).
	var shown_log: Inventory = Inventory.new()
	shown_log.add(&"log", 1)
	var stale: NetProtocol.InputFrame = sell_req(slot_of(inv, &"stone_a"), true)
	NetProtocol.seen_in(stale, shown_log.stack_at(0))
	var money_before: int = money_of(m)
	refill(m)
	run_one(r, m, stale)
	check(m.refused(SessionHost.WHY_SLOT_CHANGED) == 1 and inv.count_of(&"stone_a") == 29 and money_of(m) == money_before,
		"a SELL naming a log in the stones' slot: %s, nothing sold" % SessionHost.WHY_SLOT_CHANGED)
	var graded: NetProtocol.InputFrame = sell_req(slot_of(inv, &"stone_a"), false, MERCHANT, inv)
	graded.grade = ItemDB.GRADE_NAMES.size() - 1
	refill(m)
	run_one(r, m, graded)
	check(m.refused(SessionHost.WHY_SLOT_CHANGED) == 2 and inv.count_of(&"stone_a") == 29,
		"naming the right item at another grade: refused too")
	check_eq(shop_edits_since(r, edits0), 2, "a shop stock edit for each buy, none for the sale or the refusals")
	# From the dungeon, and aimed at another map.
	r.host.move_to_map(m, Config.MAP_DUNGEON)
	refill(m)
	run_one(r, m, buy_req(TORCH, MERCHANT, Config.MAP_DUNGEON))
	check_eq(m.refused(Merchant.WHY_SURFACE), 1, "from the dungeon: %s" % Merchant.WHY_SURFACE)
	refill(m)
	run_one(r, m, buy_req(TORCH, MERCHANT, Config.MAP_SURFACE))
	check_eq(m.refused(WorldItems.WHY_WRONG_MAP), 1, "aimed at the surface from the dungeon: wrong map")
	r.host.move_to_map(m, Config.MAP_SURFACE)
	m.player.teleport(feet_in(WEST))
	# Spam: one budget, ten buys in one go.
	var torches: int = inv.count_of(&"torch")
	var rate: int = m.refused("rate")
	refill(m)
	for i: int in 10:
		run_one(r, m, buy_req(TORCH))
	check(inv.count_of(&"torch") - torches == Config.NET_OP_BURST and m.refused("rate") - rate == 10 - Config.NET_OP_BURST,
		"ten buys at once: %d bought (the burst), the rest rate" % (inv.count_of(&"torch") - torches))
	# PROVISIONAL Config.SHOP_WHILE_CARRYING (on): the altar's carrier still trades (M8a's offline behaviour).
	var before_carry: int = inv.count_of(&"torch")
	m.player.set_carrying_altar(true)
	refill(m)
	run_one(r, m, buy_req(TORCH))
	m.player.set_carrying_altar(false)
	check_eq(inv.count_of(&"torch") - before_carry, 1 if Config.SHOP_WHILE_CARRYING else 0,
		"a carrier's BUY: bought while Config.SHOP_WHILE_CARRYING is on (%s)" % Config.SHOP_WHILE_CARRYING)
	# Down.
	m.player.take_hit(Config.PLAYER_HP_MAX)
	refill(m)
	run_one(r, m, buy_req(TORCH))
	check_eq(m.refused(SessionHost.WHY_DOWN), 1, "down: refused")
	# The wire refuses what no client can send.
	var w: PackedByteArray = NetProtocol.encode_inputs([buy_req(TORCH)] as Array[NetProtocol.InputFrame])
	w[NetProtocol.INPUT_HEADER + 2 + 7] = 200
	check(not NetProtocol.decode_inputs(w).ok, "an offer of 200 never reaches run_frame (the decoder refuses the packet)")
	var rated: int = r.host.shop_refusals.get("rate", 0)
	check(rated == 10 - Config.NET_OP_BURST and r.host.buys == 2 + Config.NET_OP_BURST + (1 if Config.SHOP_WHILE_CARRYING else 0)
		and r.host.sales == 1, "the host counted it all (%s, %d buys, %d sales)" % [r.host.shop_refusals, r.host.buys, r.host.sales])
	# M8 review: run_frame's own refusals of a BUY / SELL (wrong map, down) count among the shop's refusals too.
	var wrong_map: int = r.host.shop_refusals.get(WorldItems.WHY_WRONG_MAP, 0)
	var downed: int = r.host.shop_refusals.get(SessionHost.WHY_DOWN, 0)
	var changed: int = r.host.shop_refusals.get(SessionHost.WHY_SLOT_CHANGED, 0)
	check(wrong_map == 1 and downed == 1 and changed == 2,
		"the shop's refusals hold run_frame's too (wrong map, down) and the slot changes (%s)" % r.host.shop_refusals)
	_free_rig(r)


# --- flows --------------------------------------------------------------------------------------------------------------

## The host and a client buy in the same tick, then sell in the same tick: every inventory as the host has it, the stock the
## same everywhere.
func _check_two_at_once() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var hp: Player = r.s.local.player
	hp.teleport(feet_in(EAST))
	stock_up(r.s.local, 60, [[&"stone_a", 10]])
	var a: Client = _join(r, 101, "miner", feet_in(WEST), false)
	var ma: NetMember = hm(r, a)
	stock_up(ma, 60, [[&"log", 5]])
	_tick(r, 3)
	var edits0: int = r.s.log_for(Config.MAP_SURFACE).size()
	r.action = buy_click(POTION)
	a.action = buy_click(TORCH)
	_tick(r)
	r.action = null
	a.action = null
	_tick(r, 4)
	check(hp.inventory.count_of(&"potion_healing") == 1 and money_of(r.s.local) == 48, "the host bought a healing potion (48 left)")
	check(ma.player.inventory.count_of(&"torch") == 1 and money_of(ma) == 57, "the client bought a torch in the same tick (57 left)")
	var shop: Shop = r.surface.data.shop
	check(shop.left_of(&"potion_healing") == 2 and shop.left_of(&"torch") == 9 and shops_agree(r), "the stock: 2 potions, 9 torches, on both")
	check_eq(shop_edits_since(r, edits0), 2, "two shop stock edits")
	r.action = sell_click(slot_of(hp.inventory, &"stone_a"), true, hp.inventory)
	a.action = sell_click(slot_of(a.s.local.player.inventory, &"log"), false, a.s.local.player.inventory)
	_tick(r)
	r.action = null
	a.action = null
	_tick(r, 4)
	check(money_of(r.s.local) == 58 and hp.inventory.count_of(&"stone_a") == 0, "the host sold its ten stones (58)")
	check(money_of(ma) == 59 and ma.player.inventory.count_of(&"log") == 4, "the client sold a log in the same tick (59)")
	check(inventories_agree(r) and worlds_agree(r) and shops_agree(r), "the client's inventory, world and stock = the host's")
	check_prediction("two at once", a)
	_free_rig(r)


## Two clients buy the last holy water in one tick (the higher slot's packet first): the lower slot gets it, the other is
## refused (sold out) with its money untouched; then one sells while the other buys, in one tick.
func _check_last_item_race() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	r.s.local.player.teleport(feet_in(Vector2i(58, 47)))
	var a: Client = _join(r, 101, "miner", feet_in(WEST), false)
	var b: Client = _join(r, 102, "archer", feet_in(EAST), false)
	var ma: NetMember = hm(r, a)
	var mb: NetMember = hm(r, b)
	check(ma.slot < mb.slot, "the miner has the lower slot (%d, %d)" % [ma.slot, mb.slot])
	stock_up(ma, 100, [[&"stone_a", 5]])
	stock_up(mb, 100)
	r.host.apply_world_edit(EditLog.WorldEdit.shop_stock(HOLY, 1), Config.MAP_SURFACE)
	_tick(r, 3)
	check(a.surface.data.shop.left_at(HOLY) == 1 and b.surface.data.shop.left_at(HOLY) == 1, "both see one holy water left")
	var total: int = money_total(r)
	b.action = buy_click(HOLY)
	a.action = buy_click(HOLY)
	r.clients.reverse()
	_tick(r)
	r.clients.reverse()
	a.action = null
	b.action = null
	_tick(r, 4)
	var price: int = Shop.price_of(&"holy_water")
	check(ma.player.inventory.count_of(&"holy_water") == 1 and money_of(ma) == 100 - price, "the lower slot got it (paid %d)" % price)
	check(mb.player.inventory.count_of(&"holy_water") == 0 and money_of(mb) == 100 and mb.refused(Shop.WHY_SOLD_OUT) == 1,
		"the other: %s, its money untouched" % Shop.WHY_SOLD_OUT)
	check_eq(money_total(r), total - price, "no money lost or made: only the price left")
	check(r.surface.data.shop.left_at(HOLY) == 0 and shops_agree(r), "sold out on the host and both clients")
	check(inventories_agree(r) and worlds_agree(r), "inventories and worlds = the host's")
	# One sells while the other buys.
	b.action = buy_click(TORCH)
	a.action = sell_click(slot_of(a.s.local.player.inventory, &"stone_a"), true, a.s.local.player.inventory)
	_tick(r)
	a.action = null
	b.action = null
	_tick(r, 4)
	check(money_of(ma) == 100 - price + 5 and ma.player.inventory.count_of(&"stone_a") == 0, "the miner sold five stones")
	check(money_of(mb) == 100 - Shop.price_of(&"torch") and mb.player.inventory.count_of(&"torch") == 1
		and r.surface.data.shop.left_of(&"torch") == Shop.offer_of(&"torch").cap - 1, "the archer bought a torch in the same tick")
	check(inventories_agree(r) and worlds_agree(r) and shops_agree(r), "consistent everywhere")
	check_prediction("race / miner", a)
	check_prediction("race / archer", b)
	_free_rig(r)


## A late joiner gets the merchant and the stock as they are now; a client in the dungeon gets no shop edit, and coming
## back up gets the stock as it is then (its map entry's snapshot).
func _check_late_and_map_entry() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var hp: Player = r.s.local.player
	hp.teleport(feet_in(EAST))
	stock_up(r.s.local, 200)
	var a: Client = _join(r, 101, "miner", feet_in(Vector2i(58, 47)), false)
	var ma: NetMember = hm(r, a)
	for offer: int in [POTION, POTION, TORCH, SWORD]:
		press(r, buy_click(offer))
		_tick(r, Config.NET_OP_INTERVAL_TICKS)
	_tick(r, 3)
	var shop: Shop = r.surface.data.shop
	check(shop.left_of(&"potion_healing") == 1 and shop.left_of(&"sword_t1") == 0 and shops_agree(r), "the host bought four things")
	var late: Client = _join(r, 102, "cleric", feet_in(Vector2i(58, 50)), false)
	check(late.s.active and late.surface.data.content_hash() == r.surface.data.content_hash(), "a late joiner has the host's world")
	check(late.surface.data.shop.stock_bytes() == shop.stock_bytes() and Merchant.tile_of(late.surface.data) == MERCHANT
		and late.surface.fixtures.merchant_at(MERCHANT) != null, "with the stock as it is now and the merchant where he stands")
	# The miner goes down to the dungeon; the host buys meanwhile.
	r.host.move_to_map(ma, Config.MAP_DUNGEON)
	tick_until(r, func() -> bool: return a.s.local.map_id == Config.MAP_DUNGEON, 60)
	_tick(r, 3)
	var edits_seen: int = a.s.client.wrong_map_edits
	press(r, buy_click(TORCH))
	_tick(r, Config.NET_OP_INTERVAL_TICKS)
	press(r, buy_click(HOLY))
	_tick(r, 4)
	check(a.s.local.map_id == Config.MAP_DUNGEON and a.s.client.wrong_map_edits == edits_seen and a.s.bad_messages == 0,
		"the miner in the dungeon got no shop edit (they are the surface's)")
	check(late.surface.data.shop.stock_bytes() == shop.stock_bytes(), "the cleric on the surface got both")
	r.host.move_to_map(ma, Config.MAP_SURFACE)
	tick_until(r, func() -> bool: return a.s.local.map_id == Config.MAP_SURFACE, 60)
	_tick(r, 3)
	var back_stock: String = a.surface.data.shop.describe() if a.surface.data.shop != null else "none"
	check(a.surface.data.shop != null and a.surface.data.shop.stock_bytes() == shop.stock_bytes()
		and a.surface.data.content_hash() == r.surface.data.content_hash(), "back on the surface: the stock as it is now (%s)" %
		back_stock)
	check(a.s.bad_messages == 0 and late.s.bad_messages == 0, "no malformed message")
	_free_rig(r)


## The host's clock reaches the restock: one shop stock edit per offer that changed, to every client on the surface.
func _check_restock() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	r.s.local.player.teleport(feet_in(EAST))
	stock_up(r.s.local, 200)
	var a: Client = _join(r, 101, "miner", feet_in(WEST), false)
	var b: Client = _join(r, 102, "archer", feet_in(Vector2i(58, 47)), false)
	for offer: int in [HOLY, HOLY, TORCH]:
		press(r, buy_click(offer))
		_tick(r, Config.NET_OP_INTERVAL_TICKS)
	_tick(r, 3)
	var shop: Shop = r.surface.data.shop
	check(shop.left_of(&"holy_water") == 0 and shops_agree(r), "holy water sold out, a torch gone, on every machine")
	shop.clock = Shop.restock_ticks - 3
	var edits0: int = r.s.log_for(Config.MAP_SURFACE).size()
	_tick(r, 2)
	check(shop.left_of(&"holy_water") == 0 and r.host.restocks == 0, "two ticks before: still sold out")
	_tick(r, 1)
	check(r.host.restocks == 1 and shop.describe() == Shop.new().describe(), "the restock tick: every offer at its cap")
	check_eq(shop_edits_since(r, edits0), 2, "two shop stock edits (holy water and torch: the offers that changed)")
	_tick(r, 3)
	check(shops_agree(r) and worlds_agree(r) and a.surface.data.shop.left_of(&"holy_water") == 2
		and b.surface.data.shop.left_of(&"torch") == Shop.offer_of(&"torch").cap, "both clients see the restock")
	_free_rig(r)


## A client lifts the altar, carries it 13 tiles west and puts it down (the wire: F held, the click): the merchant waits
## while it is carried and then goes beside the new place on the host and both clients; a buy aimed at his old tile is
## refused, one at the new tile goes through.
func _check_merchant_follows() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var data: WorldData = r.surface.data
	r.s.local.player.teleport(feet_in(Vector2i(60, 52)))
	var a: Client = _join(r, 101, "miner", feet_in(Vector2i(63, 50)), false)
	var b: Client = _join(r, 102, "archer", feet_in(Vector2i(58, 50)), false)
	var ma: NetMember = hm(r, a)
	var t: int = bot_run(r, a, "walkto:63,49;aimat:63,48;hold:125;mark:lifted", 400)
	_tick(r, 3)
	check(ma.player.carrying_altar and not data.altar_rect.has_area(), "the miner carries the altar (%d ticks)" % t)
	for w: WorldData in [data, a.surface.data, b.surface.data]:
		check_eq(Merchant.tile_of(w), MERCHANT, "the merchant waits where he stood while it is carried")
	stock_up(ma, 50)
	_tick(r, 2)
	bot_run(r, a, "walkto:50,48;aimat:50,47;wait:6;use:1;wait:10", 600)
	_tick(r, 3)
	check(not ma.player.carrying_altar and data.altar_rect == Rect2i(ALTAR_NEW, Config.ALTAR_FOOTPRINT),
		"the miner put it down at %s" % data.altar_rect)
	check_eq(Merchant.tile_of(data), MERCHANT_MOVED, "the host's merchant went beside the new place (%s)" % Merchant.tile_of(data))
	check_eq(Merchant.tile_of(data), Merchant.spot_for(data, r.host.bodies_on(Config.MAP_SURFACE)), "by the same rule")
	for c: Client in [a, b]:
		var w2: WorldData = c.surface.data
		check(Merchant.tile_of(w2) == MERCHANT_MOVED and w2.get_value(WorldData.Layer.PLACEABLE, MERCHANT) == WorldData.PLACEABLE_NONE
			and c.surface.fixtures.merchant_at(MERCHANT_MOVED) != null and c.surface.fixtures.merchant_at(MERCHANT) == null,
			"peer %d: the merchant at the new tile, drawn there, gone from the old one" % c.peer)
	check(worlds_agree(r), "the clients' worlds = the host's")
	check_eq(r.host.merchant_moves, 2, "he moved twice (the start, the altar put down)")
	# A buy at the old tile is refused; walking next to the new one, it goes through.
	press(r, null, a, buy_click(TORCH, MERCHANT))
	_tick(r, 4)
	check_eq(ma.refused(Shop.WHY_NO_MERCHANT), 1, "a buy aimed at his old tile: %s" % Shop.WHY_NO_MERCHANT)
	bot_run(r, a, "walkto:53,49", 400)
	_tick(r, Config.NET_OP_INTERVAL_TICKS)
	press(r, null, a, buy_click(TORCH, MERCHANT_MOVED))
	_tick(r, 4)
	check(ma.player.inventory.count_of(&"torch") == 1 and a.s.local.player.inventory.count_of(&"torch") == 1 and shops_agree(r),
		"a buy at his new tile: a torch (refusals %s)" % ma.ops_refused)
	check_prediction("merchant follows (the carrier)", a)
	check_prediction("merchant follows (the other client)", b)
	_free_rig(r)


## M8 review: a client with a delay clicks faster than its inventory comes back. It sells its whole stack of stones and buys
## the tier-1 sword at once (on the host the sword takes the slot the stones left), then clicks that slot again while it still
## shows the stones: the SELL names the stones, so the host refuses it (the slot changed) and the sword stays. A SELL that
## names nothing (a slot that looked empty: Main sends none, an old or forged frame) does not sell the sword either.
func _check_stale_sell() -> void:
	var r: Rig = _rig("paladin")
	r.delay = 3
	await await_frames(1)
	r.s.local.player.teleport(feet_in(Vector2i(58, 47)))
	var a: Client = _join(r, 101, "miner", feet_in(WEST), false)
	var ma: NetMember = hm(r, a)
	stock_up(ma, 100, [[&"stone_a", 5]])
	_tick(r, 12)
	var inv: Inventory = a.s.local.player.inventory
	var k: int = slot_of(inv, &"stone_a")
	check(k >= 0 and inventories_agree(r), "the client shows its stones in slot %d, as the host has them" % k)
	press(r, null, a, sell_click(k, true, inv))
	press(r, null, a, buy_click(SWORD))
	var shows_stones: bool = inv.stack_at(k) != null and inv.stack_at(k).id == &"stone_a"
	press(r, null, a, sell_click(k, false, inv))
	_tick(r, 12)
	var host_inv: Inventory = ma.player.inventory
	var want: int = 100 + 5 * Shop.pays_for(&"stone_a") - Shop.price_of(&"sword_t1")
	check(shows_stones and host_inv.stack_at(k) != null and host_inv.stack_at(k).id == &"sword_t1"
		and ma.refused(SessionHost.WHY_SLOT_CHANGED) == 1 and r.host.sales == 1 and money_of(ma) == want,
		"a click on the slot still showing stones: %s, the sword stays (money %d, sales %d)" % [SessionHost.WHY_SLOT_CHANGED,
		money_of(ma), r.host.sales])
	# The reviewer's case: a SELL of the slot that looked empty (item 0, grade 0) one tick after the buy.
	var empty: int = -1
	for i: int in inv.size():
		if inv.stack_at(i) == null and host_inv.stack_at(i) == null:
			empty = i
			break
	press(r, null, a, sell_click(empty, false, inv))
	press(r, null, a, buy_click(ORE))
	press(r, null, a, sell_click(empty, true, Inventory.new()))
	_tick(r, 12)
	check(host_inv.count_of(&"ore_copper") == 1 and host_inv.count_of(&"sword_t1") == 1 and r.host.sales == 1,
		"SELLs naming nothing (slot %d looked empty) never sell the ore just bought there nor anything else (%s)" % [empty,
		host_inv.describe()])
	check(inventories_agree(r) and shops_agree(r), "the client ends with the host's inventory and stock")
	_free_rig(r)


## M8 review (PROVISIONAL README "M8b 상인 막기 여유"): the altar goes down while a client walks toward the tile the merchant would
## take (its feet on the host clear of the tile, its prediction a round trip ahead): he takes a tile Config.BLOCK_CLEARANCE_PX
## away from the client instead, and the client's prediction is never pulled back.
func _check_merchant_clearance() -> void:
	var r: Rig = _rig("paladin")
	r.delay = 4
	await await_frames(1)
	var data: WorldData = r.surface.data
	var home: Rect2i = data.altar_rect
	var hp: NetMember = r.s.local
	hp.player.teleport(feet_in(Vector2i(60, 54)))
	for e: EditLog.WorldEdit in AltarMove.pickup_edits(data):
		r.host.apply_world_edit(e)
	hp.player.set_carrying_altar(true)
	r.host.altar_home = home
	var a: Client = _join(r, 101, "miner", Vector2(905.0, feet_in(MERCHANT_MOVED).y), false)
	var ma: NetMember = hm(r, a)
	_tick(r, 12)
	var walk: NetBot.Action = NetBot.Action.new()
	walk.dir = Vector2i(-1, 0)
	a.action = walk
	var at_placing: Vector2 = Vector2.ZERO
	for t: int in 120:
		_tick(r)
		if at_placing == Vector2.ZERO and ma.player.sim_position.x <= 886.5:
			at_placing = ma.player.sim_position
			r.host._put_altar(hp, Rect2i(ALTAR_NEW, Config.ALTAR_FOOTPRINT), "placed")
	a.action = null
	_tick(r, 20)
	var got: Vector2i = Merchant.tile_of(data)
	check(at_placing != Vector2.ZERO and got != Walls.NO_CELL and got != MERCHANT_MOVED
		and Building.clear_of_others([got] as Array[Vector2i], [at_placing] as Array[Vector2]),
		"the merchant took %s, clear of the walking client (at %s), not %s" % [got, at_placing, MERCHANT_MOVED])
	check_eq(Merchant.spot_refusal(data, MERCHANT_MOVED, [] as Array[Vector2], [] as Array[Vector2], [at_placing] as Array[Vector2]),
		Building.WHY_NEAR, "the preferred tile was too close to the client then")
	check(worlds_agree(r), "the client's world = the host's")
	check_prediction("merchant clearance", a)
	_free_rig(r)


## M8 review: the bot's buy:<n> and sell:<n> stay within the panel (waitstock's rule): a typo is a parse error, not a request
## the decoder refuses (which would stall the client's inputs).
func _check_bot_bounds() -> void:
	check_eq(NetBot.new().parse("buy:1;buy:%d;sell:1;sell:%d,all" % [Shop.offers().size(), Config.INVENTORY_SLOTS]), "",
		"buy:1..%d and sell:1..%d parse" % [Shop.offers().size(), Config.INVENTORY_SLOTS])
	check_ne(NetBot.new().parse("buy:%d" % (Shop.offers().size() + 1)), "", "buy past the last entry: an error")
	check_ne(NetBot.new().parse("sell:%d" % (Config.INVENTORY_SLOTS + 1)), "", "sell past the last slot: an error")
	check_ne(NetBot.new().parse("buy:0"), "", "buy:0: an error")


## ● gameplay-design §2.6: a client dies holding money; half of its money stack falls in the bag (M4a's rule), the other
## client picks the bag up and holds the money; every machine agrees and no money is made or lost.
func _check_death_bag_money() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var f: Vector2 = spot(r)
	var a: Client = _join(r, 101, "herbalist", f, false)
	var b: Client = _join(r, 102, "miner", f + Vector2(16, 0), false)
	var ma: NetMember = hm(r, a)
	var mb: NetMember = hm(r, b)
	stock_up(ma, 101)
	stock_up(mb, 0)
	_tick(r, 3)
	var total: int = money_total(r)
	ma.player.take_hit(Config.PLAYER_HP_MAX)
	_tick(r, 3)
	a.action = holding_f()
	tick_until(r, func() -> bool: return ma.player.vitals.life == Vitals.Life.DEAD, Config.GIVE_UP_HOLD_TICKS + 30)
	a.action = null
	_tick(r, 3)
	var bag: Vector2i = _find_bag(r.surface.data)
	var in_bag: int = 0
	for d: WorldData.Drop in r.surface.data.drops_at(bag):
		if d.item == ItemDB.MONEY:
			in_bag += d.count
	check(ma.player.vitals.life == Vitals.Life.DEAD and in_bag == 51 and money_of(ma) == 50,
		"dead: 51 of its 101 money in the bag at %s (half, rounded up), 50 kept" % bag)
	check(a.s.local.player.inventory.count_of(ItemDB.MONEY) == 50, "the dead client's own inventory says 50")
	check_eq(money_total(r), total, "the bag holds what left the inventory")
	b.action = NetBot.Action.new()
	b.action.mouse = _feet(bag) - Vector2(0, 2)
	b.action.aiming = true
	_tick(r, 2)
	b.action.op = NetProtocol.InputFrame.new()
	b.action.op.op = NetProtocol.Op.PICKUP
	_tick(r, 4)
	b.action = null
	_tick(r, 3)
	check(money_of(mb) == 51 and b.s.local.player.inventory.count_of(ItemDB.MONEY) == 51
		and r.surface.data.get_value(WorldData.Layer.PLACEABLE, bag) == WorldData.PLACEABLE_NONE,
		"the miner picked the bag up: 51 money on the host and in its own inventory")
	check(money_total(r) == total and worlds_agree(r), "no money made or lost; both clients see the bag gone")
	_free_rig(r)


## Four players with a two-tick delay: all buy a torch in one tick, all buy the three healing potions in one tick (the three
## lowest slots get them), the buyers sell them back in one tick; everyone agrees with the host.
func _check_four_shoppers() -> void:
	var r: Rig = _rig("paladin")
	r.delay = 2
	await await_frames(1)
	r.s.local.player.teleport(feet_in(EAST))
	stock_up(r.s.local, 100)
	var spots: Array[Vector2i] = [WEST, SOUTH, SOUTH_WEST]
	var classes: Array[String] = ["miner", "archer", "cleric"]
	for i: int in 3:
		var c: Client = _join(r, 101 + i, classes[i], feet_in(spots[i]), false)
		stock_up(hm(r, c), 100)
	_tick(r, 6)
	var total: int = money_total(r)
	r.action = buy_click(TORCH)
	for c: Client in r.clients:
		c.action = buy_click(TORCH)
	_tick(r)
	_tick(r, 8)
	var torch_price: int = Shop.price_of(&"torch")
	var all_torch: bool = r.s.local.player.inventory.count_of(&"torch") == 1
	for c2: Client in r.clients:
		all_torch = all_torch and hm(r, c2).player.inventory.count_of(&"torch") == 1
	check(all_torch and r.surface.data.shop.left_of(&"torch") == Shop.offer_of(&"torch").cap - 4, "four torches in one tick")
	_tick(r, Config.NET_OP_INTERVAL_TICKS)
	r.action = buy_click(POTION)
	for c3: Client in r.clients:
		c3.action = buy_click(POTION)
	_tick(r)
	_tick(r, 8)
	var got: Array[int] = []
	for slot: int in r.s.slots():
		if r.s.members[slot].player.inventory.count_of(&"potion_healing") == 1:
			got.append(slot)
	var last_slot: int = r.s.slots().back()
	var last: NetMember = r.s.members[last_slot]
	check(got == ([0, 1, 2] as Array[int]) and last.refused(Shop.WHY_SOLD_OUT) == 1, "three potions for four: slots %s got one, the last %s" % [got,
		Shop.WHY_SOLD_OUT])
	_tick(r, Config.NET_OP_INTERVAL_TICKS)
	r.action = sell_click(slot_of(r.s.local.player.inventory, &"potion_healing"), false, r.s.local.player.inventory)
	for c4: Client in r.clients:
		var s: int = slot_of(c4.s.local.player.inventory, &"potion_healing")
		c4.action = sell_click(s if s >= 0 else 0, false, c4.s.local.player.inventory)
	_tick(r)
	_tick(r, 8)
	var pays: int = Shop.pays_for(&"potion_healing")
	var spent: int = 4 * torch_price + 3 * Shop.price_of(&"potion_healing") - 3 * pays
	check_eq(money_total(r), total - spent, "money: %d spent in all (torches, potions, three sold back)" % spent)
	check(inventories_agree(r) and worlds_agree(r) and shops_agree(r), "four players agree with the host (inventories, worlds, stock)")
	for c5: Client in r.clients:
		check_prediction("four shoppers / %s" % c5.s.local.class_id, c5)
	_free_rig(r)


## A hello of version 9 (an M7-rf build, before the shop) is refused with `version`; a client told so ends "refused: version"
## with EXIT_REFUSED (nothing of the world sent).
func _check_version_9_refused() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	r.host.on_hello(160, NetProtocol.encode_hello(NetProtocol.class_index("miner"), 9))
	var to_peer: Array[Array] = r.s.take_for(160)
	var refusal: PackedByteArray = PackedByteArray()
	if to_peer.size() == 1:
		refusal = to_peer[0][2]
	check(to_peer.size() == 1 and str(to_peer[0][1]) == "refused" and NetProtocol.decode_refusal(refusal) == "version"
		and member_of_peer(r, 160) == null and not r.host.streams.has(160), "a version 9 hello: one refusal (version), no member, no world")
	var c: Client = Client.new()
	c.s = CaptureSession.new()
	add_node(c.s)
	c.s.set_physics_process(false)
	c.s.set_process(false)
	c.s.role = NetSession.Role.CLIENT
	c.s.options = CliOptions.new()
	c.s.client = SessionClient.new(c.s)
	var codes: Array[int] = []
	c.s.ended.connect(func(_reason: String, code: int) -> void: codes.append(code))
	c.s.client.on_refused(refusal)
	await await_frames(2)
	check(c.s.over and c.s.end_reason == "refused: version" and codes == ([NetSession.EXIT_REFUSED] as Array[int]),
		"the version 9 client ends cleanly: %s, code %s" % [c.s.end_reason, codes])
	_owned_nodes.erase(c.s)
	c.s.get_parent().remove_child(c.s)
	c.s.free()
	_free_rig(r)


# --- traffic -------------------------------------------------------------------------------------------------------------

## ENet payload bytes to two clients (one process, host -> clients, a one-tick delay): a buy, a sale, a shop session (one
## client buying and selling every 20 ticks for 4 s while the other stands on the surface), a restock.
func _measure_shop_traffic() -> void:
	var r: Rig = _rig("paladin")
	r.delay = 1
	await await_frames(1)
	r.s.local.player.teleport(feet_in(Vector2i(58, 47)))
	var a: Client = _join(r, 101, "miner", feet_in(WEST), false)
	var b: Client = _join(r, 102, "archer", feet_in(Vector2i(58, 50)), false)
	stock_up(hm(r, a), 200, [[&"stone_a", 40]])
	_tick(r, 60)
	var lines: PackedStringArray = []
	var before: Dictionary[String, int] = r.bytes_by_kind.duplicate()
	press(r, null, a, buy_click(TORCH))
	_tick(r, 59)
	var buy_rate: float = _rate_since(r, before, 60, lines, "one buy (1 s window)")
	var buy_bytes: int = 0
	for k: String in r.bytes_by_kind:
		var was: int = before.get(k, 0)
		buy_bytes += r.bytes_by_kind[k] - was
	before = r.bytes_by_kind.duplicate()
	press(r, null, a, sell_click(slot_of(a.s.local.player.inventory, &"stone_a"), false, a.s.local.player.inventory))
	_tick(r, 59)
	var sell_rate: float = _rate_since(r, before, 60, lines, "one sale (1 s window)")
	before = r.bytes_by_kind.duplicate()
	var edits0: int = r.s.log_for(Config.MAP_SURFACE).size()
	for i: int in 12:
		if i % 2 == 0:
			press(r, null, a, buy_click(TORCH if i % 4 == 0 else ORE))
		else:
			press(r, null, a, sell_click(slot_of(a.s.local.player.inventory, &"stone_a"), false, a.s.local.player.inventory))
		_tick(r, 19)
	var session_rate: float = _rate_since(r, before, 12 * 20, lines, "a shop session (6 buys + 6 sales in 4 s)")
	var own: int = 0
	for k2: String in ["edit", "inventory"]:
		var was2: int = before.get(k2, 0)
		own += r.bytes_by_kind.get(k2, 0) - was2
	var own_rate: float = own * float(Config.NET_TICK_RATE) / (12 * 20)
	var edits: int = shop_edits_since(r, edits0)
	before = r.bytes_by_kind.duplicate()
	r.surface.data.shop.clock = Shop.restock_ticks - 1
	_tick(r, 60)
	var restock_rate: float = _rate_since(r, before, 60, lines, "a restock (1 s window)")
	check(edits == 6 and buy_rate < 600.0 and sell_rate < 600.0 and session_rate < 1500.0 and own_rate < 500.0,
		"a shop costs a shop stock edit per buy and the trader's inventory: %d edits, buy %.0f B/s, sale %.0f B/s, session %.0f B/s (own %.0f)" % [
		edits, buy_rate, sell_rate, session_rate, own_rate])
	note("one buy = %d B to two clients (the shop stock edit 8 B each + the buyer's inventory %d B + the state batches its frame's acknowledgement sends)" % [
		buy_bytes, NetProtocol.encode_inventory(hm(r, a).player.inventory, 0).size()])
	note("restock: %.0f B/s for one second (one 8 B edit per offer that changed, to each client on the surface)" % restock_rate)
	check(worlds_agree(r) and shops_agree(r) and inventories_agree(r), "traffic: everything agrees")
	note("M8b traffic, one process, ENet payload bytes host -> two clients: %s" % "; ".join(lines))
	_free_rig(r)

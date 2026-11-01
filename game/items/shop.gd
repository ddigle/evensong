class_name Shop
extends RefCounted
## M8a: the merchant's shop (● gameplay-design §3.0 R11 tier 1 "대체 수단: 상점 또는 기본 수단으로 누구나 얻는다. 성능 상한이 있고
## 지속 공급이 안 된다"; ● R41 the currency is money). One shop for the world (one merchant, one stock: the offline game keeps it,
## core/main.gd; M8b gives it to the host). Rules are pure on an Inventory like items/storage.gd; the stock and its game clock are
## this object's.
##
## Money is the item ItemDB.MONEY (PROVISIONAL Config.STACK_MONEY): the inventory's stacks are the purse (money_in, take_money).
## Buying (buy): an offer of Config.SHOP_SELLS (its price, its stock left); refused when sold out, when the money is short, and
## when the item would not fit once the price is out (tried on a copy of the inventory first: nothing changes unless all of it
## goes through); one at a time. Selling (sell): an inventory stack the merchant buys (Config.SHOP_BUYS); one, or the whole stack
## (as many as the money they fetch fits, the slot they leave counting), all or nothing per count; an item with durability at its
## price times the share left (Config.SHOP_SELL_WORN_SCALED), refused when that comes to nothing. What he buys is gone (it never
## joins his stock). The stock comes back to every offer's cap every Config.SHOP_RESTOCK_TICKS of game time (step(): the shop's
## own tick count, never the wall clock).
## Refusals are Korean lines (the task's words): the log prints them, the panel marks them (ui/shop_panel.gd).
##
## M8b (sessions): the shop is world state, one per world: WorldData.shop of the surface (offline Main and a session host put
## one there; a client's comes with the world snapshot). Its stock travels as bytes (stock_bytes: one per offer, the left
## count, Config.SHOP_SELLS order) in the snapshot and the content hash, and a shop stock edit (net/edit_log.gd) sets one
## offer's (set_left); the clock is the host's only (it is never sent, like a farm's timers). The host decides every buy and
## sale (net/session_host.gd BUY / SELL) with the same rules as offline.

const WHY_MONEY: String = "돈이 모자라다"
const WHY_SOLD_OUT: String = "다 팔렸다"
const WHY_FULL: String = "가방이 찼다"
const WHY_NOT_BOUGHT: String = "상인이 사지 않는 것"
## An item with durability whose price comes to 0 (broken, or nearly); with Config.SHOP_SELL_WORN_SCALED off, any worn one.
const WHY_WORN_OUT: String = "다 닳아 값이 없다"
const WHY_EMPTY: String = "빈 칸"
const WHY_NOT_SOLD: String = "상인이 팔지 않는 것"
## M8b (the host's BUY / SELL): the request's tile is not where the merchant stands on that map (or he stands nowhere).
const WHY_NO_MERCHANT: String = "no merchant there"

## M8b, IMPL test hook: the restock period step() uses (Config.SHOP_RESTOCK_TICKS; a test sets it shorter, --test-shop-restock,
## so a session test sees a restock within its time; the PROVISIONAL value itself is the config's).
static var restock_ticks: int = Config.SHOP_RESTOCK_TICKS


## One thing the merchant sells: the item, its price in money, its stock cap, the grade it comes in.
class Offer:
	extends RefCounted
	var item: StringName
	var price: int
	var cap: int
	var grade: int

	func _init(p_item: StringName, p_price: int, p_cap: int) -> void:
		item = p_item
		price = p_price
		cap = p_cap
		grade = ItemDB.normalize_grade(p_item, Config.SHOP_GRADE)


## What a buy or a sale did: ok, or why not; the item, how many, its grade, the money that changed hands and what is left
## (the offer's stock after a buy, the slot's count after a sale).
class Deal:
	extends RefCounted
	var why: String = ""
	var item: StringName = &""
	var count: int = 0
	var grade: int = 0
	var money: int = 0
	var left: int = 0

	func ok() -> bool:
		return why.is_empty()

	static func refused(reason: String, p_item: StringName = &"") -> Deal:
		var d: Deal = Deal.new()
		d.why = reason
		d.item = p_item
		return d


static var _offers: Array[Offer] = []

## Stock left per offered item (Config.SHOP_SELLS order).
var stock: Dictionary[StringName, int] = {}
## Game ticks since the last restock (or the start), and how many restocks there were.
var clock: int = 0
var restocks: int = 0


func _init() -> void:
	refill()


## Every offer, in Config.SHOP_SELLS order (the panel's).
static func offers() -> Array[Offer]:
	if _offers.is_empty():
		for row: Array in Config.SHOP_SELLS:
			var item: StringName = row[0]
			var price: int = row[1]
			var cap: int = row[2]
			_offers.append(Offer.new(item, price, cap))
	return _offers.duplicate()


## Offer number `index` (the panel's entry), or null.
static func offer_at(index: int) -> Offer:
	var all: Array[Offer] = offers()
	return all[index] if index >= 0 and index < all.size() else null


## The offer of `item`, or null (he does not sell it).
static func offer_of(item: StringName) -> Offer:
	for o: Offer in offers():
		if o.item == item:
			return o
	return null


## What the merchant charges for one `item` (-1: he does not sell it).
static func price_of(item: StringName) -> int:
	var o: Offer = offer_of(item)
	return o.price if o != null else -1


## What the merchant pays for one `item` when new / full (0: he does not buy it).
static func pays_for(item: StringName) -> int:
	return Config.SHOP_BUYS.get(item, 0)


## What the merchant pays for one of `stack` as it is: pays_for(), scaled by the durability left for an item with durability
## (rounded down; Config.SHOP_SELL_WORN_SCALED off: 0 when worn). 0 = he will not buy it.
static func pays_for_stack(stack: ItemStack) -> int:
	if stack == null:
		return 0
	var each: int = pays_for(stack.id)
	var full: int = stack.max_durability()
	if each <= 0 or full <= 0 or not stack.worn():
		return each
	if not Config.SHOP_SELL_WORN_SCALED:
		return 0
	return each * stack.durability / full


## How much money `inv` holds.
static func money_in(inv: Inventory) -> int:
	return inv.count_of(ItemDB.MONEY)


## Takes `amount` money out of `inv` (the caller checked there is enough), from the last money stack first (the hotbar's stay
## longest, like a craft's inputs).
static func take_money(inv: Inventory, amount: int) -> void:
	var need: int = amount
	for slot: int in range(inv.size() - 1, -1, -1):
		if need <= 0:
			break
		var s: ItemStack = inv.stack_at(slot)
		if s != null and s.id == ItemDB.MONEY:
			need -= inv.remove(slot, mini(need, s.count))


## Every stock back at its cap.
func refill() -> void:
	for o: Offer in offers():
		stock[o.item] = o.cap


## Stock left of `item` (0 for anything he does not sell).
func left_of(item: StringName) -> int:
	var n: int = stock.get(item, 0)
	return n


## One game tick: the clock runs on; every Config.SHOP_RESTOCK_TICKS (0 = never; M8b: restock_ticks, the test hook) the stock
## comes back. Returns whether it did.
func step() -> bool:
	if restock_ticks <= 0:
		return false
	clock += 1
	if clock < restock_ticks:
		return false
	clock = 0
	restocks += 1
	refill()
	return true


## Why `inv` may not buy one of offer `index` now ("" = it may): an offer, in stock, the price in hand, room for it once the
## price is out.
func buy_refusal(inv: Inventory, index: int) -> String:
	var o: Offer = offer_at(index)
	if o == null:
		return WHY_NOT_SOLD
	if left_of(o.item) <= 0:
		return WHY_SOLD_OUT
	if money_in(inv) < o.price:
		return WHY_MONEY
	var trial: Inventory = Crafting.copy_of(inv)
	take_money(trial, o.price)
	if trial.room_for(o.item, o.grade) < 1:
		return WHY_FULL
	return ""


## Buys one of offer `index` into `inv`, all or nothing (buy_refusal first): the price leaves, the item comes in (its full
## durability, the shop's grade), the stock goes down by one.
func buy(inv: Inventory, index: int) -> Deal:
	var o: Offer = offer_at(index)
	var why: String = buy_refusal(inv, index)
	if not why.is_empty():
		return Deal.refused(why, o.item if o != null else &"")
	take_money(inv, o.price)
	var missed: int = inv.add(o.item, 1, o.grade)
	assert(missed == 0, "buy_refusal checked the room")
	stock[o.item] = left_of(o.item) - 1
	var d: Deal = Deal.new()
	d.item = o.item
	d.count = 1
	d.grade = o.grade
	d.money = o.price
	d.left = stock[o.item]
	return d


## How many of the stack in `slot` of `inv` a sale of `want` (1, or the whole stack) moves: the most, up to `want`, whose money
## fits (the slot itself counts as room once it is emptied); 0 when not even one does. `each` = the price of one.
static func sellable(inv: Inventory, slot: int, want: int, each: int) -> int:
	var s: ItemStack = inv.stack_at(slot)
	if s == null or each <= 0:
		return 0
	var room: int = inv.room_for(ItemDB.MONEY)
	for k: int in range(mini(want, s.count), 0, -1):
		var fits: int = room + (Config.STACK_MONEY if k == s.count else 0)
		if k * each <= fits:
			return k
	return 0


## Why the stack in `slot` of `inv` may not be sold now (one, or `whole`: "" = it may): an empty slot, an item he does not buy,
## one worth nothing (worn out), not even one sale's money fitting. M8b: a session client marks it at once as a hint (the host
## decides with sell()).
static func sell_refusal(inv: Inventory, slot: int, whole: bool) -> String:
	var s: ItemStack = inv.stack_at(slot)
	if s == null:
		return WHY_EMPTY
	if pays_for(s.id) <= 0:
		return WHY_NOT_BOUGHT
	var each: int = pays_for_stack(s)
	if each <= 0:
		return WHY_WORN_OUT
	if sellable(inv, slot, s.count if whole else 1, each) < 1:
		return WHY_FULL
	return ""


## Sells the stack in `slot` of `inv` to the merchant: one (`whole` false) or as many of it as the money fits (`whole` true).
## Refused, nothing changing, for an empty slot, an item he does not buy, one worth nothing (worn out) and when not even one
## sale's money fits.
func sell(inv: Inventory, slot: int, whole: bool) -> Deal:
	var s: ItemStack = inv.stack_at(slot)
	var why: String = sell_refusal(inv, slot, whole)
	if not why.is_empty():
		return Deal.refused(why, s.id if s != null else &"")
	var each: int = pays_for_stack(s)
	var n: int = sellable(inv, slot, s.count if whole else 1, each)
	var d: Deal = Deal.new()
	d.item = s.id
	d.grade = s.grade
	d.count = n
	d.money = n * each
	inv.remove(slot, n)
	var missed: int = inv.add(ItemDB.MONEY, d.money)
	assert(missed == 0, "sellable checked the room")
	var after: ItemStack = inv.stack_at(slot)
	d.left = after.count if after != null and after.id == d.item else 0
	return d


## One line of the stock, for logs and tests ("item=left/cap ...").
func describe() -> String:
	var parts: PackedStringArray = []
	for o: Offer in offers():
		parts.append("%s=%d/%d" % [o.item, left_of(o.item), o.cap])
	return " ".join(parts)


# --- M8b: the stock as world state (snapshot, content hash, shop stock edits) -----------------------------------------

## The stock as bytes: one per offer, its count left (Config.SHOP_SELLS order; every cap is at most 255, WorldSnapshot checks
## each against its cap). The snapshot and the content hash carry these.
func stock_bytes() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	for o: Offer in offers():
		out.append(clampi(left_of(o.item), 0, 255))
	return out


## Offer `index`'s count left (-1: no such offer).
func left_at(index: int) -> int:
	var o: Offer = offer_at(index)
	return left_of(o.item) if o != null else -1


## Sets offer `index`'s count left to `n` (a shop stock edit). False, nothing changed, for no such offer or a count outside
## 0..its cap.
func set_left(index: int, n: int) -> bool:
	if not valid_left(index, n):
		return false
	stock[offer_at(index).item] = n
	return true


## Whether offer `index` exists and `n` is a count it may have left (0..its cap).
static func valid_left(index: int, n: int) -> bool:
	var o: Offer = offer_at(index)
	return o != null and n >= 0 and n <= o.cap


## A shop holding the stock `bytes` (stock_bytes()'s form; its clock at 0), or null when they are not one: the wrong count,
## or a count above its offer's cap.
static func from_bytes(bytes: PackedByteArray) -> Shop:
	if bytes.size() != offers().size():
		return null
	var s: Shop = Shop.new()
	for i: int in bytes.size():
		if not s.set_left(i, bytes[i]):
			return null
	return s


## The offers whose count left differs between stock bytes `before` and this shop's now (offer indices, ascending): what a
## host sends as shop stock edits after a buy or a restock.
func changed_since(before: PackedByteArray) -> Array[int]:
	var out: Array[int] = []
	var now: PackedByteArray = stock_bytes()
	for i: int in now.size():
		if i >= before.size() or before[i] != now[i]:
			out.append(i)
	return out

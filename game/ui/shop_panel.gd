class_name ShopPanel
extends Node2D
## M8a: the merchant's shop panel (● gameplay-design §3.0 R11 the merchant; PROVISIONAL README "임시값" M8a), drawn in code on the
## HUD's canvas layer (ui/hud.gd) above the open inventory grid, like the chest panel (ui/chest_panel.gd): PLACEHOLDER, no UI
## art, and no text (the HUD has no font: names and refusals are icons, digits and marks; the log prints the Korean lines).
##   - Header: the money icon and how much the player holds, a gold underline.
##   - Buy entries (Config.SHOP_SELLS order, COLUMNS a row): the item in a slot with its stock left (bottom right, always, rust
##     when sold out and the icon dimmed), then a small coin and its price (ivory, rust when the player's money is short). The
##     keyboard's entry has a gold frame.
##   - Sell marks over the inventory grid: a stack the merchant buys shows what one fetches (gold digits, top right of its
##     slot); a stack he does not buy is dimmed.
##   - A refused click flashes the entry or the slot (a red frame, and its reason's mark: a struck coin = not enough money, a
##     struck bag = no room; "sold out" is the rust 0, "not bought" / "worn out" the struck slot) for FLASH_FRAMES.
## Mouse: a click on an entry buys one (buy_requested), a click on an inventory slot sells one, shift-click the whole stack
## (sell_requested); Main does the deal (Shop.buy / sell). Keys (Main): the move keys pick an entry, Enter buys it; Tab, Esc or F
## close it.

signal buy_requested(index: int)
signal sell_requested(slot: int, whole: bool)

## IMPL layout (px): padding, header, gap above the inventory grid's top row (the chest panel's), entries a row, an entry's
## width and the gap between entries, the coin's size, frames a refusal shows.
const PAD: int = 3
const HEADER: int = 18
const GAP_ABOVE: int = 6
const COLUMNS: int = 4
const ENTRY_W: int = 38
const ENTRY_GAP: int = 2
const COIN_SIZE: int = 5
const FLASH_FRAMES: int = 40
const REFUSE: Color = Color8(0xb8, 0x2e, 0x24)
const SHORT: Color = Color8(0xb8, 0x43, 0x2f)
const VEIL: Color = Color(0.102, 0.090, 0.078, 0.62)
const COIN: Array = [".kkk.", "khhhk", "khghk", "khhhk", ".kkk."]
const COIN_COLORS: Dictionary[String, Color] = {"k": Color8(0x1a, 0x17, 0x14), "h": Color8(0xd2, 0xcb, 0xb8),
	"g": Color8(0xf4, 0xc9, 0x5d)}
## A slot's "no room" mark (a small bag, struck) and the strike (rows of "1" = drawn in REFUSE).
const BAG: Array = [".kk.", "kwwk", "kwwk", ".kk."]
const BAG_COLORS: Dictionary[String, Color] = {"k": Color8(0x1a, 0x17, 0x14), "w": Color8(0x8c, 0x58, 0x30)}

var shop: Shop
var inventory: Inventory
## The merchant's tile and map (Main closes the panel when he is gone or out of reach: Merchant.still_at).
var tile: Vector2i = Walls.NO_CELL
var map: int = Config.MAP_SURFACE
## The keyboard's entry.
var selected: int = 0
## The last refusal (Shop.WHY_*) and what it flashes: an entry (>= 0) or an inventory slot (>= 0), frames left.
var refused_why: String = ""
var flash_entry: int = -1
var flash_slot: int = -1
var flash_left: int = 0


func _init() -> void:
	name = &"ShopPanel"
	visible = false


func is_open() -> bool:
	return visible


func open_for(p_shop: Shop, inv: Inventory, p_tile: Vector2i, p_map: int) -> void:
	shop = p_shop
	inventory = inv
	tile = p_tile
	map = p_map
	selected = clampi(selected, 0, maxi(entries() - 1, 0))
	_clear_flash()
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	shop = null
	tile = Walls.NO_CELL
	_clear_flash()


## How many buy entries there are (Shop.offers()).
static func entries() -> int:
	return Shop.offers().size()


static func rows() -> int:
	return ceili(float(entries()) / COLUMNS)


## The panel's rect for a view of `view` px: as wide as the hotbar (+ padding, the chest panel's width), its bottom GAP_ABOVE
## over the inventory grid's top row.
func panel_rect_for(view: Vector2i) -> Rect2i:
	var cols: int = inventory.hotbar_size if inventory != null else Config.HOTBAR_SLOTS
	var inv_size: int = inventory.size() if inventory != null else Config.INVENTORY_SLOTS
	var top_inv: Vector2i = Hud.slot_origin(inv_size - 1, cols, view)
	var w: int = cols * Hud.SLOT + (cols - 1) * Hud.GAP + 2 * PAD
	var h: int = PAD + HEADER + rows() * Hud.SLOT + (rows() - 1) * Hud.GAP + PAD
	var left: int = Hud.slot_origin(0, cols, view).x - PAD
	return Rect2i(left, top_inv.y - GAP_ABOVE - h, w, h)


func panel_rect() -> Rect2i:
	return panel_rect_for(_view())


## Entry `i`'s rect (its slot at the left, the price to its right), COLUMNS a row, top row first.
func entry_rect(i: int) -> Rect2i:
	var p: Rect2i = panel_rect()
	return Rect2i(p.position + Vector2i(PAD + (i % COLUMNS) * (ENTRY_W + ENTRY_GAP), PAD + HEADER + (i / COLUMNS) * (Hud.SLOT + Hud.GAP)),
		Vector2i(ENTRY_W, Hud.SLOT))


## Where entry `i`'s small coin goes (its price's digits follow it, 1 px apart).
func coin_at(i: int) -> Vector2i:
	var r: Rect2i = entry_rect(i)
	return r.position + Vector2i(Hud.SLOT + 2, (Hud.SLOT - COIN_SIZE) / 2)


func header_icon_at() -> Vector2i:
	return panel_rect().position + Vector2i(PAD + 1, PAD + 1)


## The entry at viewport point `point`, or -1.
func entry_at(point: Vector2) -> int:
	for i: int in entries():
		if Rect2(entry_rect(i)).has_point(point):
			return i
	return -1


## The inventory slot at viewport point `point` (the HUD's open grid), or -1.
func inventory_slot_at(point: Vector2) -> int:
	if inventory == null:
		return -1
	for i: int in inventory.size():
		if Rect2(Rect2i(Hud.slot_origin(i, inventory.hotbar_size, _view()), Vector2i(Hud.SLOT, Hud.SLOT))).has_point(point):
			return i
	return -1


## A click at viewport point `point` (`shift` held: a whole stack): an entry asks to buy one, an inventory slot to sell. Returns
## whether it was one of them.
func click_at(point: Vector2, shift: bool = false) -> bool:
	var e: int = entry_at(point)
	if e >= 0:
		selected = e
		buy_requested.emit(e)
		queue_redraw()
		return true
	var s: int = inventory_slot_at(point)
	if s >= 0:
		sell_requested.emit(s, shift)
		return true
	return false


## The keyboard: moves the selected entry by `step` (left / right = 1, up / down = COLUMNS), staying on the entries.
func move_selection(step: int) -> void:
	selected = clampi(selected + step, 0, entries() - 1)
	queue_redraw()


## A refusal to show: `why` (Shop.WHY_*) on entry `entry` (-1 = none) or inventory slot `slot` (-1 = none).
func flash(why: String, entry: int, slot: int) -> void:
	refused_why = why
	flash_entry = entry
	flash_slot = slot
	flash_left = FLASH_FRAMES
	queue_redraw()


func _clear_flash() -> void:
	refused_why = ""
	flash_entry = -1
	flash_slot = -1
	flash_left = 0


func _process(_delta: float) -> void:
	if flash_left > 0:
		flash_left -= 1
		if flash_left == 0:
			_clear_flash()
			queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and click_at(get_local_mouse_position(), mb.shift_pressed):
		get_viewport().set_input_as_handled()


func _view() -> Vector2i:
	return Vector2i(get_viewport_rect().size)


func _draw() -> void:
	if shop == null or inventory == null:
		return
	var p: Rect2i = panel_rect()
	draw_rect(Rect2(p), Hud.FILL)
	_frame(p, Hud.FRAME_DARK)
	_frame(p.grow(-1), Hud.FRAME)
	var icon: Texture2D = ItemIcons.texture_for(ItemDB.MONEY)
	if icon != null:
		draw_texture(icon, Vector2(header_icon_at()))
	var money: int = Shop.money_in(inventory)
	_number(money, header_icon_at() + Vector2i(Hud.SLOT + 2 + 4 * str(money).length() - 2, 11), Hud.DIGIT, true)
	draw_rect(Rect2(p.position.x + PAD, p.position.y + PAD + HEADER - 1, p.size.x - 2 * PAD, 1), Hud.SELECT_INNER)
	var all: Array[Shop.Offer] = Shop.offers()
	for i: int in all.size():
		_entry(i, all[i], money)
	_sell_marks()


## Entry `i` (offer `o`), for a player holding `money`.
func _entry(i: int, o: Shop.Offer, money: int) -> void:
	var r: Rect2i = entry_rect(i)
	var o_slot: Vector2i = r.position
	var sq: Rect2i = Rect2i(o_slot, Vector2i(Hud.SLOT, Hud.SLOT))
	draw_rect(Rect2(sq), Hud.FILL)
	var refused: bool = flash_entry == i and flash_left > 0
	_frame(sq, REFUSE if refused else Hud.FRAME_DARK)
	_frame(sq.grow(-1), Hud.FRAME)
	var tex: Texture2D = ItemIcons.texture_for(o.item)
	if tex != null:
		draw_texture(tex, Vector2(o_slot + Vector2i(1, 1)))
	var left: int = shop.left_of(o.item)
	if left <= 0:
		draw_rect(Rect2(sq.grow(-2)), VEIL)
	_number(left, o_slot + Vector2i(Hud.SLOT - 3, Hud.SLOT - 3), SHORT if left <= 0 else Hud.DIGIT, true)
	var coin: Vector2i = coin_at(i)
	_map(COIN, coin, COIN_COLORS)
	var digits: String = str(o.price)
	_number(o.price, coin + Vector2i(COIN_SIZE + 1 + 4 * digits.length() - 2, COIN_SIZE - 1), Hud.DIGIT if money >= o.price else SHORT,
		false)
	if i == selected:
		_frame(r.grow(1), Hud.SELECT)
	if refused and refused_why == Shop.WHY_MONEY:
		_strike(Rect2i(coin - Vector2i(1, 1), Vector2i(COIN_SIZE + 2, COIN_SIZE + 2)))
	elif refused and refused_why == Shop.WHY_FULL:
		var bag_at: Vector2i = r.end - Vector2i(6, 6)
		_map(BAG, bag_at, BAG_COLORS)
		_strike(Rect2i(bag_at - Vector2i(1, 1), Vector2i(6, 6)))


## Over the open inventory grid: the price one of each stack fetches (gold, top right), the stacks he does not buy dimmed, and a
## refused sale's slot struck in red.
func _sell_marks() -> void:
	var view: Vector2i = _view()
	for slot: int in inventory.size():
		var st: ItemStack = inventory.stack_at(slot)
		var o: Vector2i = Hud.slot_origin(slot, inventory.hotbar_size, view)
		var sq: Rect2i = Rect2i(o, Vector2i(Hud.SLOT, Hud.SLOT))
		if st != null:
			var each: int = Shop.pays_for_stack(st)
			if each > 0:
				_number(each, o + Vector2i(Hud.SLOT - 3, 6), Hud.SELECT, true)
			else:
				draw_rect(Rect2(sq.grow(-1)), VEIL)
		if flash_slot == slot and flash_left > 0:
			_frame(sq, REFUSE)
			_strike(sq.grow(-2))


## A red diagonal from the top-left to the bottom-right of `r`, 1 px.
func _strike(r: Rect2i) -> void:
	var n: int = mini(r.size.x, r.size.y)
	for k: int in n:
		draw_rect(Rect2(Vector2(r.position + Vector2i(k, k)), Vector2.ONE), REFUSE)


func _map(rows_map: Array, at: Vector2i, colors: Dictionary[String, Color]) -> void:
	for y: int in rows_map.size():
		var row: String = rows_map[y]
		for x: int in row.length():
			var ch: String = row[x]
			if colors.has(ch):
				draw_rect(Rect2(Vector2(at + Vector2i(x, y)), Vector2.ONE), colors[ch])


func _frame(r: Rect2i, color: Color) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), color)
	draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), color)
	draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), color)
	draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), color)


## The HUD's right-aligned 3x5 number in `color` (its bottom-right lit pixel at `bottom_right`), with the dark shadow when
## `shadow`.
func _number(n: int, bottom_right: Vector2i, color: Color, shadow: bool) -> void:
	var text: String = str(n)
	var x: int = bottom_right.x - (text.length() * 4 - 1) + 1
	var y: int = bottom_right.y - 5 + 1
	for ch: String in text:
		var digit_rows: Array = Hud.DIGITS[ch.to_int()]
		for pass_i: int in 2:
			if pass_i == 0 and not shadow:
				continue
			var shift: int = 1 if pass_i == 0 else 0
			var c: Color = Hud.FRAME_DARK if pass_i == 0 else color
			for dy: int in 5:
				for dx: int in 3:
					if str(digit_rows[dy])[dx] == "1":
						draw_rect(Rect2(Vector2(x + dx + shift, y + dy + shift), Vector2.ONE), c)
		x += 4

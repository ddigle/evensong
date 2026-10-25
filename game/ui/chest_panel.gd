class_name ChestPanel
extends Node2D
## M7a: the storage chest panel (○ gameplay-design §5 "공유 창고"; PROVISIONAL README "임시값" M7a 공유 창고), drawn in code on the
## HUD's canvas layer (ui/hud.gd) above the open inventory grid: the chest's icon and a gold underline, then its
## Config.CHEST_SLOTS slots in rows of the hotbar's width (the HUD's slot look: icon, count, FINE dot, durability bar).
## PLACEHOLDER (no UI art). Main opens it with F at a chest (items/storage.gd) together with the inventory grid.
##
## Mouse: a click on a chest slot asks to take that stack (take_requested), a click on an inventory slot (the HUD's grid,
## Hud.slot_origin) asks to store it (store_requested); Main moves it (Storage.take / store: as much as fits). Keys (Main):
## Tab, Esc or F close it.

signal store_requested(slot: int)
signal take_requested(slot: int)

## IMPL layout (px): inner padding, the header, the gap above the inventory grid's top row.
const PAD: int = 3
const HEADER: int = 18
const GAP_ABOVE: int = 6

var inventory: Inventory
var chest: WorldData.Chest
## The chest's footprint and map (Main closes the panel when it is gone or out of reach: Storage.still_at).
var rect: Rect2i = Rect2i()
var map: int = Config.MAP_SURFACE


func _init() -> void:
	name = &"ChestPanel"
	visible = false


func is_open() -> bool:
	return visible


func open_for(p_chest: WorldData.Chest, p_rect: Rect2i, p_map: int, inv: Inventory) -> void:
	chest = p_chest
	rect = p_rect
	map = p_map
	inventory = inv
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	chest = null
	rect = Rect2i()


## Columns per row (the hotbar's width).
func columns() -> int:
	return inventory.hotbar_size if inventory != null else Config.HOTBAR_SLOTS


## The panel's rect for a view of `view` px: as wide as the hotbar (+ padding), its bottom GAP_ABOVE over the inventory
## grid's top row.
func panel_rect_for(view: Vector2i) -> Rect2i:
	var cols: int = columns()
	var n: int = chest.slots.size() if chest != null else Config.CHEST_SLOTS
	var rows: int = ceili(float(n) / cols)
	var inv_size: int = inventory.size() if inventory != null else Config.INVENTORY_SLOTS
	var top_inv: Vector2i = Hud.slot_origin(inv_size - 1, cols, view)
	var w: int = cols * Hud.SLOT + (cols - 1) * Hud.GAP + 2 * PAD
	var h: int = PAD + HEADER + rows * Hud.SLOT + (rows - 1) * Hud.GAP + PAD
	var left: int = Hud.slot_origin(0, cols, view).x - PAD
	return Rect2i(left, top_inv.y - GAP_ABOVE - h, w, h)


func panel_rect() -> Rect2i:
	return panel_rect_for(_view())


## Top-left of chest slot `i` (rows of columns(), top row first).
func slot_origin(i: int) -> Vector2i:
	var p: Rect2i = panel_rect()
	var cols: int = columns()
	return p.position + Vector2i(PAD + (i % cols) * (Hud.SLOT + Hud.GAP), PAD + HEADER + (i / cols) * (Hud.SLOT + Hud.GAP))


func header_icon_at() -> Vector2i:
	return panel_rect().position + Vector2i(PAD + 1, PAD + 1)


## The chest slot at viewport point `point`, or -1.
func chest_slot_at(point: Vector2) -> int:
	if chest == null:
		return -1
	for i: int in chest.slots.size():
		if Rect2(Rect2i(slot_origin(i), Vector2i(Hud.SLOT, Hud.SLOT))).has_point(point):
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


## A click at viewport point `point`: a chest slot asks to take it, an inventory slot to store it. Returns whether it
## was one of them.
func click_at(point: Vector2) -> bool:
	var c: int = chest_slot_at(point)
	if c >= 0:
		take_requested.emit(c)
		return true
	var i: int = inventory_slot_at(point)
	if i >= 0:
		store_requested.emit(i)
		return true
	return false


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and click_at(get_local_mouse_position()):
		get_viewport().set_input_as_handled()


func _view() -> Vector2i:
	return Vector2i(get_viewport_rect().size)


func _draw() -> void:
	if chest == null:
		return
	var p: Rect2i = panel_rect()
	draw_rect(Rect2(p), Hud.FILL)
	_frame(p, Hud.FRAME_DARK)
	_frame(p.grow(-1), Hud.FRAME)
	var icon: Texture2D = ItemIcons.texture_for(&"storage_chest")
	if icon != null:
		draw_texture(icon, Vector2(header_icon_at()))
	draw_rect(Rect2(p.position.x + PAD, p.position.y + PAD + HEADER - 1, p.size.x - 2 * PAD, 1), Hud.SELECT_INNER)
	for i: int in chest.slots.size():
		_slot(slot_origin(i), chest.slots[i])


func _slot(o: Vector2i, stack: ItemStack) -> void:
	var r: Rect2i = Rect2i(o, Vector2i(Hud.SLOT, Hud.SLOT))
	draw_rect(Rect2(r), Hud.FILL)
	_frame(r, Hud.FRAME_DARK)
	_frame(r.grow(-1), Hud.FRAME)
	if stack == null:
		return
	var tex: Texture2D = ItemIcons.texture_for(stack.id)
	if tex != null:
		draw_texture(tex, Vector2(o + Vector2i(1, 1)))
	if stack.grade == ItemDB.Grade.FINE:
		draw_rect(Rect2(Vector2(o + Vector2i(2, 2)), Vector2(2, 2)), Hud.FINE_MARK)
	if stack.count > 1:
		_number(stack.count, o + Vector2i(Hud.SLOT - 3, Hud.SLOT - 3))
	if stack.worn():
		Hud.draw_durability(self, o, stack.durability, stack.max_durability())


func _frame(r: Rect2i, color: Color) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), color)
	draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), color)
	draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), color)
	draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), color)


## The HUD's right-aligned 3x5 number with its shadow.
func _number(n: int, bottom_right: Vector2i) -> void:
	var text: String = str(n)
	var x: int = bottom_right.x - (text.length() * 4 - 1) + 1
	var y: int = bottom_right.y - 5 + 1
	for ch: String in text:
		var rows: Array = Hud.DIGITS[ch.to_int()]
		for pass_i: int in 2:
			var shift: int = 1 if pass_i == 0 else 0
			var c: Color = Hud.FRAME_DARK if pass_i == 0 else Hud.DIGIT
			for dy: int in 5:
				for dx: int in 3:
					if str(rows[dy])[dx] == "1":
						draw_rect(Rect2(Vector2(x + dx + shift, y + dy + shift), Vector2.ONE), c)
		x += 4

class_name Hud
extends CanvasLayer
## Minimal HUD (M2a): the hotbar strip at the bottom centre (icons, stack counts, the selected slot)
## and, toggled with Tab, the rest of the inventory as a grid above it (display only). Drawn in code
## on its own canvas layer, so neither the camera nor the evening darkness touch it. No text: counts
## use a 3x5 pixel digit set drawn here (no font dependency). Colours from brief §4 (base and faith
## rows), no cool greys. The sacred-fire UI layer (game-concept §10) is not this; it is 2차.
## Layout values are IMPL.

const SLOT: int = 18                 # slot square, px (16 px icon + 1 px frame)
const GAP: int = 2                   # between slots
const BOTTOM: int = 4                # hotbar distance from the viewport's bottom edge
const ROW_GAP: int = 4               # between the hotbar and the inventory grid
const FILL: Color = Color(0.180, 0.165, 0.149, 0.86)     # #2e2a26 (§4 base), a little see-through
const FRAME: Color = Color8(0x4a, 0x42, 0x3a)            # §4 base
const FRAME_DARK: Color = Color8(0x1a, 0x17, 0x14)       # §4 base (ash black)
const SELECT: Color = Color8(0xf4, 0xc9, 0x5d)           # §4 faith gold
const SELECT_INNER: Color = Color8(0x9c, 0x6a, 0x1f)     # §4 faith
const DIGIT: Color = Color8(0xef, 0xe3, 0xc6)            # §4 faith ivory
const FINE_MARK: Color = Color8(0xf4, 0xc9, 0x5d)        # grade 상급 dot
## 3x5 digits, rows top to bottom, "1" = lit. Plain Arrays (see items/item_icons.gd MAPS).
const DIGITS: Array[Array] = [
	["111", "101", "101", "101", "111"], ["010", "110", "010", "010", "111"], ["111", "001", "111", "100", "111"],
	["111", "001", "011", "001", "111"], ["101", "101", "111", "001", "001"], ["111", "100", "111", "001", "111"],
	["111", "100", "111", "101", "111"], ["111", "001", "010", "010", "010"], ["111", "101", "111", "101", "111"],
	["111", "101", "111", "001", "111"],
]

var inventory: Inventory
## The inventory grid above the hotbar is shown (Tab).
var open: bool = false
var canvas: Node2D


func _init() -> void:
	layer = 10
	name = &"Hud"
	canvas = Node2D.new()
	canvas.name = &"Canvas"
	add_child(canvas)
	canvas.draw.connect(_draw_hud)


func _ready() -> void:
	get_viewport().size_changed.connect(canvas.queue_redraw)


## Shows `inv` (the local player's inventory).
func bind(inv: Inventory) -> void:
	if inventory != null and inventory.changed.is_connected(canvas.queue_redraw):
		inventory.changed.disconnect(canvas.queue_redraw)
	inventory = inv
	if inventory != null:
		inventory.changed.connect(canvas.queue_redraw)
	canvas.queue_redraw()


func set_open(value: bool) -> void:
	open = value
	canvas.queue_redraw()


func toggle_open() -> void:
	set_open(not open)


## Top-left of slot `i` in viewport px for a view of `view` px (hotbar at the bottom centre, the other
## slots in rows of hotbar_size above it, bottom row first).
static func slot_origin(i: int, hotbar: int, view: Vector2i) -> Vector2i:
	var width: int = hotbar * SLOT + (hotbar - 1) * GAP
	var left: int = (view.x - width) / 2
	var bottom: int = view.y - BOTTOM - SLOT
	if i < hotbar:
		return Vector2i(left + i * (SLOT + GAP), bottom)
	var k: int = i - hotbar
	var row: int = k / hotbar
	var col: int = k % hotbar
	return Vector2i(left + col * (SLOT + GAP), bottom - ROW_GAP - SLOT - row * (SLOT + GAP))


func view_size() -> Vector2i:
	return Vector2i(canvas.get_viewport_rect().size)


func _draw_hud() -> void:
	if inventory == null:
		return
	var view: Vector2i = view_size()
	var count: int = inventory.size() if open else inventory.hotbar_size
	for i: int in count:
		var o: Vector2i = slot_origin(i, inventory.hotbar_size, view)
		_draw_slot(o, inventory.stack_at(i), i == inventory.selected)


func _draw_slot(o: Vector2i, stack: ItemStack, selected: bool) -> void:
	var r: Rect2i = Rect2i(o, Vector2i(SLOT, SLOT))
	canvas.draw_rect(Rect2(r), FILL)
	_frame(r, SELECT if selected else FRAME_DARK)
	_frame(r.grow(-1), SELECT_INNER if selected else FRAME)
	if stack == null:
		return
	var tex: Texture2D = ItemIcons.texture_for(stack.id)
	if tex != null:
		canvas.draw_texture(tex, Vector2(o + Vector2i(1, 1)))
	if stack.grade == ItemDB.Grade.FINE:
		canvas.draw_rect(Rect2(Vector2(o + Vector2i(2, 2)), Vector2(2, 2)), FINE_MARK)
	if stack.count > 1:
		_draw_number(stack.count, o + Vector2i(SLOT - 3, SLOT - 3))


## A 1 px frame just inside `r` (whole pixels: four filled strips).
func _frame(r: Rect2i, color: Color) -> void:
	canvas.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), color)
	canvas.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), color)
	canvas.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), color)
	canvas.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), color)


## Draws `n` right-aligned so its bottom-right pixel is at `bottom_right`, with a dark shadow.
func _draw_number(n: int, bottom_right: Vector2i) -> void:
	var text: String = str(n)
	var x: int = bottom_right.x - (text.length() * 4 - 1) + 1
	var y: int = bottom_right.y - 5 + 1
	for ch: String in text:
		var rows: Array = DIGITS[ch.to_int()]
		for dy: int in 5:
			for dx: int in 3:
				if str(rows[dy])[dx] == "1":
					canvas.draw_rect(Rect2(Vector2(x + dx + 1, y + dy + 1), Vector2.ONE), FRAME_DARK)
		for dy: int in 5:
			for dx: int in 3:
				if str(rows[dy])[dx] == "1":
					canvas.draw_rect(Rect2(Vector2(x + dx, y + dy), Vector2.ONE), DIGIT)
		x += 4

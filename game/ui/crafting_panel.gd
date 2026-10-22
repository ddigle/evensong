class_name CraftingPanel
extends Node2D
## M6a: the crafting panel (○ gameplay-design §1 "Tab 인벤토리·제작", §3.5 "작업대 근처에서 Tab"), drawn in code on
## the HUD's canvas layer (ui/hud.gd): the station's icon on top, then one row per recipe the player has
## unlocked (Crafting.shown_recipes): the input (icon, count, the FINE dot) -> the output, and a small mark on
## the herbalist's recipes (● gameplay-design §3.0: gold when this player may brew it, rust when not). Rows
## that cannot be crafted now (Crafting.refusal) are dimmed. The selected row has a gold frame. PLACEHOLDER
## (no UI art exists; the sacred-fire UI, game-concept §10, is 2차). No text: counts are the HUD's 3x5 digits.
## Small for 480x270 at integer scale (● R31): 60 px wide at the top right.
##
## Mouse: hovering a row selects it, a left click crafts it (craft_requested). Keys (Main, PROVISIONAL README
## "M6a 키"): W / S or the arrows move the selection, F or Enter crafts, Tab or Esc closes. Main does the
## craft (Crafting.craft) and calls refresh().

signal craft_requested(index: int)

## IMPL layout (px).
const PAD: int = 3
const HEADER: int = 18
const ROW: int = 18
const ROW_GAP: int = 2
const ARROW_GAP: int = 3
const ARROW_W: int = 5
const MARK_W: int = 3
const WIDTH: int = PAD + Hud.SLOT + ARROW_GAP + ARROW_W + ARROW_GAP + Hud.SLOT + 2 + MARK_W + PAD
const MARGIN: int = 4
const DIM: Color = Color(0.102, 0.090, 0.078, 0.62)      # #1a1714 (§4 base) over a row that cannot be crafted
const ARROW: Array = ["1....", "11...", "111..", "11...", "1...."]
const MARK: Array = ["111", "1.1", "111", "111", "111"]   # the herbalist's pouch, 3x5
const MARK_OK: Color = Color8(0xf4, 0xc9, 0x5d)           # §4 faith gold
const MARK_NO: Color = Color8(0xa3, 0x49, 0x2c)           # rust

var inventory: Inventory
var class_id: String = ""
var station: Crafting.StationAt
var recipes: Array[Crafting.Recipe] = []
var selected: int = 0


func _init() -> void:
	name = &"CraftingPanel"
	visible = false


func is_open() -> bool:
	return visible


## Opens on station `at` for a player of `p_class` with `inv`.
func open_for(at: Crafting.StationAt, inv: Inventory, p_class: String) -> void:
	station = at
	inventory = inv
	class_id = p_class
	selected = 0
	visible = true
	refresh()


func close() -> void:
	visible = false
	station = null


## Re-reads the recipes the player has unlocked (after a craft, a pick-up) and redraws.
func refresh() -> void:
	if station == null or inventory == null:
		recipes.clear()
	else:
		recipes = Crafting.shown_recipes(station.kind, inventory)
	selected = clampi(selected, 0, maxi(recipes.size() - 1, 0))
	queue_redraw()


func move_selection(step: int) -> void:
	if recipes.is_empty():
		return
	selected = posmod(selected + step, recipes.size())
	queue_redraw()


func selected_recipe() -> Crafting.Recipe:
	return recipes[selected] if selected >= 0 and selected < recipes.size() else null


## The panel's rect in viewport px for a view of `view` px and `rows` rows (at least one row of room).
static func panel_rect_for(view: Vector2i, rows: int) -> Rect2i:
	var h: int = PAD + HEADER + maxi(rows, 1) * (ROW + ROW_GAP) - ROW_GAP + PAD
	return Rect2i(view.x - MARGIN - WIDTH, MARGIN, WIDTH, h)


func panel_rect() -> Rect2i:
	return panel_rect_for(_view(), recipes.size())


## Row `i`'s rect (its input slot to its mark).
func row_rect(i: int) -> Rect2i:
	var p: Rect2i = panel_rect()
	return Rect2i(p.position + Vector2i(PAD, PAD + HEADER + i * (ROW + ROW_GAP)), Vector2i(WIDTH - 2 * PAD, ROW))


func input_slot(i: int) -> Vector2i:
	return row_rect(i).position


func output_slot(i: int) -> Vector2i:
	return row_rect(i).position + Vector2i(Hud.SLOT + ARROW_GAP + ARROW_W + ARROW_GAP, 0)


func header_icon_at() -> Vector2i:
	return panel_rect().position + Vector2i(PAD + 1, PAD + 1)


## The row at viewport point `point`, or -1.
func row_at(point: Vector2) -> int:
	for i: int in recipes.size():
		if Rect2(row_rect(i)).has_point(point):
			return i
	return -1


## A click at viewport point `point`: selects the row there and asks to craft it. Returns the row or -1.
func click_at(point: Vector2) -> int:
	var i: int = row_at(point)
	if i >= 0:
		selected = i
		queue_redraw()
		craft_requested.emit(i)
	return i


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var hover: int = row_at(get_local_mouse_position())
		if hover >= 0 and hover != selected:
			selected = hover
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and click_at(get_local_mouse_position()) >= 0:
			get_viewport().set_input_as_handled()


func _view() -> Vector2i:
	return Vector2i(get_viewport_rect().size)


func _draw() -> void:
	if station == null:
		return
	var p: Rect2i = panel_rect()
	draw_rect(Rect2(p), Hud.FILL)
	_frame(p, Hud.FRAME_DARK)
	_frame(p.grow(-1), Hud.FRAME)
	var icon: Texture2D = ItemIcons.texture_for(&"alchemy_table")
	if icon != null:
		draw_texture(icon, Vector2(header_icon_at()))
	draw_rect(Rect2(p.position.x + PAD, p.position.y + PAD + HEADER - 1, p.size.x - 2 * PAD, 1), Hud.SELECT_INNER)
	for i: int in recipes.size():
		var r: Crafting.Recipe = recipes[i]
		var ing: Crafting.Ingredient = r.inputs[0]
		_slot(input_slot(i), ing.item, ing.count, ing.grade)
		_pixels(ARROW, row_rect(i).position + Vector2i(Hud.SLOT + ARROW_GAP, (ROW - 5) / 2), Hud.DIGIT)
		_slot(output_slot(i), r.output, r.out_count, r.out_grade)
		if not r.classes.is_empty():
			_pixels(MARK, output_slot(i) + Vector2i(Hud.SLOT + 2, (ROW - 5) / 2), MARK_OK if r.allows(class_id) else MARK_NO)
		if not Crafting.refusal(r, class_id, inventory).is_empty():
			draw_rect(Rect2(row_rect(i)), DIM)
		if i == selected:
			_frame(row_rect(i).grow(1), Hud.SELECT)


func _slot(o: Vector2i, item: StringName, count: int, grade: int) -> void:
	var r: Rect2i = Rect2i(o, Vector2i(Hud.SLOT, Hud.SLOT))
	draw_rect(Rect2(r), Hud.FILL)
	_frame(r, Hud.FRAME_DARK)
	_frame(r.grow(-1), Hud.FRAME)
	var tex: Texture2D = ItemIcons.texture_for(item)
	if tex != null:
		draw_texture(tex, Vector2(o + Vector2i(1, 1)))
	if grade == ItemDB.Grade.FINE:
		draw_rect(Rect2(Vector2(o + Vector2i(2, 2)), Vector2(2, 2)), Hud.FINE_MARK)
	if count > 1:
		_number(count, o + Vector2i(Hud.SLOT - 3, Hud.SLOT - 3))


## `rows` ("1" = lit) at `at` in `color`.
func _pixels(rows: Array, at: Vector2i, color: Color) -> void:
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] == "1":
				draw_rect(Rect2(Vector2(at + Vector2i(x, y)), Vector2.ONE), color)


func _frame(r: Rect2i, color: Color) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), color)
	draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), color)
	draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), color)
	draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), color)


## The HUD's right-aligned 3x5 number with its shadow (Hud._draw_number).
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

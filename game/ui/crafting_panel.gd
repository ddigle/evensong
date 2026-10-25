class_name CraftingPanel
extends Node2D
## M6a: the crafting panel (○ gameplay-design §1 "Tab 인벤토리·제작", §3.5 "작업대 근처에서 Tab"), drawn in code on
## the HUD's canvas layer (ui/hud.gd): the station's icon on top, then one row per recipe the player has
## unlocked (Crafting.shown_recipes): the input (icon, count, the FINE dot) -> the output, and a small mark on
## the herbalist's recipes (● gameplay-design §3.0: gold when this player may brew it, rust when not). Rows
## that cannot be crafted now (Crafting.refusal) are dimmed. The selected row has a gold frame. PLACEHOLDER
## (no UI art exists; the sacred-fire UI, game-concept §10, is 2차). No text: counts are the HUD's 3x5 digits.
## Small for 480x270 at integer scale (● R31): 60 px wide at the top right.
## M7a: a row shows every input of its recipe (up to three, 1 px apart; the panel is as wide as its widest row needs, so
## the alchemy table's stays 60 px), a repair row shows the worn item and its material -> the item with a full
## durability bar (Hud.draw_durability), the hand panel (Crafting.HAND) is headed by the log, and rows beyond what fits
## the view scroll (the selection stays in view; a 1 px gold notch at the top / bottom edge says more rows are there).
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
## M7a: between two input slots of a row.
const INPUT_GAP: int = 1
## The width with one input a row (M6a's panel).
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
## M7a: the first row in view (rows scroll when more than rows_fit()).
var first: int = 0


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
	first = 0
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
	_keep_in_view()
	queue_redraw()


func move_selection(step: int) -> void:
	if recipes.is_empty():
		return
	selected = posmod(selected + step, recipes.size())
	_keep_in_view()
	queue_redraw()


func selected_recipe() -> Crafting.Recipe:
	return recipes[selected] if selected >= 0 and selected < recipes.size() else null


## M7a: the input slots a row of recipe `r` shows (a repair: the worn item and its material).
static func inputs_shown(r: Crafting.Recipe) -> int:
	return r.inputs.size() + (1 if r.is_repair() else 0)


## M7a: the panel's width for rows of `n` inputs.
static func width_for(n: int) -> int:
	var k: int = maxi(n, 1)
	return WIDTH + (k - 1) * (Hud.SLOT + INPUT_GAP)


## M7a: the most input slots any shown row needs.
func inputs_max() -> int:
	var n: int = 1
	for r: Crafting.Recipe in recipes:
		n = maxi(n, inputs_shown(r))
	return n


## M7a: how many rows fit a view of `view` px.
static func rows_fit(view: Vector2i) -> int:
	return maxi((view.y - 2 * MARGIN - 2 * PAD - HEADER + ROW_GAP) / (ROW + ROW_GAP), 1)


## The panel's rect in viewport px for a view of `view` px and `rows` rows (at least one row of room; M7a: at most
## rows_fit) of `n` inputs.
static func panel_rect_for(view: Vector2i, rows: int, n: int = 1) -> Rect2i:
	var shown: int = clampi(rows, 1, rows_fit(view))
	var h: int = PAD + HEADER + shown * (ROW + ROW_GAP) - ROW_GAP + PAD
	var w: int = width_for(n)
	return Rect2i(view.x - MARGIN - w, MARGIN, w, h)


func panel_rect() -> Rect2i:
	return panel_rect_for(_view(), recipes.size(), inputs_max())


## Whether row `i` is in view (M7a: the rows scroll).
func in_view(i: int) -> bool:
	return i >= first and i < first + rows_fit(_view()) and i < recipes.size()


## Row `i`'s rect (its input slot to its mark), where it is drawn (M7a: counted from the first row in view).
func row_rect(i: int) -> Rect2i:
	var p: Rect2i = panel_rect()
	return Rect2i(p.position + Vector2i(PAD, PAD + HEADER + (i - first) * (ROW + ROW_GAP)), Vector2i(p.size.x - 2 * PAD, ROW))


func input_slot(i: int, j: int = 0) -> Vector2i:
	return row_rect(i).position + Vector2i(j * (Hud.SLOT + INPUT_GAP), 0)


func arrow_at(i: int) -> Vector2i:
	var n: int = inputs_max()
	return row_rect(i).position + Vector2i(n * Hud.SLOT + (n - 1) * INPUT_GAP + ARROW_GAP, (ROW - 5) / 2)


func output_slot(i: int) -> Vector2i:
	return arrow_at(i) + Vector2i(ARROW_W + ARROW_GAP, -(ROW - 5) / 2)


func header_icon_at() -> Vector2i:
	return panel_rect().position + Vector2i(PAD + 1, PAD + 1)


## The row at viewport point `point`, or -1.
func row_at(point: Vector2) -> int:
	for i: int in recipes.size():
		if in_view(i) and Rect2(row_rect(i)).has_point(point):
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


func _keep_in_view() -> void:
	var fit: int = rows_fit(_view())
	first = clampi(first, 0, maxi(recipes.size() - fit, 0))
	if selected < first:
		first = selected
	elif selected >= first + fit:
		first = selected - fit + 1


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
	var icon: Texture2D = ItemIcons.texture_for(Crafting.station_icon(station.kind))  # M6-fix: the station's own
	if icon != null:
		draw_texture(icon, Vector2(header_icon_at()))
	draw_rect(Rect2(p.position.x + PAD, p.position.y + PAD + HEADER - 1, p.size.x - 2 * PAD, 1), Hud.SELECT_INNER)
	for i: int in recipes.size():
		if not in_view(i):
			continue
		var r: Crafting.Recipe = recipes[i]
		if r.is_repair():
			# M7a: the worn item (its bar as it is) and the material -> the item at full durability.
			var worn: ItemStack = Gear.most_worn(inventory, r.repair)
			_slot(input_slot(i, 0), r.repair, 1, ItemDB.Grade.NONE, worn.durability if worn != null else 0)
			_slot(input_slot(i, 1), r.inputs[0].item, r.inputs[0].count, r.inputs[0].grade)
		else:
			for j: int in r.inputs.size():
				var ing: Crafting.Ingredient = r.inputs[j]
				_slot(input_slot(i, j), ing.item, ing.count, ing.grade)
		_pixels(ARROW, arrow_at(i), Hud.DIGIT)
		_slot(output_slot(i), r.output, r.out_count, r.out_grade, Gear.max_durability(r.output) if r.is_repair() else -1)
		if not r.classes.is_empty():
			_pixels(MARK, output_slot(i) + Vector2i(Hud.SLOT + 2, (ROW - 5) / 2), MARK_OK if r.allows(class_id) else MARK_NO)
		if not Crafting.refusal(r, class_id, inventory).is_empty():
			draw_rect(Rect2(row_rect(i)), DIM)
		if i == selected:
			_frame(row_rect(i).grow(1), Hud.SELECT)
	# M7a: more rows above / below the view.
	if first > 0:
		draw_rect(Rect2(p.position.x + p.size.x / 2 - 2, p.position.y + PAD + HEADER, 4, 1), Hud.SELECT)
	if first + rows_fit(_view()) < recipes.size():
		draw_rect(Rect2(p.position.x + p.size.x / 2 - 2, p.end.y - 2, 4, 1), Hud.SELECT)


## A slot at `o` with `item`, its count and grade dot; M7a: `durability` >= 0 draws its bar (Hud.draw_durability) when less
## than full (a repair's output: full, so no bar).
func _slot(o: Vector2i, item: StringName, count: int, grade: int, durability: int = -1) -> void:
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
	if durability >= 0:
		Hud.draw_durability(self, o, durability, Gear.max_durability(item))


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

class_name CollectionPanel
extends Node2D
## M11b: the world's collection panel (game-concept §4; ● §2 the units and scopes; 코덱스·채색 필사본 UI is 2차, so this is a PLACEHOLDER drawn in
## code, no UI art and no text: the HUD has no font), on the HUD's canvas layer like the chest and shop panels. Key K (Main.toggle_collection)
## opens it; the player stands while it is open (Player.ui_locked), K, Tab or Esc close it, going down closes it, a prayer refuses it, and
## the game goes on behind it (no pause).
##   - Header: entries registered / all of them (the HUD's 3x5 digits), a gold underline.
##   - One cell per Config.COLLECTION_ENTRIES row: the creature (CreatureView, its east picture) or the item (ItemIcons) once registered,
##     its dark silhouette until then, and a corner dot for its unit (생물 copper, 자원 ivory, 업적 gold). A "kills" entry has a pip per
##     kill it needs.
##   - One mark per benefit (class, all, world): lit, framed gold, at its count (the digit beside it); dimmed before that.
## What it shows is read from the Collection (the world's); it redraws when that changes.

const PAD: int = 4
const HEADER: int = 14
const COLUMNS: int = 4
const CELL: int = 30
const CELL_GAP: int = 2
const BENEFIT_GAP: int = 3
const BENEFIT_H: int = 20
const MARGIN: int = 4
const DOT: int = 2
const PIP: int = 2
const PIP_GAP: int = 2
const PIPS_A_ROW: int = 5
const SILHOUETTE: Color = Color8(0x3f, 0x37, 0x30)
const CELL_DARK: Color = Color8(0x1a, 0x17, 0x14)
const VEIL: Color = Color(0.102, 0.090, 0.078, 0.72)
const UNIT_COLOURS: Dictionary[String, Color] = {"creature": Color8(0xc0, 0x6a, 0x2e), "resource": Color8(0xef, 0xe3, 0xc6),
	"achievement": Color8(0xf4, 0xc9, 0x5d)}
const SLASH: Array = ["001", "001", "010", "100", "100"]
## The benefits, left to right, and their marks' pictures (ItemIcons.MAPS).
const BENEFITS: Array[StringName] = [&"class", &"all", &"world"]
const BENEFIT_MAPS: Dictionary[StringName, StringName] = {&"class": &"benefit_class", &"all": &"benefit_all", &"world": &"benefit_world"}

static var _pictures: Dictionary[StringName, ImageTexture] = {}
static var _shadows: Dictionary[StringName, ImageTexture] = {}
static var _marks: Dictionary[StringName, ImageTexture] = {}

var collection: Collection
var _seen: int = -1


func _init() -> void:
	name = &"CollectionPanel"
	visible = false


func is_open() -> bool:
	return visible


func open_for(c: Collection) -> void:
	collection = c
	_seen = c.revision
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	collection = null


func _process(_delta: float) -> void:
	if visible and collection != null and collection.revision != _seen:
		_seen = collection.revision
		queue_redraw()


## The picture of an entry's row: the creature's east view, the item's icon, or the tally of a "kills" row.
static func picture_of(row: Dictionary) -> Image:
	var what: StringName = row["what"]
	var how: String = row["how"]
	if how == "kills":
		return ItemIcons.image_from_map(&"tally")
	if how == "item":
		return LightGen.to_rgba8(ItemIcons.texture_for(what).get_image())
	return CreatureView.image(what, 1, 0)


## `img` as a silhouette: every drawn pixel SILHOUETTE.
static func shadow_of(img: Image) -> Image:
	var out: Image = Image.create_empty(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a8 >= 128:
				out.set_pixel(x, y, SILHOUETTE)
	return out


static func picture_texture(row: Dictionary) -> ImageTexture:
	var id: StringName = row["id"]
	if not _pictures.has(id):
		_pictures[id] = ImageTexture.create_from_image(picture_of(row))
	return _pictures[id]


static func shadow_texture(row: Dictionary) -> ImageTexture:
	var id: StringName = row["id"]
	if not _shadows.has(id):
		_shadows[id] = ImageTexture.create_from_image(shadow_of(picture_of(row)))
	return _shadows[id]


static func mark_texture(which: StringName) -> ImageTexture:
	if not _marks.has(which):
		_marks[which] = ImageTexture.create_from_image(ItemIcons.image_from_map(BENEFIT_MAPS[which]))
	return _marks[which]


## How many rows of cells there are.
static func rows() -> int:
	return ceili(float(Collection.total()) / COLUMNS)


## The panel's rect for a view of `view` px: at the top right, like the crafting panel, clear of the player in the view's middle (the
## game goes on behind it).
static func panel_rect_for(view: Vector2i) -> Rect2i:
	var w: int = 2 * PAD + COLUMNS * CELL + (COLUMNS - 1) * CELL_GAP
	var h: int = PAD + HEADER + rows() * CELL + (rows() - 1) * CELL_GAP + BENEFIT_GAP + BENEFIT_H + PAD
	return Rect2i(view.x - w - MARGIN, MARGIN, w, h)


## Cell `i`'s rect (table order, COLUMNS a row, the top row first).
static func cell_rect(i: int, view: Vector2i) -> Rect2i:
	var p: Rect2i = panel_rect_for(view)
	return Rect2i(p.position + Vector2i(PAD + (i % COLUMNS) * (CELL + CELL_GAP), PAD + HEADER + (i / COLUMNS) * (CELL + CELL_GAP)),
		Vector2i(CELL, CELL))


## Where a picture of `size` goes in cell `i`: centred.
static func picture_at(i: int, size: Vector2i, view: Vector2i) -> Vector2i:
	var r: Rect2i = cell_rect(i, view)
	return r.position + (r.size - size) / 2


## Pip `k`'s rect of a "kills" cell `i` (PIPS_A_ROW a row from the cell's bottom left, the first row on top).
static func pip_rect(i: int, k: int, need: int, view: Vector2i) -> Rect2i:
	var r: Rect2i = cell_rect(i, view)
	var row_count: int = ceili(float(need) / PIPS_A_ROW)
	var across: int = PIPS_A_ROW * PIP + (PIPS_A_ROW - 1) * PIP_GAP
	var top: int = r.end.y - 3 - row_count * PIP - (row_count - 1) * PIP_GAP
	return Rect2i(r.position.x + (CELL - across) / 2 + (k % PIPS_A_ROW) * (PIP + PIP_GAP), top + (k / PIPS_A_ROW) * (PIP + PIP_GAP), PIP, PIP)


## Benefit `j`'s rect (three across the panel's inside, under the cells).
static func benefit_rect(j: int, view: Vector2i) -> Rect2i:
	var p: Rect2i = panel_rect_for(view)
	var inside: int = p.size.x - 2 * PAD
	var w: int = (inside - 2 * CELL_GAP) / BENEFITS.size()
	return Rect2i(p.position.x + PAD + j * (w + CELL_GAP), p.end.y - PAD - BENEFIT_H, w, BENEFIT_H)


func _view() -> Vector2i:
	return Vector2i(get_viewport_rect().size)


func _draw() -> void:
	if collection == null:
		return
	var view: Vector2i = _view()
	var p: Rect2i = panel_rect_for(view)
	draw_rect(Rect2(p), Hud.FILL)
	_frame(p, Hud.FRAME_DARK)
	_frame(p.grow(-1), Hud.FRAME)
	_header(p)
	var rows_table: Array = Config.COLLECTION_ENTRIES
	for i: int in rows_table.size():
		var row: Dictionary = rows_table[i]
		_cell(i, row, view)
	for j: int in BENEFITS.size():
		_benefit(j, view)


## "n/8" at the top left, the gold underline.
func _header(p: Rect2i) -> void:
	var at: Vector2i = p.position + Vector2i(PAD + 1, PAD + 2)
	at = _digits(collection.count(), at, Hud.DIGIT)
	_pixels(SLASH, at, Hud.SELECT_INNER)
	_digits(Collection.total(), at + Vector2i(4, 0), Hud.DIGIT)
	draw_rect(Rect2(p.position.x + PAD, p.position.y + PAD + HEADER - 3, p.size.x - 2 * PAD, 1), Hud.SELECT_INNER)


## Cell `i` for `row`.
func _cell(i: int, row: Dictionary, view: Vector2i) -> void:
	var r: Rect2i = cell_rect(i, view)
	var id: StringName = row["id"]
	var done: bool = collection.has(id)
	draw_rect(Rect2(r), Hud.FILL if done else CELL_DARK)
	_frame(r, Hud.SELECT_INNER if done else Hud.FRAME_DARK)
	var tex: ImageTexture = picture_texture(row) if done else shadow_texture(row)
	draw_texture(tex, Vector2(picture_at(i, Vector2i(tex.get_size()), view)))
	var unit: String = row["unit"]
	draw_rect(Rect2(Vector2(r.position + Vector2i(2, 2)), Vector2(DOT, DOT)), UNIT_COLOURS[unit])
	if row["how"] == "kills":
		var need: int = row["count"]
		var have: int = collection.progress_of(id)
		for k: int in need:
			draw_rect(Rect2(pip_rect(i, k, need, view)), Hud.SELECT if k < have else Hud.FRAME)


## Benefit mark `j`: its picture and count, lit and framed gold at its count, veiled before.
func _benefit(j: int, view: Vector2i) -> void:
	var r: Rect2i = benefit_rect(j, view)
	var which: StringName = BENEFITS[j]
	var lit: bool = collection.benefit(which)
	draw_rect(Rect2(r), Hud.FILL if lit else CELL_DARK)
	_frame(r, Hud.SELECT if lit else Hud.FRAME_DARK)
	var at: Vector2i = r.position + Vector2i(2, 2)
	draw_texture(mark_texture(which), Vector2(at))
	if not lit:
		draw_rect(Rect2(Vector2(at), Vector2(16, 16)), VEIL)
	var need: int = Config.COLLECTION_BENEFITS[which]
	_digits(need, r.position + Vector2i(22, 7), Hud.SELECT if lit else Hud.FRAME)


## `n` in the HUD's 3x5 digits in `color`, left to right from `at`. Returns the point after it.
func _digits(n: int, at: Vector2i, color: Color) -> Vector2i:
	var x: Vector2i = at
	for ch: String in str(n):
		var rows_map: Array = Hud.DIGITS[ch.to_int()]
		_pixels(rows_map, x, color)
		x.x += 4
	return x


func _pixels(rows_map: Array, at: Vector2i, color: Color) -> void:
	for y: int in rows_map.size():
		var row: String = rows_map[y]
		for x: int in row.length():
			if row[x] == "1":
				draw_rect(Rect2(Vector2(at + Vector2i(x, y)), Vector2.ONE), color)


func _frame(r: Rect2i, color: Color) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), color)
	draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), color)
	draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), color)
	draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), color)

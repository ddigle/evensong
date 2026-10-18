extends Node2D
## Layered chibi character: base body walk + one signature layer, per-direction draw order,
## per-frame anchor offsets, west = east mirrored, palette swap on the body (res://chars/).
##
## The node position is the point between the feet (frame row y=31 sits just above it).
## Children (built in _init, so setters work before the node enters the tree):
##   Rig (Node2D, scale.x = -1 for west)
##     Body (Sprite2D, palette swap ShaderMaterial), Back, Waist, Float (Sprite2D slots)
## Rig's child order is the draw order and changes with the direction (DRAW_ORDER).
## Draw order uses tree order, not z_index: z_index would also move a layer behind or in
## front of other characters and tiles on the same canvas layer.

const Data := preload("res://chars/char_data.gd")
const PALETTE_SHADER: Shader = preload("res://chars/palette_swap.gdshader")

const SLOT_NODE_NAMES: Dictionary = {
	Data.SLOT_BODY: &"Body", Data.SLOT_BACK: &"Back", Data.SLOT_WAIST: &"Waist", Data.SLOT_FLOAT: &"Float",
}

@export_enum("South", "East", "North", "West") var direction: int = Data.Dir.SOUTH:
	set = set_direction
## "" (none), "pouch", "pickaxe" or "halo" (Data.SIGNATURES).
@export var signature: StringName = &"":
	set = set_signature
## Key of Data.PALETTES ("default" = no swap).
@export var palette: StringName = &"default":
	set = set_palette
@export var walking: bool = true
@export var frame_time: float = Data.FRAME_TIME

var frame: int = 0:
	set = set_frame

var rig: Node2D
var body: Sprite2D
var slots: Dictionary = {}  # StringName slot -> Sprite2D
var body_material: ShaderMaterial

var _time: float = 0.0


func _init() -> void:
	rig = Node2D.new()
	rig.name = &"Rig"
	add_child(rig)
	body = Sprite2D.new()
	body.name = SLOT_NODE_NAMES[Data.SLOT_BODY]
	body.texture = load(Data.BODY_SHEET) as Texture2D
	body.centered = false
	body.hframes = Data.FRAME_COUNT
	body.vframes = 3
	body.position = Vector2(-Data.FRAME_ORIGIN)
	body_material = ShaderMaterial.new()
	body_material.shader = PALETTE_SHADER
	body_material.set_shader_parameter("frame_grid", Vector2(body.hframes, body.vframes))
	body_material.set_shader_parameter("frame_height", float(Data.FRAME_SIZE.y))
	body_material.set_shader_parameter("band", Vector2(Data.TUNIC_BAND))
	body.material = body_material
	rig.add_child(body)
	for slot: StringName in Data.SLOTS:
		var s: Sprite2D = Sprite2D.new()
		s.name = SLOT_NODE_NAMES[slot]
		s.centered = false
		s.visible = false
		rig.add_child(s)
		slots[slot] = s
	_apply_palette()
	_refresh()


func _process(delta: float) -> void:
	if walking:
		advance(delta)


## Moves the walk animation on by `seconds` (also used by tests instead of real time).
func advance(seconds: float) -> void:
	_time += seconds
	var steps: int = 0
	while _time >= frame_time and frame_time > 0.0:
		_time -= frame_time
		steps += 1
	if steps > 0:
		frame = (frame + steps) % Data.FRAME_COUNT


func set_direction(value: int) -> void:
	direction = clampi(value, Data.Dir.SOUTH, Data.Dir.WEST)
	_refresh()


func set_signature(value: StringName) -> void:
	if not value.is_empty() and not Data.SIGNATURES.has(value):
		push_error("unknown signature %s" % value)
		value = &""
	signature = value
	_refresh()


func set_palette(value: StringName) -> void:
	if not Data.PALETTES.has(value):
		push_error("unknown palette %s" % value)
		value = &"default"
	palette = value
	_apply_palette()


func set_frame(value: int) -> void:
	frame = posmod(value, Data.FRAME_COUNT)
	_refresh()


## Rig children in draw order as slot names (first = furthest back), visible layers only.
func draw_order() -> Array[StringName]:
	var out: Array[StringName] = []
	for child: Node in rig.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite != null and sprite.visible:
			out.append(SLOT_NODE_NAMES.find_key(sprite.name) as StringName)
	return out


func _apply_palette() -> void:
	if body_material == null:
		return
	var src: PackedColorArray = Data.source_colors()
	var dst: PackedColorArray = Data.palette_colors(palette)
	body_material.set_shader_parameter("swap_count", dst.size())
	body_material.set_shader_parameter("src_colors", src)
	body_material.set_shader_parameter("dst_colors", dst if not dst.is_empty() else src)


func _refresh() -> void:
	if rig == null:
		return
	var row: int = Data.sheet_row(direction)
	rig.scale = Vector2(-1.0 if Data.is_mirrored(direction) else 1.0, 1.0)
	body.frame = row * Data.FRAME_COUNT + frame
	for slot: StringName in Data.SLOTS:
		(slots[slot] as Sprite2D).visible = false
	if not signature.is_empty():
		var info: Dictionary = Data.SIGNATURES[signature]
		var s: Sprite2D = slots[info["slot"]]
		var tex: Texture2D = load(info["sheet"]) as Texture2D
		if s.texture != tex:
			s.texture = tex
		if info["layout"] == &"columns":
			s.hframes = 3
			s.frame = row
		else:
			s.hframes = 1
			s.frame = 0
		s.position = Vector2(-Data.FRAME_ORIGIN + Data.layer_frame_pos(signature, row, frame))
		s.visible = true
	# Draw order for this direction: move each slot node to its index.
	var order: Array = Data.DRAW_ORDER[row]
	for i: int in order.size():
		var node: Node = body if order[i] == Data.SLOT_BODY else slots[order[i]]
		rig.move_child(node, i)

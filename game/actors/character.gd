class_name Character
extends Node2D
## Layered chibi character (● brief §5.6): the shared base body (walk 6 / idle 4 frames) plus one
## class signature layer (● R21), 4 directions with west = east mirrored (● R19), per-direction draw
## order and per-frame anchors (● R27). Tables: actors/rig_data.gd, actors/rig_anchors.gd.
##
## The node position is the point between the feet (frame row y=31 sits just above it), so a
## y-sorted parent sorts characters by their feet. Children, built in _init:
##   Rig (Node2D, scale.x = -1 facing west)
##     Body (Sprite2D) and the slot sprites Back, Arm, Waist, Float
## Rig's child order is the draw order and changes with the direction. Tree order instead of
## z_index: z_index would also move a layer behind other characters or the ground.
## Every sprite uses light layer Config.LIGHT_LAYER_ACTORS (the hard-edged altar light).
##
## Body actions (M2a, brief §5.6 "슬라이스 몸 동작"): show_action(anim, frame) shows a frame of an
## action sheet instead of walk / idle until end_action(). The caller times it (actors/player.gd, in
## simulation ticks); advance() leaves it alone. A 64 cell action frame sits so its feet row (y=47)
## lands on the same feet as the 32 walk frame (● R26). The other signature layers stay on their
## per-frame anchors; the one the action holds in hand is hidden (● R27, RigData.hides_signature).

const SLOT_NODE_NAMES: Dictionary[StringName, StringName] = {
	RigData.SLOT_BODY: &"Body", RigData.SLOT_BACK: &"Back", RigData.SLOT_ARM: &"Arm",
	RigData.SLOT_WAIST: &"Waist", RigData.SLOT_FLOAT: &"Float",
}

## paladin | miner | archer | cleric | herbalist (Config.CLASSES).
@export var class_id: String = Config.DEFAULT_CLASS:
	set = set_class_id
@export var direction: RigData.Dir = RigData.Dir.SOUTH:
	set = set_direction
## Walk animation when true, idle when false. Changing it restarts the animation at frame 0.
@export var walking: bool = false:
	set = set_walking
## Advance the animation in _process (tests and captures turn this off and set `frame`).
@export var animate: bool = true

var frame: int = 0:
	set = set_frame
var anim: int = RigData.Anim.IDLE
## The body action shown (a RigData action anim), or -1 for walk / idle.
var action: int = -1
var signature: RigData.Signature

var rig: Node2D
var body: Sprite2D
var slots: Dictionary[StringName, Sprite2D] = {}

var _time: float = 0.0


func _init() -> void:
	rig = Node2D.new()
	rig.name = &"Rig"
	rig.light_mask = Config.LIGHT_LAYER_ACTORS
	add_child(rig)
	body = _new_sprite(SLOT_NODE_NAMES[RigData.SLOT_BODY])
	body.position = Vector2(-RigData.FRAME_ORIGIN)
	for slot: StringName in RigData.SLOTS:
		var s: Sprite2D = _new_sprite(SLOT_NODE_NAMES[slot])
		s.visible = false
		slots[slot] = s
	light_mask = Config.LIGHT_LAYER_ACTORS
	set_class_id(class_id)


func _new_sprite(node_name: StringName) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.name = node_name
	s.centered = false
	s.region_enabled = true
	s.light_mask = Config.LIGHT_LAYER_ACTORS
	rig.add_child(s)
	return s


func _process(delta: float) -> void:
	if animate:
		advance(delta)


## Moves the walk / idle animation on by `seconds` (tests call this instead of waiting). Body
## actions are timed by whoever shows them (show_action).
func advance(seconds: float) -> void:
	if action >= 0:
		return
	var step: float = RigData.frame_time(anim)
	_time += seconds
	var steps: int = 0
	while _time >= step:
		_time -= step
		steps += 1
	if steps > 0:
		frame = (frame + steps) % RigData.frame_count(anim)


func set_class_id(value: String) -> void:
	var sig: RigData.Signature = RigData.signature_for(value)
	if sig == null:
		push_error("Character: unknown class '%s'" % value)
		return
	class_id = value
	signature = sig
	_refresh()


func set_direction(value: RigData.Dir) -> void:
	direction = value
	_refresh()


func set_walking(value: bool) -> void:
	walking = value
	if action >= 0:
		return  # the action keeps showing; end_action() picks walk or idle
	var next: int = RigData.Anim.WALK if value else RigData.Anim.IDLE
	if next != anim:
		anim = next
		_time = 0.0
		frame = 0
	_refresh()


func set_frame(value: int) -> void:
	frame = posmod(value, RigData.frame_count(anim))
	_refresh()


## Shows frame `p_frame` (clamped to the action's frames) of body action `p_anim` (a RigData action).
func show_action(p_anim: int, p_frame: int) -> void:
	if not RigData.is_action(p_anim):
		push_error("Character: %d is not a body action" % p_anim)
		return
	action = p_anim
	anim = p_anim
	_time = 0.0
	frame = clampi(p_frame, 0, RigData.frame_count(p_anim) - 1)


## Back to walk / idle (by `walking`) from frame 0. Nothing if no action is shown.
func end_action() -> void:
	if action < 0:
		return
	action = -1
	anim = RigData.Anim.WALK if walking else RigData.Anim.IDLE
	_time = 0.0
	frame = 0


func sheet_row() -> int:
	return RigData.sheet_row(direction)


func signature_sprite() -> Sprite2D:
	return slots[signature.slot] if signature != null else null


## Visible rig layers in draw order (first = furthest back), as slot names.
func draw_order() -> Array[StringName]:
	var out: Array[StringName] = []
	for child: Node in rig.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite != null and sprite.visible:
			out.append(SLOT_NODE_NAMES.find_key(sprite.name))
	return out


func _refresh() -> void:
	if rig == null or signature == null:
		return
	var row: int = RigData.sheet_row(direction)
	rig.scale = Vector2(-1.0 if RigData.is_mirrored(direction) else 1.0, 1.0)
	var sheet: Texture2D = RigData.sheet(anim)
	if body.texture != sheet:
		body.texture = sheet
	body.region_rect = Rect2(RigData.body_rect(row, frame, anim))
	body.position = Vector2(-RigData.FRAME_ORIGIN - RigData.body_offset(anim))
	var held: bool = RigData.hides_signature(signature, anim)
	for slot: StringName in RigData.SLOTS:
		slots[slot].visible = slot == signature.slot and not held
	var s: Sprite2D = slots[signature.slot]
	if s.texture != signature.texture:
		s.texture = signature.texture
	s.region_rect = Rect2(signature.source_rect(row))
	s.position = Vector2(RigData.layer_frame_pos(signature, anim, row, frame) - RigData.FRAME_ORIGIN)
	var order: Array[StringName] = RigData.draw_order(row)
	for i: int in order.size():
		var node: Sprite2D = body if order[i] == RigData.SLOT_BODY else slots[order[i]]
		if node.get_index() != i:
			rig.move_child(node, i)

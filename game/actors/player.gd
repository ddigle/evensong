class_name Player
extends Node2D
## A player in the world: simulation state (feet position, facing) + a Character for the picture.
##
## Offline (main.tscn without --host/--join) the simulation runs in _physics_process (fixed ticks)
## with Movement.step, from the local keys (read_input) when `local_input` is on. In a session
## (net/session.gd) `local_input` is off and the session drives the player: the host steps it with
## apply_input() per input frame (facing derived from the direction, Movement.facing_for), a client
## shows predicted or received states with show_state().
##
## Drawing: the node sits on whole pixels. Every player is drawn between where the last simulation
## tick started (begin_tick, first thing each physics tick) and where it left it, at
## Engine.get_physics_interpolation_fraction(), rounded (draw_position). A player stepped on physics
## ticks (the local player, every player the host simulates, a client's own predicted player) so
## moves in even steps on a monitor faster than 60 Hz instead of 0 / 1 / 2 px jumps; one the tick
## did not move (a host-side player whose frame is late) stands still, and one the tick moved more
## than two steps (a client the host catches up) is drawn where the tick ended. Only `position` follows the
## drawing; `sim_position` (simulation, net state, hashes) is untouched. A player drawn from
## interpolated host states (other players on a client) gets show_state() every frame and is drawn
## where it is. The camera (actors/player_camera.gd) follows the drawn position after this.
##
## Controls (M2a; M2b also in sessions): make_frame() turns one tick of local input (keys, mouse,
## use button) into an input frame and updates the aim (actors/aim.gd: sector, target tile next to
## the feet, facing toward the mouse while aiming, Config.AIM_HOLD_SEC); "use" (left click) with a
## tool selected in the inventory's hotbar puts that tool's body action into the frame, toward the
## target tile. step_frame() runs a frame with the one simulation rule (actors/player_sim.gd):
## actions timed in frames (Config.ACTION_FRAME_TICKS per animation frame), movement locked
## meanwhile, repeated while held (PROVISIONAL values). An action has no world effect yet; it
## reports its target (action_started). Offline, tick_controls() = make_frame() + step_frame() each
## tick. In a session the session builds the local player's frames with make_frame(), the host steps
## every player with step_frame(), and a client shows its predicted and the others' received states
## with show_state(). `controls` (mouse aim, target marker) is on for the local player offline and
## in sessions.

signal action_started(item: StringName, anim: int, target: Vector2i)
signal action_finished(anim: int)
## M3a: the playing action reached Mining.impact_tick() (the pickaxe lands; offline, Main mines then).
signal action_impact(item: StringName, anim: int, target: Vector2i)
## M3a, offline: a frame used a placeable item (the torch) from hotbar slot `slot` on tile `cell`.
signal place_requested(slot: int, cell: Vector2i)

## Longest tick (px) drawn between its ends: two walking steps (2.4 px) and some float slack. One
## frame per tick is one step; more only while the host catches a client up (net/input_gate.gd),
## and such a tick is drawn at its end (update_draw).
const MAX_DRAWN_STEP_PX: float = 2.5 * Config.WALK_SPEED / Config.NET_TICK_RATE

## Read the move_* actions each physics tick. Off for players driven by tests or the session.
@export var local_input: bool = true
## Mouse aim, hotbar use and body actions (offline local player, see the class comment).
@export var controls: bool = false

var inventory: Inventory = Inventory.new()
## Aim (updated each controls tick): the mouse in world px, its sector and target tile, and whether
## the player is aiming (facing the mouse).
var aim_point: Vector2 = Vector2.ZERO
var aim_sector: int = Aim.Sector.SOUTH
var aim_cell: Vector2i = Vector2i.ZERO
var aim_active: bool = false
## Test / screenshot aim: when set, the mouse is this far from the feet and the player always aims.
var test_aim: Variant = null
## Players shown from received states (the other players on a client) hold what the state says;
## every other player holds its inventory's selected stack (held_id()).
var held_from_state: bool = false
var state_held: StringName = &""
## The body action playing (RigData action anim) or -1, ticks since it started, its item and target.
var action_anim: int = -1
var action_tick: int = 0
var action_item: StringName = &""
var action_cell: Vector2i = Vector2i.ZERO
var _mouse_moved_msec: int = -1000000
## make_frame(): the mouse aimed or the use button was held (step_frame() adds "an action plays").
var _aim_input: bool = false

var data: WorldData
## Feet position (float, simulation). `position` is this rounded (or between ticks, see above).
var sim_position: Vector2 = Vector2.ZERO
var facing: int = RigData.Dir.SOUTH
var last_input: Vector2i = Vector2i.ZERO
## Walk animation (input held), idle otherwise.
var walking: bool = false
var character: Character
## Draw between the last two simulation ticks (see the class comment). Off = draw at sim_position.
var smooth_draw: bool = true
## sim_position when the latest tick started: the drawing moves from here to sim_position.
var tick_from: Vector2 = Vector2.ZERO


func _init() -> void:
	process_physics_priority = -1  # begin_tick() before the session steps this player in the same tick
	character = Character.new()
	character.name = &"Character"
	add_child(character)


func setup(p_data: WorldData, class_id: String, feet: Vector2, p_facing: int = RigData.Dir.SOUTH) -> void:
	data = p_data
	character.class_id = class_id
	sim_position = feet
	tick_from = feet
	facing = p_facing
	last_input = Vector2i.ZERO
	walking = false
	action_anim = -1
	action_tick = 0
	_sync_view()


func class_id() -> String:
	return character.class_id


func _physics_process(delta: float) -> void:
	begin_tick()
	if local_input and data != null:
		if controls:
			tick_controls(read_input(), mouse_world(), mouse_aiming(), Input.is_action_just_pressed(&"use_item"),
				Input.is_action_pressed(&"use_item"), delta)
		else:
			apply_input(read_input(), delta)


func _input(event: InputEvent) -> void:
	if controls and event is InputEventMouseMotion:
		_mouse_moved_msec = Time.get_ticks_msec()


## Where the mouse points in the world (the engine's canvas transform: camera and window stretch).
func mouse_world() -> Vector2:
	if test_aim != null:
		var offset: Vector2 = test_aim
		return sim_position + offset
	return get_global_mouse_position()


## True while the mouse moved within Config.AIM_HOLD_SEC (always with a test aim).
func mouse_aiming() -> bool:
	if test_aim != null:
		return true
	return Time.get_ticks_msec() - _mouse_moved_msec < int(Config.AIM_HOLD_SEC * 1000.0)


## One simulation tick of the offline controls: 8-way move input, the mouse in world px, whether the
## mouse aims, use pressed this tick / held. make_frame() + step_frame(): the running action
## advances (and may end), the aim is updated, use may start an action (the selected hotbar item's),
## then the player moves (unless an action locks it) and faces the mouse while aiming or the
## movement otherwise.
func tick_controls(input: Vector2i, mouse: Vector2, aiming: bool, use_pressed: bool, use_held: bool, delta: float) -> void:
	var f: NetProtocol.InputFrame = make_frame(input, mouse, aiming, use_pressed, use_held)
	step_frame(f, delta)
	if f.op == NetProtocol.Op.USE and f.anim < 0:
		place_requested.emit(f.slot, f.cell)


## One tick of local input as an input frame (seq 0: a session numbers it). Updates the aim from the
## mouse; a use (pressed, or held with Config.ACTION_REPEAT_WHILE_HELD) of a tool in the selected
## hotbar slot becomes the frame's USE op when no action will still be playing in that frame. The
## look is the facing toward the mouse while aiming or using, -1 otherwise (facing by movement).
func make_frame(input: Vector2i, mouse: Vector2, aiming: bool, use_pressed: bool, use_held: bool) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, input)
	aim_point = mouse
	var to_mouse: Vector2 = mouse - sim_position
	aim_sector = Aim.sector(to_mouse, aim_sector)
	aim_cell = Aim.target_cell(sim_position, aim_sector)
	var free: bool = not (action_anim >= 0 and action_tick + 1 < action_ticks(action_anim))
	if free and (use_pressed or (use_held and Config.ACTION_REPEAT_WHILE_HELD)):
		var anim: int = WorldItems.use_action(sim_position, inventory, inventory.selected, aim_cell)
		if anim >= 0:
			f.op = NetProtocol.Op.USE
			f.slot = inventory.selected
			f.cell = aim_cell
			f.anim = anim
			f.item = inventory.selected_stack().id
		elif use_pressed and WorldItems.placeable_in(inventory, inventory.selected) != WorldData.PLACEABLE_NONE 				and WorldItems.in_reach(sim_position, aim_cell):
			# M3a: a placeable (the torch) goes down on a click, not repeated while held. A USE without an
			# action: the host (or offline Main) places it; nothing is predicted.
			f.op = NetProtocol.Op.USE
			f.slot = inventory.selected
			f.cell = aim_cell
			f.item = inventory.selected_stack().id
	_aim_input = aiming or use_held
	f.look = Aim.facing(to_mouse, facing) if (_aim_input or f.anim >= 0) else -1
	return f


## Runs one input frame with PlayerSim.step (the frame's `anim` = the use it starts, -1 for none)
## and shows the result. Emits action_finished, then action_started.
func step_frame(frame: NetProtocol.InputFrame, delta: float) -> void:
	last_input = frame.dir
	var before: int = action_anim
	var st: PlayerSim = to_sim()
	var events: int = st.step(data, frame.dir, frame.look, frame.anim, frame.cell, delta)
	load_sim(st)
	if events & PlayerSim.STARTED:
		action_item = frame.item
	aim_active = _aim_input or action_anim >= 0
	_sync_view()
	if events & PlayerSim.ENDED:
		action_finished.emit(before)
	if events & PlayerSim.STARTED:
		action_started.emit(action_item, action_anim, action_cell)
	if action_anim >= 0 and action_tick == Mining.impact_tick():
		action_impact.emit(action_item, action_anim, action_cell)


## The simulation state (a copy).
func to_sim() -> PlayerSim:
	var st: PlayerSim = PlayerSim.new()
	st.pos = sim_position
	st.facing = facing
	st.walking = walking
	st.action = action_anim
	st.action_tick = action_tick
	st.action_cell = action_cell
	return st


## Takes a simulation state (no drawing: step_frame() and show_state() do that).
func load_sim(st: PlayerSim) -> void:
	sim_position = st.pos
	facing = st.facing
	walking = st.walking
	action_anim = st.action
	action_tick = st.action_tick
	action_cell = st.action_cell


## Aiming after a frame stepped elsewhere (a client's prediction): the last make_frame()'s input
## or an action playing.
func refresh_aim() -> void:
	aim_active = _aim_input or action_anim >= 0


## What the player holds: the received state's item for a player shown from states, else its
## selected hotbar stack (&"" for an empty hand).
func held_id() -> StringName:
	if held_from_state:
		return state_held
	var stack: ItemStack = inventory.selected_stack()
	return stack.id if stack != null else &""


## Starts body action `anim` toward the current aim (facing and target fixed until it ends).
func start_action(anim: int, item: StringName = &"") -> void:
	if not RigData.is_action(anim):
		return
	action_anim = anim
	action_tick = 0
	action_item = item
	action_cell = aim_cell
	facing = Aim.facing(aim_point - sim_position, facing)
	walking = false
	_sync_view()
	action_started.emit(item, anim, action_cell)


## Shows body action `anim` frozen at `frame` (-1 = its middle frame) and stops reading input
## (--test-action screenshots). With a test aim the aim and facing follow it first.
func freeze_action(anim: int, frame: int) -> void:
	if not RigData.is_action(anim):
		return
	local_input = false
	if test_aim != null:
		var offset: Vector2 = test_aim
		aim_point = sim_position + offset
		aim_sector = Aim.sector(offset, aim_sector)
		aim_cell = Aim.target_cell(sim_position, aim_sector)
		aim_active = true
		facing = Aim.facing(offset, facing)
	var f: int = frame if frame >= 0 else RigData.frame_count(anim) / 2
	action_anim = anim
	action_tick = clampi(f, 0, RigData.frame_count(anim) - 1) * Config.ACTION_FRAME_TICKS
	action_cell = aim_cell
	walking = false
	_sync_view()


## The frame of the playing action (0 when none).
func action_frame() -> int:
	return action_tick / Config.ACTION_FRAME_TICKS if action_anim >= 0 else 0


## How many simulation ticks body action `anim` lasts.
static func action_ticks(anim: int) -> int:
	return PlayerSim.action_ticks(anim)


func _process(_delta: float) -> void:
	update_draw(Engine.get_physics_interpolation_fraction())


## Start of a simulation tick (every physics tick, before anything steps this player; code that
## drives a player outside the tree calls it itself). Whatever moves the player during the tick is
## drawn from here.
func begin_tick() -> void:
	tick_from = sim_position


## One simulation tick with an 8-way input (-1/0/1 per axis) and nothing else (the M1 frame: no
## look, no use). The facing follows the input (Movement.facing_for).
func apply_input(input: Vector2i, delta: float) -> void:
	step_frame(NetProtocol.InputFrame.new(0, input), delta)


## Shows a state decided elsewhere. `tick` = it is this player's move in the current simulation tick
## (a client's own prediction step): drawn from the tick's start like apply_input. Otherwise (a host
## correction, another player's interpolated state) the drawing keeps its offset to sim_position, so
## a correction moves the whole step and an unchanged state changes nothing.
## `p_action` / `p_action_tick` (M2b): the body action shown (-1 = none) and its frames so far.
func show_state(pos: Vector2, p_facing: int, p_walking: bool, tick: bool = false, p_action: int = -1,
		p_action_tick: int = 0) -> void:
	if not tick:
		tick_from += pos - sim_position
	sim_position = pos
	facing = p_facing
	walking = p_walking
	action_anim = p_action if RigData.is_action(p_action) else -1
	action_tick = p_action_tick if action_anim >= 0 else 0
	_sync_view()


## M3a: moves the player onto another map's data at feet position `feet`, facing south, any action
## stopped (Main.travel).
func set_world(p_data: WorldData, feet: Vector2) -> void:
	data = p_data
	action_anim = -1
	action_tick = 0
	walking = false
	facing = RigData.Dir.SOUTH
	teleport(feet)


## Puts the player at a feet position (spawn, tests). No drawing between the old and new place.
func teleport(feet: Vector2) -> void:
	sim_position = feet
	tick_from = feet
	_sync_view()


## Draws the node at `fraction` (0..1) of the way from tick_from to sim_position, on whole pixels.
## A tick that moved the player further than MAX_DRAWN_STEP_PX (the host applying several of a
## client's frames at once while it catches up) is drawn where it ended: the straight line between
## its ends could cut a corner the steps went around (through the altar, for instance).
func update_draw(fraction: float) -> void:
	if smooth_draw and tick_from.distance_to(sim_position) <= MAX_DRAWN_STEP_PX:
		position = draw_position(tick_from, sim_position, fraction)
	else:
		position = sim_position.round()


## Whole-pixel point `fraction` (clamped to 0..1) of the way from `from` to `to`.
static func draw_position(from: Vector2, to: Vector2, fraction: float) -> Vector2:
	return from.lerp(to, clampf(fraction, 0.0, 1.0)).round()


func _sync_view() -> void:
	position = sim_position.round()
	character.direction = facing as RigData.Dir
	character.walking = walking
	if action_anim >= 0:
		character.show_action(action_anim, action_frame())
	else:
		character.end_action()


## The move_* actions (WASD / arrows) as an 8-way input.
static func read_input() -> Vector2i:
	var x: int = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var y: int = int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	return Vector2i(x, y)

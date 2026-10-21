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
## Controls (M2a, offline only: `controls` on): each tick runs tick_controls() instead of
## apply_input(). The mouse aims (actors/aim.gd: sector, target tile next to the feet, facing toward
## the mouse while aiming, Config.AIM_HOLD_SEC); "use" (left click) with a tool selected in the
## inventory's hotbar plays that tool's body action toward the target tile: timed in simulation
## ticks (Config.ACTION_FRAME_TICKS per frame), movement locked meanwhile, repeated while held
## (PROVISIONAL values). An action has no world effect yet; it reports its target (action_started).
## In a session `controls` stays off (the host does not simulate aim or actions yet), so the session's
## apply_input / show_state path is the M1 one.

signal action_started(item: StringName, anim: int, target: Vector2i)
signal action_finished(anim: int)

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
## The body action playing (RigData action anim) or -1, ticks since it started, its item and target.
var action_anim: int = -1
var action_tick: int = 0
var action_item: StringName = &""
var action_cell: Vector2i = Vector2i.ZERO
var _mouse_moved_msec: int = -1000000

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
## mouse aims, use pressed this tick / held. Order: the running action advances (and may end), the
## aim is updated, use may start an action (the selected hotbar item's), then the player moves
## (unless an action locks it) and faces the mouse while aiming or the movement otherwise.
func tick_controls(input: Vector2i, mouse: Vector2, aiming: bool, use_pressed: bool, use_held: bool, delta: float) -> void:
	last_input = input
	if action_anim >= 0:
		_advance_action()
	aim_point = mouse
	var to_mouse: Vector2 = mouse - sim_position
	aim_sector = Aim.sector(to_mouse, aim_sector)
	aim_cell = Aim.target_cell(sim_position, aim_sector)
	aim_active = aiming or use_held or action_anim >= 0
	if action_anim < 0 and (use_pressed or (use_held and Config.ACTION_REPEAT_WHILE_HELD)):
		var anim: int = inventory.selected_action()
		if anim >= 0:
			var stack: ItemStack = inventory.selected_stack()
			start_action(anim, stack.id)
	var acting: bool = action_anim >= 0
	if not acting or not Config.ACTION_LOCKS_MOVEMENT:
		sim_position = Movement.step(data, sim_position, input, delta)
	if acting:
		walking = input != Vector2i.ZERO and not Config.ACTION_LOCKS_MOVEMENT
	else:
		facing = Aim.facing(to_mouse, facing) if aim_active else Movement.facing_for(input, facing)
		walking = input != Vector2i.ZERO
	_sync_view()


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


## Ticks one action: frame = ticks / ACTION_FRAME_TICKS; after the last frame it ends.
func _advance_action() -> void:
	action_tick += 1
	if action_tick >= action_ticks(action_anim):
		var done: int = action_anim
		action_anim = -1
		action_tick = 0
		_sync_view()
		action_finished.emit(done)


## The frame of the playing action (0 when none).
func action_frame() -> int:
	return action_tick / Config.ACTION_FRAME_TICKS if action_anim >= 0 else 0


## How many simulation ticks body action `anim` lasts.
static func action_ticks(anim: int) -> int:
	return RigData.frame_count(anim) * Config.ACTION_FRAME_TICKS


func _process(_delta: float) -> void:
	update_draw(Engine.get_physics_interpolation_fraction())


## Start of a simulation tick (every physics tick, before anything steps this player; code that
## drives a player outside the tree calls it itself). Whatever moves the player during the tick is
## drawn from here.
func begin_tick() -> void:
	tick_from = sim_position


## One simulation tick with an 8-way input (-1/0/1 per axis). The facing follows the input
## (Movement.facing_for): the host derives a client's facing this way too, the client predicts it.
func apply_input(input: Vector2i, delta: float) -> void:
	last_input = input
	sim_position = Movement.step(data, sim_position, input, delta)
	facing = Movement.facing_for(input, facing)
	walking = input != Vector2i.ZERO
	_sync_view()


## Shows a state decided elsewhere. `tick` = it is this player's move in the current simulation tick
## (a client's own prediction step): drawn from the tick's start like apply_input. Otherwise (a host
## correction, another player's interpolated state) the drawing keeps its offset to sim_position, so
## a correction moves the whole step and an unchanged state changes nothing.
func show_state(pos: Vector2, p_facing: int, p_walking: bool, tick: bool = false) -> void:
	if not tick:
		tick_from += pos - sim_position
	sim_position = pos
	facing = p_facing
	walking = p_walking
	_sync_view()


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

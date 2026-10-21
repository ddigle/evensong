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
## did not move (a host-side player whose frame is late) stands still. Only `position` follows the
## drawing; `sim_position` (simulation, net state, hashes) is untouched. A player drawn from
## interpolated host states (other players on a client) gets show_state() every frame and is drawn
## where it is. The camera (actors/player_camera.gd) follows the drawn position after this.

## Read the move_* actions each physics tick. Off for players driven by tests or the session.
@export var local_input: bool = true

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
	_sync_view()


func class_id() -> String:
	return character.class_id


func _physics_process(delta: float) -> void:
	begin_tick()
	if local_input and data != null:
		apply_input(read_input(), delta)


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
func update_draw(fraction: float) -> void:
	position = draw_position(tick_from, sim_position, fraction) if smooth_draw else sim_position.round()


## Whole-pixel point `fraction` (clamped to 0..1) of the way from `from` to `to`.
static func draw_position(from: Vector2, to: Vector2, fraction: float) -> Vector2:
	return from.lerp(to, clampf(fraction, 0.0, 1.0)).round()


func _sync_view() -> void:
	position = sim_position.round()
	character.direction = facing as RigData.Dir
	character.walking = walking


## The move_* actions (WASD / arrows) as an 8-way input.
static func read_input() -> Vector2i:
	var x: int = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var y: int = int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	return Vector2i(x, y)

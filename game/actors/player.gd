class_name Player
extends Node2D
## A player in the world: simulation state (feet position, facing) + a Character for the picture.
##
## The simulation runs in _physics_process (fixed ticks) with Movement.step, from the local keys
## (read_input) when `local_input` is on. The node itself sits on the rounded feet position, so
## the sprite and the camera (actors/player_camera.gd) move in whole pixels together.

## Read the move_* actions each physics tick. Off for players driven by tests (or the network, G3).
@export var local_input: bool = true

var data: WorldData
## Feet position (float, simulation). `position` is this rounded.
var sim_position: Vector2 = Vector2.ZERO
var facing: int = RigData.Dir.SOUTH
var last_input: Vector2i = Vector2i.ZERO
var character: Character


func _init() -> void:
	character = Character.new()
	character.name = &"Character"
	add_child(character)


func setup(p_data: WorldData, class_id: String, feet: Vector2, p_facing: int = RigData.Dir.SOUTH) -> void:
	data = p_data
	character.class_id = class_id
	sim_position = feet
	facing = p_facing
	last_input = Vector2i.ZERO
	_sync_view()


func class_id() -> String:
	return character.class_id


func _physics_process(delta: float) -> void:
	if local_input and data != null:
		apply_input(read_input(), delta)


## One simulation tick with an 8-way input (-1/0/1 per axis).
func apply_input(input: Vector2i, delta: float) -> void:
	last_input = input
	sim_position = Movement.step(data, sim_position, input, delta)
	facing = Movement.facing_for(input, facing)
	_sync_view()


## Puts the player at a feet position (spawn, tests).
func teleport(feet: Vector2) -> void:
	sim_position = feet
	_sync_view()


func _sync_view() -> void:
	position = sim_position.round()
	character.direction = facing as RigData.Dir
	character.walking = last_input != Vector2i.ZERO


## The move_* actions (WASD / arrows) as an 8-way input.
static func read_input() -> Vector2i:
	var x: int = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var y: int = int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	return Vector2i(x, y)

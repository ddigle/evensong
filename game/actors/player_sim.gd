class_name PlayerSim
extends RefCounted
## One player's simulation state and the one rule that advances it by an input frame (M2b). The
## offline player (Player.tick_controls), the host (every player in a session) and a client's
## prediction of its own player (net/prediction.gd, also when it replays frames the host has not
## acknowledged) all step with step(), so they land on the same state frame by frame.
##
## A frame: an 8-way direction, a "look" (the facing toward the mouse while aiming, or -1: the
## facing follows the movement as in M1), and the body action a "use" starts this frame (a RigData
## action anim resolved from the used hotbar slot, or -1) toward a target tile.
## Order within a frame (M2a's tick_controls): the playing action advances one tick and may end;
## then a use may start an action if none plays (it fixes the facing to the look); then the player
## moves unless an action locks movement (Config.ACTION_LOCKS_MOVEMENT); without an action the
## facing follows the look, or the movement when there is none. An action is timed in frames:
## Config.ACTION_FRAME_TICKS frames per animation frame.

var pos: Vector2 = Vector2.ZERO
var facing: int = RigData.Dir.SOUTH
var walking: bool = false
## The body action playing (RigData action anim) or -1, frames since it started, its target tile.
var action: int = -1
var action_tick: int = 0
var action_cell: Vector2i = Vector2i.ZERO


func copy() -> PlayerSim:
	var c: PlayerSim = PlayerSim.new()
	c.pos = pos
	c.facing = facing
	c.walking = walking
	c.action = action
	c.action_tick = action_tick
	c.action_cell = action_cell
	return c


## Same replicated state (the target tile is not replicated).
func same_as(o: PlayerSim) -> bool:
	return o != null and pos == o.pos and facing == o.facing and walking == o.walking and action == o.action \
		and action_tick == o.action_tick


## How many frames body action `anim` lasts.
static func action_ticks(anim: int) -> int:
	return RigData.frame_count(anim) * Config.ACTION_FRAME_TICKS


## An action still plays after the next frame's advance (a use in that frame would be refused).
func busy_next() -> bool:
	return action >= 0 and action_tick + 1 < action_ticks(action)


## The current frame of the playing action (0 when none).
func action_frame() -> int:
	return action_tick / Config.ACTION_FRAME_TICKS if action >= 0 else 0


## One frame. `look`: facing toward the mouse (RigData.Dir) or -1. `anim`: the action a use starts
## (-1 = no use), toward tile `cell`. Returns what happened to actions: ENDED and / or STARTED bits.
const ENDED: int = 1
const STARTED: int = 2

func step(data: WorldData, dir: Vector2i, look: int, anim: int, cell: Vector2i, delta: float) -> int:
	var events: int = 0
	if action >= 0:
		action_tick += 1
		if action_tick >= action_ticks(action):
			action = -1
			action_tick = 0
			events |= ENDED
	if action < 0 and RigData.is_action(anim):
		action = anim
		action_tick = 0
		action_cell = cell
		if look >= 0:
			facing = look
		walking = false
		events |= STARTED
	var acting: bool = action >= 0
	if not acting or not Config.ACTION_LOCKS_MOVEMENT:
		pos = Movement.step(data, pos, dir, delta)
	if acting:
		walking = dir != Vector2i.ZERO and not Config.ACTION_LOCKS_MOVEMENT
	else:
		facing = look if look >= 0 else Movement.facing_for(dir, facing)
		walking = dir != Vector2i.ZERO
	return events

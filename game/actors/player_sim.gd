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
## then a use may start an action if none plays (it faces the target tile: the look when that points
## toward the tile, else the tile's direction, Aim.use_facing, so the host decides it); then the player
## moves unless an action locks movement (Config.ACTION_LOCKS_MOVEMENT); without an action the
## facing follows the look, or the movement when there is none. An action is timed in frames:
## Config.ACTION_FRAME_TICKS frames per animation frame.
##
## M4a: the state also holds the player's Vitals (HP, stamina, dash, stagger, down / dead) and the aim
## of the playing action (a 0..255 angle code, Combat.aim_code). A frame may also dash (Space) and hold
## F (`interact`: giving up while down; a revive of someone else is the combat rules', arena.gd). The
## order before the M2b steps: a downed player only counts its down time (DIED after Config.DOWN_TICKS
## or GIVE_UP_HOLD_TICKS of F) and a dead one its respawn time (RESPAWN when due); an alive one counts
## down its invulnerability, dash cooldown and stamina wait / regen; a dash in progress moves it at
## Config.DASH_SPEED with Movement's collision and does nothing else; a stagger (hurt) keeps it from
## moving, starting an action or dashing; a frame's dash starts one (stamina, cooldown) when no action
## plays. Damage is hurt() (from outside: the heretic's knife, combat/arena.gd).

var pos: Vector2 = Vector2.ZERO
var facing: int = RigData.Dir.SOUTH
var walking: bool = false
## The body action playing (RigData action anim) or -1, frames since it started, its target tile.
var action: int = -1
var action_tick: int = 0
var action_cell: Vector2i = Vector2i.ZERO
## M4a: the playing action's aim (Combat.aim_code 0..255, toward the mouse when it started).
var action_aim: int = 0
## M4a: health, stamina, dash, stagger, life.
var vit: Vitals = Vitals.new()


func copy() -> PlayerSim:
	var c: PlayerSim = PlayerSim.new()
	c.pos = pos
	c.facing = facing
	c.walking = walking
	c.action = action
	c.action_tick = action_tick
	c.action_cell = action_cell
	c.action_aim = action_aim
	c.vit = vit.copy()
	return c


## Same replicated position, facing and action (the target tile is not replicated). M4b: the vitals
## travel too (same_all, NetProtocol's vitals block).
func same_as(o: PlayerSim) -> bool:
	return o != null and pos == o.pos and facing == o.facing and walking == o.walking and action == o.action \
		and action_tick == o.action_tick


## Everything, vitals and aim included (the M4a determinism checks).
func same_all(o: PlayerSim) -> bool:
	return same_as(o) and action_cell == o.action_cell and action_aim == o.action_aim and vit.same_as(o.vit)


## How many frames body action `anim` lasts.
static func action_ticks(anim: int) -> int:
	return RigData.frame_count(anim) * Config.ACTION_FRAME_TICKS


## An action still plays after the next frame's advance (a use in that frame would be refused).
func busy_next() -> bool:
	return action >= 0 and action_tick + 1 < action_ticks(action)


## The current frame of the playing action (0 when none).
func action_frame() -> int:
	return action_tick / Config.ACTION_FRAME_TICKS if action >= 0 else 0


## The unit vector of facing `dir` (RigData.Dir).
static func facing_vector(dir: int) -> Vector2i:
	match dir:
		RigData.Dir.EAST:
			return Vector2i(1, 0)
		RigData.Dir.NORTH:
			return Vector2i(0, -1)
		RigData.Dir.WEST:
			return Vector2i(-1, 0)
	return Vector2i(0, 1)


## One frame. `look`: facing toward the mouse (RigData.Dir) or -1. `anim`: the action a use starts
## (-1 = no use), toward tile `cell`. M4a: `dash` (Space this frame), `interact` (F held), `aim` (the
## use's aim code, -1 = toward the target tile). Returns what happened: the bits below.
const ENDED: int = 1
const STARTED: int = 2
const DASHED: int = 4
const DIED: int = 8
const RESPAWN: int = 16
## hurt(): the hit landed and staggers / took the player down.
const HURT: int = 32
const DOWNED: int = 64

func step(data: WorldData, dir: Vector2i, look: int, anim: int, cell: Vector2i, delta: float, dash: bool = false,
		interact: bool = false, aim: int = -1) -> int:
	var events: int = 0
	if vit.flash_ticks > 0:
		vit.flash_ticks -= 1
	if vit.life == Vitals.Life.DOWN:
		vit.life_ticks += 1
		vit.give_up_ticks = vit.give_up_ticks + 1 if interact else 0
		walking = false
		if vit.life_ticks >= Config.DOWN_TICKS or vit.give_up_ticks >= Config.GIVE_UP_HOLD_TICKS:
			vit.life = Vitals.Life.DEAD
			vit.life_ticks = 0
			vit.revive_ticks = 0
			vit.give_up_ticks = 0
			events |= DIED
		return events
	if vit.life == Vitals.Life.DEAD:
		vit.life_ticks += 1
		walking = false
		if vit.life_ticks == Config.RESPAWN_TICKS:
			events |= RESPAWN
		return events
	if vit.invuln_ticks > 0:
		vit.invuln_ticks -= 1
	if vit.dash_cooldown > 0:
		vit.dash_cooldown -= 1
	if vit.stamina_wait > 0:
		vit.stamina_wait -= 1
	elif vit.stamina < Config.STAMINA_MAX:
		vit.regen_tick += 1
		if vit.regen_tick >= Config.STAMINA_REGEN_TICKS:
			vit.regen_tick = 0
			vit.stamina += 1
	if action >= 0:
		action_tick += 1
		if action_tick >= action_ticks(action):
			action = -1
			action_tick = 0
			events |= ENDED
	if vit.dash_ticks > 0:
		_dash_move(data, delta)
		return events
	var staggered: bool = vit.hurt_ticks > 0
	if staggered:
		vit.hurt_ticks -= 1
		walking = false
		return events
	if dash and action < 0 and vit.dash_cooldown == 0 and vit.stamina >= Config.DASH_STAMINA:
		vit.stamina -= Config.DASH_STAMINA
		vit.stamina_wait = Config.STAMINA_REGEN_DELAY_TICKS
		vit.regen_tick = 0
		vit.dash_cooldown = Config.DASH_COOLDOWN_TICKS + Config.DASH_TICKS
		vit.dash_ticks = Config.DASH_TICKS
		vit.dash_dir = dir if dir != Vector2i.ZERO else facing_vector(facing)
		if dir != Vector2i.ZERO:
			facing = look if look >= 0 else Movement.facing_for(dir, facing)
		events |= DASHED
		_dash_move(data, delta)
		return events
	if action < 0 and RigData.is_action(anim):
		action = anim
		action_tick = 0
		action_cell = cell
		var to_cell: Vector2i = cell - Aim.feet_cell(pos)
		facing = Aim.use_facing(look, to_cell, facing)
		action_aim = aim if aim >= 0 else Combat.aim_code(Vector2(to_cell))
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


## One dash tick: Config.DASH_SPEED along dash_dir with walking's collision (Movement.step). M4b: the
## direction is cleared when the dash ends (it is only read while one lasts), so the vitals come back to
## rest (Vitals.at_rest) and a state batch stops carrying them.
func _dash_move(data: WorldData, delta: float) -> void:
	pos = Movement.step(data, pos, vit.dash_dir, delta, Config.DASH_SPEED)
	vit.dash_ticks -= 1
	if vit.dash_ticks == 0:
		vit.dash_dir = Vector2i.ZERO
	walking = true


## A hit of `amount` (M4a): nothing while down, dead or invulnerable (after a hit, dashing). Otherwise
## the HP drop (less Config.PLAYER_DEFENCE, 0 in M4a); at 0 the player goes DOWN (its action and dash
## stop), else it is staggered (its action is cut off) and invulnerable for a moment. Returns HURT and /
## or DOWNED, 0 when it did not land.
func hurt(amount: int) -> int:
	if vit.life != Vitals.Life.ALIVE or vit.invulnerable():
		return 0
	vit.hp = maxi(vit.hp - maxi(amount - Config.PLAYER_DEFENCE, 0), 0)
	vit.flash_ticks = Config.HIT_FLASH_TICKS
	action = -1
	action_tick = 0
	vit.dash_ticks = 0
	vit.dash_dir = Vector2i.ZERO
	walking = false
	if vit.hp == 0:
		vit.life = Vitals.Life.DOWN
		vit.life_ticks = 0
		vit.revive_ticks = 0
		vit.give_up_ticks = 0
		vit.hurt_ticks = 0
		vit.invuln_ticks = 0
		return HURT | DOWNED
	vit.hurt_ticks = Config.HURT_TICKS
	vit.invuln_ticks = Config.HURT_INVULN_TICKS
	return HURT


## M4b: the respawn (shared by the offline game, the host and a client's prediction, so they land on the
## same state): at feet `feet` facing Config.SPAWN_FACING, no action, full vitals (Config.RESPAWN_HP).
func respawn(feet: Vector2) -> void:
	pos = feet
	facing = Config.SPAWN_FACING
	walking = false
	action = -1
	action_tick = 0
	vit.reset()


## A downed player gets up (a revive) with `hp`.
func revive(hp: int = Config.REVIVE_HP) -> void:
	vit.life = Vitals.Life.ALIVE
	vit.hp = clampi(hp, 1, Config.PLAYER_HP_MAX)
	vit.life_ticks = 0
	vit.revive_ticks = 0
	vit.give_up_ticks = 0
	vit.hurt_ticks = 0
	vit.invuln_ticks = Config.HURT_INVULN_TICKS

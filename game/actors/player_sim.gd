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
## or GIVE_UP_HOLD_TICKS of F) and a dead one its respawn time (RESPAWN on every frame from when it is
## due until the caller respawns it, M4-fix); an alive one counts
## down its invulnerability, dash cooldown and stamina wait / regen; a dash in progress moves it at
## Config.DASH_SPEED with Movement's collision and does nothing else; a stagger (hurt) keeps it from
## moving, starting an action or dashing; a frame's dash starts one (stamina, cooldown) when no action
## plays. Damage is hurt() (from outside: the heretic's knife, combat/arena.gd).
##
## M6a: the Vitals hold the effects too (a buff raising the walking speed, poison taking HP every interval:
## items/potions.gd, Config "M6a"); an alive player counts them down first thing (_tick_effects), so the
## offline game, the host and a prediction run them alike. A potion works from outside (Potions.apply: heal,
## add_buff, add_poison), like damage.
##
## M5b: the paladin's purification channel (channel_tick, channel_cell). A frame with `channel` starts it standing free; it
## then runs on its own, Config.PURIFY_CHANNEL_TICKS frames, and reports CHANNEL_DONE (the caller purifies around
## channel_cell, items/purify.gd). A frame that moves, dashes or uses breaks it (CHANNEL_BROKEN, then the frame goes on as
## usual); hurt() and going down break it too. M5c: on the wire (same_as, a state's action bits): the host runs it from the
## client's frames like an action and a client predicts it; channel_cell is the feet tile (a channel never moves).

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
## M5b: the paladin's purification channel: ticks so far (0 = none; 1 on the frame it starts) and the tile it purifies
## around (items/purify.gd; always the feet tile: the player stands). M5c: on the wire, so in same_as().
var channel_tick: int = 0
var channel_cell: Vector2i = Vector2i.ZERO


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
	c.channel_tick = channel_tick
	c.channel_cell = channel_cell
	return c


## Same replicated position, facing and action (the target tile is not replicated). M4b: the vitals
## travel too (same_all, NetProtocol's vitals block). M5c: the purification channel's ticks too.
func same_as(o: PlayerSim) -> bool:
	return o != null and pos == o.pos and facing == o.facing and walking == o.walking and action == o.action \
		and action_tick == o.action_tick and channel_tick == o.channel_tick


## Everything, vitals and aim included (the M4a determinism checks).
func same_all(o: PlayerSim) -> bool:
	return same_as(o) and action_cell == o.action_cell and action_aim == o.action_aim and vit.same_as(o.vit) \
		and channel_cell == o.channel_cell


## M5b: a purification channel is under way.
func channelling() -> bool:
	return channel_tick > 0


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
## M6a: a potion healed / buffed / poisoned the player (Potions.apply), and a poison tick took HP this frame
## (with DOWNED when it took the last).
const HEALED: int = 128
const BUFFED: int = 256
const POISONED: int = 512
const POISON_TICK: int = 1024
## M5b: the purification channel started this frame / ran its Config.PURIFY_CHANNEL_TICKS (the caller purifies around
## channel_cell) / was broken this frame (by moving, a dash or a use in it; hurt() and going down break it too, the
## caller sees the channel gone).
const CHANNEL_STARTED: int = 2048
const CHANNEL_DONE: int = 4096
const CHANNEL_BROKEN: int = 8192

## M5b: `channel` (the frame starts the purification channel: the caller checked the class and the ground,
## Purify.channel_refusal; M5c: the host decides it for every member, SessionHost._channel). It starts only standing free (no move, dash, use, action, stagger) and
## then runs on its own; a frame that moves, dashes or uses breaks it.
func step(data: WorldData, dir: Vector2i, look: int, anim: int, cell: Vector2i, delta: float, dash: bool = false,
		interact: bool = false, aim: int = -1, channel: bool = false) -> int:
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
		# M4-fix: due from RESPAWN_TICKS on, every frame until the caller respawns it (the count stops there),
		# so a dead player handed over past that tick (a client that lost its host while waiting in the
		# dungeon for the surface) still comes back.
		if vit.life_ticks < Config.RESPAWN_TICKS:
			vit.life_ticks += 1
		walking = false
		if vit.life_ticks >= Config.RESPAWN_TICKS:
			events |= RESPAWN
		return events
	# M6a: the buff and the poison count down; a poison tick may take the player down.
	events |= _tick_effects()
	if vit.life != Vitals.Life.ALIVE:
		walking = false
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
	# M5b: the purification channel runs standing; moving, a dash or a use breaks it (and then happens as usual).
	if channel_tick > 0:
		if dir != Vector2i.ZERO or dash or RigData.is_action(anim):
			channel_tick = 0
			events |= CHANNEL_BROKEN
		else:
			channel_tick += 1
			walking = false
			if channel_tick >= Config.PURIFY_CHANNEL_TICKS:
				channel_tick = 0
				events |= CHANNEL_DONE
			return events
	elif channel and action < 0 and dir == Vector2i.ZERO and not dash and not RigData.is_action(anim):
		channel_tick = 1
		channel_cell = Aim.feet_cell(pos)
		walking = false
		events |= CHANNEL_STARTED
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
		pos = Movement.step(data, pos, dir, delta, walk_speed())
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
	channel_tick = 0  # M5b: a hit breaks the purification channel
	vit.dash_ticks = 0
	vit.dash_dir = Vector2i.ZERO
	walking = false
	if vit.hp == 0:
		_go_down()
		return HURT | DOWNED
	vit.hurt_ticks = Config.HURT_TICKS
	vit.invuln_ticks = Config.HURT_INVULN_TICKS
	return HURT


## At 0 HP: down (its action and dash already stopped by the caller); M6a: the effects end
## (Config.EFFECTS_END_ON_DOWN).
func _go_down() -> void:
	channel_tick = 0  # M5b: going down (a poison tick too) breaks the purification channel
	vit.life = Vitals.Life.DOWN
	vit.life_ticks = 0
	vit.revive_ticks = 0
	vit.give_up_ticks = 0
	vit.hurt_ticks = 0
	vit.invuln_ticks = 0
	if Config.EFFECTS_END_ON_DOWN:
		vit.clear_effects()


# --- M6a: effects (items/potions.gd) -------------------------------------------------------------------

## Walking speed now: Config.WALK_SPEED, raised by the buff (Config.BUFF_SPEED_PCT) while it lasts.
func walk_speed() -> float:
	if vit.buff_ticks <= 0:
		return Config.WALK_SPEED
	return Config.WALK_SPEED * vit.buff_pct / 100.0


## One tick of the buff and the poison (alive only): the buff runs out; the poison takes Vitals.poison_damage
## every Config.POISON_INTERVAL_TICKS (the first one interval after it started) until it runs out. A poison
## tick takes HP only: no stagger, no invulnerability, not stopped by one, no defence; at 0 the player goes
## down (and the effects end). Returns POISON_TICK (| DOWNED). A poison that ran out leaves no field set, also
## when its last tick took the player down (M6-fix: with Config.EFFECTS_END_ON_DOWN false its damage and timer
## stayed, so Vitals.has_effects() was true for good after a revive).
func _tick_effects() -> int:
	var events: int = 0
	if vit.buff_ticks > 0:
		vit.buff_ticks -= 1
		if vit.buff_ticks == 0:
			vit.buff_pct = 100
	if vit.poison_ticks > 0:
		vit.poison_ticks -= 1
		vit.poison_timer -= 1
		var amount: int = vit.poison_damage
		if vit.poison_timer <= 0:
			vit.poison_timer = Config.POISON_INTERVAL_TICKS
			events |= _poison_hit(amount)
		if vit.poison_ticks == 0:
			vit.poison_damage = 0
			vit.poison_timer = 0
	return events


func _poison_hit(amount: int) -> int:
	vit.hp = maxi(vit.hp - amount, 0)
	vit.flash_ticks = Config.HIT_FLASH_TICKS
	if vit.hp > 0:
		return POISON_TICK
	action = -1
	action_tick = 0
	vit.dash_ticks = 0
	vit.dash_dir = Vector2i.ZERO
	walking = false
	_go_down()
	return POISON_TICK | DOWNED


## Restores up to `amount` HP (not past Config.PLAYER_HP_MAX; only while up). Returns the HP gained.
func heal(amount: int) -> int:
	if vit.life != Vitals.Life.ALIVE or amount <= 0:
		return 0
	var gained: int = mini(amount, Config.PLAYER_HP_MAX - vit.hp)
	vit.hp += gained
	return gained


## The buff: walking speed `pct` percent for `ticks` (only while up). One already running keeps the longer
## time and the larger percent (Config.EFFECT_REFRESH_KEEPS_STRONGER; else the new one replaces it).
func add_buff(pct: int, ticks: int) -> bool:
	if vit.life != Vitals.Life.ALIVE or ticks <= 0:
		return false
	if vit.buff_ticks > 0 and Config.EFFECT_REFRESH_KEEPS_STRONGER:
		vit.buff_pct = maxi(vit.buff_pct, pct)
		vit.buff_ticks = maxi(vit.buff_ticks, ticks)
	else:
		vit.buff_pct = pct
		vit.buff_ticks = ticks
	return true


## Poison: `damage` every Config.POISON_INTERVAL_TICKS for `ticks` (only while up). A running one keeps the
## longer time and the larger damage and its tick rhythm (Config.EFFECT_REFRESH_KEEPS_STRONGER).
func add_poison(damage: int, ticks: int) -> bool:
	if vit.life != Vitals.Life.ALIVE or ticks <= 0 or damage <= 0:
		return false
	if vit.poison_ticks > 0 and Config.EFFECT_REFRESH_KEEPS_STRONGER:
		vit.poison_damage = maxi(vit.poison_damage, damage)
		vit.poison_ticks = maxi(vit.poison_ticks, ticks)
	else:
		vit.poison_damage = damage
		vit.poison_ticks = ticks
		vit.poison_timer = Config.POISON_INTERVAL_TICKS
	return true


## M4b: the respawn (shared by the offline game, the host and a client's prediction, so they land on the
## same state): at feet `feet` facing Config.SPAWN_FACING, no action, full vitals (Config.RESPAWN_HP).
func respawn(feet: Vector2) -> void:
	pos = feet
	facing = Config.SPAWN_FACING
	walking = false
	action = -1
	action_tick = 0
	channel_tick = 0
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

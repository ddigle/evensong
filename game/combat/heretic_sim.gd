class_name HereticSim
extends RefCounted
## One heretic (M4a: the slice's one enemy kind, melee; 03-pixel heretic_v02 sheets): its state and
## the timing of its animations. The arena (combat/arena.gd) runs its behaviour each tick; the view is
## actors/heretic.gd. Values are PROVISIONAL (Config "M4a").
##
## States: IDLE at home, CHASE the target, ATTACK (the telegraph: the knife raised for
## Config.HERETIC_TELEGRAPH_TICKS, then the hit on the hit column, then the rest of the swing; a hit does
## not cut it off, Config.HERETIC_HURT_INTERRUPTS_ATTACK), HURT (staggered), EDGE (its target stepped into
## the altar light: it stands at the edge facing it), RETURN home, DEAD (the death frames, then the corpse
## for Config.HERETIC_CORPSE_TICKS).
##
## Sheets (03-pixel/prompts.md 13차 "M4에 넘길 것"): rows south / east / north, west = east mirrored; walk
## 6, idle 4, hurt 6, death 7 frames in 32 cells (feet y=31, first column 0); attack 8 frames in 64 cells
## (feet y=47, the body at (16, 16), column 0 = the start picture, play from column 1).

enum State { IDLE, CHASE, ATTACK, HURT, EDGE, RETURN, DEAD }
enum Anim { WALK, IDLE, ATTACK, HURT, DEATH }

const STATE_NAMES: PackedStringArray = ["idle", "chase", "attack", "hurt", "edge", "return", "dead"]
const ANIM_NAMES: PackedStringArray = ["walk", "idle", "attack", "hurt", "death"]
const FRAME_COUNTS: PackedInt32Array = [6, 4, 8, 6, 7]
const CELLS: PackedInt32Array = [32, 32, 64, 32, 32]
const FIRST_COLUMN: PackedInt32Array = [0, 0, 1, 0, 0]
const SHEET_PATHS: PackedStringArray = [
	"res://art/enemies/heretic_v02_walk.png", "res://art/enemies/heretic_v02_idle.png",
	"res://art/enemies/heretic_v02_attack.png", "res://art/enemies/heretic_v02_hurt.png",
	"res://art/enemies/heretic_v02_death.png",
]
## IMPL: walk and idle frame times in ticks (the player's Config.WALK_FRAME_TIME / IDLE_FRAME_TIME).
const WALK_FRAME_TICKS: int = 7
const IDLE_FRAME_TICKS: int = 12

var id: int = 0
var pos: Vector2 = Vector2.ZERO
var home: Vector2 = Vector2.ZERO
var facing: int = RigData.Dir.SOUTH
var state: int = State.IDLE
var state_ticks: int = 0
var hp: int = Config.HERETIC_HP
## The player it goes after (its node instance id) while has_target.
var target_id: int = 0
var has_target: bool = false
var cooldown: int = 0
## The direction of the attack under way (unit vector toward the target when it started).
var attack_dir: Vector2 = Vector2.DOWN
var walking: bool = false
## Ticks it has been on the way home without getting closer (gives up and makes this its home).
var stuck: int = 0
## M4-fix: ticks since it started watching its target in the light (EDGE, and HURT while watching); at
## Arena.edge_wait_ticks() it walks home. The host's AI only (not sent: a client draws EDGE from its state).
var watch_ticks: int = 0
## Display: ticks since spawning (walk / idle frames), hit flash ticks left.
var clock: int = 0
var flash_ticks: int = 0


func alive() -> bool:
	return state != State.DEAD


func row() -> int:
	return RigData.sheet_row(facing)


## The attack frame (0-based played frame) the knife lands on for sheet row `r`.
static func hit_frame(r: int) -> int:
	return Config.HERETIC_HIT_COLUMN[r] - FIRST_COLUMN[Anim.ATTACK]


## Ticks an attack in sheet row `r` lasts: the telegraph, then the frames from the hit frame on.
static func attack_ticks(r: int) -> int:
	return Config.HERETIC_TELEGRAPH_TICKS + (FRAME_COUNTS[Anim.ATTACK] - hit_frame(r)) * Config.HERETIC_ATTACK_FRAME_TICKS


## The attack frame shown `t` ticks into an attack in row `r`: the frames before the hit frame at the
## attack frame time, the last of them held until the telegraph ends, then on from the hit frame.
static func attack_frame(r: int, t: int) -> int:
	var pre: int = hit_frame(r)
	if t < Config.HERETIC_TELEGRAPH_TICKS:
		return mini(t / Config.HERETIC_ATTACK_FRAME_TICKS, maxi(pre - 1, 0))
	return mini(pre + (t - Config.HERETIC_TELEGRAPH_TICKS) / Config.HERETIC_ATTACK_FRAME_TICKS,
		FRAME_COUNTS[Anim.ATTACK] - 1)


static func hurt_ticks() -> int:
	return FRAME_COUNTS[Anim.HURT] * Config.HERETIC_HURT_FRAME_TICKS


static func death_ticks() -> int:
	return FRAME_COUNTS[Anim.DEATH] * Config.HERETIC_DEATH_FRAME_TICKS


## The animation and frame to show now.
func anim() -> int:
	match state:
		State.ATTACK:
			return Anim.ATTACK
		State.HURT:
			return Anim.HURT
		State.DEAD:
			return Anim.DEATH
	return Anim.WALK if walking else Anim.IDLE


func frame() -> int:
	match state:
		State.ATTACK:
			return attack_frame(row(), state_ticks)
		State.HURT:
			return mini(state_ticks / Config.HERETIC_HURT_FRAME_TICKS, FRAME_COUNTS[Anim.HURT] - 1)
		State.DEAD:
			return mini(state_ticks / Config.HERETIC_DEATH_FRAME_TICKS, FRAME_COUNTS[Anim.DEATH] - 1)
	if walking:
		return (clock / WALK_FRAME_TICKS) % FRAME_COUNTS[Anim.WALK]
	return (clock / IDLE_FRAME_TICKS) % FRAME_COUNTS[Anim.IDLE]


## The knife is out (the telegraph and the swing): every attack frame but the start picture's.
func knife_out() -> bool:
	return state == State.ATTACK


## Gone for good (the corpse has lain long enough).
func finished() -> bool:
	return state == State.DEAD and state_ticks >= death_ticks() + Config.HERETIC_CORPSE_TICKS


func describe() -> String:
	return "heretic %d %s hp=%d at %.1f,%.1f facing=%s" % [id, STATE_NAMES[state], hp, pos.x, pos.y,
		RigData.DIR_NAMES[facing]]

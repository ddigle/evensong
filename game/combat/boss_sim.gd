class_name BossSim
extends RefCounted
## M12a: the heretic leader's state (combat/boss_fight.gd steps it; combat/boss_view.gd draws it). Numbers are Config "M12a" (BOSS,
## BOSS_ATTACKS: PROVISIONAL). M12 boss art: its picture is its own sheets (03-pixel PixelLab 17차 boss_leader_v02, README "M12 보스 그림"):
## the heretic's five animations with the same frame counts plus a CAST sheet (the fire volley and the burning ground; the cleave keeps
## the attack sheet), rows south / east / north, west mirrored. anim() / frame() below only pick the picture: nothing in the fight reads
## them (the simulation, its timing and the wire are M12's).
##
## States: SLEEP (at home, idle: nobody has come in yet), CHASE (awake: walks after its target, or stands), ATTACK (one of the three:
## the telegraph, the hit, a short after-pause), RETURN (walking home to reset: nobody in its room for a while, or dragged too far; no
## blow lands on it), DEAD (the death frames, then lying: it does not come back, Config.BOSS_RESPAWNS). A stun (a skill's, shortened, then
## an immunity; or a pillar's debris) holds it still on top of any state but SLEEP and DEAD.

enum State { SLEEP, CHASE, ATTACK, RETURN, DEAD }
enum Attack { NONE, CLEAVE, VOLLEY, BURN }
## M12 boss art: its sheets (BossView.SHEETS). The first five are HereticSim.Anim's (same values, same frame counts); CAST is its own.
enum Anim { WALK, IDLE, ATTACK, HURT, DEATH, CAST }

const STATE_NAMES: PackedStringArray = ["sleep", "chase", "attack", "return", "dead"]
const ATTACK_NAMES: PackedStringArray = ["none", "cleave", "volley", "burn"]
## The Config.BOSS_ATTACKS row of each Attack.
const ATTACK_IDS: Array[StringName] = [&"", &"cleave", &"volley", &"burn"]
## M12 boss art (IMPL "M12 보스 그림 시트"): per Anim its name, frames played and the sheet column of the first (the two action sheets'
## column 0 is the start picture, as the heretic's attack); the hurt and death frame counts are the heretic's, so the wire's death time
## (NetProtocol.boss_death_ticks: HereticSim's 7 x 6 ticks) is this sheet's too.
const ANIM_NAMES: PackedStringArray = ["walk", "idle", "attack", "hurt", "death", "cast"]
const FRAME_COUNTS: PackedInt32Array = [6, 4, 8, 6, 7, 8]
const FIRST_COLUMN: PackedInt32Array = [0, 0, 1, 0, 0, 1]
## M12 boss art (IMPL "M12 보스 그림 맞는 열", picture only): the sheet column (rows south, east, north) the blow shows on, the attack's
## and the cast's; the column before it is the telegraph picture held until the blow (the attack: the staff raised to swing; the cast:
## the fire gathering). The art step's candidates (03-pixel prompts.md 17차 "game/에 넘길 것"): with the heretic's columns (Config
## HERETIC_HIT_COLUMN 3, 4, 5) the held east and north columns would already be mid-swing.
const HIT_COLUMN_ATTACK: PackedInt32Array = [3, 3, 3]
const HIT_COLUMN_CAST: PackedInt32Array = [4, 3, 3]

var pos: Vector2 = Vector2.ZERO
var home: Vector2 = Vector2.ZERO
var facing: int = RigData.Dir.SOUTH
var state: int = State.SLEEP
var state_ticks: int = 0
## Ticks since it was made (the idle and walk frames).
var clock: int = 0
var hp: int = 1
var hp_max: int = 1
## 1, then 2 once its HP fell to Config.BOSS "phase2_hp_pct".
var phase: int = 1
## The attack under way (ATTACK), its direction (unit), its target's feet at the start and the bolts' directions of a volley.
var attack: int = Attack.NONE
var attack_dir: Vector2 = Vector2.DOWN
var attack_at: Vector2 = Vector2.ZERO
var volley_dirs: Array[Vector2] = []
## M12c: the volley's middle direction (radians; its bolts fan out round it, volley_dirs_for): a client draws the same aim lines from it.
var volley_base: float = 0.0
## Ticks before it may start another attack.
var recover: int = 0
var walking: bool = false
var stuck: int = 0
## The player it goes after (node instance id, 0 = none) and the threat table (○ gameplay-design §2.3, the M9 rules).
var target_id: int = 0
var threat: Dictionary[int, int] = {}
var taunt_by: int = 0
var taunt_ticks: int = 0
## Stun, the immunity after one, slow (percent and ticks), exposed (after a pillar's debris), poison.
var stun_ticks: int = 0
var stun_immune: int = 0
var slow_pct: int = 0
var slow_ticks: int = 0
var exposed_ticks: int = 0
var poison_damage: int = 0
var poison_ticks: int = 0
var poison_timer: int = 0
var poison_by: int = 0
## Display: the hit flash.
var flash_ticks: int = 0
## Ticks no living player has stood in its room (awake).
var empty_ticks: int = 0
## The heretics it called in phase 2 (their ids in the arena) and whether it called them this fight.
var adds: Array[int] = []
var adds_called: bool = false
## The players on the map when it woke (its HP scaling).
var woke_with: int = 0


static func num(key: String) -> float:
	return Config.BOSS[key]


static func num_i(key: String) -> int:
	return roundi(Config.BOSS[key])


## Attack `a`'s number `key` (Config.BOSS_ATTACKS).
static func attack_num(a: int, key: String) -> float:
	var row: Dictionary = Config.BOSS_ATTACKS[ATTACK_IDS[a]]
	var v: float = row[key]
	return v


static func attack_int(a: int, key: String) -> int:
	return roundi(attack_num(a, key))


## Its max HP when it wakes with `players` players on its map (Config.BOSS hp_base x (1 + hp_per_player_pct/100 (n - 1)), n capped).
static func hp_for(players: int) -> int:
	var n: int = clampi(players, 1, num_i("players_cap"))
	return roundi(num("hp_base") * (1.0 + num("hp_per_player_pct") / 100.0 * float(n - 1)))


func alive() -> bool:
	return state != State.DEAD


func awake() -> bool:
	return state != State.SLEEP and state != State.DEAD


## Blows land on it (awake, not walking home to reset).
func open_to_hits() -> bool:
	return alive() and state != State.RETURN


func stunned() -> bool:
	return alive() and stun_ticks > 0


func slowed() -> bool:
	return alive() and slow_ticks > 0 and slow_pct > 0


func taunted() -> bool:
	return alive() and taunt_ticks > 0 and taunt_by != 0


func exposed() -> bool:
	return alive() and exposed_ticks > 0


func poisoned() -> bool:
	return alive() and poison_ticks > 0


func threat_of(player_id: int) -> int:
	var v: int = threat.get(player_id, 0)
	return v


func top_threat() -> int:
	var top: int = 0
	for v: int in threat.values():
		top = maxi(top, v)
	return top


func row() -> int:
	return RigData.sheet_row(facing)


## A volley's `n` bolt directions fanned Config.BOSS_ATTACKS volley spread_deg apart round angle `base` (radians), first to last.
static func volley_dirs_for(base: float, n: int) -> Array[Vector2]:
	var spread: float = deg_to_rad(attack_num(Attack.VOLLEY, "spread_deg"))
	var out: Array[Vector2] = []
	for i: int in n:
		out.append(Vector2.from_angle(base + (float(i) - (n - 1) / 2.0) * spread))
	return out


## Ticks its attack `a` lasts in ATTACK (the burn's cast only: its circles wait on their own).
static func attack_length(a: int) -> int:
	if a == Attack.BURN:
		return attack_int(a, "cast_ticks")
	return attack_int(a, "telegraph") + attack_int(a, "after")


## The tick of its attack `a` on which the blow goes (the cleave's hit, the volley's bolts; the burn's circles are placed at the start).
static func strike_tick(a: int) -> int:
	if a == Attack.BURN:
		return 0
	return attack_int(a, "telegraph")


## Its walking speed now (Config.BOSS speed, less a slow).
func speed() -> float:
	var s: float = num("speed")
	return s * float(100 - clampi(slow_pct, 0, 100)) / 100.0 if slowed() else s


# --- the picture (its own sheets: Anim; M12 boss art) ----------------------------------------------------------------

## The sheet shown now (Anim): dead, stunned (the hurt pose held), mid-attack (the cleave on the attack sheet, the volley and the burn on
## the cast sheet), the hit flash standing, else walking or idle (asleep too).
func anim() -> int:
	if state == State.DEAD:
		return Anim.DEATH
	if stunned():
		return Anim.HURT
	if state == State.ATTACK:
		return action_anim(attack)
	if flash_ticks > 0 and state == State.CHASE and not walking:
		return Anim.HURT
	return Anim.WALK if walking else Anim.IDLE


## The action sheet of attack `a`: the cleave swings the staff (ATTACK), the fire volley and the burning ground cast (CAST).
static func action_anim(a: int) -> int:
	return Anim.ATTACK if a == Attack.CLEAVE else Anim.CAST


## The frame (0-based played frame: its sheet column is FIRST_COLUMN more) of anim() now. The timing is the heretic's, as in M12a.
func frame() -> int:
	var a: int = anim()
	match a:
		Anim.DEATH:
			return mini(state_ticks / Config.HERETIC_DEATH_FRAME_TICKS, FRAME_COUNTS[Anim.DEATH] - 1)
		Anim.HURT:
			return Config.SKILL_STUN_FRAME if stunned() else mini((Config.HIT_FLASH_TICKS - flash_ticks) / 2, FRAME_COUNTS[Anim.HURT] - 1)
		Anim.ATTACK, Anim.CAST:
			return attack_frame(a, row(), attack, state_ticks)
		Anim.WALK:
			return (clock / HereticSim.WALK_FRAME_TICKS) % FRAME_COUNTS[Anim.WALK]
	return (clock / HereticSim.IDLE_FRAME_TICKS) % FRAME_COUNTS[Anim.IDLE]


## The sheet column of action sheet `sheet` (Anim.ATTACK or CAST) the blow shows on in row `r` (HIT_COLUMN_*).
static func hit_column(sheet: int, r: int) -> int:
	return HIT_COLUMN_ATTACK[r] if sheet == Anim.ATTACK else HIT_COLUMN_CAST[r]


## Its played frame (the column less FIRST_COLUMN).
static func hit_frame(sheet: int, r: int) -> int:
	return hit_column(sheet, r) - FIRST_COLUMN[sheet]


## The tick of attack `a` its picture's blow column waits for: the blow (strike_tick), the burn's whole cast (its circles erupt later,
## while it walks).
static func picture_blow_tick(a: int) -> int:
	return strike_tick(a) if a != Attack.BURN else attack_int(a, "cast_ticks")


## The frame of action sheet `sheet` at tick `t` of attack `a` in row `r` (M12a's rule on the boss's own columns): the frames before
## its hit frame at the heretic's attack frame time, the last of them held until the blow (the telegraph), then the rest (the burn: the
## raise held over its whole cast).
static func attack_frame(sheet: int, r: int, a: int, t: int) -> int:
	var pre: int = hit_frame(sheet, r)
	var blow: int = picture_blow_tick(a)
	if t < blow:
		return mini(t / Config.HERETIC_ATTACK_FRAME_TICKS, maxi(pre - 1, 0))
	return mini(pre + (t - blow) / Config.HERETIC_ATTACK_FRAME_TICKS, FRAME_COUNTS[sheet] - 1)


func describe() -> String:
	return "boss %s%s hp=%d/%d phase=%d at %.1f,%.1f" % [STATE_NAMES[state],
		"/" + ATTACK_NAMES[attack] if state == State.ATTACK else "", hp, hp_max, phase, pos.x, pos.y]

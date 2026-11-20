class_name BossSim
extends RefCounted
## M12a: the heretic leader's state (combat/boss_fight.gd steps it; combat/boss_view.gd draws it). Numbers are Config "M12a" (BOSS,
## BOSS_ATTACKS: PROVISIONAL). Its picture frames are the heretic's (03-pixel heretic_v02 sheets, the leader's view adds to them: a
## code-drawn PLACEHOLDER until a sheet of its own exists): the same five animations, rows south / east / north, west mirrored.
##
## States: SLEEP (at home, idle: nobody has come in yet), CHASE (awake: walks after its target, or stands), ATTACK (one of the three:
## the telegraph, the hit, a short after-pause), RETURN (walking home to reset: nobody in its room for a while, or dragged too far; no
## blow lands on it), DEAD (the death frames, then lying: it does not come back, Config.BOSS_RESPAWNS). A stun (a skill's, shortened, then
## an immunity; or a pillar's debris) holds it still on top of any state but SLEEP and DEAD.

enum State { SLEEP, CHASE, ATTACK, RETURN, DEAD }
enum Attack { NONE, CLEAVE, VOLLEY, BURN }

const STATE_NAMES: PackedStringArray = ["sleep", "chase", "attack", "return", "dead"]
const ATTACK_NAMES: PackedStringArray = ["none", "cleave", "volley", "burn"]
## The Config.BOSS_ATTACKS row of each Attack.
const ATTACK_IDS: Array[StringName] = [&"", &"cleave", &"volley", &"burn"]

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


# --- the picture (the heretic's sheets: HereticSim.Anim) -------------------------------------------------------------

func anim() -> int:
	if state == State.DEAD:
		return HereticSim.Anim.DEATH
	if stunned():
		return HereticSim.Anim.HURT
	if state == State.ATTACK:
		return HereticSim.Anim.ATTACK
	if flash_ticks > 0 and state == State.CHASE and not walking:
		return HereticSim.Anim.HURT
	return HereticSim.Anim.WALK if walking else HereticSim.Anim.IDLE


func frame() -> int:
	var counts: PackedInt32Array = HereticSim.FRAME_COUNTS
	match anim():
		HereticSim.Anim.DEATH:
			return mini(state_ticks / Config.HERETIC_DEATH_FRAME_TICKS, counts[HereticSim.Anim.DEATH] - 1)
		HereticSim.Anim.HURT:
			return Config.SKILL_STUN_FRAME if stunned() else mini((Config.HIT_FLASH_TICKS - flash_ticks) / 2, counts[HereticSim.Anim.HURT] - 1)
		HereticSim.Anim.ATTACK:
			return attack_frame(row(), attack, state_ticks)
		HereticSim.Anim.WALK:
			return (clock / HereticSim.WALK_FRAME_TICKS) % counts[HereticSim.Anim.WALK]
	return (clock / HereticSim.IDLE_FRAME_TICKS) % counts[HereticSim.Anim.IDLE]


## The attack sheet frame at tick `t` of attack `a` in row `r`: the frames before the heretic's hit column, the last of them held until
## the blow (the telegraph: the arm raised), then the rest at the heretic's frame time (the burn: the raise held over its whole cast).
static func attack_frame(r: int, a: int, t: int) -> int:
	var pre: int = HereticSim.hit_frame(r)
	var blow: int = strike_tick(a) if a != Attack.BURN else attack_int(a, "cast_ticks")
	if t < blow:
		return mini(t / Config.HERETIC_ATTACK_FRAME_TICKS, maxi(pre - 1, 0))
	return mini(pre + (t - blow) / Config.HERETIC_ATTACK_FRAME_TICKS, HereticSim.FRAME_COUNTS[HereticSim.Anim.ATTACK] - 1)


func describe() -> String:
	return "boss %s%s hp=%d/%d phase=%d at %.1f,%.1f" % [STATE_NAMES[state],
		"/" + ATTACK_NAMES[attack] if state == State.ATTACK else "", hp, hp_max, phase, pos.x, pos.y]

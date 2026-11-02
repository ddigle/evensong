class_name Prayer
extends RefCounted
## M10a: the group prayer at the altar and meditation (offline first, like M5a-M9a; M10b: the session host runs it too). One per surface
## world: the offline game (core/main.gd) keeps one and steps it every game tick after the combat; tests drive it directly. Rules
## on Player nodes like the arena's (keyed by node instance id), deterministic (the directions come from a seeded generator, the
## turns from the join order, no clock but its own game ticks).
##
## ● decided (R45, game-concept §9.3·§9.4, gameplay-design §3.6), followed as written:
##   - a cleric starts it with F at the altar; the players inside the circle round the altar join with one F (no holding);
##   - the turns go round the participants; the one whose turn it is enters the shown direction with W A S D within the window
##     (participants do not move while praying: the move keys are the answers); every participant gets the buff at the end;
##   - the turns are fixed whatever the head count; one turn = one of the altar's 3x3 lamps: a success lights it, a failure
##     flickers it out; the lamps lit at the end and the head count (with a cap) set the effect, never below a floor: a failure
##     never gives a debuff and never cancels the prayer;
##   - a participant hit (any damage) or quitting leaves alone (its later turns go to the others); the cleric hit or quitting
##     stops it all; it cannot start in combat;
##   - the effect is timed and a death removes it; while it lasts there is no new prayer; it costs the cleric's faith; the one
##     prayer of the slice is zeal (more damage); with no cleric or alone anyone meditates at the altar (short, no turns) for a
##     small buff.
## ○ / not in the docs (PROVISIONAL, core/config.gd "M10a", README "임시값" M10a): the circle (PRAYER_CIRCLE_RADIUS_PX), a tap
## (PRAYER_TAP_MAX_TICKS, Main), the gather and joining only then, the window and the gap (21 s in all), the direction rule, the
## zeal formula and time, the faith's amount and when it is spent (on completion), combat, who the zeal blocks, meditation's
## numbers and what breaks it, which damage zeal counts (Prayer.zeal_damage), "alone" for a cleric (no other living player in
## the circle), what a turn owner leaving does to its turn (it fails), the refusals while praying (Player.make_frame,
## Skills.refusal, Main: lifting, panels).
##
## Order inside step(): the clock, the participants who are gone, down or dead leave (the cleric: it stops), the meditations
## (broken by a move, a dash, an action; done after Config.MEDITATE_TICKS), then the phase: the gather counts down and opens
## turn 0; a turn judges its owner's answer (the first press of a move key this tick, from rest: a key held before does not
## count; two at once = wrong), times out at the window's end, and the next turn opens after the gap; after the last one the
## prayer ends (zeal for everyone still in, the cleric's faith spent). The keys each participant held this tick are kept to tell
## the next tick's press.
##
## M10b (sessions, the host runs this model; `answers_from_keys` off): an answer is no move key on the owner's frame but the ANSWER
## request its machine sent, tagged with the prayer and the turn it answers (submit(): this prayer, this turn, open, the sender's,
## not answered yet; the step judges it where it judges a key). The host takes it up to `lag_ticks` (Config.PRAYER_ANSWER_LAG_TICKS)
## past the window (window_end: the way of the turn's event down and of the answer up), and every turn lasts that much longer
## (turn_ticks_total). Every Event carries the clock it happened at (a tap's: the clock before this tick's step; a step's: after),
## so the host stamps the wire's events with it and a client's mirror ages them like the host (net/net_prayer.gd).
##
## M10-fix (review, PROVISIONAL rows "M10 검토 …"): "alone" counts only company that could join (up, in the circle, no prayer's
## zeal: Config.PRAYER_COMPANY_MUST_BE_ABLE_TO_JOIN); a gather that ends with the cleric alone (Config.PRAYER_MIN_PARTICIPANTS) is
## no prayer: it stops (`nobody joined`: nothing given, no faith spent) and the cleric meditates instead; a meditation's zeal does
## not block a prayer (SkillState.zeal_from_prayer, Config.MEDITATION_ZEAL_BLOCKS_PRAYER); on the host a join that arrives within
## `join_lag_ticks` (Config.PRAYER_JOIN_LAG_TICKS) of the turns' start is still taken (its machine saw the gather when it tapped).

enum Phase { IDLE, GATHER, TURNS }
enum Lamp { UNLIT, LIT, OUT }
## A player's part (Player.prayer_role).
enum Role { NONE, PRAYING, MEDITATING }
## The four answers, W A S D.
enum Dir { UP, LEFT, DOWN, RIGHT }

const PHASE_NAMES: PackedStringArray = ["idle", "gather", "turns"]
const LAMP_NAMES: PackedStringArray = ["unlit", "lit", "out"]
const DIR_KEYS: PackedStringArray = ["w", "a", "s", "d"]
const DIR_VECTORS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
## answer_of(): no press this tick / several move keys pressed at once (a wrong answer).
const NO_PRESS: int = -1
const SEVERAL: int = -2
const CLERIC: String = "cleric"
## IMPL: mixed into the directions' seed (with the world seed and the prayers started).
const SALT: int = 0x9A7E

## Why a tap did nothing (logs, tests; the HUD has no font).
const WHY_DOWN: String = "down"
const WHY_DEAD: String = "dead"
const WHY_SURFACE: String = "the altar is on the surface"
const WHY_NO_ALTAR: String = "no altar (it is carried)"
const WHY_CARRYING: String = "carrying the altar"
const WHY_OUTSIDE: String = "outside the prayer circle"
const WHY_PANEL: String = "a panel is open"
const WHY_BUSY: String = "mid-action"
const WHY_MOVING: String = "moving"
const WHY_REVIVE: String = "a downed player is within reach (F revives)"
const WHY_NOT_CLERIC: String = "cleric only"
const WHY_RUNNING: String = "a prayer is under way"
const WHY_NO_PRAYER: String = "no prayer to join"
const WHY_JOINED: String = "already praying"
const WHY_CLOSED: String = "the turns have begun"
const WHY_FULL: String = "the circle is full"
const WHY_ZEAL: String = "zeal still lasts"
const WHY_FAITH: String = "not enough faith"
const WHY_COMBAT: String = "in combat"
const WHY_MEDITATING: String = "meditating"
## M10-fix: why a prayer stopped at the gather's end (the cleric alone: Config.PRAYER_MIN_PARTICIPANTS).
const WHY_NOBODY: String = "nobody joined"
## M10b: why the host refused an ANSWER (submit): the sender is in no prayer, it names another prayer, a turn not open yet, a turn
## whose result went out (decided late or by a leave), another participant's turn, a second answer to one turn.
const WHY_NOT_PRAYING: String = "not praying"
const WHY_OTHER_PRAYER: String = "another prayer"
const WHY_NOT_YET: String = "not this turn yet"
const WHY_TURN_OVER: String = "that turn is over"
const WHY_NOT_YOURS: String = "not your turn"
const WHY_ANSWERED: String = "already answered"
## M10b: an answer naming no direction (a malformed ANSWER; the wire decoder refuses it first).
const WHY_BAD_ANSWER: String = "bad answer"
## M10b: the wire's answer for two move keys at once (a wrong answer, answer_of's SEVERAL), after the four Dir.
const WIRE_SEVERAL: int = 4
## M10b: the wire's codes (net/protocol.gd prayer events) of why a participant left or a meditation broke, why a prayer stopped,
## how a turn was decided. Index = code.
const LEAVE_WHYS: PackedStringArray = ["quit", "hit", "down", "dead", "gone", "moved", "a prayer began"]
const STOP_WHYS: PackedStringArray = ["the cleric: quit", "the cleric: hit", "the cleric: down", "the cleric: dead", "the cleric: gone",
	"the altar is gone", WHY_NOBODY]
const ANSWER_WHYS: PackedStringArray = ["ok", "wrong", "late", "left"]


## Something that happened in a step or a tap (Main logs it).
class Event:
	extends RefCounted
	## start, join, leave, stop, turn, answer, end, meditate, meditated, broken.
	var what: String = ""
	var who: int = 0
	var turn: int = -1
	var dir: int = -1
	## answer: "ok", "wrong", "late"; leave / stop / broken: why.
	var why: String = ""
	## M10b: the prayer's clock when it happened (a tap's: before this tick's step; a step's: after it).
	var tick: int = 0


## A prayer that ended or stopped (logs, tests).
class Result:
	extends RefCounted
	var stopped: bool = false
	var why: String = ""
	var lit: int = 0
	var participants: int = 0
	var zeal_pct: int = 0
	var faith: int = 0
	var lamps: PackedInt32Array = PackedInt32Array()


## What a tap tried (start, join, leave, stop, meditate, quit = a meditation stopped) and why it did not ("" = done).
class Tapped:
	extends RefCounted
	var what: String = ""
	var why: String = ""

	func ok() -> bool:
		return why.is_empty()


var data: WorldData
var world_seed: int = Config.DEFAULT_SEED
## Prayers started at this altar (part of the directions' seed).
var prayers: int = 0
## Game ticks stepped.
var clock: int = 0
var phase: int = Phase.IDLE
var phase_ticks: int = 0
var cleric_id: int = 0
## The participants still in, in join order (the cleric first), and everyone who joined this prayer in that order (the turns go
## round it, skipping those who left).
var members: Array[int] = []
var order: Array[int] = []
## The players met (members, meditators, those who left): node instance id -> Player.
var people: Dictionary[int, Player] = {}
## Those who left this prayer -> the tick they left (the left mark); those in it -> the tick they joined (the joined mark).
var left_at: Dictionary[int, int] = {}
var joined_at: Dictionary[int, int] = {}
var directions: PackedInt32Array = PackedInt32Array()
var lamps: PackedInt32Array = PackedInt32Array()
## The tick each lamp changed (its flicker).
var lamp_ticks: PackedInt32Array = PackedInt32Array()
## The turn under way (-1 before the first), its owner, ticks since it opened, whether it is decided.
var turn: int = -1
var turn_owner: int = 0
var turn_ticks: int = 0
var answered: bool = false
## Each participant's move keys on its last tick (a press is a key down from rest).
var prev_dirs: Dictionary[int, Vector2i] = {}
## The tick each player last took damage (combat_refusal).
var hurt_at: Dictionary[int, int] = {}
## Meditating players -> ticks so far.
var meditators: Dictionary[int, int] = {}
## The last prayer's lamps stay shown until this tick (Config.PRAYER_RESULT_SHOW_TICKS).
var shown_until: int = 0
var last: Result
var stats: Dictionary[String, int] = {}
## The events of the last step / tap (Main logs them; cleared by each).
var events: Array[Event] = []
## M10b: offline the owner's move keys answer (true); the host takes the ANSWER requests instead (false, submit), up to `lag_ticks`
## past the window. The answer submitted to the turn under way waits here for the step (its owner, its turn, its Dir or
## WIRE_SEVERAL); `by_answer` = the turn under way was decided by an answer (not late, not left).
var answers_from_keys: bool = true
var lag_ticks: int = 0
## M10-fix (the host; offline 0): a join arriving within this many ticks of the turns' start (turn 0 still on) is still taken.
var join_lag_ticks: int = 0
var _sub_owner: int = 0
var _sub_turn: int = -1
var _sub_dir: int = -1
var by_answer: bool = false


func setup(p_data: WorldData, p_seed: int) -> void:
	data = p_data
	world_seed = p_seed
	lamps.resize(Config.PRAYER_TURNS)
	lamp_ticks.resize(Config.PRAYER_TURNS)
	lamps.fill(Lamp.UNLIT)
	lamp_ticks.fill(0)


func count(key: String, n: int = 1) -> void:
	stats[key] = stats.get(key, 0) + n


func stat(key: String) -> int:
	return stats.get(key, 0)


# --- rules ---------------------------------------------------------------------------------------------------

## Whether feet `feet` stand in the prayer circle of `p_data`'s altar (the surface's, not carried).
static func in_circle(p_data: WorldData, feet: Vector2) -> bool:
	if p_data == null or p_data.map_id != Config.MAP_SURFACE or not p_data.altar_rect.has_area():
		return false
	return feet.distance_to(p_data.altar_center_px()) <= Config.PRAYER_CIRCLE_RADIUS_PX


## Every way a tap of player `p` is refused whatever it would do ("" = none): down, dead, not on the surface, no altar (carried),
## carrying it, outside the circle, a panel open, mid-action (an action that plays on, a dash, a stagger, a purification
## channel), a downed player within revive reach among `players` (F there revives: AltarMove.hold_counts' rule).
static func tap_refusal(p_data: WorldData, p: Player, players: Array[Player]) -> String:
	if p.vitals.life == Vitals.Life.DOWN:
		return WHY_DOWN
	if p.vitals.life == Vitals.Life.DEAD:
		return WHY_DEAD
	if p_data == null or p_data.map_id != Config.MAP_SURFACE or p.data != p_data:
		return WHY_SURFACE
	if p.carrying_altar:
		return WHY_CARRYING
	if not p_data.altar_rect.has_area():
		return WHY_NO_ALTAR
	if not in_circle(p_data, p.sim_position):
		return WHY_OUTSIDE
	if p.ui_locked:
		return WHY_PANEL
	if Skills.busy(p) or p.channel_tick > 0:
		return WHY_BUSY
	for q: Player in players:
		if q != p and q.vitals.life == Vitals.Life.DOWN and q.sim_position.distance_to(p.sim_position) <= Config.REVIVE_REACH_PX:
			return WHY_REVIVE
	return ""


## Whether `p` is in combat now (Config.PRAYER_COMBAT_*): it took damage within PRAYER_COMBAT_HURT_TICKS, or a live heretic of
## `heretics` engaged with someone (a target, or watching the light's edge) stands within PRAYER_COMBAT_REACH_PX of the altar.
func in_combat(p: Player, heretics: Array[HereticSim]) -> bool:
	var id: int = p.get_instance_id()
	if hurt_at.has(id) and clock - hurt_at[id] < Config.PRAYER_COMBAT_HURT_TICKS:
		return true
	if data == null or not data.altar_rect.has_area():
		return false
	var centre: Vector2 = data.altar_center_px()
	for h: HereticSim in heretics:
		if h.alive() and (h.has_target or h.state == HereticSim.State.EDGE) \
				and h.pos.distance_to(centre) <= Config.PRAYER_COMBAT_REACH_PX:
			return true
	return false


## Whether no player of `players` other than `p` who could join stands up in the circle (a cleric's tap then meditates). M10-fix
## (Config.PRAYER_COMPANY_MUST_BE_ABLE_TO_JOIN): one whose prayer's zeal still lasts may not join and is no company.
func alone(p: Player, players: Array[Player]) -> bool:
	for q: Player in players:
		if q == p or not q.vitals.alive() or q.data != data or not in_circle(data, q.sim_position):
			continue
		if Config.PRAYER_COMPANY_MUST_BE_ABLE_TO_JOIN and zeal_blocks(q):
			continue
		return false
	return true


## Whether `p`'s zeal keeps it from a new prayer (starting, joining; Config.PRAYER_ZEAL_BLOCKS). M10-fix: only a prayer's zeal, not
## a meditation's (Config.MEDITATION_ZEAL_BLOCKS_PRAYER).
static func zeal_blocks(p: Player) -> bool:
	return Config.PRAYER_ZEAL_BLOCKS and p.skills.zealous() \
		and (p.skills.zeal_from_prayer or Config.MEDITATION_ZEAL_BLOCKS_PRAYER)


## Whether `p`'s zeal keeps it from a meditation (Config.PRAYER_ZEAL_BLOCKS): any zeal, a prayer's or a meditation's.
static func zeal_blocks_meditation(p: Player) -> bool:
	return Config.PRAYER_ZEAL_BLOCKS and p.skills.zealous()


## Why cleric `p` may not start a prayer now ("" = it may): the tap's refusals, the class, a prayer under way, its own zeal still
## lasting, faith short of Config.PRAYER_FAITH_COST, combat.
func start_refusal(p: Player, players: Array[Player], heretics: Array[HereticSim]) -> String:
	var why: String = tap_refusal(data, p, players)
	if not why.is_empty():
		return why
	if p.class_id() != CLERIC:
		return WHY_NOT_CLERIC
	if running():
		return WHY_RUNNING
	if zeal_blocks(p):
		return WHY_ZEAL
	if p.skills.resource < Config.PRAYER_FAITH_COST:
		return WHY_FAITH
	if in_combat(p, heretics):
		return WHY_COMBAT
	return ""


## Why `p` may not join now ("" = it may): the tap's refusals, no prayer, already in, the gather over (M10-fix, the host: but for
## its lag allowance, late_join_ok), its prayer's zeal still lasting, the circle full (Config.MAX_PLAYERS).
func join_refusal(p: Player, players: Array[Player]) -> String:
	var why: String = tap_refusal(data, p, players)
	if not why.is_empty():
		return why
	if not running():
		return WHY_NO_PRAYER
	if is_member(p.get_instance_id()):
		return WHY_JOINED
	if phase != Phase.GATHER and not late_join_ok(p.get_instance_id()):
		return WHY_CLOSED
	if zeal_blocks(p):
		return WHY_ZEAL
	if members.size() >= Config.MAX_PLAYERS:
		return WHY_FULL
	return ""


## Why `p` may not meditate now ("" = it may): the tap's refusals, moving, a prayer under way, meditating already, any zeal still
## lasting (a prayer's or a meditation's), combat.
func meditate_refusal(p: Player, players: Array[Player], heretics: Array[HereticSim]) -> String:
	var why: String = tap_refusal(data, p, players)
	if not why.is_empty():
		return why
	if p.last_input != Vector2i.ZERO or p.walking:
		return WHY_MOVING
	if running():
		return WHY_RUNNING
	if is_meditating(p.get_instance_id()):
		return WHY_MEDITATING
	if zeal_blocks_meditation(p):
		return WHY_ZEAL
	if in_combat(p, heretics):
		return WHY_COMBAT
	return ""


## M10-fix (the host, Config.PRAYER_JOIN_LAG_TICKS): a join `id` sends that arrives just after the gather (turn 0 open for fewer than
## join_lag_ticks) is still taken: its machine saw the gather when it tapped (the TURN's way down and the PRAY's way up), as an
## answer gets its lag allowance. Not for one who left this prayer. Offline join_lag_ticks is 0 (never).
func late_join_ok(id: int) -> bool:
	return join_lag_ticks > 0 and phase == Phase.TURNS and turn == 0 and turn_ticks < join_lag_ticks and not left_at.has(id)


# --- the zeal ------------------------------------------------------------------------------------------------

## The zeal (percent) of a prayer that ends with `lit` lamps lit and `participants` still in (Config "M10a 열정 크기").
static func zeal_pct(lit: int, participants: int) -> int:
	var crowd: int = mini(maxi(participants - 1, 0) * Config.PRAYER_ZEAL_PER_MEMBER_PCT, Config.PRAYER_ZEAL_MEMBER_CAP_PCT)
	var pct: int = Config.PRAYER_ZEAL_BASE_PCT + (lit - Config.PRAYER_ZEAL_PAR_LAMPS) * Config.PRAYER_ZEAL_PER_LAMP_PCT + crowd
	return maxi(pct, Config.PRAYER_ZEAL_FLOOR_PCT)


## A hit of `amount` with `pct` percent zeal: amount + amount x pct / 100 (rounded half up), at least Config.ZEAL_MIN_BONUS more;
## no zeal (or no damage) = `amount`.
static func zeal_hit(amount: int, pct: int) -> int:
	if pct <= 0 or amount <= 0:
		return amount
	return amount + maxi((amount * pct + 50) / 100, Config.ZEAL_MIN_BONUS)


## The damage a hit of `amount` that player `p` lands deals (its zeal while it lasts; Config "M10a 열정이 세는 피해").
static func zeal_damage(amount: int, p: Player) -> int:
	if p == null or not p.skills.zealous():
		return amount
	return zeal_hit(amount, p.skills.zeal_pct)


# --- the directions ------------------------------------------------------------------------------------------

## The seed of the `n`th prayer of a world of `p_seed`.
static func seed_for(p_seed: int, n: int) -> int:
	return hash([p_seed, n, SALT])


## The Config.PRAYER_TURNS directions (Dir) a prayer of seed `s` shows, drawn in order; a draw that would make a run longer than
## Config.PRAYER_MAX_SAME_RUN is drawn again from the other three.
static func directions_for(s: int) -> PackedInt32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = s
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in Config.PRAYER_TURNS:
		var d: int = rng.randi_range(0, 3)
		if run_at_end(out) >= Config.PRAYER_MAX_SAME_RUN and d == out[out.size() - 1]:
			d = (d + 1 + rng.randi_range(0, 2)) % 4
		out.append(d)
	return out


## Directions `dirs` as their keys ("w,a,s,d"; logs).
static func keys_of(dirs: PackedInt32Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	for d: int in dirs:
		out.append(DIR_KEYS[d] if d >= 0 and d < DIR_KEYS.size() else "?")
	return ",".join(out)


## How many of the last directions of `dirs` are the same as its last one (0 for none).
static func run_at_end(dirs: PackedInt32Array) -> int:
	if dirs.is_empty():
		return 0
	var n: int = 0
	var last_dir: int = dirs[dirs.size() - 1]
	for i: int in range(dirs.size() - 1, -1, -1):
		if dirs[i] != last_dir:
			break
		n += 1
	return n


## The answer the move keys `now` give after `before` (the last tick's): NO_PRESS unless they went down from rest; SEVERAL for two
## axes at once; else the Dir.
static func answer_of(now: Vector2i, before: Vector2i) -> int:
	if before != Vector2i.ZERO or now == Vector2i.ZERO:
		return NO_PRESS
	if now.x != 0 and now.y != 0:
		return SEVERAL
	return DIR_VECTORS.find(now)


# --- the state ----------------------------------------------------------------------------------------------

func running() -> bool:
	return phase != Phase.IDLE


## M10b: the player met under node id `id`, or null (never met, or freed: a session member who left the session mid-prayer).
func person(id: int) -> Player:
	var v: Variant = people.get(id, null)
	if v == null or not is_instance_valid(v):
		return null
	var p: Player = v
	return p


func is_member(id: int) -> bool:
	return members.has(id)


func is_meditating(id: int) -> bool:
	return meditators.has(id)


## The lamps of the prayer under way, or of the last one while it is still shown.
func showing() -> bool:
	return running() or clock < shown_until


## The lamp being answered now (its turn's window open, not decided yet), or -1.
func current_lamp() -> int:
	if phase == Phase.TURNS and not answered and turn >= 0:
		return turn
	return -1


## The direction player `id` must enter now (its turn's window open and not decided), or -1.
func prompt_for(id: int) -> int:
	if current_lamp() >= 0 and turn_owner == id:
		return directions[turn]
	return -1


## Ticks left in the open window (0 when none). M10b: the window its owner's machine shows (the host's lag allowance is not in it).
func window_left() -> int:
	return maxi(Config.PRAYER_ANSWER_WINDOW_TICKS - turn_ticks, 0) if current_lamp() >= 0 else 0


## M10b: the last turn tick an answer counts at (the window, and on the host the lag allowance after it).
func window_end() -> int:
	return Config.PRAYER_ANSWER_WINDOW_TICKS + lag_ticks


## M10b: how long every turn lasts (its window, the allowance, the gap).
func turn_ticks_total() -> int:
	return window_end() + Config.PRAYER_TURN_GAP_TICKS


## M10b: the prayer number the wire carries (its low byte: an answer names the prayer it was for).
func number() -> int:
	return prayers & 0xFF


func lit_count() -> int:
	var n: int = 0
	for s: int in lamps:
		if s == Lamp.LIT:
			n += 1
	return n


## Ticks of meditation `id` has done (0 when it does not meditate).
func meditation_ticks(id: int) -> int:
	return meditators.get(id, 0)


func _event(what: String, who: int, why: String = "") -> Event:
	var e: Event = Event.new()
	e.what = what
	e.who = who
	e.why = why
	e.turn = turn
	e.tick = clock
	events.append(e)
	return e


static func _face(p_data: WorldData, p: Player) -> int:
	return RigData.facing_toward(p.sim_position, p_data.altar_center_px())


# --- the tap ------------------------------------------------------------------------------------------------

## Player `p` tapped F (Config.PRAYER_TAP_MAX_TICKS, Main) with `players` on its map and the map's `heretics`: a participant leaves
## (the cleric: the prayer stops); a meditating player stops; else (the tap's refusals first) during a prayer it joins, with none a
## cleric with someone else in the circle who could join (alone) starts one, anyone else (and a cleric alone) meditates. A
## non-cleric meditates even with a cleric beside it (● R45 "누구나"; README "M10 검토 묵상 범위").
func tap(p: Player, players: Array[Player], heretics: Array[HereticSim]) -> Tapped:
	events.clear()
	var t: Tapped = Tapped.new()
	var id: int = p.get_instance_id()
	if is_member(id):
		t.what = "stop" if id == cleric_id else "leave"
		leave(id, "quit")
		return t
	if is_meditating(id):
		t.what = "quit"
		break_meditation(id, "quit")
		return t
	if running():
		t.what = "join"
		t.why = join_refusal(p, players)
		if t.ok():
			join(p)
	elif p.class_id() == CLERIC and tap_refusal(data, p, players).is_empty() and not alone(p, players):
		t.what = "start"
		t.why = start_refusal(p, players, heretics)
		if t.ok():
			start(p)
	else:
		t.what = "meditate"
		t.why = meditate_refusal(p, players, heretics)
		if t.ok():
			meditate(p)
	if not t.ok():
		count("refused_" + t.what)
	return t


## Cleric `p` starts a prayer (start_refusal said yes): the gather opens, the directions are drawn, every meditation here ends.
func start(p: Player) -> void:
	prayers += 1
	count("started")
	for mid: int in meditators.keys():
		break_meditation(mid, "a prayer began")
	var id: int = p.get_instance_id()
	phase = Phase.GATHER
	phase_ticks = 0
	cleric_id = id
	members = [id]
	order = [id]
	left_at.clear()
	joined_at.clear()
	prev_dirs.clear()
	directions = directions_for(seed_for(world_seed, prayers))
	lamps.fill(Lamp.UNLIT)
	lamp_ticks.fill(clock)
	turn = -1
	turn_owner = 0
	turn_ticks = 0
	answered = false
	by_answer = false
	_sub_turn = -1
	shown_until = 0
	_enter(p)
	_event("start", id)


## `p` joins the prayer (join_refusal said yes); one who left in the gather and joins again goes to the end of the order.
func join(p: Player) -> void:
	var id: int = p.get_instance_id()
	members.append(id)
	order.erase(id)  # who left and joins again (in the gather) goes to the end of the turn order, once
	order.append(id)
	left_at.erase(id)
	count("joined")
	_enter(p)
	_event("join", id)


func _enter(p: Player) -> void:
	var id: int = p.get_instance_id()
	people[id] = p
	prev_dirs[id] = p.last_input
	joined_at[id] = clock
	p.prayer_role = Role.PRAYING
	p.prayer_face = _face(data, p)


## Participant `id` leaves (`why`: quit, hit, down, dead, gone): the cleric stops the prayer; another leaves alone (its later turns go
## to the others; its turn under way fails). Returns whether the prayer stopped.
func leave(id: int, why: String) -> bool:
	if not is_member(id):
		return false
	if id == cleric_id:
		stop("the cleric: " + why)
		return true
	members.erase(id)
	prev_dirs.erase(id)
	left_at[id] = clock
	_release(id)
	count("left")
	_event("leave", id, why)
	if phase == Phase.TURNS and turn_owner == id and not answered:
		_decide(false, "left")
	return false


## The prayer stops (the cleric hit, quit, down, dead or gone; the altar gone): nothing given, no faith spent.
func stop(why: String) -> void:
	for id: int in members:
		_release(id)
	var r: Result = Result.new()
	r.stopped = true
	r.why = why
	r.lit = lit_count()
	r.participants = members.size()
	r.lamps = lamps.duplicate()
	last = r
	members.clear()
	prev_dirs.clear()
	phase = Phase.IDLE
	shown_until = clock + Config.PRAYER_RESULT_SHOW_TICKS
	count("stopped")
	_event("stop", cleric_id, why)


func _release(id: int) -> void:
	var p: Player = person(id)
	if p != null and is_instance_valid(p) and p.prayer_role == Role.PRAYING:
		p.prayer_role = Role.NONE


## M10b (the host): participant `id`'s machine answers turn `t` of prayer `n` (number(): the wire's low byte) with `dir` (a Dir, or
## WIRE_SEVERAL for two keys at once). Taken ("") when it is in this prayer, the turn is the one under way, open and its own, and not
## answered yet: the step judges it (in the window and its lag allowance, window_end; first come first judged). Else why not: a turn
## not open yet (`not this turn yet`), one whose result went out late or because its owner left (`that turn is over`), another's,
## a second answer.
func submit(id: int, n: int, t: int, dir: int) -> String:
	if dir < 0 or dir > WIRE_SEVERAL:
		return WHY_BAD_ANSWER
	if not is_member(id):
		return WHY_NOT_PRAYING
	if n != number():
		return WHY_OTHER_PRAYER
	if phase != Phase.TURNS or t > turn:
		return WHY_NOT_YET
	if t < turn or (answered and not by_answer):
		return WHY_TURN_OVER
	if turn_owner != id:
		return WHY_NOT_YOURS
	if answered or _sub_turn == turn:
		return WHY_ANSWERED
	_sub_owner = id
	_sub_turn = turn
	_sub_dir = dir
	count("answers_taken")
	return ""


## Player `p` took damage (a hit that landed, a poison tick): its combat clock starts over; a participant leaves (the cleric: it
## stops); a meditation breaks.
func on_hurt(p: Player) -> void:
	var id: int = p.get_instance_id()
	hurt_at[id] = clock
	if is_member(id):
		leave(id, "hit")
	if is_meditating(id):
		break_meditation(id, "hit")


# --- meditation ---------------------------------------------------------------------------------------------

func meditate(p: Player) -> void:
	var id: int = p.get_instance_id()
	people[id] = p
	meditators[id] = 0
	p.prayer_role = Role.MEDITATING
	p.prayer_face = _face(data, p)
	count("meditations")
	_event("meditate", id)


func break_meditation(id: int, why: String) -> void:
	if not meditators.has(id):
		return
	meditators.erase(id)
	var p: Player = person(id)
	if p != null and is_instance_valid(p) and p.prayer_role == Role.MEDITATING:
		p.prayer_role = Role.NONE
	count("meditations_broken")
	_event("broken", id, why)


func _step_meditations(players: Array[Player]) -> void:
	for id: int in meditators.keys():
		var p: Player = _find(players, id)
		if p == null:
			break_meditation(id, "gone")
			continue
		if not p.vitals.alive():
			break_meditation(id, WHY_DOWN if p.vitals.life == Vitals.Life.DOWN else WHY_DEAD)
			continue
		if p.last_input != Vector2i.ZERO or p.vitals.dashing() or p.action_anim >= 0 or p.channel_tick > 0 \
				or p.carrying_altar or not in_circle(data, p.sim_position):
			break_meditation(id, "moved")
			continue
		meditators[id] += 1
		if meditators[id] >= Config.MEDITATE_TICKS:
			meditators.erase(id)
			p.prayer_role = Role.NONE
			p.skills.add_zeal(Config.MEDITATE_ZEAL_PCT, Config.MEDITATE_ZEAL_TICKS, false)
			count("meditated")
			_event("meditated", id)


# --- one tick ------------------------------------------------------------------------------------------------

static func _find(players: Array[Player], id: int) -> Player:
	for q: Player in players:
		if is_instance_valid(q) and q.get_instance_id() == id:
			return q
	return null


## One game tick after `players` (the players on the altar's map, the surface) have stepped. Returns this tick's events.
func step(players: Array[Player]) -> Array[Event]:
	events.clear()
	clock += 1
	if running():
		if data == null or not data.altar_rect.has_area():
			stop("the altar is gone")
		else:
			for id: int in members.duplicate():
				var p: Player = _find(players, id)
				var why: String = ""
				if p == null:
					why = "gone"
				elif p.vitals.life == Vitals.Life.DOWN:
					why = WHY_DOWN
				elif p.vitals.life == Vitals.Life.DEAD:
					why = WHY_DEAD
				if not why.is_empty() and leave(id, why):
					break
	_step_meditations(players)
	if phase == Phase.GATHER:
		phase_ticks += 1
		if phase_ticks >= Config.PRAYER_GATHER_TICKS:
			if members.size() < Config.PRAYER_MIN_PARTICIPANTS:
				_gathered_alone(players)
			else:
				phase = Phase.TURNS
				phase_ticks = 0
				_open_turn(0)
	elif phase == Phase.TURNS:
		phase_ticks += 1
		turn_ticks += 1
		if not answered and turn_ticks <= window_end():
			var ans: int = NO_PRESS
			if not answers_from_keys:
				# M10b: the ANSWER this turn's owner's machine sent (submit), judged here like a key.
				if _sub_turn == turn and _sub_owner == turn_owner:
					ans = SEVERAL if _sub_dir == WIRE_SEVERAL else _sub_dir
			else:
				var owner: Player = _find(players, turn_owner)
				if owner != null:
					var before: Vector2i = prev_dirs.get(turn_owner, Vector2i.ZERO)
					ans = answer_of(owner.last_input, before)
			if ans != NO_PRESS:
				_decide(ans == directions[turn], "ok" if ans == directions[turn] else "wrong")
		if not answered and turn_ticks >= window_end():
			_decide(false, "late")
		if turn_ticks >= turn_ticks_total():
			if turn + 1 < Config.PRAYER_TURNS:
				_open_turn(turn + 1)
			else:
				_end()
	for id: int in members:
		var q: Player = _find(players, id)
		if q != null:
			prev_dirs[id] = q.last_input
	return events


## M10-fix (Config.PRAYER_MIN_PARTICIPANTS, ● R45 "혼자일 때 → 묵상"): the gather ended with the cleric alone (nobody joined, or all who
## did left): no prayer. It stops (`nobody joined`: nothing given, no faith spent) and the cleric meditates instead, when he may (up
## in the circle, no zeal, not pressing a move key; the combat was checked at the start and a hit would have stopped it).
func _gathered_alone(players: Array[Player]) -> void:
	var cleric: Player = _find(players, cleric_id)
	stop(WHY_NOBODY)
	if cleric != null and tap_refusal(data, cleric, players).is_empty() and not zeal_blocks_meditation(cleric) \
			and cleric.last_input == Vector2i.ZERO and not cleric.walking:
		meditate(cleric)


## Turn `i` opens: its owner is the next participant still in after the last owner in join order (turn 0: the first still in).
func _open_turn(i: int) -> void:
	var from: int = order.find(turn_owner) + 1 if i > 0 else 0
	for k: int in order.size():
		var cand: int = order[(from + k) % order.size()]
		if members.has(cand):
			turn_owner = cand
			break
	turn = i
	turn_ticks = 0
	answered = false
	by_answer = false
	_sub_turn = -1
	var e: Event = _event("turn", turn_owner)
	e.dir = directions[i]


## The turn under way is decided: its lamp lit (`ok`) or out (`why`: wrong, late, left).
func _decide(ok: bool, why: String) -> void:
	answered = true
	by_answer = why == "ok" or why == "wrong"
	lamps[turn] = Lamp.LIT if ok else Lamp.OUT
	lamp_ticks[turn] = clock
	count("lamps_lit" if ok else "lamps_out")
	var e: Event = _event("answer", turn_owner, why)
	e.dir = directions[turn]


## The last turn's gap is over: everyone still in gets zeal (zeal_pct of the lamps lit and the head count) for
## Config.PRAYER_ZEAL_TICKS, and the cleric's faith is spent (too little now: nothing is given).
func _end() -> void:
	var r: Result = Result.new()
	r.lit = lit_count()
	r.participants = members.size()
	r.lamps = lamps.duplicate()
	var cleric: Player = person(cleric_id)
	if cleric != null and is_instance_valid(cleric) and cleric.skills.spend(Config.PRAYER_FAITH_COST):
		r.faith = Config.PRAYER_FAITH_COST
		r.zeal_pct = zeal_pct(r.lit, r.participants)
		for id: int in members:
			var p: Player = person(id)
			if p != null and is_instance_valid(p):
				p.skills.add_zeal(r.zeal_pct, Config.PRAYER_ZEAL_TICKS, true)
		count("completed")
	else:
		r.why = WHY_FAITH
		count("fizzled")
	for id: int in members:
		_release(id)
	last = r
	members.clear()
	prev_dirs.clear()
	phase = Phase.IDLE
	turn = -1
	answered = false
	shown_until = clock + Config.PRAYER_RESULT_SHOW_TICKS
	_event("end", cleric_id, r.why)


## Whether the altar may not be lifted now (a prayer under way or anyone meditating at it: README "M10a F").
func blocks_lift() -> bool:
	return running() or not meditators.is_empty()


func describe() -> String:
	return "%s t=%d turn=%d owner=%d members=%d lamps=%s lit=%d" % [PHASE_NAMES[phase], phase_ticks, turn, turn_owner,
		members.size(), lamps, lit_count()]

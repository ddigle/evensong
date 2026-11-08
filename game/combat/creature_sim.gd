class_name CreatureSim
extends RefCounted
## One creature (M11a): its state and the numbers its kind gives it (one row of Config.CREATURES). Combat/creatures.gd runs its
## behaviour each game tick; the picture is actors/creature_view.gd. Values are PROVISIONAL (Config "M11a").
##
## States: IDLE (it stands at or near home, Creatures draws how long), WANDER (it walks to a spot near home), FLEE (a burst: it
## runs from `flee_from`, faster than a player walks), REST (out of breath: it stands, a player walking catches it; only a hit
## moves it), DEAD (it lies for Config.CREATURE_CORPSE_TICKS, then is gone).

enum State { IDLE, WANDER, FLEE, REST, DEAD }

const STATE_NAMES: PackedStringArray = ["idle", "wander", "flee", "rest", "dead"]
## IMPL: the view's walk frames take this many ticks each (the heretic's HereticSim.WALK_FRAME_TICKS); while it flees,
## Config.CREATURE_FLEE_FRAME_TICKS (M11 creature art). The walk sheets have WALK_FRAMES frames a direction (PixelLab 16차).
const WALK_FRAME_TICKS: int = 7
const WALK_FRAMES: int = 6
## The frame of a creature not walking: the sheet's standing picture (its rotation), not a walk frame (CreatureView.sheet).
const STAND: int = -1

var id: int = 0
## Its row of Config.CREATURES.
var kind: StringName = &""
var pos: Vector2 = Vector2.ZERO
## Where it wanders around (the spot it was put down).
var home: Vector2 = Vector2.ZERO
var facing: int = RigData.Dir.SOUTH
var state: int = State.IDLE
var state_ticks: int = 0
var hp: int = 0
## The spot a WANDER walks to, the point a FLEE runs from.
var target: Vector2 = Vector2.ZERO
var flee_from: Vector2 = Vector2.ZERO
## Ticks the IDLE lasts (drawn from the herd's stream).
var idle_ticks: int = 0
var walking: bool = false
## Skills that stop or slow a heretic do it here too (README "M11a 기절·둔화"), by Arena's rule: ticks left, percent off its speed.
var stun_ticks: int = 0
var slow_pct: int = 0
var slow_ticks: int = 0
## A thrown poison (Arena._splash): damage per poison tick, ticks left, ticks to the next, who threw it (node instance id: the
## killing blow's class is the thrower's).
var poison_damage: int = 0
var poison_ticks: int = 0
var poison_timer: int = 0
var poison_by: int = 0
## Display: ticks since it was put down (walk frames), hit flash ticks left.
var clock: int = 0
var flash_ticks: int = 0
## M11b: it came down in the rare zone and stays in it (Creatures.can_walk). A test flag's creature is not bound.
var bound: bool = false
## M11b: a snare holds it where it stands for this many ticks more (Capture.begin), thrown from this point (the rope is drawn to it).
var hold_ticks: int = 0
var held_from: Vector2 = Vector2.ZERO
## M11c: the node instance id of the player whose snare holds it (0 = nobody): the batches name its slot, the rope is drawn to it.
var held_by: int = 0
## M11b: display: ticks left of the refused mark (a blow that does nothing to it, Creatures.refuse).
var refused_ticks: int = 0


func alive() -> bool:
	return state != State.DEAD


## Its kind's row (Config.CREATURES).
func row() -> Dictionary:
	return Config.CREATURES[kind]


func rare() -> bool:
	var v: bool = row()["rare"]
	return v


func num_f(key: String) -> float:
	var v: float = row()[key]
	return v


func num_i(key: String) -> int:
	var v: int = row()[key]
	return v


func hp_max() -> int:
	return num_i("hp")


## Its walking speed now (`speed`, less its slow while slowed).
func speed_now(speed: float) -> float:
	if not slowed():
		return speed
	return speed * float(100 - clampi(slow_pct, 0, 100)) / 100.0


## The frame shown now: STAND while it does not walk (a corpse too), else the walk's frame (0 .. WALK_FRAMES - 1) by its clock, each
## WALK_FRAME_TICKS long, Config.CREATURE_FLEE_FRAME_TICKS while it flees (a client has the state and the walking bit from the batch and the
## host's tick for the clock: the same frame).
func frame() -> int:
	if not walking:
		return STAND
	var each: int = Config.CREATURE_FLEE_FRAME_TICKS if state == State.FLEE else WALK_FRAME_TICKS
	return (clock / each) % WALK_FRAMES


## Gone for good (it has lain long enough).
func finished() -> bool:
	return state == State.DEAD and state_ticks >= Config.CREATURE_CORPSE_TICKS


func stunned() -> bool:
	return alive() and stun_ticks > 0


func slowed() -> bool:
	return alive() and slow_ticks > 0 and slow_pct > 0


func poisoned() -> bool:
	return alive() and poison_ticks > 0


## M11b: a snare holds it now.
func held() -> bool:
	return alive() and hold_ticks > 0


## M11b: its HP is low enough for a snare (Config.CAPTURE_HP_PCT of its full HP, or less) and it is a rare one.
func can_be_taken() -> bool:
	return alive() and rare() and hp * 100 <= hp_max() * Config.CAPTURE_HP_PCT


func describe() -> String:
	return "%s %d %s hp=%d at %.1f,%.1f facing=%s" % [kind, id, STATE_NAMES[state], hp, pos.x, pos.y, RigData.DIR_NAMES[facing]]

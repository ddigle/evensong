class_name Capture
extends RefCounted
## M11b: the archer's capture (● game-concept §3, §4 "희귀 생물 포획·사냥은 아처만"; ○ gameplay-design §3.4 "포획: 아처 전용 도구(올가미·덫). 희귀 생물의 HP를
## 일정 이하로 낮춘 뒤 포획 시도 → 컬렉션 등록"; the numbers and the rest PROVISIONAL, Config "M11b"). Pure rules on Player, CreatureSim and
## Creatures, like items/potions.gd: the offline game (core/main.gd) calls begin() when the throw starts and land() on its impact frame.
## M11c's host will call the same.
##
## A left click with the snare selected picks the creature under the mouse (target_at) and goes through refusal(): nothing is spent
## and nothing starts unless the player is up and free, an archer, and the creature is a rare one in reach with its HP at or below
## Config.CAPTURE_HP_PCT. Then the throw plays (Config.CAPTURE_ANIM); begin() holds the creature where it stands, so what is in reach at
## the click stays in reach. On the impact frame land() checks everything again (the M6 drink's rule: a creature killed meanwhile, a
## snare gone: nothing is spent), takes one snare and the creature, no dice: the herd registers the capture, its place waits for
## its respawn, and the rare material goes into the inventory (what does not fit lies on the creature's tile). A hit on the archer
## cuts the throw off: nothing spent, and the hold runs out by itself.
##
## ○ 덫 and ○ the herbalist's handover are not built (README "M11b 덫", "M11b 인계").

const SNARE: StringName = &"snare"
## Why a capture was refused (logs, tests).
const WHY_NOT_UP: String = "not up"
const WHY_CARRYING: String = "carrying the altar"
const WHY_PRAYING: String = "praying"
const WHY_PANEL: String = "a panel is open"
const WHY_NOT_ARCHER: String = "archer only"
const WHY_NO_SNARE: String = "no snare"
const WHY_NOTHING: String = "nothing there"
const WHY_PREY: String = "prey cannot be captured"
const WHY_REACH: String = "out of reach"
const WHY_HEALTHY: String = "too healthy"
const WHY_GONE: String = "the creature is gone"


## What a capture did.
class Landed:
	extends RefCounted
	## "" = captured; else why not (nothing was spent).
	var why: String = ""
	var kind: StringName = &""
	var at: Vector2 = Vector2.ZERO
	## The material that went into the inventory, and what lay down for want of room.
	var given: int = 0
	var dropped: int = 0

	func ok() -> bool:
		return why.is_empty()


static func is_snare(id: StringName) -> bool:
	return id == SNARE


## The tick of its action on which a snare lands.
static func impact_tick() -> int:
	return Config.CAPTURE_IMPACT_FRAME * Config.ACTION_FRAME_TICKS


## The live creature of `herd` the mouse at `mouse` is on: the one whose figure's middle (Creatures.aim_point) is nearest it, within its
## hit box's larger half + Config.CAPTURE_GRAB_PX; the first in the list between two as near. null = none.
static func target_at(herd: Creatures, mouse: Vector2) -> CreatureSim:
	if herd == null:
		return null
	var best: CreatureSim = null
	var best_d: float = INF
	for c: CreatureSim in herd.list:
		if not c.alive():
			continue
		var d: float = Creatures.aim_point(c).distance_to(mouse)
		if d <= maxf(c.num_f("hit_radius_px"), c.num_f("hit_height_px") / 2.0) + Config.CAPTURE_GRAB_PX and d < best_d:
			best = c
			best_d = d
	return best


## Whether creature `c` is within the snare's reach of player `p`: Config.CAPTURE_REACH_PX, feet to feet, and nothing that stops a shot
## between their body points.
static func in_reach(p: Player, c: CreatureSim) -> bool:
	return p.sim_position.distance_to(c.pos) <= Config.CAPTURE_REACH_PX \
			and Combat.line_clear(p.data, Combat.body_point(p.sim_position), Combat.body_point(c.pos))


## Why player `p` may not snare creature `c` now ("" = it may).
static func refusal(p: Player, c: CreatureSim) -> String:
	if not p.vitals.alive():
		return WHY_NOT_UP
	if p.carrying_altar:
		return WHY_CARRYING
	if p.prayer_role == Prayer.Role.PRAYING:
		return WHY_PRAYING
	if p.ui_locked:
		return WHY_PANEL
	if p.class_id() != Config.HUNTER_CLASS:
		return WHY_NOT_ARCHER
	if p.inventory.count_of(SNARE) < 1:
		return WHY_NO_SNARE
	if c == null or not c.alive():
		return WHY_NOTHING
	if not c.rare():
		return WHY_PREY
	if not in_reach(p, c):
		return WHY_REACH
	if not c.can_be_taken():
		return WHY_HEALTHY
	return ""


## The throw of player `p` at creature `c` started: `c` is held until the impact frame (Config.CAPTURE_HOLD_SLACK_TICKS past it).
static func begin(p: Player, herd: Creatures, c: CreatureSim) -> void:
	if herd != null and c != null:
		herd.hold(c, impact_tick() + Config.CAPTURE_HOLD_SLACK_TICKS, Combat.body_point(p.sim_position))


## Player `p`'s throw at the creature with id `creature_id` of `herd` reaches its impact frame.
static func land(p: Player, herd: Creatures, creature_id: int) -> Landed:
	var r: Landed = Landed.new()
	var c: CreatureSim = herd.by_id(creature_id) if herd != null else null
	r.why = WHY_GONE if c == null or not c.alive() else refusal(p, c)
	if not r.ok():
		return r
	if not Potions.take_one(p.inventory, p.action_slot, SNARE, ItemDB.Grade.NONE):
		r.why = WHY_NO_SNARE
		return r
	r.kind = c.kind
	r.at = c.pos
	herd.capture(c)
	r.dropped = p.inventory.add(Config.RARE_MATERIAL, Config.CAPTURE_MATERIAL_COUNT)
	r.given = Config.CAPTURE_MATERIAL_COUNT - r.dropped
	if r.dropped > 0:
		herd.lay_down(r.at, Config.RARE_MATERIAL, r.dropped)
	return r

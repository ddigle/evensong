class_name WorldProgress
extends RefCounted
## M12a: what the world has achieved (the shared track, ● game-concept §9.2 "공동 트랙: 제단 진행. 보스 = 문"): the altar's tier (● §9.3 R49:
## the only thing that raises it is the boss drop, the relic bench's altar upgrade, Crafting) and whether the boss was defeated (the flag
## M12 sets, Config.BOSS_RESPAWNS off: it does not come back). One per world, like the collection: WorldData.progress, the same object on the
## surface's and the dungeon's data (offline Main puts it there with the arenas), so the surface's light reads the tier and the dungeon's
## fight sets the flag. A world with none (a test's bare map, a session until M12c) is tier 0 and nothing defeated: every rule as before.
##
## The tier is the world's, not the altar's or a player's: carrying the altar and putting it down keeps it (the light it gives is the tier's,
## SafeZone.for_world), a death loses nothing, a new world starts at 0. Not in WorldData.content_hash or a snapshot in M12a (sessions never
## change it until M12c, which brings it to the wire).

## The altar's tier (0 .. Config.ALTAR_TIER_MAX).
var altar_tier: int = 0
## The boss of the first dungeon was killed (it does not come back: Config.BOSS_RESPAWNS).
var boss_defeated: bool = false
## Moves whenever something here changed (views redraw on it).
var revision: int = 0


## The progress of the world `d` belongs to (null: none).
static func of(d: WorldData) -> WorldProgress:
	return d.progress if d != null else null


## The altar tier of the world `d` belongs to (0 without progress).
static func tier_of(d: WorldData) -> int:
	var p: WorldProgress = of(d)
	return p.altar_tier if p != null else 0


## Whether the boss of the world `d` belongs to was defeated.
static func boss_dead(d: WorldData) -> bool:
	var p: WorldProgress = of(d)
	return p != null and p.boss_defeated


## The safe radius (px) of the world `d` belongs to: its tier's (Config.safe_radius_px_at).
static func radius_px(d: WorldData) -> float:
	return Config.safe_radius_px_at(tier_of(d))


## Whether the altar can go up a tier (below Config.ALTAR_TIER_MAX).
func can_raise() -> bool:
	return altar_tier < Config.ALTAR_TIER_MAX


## The altar goes up one tier (refused at the maximum: false, nothing changes).
func raise_altar() -> bool:
	if not can_raise():
		return false
	altar_tier += 1
	revision += 1
	return true


## The boss fell (once; false when it already had).
func defeat_boss() -> bool:
	if boss_defeated:
		return false
	boss_defeated = true
	revision += 1
	return true


func describe() -> String:
	return "altar_tier=%d boss_defeated=%s" % [altar_tier, boss_defeated]

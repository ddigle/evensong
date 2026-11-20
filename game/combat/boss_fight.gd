class_name BossFight
extends RefCounted
## M12a: the heretic leader's fight in the first dungeon (● game-concept §6, §11, §12; every number and rule PROVISIONAL, Config "M12a"):
## its room (world/boss_room.gd), the boss (combat/boss_sim.gd), its three attacks with their telegraphs (cleave, fire volley, burning
## ground), phase 2 and its two heretics, the reset, its death and the relics, and the cracked support pillars (● §12 R49: the miner
## breaks them, their debris falls). The arena of its map owns it (Arena.boss: offline Main makes one for the dungeon; a session has none
## until M12c) and calls it from every path that can hit a heretic, so every attack of every class and skill reaches the boss (zeal, the
## tier-1 weapon's damage and the collection's arrow benefit are in the damage those paths already pass), and steps it after its heretics.
## Pure data and rules like the arena; the views are combat/boss_view.gd and combat/boss_fight_view.gd.
##
## Determinism: its own RandomNumberGenerator (the world seed, the dungeon's map id and Config.BOSS_SALT: tests/test_boss_keeps.gd proves the
## heretic spawns, prayer directions and creature spawns are main's) and the game clock (ticks).
##
## The pillars stand on WorldData.blockers (walking, dashing, the heretics and the boss, shots and sight stop there like at a station). A
## blow on one is the miner's alone (● gameplay-design §3.0 R11 class-only column "보스전 지형 상호작용"): the miner's pickaxe (basic or
## tier-1, Arena.player_attack) and a miner's damaging skill (the slam, the heavy strike or any weapon skill a miner swings, the rockfall)
## that reaches it count a hit; anyone else's swing, weapon skill or shot that meets it shows the refused mark (the M11b creature rule's
## EffectMarks.Kind.REFUSED) and does nothing. Config.BOSS_PILLARS "hits_per_state" hits a state; the third state change breaks it: dust
## over its fall circle for the telegraph, then the debris lands (Config "M12a" BOSS_PILLARS, BOSS debris_*). Without a miner the boss is
## still beaten by fighting (lower ceiling, no block).
##
## M12c (sessions): the host's dungeon arena owns one too (SessionHost._setup_combat) and with the arena's `logging` on every change a client
## draws goes out as a wire event on the arena's shot events (NetProtocol.ShotEvent kinds BOSS_ATTACK .. PILLAR: an attack's start with its
## telegraph's numbers, an attack or the fire stopped early, a bolt let go and stopped, a burning circle, a pillar's state after a blow, a
## refusal, its breaking, its debris landing, its restoring); its body goes in the map's enemy batch (NetProtocol.boss_of). The dungeon's
## snapshot carries its site (site_bytes: the room, the home, the pillars and their hits). A client draws a mirror (BossFight.mirror: never
## stepped; net/net_boss.gd fills it from those messages) through the same views.

## M12c: the boss site a dungeon snapshot carries (net/world_snapshot.gd): the room (its rect as DungeonGen made it, the face row
## included), the boss's home tile, the pillars' tiles in order and each one's hits and whether it lies as rubble.
class Site:
	extends RefCounted
	var room: Rect2i = Rect2i()
	var home: Vector2i = Vector2i.ZERO
	var pillars: Array[Vector2i] = []
	var hits: PackedInt32Array = PackedInt32Array()
	var fallen: Array[bool] = []

	## The room as a layout (its walkable rows, home and pillars; no doorways: a client never picks pillars).
	func layout() -> BossRoom.Layout:
		var out: BossRoom.Layout = BossRoom.Layout.new()
		out.room = room
		out.walk = BossRoom.walk_of(room)
		out.home_tile = home
		out.pillars = pillars.duplicate()
		return out

	func describe() -> String:
		var parts: PackedStringArray = []
		for i: int in pillars.size():
			parts.append("%d,%d:%d%s" % [pillars[i].x, pillars[i].y, hits[i], "R" if fallen[i] else ""])
		return "room=%d,%d %dx%d home=%d,%d pillars=%s" % [room.position.x, room.position.y, room.size.x, room.size.y, home.x, home.y,
			" ".join(parts)]


## One cracked support pillar on its tile.
class Pillar:
	extends RefCounted
	var tile: Vector2i = Vector2i.ZERO
	## Landed miner blows.
	var hits: int = 0
	## Ticks left of the dust before the debris lands (-1 = not falling).
	var falling: int = -1
	## The debris landed: rubble now (walkable, Config.PILLAR_RUBBLE_BLOCKS).
	var fallen: bool = false
	## Who broke it (node instance id: the debris's threat on the boss is his).
	var broken_by: int = 0
	## Display: the refused mark's ticks left, a hit's flash.
	var refused_ticks: int = 0
	var flash_ticks: int = 0

	## 0 intact, 1 cracked, 2 badly cracked, 3 broken (a stub and rubble; falling or fallen).
	func look() -> int:
		if fallen or falling >= 0:
			return 3
		return mini(hits / hits_per_state(), 2)

	## It still blocks (the stub stands while its debris is coming down).
	func blocks() -> bool:
		return not fallen or Config.PILLAR_RUBBLE_BLOCKS

	## A blow may land (neither breaking nor broken).
	func whole() -> bool:
		return not fallen and falling < 0

	func centre() -> Vector2:
		return (Vector2(tile) + Vector2(0.5, 0.5)) * Config.TILE

	static func hits_per_state() -> int:
		return maxi(roundi(Config.BOSS_PILLARS["hits_per_state"]), 1)


## A fire bolt of the volley (code-drawn: combat/boss_fight_view.gd).
class Bolt:
	extends RefCounted
	var id: int = 0
	## Ground point (the body-point height; drawn Config.SHOT_DRAW_LIFT_PX higher like a shot) and unit direction.
	var pos: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.RIGHT
	var speed: float = 0.0
	var left: int = 0
	var damage: int = 0
	var done: bool = false
	## "", "wall", "player", "spent", "quiet" (the fight ended or reset).
	var stopped_by: String = ""
	## Players it passed while they dodged (node instance ids: a dash through it).
	var dodged: Dictionary[int, bool] = {}
	## M12c: the tick it was let go, where from and its direction's angle (a late client gets it as a let-go event).
	var born: int = 0
	var origin: Vector2 = Vector2.ZERO
	var angle: float = 0.0


## A circle of the burning ground: it waits `telegraph` ticks (the warning), erupts, then burns `show` ticks (display only).
class Circle:
	extends RefCounted
	var id: int = 0
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 0.0
	var age: int = 0
	var telegraph: int = 0
	var damage: int = 0
	var show: int = 0
	var erupted: bool = false
	## Players it hurt when it erupted.
	var hits: int = 0
	## M12c: the tick it was put down (age 0).
	var born: int = 0

	func left() -> int:
		return maxi(telegraph - age, 0)


## Where a pillar's debris landed (display only: the dust settling, combat/boss_fight_view.gd).
class Debris:
	extends RefCounted
	var id: int = 0
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 0.0
	var age: int = 0
	var boss_hit: bool = false
	var players_hit: int = 0

## IMPL: how long a landed debris and an erupted circle stay drawn (ticks), the boss's pierce key in a piercing arrow's list (heretic ids
## count from 1 up, creature ids negated: 0 is free) and the add spots tried around the boss (px) in order.
const DEBRIS_SHOW_TICKS: int = 30
const PIERCE_KEY: int = 0
const ADD_SPOTS: Array[Vector2] = [Vector2(28, 0), Vector2(-28, 0), Vector2(0, 24), Vector2(0, -24), Vector2(24, 20), Vector2(-24, 20),
	Vector2(24, -20), Vector2(-24, -20), Vector2(44, 0), Vector2(-44, 0)]

## The arena that owns it (weak: the arena holds the fight, Arena.boss; a strong reference both ways would never be freed).
var _arena: WeakRef = null
var data: WorldData
var room: BossRoom.Layout
## Null when the dungeon has no boss room.
var sim: BossSim = null
var pillars: Array[Pillar] = []
var bolts: Array[Bolt] = []
var circles: Array[Circle] = []
var debris: Array[Debris] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var next_id: int = 1
## Counters for logs and tests.
var stats: Dictionary[String, int] = {}
## What happened since Main last took them (it prints them as EVENSONG_BOSS lines).
var events: PackedStringArray = []
## World edits waiting for the arena to return (a relic that did not fit, lying at its player's feet).
var pending_edits: Array[EditLog.WorldEdit] = []
## The relics given at the kill: per player node instance id, into the inventory and onto the ground.
var relics_given: Dictionary[int, int] = {}
var relics_dropped: Dictionary[int, int] = {}
## The players of the map at the last step (a blow that wakes it counts them).
var _players: Array[Player] = []
## Test hooks (--test-boss-hp, --test-boss-attack; tests): its HP when it wakes (0 = its max) and the only attack it uses (NONE = drawn).
var test_hp: int = 0
var test_attack: int = BossSim.Attack.NONE
## Test hook (tests that only count blows): awake, it neither walks, picks a target nor attacks (its timers, hits and effects run on).
var frozen: bool = false
## M12c: the arena tick its last step ran on (a pillar breaking before this tick's step lands a tick sooner: pillar_event's dust count).
var _step_tick: int = -1


## For the dungeon of world seed `world_seed` on `p_arena` (its data): the room from the seed (BossRoom.for_seed).
func setup(p_arena: Arena, world_seed: int) -> void:
	setup_with(p_arena, BossRoom.for_seed(world_seed), world_seed)


## For a given room (tests put one on a bare map).
func setup_with(p_arena: Arena, p_room: BossRoom.Layout, world_seed: int) -> void:
	_arena = weakref(p_arena)
	data = p_arena.data
	data.boss_fight = self  # M12c: the dungeon's snapshot carries its site
	room = p_room
	rng.seed = hash([world_seed, Config.MAP_DUNGEON, Config.BOSS_SALT])
	stats.clear()
	events.clear()
	pending_edits.clear()
	bolts.clear()
	circles.clear()
	debris.clear()
	pillars.clear()
	_unblock_all()
	sim = null
	if not room.has_room():
		return
	for t: Vector2i in room.pillars:
		var p: Pillar = Pillar.new()
		p.tile = t
		pillars.append(p)
	sim = BossSim.new()
	sim.home = room.home_feet()
	sim.pos = sim.home
	sim.hp_max = BossSim.hp_for(1)
	sim.hp = sim.hp_max
	if WorldProgress.boss_dead(data) and not Config.BOSS_RESPAWNS:
		sim.state = BossSim.State.DEAD  # killed before (the flag): it lies there, its pillars as rubble
		sim.state_ticks = BossSim.num_i("reset_ticks")
		sim.hp = 0
		for p: Pillar in pillars:
			p.fallen = true
	_block_standing()


## M12c: a client's mirror of the host's fight on `p_arena` (Arena.mirror) from a snapshot's `site`: the room, the boss asleep at home (dead and
## lying there when `defeated`), the pillars with their hits and rubble, blocking where they stand (this client's prediction walks round
## them like the host's players). Never stepped: net/net_boss.gd sets what the views draw from the host's messages.
static func mirror(p_arena: Arena, site: Site, defeated: bool) -> BossFight:
	var f: BossFight = BossFight.new()
	f._arena = weakref(p_arena)
	f.data = p_arena.data
	f.data.boss_fight = f
	f.room = site.layout()
	for i: int in site.pillars.size():
		var p: Pillar = Pillar.new()
		p.tile = site.pillars[i]
		p.hits = site.hits[i]
		p.fallen = site.fallen[i]
		f.pillars.append(p)
	f.sim = BossSim.new()
	f.sim.home = f.room.home_feet()
	f.sim.pos = f.sim.home
	f.sim.hp_max = BossSim.hp_for(1)
	f.sim.hp = f.sim.hp_max
	if defeated:
		f.sim.state = BossSim.State.DEAD
		f.sim.state_ticks = BossSim.num_i("reset_ticks")
		f.sim.hp = 0
	f._block_standing()
	return f


## M12c: this fight's site as its map's snapshot carries it (Site; the hits cut to the broken state's).
func site() -> Site:
	var out: Site = Site.new()
	if room == null or not room.has_room():
		return out
	out.room = room.room
	out.home = room.home_tile
	for p: Pillar in pillars:
		out.pillars.append(p.tile)
		out.hits.append(mini(p.hits, Pillar.hits_per_state() * 3))
		out.fallen.append(p.fallen)
	return out


## M12c: pillar `i` as the host says it is (a client's mirror: its hits, its dust ticks left (-1 = none), rubble); blocks where it stands.
func set_pillar_state(i: int, hits: int, falling: int, fallen: bool) -> void:
	if i < 0 or i >= pillars.size():
		return
	var p: Pillar = pillars[i]
	p.hits = hits
	p.falling = falling
	p.fallen = fallen
	_block_standing()


## The arena that owns it.
func arena() -> Arena:
	if _arena == null:
		return null
	var a: Arena = _arena.get_ref()
	return a


func stat(key: String) -> int:
	var v: int = stats.get(key, 0)
	return v


func count(key: String, n: int = 1) -> void:
	var v: int = stats.get(key, 0)
	stats[key] = v + n


func note(text: String) -> void:
	events.append(text)


## M12c: an event a client draws goes out with the arena's shot events (a session host's arena: `logging` on; offline and a mirror: none).
func _wire(e: NetProtocol.ShotEvent) -> void:
	var a: Arena = arena()
	if a != null and a.logging:
		a.shot_events.append(e)


func _now() -> int:
	var a: Arena = arena()
	return a.now if a != null else 0


## M12c: the attack under way as its start event (a late client's too: its start tick is now less the ticks it ran).
func attack_event() -> NetProtocol.ShotEvent:
	var b: BossSim = sim
	var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	e.kind = NetProtocol.ShotEvent.Kind.BOSS_ATTACK
	e.tick = _now() - b.state_ticks
	e.sub = b.attack
	e.face = b.facing
	e.pos = b.pos
	e.angle = b.attack_dir.angle()
	e.base = b.volley_base
	e.count = b.volley_dirs.size()
	return e


## M12c: the attack under way (`attack`) and / or the fire in the air and on the ground (`fire`) stopped this tick.
func _stop_event(attack: bool, fire: bool) -> void:
	var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	e.kind = NetProtocol.ShotEvent.Kind.BOSS_STOP
	e.tick = _now()
	e.flags = (NetProtocol.BOSS_STOP_ATTACK if attack else 0) | (NetProtocol.BOSS_STOP_FIRE if fire else 0)
	if e.flags != 0:
		_wire(e)


## M12c: bolt `bolt`'s let-go event (with its own tick and origin: a late client flies it from there).
static func bolt_event(bolt: Bolt) -> NetProtocol.ShotEvent:
	var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	e.kind = NetProtocol.ShotEvent.Kind.BOLT
	e.id = bolt.id
	e.tick = bolt.born
	e.pos = bolt.origin
	e.angle = bolt.angle
	return e


## M12c: circle `c`'s event (its tick of age 0).
static func circle_event(c: Circle) -> NetProtocol.ShotEvent:
	var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	e.kind = NetProtocol.ShotEvent.Kind.CIRCLE
	e.id = c.id
	e.tick = c.born
	e.pos = c.pos
	e.radius = c.radius
	e.ticks = c.telegraph
	return e


## M12c: pillar `i`'s state now, with what happened to it this tick (`flags`: NetProtocol.PILLAR_* beyond the rubble bit).
func pillar_event(i: int, flags: int = 0) -> NetProtocol.ShotEvent:
	var p: Pillar = pillars[i]
	var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	e.kind = NetProtocol.ShotEvent.Kind.PILLAR
	e.id = i
	e.tick = _now()
	e.hits = mini(p.hits, Pillar.hits_per_state() * 3)
	# The dust's ticks left counted from this tick's end: a pillar broken before this tick's step loses one more in it.
	e.falling = maxi(p.falling - (0 if _step_tick == _now() else 1), 0) if p.falling >= 0 else -1
	e.flags = flags | (NetProtocol.PILLAR_FALLEN if p.fallen else 0)
	return e


## M12c: what a player arriving on this map needs to draw the fight as it is (a late joiner, a map entry): the attack under way, the
## bolts in the air, the circles waiting or burning, every pillar's state.
func snapshot_events() -> Array[NetProtocol.ShotEvent]:
	var out: Array[NetProtocol.ShotEvent] = []
	if sim == null:
		return out
	if sim.state == BossSim.State.ATTACK and sim.attack != BossSim.Attack.NONE:
		out.append(attack_event())
	for bolt: Bolt in bolts:
		if not bolt.done:
			out.append(bolt_event(bolt))
	for c: Circle in circles:
		out.append(circle_event(c))
	for i: int in pillars.size():
		out.append(pillar_event(i))
	return out


## The events since the last call (cleared).
func take_events() -> PackedStringArray:
	var out: PackedStringArray = events
	events = PackedStringArray()
	return out


func defeated() -> bool:
	return sim != null and not sim.alive()


func _block_standing() -> void:
	for p: Pillar in pillars:
		if p.blocks():
			data.blockers[p.tile] = true
		else:
			data.blockers.erase(p.tile)


func _unblock_all() -> void:
	if data == null:
		return
	for p: Pillar in pillars:
		data.blockers.erase(p.tile)


# --- one tick -----------------------------------------------------------------------------------------------------

## One tick after the map's heretics (`players`: the players on this map, in a fixed order). Returns world edits (the relics' drops).
func step(players: Array[Player]) -> Array[EditLog.WorldEdit]:
	_players = players
	_step_tick = _now()
	var edits: Array[EditLog.WorldEdit] = take_edits()
	if sim == null:
		return edits
	sim.clock += 1
	_step_bolts(players)
	_step_circles(players)
	_age_debris()
	match sim.state:
		BossSim.State.SLEEP:
			for p: Player in players:
				if p.vitals.alive() and room.holds(p.sim_position):
					wake(players)
					break
		BossSim.State.DEAD:
			sim.state_ticks += 1
		_:
			_step_awake(players)
	_step_pillars(players)  # last: a debris landing this tick stuns from the next one, its whole length
	edits.append_array(take_edits())
	return edits


## The edits waiting (cleared).
func take_edits() -> Array[EditLog.WorldEdit]:
	var out: Array[EditLog.WorldEdit] = pending_edits
	pending_edits = []
	return out


## The map's last player left (Arena.on_emptied): an awake fight resets at once (home, full, its adds gone, the pillars back), the fire
## in the air is gone.
func on_emptied() -> void:
	if sim == null:
		return
	if sim.awake():
		reset("emptied")
	elif not bolts.is_empty() or not circles.is_empty():
		_stop_event(false, true)  # M12c
	_quiet()


## It wakes (a living player came into its room, or a blow landed): its max HP from the players on its map now.
func wake(players: Array[Player]) -> void:
	if sim == null or sim.state != BossSim.State.SLEEP:
		return
	sim.woke_with = maxi(players.size(), 1)
	sim.hp_max = BossSim.hp_for(sim.woke_with)
	sim.hp = sim.hp_max if test_hp <= 0 else mini(test_hp, sim.hp_max)
	sim.phase = 1
	sim.state = BossSim.State.CHASE
	sim.state_ticks = 0
	sim.recover = BossSim.num_i("recover_ticks") / 2
	sim.empty_ticks = 0
	count("woke")
	note("woke players=%d hp=%d" % [sim.woke_with, sim.hp_max])


func _step_awake(players: Array[Player]) -> void:
	var b: BossSim = sim
	b.state_ticks += 1
	if b.flash_ticks > 0:
		b.flash_ticks -= 1
	if b.stun_immune > 0:
		b.stun_immune -= 1
	if b.exposed_ticks > 0:
		b.exposed_ticks -= 1
	if b.slow_ticks > 0:
		b.slow_ticks -= 1
		if b.slow_ticks == 0:
			b.slow_pct = 0
	if b.taunt_ticks > 0:
		b.taunt_ticks -= 1
		if b.taunt_ticks == 0 or not Arena._up_here(b.taunt_by, players):
			b.taunt_ticks = 0
			b.taunt_by = 0
	if b.poison_ticks > 0:
		_tick_poison()
		if not b.alive():
			return
	if b.state == BossSim.State.RETURN:
		_go_home()
		return
	var anyone: bool = false
	for p: Player in players:
		if p.vitals.alive() and room.holds(p.sim_position):
			anyone = true
			break
	b.empty_ticks = 0 if anyone else b.empty_ticks + 1
	if b.empty_ticks >= BossSim.num_i("reset_ticks") or b.pos.distance_to(b.home) > BossSim.num("leash_px"):
		_start_return("left alone" if b.empty_ticks >= BossSim.num_i("reset_ticks") else "dragged too far")
		return
	if b.stun_ticks > 0:
		b.stun_ticks -= 1
		b.walking = false
		return
	if frozen:
		b.walking = false
		return
	if b.state == BossSim.State.ATTACK:
		b.walking = false
		if b.attack != BossSim.Attack.BURN and b.state_ticks == BossSim.strike_tick(b.attack):
			_strike(players)
		if b.state_ticks >= BossSim.attack_length(b.attack):
			_end_attack()
		return
	b.walking = false
	var t: Player = pick_target(players)
	if b.recover > 0:
		b.recover -= 1
	if t == null:
		b.target_id = 0
		return
	b.target_id = t.get_instance_id()
	var d: Vector2 = t.sim_position - b.pos
	if b.recover == 0:
		_start_attack(t, players)
		return
	b.facing = RigData.facing_toward(b.pos, t.sim_position)
	if d.length() > BossSim.attack_num(BossSim.Attack.CLEAVE, "trigger_px") * 0.75:
		_move_toward(t.sim_position, b.speed())


## The ticks before its next attack: Config.BOSS recover_ticks (phase 2: x phase2_cadence_pct).
func cadence() -> int:
	var r: int = BossSim.num_i("recover_ticks")
	if sim.phase >= 2:
		r = roundi(r * BossSim.num("phase2_cadence_pct") / 100.0)
	return maxi(r, 1)


func _end_attack() -> void:
	sim.state = BossSim.State.CHASE
	sim.state_ticks = 0
	sim.attack = BossSim.Attack.NONE
	sim.volley_dirs.clear()
	sim.recover = cadence()


## The target its next attack goes at (pick_target), the attack drawn from Config.BOSS_ATTACKS' weights (near: within the cleave's
## trigger, else far) with its own stream.
func _start_attack(t: Player, players: Array[Player]) -> void:
	var b: BossSim = sim
	var d: Vector2 = t.sim_position - b.pos
	var near: bool = d.length() <= BossSim.attack_num(BossSim.Attack.CLEAVE, "trigger_px")
	var key: String = "weight_near" if near else "weight_far"
	var total: int = 0
	for a: int in [BossSim.Attack.CLEAVE, BossSim.Attack.VOLLEY, BossSim.Attack.BURN]:
		total += BossSim.attack_int(a, key)
	if total <= 0:
		return
	var roll: int = rng.randi_range(1, total)
	var pick: int = BossSim.Attack.CLEAVE
	for a: int in [BossSim.Attack.CLEAVE, BossSim.Attack.VOLLEY, BossSim.Attack.BURN]:
		roll -= BossSim.attack_int(a, key)
		if roll <= 0:
			pick = a
			break
	if test_attack != BossSim.Attack.NONE:
		pick = test_attack
	begin_attack(pick, t, players)


## Starts attack `a` at player `t` (tests call it directly): it faces `t` and stands for the telegraph. A volley's bolt directions and the
## burn's circles are set now, so their warnings show where they will go.
func begin_attack(a: int, t: Player, players: Array[Player]) -> void:
	var b: BossSim = sim
	var d: Vector2 = t.sim_position - b.pos
	b.facing = RigData.facing_toward(b.pos, t.sim_position)
	b.attack_dir = d.normalized() if d.length_squared() > 0.0001 else Vector2(PlayerSim.facing_vector(b.facing))
	b.attack_at = t.sim_position
	b.attack = a
	b.state = BossSim.State.ATTACK
	b.state_ticks = 0
	b.walking = false
	b.volley_dirs.clear()
	b.volley_base = 0.0
	count("attacks")
	count("attack_" + BossSim.ATTACK_NAMES[a])
	if a == BossSim.Attack.VOLLEY:
		var n: int = BossSim.num_i("phase2_bolts") if b.phase >= 2 else BossSim.attack_int(a, "bolts")
		var from: Vector2 = Combat.body_point(b.pos)
		var aim: Vector2 = Combat.body_point(t.sim_position) - from
		b.volley_base = aim.angle() if aim.length_squared() > 0.0001 else b.attack_dir.angle()
		b.volley_dirs = BossSim.volley_dirs_for(b.volley_base, n)
	var placed: Array[Circle] = []
	if a == BossSim.Attack.BURN:
		for q: Player in burn_targets(players):
			var c: Circle = Circle.new()
			c.id = _new_id()
			c.pos = q.sim_position
			c.radius = BossSim.attack_num(a, "radius_px")
			c.telegraph = BossSim.attack_int(a, "telegraph")
			c.damage = BossSim.attack_int(a, "damage")
			c.show = BossSim.attack_int(a, "show_ticks")
			c.born = _now()
			circles.append(c)
			placed.append(c)
	_wire(attack_event())  # M12c: its telegraph's numbers, then the circles it put down
	for c2: Circle in placed:
		_wire(circle_event(c2))
	note("attack %s at=%d,%d" % [BossSim.ATTACK_NAMES[a], roundi(t.sim_position.x), roundi(t.sim_position.y)])


## The players the burn's circles go under: the valid targets (can_target), the highest threat first, then the nearer, at most
## Config.BOSS_ATTACKS burn "circles".
func burn_targets(players: Array[Player]) -> Array[Player]:
	var valid: Array[Player] = []
	for p: Player in players:
		if can_target(p):
			valid.append(p)
	var b: BossSim = sim
	valid.sort_custom(func(x: Player, y: Player) -> bool:
		var tx: int = b.threat_of(x.get_instance_id())
		var ty: int = b.threat_of(y.get_instance_id())
		if tx != ty:
			return tx > ty
		return x.sim_position.distance_squared_to(b.pos) < y.sim_position.distance_squared_to(b.pos))
	return valid.slice(0, BossSim.attack_int(BossSim.Attack.BURN, "circles"))


## The blow of the attack under way lands (its telegraph is over): the cleave hits, the volley's bolts fly.
func _strike(players: Array[Player]) -> void:
	var b: BossSim = sim
	match b.attack:
		BossSim.Attack.CLEAVE:
			count("cleaves")
			var reach: float = BossSim.attack_num(BossSim.Attack.CLEAVE, "reach_px")
			var arc: float = BossSim.attack_num(BossSim.Attack.CLEAVE, "arc_deg")
			for p: Player in players:
				if not p.vitals.alive() or Combat.in_safe_light(data, arena().safe, p.sim_position):
					continue
				if Combat.melee_hits(data, b.pos, b.attack_dir, p.sim_position, reach, arc):
					_hurt_player(p, BossSim.attack_int(BossSim.Attack.CLEAVE, "damage"), "cleave")
		BossSim.Attack.VOLLEY:
			count("volleys")
			var speed: float = BossSim.attack_num(BossSim.Attack.VOLLEY, "speed")
			var life: int = ceili(BossSim.attack_num(BossSim.Attack.VOLLEY, "range_px") / speed * Config.NET_TICK_RATE)
			for dir: Vector2 in b.volley_dirs:
				var bolt: Bolt = Bolt.new()
				bolt.id = _new_id()
				bolt.pos = Combat.body_point(b.pos)
				bolt.dir = dir
				bolt.speed = speed
				bolt.left = life
				bolt.damage = BossSim.attack_int(BossSim.Attack.VOLLEY, "damage")
				bolt.born = _now()
				bolt.origin = bolt.pos
				bolt.angle = dir.angle()
				bolts.append(bolt)
				count("bolts")
				_wire(bolt_event(bolt))  # M12c


## A boss blow on player `p` (Player.take_hit: armour counts, a dash or the hit's invulnerability avoids it). Returns whether it hurt.
func _hurt_player(p: Player, amount: int, what: String) -> bool:
	var ev: int = p.take_hit(amount, true)
	if ev & PlayerSim.HURT:
		count("player_hits")
		count("player_hits_" + what)
		if ev & PlayerSim.DOWNED:
			count("downed")
		return true
	count("player_dodged")
	count("player_dodged_" + what)
	return false


func _new_id() -> int:
	var id: int = next_id
	next_id += 1
	return id


# --- targets, threat --------------------------------------------------------------------------------------------------

## A player it may go after: up, within Config.BOSS sight_px, outside the altar's light (the dungeon has none: the M4 rule as written).
func can_target(p: Player) -> bool:
	if sim == null or not p.vitals.alive() or p.sim_position.distance_to(sim.pos) > BossSim.num("sight_px"):
		return false
	return Config.HERETIC_ENTERS_LIGHT or not Combat.in_safe_light(data, arena().safe, p.sim_position)


## Its target (○ gameplay-design §2.3, the M9 rules): the taunting paladin while a taunt forces it, else (the arena's threat on) the valid
## target with the highest threat (ties: the nearer, then the first), else the nearest valid one.
func pick_target(players: Array[Player]) -> Player:
	var b: BossSim = sim
	if b.taunted():
		for p: Player in players:
			if p.get_instance_id() == b.taunt_by and can_target(p):
				return p
	if arena().threat_on:
		var best: Player = null
		var best_t: int = 0
		var best_d: float = INF
		for p: Player in players:
			var t: int = b.threat_of(p.get_instance_id())
			if t <= 0 or not can_target(p):
				continue
			var d: float = p.sim_position.distance_to(b.pos)
			if t > best_t or (t == best_t and d < best_d):
				best = p
				best_t = t
				best_d = d
		if best != null:
			return best
	var near: Player = null
	var near_d: float = INF
	for p: Player in players:
		if not can_target(p):
			continue
		var d2: float = p.sim_position.distance_to(b.pos)
		if d2 < near_d:
			near = p
			near_d = d2
	return near


func add_threat(by: int, amount: int) -> void:
	if not arena().threat_on or by == 0 or amount <= 0 or sim == null or not sim.alive():
		return
	sim.threat[by] = sim.threat_of(by) + amount


## M9a's heal threat on the boss (Arena.heal_threat): awake with a target near the healed ally. Returns whether it got some.
func heal_threat(healer_id: int, healed: Player, add: int, players: Array[Player]) -> bool:
	if sim == null or not sim.awake() or sim.target_id == 0:
		return false
	for p: Player in players:
		if p.get_instance_id() == sim.target_id and p.sim_position.distance_to(healed.sim_position) <= Config.THREAT_HEAL_REACH_PX:
			add_threat(healer_id, add)
			return true
	return false


## The paladin's taunt (M9a, the heretics' rule): awake, within `radius` of `p` with nothing between, it goes after `p` for `ticks` and
## `p`'s threat goes on top. Returns 1 when it took.
func taunt(p: Player, radius: float, ticks: int) -> int:
	if sim == null or not sim.awake() or sim.state == BossSim.State.RETURN or sim.pos.distance_to(p.sim_position) > radius:
		return 0
	if not Combat.line_clear(data, Combat.body_point(sim.pos), Combat.body_point(p.sim_position)):
		return 0
	var pid: int = p.get_instance_id()
	sim.taunt_by = pid
	sim.taunt_ticks = ticks
	if arena().threat_on:
		sim.threat[pid] = sim.top_threat() + Config.TAUNT_THREAT_MARGIN
	count("taunted")
	return 1


# --- blows on the boss -----------------------------------------------------------------------------------------------

## `amount` of damage on the boss by the player with node instance id `by` (every path of the arena): asleep it wakes first; exposed it
## takes Config.BOSS exposed_damage_pct; threat for `by`; phase 2 at its threshold; dead at 0. Walking home to reset, nothing lands.
## Returns the damage dealt.
func hit(amount: int, by: int = 0) -> int:
	if sim == null or not sim.open_to_hits() or amount <= 0:
		return 0
	if sim.state == BossSim.State.SLEEP:
		wake(_players)
	var dealt: int = amount
	if sim.exposed():
		dealt = ceili(amount * BossSim.num("exposed_damage_pct") / 100.0)
	add_threat(by, dealt * Config.THREAT_PER_DAMAGE)
	sim.hp = maxi(sim.hp - dealt, 0)
	sim.flash_ticks = Config.BOSS_FLASH_TICKS
	count("boss_hits")
	count("boss_damage", dealt)
	if sim.hp == 0:
		_die(by)
		return dealt
	if sim.phase == 1 and sim.hp * 100 <= sim.hp_max * BossSim.num_i("phase2_hp_pct"):
		_enter_phase2()
	return dealt


## A shot whose ground point is `point` meets the boss's drawn box (Config.BOSS hit_radius_px / hit_height_px, Combat.shot_hits_box).
func shot_hits(point: Vector2) -> bool:
	return sim != null and sim.open_to_hits() and Combat.shot_hits_box(point, sim.pos, BossSim.num("hit_radius_px"),
		BossSim.num("hit_height_px"))


## A melee arc from feet `from` along `dir` reaches it (its bigger body: Config.BOSS melee_bonus_px more reach).
func in_arc(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> bool:
	return sim != null and sim.open_to_hits() and Combat.melee_hits(data, from, dir, sim.pos, reach + BossSim.num("melee_bonus_px"),
		arc_deg)


## Its feet in the circle of `radius` around `at` with nothing between (the holy burst, the strikes, the slam, a splash).
func in_circle(at: Vector2, radius: float) -> bool:
	return sim != null and sim.open_to_hits() and sim.pos.distance_to(at) <= radius \
		and Combat.line_clear(data, at, Combat.body_point(sim.pos))


## The aim point of its figure (bots, tests): the middle of its box.
func aim_point() -> Vector2:
	return sim.pos - Vector2(0.0, BossSim.num("hit_height_px") / 2.0) if sim != null else Vector2.ZERO


## A skill's stun (Config.BOSS stun_pct of it, at least 1 tick), then Config.BOSS stun_immune_ticks with no stun: refused while that runs
## (the paladin cannot lock it). It cancels the attack under way before its blow (like a heretic's, Config.SKILL_STUN_CANCELS_ATTACK).
## Returns whether it took.
func stun(ticks: int) -> bool:
	if sim == null or not sim.awake() or sim.state == BossSim.State.RETURN or ticks <= 0:
		return false
	if sim.stun_immune > 0:
		count("stuns_resisted")
		return false
	_stun_for(maxi(roundi(ticks * BossSim.num("stun_pct") / 100.0), 1))
	return true


## The debris's stun: its full length, the immunity ignored (then the immunity follows like any stun's).
func force_stun(ticks: int) -> void:
	if sim == null or not sim.awake() or sim.state == BossSim.State.RETURN or ticks <= 0:
		return
	_stun_for(ticks)


func _stun_for(t: int) -> void:
	var b: BossSim = sim
	if b.state == BossSim.State.ATTACK and Config.SKILL_STUN_CANCELS_ATTACK and b.state_ticks < BossSim.strike_tick(b.attack):
		count("attacks_stunned")
		_end_attack()
		_stop_event(true, false)  # M12c: its telegraph ends there
	b.stun_ticks = maxi(b.stun_ticks, t)
	b.stun_immune = b.stun_ticks + BossSim.num_i("stun_immune_ticks")
	b.walking = false
	count("stunned")
	note("stunned ticks=%d" % b.stun_ticks)


## A slow on it: Config.BOSS slow_pct of its strength and of its time (the stronger and longer kept, M6a's rule). Returns whether it took.
func slow(pct: int, ticks: int) -> bool:
	if sim == null or not sim.awake() or sim.state == BossSim.State.RETURN or pct <= 0 or ticks <= 0:
		return false
	var share: float = BossSim.num("slow_pct") / 100.0
	var p: int = maxi(roundi(pct * share), 1)
	var t: int = maxi(roundi(ticks * share), 1)
	sim.slow_pct = maxi(sim.slow_pct, p) if sim.slow_ticks > 0 else p
	sim.slow_ticks = maxi(sim.slow_ticks, t)
	count("slowed")
	return true


## A thrown poison on it (M6a's rule: the longer time, the larger damage, the new thrower).
func poison(damage: int, ticks: int, by: int) -> bool:
	if sim == null or not sim.open_to_hits() or damage <= 0 or ticks <= 0:
		return false
	if sim.state == BossSim.State.SLEEP:
		wake(_players)
	if sim.poison_ticks > 0:
		sim.poison_damage = maxi(sim.poison_damage, damage)
		sim.poison_ticks = maxi(sim.poison_ticks, ticks)
	else:
		sim.poison_damage = damage
		sim.poison_ticks = ticks
		sim.poison_timer = Config.POISON_INTERVAL_TICKS
	sim.poison_by = by
	count("poisoned")
	return true


func _tick_poison() -> void:
	sim.poison_ticks -= 1
	sim.poison_timer -= 1
	if sim.poison_timer <= 0:
		sim.poison_timer = Config.POISON_INTERVAL_TICKS
		hit(sim.poison_damage, sim.poison_by)
	if sim.poison_ticks <= 0:
		sim.poison_ticks = 0
		sim.poison_damage = 0


## Phase 2 (Config.BOSS phase2_hp_pct): the faster cadence and the bigger volley from now, and phase2_adds heretics called once this fight
## at the first spots around it they can stand on in its room.
func _enter_phase2() -> void:
	sim.phase = 2
	count("phase2")
	var called: int = 0
	if not sim.adds_called:
		sim.adds_called = true
		for off: Vector2 in ADD_SPOTS:
			if called >= BossSim.num_i("phase2_adds"):
				break
			var at: Vector2 = sim.pos + off
			if room.holds(at) and Movement.can_stand(data, at) and Combat.box_outside_light(data, arena().safe, at):
				var h: HereticSim = arena().spawn_heretic(at)
				sim.adds.append(h.id)
				called += 1
		count("adds", called)
	note("phase 2 adds=%d" % called)


func _die(by: int) -> void:
	var b: BossSim = sim
	_stop_event(b.state == BossSim.State.ATTACK, not bolts.is_empty() or not circles.is_empty())  # M12c
	b.state = BossSim.State.DEAD
	b.state_ticks = 0
	b.walking = false
	b.attack = BossSim.Attack.NONE
	b.stun_ticks = 0
	b.slow_ticks = 0
	b.poison_ticks = 0
	b.taunt_ticks = 0
	_quiet()
	for i: int in pillars.size():
		var p: Pillar = pillars[i]
		if p.falling >= 0:
			p.falling = -1
			p.fallen = true  # the arena goes quiet: a pillar coming down lies as rubble at once, harming nobody
			_wire(pillar_event(i))  # M12c
	_block_standing()
	count("killed")
	var progress: WorldProgress = WorldProgress.of(data)
	if progress != null:
		progress.defeat_boss()
	note("killed by=%s players=%d" % [Creatures.class_of(by) if by != 0 else "?", _players.size()])
	_give_relics(_players)


## ○ gameplay-design §5 "보스 드롭은 인원수만큼 분배": Config.BOSS_RELICS_PER_PLAYER relics to every player on the map at the kill, straight into
## the inventory; what does not fit lies on that player's feet tile as one drop (the ground-item path: a drop edit), none when the map
## holds Config.MAX_DROPS.
func _give_relics(players: Array[Player]) -> void:
	for p: Player in players:
		var want: int = Config.BOSS_RELICS_PER_PLAYER
		var left: int = p.inventory.add(Config.BOSS_RELIC, want)
		var pid: int = p.get_instance_id()
		relics_given[pid] = want - left
		relics_dropped[pid] = 0
		if left > 0 and data.drops.size() + pending_edits.size() < Config.MAX_DROPS:
			var tile: Vector2i = Aim.feet_cell(p.sim_position)
			var centre: Vector2i = tile * Config.TILE + Vector2i(Config.TILE / 2, Config.TILE / 2)
			pending_edits.append(EditLog.WorldEdit.drop_put(WorldData.Drop.new(data.new_drop_id(),
				Config.BOSS_RELIC, left, ItemDB.normalize_grade(Config.BOSS_RELIC), centre)))
			relics_dropped[pid] = left
		count("relics", want - left)
		count("relics_dropped", relics_dropped[pid])
		note("relic who=%s given=%d dropped=%d" % [p.class_id(), want - left, relics_dropped[pid]])


## The fire in the air and on the ground is gone (death, a reset, the map emptied).
func _quiet() -> void:
	for bolt: Bolt in bolts:
		bolt.done = true
		bolt.stopped_by = "quiet"
	bolts.clear()
	circles.clear()


## It walks home to reset (`why` for the log): no blow lands on it meanwhile.
func _start_return(why: String) -> void:
	_stop_event(sim.state == BossSim.State.ATTACK, not bolts.is_empty() or not circles.is_empty())  # M12c
	sim.state = BossSim.State.RETURN
	sim.state_ticks = 0
	sim.attack = BossSim.Attack.NONE
	sim.volley_dirs.clear()
	sim.stun_ticks = 0
	sim.slow_ticks = 0
	sim.slow_pct = 0
	sim.taunt_ticks = 0
	sim.taunt_by = 0
	sim.target_id = 0
	sim.stuck = 0
	_quiet()
	count("returns")
	note("returns home: %s" % why)


func _go_home() -> void:
	var b: BossSim = sim
	var before: float = b.pos.distance_to(b.home)
	if before <= Config.BOSS_HOME_ARRIVE_PX:
		reset("home")
		return
	_move_toward(b.home, BossSim.num("speed"))
	if b.pos.distance_to(b.home) >= before - 0.01:
		b.stuck += 1
	else:
		b.stuck = 0
	if b.pos.distance_to(b.home) <= Config.BOSS_HOME_ARRIVE_PX or b.stuck >= BossSim.num_i("home_stuck_ticks"):
		reset("home")


## The reset (`why` for the log): at home, asleep, full HP (its next wake works its HP out again), phase 1, no threat, no effect, the
## heretics it called gone, every pillar standing whole again.
func reset(why: String) -> void:
	var b: BossSim = sim
	_stop_event(b.state == BossSim.State.ATTACK, not bolts.is_empty() or not circles.is_empty())  # M12c
	b.pos = b.home
	b.facing = RigData.Dir.SOUTH
	b.state = BossSim.State.SLEEP
	b.state_ticks = 0
	b.attack = BossSim.Attack.NONE
	b.volley_dirs.clear()
	b.hp = b.hp_max
	b.phase = 1
	b.recover = 0
	b.walking = false
	b.stuck = 0
	b.target_id = 0
	b.threat.clear()
	b.taunt_by = 0
	b.taunt_ticks = 0
	b.stun_ticks = 0
	b.stun_immune = 0
	b.slow_pct = 0
	b.slow_ticks = 0
	b.exposed_ticks = 0
	b.poison_ticks = 0
	b.poison_damage = 0
	b.flash_ticks = 0
	b.empty_ticks = 0
	var gone: int = arena().remove_heretics(b.adds)
	b.adds.clear()
	b.adds_called = false
	for i: int in pillars.size():
		var p: Pillar = pillars[i]
		var was: bool = p.hits != 0 or p.falling >= 0 or p.fallen
		p.hits = 0
		p.falling = -1
		p.fallen = false
		p.broken_by = 0
		p.refused_ticks = 0
		if was:
			_wire(pillar_event(i))  # M12c: standing whole again
	_block_standing()
	_quiet()
	debris.clear()
	count("resets")
	note("reset (%s) hp=%d adds_removed=%d" % [why, b.hp, gone])


## One step toward `to` at `speed` (8 ways, walking's collision; never into the altar's light: the M4 heretic rule). Returns whether it moved.
func _move_toward(to: Vector2, speed: float) -> bool:
	var b: BossSim = sim
	var d: Vector2 = to - b.pos
	var dz: float = Config.HERETIC_AXIS_DEAD_ZONE_PX
	var dir: Vector2i = Vector2i(0 if absf(d.x) < dz else (1 if d.x > 0.0 else -1), 0 if absf(d.y) < dz else (1 if d.y > 0.0 else -1))
	if dir == Vector2i.ZERO:
		return false
	var tries: Array[Vector2i] = [dir]
	if dir.x != 0 and dir.y != 0:
		tries.append(Vector2i(dir.x, 0))
		tries.append(Vector2i(0, dir.y))
	for t: Vector2i in tries:
		var next: Vector2 = Movement.step(data, b.pos, t, Config.NET_TICK, speed)
		if next == b.pos:
			continue
		if not Config.HERETIC_ENTERS_LIGHT and not Combat.box_outside_light(data, arena().safe, next):
			continue
		b.pos = next
		b.walking = true
		b.facing = Movement.facing_for(t, b.facing)
		return true
	return false


# --- the fire --------------------------------------------------------------------------------------------------------------

func _step_bolts(players: Array[Player]) -> void:
	if bolts.is_empty():
		return
	var flying: Array[Bolt] = []
	for bolt: Bolt in bolts:
		_step_bolt(bolt, players)
		if not bolt.done:
			flying.append(bolt)
	bolts = flying


## One tick of a fire bolt: its speed in steps of at most Config.SHOT_STEP_PX; every tile a step crosses that stops a shot (walls, faces,
## blocking placeables, a standing pillar) stops it before; the first player up whose drawn box it is inside takes it (a dodging one, a
## dash's or a hit's invulnerability, lets it pass: it flies on); it is gone after its range.
func _step_bolt(bolt: Bolt, players: Array[Player]) -> void:
	var dist: float = bolt.speed / Config.NET_TICK_RATE
	var steps: int = maxi(ceili(dist / Config.SHOT_STEP_PX), 1)
	for i: int in steps:
		var from: Vector2 = bolt.pos
		bolt.pos += bolt.dir * (dist / steps)
		var c: Vector2i = Aim.cell_of(bolt.pos)
		var cells: Array[Vector2i] = [c]
		if c != Aim.cell_of(from):
			cells = Combat.cells_on_line(from, bolt.pos)
		for cc: Vector2i in cells:
			if Combat.blocks_line(data, cc):
				if cc != c:
					bolt.pos = from
				_stop_bolt(bolt, "wall")
				return
		for p: Player in players:
			var pid: int = p.get_instance_id()
			if not p.vitals.alive() or bolt.dodged.has(pid) or not Combat.shot_hits_body(bolt.pos, p.sim_position):
				continue
			if _hurt_player(p, bolt.damage, "bolt"):
				_stop_bolt(bolt, "player")
				return
			bolt.dodged[pid] = true
	bolt.left -= 1
	if bolt.left <= 0:
		_stop_bolt(bolt, "spent")


func _stop_bolt(bolt: Bolt, why: String) -> void:
	bolt.done = true
	bolt.stopped_by = why
	count("bolt_" + why)
	var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()  # M12c
	e.kind = NetProtocol.ShotEvent.Kind.BOLT_END
	e.id = bolt.id
	e.tick = _now()
	e.pos = bolt.pos
	e.why = maxi(NetProtocol.BOLT_STOPS.find(why), 0)
	_wire(e)


func _step_circles(players: Array[Player]) -> void:
	if circles.is_empty():
		return
	var lasting: Array[Circle] = []
	for c: Circle in circles:
		c.age += 1
		if not c.erupted and c.age >= c.telegraph:
			c.erupted = true
			count("eruptions")
			for p: Player in players:
				if p.vitals.alive() and p.sim_position.distance_to(c.pos) <= c.radius \
						and (Config.HERETIC_ENTERS_LIGHT or not Combat.in_safe_light(data, arena().safe, p.sim_position)):
					if _hurt_player(p, c.damage, "burn"):
						c.hits += 1
		if c.age < c.telegraph + c.show:
			lasting.append(c)
	circles = lasting


# --- the pillars --------------------------------------------------------------------------------------------------------------

## Test hook (--test-pillar-hits): pillar `i` has `hits` miner hits (its crack state); at its third state's end it lies as rubble.
func set_pillar_hits(i: int, hits: int) -> void:
	if i < 0 or i >= pillars.size():
		return
	var p: Pillar = pillars[i]
	p.hits = maxi(hits, 0)
	p.falling = -1
	p.fallen = p.hits >= Pillar.hits_per_state() * 3
	_block_standing()
	_wire(pillar_event(i))  # M12c


## The standing pillar on tile `cell` (its index; -1 = none).
func pillar_at(cell: Vector2i) -> int:
	for i: int in pillars.size():
		if pillars[i].tile == cell and pillars[i].blocks():
			return i
	return -1


## The whole pillars a melee arc from feet `from` along `dir` reaches (Combat.melee_hits_rect on its tile).
func pillars_in_arc(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> Array[int]:
	var out: Array[int] = []
	for i: int in pillars.size():
		if pillars[i].whole() and Combat.melee_hits_rect(data, from, dir, Rect2i(pillars[i].tile, Vector2i.ONE), reach, arc_deg):
			out.append(i)
	return out


## The whole pillars whose tile's middle is within `radius` + half a tile of `at` with nothing else between (the slam, the rocks).
func pillars_in_circle(at: Vector2, radius: float) -> Array[int]:
	var out: Array[int] = []
	for i: int in pillars.size():
		var p: Pillar = pillars[i]
		if p.whole() and p.centre().distance_to(at) <= radius + Config.TILE / 2.0 \
				and Combat.line_clear(data, at, p.centre(), Rect2i(p.tile, Vector2i.ONE)):
			out.append(i)
	return out


## A blow on pillar `i` by the player with node instance id `by`: `miner` = the miner's (a hit), else refused (its mark shows, nothing
## else). The last hit of its third state breaks it: its dust starts. Returns whether a hit landed.
func blow(i: int, by: int, miner: bool) -> bool:
	if i < 0 or i >= pillars.size() or not pillars[i].whole():
		return false
	var p: Pillar = pillars[i]
	if not miner:
		p.refused_ticks = Config.PILLAR_REFUSED_SHOW_TICKS
		count("pillar_refused")
		note("pillar %d refused by=%s: miner only" % [i, Creatures.class_of(by) if by != 0 else "?"])
		_wire(pillar_event(i, NetProtocol.PILLAR_REFUSED))  # M12c: the refused mark on every machine
		return false
	var before: int = p.look()
	p.hits += 1
	p.flash_ticks = Config.HIT_FLASH_TICKS
	count("pillar_hits")
	if p.hits >= Pillar.hits_per_state() * 3:
		p.falling = roundi(Config.BOSS_PILLARS["telegraph_ticks"])
		p.broken_by = by
		count("pillars_broken")
		note("pillar %d broken at=%d,%d" % [i, p.tile.x, p.tile.y])
	elif p.look() != before:
		note("pillar %d look=%d" % [i, p.look()])
	_wire(pillar_event(i, NetProtocol.PILLAR_HIT))  # M12c
	return true


## The blows of a melee arc (`p` swinging `item` or a skill: `skill`): on the boss and on the pillars it reaches.
func melee(p: Player, dir: Vector2, reach: float, arc_deg: float, amount: int, pick_blow: bool) -> int:
	var landed: int = 0
	if in_arc(p.sim_position, dir, reach, arc_deg):
		hit(amount, p.get_instance_id())
		landed += 1
	for i: int in pillars_in_arc(p.sim_position, dir, reach, arc_deg):
		blow(i, p.get_instance_id(), pick_blow)
	return landed


## Whether a blow of `p` with `item` (a basic attack) or a skill (`item` empty) counts on a pillar: the miner's, with his pickaxe for a basic
## attack (basic or tier-1), with any damaging skill.
static func miner_blow(p: Player, item: StringName) -> bool:
	if p == null or p.class_id() != "miner":
		return false
	return item.is_empty() or Gear.base(item) == Mining.PICKAXE


func _step_pillars(players: Array[Player]) -> void:
	for i: int in pillars.size():
		var p: Pillar = pillars[i]
		if p.refused_ticks > 0:
			p.refused_ticks -= 1
		if p.flash_ticks > 0:
			p.flash_ticks -= 1
		if p.falling < 0:
			continue
		p.falling -= 1
		if p.falling <= 0:
			p.falling = -1
			_land_debris(i, players)


## Pillar `i`'s debris lands on its fall circle (Config.BOSS_PILLARS fall_radius_px around its middle): the boss under it takes Config.BOSS
## debris_damage_pct of its max HP (threat for whoever broke it), the long stun and the exposure; every player up under it player_damage.
func _land_debris(i: int, players: Array[Player]) -> void:
	var p: Pillar = pillars[i]
	p.fallen = true
	_block_standing()
	var d: Debris = Debris.new()
	d.id = _new_id()
	d.pos = p.centre()
	d.radius = Config.BOSS_PILLARS["fall_radius_px"]
	debris.append(d)
	count("debris")
	if sim != null and sim.open_to_hits() and sim.pos.distance_to(d.pos) <= d.radius:
		var amount: int = maxi(ceili(sim.hp_max * BossSim.num("debris_damage_pct") / 100.0), 1)
		var was_exposed: int = sim.exposed_ticks
		sim.exposed_ticks = 0  # the debris's own damage is not raised by the exposure it brings
		hit(amount, p.broken_by)
		sim.exposed_ticks = was_exposed
		if sim.alive():
			force_stun(BossSim.num_i("debris_stun_ticks"))
			sim.exposed_ticks = BossSim.num_i("exposed_ticks")
		d.boss_hit = true
		count("debris_boss")
	for q: Player in players:
		if q.vitals.alive() and q.sim_position.distance_to(d.pos) <= d.radius:
			if _hurt_player(q, roundi(Config.BOSS_PILLARS["player_damage"]), "debris"):
				d.players_hit += 1
	note("debris pillar=%d boss=%s players=%d" % [i, d.boss_hit, d.players_hit])
	_wire(pillar_event(i, NetProtocol.PILLAR_LANDED | (NetProtocol.PILLAR_BOSS if d.boss_hit else 0)
		| (mini(d.players_hit, NetProtocol.PILLAR_PLAYERS_MAX) << NetProtocol.PILLAR_PLAYERS_SHIFT)))  # M12c


func _age_debris() -> void:
	if debris.is_empty():
		return
	var showing: Array[Debris] = []
	for d: Debris in debris:
		d.age += 1
		if d.age < DEBRIS_SHOW_TICKS:
			showing.append(d)
	debris = showing


## M12c: a pillar's dust is coming down (a session's quiet waits for it).
func falling_any() -> bool:
	for p: Pillar in pillars:
		if p.falling >= 0:
			return true
	return false


## Anything fighting (traffic and logs: Arena.fighting).
func fighting() -> bool:
	return sim != null and (sim.awake() or not bolts.is_empty() or not circles.is_empty())


func describe() -> String:
	if sim == null:
		return "no boss room"
	return "%s %s" % [sim.describe(), room.describe()]

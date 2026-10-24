class_name Prediction
extends RefCounted
## Client-side prediction of the local player (spike RESULTS §5: over Tailscale the client's own
## character lagged by a round trip when only the host moved it).
##
## Every tick the client steps its own player at once with the rule the host uses (PlayerSim.step:
## movement, the look, M2b body actions) and records the input frame. Frames are numbered (seq) only
## when they matter to the host: while moving and on the first idle tick after moving (the stop), a
## frame carrying a request (use, pick up, select ...), every frame while a body action plays (the
## action is timed in frames on both sides) and a frame whose look turned the player. Standing still
## records nothing, so an idle client sends nothing.
## When a host state for this player arrives (state after frame `ack`), reconcile() starts from it and
## replays the frames the host has not handled yet. Same code, same float32 numbers, same order: the
## replay lands where the prediction already was, and `max_error_px` stays 0. A frame the host never
## applied, or a host that disagrees for any other reason (it refused a use, say), shows up as an
## error or a correction count and the host's state wins. The facing is not sent unless the player
## aims (the look): the host derives it with the same rule (Movement.facing_for), and
## `facing_corrections` counts states whose facing differed from the prediction for that frame;
## `action_corrections` the same for the body action (0 when both sides agree).
##
## M3b, maps: the prediction steps on the data of the map the client has loaded (`data`, `map`; the
## same WorldData the host's edits change, so a wall the host broke stops blocking as soon as its edit
## is here; until then the prediction is blocked where the host is not, the host's state corrects it,
## and the replay from inside that wall walks out of it: Movement ignores what the box already
## overlaps). The client does not predict travel: after F on an entrance it goes on stepping on the
## old map until the host's map entry arrives; switch_map() then takes the host's state on the new map
## and replays the frames the host has not handled yet there. Host states for this player on another
## map than `map` (sent before the entry arrived) are skipped (`other_map`). A use aimed on another
## map (frame.map) is refused by the host ("wrong map"), so a replay does not start its action either.
##
## M4b, vitals: the state is PlayerSim's whole state, its Vitals included (HP, stamina, dash, stagger,
## down / dead; a host state carries them, NetProtocol's vitals block), so a dash, a stagger running out
## and the down and respawn timers are predicted like the movement. A frame is also recorded while F is
## held (and on its release: the host revives with it), on a dash, and on every tick a vitals timer runs
## (Vitals.idle false before or after the step): those frames are the host's clock for this player. A
## respawn (PlayerSim.RESPAWN) puts the prediction at its spawn slot (`spawn_feet`) like the host, when it
## is on the surface; from the dungeon the host sends the surface (switch_map). Damage, a revive and the
## revive's progress are the host's alone: a host state whose HP, life or revive progress differ from the
## prediction is a host event (`event_corrections`, its error in `max_event_error_px`), not a prediction
## error; the other counters stay for what the prediction itself got wrong (`vitals_corrections` for the
## timers, which the host and the prediction step alike).
##
## M6b, potions: the prediction plays a drink or a throw like any action (the frame's USE / THROW), never its
## effect. The effects are part of the Vitals (the effects block): a buff or a poison running down is stepped
## alike here and on the host (its walking speed, its poison ticks), but one put on (a drink's effect frame, a
## splash; or one made longer or stronger) is the host's event (effect_event), like a hit, and so is a heal.
##
## M5c: the paladin's purification channel is predicted like an action (a CHANNEL frame starts it, PlayerSim runs it, every
## frame of it is recorded: the host's clock of it; a state carries its ticks and a mismatch is an action correction);
## what it purifies, a crop that grows, the altar lifted or put down are the host's edits, never predicted. The respawn
## follows the altar: at this player's slot around the altar where the client's world has it now (respawn_feet), and not
## while it is carried (the host waits too).

class Pending:
	extends RefCounted
	var frame: NetProtocol.InputFrame
	var after: PlayerSim


var data: WorldData
## M3b: the map `data` is (the client's loaded map).
var map: int = Config.MAP_SURFACE
## The predicted state now.
var sim: PlayerSim = PlayerSim.new()
var next_seq: int = 1
var pending: Array[Pending] = []

## Last host state for this player and its ack.
var base_seq: int = 0
var base: PlayerSim = PlayerSim.new()

var frames: int = 0
var reconciles: int = 0
var corrections: int = 0
var max_error_px: float = 0.0
var facing_corrections: int = 0
var action_corrections: int = 0
var stale: int = 0
var dropped_unsent: int = 0
## M3b: map switches, and host states skipped because they were on another map.
var switches: int = 0
var other_map: int = 0
## M4b: where this player respawns (its spawn slot on the surface), host events taken (a hit, a revive;
## M6b: a potion's effect) and their largest position error, timer mismatches without one (M6-fix: including the
## states the host made stepping a quiet client itself), respawns.
var spawn_feet: Vector2 = Vector2.ZERO
## M5c: this player's spawn slot (Config.SPAWN_SLOTS; -1 = respawn at spawn_feet): the respawn follows the altar.
var spawn_slot: int = -1
var event_corrections: int = 0
var max_event_error_px: float = 0.0
var vitals_corrections: int = 0
var respawns: int = 0
## The last vitals mismatch without a host event (logged by the client: it should never happen).
var last_vitals_mismatch: String = ""

var _last_dir: Vector2i = Vector2i.ZERO
var _last_interact: bool = false

var pos: Vector2:
	get:
		return sim.pos
var facing: int:
	get:
		return sim.facing
var walking: bool:
	get:
		return sim.walking


func setup(p_data: WorldData, p_pos: Vector2, p_facing: int, ack: int) -> void:
	data = p_data
	map = p_data.map_id
	sim = PlayerSim.new()
	sim.pos = p_pos
	sim.facing = p_facing
	base = sim.copy()
	base_seq = ack
	next_seq = ack + 1
	pending.clear()


## One local tick with a direction only (M1). Returns the recorded frame, or null (idle).
func step(dir: Vector2i) -> NetProtocol.InputFrame:
	return step_frame(NetProtocol.InputFrame.new(0, dir))


## One local tick: `frame` (look, request; a USE resolved into `anim` by the caller) is stepped at
## once. Returns it numbered when it was recorded (see the class comment), or null.
func step_frame(frame: NetProtocol.InputFrame) -> NetProtocol.InputFrame:
	var was_acting: bool = sim.action >= 0 or sim.channel_tick > 0
	var facing_before: int = sim.facing
	var idle_before: bool = sim.vit.idle()
	_after_step(sim.step(data, frame.dir, frame.look, frame.anim, frame.cell, Config.NET_TICK, frame.dash, frame.interact,
		frame.aim, channel_on_map(frame)))
	# M5c: every frame of a purification channel too (they are the host's clock of it, like an action's).
	var recorded: bool = frame.dir != Vector2i.ZERO or _last_dir != Vector2i.ZERO or frame.op != NetProtocol.Op.NONE \
		or was_acting or sim.action >= 0 or sim.channel_tick > 0 or sim.facing != facing_before or frame.dash \
		or frame.interact or _last_interact or not idle_before or not sim.vit.idle()
	_last_dir = frame.dir
	_last_interact = frame.interact
	if not recorded:
		return null
	frame.seq = next_seq
	var p: Pending = Pending.new()
	p.frame = frame
	p.after = sim.copy()
	next_seq += 1
	pending.append(p)
	frames += 1
	# A host that stops acknowledging (gone, or far behind) must not grow this without end.
	while pending.size() > 4 * Config.NET_MAX_FRAMES_PER_PACKET:
		pending.pop_front()
		dropped_unsent += 1
	return frame


func has_unacked() -> bool:
	return not pending.is_empty()


## The newest unacknowledged frames (at most one packet), oldest first, consecutive.
func frames_to_send() -> Array[NetProtocol.InputFrame]:
	var out: Array[NetProtocol.InputFrame] = []
	var first: int = maxi(0, pending.size() - Config.NET_MAX_FRAMES_PER_PACKET)
	for i: int in range(first, pending.size()):
		out.append(pending[i].frame)
	return out


## Unacknowledged frames carrying a request of kind `op` with a seq above `after_seq`, oldest first
## (the client re-applies its pending hotbar selections on top of an inventory from the host).
func pending_ops(op: int, after_seq: int) -> Array[NetProtocol.InputFrame]:
	var out: Array[NetProtocol.InputFrame] = []
	for p: Pending in pending:
		if p.frame.op == op and p.frame.seq > after_seq:
			out.append(p.frame)
	return out


## Applies the host's state for this player. Returns the prediction error in px (how far the
## predicted position after frame `ack` was from the host's), or -1 for a stale state.
func reconcile(state: NetProtocol.PlayerState) -> float:
	if state.map != map:
		other_map += 1
		return -1.0
	if state.ack < base_seq:
		stale += 1
		return -1.0
	var host: PlayerSim = _sim_of(state)
	var predicted: PlayerSim = base
	if state.ack > base_seq:
		predicted = host  # a frame we no longer hold: nothing to compare
		for p: Pending in pending:
			if p.frame.seq == state.ack:
				predicted = p.after
				break
	var error: float = predicted.pos.distance_to(state.pos)
	reconciles += 1
	# M4b: a hit, a revive (or its progress) is the host's event. M6-fix: the host stepping this player itself (a
	# quiet client, SessionHost "host_steps") is not told apart here: a state it made counts as a vitals correction
	# when its timers ran ahead of the prediction's (README "M6b 예측", known issues).
	var event: bool = predicted.vit.hp != host.vit.hp or predicted.vit.life != host.vit.life \
		or predicted.vit.revive_ticks != host.vit.revive_ticks or effect_event(predicted.vit, host.vit)
	if event:
		if error > 0.0 or predicted.facing != state.facing or predicted.action != state.action \
				or predicted.action_tick != state.action_tick or predicted.channel_tick != state.channel \
				or not predicted.vit.same_wire(host.vit):
			event_corrections += 1
		max_event_error_px = maxf(max_event_error_px, error)
		error = 0.0
	else:
		if error > 0.0:
			corrections += 1
		if predicted.facing != state.facing:
			facing_corrections += 1
		if predicted.action != state.action or predicted.action_tick != state.action_tick \
				or predicted.channel_tick != state.channel:
			action_corrections += 1  # M5c: the purification channel counts as an action here
		if not predicted.vit.same_wire(host.vit):
			vitals_corrections += 1
			last_vitals_mismatch = "ack %d: predicted %s flash %d / host %s flash %d" % [state.ack, predicted.vit.describe(),
				predicted.vit.flash_ticks, host.vit.describe(), host.vit.flash_ticks]
	# The target tile is not replicated: keep the predicted one for the same action.
	host.action_cell = predicted.action_cell if predicted.action == host.action else sim.action_cell
	max_error_px = maxf(max_error_px, error)
	base_seq = state.ack
	base = host
	while not pending.is_empty() and pending[0].frame.seq <= state.ack:
		pending.pop_front()
	# Replay what the host has not handled yet, from the host's state, with the rule the host applies
	# to each frame.
	_replay(host)
	return error


## M6b: the host put an effect on this player that the prediction does not have (a potion: a buff or a poison
## that is new, longer or stronger). One running out is stepped alike on both sides, so a buff or a poison the
## prediction holds longer than the host is the prediction's mistake (a vitals correction), not an event.
static func effect_event(pred: Vitals, host: Vitals) -> bool:
	return host.buff_ticks > pred.buff_ticks or host.buff_pct > pred.buff_pct or host.poison_ticks > pred.poison_ticks \
		or host.poison_damage > pred.poison_damage


## M3b: the host moved this player to map `p_map` (data `p_data`) and says where it stands there after
## frame `state.ack`: take that state and replay the frames after it on the new map (a map change is
## not a prediction error, so nothing is counted but the switch).
func switch_map(p_data: WorldData, p_map: int, state: NetProtocol.PlayerState) -> void:
	data = p_data
	map = p_map
	switches += 1
	var host: PlayerSim = _sim_of(state)
	host.action_cell = sim.action_cell
	base_seq = maxi(base_seq, state.ack)
	base = host
	while not pending.is_empty() and pending[0].frame.seq <= state.ack:
		pending.pop_front()
	_replay(host)


## Replays the unacknowledged frames from `from` with the rule the host applies to each frame (a use
## aimed on another map starts nothing: the host refuses it).
func _replay(from: PlayerSim) -> void:
	sim = from.copy()
	for p: Pending in pending:
		_after_step(sim.step(data, p.frame.dir, p.frame.look, anim_on_map(p.frame), p.frame.cell, Config.NET_TICK,
			p.frame.dash, p.frame.interact, p.frame.aim, channel_on_map(p.frame)), false)
		p.after = sim.copy()


## M4b: what the host does after a step that the prediction does too: the respawn at the spawn slot (on
## the surface; from another map the host sends the surface and switch_map takes over). M5c: at the spawn slot of the
## altar where the client's world has it now (it moves), and not while it is carried (the host waits too).
func _after_step(events: int, count: bool = true) -> void:
	if events & PlayerSim.RESPAWN and map == Config.MAP_SURFACE and data != null and data.altar_rect.has_area():
		sim.respawn(respawn_feet())
		if count:
			respawns += 1


## M5c: where this player respawns: its spawn slot around the altar as the client's world has it (GameWorld.spawn_point's
## rule), or `spawn_feet` when no slot was set (tests that set the feet themselves).
func respawn_feet() -> Vector2:
	if spawn_slot < 0 or data == null or not data.altar_rect.has_area():
		return spawn_feet
	return data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[spawn_slot % Config.SPAWN_SLOTS.size()])


## M5c: whether frame `f` starts the purification channel on this map (a CHANNEL aimed on another map is refused by the
## host, like a use).
func channel_on_map(f: NetProtocol.InputFrame) -> bool:
	return f.channel and not (NetProtocol.op_has_map(f.op) and f.map != map)


## The action frame `f` starts on this map: its own, unless it is a request aimed on another map.
func anim_on_map(f: NetProtocol.InputFrame) -> int:
	if NetProtocol.op_has_map(f.op) and f.map != map:
		return -1
	return f.anim


static func _sim_of(state: NetProtocol.PlayerState) -> PlayerSim:
	var host: PlayerSim = PlayerSim.new()
	host.pos = state.pos
	host.facing = state.facing
	host.walking = state.walking
	host.action = state.action
	host.action_tick = state.action_tick
	host.vit = state.vitals_or_full()
	host.channel_tick = state.channel  # M5c: around the feet tile (a channel never moves)
	if state.channel > 0:
		host.channel_cell = Aim.feet_cell(state.pos)
	return host


func to_dict() -> Dictionary:
	return {
		"frames": frames, "reconciles": reconciles, "corrections": corrections, "max_error_px": max_error_px,
		"facing_corrections": facing_corrections, "action_corrections": action_corrections,
		"stale": stale, "pending": pending.size(), "dropped_unsent": dropped_unsent, "next_seq": next_seq,
		"map": map, "switches": switches, "other_map": other_map,
		"event_corrections": event_corrections, "max_event_error_px": max_event_error_px,
		"vitals_corrections": vitals_corrections, "respawns": respawns,
	}

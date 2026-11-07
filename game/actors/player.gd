class_name Player
extends Node2D
## A player in the world: simulation state (feet position, facing) + a Character for the picture.
##
## Offline (main.tscn without --host/--join) the simulation runs in _physics_process (fixed ticks)
## with Movement.step, from the local keys (read_input) when `local_input` is on. In a session
## (net/session.gd) `local_input` is off and the session drives the player: the host steps it with
## apply_input() per input frame (facing derived from the direction, Movement.facing_for), a client
## shows predicted or received states with show_state().
##
## Drawing: the node sits on whole pixels. Every player is drawn between where the last simulation
## tick started (begin_tick, first thing each physics tick) and where it left it, at
## Engine.get_physics_interpolation_fraction(), rounded (draw_position). A player stepped on physics
## ticks (the local player, every player the host simulates, a client's own predicted player) so
## moves in even steps on a monitor faster than 60 Hz instead of 0 / 1 / 2 px jumps; one the tick
## did not move (a host-side player whose frame is late) stands still, and one the tick moved more
## than two steps (a client the host catches up) is drawn where the tick ended. Only `position` follows the
## drawing; `sim_position` (simulation, net state, hashes) is untouched. A player drawn from
## interpolated host states (other players on a client) gets show_state() every frame and is drawn
## where it is. The camera (actors/player_camera.gd) follows the drawn position after this.
##
## Controls (M2a; M2b also in sessions): make_frame() turns one tick of local input (keys, mouse,
## use button) into an input frame and updates the aim (actors/aim.gd: sector, target tile next to
## the feet, facing toward the mouse while aiming, Config.AIM_HOLD_SEC); "use" (left click) with a
## tool selected in the inventory's hotbar puts that tool's body action into the frame, toward the
## target tile. step_frame() runs a frame with the one simulation rule (actors/player_sim.gd):
## actions timed in frames (Config.ACTION_FRAME_TICKS per animation frame), movement locked
## meanwhile, repeated while held (PROVISIONAL values). An action has no world effect yet; it
## reports its target (action_started). Offline, tick_controls() = make_frame() + step_frame() each
## tick. In a session the session builds the local player's frames with make_frame(), the host steps
## every player with step_frame(), and a client shows its predicted and the others' received states
## with show_state(). `controls` (mouse aim, target marker) is on for the local player offline and
## in sessions.
##
## M4a (offline; a session has no damage or dash yet): the simulation state holds the Vitals (HP,
## stamina, dash, stagger, down / dead, actors/vitals.gd) and the playing action's aim. Space dashes,
## F held revives a downed player next to it (combat/arena.gd) or, while down, gives up. take_hit() is
## a hit (the heretic's knife); the picture shows base_body_v02_hurt while staggered, base_body_v02_death
## while down (then lying), nothing while dead (the death bag marks the spot). Signals: died (drop the
## bag), respawn_due (Main puts it back at the altar), action_impact on the weapon's hit frame
## (Combat.impact_tick; the pickaxe's is the M3a mining frame).
##
## M6a (`potions_on`: offline, and M6b the local player of a session too, whose frames the session sends; the
## host resolves them itself): a click with a potion selected
## drinks it (Config.DRINK_ANIM), the skill key 1 throws it (the herbalist's, the throw action) toward the
## mouse; action_impact comes on the potion's effect / release frame (Potions.impact_tick) with the slot,
## grade and landing point kept in action_slot / action_grade / action_target; Main applies it. The Vitals
## carry the effects (buff, poison: PlayerSim); EffectMarks shows them over the head. `ui_locked` (the
## crafting panel open) turns every tick's input into an empty frame.
##
## M5a (`farming_on`, offline; M5c: the session's local player too): a click with seeds selected is a USE without an action
## like a torch's (Main plants; in a session the host); the hoe and the watering can land on their own frames
## (Farming.impact_tick), the sickle on its hit frame.
##
## M5b (`purify_on`, offline; M5c: the session's local player too): a click with holy water selected pours it (Config.HOLY_WATER_ANIM; it works on
## Purify.impact_tick, action_impact, Main purifies). request_channel() (Main, on F with nothing to pick up) puts the
## paladin's purification channel into the next frame (PlayerSim.step runs it; channel_started / channel_done /
## channel_broken). While `carrying_altar` (Main sets it) a click asks to put the altar down on the target tile
## (altar_place_requested) and nothing else is used or thrown; an AltarMark shows over the head.
## M5c, in a session: the channel goes as the CHANNEL request (SessionHost.attach_local_op turns F with nothing to pick up
## into it), the click while carrying as ALTAR_PLACE; `carrying_altar` comes from the host's state (its held byte); the
## channel of a player drawn from states comes with show_state().
## M7a (`gear_on`: offline Main's player; M7c: a session's local player and the host's members too): a click with armour
## selected asks to put it on (equip_requested; Main, items/gear.gd; M7c: an ARMOR request); a heretic's knife hit (take_hit
## with `armored`) is lessened by the worn armour and wears it; with Config.GEAR_BROKEN_UNUSABLE a broken item makes no
## frame (gear_refused; M7-fix: the host refuses its USE too).
## M7b: a click with a build piece selected is a USE without an action like a torch's (place_requested: offline Main builds,
## items/building.gd; M7c: the host builds from the USE); the axe plays its own body action and lands on
## Forest.impact_tick (action_impact: offline Main chops; M7c: the host).
## M9a (`skills_on`: offline Main's player and allies; a session's players keep it off until M9c): the skill keys 1 2 3 R
## (combat/skills.gd: Skills.prepare decides a press, the HUD marks a refusal) put a skill's body action into the frame
## (frame.skill, its slot and target); action_item is the skill id then (the herbalist's throw keeps its potion) and
## action_impact comes on the skill's impact frame (Skills.impact_tick): offline Main lands it (Skills.land). `skills` holds the
## cooldowns, the class meter and the refusal mark; step_frame ticks it, take_hit and a poison tick feed the paladin's
## conviction, a death loses the meter. `skill_aim_target` = the ally a heal or buff would go to now (Skills.aim_target from
## `party_provider`, the players on this map: Main's AllyMark draws a ring under it). Without `skills_on` key 1 is M6's throw.
## M9b: a skill's frame carries the selected hotbar slot (a weapon skill's stack: action_slot) and a point skill's point
## (throw_to -> action_target); take_hit takes the paladin's oath ward off a hit (after the armour), shown over the head (WARD).
## M9c (sessions): every frame carries the mouse (`cursor`); a skill key's frame is a SKILL request (the herbalist's key 1 a THROW,
## as since M6b), which a session sends and its host resolves again from its own state (SessionHost._skill). The host's members
## keep `skills_on` with `skills_clock_external`: the host counts their skill clock once a host tick (SessionHost.tick), not once
## a frame. A client's own player has `skills_on` for its keys and HUD; its `skills` shows the host's (the skills message).
## M10a (offline first; M10b: in sessions too, the host's prayer sets it, a client's from the host's events): `prayer_role` (Prayer.Role, the prayer at the altar sets it): while PRAYING the
## frame's move keys are the prayer's answers (they ride in the frame as they are, Prayer.step reads them from last_input) and
## step_frame does not move the player (it faces the altar, prayer_face); nothing else starts (no use, drink, throw, dash, channel;
## a skill key is refused with the HUD's mark, Skills.WHY_PRAYING). While MEDITATING the frame is as usual (a move breaks the
## meditation, Prayer). The zeal (SkillState.zeal_*) shows over the head (EffectMarks.Kind.ZEAL); the PrayerMark shows the turn's
## arrow (not over this machine's own player: its HUD prompt), the joined / left ring and the meditation's ring and bar (Main sets it).
## M11b (`capture_on`: offline Main's player; a session's keep it off until M11c): a click with the snare selected (items/capture.gd:
## Capture.refusal on the creature under the mouse, from `herd_provider`) puts the throw into the frame with that creature
## (action_capture), or says why not (capture_refused: nothing starts, nothing is spent); it lands on Capture.impact_tick (action_impact:
## Main takes the creature). A heretic's knife hit counts the world's collection defence with the worn armour's (Collection.defence_bonus).

signal action_started(item: StringName, anim: int, target: Vector2i)
signal action_finished(anim: int)
## M3a: the playing action reached Mining.impact_tick() (the pickaxe lands; offline, Main mines then).
signal action_impact(item: StringName, anim: int, target: Vector2i)
## M3a, offline: a frame used a placeable item (the torch) from hotbar slot `slot` on tile `cell`.
signal place_requested(slot: int, cell: Vector2i)
## M4a: a hit landed (`downed`: it took the player to 0 HP), the down time ran out or the player gave up
## (it is dead now), the respawn time is up, a revive got it back up.
signal hurt(amount: int, downed: bool)
signal died
signal respawn_due
signal revived
## M6a: a drink or a throw the controls did not start (Potions.WHY_*), for the log.
signal potion_refused(what: String, why: String)
## M5b: the purification channel started around tile `cell` / ran its time (purify around `cell`) / was broken (`why`:
## "moved", "dash", "use", "hit", "down"); a holy water pour the controls did not start (Purify.WHY_*); the carrier's
## click to put the altar down on tile `cell`.
signal channel_started(cell: Vector2i)
signal channel_done(cell: Vector2i)
signal channel_broken(why: String)
signal purify_refused(what: String, why: String)
signal altar_place_requested(cell: Vector2i)
## M7a: a click with armour selected in hotbar slot `slot` (Main puts it on); a use the gear rules did not start.
signal equip_requested(slot: int)
signal gear_refused(what: String, why: String)
## M9a: a skill key of slot `slot` (Skills.Slot) was refused (`why`: Skills.WHY_* or a throw's Potions.WHY_*; nothing spent) /
## started skill `id`'s action.
signal skill_refused(slot: int, id: StringName, why: String)
signal skill_started(slot: int, id: StringName)
## M10a: a use, a drink, a throw or a dash pressed while praying (nothing starts; `what` for the log).
signal prayer_refused(what: String)
## M11b: a click with the snare that was refused (Capture.WHY_*; nothing starts or is spent), at creature `c` (null: none under the mouse).
signal capture_refused(why: String, c: CreatureSim)

## Longest tick (px) drawn between its ends: two walking steps (2.4 px) and some float slack. One
## frame per tick is one step; more only while the host catches a client up (net/input_gate.gd),
## and such a tick is drawn at its end (update_draw).
const MAX_DRAWN_STEP_PX: float = 2.5 * Config.WALK_SPEED / Config.NET_TICK_RATE
## IMPL (M4a): the hit flash tint (a placeholder: no flash art exists).
const HIT_FLASH: Color = Color(1.0, 0.55, 0.45)

## Read the move_* actions each physics tick. Off for players driven by tests or the session.
@export var local_input: bool = true
## Mouse aim, hotbar use and body actions (offline local player, see the class comment).
@export var controls: bool = false

var inventory: Inventory = Inventory.new()
## Aim (updated each controls tick): the mouse in world px, its sector and target tile, and whether
## the player is aiming (facing the mouse).
var aim_point: Vector2 = Vector2.ZERO
var aim_sector: int = Aim.Sector.SOUTH
var aim_cell: Vector2i = Vector2i.ZERO
var aim_active: bool = false
## Test / screenshot aim: when set, the mouse is this far from the feet and the player always aims.
var test_aim: Variant = null
## Players shown from received states (the other players on a client) hold what the state says;
## every other player holds its inventory's selected stack (held_id()).
var held_from_state: bool = false
var state_held: StringName = &""
## The body action playing (RigData action anim) or -1, ticks since it started, its item and target.
var action_anim: int = -1
var action_tick: int = 0
var action_item: StringName = &""
var action_cell: Vector2i = Vector2i.ZERO
## M4a: the playing action's aim (Combat.aim_code), health and the rest (actors/vitals.gd), and whether
## the last frame held F.
var action_aim: int = 0
var vitals: Vitals = Vitals.new()
var interact_held: bool = false
## M6a: drinking and throwing potions (Main turns it on for the offline player; M6b: the session for its local
## player). `ui_locked`: a panel (crafting) takes the keys, the player stands (offline here, in a session
## SessionBots.local_action). The
## playing action's hotbar slot, the grade of the item it plays and a throw's landing point.
var potions_on: bool = false
## M5a: a click with seeds selected plants them (Main turns it on for the offline player; M5c: and the session's local
## player, whose seed click is a USE the host plants; off, the click makes no frame, as potions_on did in M6a's sessions).
var farming_on: bool = false
## M5b (Main turns it on offline; M5c: and for the session's local player): holy water and the purification channel. The channel's state (PlayerSim
## channel_tick / channel_cell), whether this player carries the altar (Main sets it; AltarMove) and how long F has been
## held aimed at the altar (Main counts it, Config.ALTAR_PICKUP_HOLD_TICKS).
var purify_on: bool = false
## M7a: armour, its defence and its wear on knife hits (Main turns it on offline; M7c: the session's players too).
var gear_on: bool = false
var channel_tick: int = 0
var channel_cell: Vector2i = Vector2i.ZERO
var carrying_altar: bool = false
var altar_hold_ticks: int = 0
## M5-fix: this carrier went down and no place allowed the altar (AltarMove.set_down_fallback); it keeps it and nobody
## searches again until it is up (Main.check_carriers, SessionHost._check_carriers).
var altar_set_down_failed: bool = false
var altar_mark: AltarMark
var _channel_pending: bool = false
var ui_locked: bool = false
var action_slot: int = 0
var action_grade: int = ItemDB.Grade.NONE
var action_target: Vector2 = Vector2.ZERO
var effect_marks: EffectMarks
## M9a (Main turns it on offline for its player and the allies; a session's players keep it off until M9c): the skill kit.
## `skills`: the cooldowns, the class meter, the HUD's refusal mark (actors/skill_state.gd).
var skills_on: bool = false
var skills: SkillState = SkillState.new()
## M9c: the skill clock (SkillState.tick: the cooldowns, the meter's rules, the ward) is counted by someone else once a game
## tick, not by step_frame (a session host's members: SessionHost ticks them on host time, frames or no frames).
var skills_clock_external: bool = false
## M9a: returns the players the near-cursor pick may choose from (Array[Player]: the players on this player's map, in a fixed
## order; Main sets it offline). Unset: this player alone.
var party_provider: Callable = Callable()
## M9a: the skill the playing action is (&"" = none), its slot and the ally it goes to (node instance id, 0 = none).
var action_skill: StringName = &""
var action_skill_slot: int = -1
var action_skill_target: int = 0
## M9a: the ally a heal or buff of this player would go to now (Skills.aim_target, every controls tick; null = none).
var skill_aim_target: Player
## M9 review: a press now would be refused on that ally (the cleric's heal on an ally at full HP: Skills.aim_refused); the ring
## shows dim then.
var skill_aim_refused: bool = false
## M10a: this player's part in the prayer at the altar (Prayer.Role: none, praying, meditating; the prayer sets it), the way it faces
## while praying (toward the altar), and the marks over its head (Main shows them from the prayer).
var prayer_role: int = 0
var prayer_face: int = RigData.Dir.NORTH
var prayer_mark: PrayerMark
## M11b (Main turns it on offline): the snare's click. `herd_provider` returns the herd of this player's map (Creatures, or null: no
## creatures here), and `action_capture` is the id of the creature the playing throw goes to (0 = none).
var capture_on: bool = false
var herd_provider: Callable = Callable()
var action_capture: int = 0
var _mouse_moved_msec: int = -1000000
## make_frame(): the mouse aimed or the use button was held (step_frame() adds "an action plays").
var _aim_input: bool = false

var data: WorldData
## Feet position (float, simulation). `position` is this rounded (or between ticks, see above).
var sim_position: Vector2 = Vector2.ZERO
var facing: int = RigData.Dir.SOUTH
var last_input: Vector2i = Vector2i.ZERO
## Walk animation (input held), idle otherwise.
var walking: bool = false
var character: Character
## Draw between the last two simulation ticks (see the class comment). Off = draw at sim_position.
var smooth_draw: bool = true
## sim_position when the latest tick started: the drawing moves from here to sim_position.
var tick_from: Vector2 = Vector2.ZERO


func _init() -> void:
	process_physics_priority = -1  # begin_tick() before the session steps this player in the same tick
	character = Character.new()
	character.name = &"Character"
	add_child(character)
	effect_marks = EffectMarks.new()
	add_child(effect_marks)
	altar_mark = AltarMark.new()
	add_child(altar_mark)
	prayer_mark = PrayerMark.new()
	add_child(prayer_mark)


func setup(p_data: WorldData, class_id: String, feet: Vector2, p_facing: int = RigData.Dir.SOUTH) -> void:
	data = p_data
	character.class_id = class_id
	sim_position = feet
	tick_from = feet
	facing = p_facing
	last_input = Vector2i.ZERO
	walking = false
	action_anim = -1
	action_tick = 0
	vitals = Vitals.new()
	channel_tick = 0
	carrying_altar = false
	altar_hold_ticks = 0
	altar_set_down_failed = false
	skills = SkillState.new()
	action_skill = &""
	action_skill_slot = -1
	action_skill_target = 0
	action_capture = 0
	skill_aim_target = null
	skill_aim_refused = false
	prayer_role = Prayer.Role.NONE
	prayer_mark.show_mark(PrayerMark.Kind.NONE)
	_sync_view()


func class_id() -> String:
	return character.class_id


func _physics_process(delta: float) -> void:
	begin_tick()
	if local_input and data != null:
		if controls:
			tick_controls(read_input(), mouse_world(), mouse_aiming(), Input.is_action_just_pressed(&"use_item"),
				Input.is_action_pressed(&"use_item"), delta, Input.is_action_just_pressed(&"dash"),
				Input.is_action_pressed(&"interact"), Input.is_action_just_pressed(&"skill_1"), pressed_skill_slot())
		else:
			apply_input(read_input(), delta)


func _input(event: InputEvent) -> void:
	if controls and event is InputEventMouseMotion:
		_mouse_moved_msec = Time.get_ticks_msec()


## Where the mouse points in the world (the engine's canvas transform: camera and window stretch).
func mouse_world() -> Vector2:
	if test_aim != null:
		var offset: Vector2 = test_aim
		return sim_position + offset
	return get_global_mouse_position()


## True while the mouse moved within Config.AIM_HOLD_SEC (always with a test aim).
func mouse_aiming() -> bool:
	if test_aim != null:
		return true
	return Time.get_ticks_msec() - _mouse_moved_msec < int(Config.AIM_HOLD_SEC * 1000.0)


## One simulation tick of the offline controls: 8-way move input, the mouse in world px, whether the
## mouse aims, use pressed this tick / held. make_frame() + step_frame(): the running action
## advances (and may end), the aim is updated, use may start an action (the selected hotbar item's),
## then the player moves (unless an action locks it) and faces the mouse while aiming or the
## movement otherwise. M4a: `dash` (Space this tick) and `interact` (F held). M6a: `skill` (the skill key 1
## this tick: the herbalist's potion throw). While `ui_locked` (a panel is open) the frame is empty. M9a: `skill_slot` (the skill
## key 2 / 3 / R pressed this tick: Skills.Slot, -1 = none; key 1 is `skill`); with `skills_on` a skill key pressed while a
## panel is open is refused (Skills.WHY_PANEL: the HUD marks it).
func tick_controls(input: Vector2i, mouse: Vector2, aiming: bool, use_pressed: bool, use_held: bool, delta: float,
		dash: bool = false, interact: bool = false, skill: bool = false, skill_slot: int = -1) -> void:
	if ui_locked:
		if skills_on and (skill or skill_slot >= 0):
			var slot: int = skill_slot if skill_slot >= 0 else Skills.Slot.IDENTITY
			_refuse_skill(slot, Skills.kit_skill(class_id(), slot), Skills.WHY_PANEL)
		input = Vector2i.ZERO
		aiming = false
		use_pressed = false
		use_held = false
		dash = false
		interact = false
		skill = false
		skill_slot = -1
	var f: NetProtocol.InputFrame = make_frame(input, mouse, aiming, use_pressed, use_held, dash, interact, skill,
		skill_slot)
	step_frame(f, delta)
	if f.op == NetProtocol.Op.USE and f.anim < 0:
		place_requested.emit(f.slot, f.cell)
	if f.altar_place:
		altar_place_requested.emit(f.cell)  # M5b: Main puts the carried altar down (or says why not)


## M5b: puts the purification channel into the next frame (Main, on F with nothing to pick up; the frame starts it
## when Purify.channel_refusal allows and the player stands free, PlayerSim.step).
func request_channel() -> void:
	_channel_pending = true


## M9a: the skill key pressed this tick other than key 1 (Skills.Slot: 2 = WEAPON, 3 = CHOICE, R = SIGNATURE; -1 = none).
static func pressed_skill_slot() -> int:
	if Input.is_action_just_pressed(&"skill_2"):
		return Skills.Slot.WEAPON
	if Input.is_action_just_pressed(&"skill_3"):
		return Skills.Slot.CHOICE
	if Input.is_action_just_pressed(&"skill_signature"):
		return Skills.Slot.SIGNATURE
	return -1


## M11b: the herd of this player's map (herd_provider; unset or none: null).
func herd_here() -> Creatures:
	if herd_provider.is_valid():
		var got: Creatures = herd_provider.call()
		return got
	return null


## M9a: the players the near-cursor pick may choose from (party_provider; unset: this player alone).
func party() -> Array[Player]:
	if party_provider.is_valid():
		var got: Array[Player] = party_provider.call()
		return got
	var alone: Array[Player] = [self]
	return alone


## M9a: a skill key of slot `slot` resolved by Skills.prepare into frame `f` (the skill's action toward the target tile, its
## slot and target; the herbalist's throw as M6's THROW frame), or refused (the HUD's mark, skill_refused).
func _skill_frame(f: NetProtocol.InputFrame, slot: int, mouse: Vector2) -> void:
	var prep: Skills.Prepared = Skills.prepare(self, slot, mouse, party())
	if prep.ok() and f.dash:
		# M9 review (PROVISIONAL README "M9a 거부"): the dash pressed in the same tick wins (PlayerSim: an action does not start
		# under a dash, the M6-fix rule), so the key is refused here with its HUD mark instead of vanishing (the host does the
		# same, SessionHost._skill).
		prep.why = Skills.WHY_BUSY
	if not prep.ok():
		_refuse_skill(slot, prep.id, prep.why)
		return
	f.cell = aim_cell
	f.skill = prep.id
	f.skill_slot = slot
	f.skill_target = prep.target.get_instance_id() if prep.target != null else 0
	if prep.id == Skills.POTION_THROW:
		f.op = NetProtocol.Op.THROW
		f.slot = inventory.selected
		f.anim = RigData.Anim.THROW
		f.item = prep.item
		f.throw_to = prep.throw_to
	else:
		f.op = NetProtocol.Op.SKILL  # M9c: a session sends it (the host resolves it again); offline Main plays it as resolved here
		f.anim = Skills.anim(prep.id)
		f.item = prep.id
		f.slot = inventory.selected  # M9b: the weapon skill's stack (its tier-1 damage and wear: Skills.weapon_stack)
		f.throw_to = prep.throw_to  # M9b: a point skill's point (Skills.reach_point)


## M9a: marks slot `slot` refused on the HUD (SkillState.refuse) and says why (skill_refused).
func _refuse_skill(slot: int, id: StringName, why: String) -> void:
	if why.is_empty():
		return
	skills.refuse(slot, why)
	skill_refused.emit(slot, id, why)


## M9c: a skill key of slot `slot` pressed while a panel holds the keys (a session's input, SessionBots.local_action; offline
## tick_controls does the same): refused with the HUD's mark (Skills.WHY_PANEL).
func refuse_skill_key(slot: int) -> void:
	if skills_on and slot >= 0:
		_refuse_skill(slot, Skills.kit_skill(class_id(), slot), Skills.WHY_PANEL)


## M9c: a session client shows a ward of `pct` percent with `ticks` left over this player (the host's ward events; 0 = none).
func show_ward(pct: int, ticks: int) -> void:
	if skills.ward_pct == pct and skills.ward_ticks == ticks:
		return
	skills.ward_pct = pct
	skills.ward_ticks = ticks
	_sync_view()


## M10b: a session client shows zeal of `pct` percent with `ticks` left on this player (the host's ZEAL events; 0 = none): the
## mark over its head (redrawn when it comes or goes), the local HUD's icon and bar. M10-fix: `from_prayer` = a prayer's zeal, not
## only a meditation's (the host's rule; kept should this client go on alone, Main._go_offline_combat).
func show_zeal(pct: int, ticks: int, from_prayer: bool = true) -> void:
	var was: bool = skills.zealous()
	skills.zeal_pct = pct if ticks > 0 else 0
	skills.zeal_ticks = ticks if pct > 0 else 0
	skills.zeal_from_prayer = from_prayer and skills.zealous()
	if was != skills.zealous():
		_sync_view()


## M9a: restores up to `amount` HP (PlayerSim.heal: not past the maximum, only while up). Returns the HP gained.
func heal_hp(amount: int) -> int:
	var st: PlayerSim = to_sim()
	var gained: int = st.heal(amount)
	if gained > 0:
		load_sim(st)
		_sync_view()
	return gained


## M5b: this player carries the altar now (Main: picked up / put down), shown over its head.
func set_carrying_altar(on: bool) -> void:
	carrying_altar = on
	altar_hold_ticks = 0
	altar_set_down_failed = false
	_sync_view()


## One tick of local input as an input frame (seq 0: a session numbers it). Updates the aim from the
## mouse; a use (pressed, or held with Config.ACTION_REPEAT_WHILE_HELD) of a tool in the selected
## hotbar slot becomes the frame's USE op when no action will still be playing in that frame. The
## look is the facing toward the mouse while aiming or using, -1 otherwise (facing by movement).
##
## M6a (with `potions_on`): a click (not held) with a potion selected drinks it (Config.DRINK_ANIM, when
## Potions.drink_refusal allows), and `skill` throws the selected potion toward the mouse (the throw action;
## Potions.throw_refusal: the herbalist's, Config.THROW_HERBALIST_ONLY). The drink is a USE frame, the throw (M6b)
## a THROW frame, with the action set; the potion works on its effect / release frame (Potions.impact_tick,
## action_impact).
##
## M9a (with `skills_on`): a skill key (`skill` = key 1, `skill_slot` = key 2 / 3 / R as Skills.Slot) goes through the skill kit
## instead (Skills.prepare: the common refusals, then the skill's own): it puts the skill's body action, the skill, its slot and
## the ally it goes to into the frame, or marks the slot refused (skill_refused). The herbalist's identity skill is M6's throw
## (a THROW frame with its potion), a healing or buff potion thrown at the ally nearest the cursor (● R42), poison at the cursor.
func make_frame(input: Vector2i, mouse: Vector2, aiming: bool, use_pressed: bool, use_held: bool, dash: bool = false,
		interact: bool = false, skill: bool = false, skill_slot: int = -1) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, input)
	f.dash = dash
	f.interact = interact
	f.aim = Combat.aim_code(mouse - Combat.aim_origin(sim_position))  # M4-fix: the drawn shot flies through the mouse
	# M9c: a SKILL's and a THROW's point on the wire, in whole px (the host's near-cursor pick, a point skill's point, a throw's
	# landing): the skill kit below works from it too, so offline and the host resolve a press alike.
	f.cursor = Vector2(NetProtocol.wire_point(mouse))
	if data != null:
		f.map = data.map_id  # M3b: a request aims at a tile of the map this player stands on
	aim_point = mouse
	var to_mouse: Vector2 = mouse - sim_position
	aim_sector = Aim.sector(to_mouse, aim_sector)
	aim_cell = Aim.target_cell(sim_position, aim_sector)
	var free: bool = vitals.alive() and not (action_anim >= 0 and action_tick + 1 < action_ticks(action_anim))
	var selected: ItemStack = inventory.selected_stack()
	var slot: int = skill_slot if skill_slot >= 0 else (Skills.Slot.IDENTITY if skill else -1)
	if prayer_role == Prayer.Role.PRAYING:
		# M10a: praying. The move keys are the answers (they stay in the frame; step_frame does not move); nothing else starts:
		# a skill key is refused with its HUD mark, a click, a throw or Space says why in the log (PROVISIONAL README "M10a F").
		f.dash = false
		_channel_pending = false
		skill_aim_target = null
		skill_aim_refused = false
		if skills_on and slot >= 0:
			_refuse_skill(slot, Skills.kit_skill(class_id(), slot), Skills.WHY_PRAYING)
		elif use_pressed or skill or dash:
			prayer_refused.emit("use" if use_pressed else ("throw" if skill else "dash"))
		_aim_input = false
		f.look = -1
		return f
	if skills_on:
		skill_aim_target = Skills.aim_target(self, party(), f.cursor)  # M9 review: none while a panel is open or carrying
		skill_aim_refused = Skills.aim_refused(self, skill_aim_target)
	if _channel_pending:
		_channel_pending = false
		if purify_on and free and not carrying_altar and data != null \
				and Purify.channel_refusal(data, class_id(), sim_position).is_empty():
			f.channel = true
	if carrying_altar:
		# M5b: the click is the altar's (Main puts it down); nothing is used or thrown meanwhile. M5c: in a session the
		# click is the ALTAR_PLACE request (the host puts it down where it allows).
		f.altar_place = use_pressed and vitals.alive()
		f.cell = aim_cell
		if f.altar_place:
			f.op = NetProtocol.Op.ALTAR_PLACE
		if skills_on and slot >= 0:
			_refuse_skill(slot, Skills.kit_skill(class_id(), slot), Skills.refusal(self, slot))  # M9a: carrying the altar
	elif skills_on and slot >= 0:
		_skill_frame(f, slot, f.cursor)  # M9a: the skill kit (the herbalist's key 1 = M6's throw through it; M9c: whole px)
	elif free and potions_on and skill:
		var why_throw: String = Potions.throw_refusal(class_id(), selected)
		if why_throw.is_empty():
			f.op = NetProtocol.Op.THROW  # M6b: its own request (the point it is thrown at rides on the wire)
			f.slot = inventory.selected
			f.cell = aim_cell
			f.anim = RigData.Anim.THROW
			f.item = selected.id
			# M6-fix: in whole px, as the wire carries it (NetProtocol THROW), so offline and the host throw at the same
			# point; the arena clamps it to Config.THROW_RANGE_PX again when it leaves the hand (Arena.throw_potion).
			f.throw_to = Potions.throw_target(Combat.body_point(sim_position), mouse).round()
		else:
			potion_refused.emit("throw", why_throw)
	elif free and potions_on and use_pressed and selected != null and Potions.is_drink(selected.id):  # M11a: the meat too
		var why_drink: String = Potions.drink_refusal(selected.id, selected.grade, vitals)
		if why_drink.is_empty():
			f.op = NetProtocol.Op.USE
			f.slot = inventory.selected
			f.cell = aim_cell
			f.anim = Config.DRINK_ANIM
			f.item = selected.id
		else:
			potion_refused.emit("drink", why_drink)
	elif free and capture_on and use_pressed and selected != null and Capture.is_snare(selected.id):
		# M11b: the snare, a click (not repeated), at the creature under the mouse.
		var quarry: CreatureSim = Capture.target_at(herd_here(), mouse)
		var why_snare: String = Capture.refusal(self, quarry)
		if why_snare.is_empty():
			f.op = NetProtocol.Op.USE
			f.slot = inventory.selected
			f.cell = aim_cell
			f.anim = Config.CAPTURE_ANIM
			f.item = selected.id
			f.capture_id = quarry.id
		else:
			capture_refused.emit(why_snare, quarry)
	elif free and purify_on and use_pressed and selected != null and Purify.is_holy_water(selected.id):
		# M5b: holy water is poured on the target tile (a click, not repeated); it works on its effect frame (Main).
		var why_pour: String = Purify.holy_water_refusal(data, sim_position, aim_cell) if data != null else Purify.WHY_NOTHING
		if why_pour.is_empty():
			f.op = NetProtocol.Op.USE
			f.slot = inventory.selected
			f.cell = aim_cell
			f.anim = Config.HOLY_WATER_ANIM
			f.item = selected.id
		else:
			purify_refused.emit("holy water", why_pour)
	elif free and gear_on and use_pressed and selected != null and Gear.is_armor(selected.id):
		equip_requested.emit(inventory.selected)  # M7a: Main puts it on (no frame, nothing to predict)
	elif free and gear_on and (use_pressed or use_held) and Gear.unusable(selected):
		if use_pressed:
			gear_refused.emit("use", Gear.WHY_BROKEN)  # M7a, Config.GEAR_BROKEN_UNUSABLE
	elif free and (use_pressed or (use_held and Config.ACTION_REPEAT_WHILE_HELD)):
		var anim: int = WorldItems.use_action(sim_position, inventory, inventory.selected, aim_cell)
		if anim >= 0:
			f.op = NetProtocol.Op.USE
			f.slot = inventory.selected
			f.cell = aim_cell
			f.anim = anim
			f.item = inventory.selected_stack().id
		elif use_pressed and (WorldItems.placeable_in(inventory, inventory.selected) != WorldData.PLACEABLE_NONE \
				or (farming_on and Farming.seed_kind_in(inventory, inventory.selected) != Farming.KIND_NONE) \
				or not Building.piece_in(inventory, inventory.selected).is_empty()) \
				and WorldItems.in_reach(sim_position, aim_cell):
			# M7b: a build piece goes down the same way (a click; offline Main builds it: place_requested).
			# M5a: seeds go down the same way (a click, offline Main plants them: place_requested).
			# M3a: a placeable (the torch) goes down on a click, not repeated while held. A USE without an
			# action: the host (or offline Main) places it; nothing is predicted.
			f.op = NetProtocol.Op.USE
			f.slot = inventory.selected
			f.cell = aim_cell
			f.item = inventory.selected_stack().id
	if f.channel:
		# M5c: the channel is a request of its own in a session (CHANNEL; the host decides it again); a frame that
		# already carries another request (a click this tick) starts no channel.
		if f.op == NetProtocol.Op.NONE and f.anim < 0:
			f.op = NetProtocol.Op.CHANNEL
		else:
			f.channel = false
	_aim_input = aiming or use_held
	f.look = Aim.facing(to_mouse, facing) if (_aim_input or f.anim >= 0) else -1
	return f


## Runs one input frame with PlayerSim.step (the frame's `anim` = the use it starts, -1 for none)
## and shows the result. Emits action_finished, then action_started. Returns the step's event bits
## (PlayerSim.STARTED, DIED, RESPAWN ...; M4b: the host handles a death and a respawn with them).
func step_frame(frame: NetProtocol.InputFrame, delta: float) -> int:
	last_input = frame.dir
	interact_held = frame.interact
	var before: int = action_anim
	var poison_amount: int = vitals.poison_damage
	var was_channel: bool = channel_tick > 0
	var hp_before: int = vitals.hp
	var st: PlayerSim = to_sim()
	var events: int = 0
	if prayer_role == Prayer.Role.PRAYING:
		# M10a: praying, the move keys are answers (last_input keeps them for Prayer.step): no move, no dash, no action, no channel;
		# the player faces the altar.
		events = st.step(data, Vector2i.ZERO, prayer_face, -1, frame.cell, delta, false, frame.interact, frame.aim, false)
	else:
		# M10a: a meditating player standing still faces the altar (a move breaks the meditation, Prayer).
		var look: int = prayer_face if prayer_role == Prayer.Role.MEDITATING and frame.dir == Vector2i.ZERO and frame.look < 0 \
			else frame.look
		events = st.step(data, frame.dir, look, frame.anim, frame.cell, delta, frame.dash, frame.interact, frame.aim,
			frame.channel)
	load_sim(st)
	if events & PlayerSim.STARTED:
		action_item = frame.item
		# M6a: which stack it plays (a potion's grade) and where a throw lands.
		action_slot = frame.slot
		var played: ItemStack = inventory.stack_at(frame.slot)
		action_grade = played.grade if played != null and played.id == frame.item else ItemDB.normalize_grade(frame.item)
		action_target = frame.throw_to
		# M9a: the skill it plays (&"" for a use or a drink), its slot and the ally it goes to.
		action_skill = frame.skill
		action_skill_slot = frame.skill_slot if not frame.skill.is_empty() else -1
		action_skill_target = frame.skill_target if not frame.skill.is_empty() else 0
		action_capture = frame.capture_id  # M11b
	elif action_anim < 0:
		action_skill = &""
		action_skill_slot = -1
		action_skill_target = 0
		action_capture = 0
	if skills_on:
		# M9a: the game clock (cooldowns, the refusal mark) and the class meter; a poison tick is damage taken (the paladin's
		# conviction), a death loses the meter. M9c: a session host's members count their clock on host time instead.
		if not skills_clock_external:
			skills.tick(class_id(), walking or vitals.dashing(), vitals.alive())
		if events & PlayerSim.POISON_TICK:
			skills.on_hurt(class_id(), maxi(hp_before - vitals.hp, 0))
		if events & PlayerSim.DIED:
			skills.on_death()
	aim_active = (_aim_input or action_anim >= 0) and vitals.alive()
	_sync_view()
	if events & PlayerSim.ENDED:
		action_finished.emit(before)
	if events & PlayerSim.STARTED:
		action_started.emit(action_item, action_anim, action_cell)
		if not action_skill.is_empty():
			skill_started.emit(action_skill_slot, action_skill)
	if action_anim >= 0 and action_tick == impact_tick_of(action_item, action_anim):
		action_impact.emit(action_item, action_anim, action_cell)
	if events & PlayerSim.CHANNEL_STARTED:
		channel_started.emit(channel_cell)
	if events & PlayerSim.CHANNEL_DONE:
		channel_done.emit(channel_cell)
	elif was_channel and channel_tick == 0:
		var why: String = "down"
		if events & PlayerSim.CHANNEL_BROKEN:
			why = "dash" if frame.dash else ("use" if RigData.is_action(frame.anim) else "moved")
		channel_broken.emit(why)
	if events & PlayerSim.POISON_TICK:
		hurt.emit(poison_amount, events & PlayerSim.DOWNED != 0)
	if events & PlayerSim.DIED:
		died.emit()
	if events & PlayerSim.RESPAWN:
		respawn_due.emit()
	return events


## The tick of an action played with `item` on which it lands: a weapon's hit frame (Combat.impact_tick),
## M6a: a potion's effect / release frame (Potions.impact_tick). M5b: holy water's effect frame (Purify.impact_tick).
static func impact_tick_of(item: StringName, anim: int) -> int:
	if Skills.is_skill(item):
		return Skills.impact_tick(item)  # M9a: a skill's action lands on its own frame (Config.SKILLS "impact")
	if Potions.is_drink(item):
		return Potions.impact_tick(anim)
	if Capture.is_snare(item):
		return Capture.impact_tick()  # M11b
	if Purify.is_holy_water(item):
		return Purify.impact_tick()
	var farm_tick: int = Farming.impact_tick(item)  # M5a: the hoe tills, the watering can waters on their own frame
	if farm_tick >= 0:
		return farm_tick
	if Gear.base(item) == Forest.AXE:
		return Forest.impact_tick()  # M7b: the axe's chop
	return Combat.impact_tick(item)


## M6a: potion `id` at `grade` works on this player (drunk or splashed, Potions.apply). Returns the PlayerSim
## event bits (HEALED, BUFFED, POISONED; 0 = nothing happened).
func apply_potion(id: StringName, grade: int) -> int:
	var st: PlayerSim = to_sim()
	var events: int = Potions.apply(st, id, grade)
	if events != 0:
		load_sim(st)
		_sync_view()
	return events


## The simulation state (a copy).
func to_sim() -> PlayerSim:
	var st: PlayerSim = PlayerSim.new()
	st.pos = sim_position
	st.facing = facing
	st.walking = walking
	st.action = action_anim
	st.action_tick = action_tick
	st.action_cell = action_cell
	st.action_aim = action_aim
	st.vit = vitals.copy()
	st.channel_tick = channel_tick
	st.channel_cell = channel_cell
	return st


## Takes a simulation state (no drawing: step_frame() and show_state() do that).
func load_sim(st: PlayerSim) -> void:
	sim_position = st.pos
	facing = st.facing
	walking = st.walking
	action_anim = st.action
	action_tick = st.action_tick
	action_cell = st.action_cell
	action_aim = st.action_aim
	vitals = st.vit
	channel_tick = st.channel_tick
	channel_cell = st.channel_cell


## M4a: a hit of `amount` (PlayerSim.hurt: nothing while down, dead or invulnerable). Returns the
## PlayerSim event bits (HURT, DOWNED; 0 = it did not land). M7a: `armored` (a heretic's knife) with `gear_on`: the worn
## armour takes its defence off (Gear.after_armor) and wears when the hit lands (Gear.wear_armor). M11b: the world's collection adds its
## defence, with or without armour on.
func take_hit(amount: int, armored: bool = false) -> int:
	var st: PlayerSim = to_sim()
	var was_channel: bool = channel_tick > 0
	if armored and gear_on:
		amount = Gear.after_armor(amount, inventory, Collection.defence_bonus(data))
	if skills_on:
		amount = Skills.after_ward(amount, skills)  # M9b: the oath's ward, after the armour
	var hp_before: int = vitals.hp
	var events: int = st.hurt(amount)
	if events == 0:
		return 0
	if armored and gear_on:
		Gear.wear_armor(inventory)
	load_sim(st)
	if skills_on:
		skills.on_hurt(class_id(), hp_before - vitals.hp)  # M9a: the paladin's conviction grows with the damage taken
	_sync_view()
	if was_channel:
		channel_broken.emit("down" if events & PlayerSim.DOWNED else "hit")  # M5b
	hurt.emit(amount, events & PlayerSim.DOWNED != 0)
	return events


## M4a: a revive (combat/arena.gd) gets a downed player up with Config.REVIVE_HP.
func revive_now() -> void:
	var st: PlayerSim = to_sim()
	st.revive()
	load_sim(st)
	_sync_view()
	revived.emit()


## M4a: back to full (a respawn): vitals reset, no action, the picture shown again.
func respawn_vitals() -> void:
	vitals.reset()
	action_anim = -1
	action_tick = 0
	walking = false
	_sync_view()


## M4b: the respawn (PlayerSim.respawn, the rule the host and a client's prediction share): on `p_data`
## (the surface) at feet `feet`, facing Config.SPAWN_FACING, full; drawn there at once.
func respawn_at(p_data: WorldData, feet: Vector2) -> void:
	data = p_data
	var st: PlayerSim = to_sim()
	st.respawn(feet)
	load_sim(st)
	tick_from = feet
	_sync_view()


## Aiming after a frame stepped elsewhere (a client's prediction): the last make_frame()'s input
## or an action playing.
func refresh_aim() -> void:
	aim_active = _aim_input or action_anim >= 0


## What the player holds: the received state's item for a player shown from states, else its
## selected hotbar stack (&"" for an empty hand).
func held_id() -> StringName:
	if held_from_state:
		return state_held
	var stack: ItemStack = inventory.selected_stack()
	return stack.id if stack != null else &""


## Starts body action `anim` toward the current aim (facing and target fixed until it ends).
func start_action(anim: int, item: StringName = &"") -> void:
	if not RigData.is_action(anim):
		return
	action_anim = anim
	action_tick = 0
	action_item = item
	action_cell = aim_cell
	facing = Aim.facing(aim_point - sim_position, facing)
	walking = false
	_sync_view()
	action_started.emit(item, anim, action_cell)


## Shows body action `anim` frozen at `frame` (-1 = its middle frame) and stops reading input
## (--test-action screenshots). With a test aim the aim and facing follow it first.
func freeze_action(anim: int, frame: int) -> void:
	if not RigData.is_action(anim):
		return
	local_input = false
	if test_aim != null:
		var offset: Vector2 = test_aim
		aim_point = sim_position + offset
		aim_sector = Aim.sector(offset, aim_sector)
		aim_cell = Aim.target_cell(sim_position, aim_sector)
		aim_active = true
		facing = Aim.facing(offset, facing)
	var f: int = frame if frame >= 0 else RigData.frame_count(anim) / 2
	action_anim = anim
	action_tick = clampi(f, 0, RigData.frame_count(anim) - 1) * Config.ACTION_FRAME_TICKS
	action_cell = aim_cell
	walking = false
	_sync_view()


## The frame of the playing action (0 when none).
func action_frame() -> int:
	return action_tick / Config.ACTION_FRAME_TICKS if action_anim >= 0 else 0


## How many simulation ticks body action `anim` lasts.
static func action_ticks(anim: int) -> int:
	return PlayerSim.action_ticks(anim)


func _process(_delta: float) -> void:
	update_draw(Engine.get_physics_interpolation_fraction())


## Start of a simulation tick (every physics tick, before anything steps this player; code that
## drives a player outside the tree calls it itself). Whatever moves the player during the tick is
## drawn from here.
func begin_tick() -> void:
	tick_from = sim_position


## One simulation tick with an 8-way input (-1/0/1 per axis) and nothing else (the M1 frame: no
## look, no use). The facing follows the input (Movement.facing_for).
func apply_input(input: Vector2i, delta: float) -> void:
	step_frame(NetProtocol.InputFrame.new(0, input), delta)


## Shows a state decided elsewhere. `tick` = it is this player's move in the current simulation tick
## (a client's own prediction step): drawn from the tick's start like apply_input. Otherwise (a host
## correction, another player's interpolated state) the drawing keeps its offset to sim_position, so
## a correction moves the whole step and an unchanged state changes nothing.
## `p_action` / `p_action_tick` (M2b): the body action shown (-1 = none) and its frames so far.
## `p_vitals` (M4b): the vitals shown (a copy is kept; null = at rest: full and up).
## `p_channel` (M5c): the purification channel's ticks shown (0 = none; it purifies around the feet tile).
func show_state(pos: Vector2, p_facing: int, p_walking: bool, tick: bool = false, p_action: int = -1,
		p_action_tick: int = 0, p_vitals: Vitals = null, p_channel: int = 0) -> void:
	if not tick:
		tick_from += pos - sim_position
	sim_position = pos
	facing = p_facing
	walking = p_walking
	action_anim = p_action if RigData.is_action(p_action) else -1
	action_tick = p_action_tick if action_anim >= 0 else 0
	vitals = p_vitals.copy() if p_vitals != null else Vitals.new()
	channel_tick = maxi(p_channel, 0) if action_anim < 0 else 0
	if channel_tick > 0:
		channel_cell = Aim.feet_cell(pos)
	_sync_view()


## M3a: moves the player onto another map's data at feet position `feet`, facing south, any action
## stopped (Main.travel). M4-fix: a dash under way stops too (its cooldown runs on), so a dash pressed just
## before F on the stairs does not carry on from the arrival point (host, offline and, through the host's
## state, the prediction alike).
func set_world(p_data: WorldData, feet: Vector2) -> void:
	data = p_data
	action_anim = -1
	action_tick = 0
	walking = false
	facing = RigData.Dir.SOUTH
	vitals.dash_ticks = 0
	vitals.dash_dir = Vector2i.ZERO
	channel_tick = 0  # M5b: another map ends a purification channel
	teleport(feet)


## Puts the player at a feet position (spawn, tests). No drawing between the old and new place.
func teleport(feet: Vector2) -> void:
	sim_position = feet
	tick_from = feet
	_sync_view()


## Draws the node at `fraction` (0..1) of the way from tick_from to sim_position, on whole pixels.
## A tick that moved the player further than MAX_DRAWN_STEP_PX (the host applying several of a
## client's frames at once while it catches up) is drawn where it ended: the straight line between
## its ends could cut a corner the steps went around (through the altar, for instance).
func update_draw(fraction: float) -> void:
	if smooth_draw and tick_from.distance_to(sim_position) <= MAX_DRAWN_STEP_PX:
		position = draw_position(tick_from, sim_position, fraction)
	else:
		position = sim_position.round()


## Whole-pixel point `fraction` (clamped to 0..1) of the way from `from` to `to`.
static func draw_position(from: Vector2, to: Vector2, fraction: float) -> Vector2:
	return from.lerp(to, clampf(fraction, 0.0, 1.0)).round()


func _sync_view() -> void:
	position = sim_position.round()
	character.direction = facing as RigData.Dir
	character.walking = walking
	character.visible = vitals.life != Vitals.Life.DEAD
	character.modulate = HIT_FLASH if vitals.flash_ticks > 0 else Color.WHITE
	var kinds: Array[int] = EffectMarks.kinds_of(vitals)  # M6a
	if skills_on and skills.warded() and vitals.life != Vitals.Life.DEAD:
		kinds.append(EffectMarks.Kind.WARD)  # M9b: the paladin's oath wards this player
	if skills.zealous() and vitals.life != Vitals.Life.DEAD:
		kinds.append(EffectMarks.Kind.ZEAL)  # M10a: the prayer's zeal
	effect_marks.show_kinds(kinds)
	if vitals.life == Vitals.Life.DOWN:
		character.show_action(RigData.Anim.DEATH, mini(vitals.life_ticks / Config.DEATH_FRAME_TICKS,
			RigData.frame_count(RigData.Anim.DEATH) - 1))
	elif vitals.hurt_ticks > 0:
		character.show_action(RigData.Anim.HURT, mini((Config.HURT_TICKS - vitals.hurt_ticks) / Config.HURT_FRAME_TICKS,
			RigData.frame_count(RigData.Anim.HURT) - 1))
	elif action_anim >= 0:
		character.show_action(action_anim, action_frame())
	elif channel_tick > 0:
		character.show_action(Config.PURIFY_ANIM, channel_frame(channel_tick))  # M5b: a placeholder pose, looped
	else:
		character.end_action()
	altar_mark.visible = carrying_altar  # M5b


## M5b: the frame of Config.PURIFY_ANIM a channel `ticks` in shows (the action looped, Config.ACTION_FRAME_TICKS a
## frame).
static func channel_frame(ticks: int) -> int:
	return ((maxi(ticks, 1) - 1) / Config.ACTION_FRAME_TICKS) % RigData.frame_count(Config.PURIFY_ANIM)


## The move_* actions (WASD / arrows) as an 8-way input.
static func read_input() -> Vector2i:
	var x: int = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var y: int = int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	return Vector2i(x, y)

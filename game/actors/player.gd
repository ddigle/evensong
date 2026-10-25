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
## M7a (`gear_on`, offline; a session's players have it off until M7c): a click with armour selected asks to put it on
## (equip_requested; Main, items/gear.gd); a heretic's knife hit (take_hit with `armored`) is lessened by the worn armour
## and wears it; with Config.GEAR_BROKEN_UNUSABLE a broken item makes no frame (gear_refused).
## M7b: a click with a build piece selected is a USE without an action like a torch's (place_requested: offline Main builds,
## items/building.gd; a session's host refuses it until M7c); the axe plays its own body action and lands on
## Forest.impact_tick (action_impact: offline Main chops).

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
## M7a: armour, its defence and its wear on knife hits (Main turns it on offline; off in a session until M7c).
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
	_sync_view()


func class_id() -> String:
	return character.class_id


func _physics_process(delta: float) -> void:
	begin_tick()
	if local_input and data != null:
		if controls:
			tick_controls(read_input(), mouse_world(), mouse_aiming(), Input.is_action_just_pressed(&"use_item"),
				Input.is_action_pressed(&"use_item"), delta, Input.is_action_just_pressed(&"dash"),
				Input.is_action_pressed(&"interact"), Input.is_action_just_pressed(&"skill_1"))
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
## this tick: the herbalist's potion throw). While `ui_locked` (a panel is open) the frame is empty.
func tick_controls(input: Vector2i, mouse: Vector2, aiming: bool, use_pressed: bool, use_held: bool, delta: float,
		dash: bool = false, interact: bool = false, skill: bool = false) -> void:
	if ui_locked:
		input = Vector2i.ZERO
		aiming = false
		use_pressed = false
		use_held = false
		dash = false
		interact = false
		skill = false
	var f: NetProtocol.InputFrame = make_frame(input, mouse, aiming, use_pressed, use_held, dash, interact, skill)
	step_frame(f, delta)
	if f.op == NetProtocol.Op.USE and f.anim < 0:
		place_requested.emit(f.slot, f.cell)
	if f.altar_place:
		altar_place_requested.emit(f.cell)  # M5b: Main puts the carried altar down (or says why not)


## M5b: puts the purification channel into the next frame (Main, on F with nothing to pick up; the frame starts it
## when Purify.channel_refusal allows and the player stands free, PlayerSim.step).
func request_channel() -> void:
	_channel_pending = true


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
func make_frame(input: Vector2i, mouse: Vector2, aiming: bool, use_pressed: bool, use_held: bool, dash: bool = false,
		interact: bool = false, skill: bool = false) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, input)
	f.dash = dash
	f.interact = interact
	f.aim = Combat.aim_code(mouse - Combat.aim_origin(sim_position))  # M4-fix: the drawn shot flies through the mouse
	if data != null:
		f.map = data.map_id  # M3b: a request aims at a tile of the map this player stands on
	aim_point = mouse
	var to_mouse: Vector2 = mouse - sim_position
	aim_sector = Aim.sector(to_mouse, aim_sector)
	aim_cell = Aim.target_cell(sim_position, aim_sector)
	var free: bool = vitals.alive() and not (action_anim >= 0 and action_tick + 1 < action_ticks(action_anim))
	var selected: ItemStack = inventory.selected_stack()
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
	elif free and potions_on and use_pressed and selected != null and Potions.is_potion(selected.id):
		var why_drink: String = Potions.drink_refusal(selected.id, selected.grade, vitals)
		if why_drink.is_empty():
			f.op = NetProtocol.Op.USE
			f.slot = inventory.selected
			f.cell = aim_cell
			f.anim = Config.DRINK_ANIM
			f.item = selected.id
		else:
			potion_refused.emit("drink", why_drink)
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
	var st: PlayerSim = to_sim()
	var events: int = st.step(data, frame.dir, frame.look, frame.anim, frame.cell, delta, frame.dash, frame.interact,
		frame.aim, frame.channel)
	load_sim(st)
	if events & PlayerSim.STARTED:
		action_item = frame.item
		# M6a: which stack it plays (a potion's grade) and where a throw lands.
		action_slot = frame.slot
		var played: ItemStack = inventory.stack_at(frame.slot)
		action_grade = played.grade if played != null and played.id == frame.item else ItemDB.normalize_grade(frame.item)
		action_target = frame.throw_to
	aim_active = (_aim_input or action_anim >= 0) and vitals.alive()
	_sync_view()
	if events & PlayerSim.ENDED:
		action_finished.emit(before)
	if events & PlayerSim.STARTED:
		action_started.emit(action_item, action_anim, action_cell)
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
	if Potions.is_potion(item):
		return Potions.impact_tick(anim)
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
## armour takes its defence off (Gear.after_armor) and wears when the hit lands (Gear.wear_armor).
func take_hit(amount: int, armored: bool = false) -> int:
	var st: PlayerSim = to_sim()
	var was_channel: bool = channel_tick > 0
	if armored and gear_on:
		amount = Gear.after_armor(amount, inventory)
	var events: int = st.hurt(amount)
	if events == 0:
		return 0
	if armored and gear_on:
		Gear.wear_armor(inventory)
	load_sim(st)
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
	effect_marks.show_kinds(EffectMarks.kinds_of(vitals))  # M6a
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

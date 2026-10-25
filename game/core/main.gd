class_name Main
extends Node2D
## Root of scenes/main.tscn, the run scene (M1 + M2a + M2b).
##
## Offline (no --host / --join): the world (world.tscn without its free camera), the local player
## (class from --class, Config.DEFAULT_CLASS without it) on spawn slot 0, the other slice classes as
## static dummies on the next slots facing the altar (so all five signatures show), and a
## PlayerCamera centred on the local player. M2a: the local player has `controls` on (mouse aim,
## hotbar use, body actions, actors/player.gd), the HUD shows its hotbar (ui/hud.gd) and a
## TargetMarker shows the aimed tile (world/target_marker.gd, between the ground and the entities).
## In a session (--host / --join, net/session.gd): no dummies; the session creates every player
## and hands over the local one, which the camera follows; it has `controls` on (mouse aim, target
## marker) and the session builds its frames. The HUD shows its inventory (a client's is the host's
## copy). When the session ends with --net-out (a test instance), or with a refusal or a failed join,
## the process quits with the session's code; a client that loses its host without --net-out plays
## on alone.
##
## Keys (PROVISIONAL, README "임시값"): WASD / arrows move (8 ways), mouse aims, left click uses
## the selected hotbar item, Q / E select the hotbar slot left / right, Tab shows the inventory,
## F picks up what lies on the target tile (M2b: a gatherable, else a drop).
## Development keys: F3 debug lines, F4 evening + altar light on / off, F5 give the debug kit, F6 play
## the next body action (offline; all eight, also magic and throw that no item plays yet), F7 drop
## the selected stack on the target tile (M2b).
## Offline, F / F7 / F5 / Q / E apply at once through the same rules the host uses
## (items/world_items.gd); in a session they become requests on the local player's next frame.
##
## M3a (offline): two maps, each its own GameWorld: the surface (World) and the first dungeon
## (Dungeon, added here, hidden until entered). F on the surface's dungeon entrance takes the local
## player to the dungeon's arrival point, F on the dungeon's exit stairs back to just south of the
## entrance (travel(): the player node moves into the other world, the camera, the marker and the
## darkness switch with it; the dummies stay on the surface). A pickaxe swing that lands
## (Player.action_impact) mines (items/mining.gd), a click with a torch places it (Player.
## place_requested). --start-map=dungeon starts in the dungeon (offline); offline, --bot drives the
## local player (net/net_bot.gd, for screenshots and tests).
## M3b (sessions): both maps exist here too. The host generates the dungeon like offline; a client
## adds an empty dungeon world that the session fills when the host sends it the map. F on the
## entrance or stairs is a TRAVEL request; the session moves the player and says so
## (NetSession.local_map_changed), and Main shows that map (the camera, the marker, the darkness).
## M4a (offline; a session has no enemy, damage or dash yet, M4b): each map has an Arena
## (combat/arena.gd: heretics, shots, the shrine, the spawner) and a CombatView drawing it; the arena of
## the map the local player is on steps every physics tick after the players. The local player starts
## with its class weapon in hotbar slot Config.START_WEAPON_SLOT + 1; Space dashes; a weapon's hit frame
## (Player.action_impact) attacks (Arena.player_attack), except a pickaxe aimed at a wall, which mines
## (Combat.is_mining_swing); dying drops the death bag (WorldItems.death_drop); the respawn puts the
## player back at the altar (spawn slot 0, the surface). Test flags (--test-at, --test-heretic,
## --test-down, --test-ally, --test-shrine-hp) set scenes up for screenshots and tests.
## M4b (sessions): the session owns the combat (net/session_host.gd: an arena and a view per map on the
## host; net/net_combat.gd on a client) and the death, bag and respawn of every player; Main draws the
## HUD of the local player as before. A client that loses its host and plays on alone gets offline
## arenas from then on (the host's heretics are gone with the host).
## M6a (offline; in a session crafting, drinking, throwing and effects stay off until M6b, M3a / M4a style):
## Tab next to a station (the alchemy table, items/crafting.gd, Config.STATION_REACH_TILES) opens the crafting
## panel (ui/crafting_panel.gd) with the inventory and makes the player stand (Player.ui_locked); W / S or the
## arrows pick a row, F or Enter (or a click) crafts it, Tab or Esc closes it; walking away, going down or
## another map closes it too. Away from a station Tab shows the inventory as before. The alchemy table is
## placed like a torch (--give=alchemy_table, WorldItems.place with the bodies around). A potion's effect frame
## (Player.action_impact with a potion) drinks it (Potions.apply), a throw's release frame lets the bottle go
## into the arena (Arena.throw_potion); the skill key 1 throws (the herbalist's).
## M6b (sessions): the same keys. Tab next to a station on the local player's map opens the same panel (the
## station came with the world snapshot or an edit), a row crafted is a CRAFT request to the host (not
## predicted: the host's inventory comes back), drinking and throwing are frames the session sends (the
## client predicts the action, the host decides the effect); the alchemy table is placed like a torch, by the
## host. A bot's tab / craft in a session come here through NetSession.bot_ui.
## M5a (offline; M5c: a session's farms are the host's, net/session_host.gd): each map has a Farm (world/farm.gd), stepped every physics
## tick after the players (Config.FARM_RUNS_WITHOUT_PLAYERS: every map, the local player's or not); its edits go into
## the world. The hoe's landing frame tills the target tile, the watering can's waters it, the sickle aimed at a crop
## harvests it (Farming.is_harvest_swing; elsewhere it attacks as before), a click with seeds plants them (Player.
## place_requested, like the torch), a wild herb picked gives a seed (Config.SEEDS_PER_WILD_HERB). --test-field puts
## fields down at the start (screenshots, tests).
## M5b (offline; M5c: in a session the host does all of it): holy water's effect frame purifies the corrupted tiles around
## the target (Purify.pour); F with nothing to pick up on the target tile starts the paladin's purification channel when
## corruption is on or next to the feet tile (Purify.channel_refusal, Player.request_channel); a finished channel purifies
## around its tile (Purify.channel_done). F held Config.ALTAR_PICKUP_HOLD_TICKS on an altar tile picks the altar up
## (AltarMove; the player carries it: no light, no safe zone, nobody respawns meanwhile), a click puts it down where
## AltarMove.place_refusal allows (an AltarGhost shows where), and the carrier going down sets it down nearby
## (AltarMove.set_down_rect). Whatever follows the altar follows the world (GameWorld.altar_moved: the light; the arena
## syncs itself; the dummies stand on the new spawn slots).
## M5c (sessions): the local player farms, purifies and carries the altar with the same keys; the frames carry the
## requests (a seed's or holy water's USE, CHANNEL, ALTAR_LIFT, ALTAR_PLACE: net/session_host.gd) and the host decides.
## Main shows what this machine has: the channels' motes (_show_purify, from the players' states) and the ghost while
## the local player carries the altar (from the host's state).
## M7a (offline; in a session the stations, the chest, the new recipes and armour are refused and nothing wears until
## M7c): the workbench, the anvil and the relic bench are stations like the alchemy table (Tab next to one); Tab away from
## every station opens the hand recipes once one is unlocked (the workbench from logs). A weapon's hit frame attacks with
## its tier-1 damage (Gear.attack_damage) and wears it (Gear.wear_weapon); a click with armour selected puts it on (a
## click on the armour slot of the open inventory takes it off); a death wears every item with durability (Gear.
## wear_on_death). F at a storage chest opens the chest panel (ui/chest_panel.gd) with the inventory: a click moves a
## stack between them (Storage.store / take).
## M7b (offline; in a session the host refuses building, right-click and the door's F do nothing and the axe swings without
## chopping until M7c): a click with a build piece selected puts it on the target tile (Building.build: the stone wall, the
## door, the floor, the lantern post, cheaper in the altar's light); right-click takes a built piece down (Building.demolish,
## a piece back); F on a door opens or closes it (Building.toggle_door); the axe's landing frame chops the tree it is aimed
## at (Forest.chop: logs, the stump); every map has a Forest whose stumps grow back (step_forests, like the farms). A
## BuildGhost shows where the selected piece would go and whether it may. --test-build puts pieces down at the start.
## M7c (sessions): the same keys send requests the host decides (net/session_host.gd): a click with a station, the chest or a
## piece is a USE, right-click DEMOLISH, F on a door DOOR (SessionHost.attach_local_op), the armour click and the armour slot
## ARMOR, a click in the chest panel CHEST; F at a chest opens its panel here (NetSession.chest_wanted) on this machine's
## world, whose chest slots the host's edits keep; Tab away from every station opens the hand recipes (a CRAFT request).
## The build ghost is drawn from this machine's world (gold or red is this machine's answer; the host decides again).

## Feet offset (px) from the altar centre where --test-action-lineup puts the camera.
const LINEUP_CENTER: Vector2i = Vector2i(0, 110)
const LINEUP_STEP: int = 56

var player: Player
var dummies: Array[Character] = []
## M3a: the worlds by map id (offline: the surface and the dungeon; in a session the surface only),
## and the map the local player is on.
var worlds: Dictionary[int, GameWorld] = {}
var current_map: int = Config.MAP_SURFACE
## M3a: offline --bot (null without it).
var bot: NetBot
var hud: Hud
var marker: TargetMarker
## M4a (offline): an arena and its view per map; players that are not the local one (--test-ally).
var arenas: Dictionary[int, Arena] = {}
var combat_views: Dictionary[int, CombatView] = {}
var allies: Array[Player] = []
var deaths: int = 0
var combat_on: bool = false
## M5a (offline): a farm per map.
var farms: Dictionary[int, Farm] = {}
var farming_on: bool = false
## M5b (offline): purification and moving the altar on; where the carried altar would go down; how many tiles were
## purified and how often the altar moved (logs, tests); players whose respawn waits for the altar (logged once).
var purify_on: bool = false
var ghost: AltarGhost
var purified: int = 0
var altar_moves: int = 0
var _respawn_waiting: Dictionary[int, bool] = {}
var _gave: bool = false
var _debug_action: int = 0
## M7b (offline): a forest per map (its trees' swings, its stumps' regrowth); the selected piece's ghost.
var forests: Dictionary[int, Forest] = {}
var trees_on: bool = false
var build_ghost: BuildGhost

@onready var world: GameWorld = $World
@onready var camera: PlayerCamera = $Camera
@onready var net: NetSession = $Net


func _ready() -> void:
	if world.data == null:
		world.generate(CliOptions.current().world_seed)
	var options: CliOptions = CliOptions.current()
	if not options.errors.is_empty():
		return  # the Cli autoload reports the bad flags and quits
	hud = Hud.new()
	add_child(hud)
	marker = TargetMarker.new()
	marker.name = &"TargetMarker"
	world.add_child(marker)
	world.move_child(marker, world.entities.get_index())
	ghost = AltarGhost.new()
	world.add_child(ghost)
	world.move_child(ghost, world.entities.get_index())  # M5b: where the carried altar would go
	build_ghost = BuildGhost.new()
	world.add_child(build_ghost)
	world.move_child(build_ghost, world.entities.get_index())  # M7b: where the selected build piece would go
	world.altar_moved.connect(_on_altar_moved)
	worlds[Config.MAP_SURFACE] = world
	if options.host or options.join:
		get_window().title = "Evensong (%s, %s)" % ["host" if options.host else "client",
			options.class_id if not options.class_id.is_empty() else Config.DEFAULT_CLASS]
		net.local_player_ready.connect(_on_local_player_ready)
		net.local_map_changed.connect(_on_local_map_changed)
		net.ended.connect(_on_net_ended)
		net.bot_ui.connect(_on_bot_ui)  # M6b: a bot's tab / craft in a session
		net.chest_wanted.connect(open_chest)  # M7c: F at a chest opens its panel here
		net.bot_gear.connect(_on_bot_gear)  # M7c: a bot's chest panel / armour slot clicks
		add_dungeon(options.host)  # the host makes the dungeon; a client gets it from the host
		for id: int in worlds:
			net.worlds[id] = worlds[id]
		net.start(world, options)
		return
	add_dungeon()
	spawn(options.class_id if not options.class_id.is_empty() else Config.DEFAULT_CLASS)
	setup_combat()
	setup_farming()
	setup_forests()  # M7b
	purify_on = true  # M5b (offline; M5c: a session's is the host's)
	_apply_test_options(options)
	if not options.bot.is_empty():
		bot = NetBot.new()
		bot.parse(options.bot)
		player.local_input = false


## M3a: the dungeon's world (a second world.tscn, hidden until the local player goes down).
## `generate` false (M3b, a session client): no map yet; the session loads the host's dungeon into it.
func add_dungeon(generate: bool = true) -> void:
	if worlds.has(Config.MAP_DUNGEON):
		return
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.name = &"Dungeon"
	w.map_id = Config.MAP_DUNGEON
	w.free_camera = false
	w.auto_generate = generate
	w.visible = false
	add_child(w)
	if not generate:
		w.lighting.set_evening(not CliOptions.current().no_evening)
	move_child(w, world.get_index() + 1)
	worlds[Config.MAP_DUNGEON] = w


## The world the local player is on.
func current_world() -> GameWorld:
	var w: GameWorld = worlds.get(current_map, world)
	return w


## M3a: shows map `to` (the other one hidden first: a hidden world's darkness does not apply) and
## moves the target marker into it.
func _show_map(to: int) -> void:
	if not worlds.has(to):
		return
	for id: int in worlds:
		if id != to:
			worlds[id].visible = false
	worlds[to].visible = true
	current_map = to
	var w: GameWorld = worlds[to]
	if marker.get_parent() != w:
		marker.get_parent().remove_child(marker)
		w.add_child(marker)
	w.move_child(marker, w.entities.get_index())
	marker.map_cells = w.data.size
	if build_ghost != null:
		if build_ghost.get_parent() != w:
			build_ghost.get_parent().remove_child(build_ghost)
			w.add_child(build_ghost)
		w.move_child(build_ghost, w.entities.get_index())  # M7b: the build ghost goes with the local player's map
		build_ghost.hide_ghost()


## M3a: takes the local player to map `to` (offline): its arrival point there (the dungeon: south of
## the exit stairs; the surface: south of the entrance), facing south, its action stopped. Returns
## whether it went. M3-fix: a map with no data is refused (a session client that lost its host before
## the host ever sent it the dungeon plays on alone with an empty dungeon world).
func travel(to: int) -> bool:
	if player == null or to == current_map or not worlds.has(to) or _in_session():
		return false
	if worlds[to].data == null:
		print("EVENSONG_MAP travel refused to=%s: that map was never received" % Config.MAP_NAMES[to])
		return false
	if player.carrying_altar:
		print("EVENSONG_MAP travel refused to=%s: %s" % [Config.MAP_NAMES[to], AltarMove.WHY_CARRYING])  # M5b
		return false
	_show_map(to)
	var w: GameWorld = worlds[to]
	player.get_parent().remove_child(player)
	w.entities.add_child(player)
	player.set_world(w.data, w.arrival_point())
	_follow(player)
	marker.refresh()
	print("EVENSONG_MAP travel to=%s feet=%d,%d" % [Config.MAP_NAMES[to], roundi(player.sim_position.x),
		roundi(player.sim_position.y)])
	return true


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_check_crafting()  # M6b: in a session too
	if _in_session():
		_show_altar_ghost(player)  # M5c: where the carried altar would go down (the host decides)
		_show_purify()  # M5c: the channels under way, from the players' states
		_show_build_ghost()  # M7c: from this machine's world (the host decides)
		_redraw_chest()  # M7c: the host's chest slot edits change an open panel
		return
	if bot != null:
		_bot_tick(delta)
	step_altar_hold(player)
	step_combat(delta)
	check_carriers()  # M5-fix: after the combat, like the host (SessionHost.tick: arenas, then _check_carriers)
	step_farms()
	step_forests()  # M7b
	_show_purify()
	_show_build_ghost()  # M7b


func _bot_tick(delta: float) -> void:
	bot.foes.clear()
	if ensure_combat(current_map):
		for h: HereticSim in arenas[current_map].heretics:
			if h.alive():
				bot.foes.append(h.pos)
	bot.life = player.vitals.life
	bot.downed.clear()
	for p: Player in players_on(current_map):
		if p.vitals.life == Vitals.Life.DOWN:
			bot.downed.append(p.sim_position)
	bot.world = player.data  # M5c: waitfield
	var a: NetBot.Action = bot.step(player.sim_position)
	if a.tab:
		toggle_tab()  # M6a
	if a.craft_row >= 0:
		craft_row(a.craft_row)
	if a.store_slot >= 0:
		chest_store(a.store_slot)  # M7a
	if a.take_slot >= 0:
		chest_take(a.take_slot)
	if a.unequip:
		unequip_armor()
	if a.demolish:
		demolish()  # M7b: right-click
	if a.heretic != null and ensure_combat(current_map):
		var hc: Vector2i = a.heretic
		arenas[current_map].spawn_heretic(Arena.spawn_feet(hc))  # M7c, test only (bot "heretic")
	player.tick_controls(a.dir, a.mouse, a.aiming, a.use_pressed, a.use_held, delta, a.dash, a.interact, a.skill)
	if a.op == null:
		return
	match a.op.op:
		NetProtocol.Op.PICKUP:
			pick_up()
		NetProtocol.Op.SELECT:
			player.inventory.select(a.op.slot)
		NetProtocol.Op.DROP:
			drop_selected()
		NetProtocol.Op.GIVE:
			WorldItems.give(player.inventory, a.op.item_index, a.op.count, a.op.grade)


## (Re)creates the local player and the dummies for a local class (offline).
func spawn(local_class: String) -> void:
	var old: Array[Node2D] = []
	old.append_array(dummies)
	if player != null:
		old.append(player)
	for node: Node2D in old:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.free()
	dummies.clear()
	if current_map != Config.MAP_SURFACE:
		_show_map(Config.MAP_SURFACE)
	player = Player.new()
	player.name = &"LocalPlayer"
	player.controls = true
	player.potions_on = true  # M6a: offline only until M6b
	player.farming_on = true  # M5a (M5c: a session's local player too, _on_local_player_ready)
	player.purify_on = true  # M5b (M5c: likewise)
	player.gear_on = true  # M7a: offline only until M7c
	player.setup(world.data, local_class, world.spawn_point(0), Config.SPAWN_FACING)
	give_start_weapon(player)
	_connect_gear(player)
	player.action_started.connect(_on_action_started)
	player.action_impact.connect(_on_action_impact)
	player.place_requested.connect(_on_place_requested)
	player.potion_refused.connect(_on_potion_refused)
	player.died.connect(_on_died.bind(player))
	player.respawn_due.connect(_on_respawn_due.bind(player))
	player.hurt.connect(_on_hurt.bind(player))
	_connect_purify(player)
	world.entities.add_child(player)
	var slot: int = 1
	for class_id: String in Config.CLASSES:
		if class_id == local_class:
			continue
		var dummy: Character = Character.new()
		dummy.name = StringName("Dummy_%s" % class_id)
		dummy.class_id = class_id
		dummy.position = world.spawn_point(slot)
		dummy.direction = RigData.facing_toward(dummy.position, world.data.altar_center_px()) as RigData.Dir
		world.entities.add_child(dummy)
		dummies.append(dummy)
		slot += 1
	_follow(player)
	_bind(player)


func _follow(target: Player) -> void:
	camera.target = target
	camera.bounds = current_world().map_rect_px()
	camera.make_current()
	camera.follow()


## Points the HUD and the target marker at the local player; the first time, gives the --give items
## (offline and as the host: at once; a session client asks the host for them).
func _bind(p: Player) -> void:
	if hud == null:
		return
	p.controls = true
	hud.bind(p.inventory)
	hud.bind_player(p)
	marker.player = p
	marker.map_cells = current_world().data.size
	marker.refresh()
	if not _gave:
		_gave = true
		for entry: Array in CliOptions.current().give:
			var id: StringName = entry[0]
			var count: int = entry[1]
			var grade: int = entry[2]
			if net.role == NetSession.Role.CLIENT:
				for f: NetProtocol.InputFrame in give_requests(ItemDB.index_of(id), count, ItemDB.normalize_grade(id, grade)):
					net.queue_op(f)
			else:
				p.inventory.add(id, count, grade)


## The session's local player. Its action / place signals go to the offline handlers, which do nothing
## while in the session (the host decides) but make mining and torches work after continue_offline
## (M3-fix: before, only spawn() connected them, so a client that lost its host could not mine).
func _on_local_player_ready(p: Player) -> void:
	player = p
	p.potions_on = true  # M6b: drinking and throwing in sessions (the host decides the effect)
	p.farming_on = true  # M5c: farming, purifying and carrying the altar in sessions (the host decides the result)
	p.purify_on = true
	p.gear_on = true  # M7c: the armour click is an ARMOR request (the host puts it on, wears it, sends its durability)
	for pair: Array in [[p.action_started, _on_action_started], [p.action_impact, _on_action_impact],
			[p.place_requested, _on_place_requested], [p.potion_refused, _on_potion_refused]]:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if not sig.is_connected(handler):
			sig.connect(handler)
	_follow(p)
	_bind(p)
	_connect_gear(p)  # M7c


## M3b: the session put the local player on map `map_id`: show it, the camera and the marker with it.
func _on_local_map_changed(map_id: int) -> void:
	_show_map(map_id)
	if player == null:
		return
	_follow(player)
	marker.refresh()
	print("EVENSONG_MAP travel to=%s feet=%d,%d" % [Config.MAP_NAMES[map_id], roundi(player.sim_position.x),
		roundi(player.sim_position.y)])


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not is_instance_valid(player):
		return
	if crafting_open():
		_crafting_input(event)
		return
	if chest_open():
		_chest_input(event)  # M7a
		return
	if event.is_action_pressed(&"hotbar_prev"):
		select_hotbar(-1)
	elif event.is_action_pressed(&"hotbar_next"):
		select_hotbar(1)
	elif event.is_action_pressed(&"toggle_inventory"):
		toggle_tab()
	elif event.is_action_pressed(&"interact"):
		pick_up()
	elif event.is_action_pressed(&"debug_drop"):
		drop_selected()
	elif event.is_action_pressed(&"debug_give"):
		give_debug_kit()
	elif event.is_action_pressed(&"debug_action"):
		debug_next_action()
	elif event.is_action_pressed(&"demolish"):
		demolish()  # M7b: right-click takes a built piece down


func _in_session() -> bool:
	return net.role != NetSession.Role.OFFLINE


## A request frame (op and fields only) for NetSession.queue_op.
static func request(op: int, slot: int = 0, count: int = 0) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
	f.op = op
	f.slot = slot
	f.count = count
	return f


static func give_request(item_index: int, count: int, grade: int) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = request(NetProtocol.Op.GIVE, 0, count)
	f.item_index = item_index
	f.grade = maxi(grade, 0)
	return f


## A give of `count` as requests of at most WorldItems.GIVE_COUNT_MAX each (the wire count is one
## byte: --give=stone_a:300 on a client is 255 + 45, as offline and on the host).
static func give_requests(item_index: int, count: int, grade: int) -> Array[NetProtocol.InputFrame]:
	var out: Array[NetProtocol.InputFrame] = []
	var left: int = count
	while left > 0:
		var n: int = mini(left, WorldItems.GIVE_COUNT_MAX)
		out.append(give_request(item_index, n, grade))
		left -= n
	return out


## Q / E: the hotbar slot left / right (wrapping).
func select_hotbar(step: int) -> void:
	var slot: int = posmod(player.inventory.selected + step, player.inventory.hotbar_size)
	if _in_session():
		net.queue_op(request(NetProtocol.Op.SELECT, slot))
	else:
		player.inventory.select(slot)


## F: pick up what lies on the target tile (offline: at once; in a session: a request). M4a: not while
## down or dead (F held then gives up, Vitals).
func pick_up() -> void:
	if not player.vitals.alive():
		return
	if _in_session():
		net.queue_op(request(NetProtocol.Op.PICKUP))
		return
	var cell: Vector2i = Aim.target_cell(player.sim_position, player.aim_sector)
	var data: WorldData = current_world().data
	var to: int = WorldItems.travel(data, player.sim_position, cell)
	if to >= 0:
		travel(to)  # refused (and logged) for a map never received; F on a way is never a pick up
		return
	var chest_rect: Rect2i = Storage.chest_for(data, player.sim_position, cell)
	if chest_rect.has_area():
		open_chest(chest_rect)  # M7a: F at a storage chest opens it (nothing lies on a chest tile to pick up)
		return
	if Building.door_cell(data, cell) != Walls.NO_CELL:
		toggle_door(cell)  # M7b: F on a door (or its face) opens or closes it
		return
	var o: WorldItems.Outcome = WorldItems.pickup(data, player.sim_position, player.class_id(), player.inventory, cell)
	if not o.ok() and o.why == WorldItems.WHY_NOTHING and purify_on and not player.carrying_altar \
			and not AltarMove.is_altar_cell(data, cell) \
			and Purify.channel_refusal(data, player.class_id(), player.sim_position).is_empty():
		# M5b: F with nothing to pick up, on or next to corruption: the paladin's channel. M5-fix: not F aimed at the altar
		# (that F is the altar's: holding it lifts the altar, PROVISIONAL README "M5b 키").
		player.request_channel()
		return
	_apply_offline(o, "pickup", cell)
	if o.ok() and o.gathered and farming_on:
		seed_from_wild(player.inventory, o.item)


## M5a (offline): a wild herb picked where it grew gives Config.SEEDS_PER_WILD_HERB seeds of its crop (PROVISIONAL: the
## one way to seeds before the merchant, M8; the harvest gives seeds back). What does not fit is not given. Returns how
## many went in.
static func seed_from_wild(inv: Inventory, herb: StringName) -> int:
	var kind: int = Farming.herb_kind(herb)
	if kind == Farming.KIND_NONE or Config.SEEDS_PER_WILD_HERB <= 0:
		return 0
	var n: int = Farming.seeds_from_wild(inv, herb)  # M5c: the host's rule too
	print("EVENSONG_FARM seed from=%s item=%s count=%d%s" % [herb, Farming.SEEDS[kind], n,
		"" if n == Config.SEEDS_PER_WILD_HERB else " (inventory full)"])
	return n


## F7 (debug): drop the selected stack on the target tile (M4a: not while down or dead).
func drop_selected() -> void:
	if not player.vitals.alive():
		return
	if _in_session():
		net.queue_op(request(NetProtocol.Op.DROP, -1, 0))
		return
	var cell: Vector2i = Aim.target_cell(player.sim_position, player.aim_sector)
	_apply_offline(WorldItems.drop(current_world().data, player.sim_position, player.inventory,
		player.inventory.selected, 0, cell), "drop", cell)


## Offline: a request's world edits go straight into the world.
func _apply_offline(o: WorldItems.Outcome, what: String, cell: Vector2i) -> void:
	if not o.ok():
		print("EVENSONG_ITEMS %s refused at=%d,%d: %s" % [what, cell.x, cell.y, o.why])
		return
	for e: EditLog.WorldEdit in o.edits:
		current_world().apply_edit(e)
	print("EVENSONG_ITEMS %s item=%s count=%d grade=%s at=%d,%d" % [what, o.item, o.count,
		ItemDB.GRADE_NAMES[clampi(o.grade, 0, 2)], cell.x, cell.y])


## F5: every item of ItemDB.debug_kit() into the local player's inventory (what does not fit is lost).
## In a session a request (the host honours a client's only in debug builds or with --test-allow-give).
func give_debug_kit() -> void:
	if _in_session():
		net.queue_op(give_request(WorldItems.GIVE_KIT, 0, 0))
		return
	for entry: Array in ItemDB.debug_kit():
		var id: StringName = entry[0]
		var count: int = entry[1]
		var grade: int = entry[2] if entry.size() > 2 else -1
		player.inventory.add(id, count, grade)
	print("EVENSONG_ITEMS debug kit given: %s" % player.inventory.describe())


## F6: the next of the eight body actions toward the current aim, whatever is selected (offline).
func debug_next_action() -> void:
	if _in_session() or not player.controls or player.action_anim >= 0:
		return
	player.start_action(RigData.ACTION_ANIMS[_debug_action % RigData.ACTION_ANIMS.size()], &"debug")
	_debug_action += 1


## M3a, offline: a pickaxe swing lands (Config.MINING_IMPACT_FRAME): mine the target (items/mining.gd).
## M4a: a weapon's hit frame attacks (Arena.player_attack); the pickaxe mines only when it is aimed at a
## wall or a wall's face (Combat.is_mining_swing), and attacks otherwise.
func _on_action_impact(item: StringName, anim: int, target: Vector2i) -> void:
	if _in_session() or player == null:
		return
	if Potions.is_potion(item):
		potion_impact(player, item, anim)  # M6a
		return
	if purify_on and Purify.is_holy_water(item):
		holy_water_impact(player, target)  # M5b
		return
	var w: GameWorld = current_world()
	if farming_on and (item == Farming.HOE or item == Farming.WATERING_CAN or Farming.is_harvest_swing(w.data, item, target)):
		farm_impact(player, item, target)  # M5a: the sickle aimed at a crop harvests instead of attacking
		return
	if Gear.base(item) == Forest.AXE:
		chop_impact(player, item, target)  # M7b: the axe chops the tree it is aimed at
		return
	if Combat.attack_for(item) != null and not Combat.is_mining_swing(w.data, item, target):
		_attack(player, item)
		return
	if Gear.base(item) != Mining.PICKAXE:
		return  # M7a: the tier-1 pickaxe mines as the pickaxe (no wear: mining power and cost unchanged)
	var r: Mining.Result = Mining.strike(w.data, player.sim_position, player.class_id(), player.inventory, target)
	if r.why == Mining.WHY_NO_WALL:
		return  # a swing at open ground (the surface): nothing to report, as in M2
	for e: EditLog.WorldEdit in r.edits:
		w.apply_edit(e)
	print("EVENSONG_MINE at=%d,%d class=%s %s" % [target.x, target.y, player.class_id(),
		r.describe() if r.ok() else "refused: " + r.why])


# --- M4a: combat (offline) ----------------------------------------------------------------------

## The class weapon (Config.CLASS_WEAPONS) into hotbar slot Config.START_WEAPON_SLOT (offline only).
static func give_start_weapon(p: Player) -> void:
	var weapon: StringName = Combat.class_weapon(p.class_id())
	if weapon.is_empty() or not p.inventory.is_empty_slot(Config.START_WEAPON_SLOT):
		return
	if p.inventory.add(weapon, 1) == 0:
		for slot: int in p.inventory.size():
			var s: ItemStack = p.inventory.stack_at(slot)
			if s != null and s.id == weapon and slot != Config.START_WEAPON_SLOT:
				p.inventory.move(slot, Config.START_WEAPON_SLOT)
				break


## An arena and a view for every map (offline only: a session, and a client that lost its host and
## plays on alone, have none yet, M4b). Spawns are repeatable from the world seed.
func setup_combat() -> void:
	combat_on = true
	for id: int in worlds:
		ensure_combat(id)


## Map `id`'s arena and view, (re)made when missing or when its world got other data (tests swap worlds).
func ensure_combat(id: int) -> bool:
	var w: GameWorld = _live_world(id)
	if not combat_on or w == null or w.data == null:
		return false
	var raw: Variant = combat_views.get(id, null)
	var v: CombatView = null
	if raw != null and is_instance_valid(raw):
		v = raw
	if arenas.has(id) and arenas[id].data == w.data and v != null and v.get_parent() == w:
		return true
	if v != null:
		v.clear()
		v.get_parent().remove_child(v)
		v.free()
	var a: Arena = Arena.new()
	a.setup(w.data, CliOptions.current().world_seed)
	a.spawning = not CliOptions.current().test_no_spawns
	arenas[id] = a
	v = CombatView.new()
	v.name = &"Combat"
	w.add_child(v)
	v.setup(a, w.entities)
	combat_views[id] = v
	return true


## World `id` unless it is missing or freed (tests swap worlds).
func _live_world(id: int) -> GameWorld:
	var raw: Variant = worlds.get(id, null)
	if raw == null or not is_instance_valid(raw):
		return null
	var w: GameWorld = raw
	return w


## The players on map `map_id` in a fixed order (the local one first, then the allies).
func players_on(map_id: int) -> Array[Player]:
	var out: Array[Player] = []
	var w: GameWorld = _live_world(map_id)
	if w == null:
		return out
	if _in_session():
		# M5c: the session's players on that map as this machine has them (a client: the others drawn there).
		for slot: int in net.slots():
			var m: NetMember = net.members[slot]
			if m.map_id == map_id and m.player != null and is_instance_valid(m.player) and (m == net.local or m.player.visible):
				out.append(m.player)
		return out
	if player != null and is_instance_valid(player) and player.data == w.data:
		out.append(player)
	for a: Player in allies:
		if is_instance_valid(a) and a.data == w.data:
			out.append(a)
	return out


## One combat tick on the local player's map (after the local player stepped): the allies' own tick (no
## input: their down / respawn timers), then the arena; its edits go into the world, the view follows.
## The other maps' arenas wait (M4-fix: emptied once when the local player leaves them).
func step_combat(delta: float) -> void:
	if not ensure_combat(current_map):
		return
	for a: Player in allies:
		if is_instance_valid(a) and a.data == current_world().data:
			a.begin_tick()
			a.step_frame(NetProtocol.InputFrame.new(), delta)
	var players: Array[Player] = players_on(current_map)
	var w: GameWorld = current_world()
	var splashed: int = arenas[current_map].stat("splashes")
	for e: EditLog.WorldEdit in arenas[current_map].step(players):
		w.apply_edit(e)
		_log_edit(e)
	if arenas[current_map].stat("splashes") > splashed and not arenas[current_map].splashes.is_empty():
		var s: Arena.Splash = arenas[current_map].splashes.back()
		print("EVENSONG_POTION splash item=%s at=%d,%d players=%d heretics=%d" % [s.item, roundi(s.pos.x), roundi(s.pos.y),
			s.players, s.heretics])
	combat_views[current_map].sync(players)
	# M4-fix: the map just left is emptied once (Arena.on_emptied: an attack under way stops without its
	# knife, shots in the air are gone, the spawn timer starts over), so a heretic frozen mid-swing does not
	# finish it on the player's return.
	for id: int in arenas:
		if id != current_map and arenas[id].occupied:
			arenas[id].idle_tick()
			var raw: Variant = combat_views.get(id, null)
			if raw != null and is_instance_valid(raw):
				var v: CombatView = raw
				v.sync([] as Array[Player])


func _attack(p: Player, item: StringName) -> void:
	if not ensure_combat(current_map):
		return
	var a: Arena = arenas[current_map]
	var before: int = a.stats.get("heretic_hits", 0) + a.stats.get("shrine_hits", 0)
	# M7a: the stack that plays it (its tier-1 damage while not broken), then its use wear (M7c: the host's rule too).
	var stack: ItemStack = Gear.playing_stack(p.inventory, p.action_slot, item)
	var damage: int = Gear.attack_damage(stack, Combat.attack_for(item).damage) if p.gear_on else -1
	var edits: Array[EditLog.WorldEdit] = a.player_attack(p, item, p.action_aim, players_on(current_map), 255, damage)
	if p.gear_on and stack != null and stack.max_durability() > 0:
		var was_broken: bool = stack.broken()
		Gear.wear_weapon(p.inventory, p.action_slot, item)
		if stack.broken() and not was_broken:
			print("EVENSONG_GEAR broke item=%s who=%s" % [item, p.name])
	for e: EditLog.WorldEdit in edits:
		current_world().apply_edit(e)
		_log_edit(e)
	var after: int = a.stats.get("heretic_hits", 0) + a.stats.get("shrine_hits", 0)
	if after > before:
		print("EVENSONG_COMBAT hit item=%s class=%s hits=%d shrine_hp=%d" % [item, p.class_id(), after - before, a.shrine_hp])


func _log_edit(e: EditLog.WorldEdit) -> void:
	if e.kind == EditLog.Kind.CELL and e.layer == WorldData.Layer.PLACEABLE and e.value == WorldData.PLACEABLE_SHRINE_BROKEN:
		print("EVENSONG_COMBAT shrine broken at=%d,%d" % [e.cell.x, e.cell.y])


func _on_hurt(amount: int, downed: bool, p: Player) -> void:
	print("EVENSONG_COMBAT hurt who=%s amount=%d hp=%d%s" % [p.name, amount, p.vitals.hp, " DOWN" if downed else ""])
	# M5b: a carrier that went down sets the altar down nearby. M5-fix: not here in the middle of the arena's step (its
	# heretics half moved) but once the tick's combat is over (check_carriers), in the host's order.


## M4a: player `p` died (down time over, or gave up): part of its materials and consumables fall in a
## bag on its tile (● gameplay-design §2.6, WorldItems.death_drop).
func _on_died(p: Player) -> void:
	var w: GameWorld = _world_of(p)
	if w == null:
		return
	deaths += 1
	var o: WorldItems.Outcome = WorldItems.death_drop(w.data, p.sim_position, p.inventory, Config.DEATH_DROP_RULE,
		hash([CliOptions.current().world_seed, deaths]))
	for e: EditLog.WorldEdit in o.edits:
		w.apply_edit(e)
	print("EVENSONG_DEATH died who=%s map=%s bag=%s items=%d" % [p.name, Config.MAP_NAMES[w.map_id],
		"none (%s)" % o.why if not o.ok() else "%d,%d" % [o.edits[0].cell.x, o.edits[0].cell.y], o.count])
	if p.gear_on:
		var worn: int = Gear.wear_on_death(p.inventory)  # M7a: ● §2.6 the gear stays and wears
		if worn > 0:
			print("EVENSONG_GEAR death wear who=%s items=%d" % [p.name, worn])


## M4a: player `p`'s respawn time is up: back at its altar spawn slot on the surface (● §2.6 "부활 지점:
## 제단"), facing Config.SPAWN_FACING, full (Config.RESPAWN_HP).
func _on_respawn_due(p: Player) -> void:
	var slot: int = 0 if p == player else 1 + allies.find(p)
	if not world.data.altar_rect.has_area():
		# M5b (PROVISIONAL README "M5b 들고 있는 동안"): the altar is carried, so there is no altar to respawn at; the dead
		# wait (the respawn is due again every frame, PlayerSim.step) until it is down again.
		if not _respawn_waiting.has(p.get_instance_id()):
			_respawn_waiting[p.get_instance_id()] = true
			print("EVENSONG_DEATH respawn waits who=%s: no altar (carried)" % p.name)
		return
	_respawn_waiting.erase(p.get_instance_id())
	if p == player and current_map != Config.MAP_SURFACE:
		_show_map(Config.MAP_SURFACE)
	if p.get_parent() != world.entities:
		p.get_parent().remove_child(p)
		world.entities.add_child(p)
	p.respawn_at(world.data, world.spawn_point(slot))  # M4b: the rule the host and a prediction share
	if p == player:
		_follow(p)
		marker.refresh()
	print("EVENSONG_DEATH respawn who=%s feet=%d,%d" % [p.name, roundi(p.sim_position.x), roundi(p.sim_position.y)])


func _world_of(p: Player) -> GameWorld:
	for id: int in worlds:
		if worlds[id].data == p.data:
			return worlds[id]
	return null


## M4b: after continue_offline the local player fights offline: its death, bag and respawn are Main's
## again and every map gets an offline arena (the host's heretics went with the host).
func _go_offline_combat() -> void:
	for pair: Array in [[player.died, _on_died.bind(player)], [player.respawn_due, _on_respawn_due.bind(player)],
			[player.hurt, _on_hurt.bind(player)]]:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		sig.connect(handler)
	# M6a: offline now, so potions work (and the throw's skill key).
	player.potions_on = true
	if not player.potion_refused.is_connected(_on_potion_refused):
		player.potion_refused.connect(_on_potion_refused)
	# M5-fix: the host went while someone else carried the altar (the host itself, or another client): this world has no
	# altar and nobody here to put it down. It comes back where it last stood (GameWorld.last_altar_rect), or the nearest
	# allowed place around it (PROVISIONAL README "M5c 호스트를 잃었을 때 제단"), before the offline arena takes its light.
	if not world.data.altar_rect.has_area() and not player.carrying_altar:
		restore_altar(world, bodies_on(Config.MAP_SURFACE))
	setup_combat()
	# M5a: and farming (the fields the host's world had, with fresh timers: Farm.setup).
	player.farming_on = true
	setup_farming()
	# M5b: and purification, moving the altar.
	player.purify_on = true
	purify_on = true
	_connect_purify(player)
	# M7a: and gear (M7c: its wear goes on from the durability the host's last inventory carried).
	player.gear_on = true
	_connect_gear(player)
	# M7b: and the trees' regrowth (building and chopping are offline Main's from now on).
	setup_forests()


## --test-ally: a player of `class_id` beside the local one (no input; `down` = it starts downed).
func add_ally(class_id: String, down: bool) -> Player:
	var a: Player = Player.new()
	a.name = StringName("Ally_%s" % class_id)
	a.local_input = false
	var w: GameWorld = current_world()
	a.setup(w.data, class_id, player.sim_position + Vector2(18, 0), RigData.Dir.WEST)
	a.died.connect(_on_died.bind(a))
	a.respawn_due.connect(_on_respawn_due.bind(a))
	a.hurt.connect(_on_hurt.bind(a))
	w.entities.add_child(a)
	allies.append(a)
	if down:
		a.take_hit(Config.PLAYER_HP_MAX)
	return a


## M3a, offline: a click with a torch selected puts it on the target tile. M6a: the same for the alchemy table
## (its footprint may not cover anyone: the other players and the heretics on the map are passed along). M5a: seeds
## are planted (Farm.plant).
func _on_place_requested(slot: int, cell: Vector2i) -> void:
	if _in_session() or player == null:
		return
	if not Building.piece_in(player.inventory, slot).is_empty():
		build(slot, cell)  # M7b
		return
	if farming_on and Farming.seed_kind_in(player.inventory, slot) != Farming.KIND_NONE:
		if ensure_farm(current_map):
			_apply_farm(farms[current_map], farms[current_map].plant(player.sim_position, player.class_id(), player.inventory,
				slot, cell), "plant", cell, player)
		return
	var bodies: Array[Vector2] = []
	for p: Player in players_on(current_map):
		if p != player:
			bodies.append(p.sim_position)
	if arenas.has(current_map):
		for h: HereticSim in arenas[current_map].heretics:
			bodies.append(h.pos)
	_apply_offline(WorldItems.place(current_world().data, player.sim_position, player.inventory, slot, cell, bodies),
		"place", cell)


# --- M7b: building, doors, trees (offline) ---------------------------------------------------------------

## The other bodies on the local player's map: the other players' feet and the heretics' (what a blocking piece may not
## cover).
func _other_bodies() -> Array[Vector2]:
	var bodies: Array[Vector2] = []
	for p: Player in players_on(current_map):
		if p != player:
			bodies.append(p.sim_position)
	if _in_session():
		bodies.append_array(net.bots.foe_positions())  # M7c: the heretics as this machine has them (the build ghost)
	elif arenas.has(current_map):
		for h: HereticSim in arenas[current_map].heretics:
			if h.alive():
				bodies.append(h.pos)
	return bodies


## M7c: the other players' feet on the local player's map (the clearance of Building.clear_of_others; offline the allies).
func _other_players() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Player in players_on(current_map):
		if p != player:
			out.append(p.sim_position)
	return out


## A click with the piece in hotbar slot `slot` on tile `cell` (Building.build; offline).
func build(slot: int, cell: Vector2i) -> void:
	var w: GameWorld = current_world()
	var o: WorldItems.Outcome = Building.build(w.data, player.sim_position, player.inventory, slot, cell, _other_bodies(),
		[] as Array[Vector2], _other_players())
	if not o.ok():
		print("EVENSONG_BUILD place refused at=%d,%d: %s" % [cell.x, cell.y, o.why])
		return
	for e: EditLog.WorldEdit in o.edits:
		w.apply_edit(e)
	print("EVENSONG_BUILD place piece=%s cost=%d at=%d,%d map=%s" % [o.item, o.count, cell.x, cell.y, Config.MAP_NAMES[w.map_id]])


## Right-click: take the built piece on the target tile down (Building.demolish; offline. M7c: in a session a DEMOLISH request
## aimed at the target tile when its frame is built, SessionHost.attach_local_op).
func demolish() -> void:
	if player == null or not player.vitals.alive() or player.carrying_altar or player.ui_locked:
		return
	var cell: Vector2i = Aim.target_cell(player.sim_position, player.aim_sector)
	if _in_session():
		net.queue_op(request(NetProtocol.Op.DEMOLISH))
		return
	var w: GameWorld = current_world()
	var o: WorldItems.Outcome = Building.demolish(w.data, player.sim_position, player.inventory, cell)
	if not o.ok():
		print("EVENSONG_BUILD demolish refused at=%d,%d: %s" % [cell.x, cell.y, o.why])
		return
	for e: EditLog.WorldEdit in o.edits:
		w.apply_edit(e)
	print("EVENSONG_BUILD demolish piece=%s refund=%d at=%d,%d" % [o.item, o.count, cell.x, cell.y])


## F on a door (or its face) on tile `cell`: open or close it (Building.toggle_door; offline).
func toggle_door(cell: Vector2i) -> void:
	var w: GameWorld = current_world()
	var o: WorldItems.Outcome = Building.toggle_door(w.data, player.sim_position, cell, _other_bodies(), _other_players())
	if not o.ok():
		print("EVENSONG_BUILD door refused at=%d,%d: %s" % [cell.x, cell.y, o.why])
		return
	for e: EditLog.WorldEdit in o.edits:
		w.apply_edit(e)
	print("EVENSONG_BUILD door %s at=%d,%d" % [o.item, o.edits[0].cell.x, o.edits[0].cell.y])


## A forest for every map (offline only, like the farms).
func setup_forests() -> void:
	trees_on = true
	for id: int in worlds:
		ensure_forest(id)


## Map `id`'s forest, (re)made when missing or when its world got other data (tests swap worlds).
func ensure_forest(id: int) -> bool:
	var w: GameWorld = _live_world(id)
	if not trees_on or w == null or w.data == null:
		return false
	if not forests.has(id) or forests[id].data != w.data:
		forests[id] = Forest.new(w.data)
	return true


## One forest tick on every map (stumps grow back), in map order.
func step_forests() -> void:
	if not trees_on:
		return
	var ids: Array[int] = []
	ids.assign(worlds.keys())
	ids.sort()
	for id: int in ids:
		if not ensure_forest(id):
			continue
		var w: GameWorld = worlds[id]
		for e: EditLog.WorldEdit in forests[id].step():
			w.apply_edit(e)
			print("EVENSONG_TREE regrown at=%d,%d map=%s" % [e.cell.x, e.cell.y, Config.MAP_NAMES[id]])


## The axe's landing frame for player `p` aimed at tile `target` (Forest.chop; offline).
func chop_impact(p: Player, item: StringName, target: Vector2i) -> void:
	if not ensure_forest(current_map):
		return
	var w: GameWorld = current_world()
	var r: Forest.Result = forests[current_map].chop(p.sim_position, p.inventory, item, target)
	if not r.ok():
		if r.why != Forest.WHY_NO_TREE:
			print("EVENSONG_TREE chop refused at=%d,%d: %s" % [target.x, target.y, r.why])
		return
	for e: EditLog.WorldEdit in r.edits:
		w.apply_edit(e)
	if r.felled:
		print("EVENSONG_TREE felled at=%d,%d who=%s %s" % [target.x, target.y, p.name, r.describe()])
	else:
		w.fixtures.shake(target)
		print("EVENSONG_TREE chop at=%d,%d hits=%d/%d" % [target.x, target.y, r.hits, Config.TREE_CHOP_HITS])


## The build ghost (offline): the selected piece on the target tile while the local player aims, gold where it may go.
## The answer is worked out again when the tile, the piece, the world or the pieces held change, and every
## GHOST_RECHECK_TICKS (bodies move).
const GHOST_RECHECK_TICKS: int = 10
var _ghost_ticks: int = 0


func _show_build_ghost() -> void:
	if build_ghost == null:
		return
	_ghost_ticks += 1
	var st: ItemStack = player.inventory.selected_stack()
	var piece: StringName = st.id if st != null and Building.is_piece(st.id) else &""
	if piece.is_empty() or not player.aim_active or not player.vitals.alive() or player.carrying_altar \
			or player.ui_locked or player.action_anim >= 0:
		build_ghost.hide_ghost()
		return
	var w: GameWorld = current_world()
	var cell: Vector2i = player.aim_cell
	var key: Array = [cell, piece, w.revision, st.count, player.inventory.count_of(piece), _ghost_ticks / GHOST_RECHECK_TICKS,
		Aim.feet_cell(player.sim_position)]
	if build_ghost.visible and build_ghost.key == key:
		return
	build_ghost.key = key
	var why: String = Building.refusal(w.data, player.sim_position, piece, cell, player.inventory.count_of(piece),
		_other_bodies(), [] as Array[Vector2], _other_players())
	build_ghost.show_at(piece, cell, why.is_empty())


# --- M6a: crafting and potions (offline) ----------------------------------------------------------------

func crafting_open() -> bool:
	return hud != null and hud.crafting.is_open()


## Tab: closes the crafting panel when it is open; next to a station (Crafting.station_near; M6b: in a session
## too, on the map the local player has) opens it, else shows / hides the inventory as before (M2a). M7a: closes the
## chest panel; away from every station, offline, opens the hand recipes once one is unlocked (else the inventory).
func toggle_tab() -> void:
	if crafting_open():
		close_crafting()
		return
	if chest_open():
		close_chest()
		return
	if player.vitals.alive():
		var at: Crafting.StationAt = Crafting.station_near(current_world().data, player.sim_position)
		if at != null:
			open_crafting(at)
			return
		if not hud.open and not Crafting.shown_recipes(Crafting.HAND, player.inventory).is_empty():
			open_crafting(Crafting.hand_station(current_map))
			return
	hud.toggle_open()


func open_crafting(at: Crafting.StationAt) -> void:
	hud.crafting.open_for(at, player.inventory, player.class_id())
	if not hud.crafting.craft_requested.is_connected(craft_row):
		hud.crafting.craft_requested.connect(craft_row)
	hud.set_open(true)
	player.ui_locked = true
	print("EVENSONG_CRAFT open station=%s at=%d,%d recipes=%d" % [at.kind, at.rect.position.x, at.rect.position.y,
		hud.crafting.recipes.size()])


func close_crafting() -> void:
	hud.crafting.close()
	hud.set_open(false)
	if player != null and is_instance_valid(player):
		player.ui_locked = false


## Closes the panel when the player is no longer at its station (down, another map, the table gone). M7a: the chest
## panel likewise (Storage.still_at).
func _check_crafting() -> void:
	if chest_open() and (not player.vitals.alive() or hud.chest.map != current_map
			or not Storage.still_at(current_world().data, player.sim_position, hud.chest.rect)):
		close_chest()
		print("EVENSONG_CHEST closed: not at the chest")
	if not crafting_open():
		return
	if not player.vitals.alive() or not Crafting.still_at(current_world().data, player.sim_position, hud.crafting.station):
		close_crafting()
		print("EVENSONG_CRAFT closed: not at the station")


## Crafts row `i` of the open panel (Crafting.craft: all or nothing). M6b: in a session a CRAFT request to the
## host (it checks the station, the recipe, the inputs and the room; the inventory it sends back shows it).
func craft_row(i: int) -> void:
	if not crafting_open() or i < 0 or i >= hud.crafting.recipes.size():
		return
	var r: Crafting.Recipe = hud.crafting.recipes[i]
	hud.crafting.selected = i
	if _in_session():
		net.queue_op(craft_request(Crafting.index_of(r.id)))
		print("EVENSONG_CRAFT request recipe=%s" % r.id)
		return
	var o: Crafting.Outcome = Crafting.craft(r, player.class_id(), player.inventory)
	if o.ok():
		print("EVENSONG_CRAFT made recipe=%s item=%s count=%d grade=%s" % [r.id, o.item, o.count, ItemDB.GRADE_NAMES[o.grade]])
	else:
		print("EVENSONG_CRAFT refused recipe=%s: %s" % [r.id, o.why])
	hud.crafting.refresh()


## M6b: a CRAFT request (the map is set when it is put on a frame, SessionHost.attach_local_op).
static func craft_request(recipe_index: int) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = request(NetProtocol.Op.CRAFT)
	f.recipe = recipe_index
	return f


## M6b: a bot's Tab / craft row in a session (NetSession.bot_ui, before the frame is built).
func _on_bot_ui(tab: bool, row: int) -> void:
	if player == null or not is_instance_valid(player):
		return
	if tab:
		toggle_tab()
	if row >= 0:
		craft_row(row)


func _crafting_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"move_up"):
		hud.crafting.move_selection(-1)
	elif event.is_action_pressed(&"move_down"):
		hud.crafting.move_selection(1)
	elif event.is_action_pressed(&"interact") or _is_enter(event):
		craft_row(hud.crafting.selected)
	elif event.is_action_pressed(&"toggle_inventory") or event.is_action_pressed(&"ui_cancel"):
		close_crafting()
	elif event.is_action_pressed(&"hotbar_prev"):
		select_hotbar(-1)
	elif event.is_action_pressed(&"hotbar_next"):
		select_hotbar(1)


static func _is_enter(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var k: InputEventKey = event as InputEventKey
	return k.pressed and not k.echo and (k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER)


# --- M7a: gear and the storage chest (offline) -----------------------------------------------------------

func _connect_gear(p: Player) -> void:
	for pair: Array in [[p.equip_requested, equip_armor], [p.gear_refused, _on_gear_refused]]:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if not sig.is_connected(handler):
			sig.connect(handler)
	if hud != null and not hud.armor_clicked.is_connected(unequip_armor):
		hud.armor_clicked.connect(unequip_armor)
	if hud != null and not hud.chest.store_requested.is_connected(chest_store):
		hud.chest.store_requested.connect(chest_store)
		hud.chest.take_requested.connect(chest_take)


## A click with armour selected in hotbar slot `slot`: put it on (Gear.equip; the piece worn before goes to that slot).
## M7c: in a session an ARMOR request (the host puts it on; its inventory comes back).
func equip_armor(slot: int) -> void:
	if player == null or not player.gear_on:
		return
	if _in_session():
		net.queue_op(request(NetProtocol.Op.ARMOR, slot))
		print("EVENSONG_GEAR equip request slot=%d" % slot)
		return
	var why: String = Gear.equip(player.inventory, slot)
	if why.is_empty():
		print("EVENSONG_GEAR equip item=%s durability=%d/%d" % [player.inventory.armor.id, player.inventory.armor.durability,
			player.inventory.armor.max_durability()])
	else:
		print("EVENSONG_GEAR equip refused: %s" % why)


## A click on the armour slot of the open inventory: take the worn armour off (Gear.unequip).
func unequip_armor() -> void:
	if player == null or not player.gear_on:
		return
	if _in_session():
		net.queue_op(request(NetProtocol.Op.ARMOR, NetProtocol.ARMOR_OFF))  # M7c
		print("EVENSONG_GEAR unequip request")
		return
	var why: String = Gear.unequip(player.inventory)
	print("EVENSONG_GEAR unequip %s" % ("done" if why.is_empty() else "refused: " + why))


func _on_gear_refused(what: String, why: String) -> void:
	print("EVENSONG_GEAR %s refused: %s" % [what, why])


func chest_open() -> bool:
	return hud != null and hud.chest.is_open()


## F at the storage chest on footprint `rect`: its panel with the inventory, the player stands while it is open. M7c: in a
## session on this machine's world (NetSession.chest_wanted), whose chest slots follow the host's edits.
func open_chest(rect: Rect2i) -> void:
	if crafting_open() or chest_open() or player == null or not player.vitals.alive():
		return
	var chest: WorldData.Chest = current_world().data.chest_at(rect.position)
	if chest == null:
		return
	hud.chest.open_for(chest, rect, current_map, player.inventory)
	hud.set_open(true)
	player.ui_locked = true
	print("EVENSONG_CHEST open at=%d,%d items=%s" % [rect.position.x, rect.position.y, chest.describe()])


func close_chest() -> void:
	hud.chest.close()
	hud.set_open(false)
	if player != null and is_instance_valid(player):
		player.ui_locked = false


## A click on inventory slot `slot` while the chest is open: store that stack (as much as fits). M7c: in a session a CHEST
## request (the host moves it; its chest slot edits and the inventory come back).
func chest_store(slot: int) -> void:
	if not chest_open():
		return
	if _in_session():
		_chest_request(false, slot)
		return
	var m: Storage.Moved = Storage.store(hud.chest.chest, player.inventory, slot)
	_log_chest("store", m)


## A click on chest slot `slot` while it is open: take that stack (as much as fits). M7c: a CHEST request in a session.
func chest_take(slot: int) -> void:
	if not chest_open():
		return
	if _in_session():
		_chest_request(true, slot)
		return
	var m: Storage.Moved = Storage.take(hud.chest.chest, player.inventory, slot)
	_log_chest("take", m)


## M7c: a CHEST request for the open chest (its footprint's top-left tile): take chest slot `slot` or store inventory slot
## `slot`.
func _chest_request(take_it: bool, slot: int) -> void:
	var f: NetProtocol.InputFrame = request(NetProtocol.Op.CHEST, slot)
	f.cell = hud.chest.rect.position
	f.chest_take = take_it
	net.queue_op(f)
	print("EVENSONG_CHEST %s request slot=%d at=%d,%d" % ["take" if take_it else "store", slot, f.cell.x, f.cell.y])


## M7c: an open chest panel draws again when the host's chest slot edits changed this machine's world.
var _chest_edits_seen: int = -1


func _redraw_chest() -> void:
	if not chest_open():
		return
	var w: GameWorld = current_world()
	if w != null and w.chest_edits != _chest_edits_seen:
		_chest_edits_seen = w.chest_edits
		hud.chest.queue_redraw()


## M7c: a bot's chest panel click (store / take, -1 = none) or armour slot click in a session (NetSession.bot_gear).
func _on_bot_gear(store_slot: int, take_slot: int, unequip: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	if store_slot >= 0:
		chest_store(store_slot)
	if take_slot >= 0:
		chest_take(take_slot)
	if unequip:
		unequip_armor()


func _log_chest(what: String, m: Storage.Moved) -> void:
	hud.chest.queue_redraw()
	if m.ok():
		print("EVENSONG_CHEST %s item=%s count=%d left=%d" % [what, m.item, m.count, m.left])
	else:
		print("EVENSONG_CHEST %s refused: %s" % [what, m.why])


func _chest_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_inventory") or event.is_action_pressed(&"ui_cancel") \
			or event.is_action_pressed(&"interact"):
		close_chest()
	elif event.is_action_pressed(&"hotbar_prev"):
		select_hotbar(-1)
	elif event.is_action_pressed(&"hotbar_next"):
		select_hotbar(1)


## A potion's effect frame (drink) or release frame (throw) for player `p` (Player.action_slot / action_grade
## / action_target): the drink takes one potion and works on `p` (Potions.apply; refused again here at full HP
## and then nothing is used); the throw takes one and lets the bottle go into the map's arena.
func potion_impact(p: Player, item: StringName, anim: int) -> void:
	var arena: Arena = arenas[current_map] if ensure_combat(current_map) else null
	var r: Potions.Released = Potions.release(p, item, anim, arena)  # M6b: the host's rule too
	var what: String = "throw" if r.thrown else "drink"
	if not r.ok():
		print("EVENSONG_POTION %s refused item=%s: %s" % [what, item, r.why])
		return
	if r.thrown:
		print("EVENSONG_POTION throw item=%s grade=%s from=%d,%d to=%d,%d" % [item, ItemDB.GRADE_NAMES[r.grade],
			roundi(r.flask.origin.x), roundi(r.flask.origin.y), roundi(r.flask.target.x), roundi(r.flask.target.y)])
		return
	print("EVENSONG_POTION drink item=%s grade=%s hp=%d buff=%d poison=%d%s" % [item, ItemDB.GRADE_NAMES[r.grade],
		p.vitals.hp, p.vitals.buff_ticks, p.vitals.poison_ticks, "" if r.events != 0 else " (no effect)"])


func _on_potion_refused(what: String, why: String) -> void:
	print("EVENSONG_POTION %s refused: %s" % [what, why])


# --- M5a: farming (offline) -------------------------------------------------------------------------------

## A farm for every map (offline only, like the arenas; M5c: a session's farms are the host's, SessionHost.farm_of).
func setup_farming() -> void:
	farming_on = true
	for id: int in worlds:
		ensure_farm(id)


## Map `id`'s farm, (re)made when missing or when its world got other data (tests swap worlds).
func ensure_farm(id: int) -> bool:
	var w: GameWorld = _live_world(id)
	if not farming_on or w == null or w.data == null:
		return false
	if not farms.has(id) or farms[id].data != w.data:
		farms[id] = Farm.new(w.data)
		farms[id].stage_ticks_base = CliOptions.current().test_crop_ticks  # M5c: 0 unless --test-crop-ticks
	return true


## One farm tick on every map (Config.FARM_RUNS_WITHOUT_PLAYERS; false: only where a player is), in map order; the
## edits go into each map's world.
func step_farms() -> void:
	if not farming_on:
		return
	var ids: Array[int] = []
	ids.assign(worlds.keys())
	ids.sort()
	for id: int in ids:
		if not ensure_farm(id):
			continue
		if not Config.FARM_RUNS_WITHOUT_PLAYERS and players_on(id).is_empty():
			continue
		var w: GameWorld = worlds[id]
		for e: EditLog.WorldEdit in farms[id].step():
			var was: Farming.Field = Farming.field_at(w.data, e.cell)
			w.apply_edit(e)
			_log_field_change(was, Farming.Field.of(e.value), e.cell)


func _log_field_change(was: Farming.Field, now: Farming.Field, c: Vector2i) -> void:
	if was == null or now == null or now.kind == Farming.KIND_NONE:
		return
	if now.stage != was.stage:
		print("EVENSONG_FARM grew at=%d,%d crop=%s stage=%d" % [c.x, c.y, Farming.CROP_NAMES[now.kind], now.stage])
	if now.withered != was.withered:
		print("EVENSONG_FARM %s at=%d,%d crop=%s stage=%d" % ["withered" if now.withered else "revived", c.x, c.y,
			Farming.CROP_NAMES[now.kind], now.stage])


## The hoe's / the watering can's landing frame, or the sickle's on a crop (Farming.is_harvest_swing), for player `p`
## on the local player's map.
func farm_impact(p: Player, item: StringName, target: Vector2i) -> void:
	if not ensure_farm(current_map):
		return
	var farm: Farm = farms[current_map]
	if item == Farming.HOE:
		_apply_farm(farm, farm.till(p.sim_position, target), "till", target, p)
	elif item == Farming.WATERING_CAN:
		_apply_farm(farm, farm.water(p.sim_position, target), "water", target, p)
	else:
		_apply_farm(farm, farm.harvest(p.sim_position, p.class_id(), p.inventory, target), "harvest", target, p)


func _apply_farm(farm: Farm, r: Farm.Result, what: String, cell: Vector2i, p: Player) -> void:
	var w: GameWorld = _world_of(p)
	if w == null:
		w = current_world()
	if not r.ok():
		print("EVENSONG_FARM %s refused at=%d,%d class=%s: %s" % [what, cell.x, cell.y, p.class_id(), r.why])
		return
	for e: EditLog.WorldEdit in r.edits:
		w.apply_edit(e)
	var f: Farming.Field = Farming.field_at(farm.data, cell)
	var line: String = "EVENSONG_FARM %s at=%d,%d class=%s" % [what, cell.x, cell.y, p.class_id()]
	if what == "harvest":
		line += " item=%s count=%d grade=%s seeds=%d dropped=%d lost=%d" % [r.item, r.count, ItemDB.GRADE_NAMES[r.grade],
			r.seeds, r.dropped, r.lost]
	elif what == "plant":
		line += " item=%s" % r.item
	print(line + (" field=%s" % f.describe() if f != null else " field=none"))


## --test-field (screenshots, tests): fields put down on the start map at the start, past the farming rules (outside the
## light too) but never next to ash (the terrain rule). The farm takes them as they are; one there withers on its first
## tick if it is outside the light or next to corruption.
func apply_test_fields(entries: Array[Array]) -> void:
	if not ensure_farm(current_map):
		return
	put_test_fields(current_world(), farms[current_map], entries)


## The --test-field entries into world `w` (data and views, no edit log) and its farm `farm` (M5c: the host's start too).
static func put_test_fields(w: GameWorld, farm: Farm, entries: Array[Array]) -> void:
	for entry: Array in entries:
		var c: Vector2i = entry[0]
		var kind: int = entry[1]
		var stage: int = entry[2]
		var is_wet: bool = entry[3]
		var fast: bool = entry[4]
		if not w.data.in_bounds(c) or (w.data.terrain_at(c) != Terrain.SOIL and not w.data.can_set_terrain(c, Terrain.SOIL)):
			print("EVENSONG_FARM test field refused at=%d,%d: not soil, cannot be (ash next to it)" % [c.x, c.y])
			continue
		w.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.FLOOR, c, Terrain.SOIL))
		var f: Farming.Field = Farming.Field.new(kind, stage, is_wet, fast)
		w.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, c, f.value()))
		farm.sync_cell(c)


# --- M5b: purification and moving the altar (offline) -------------------------------------------------------------

func _connect_purify(p: Player) -> void:
	for pair: Array in [[p.channel_started, _on_channel_started], [p.channel_done, _on_channel_done],
			[p.channel_broken, _on_channel_broken], [p.purify_refused, _on_purify_refused],
			[p.altar_place_requested, _on_altar_place_requested]]:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if not sig.is_connected(handler):
			sig.connect(handler)


## Holy water's effect frame for player `p` on tile `target` (Purify.pour: checked again, one used, the area purified).
func holy_water_impact(p: Player, target: Vector2i) -> void:
	var w: GameWorld = _world_of(p)
	if w == null:
		return
	apply_purify(w, Purify.pour(w.data, p.sim_position, p.inventory, p.action_slot, target), "holy water", target, p)


## A purification's edits go into world `w` (data and views), the purified tiles flash, the arena follows the corruption
## (Arena.sync_world: its spawn tiles), and a log line.
func apply_purify(w: GameWorld, r: Purify.Result, what: String, cell: Vector2i, p: Player) -> void:
	if not r.ok():
		print("EVENSONG_PURIFY %s refused at=%d,%d class=%s: %s" % [what, cell.x, cell.y, p.class_id(), r.why])
		return
	for e: EditLog.WorldEdit in r.edits:
		w.apply_edit(e)
	w.purify_view.flash(r.cells)
	purified += r.cells.size()
	var spawn_tiles: int = -1
	if ensure_combat(w.map_id):
		arenas[w.map_id].sync_world()
		spawn_tiles = arenas[w.map_id].spawn_cells.size()
	print("EVENSONG_PURIFY %s at=%d,%d class=%s tiles=%d corrupted_left=%d spawn_tiles=%d" % [what, cell.x, cell.y,
		p.class_id(), r.cells.size(), Purify.corrupted_count(w.data), spawn_tiles])


func _on_channel_started(cell: Vector2i) -> void:
	print("EVENSONG_PURIFY channel start at=%d,%d class=%s ticks=%d" % [cell.x, cell.y, player.class_id(),
		Config.PURIFY_CHANNEL_TICKS])


func _on_channel_done(cell: Vector2i) -> void:
	var w: GameWorld = _world_of(player)
	if w == null:
		return
	apply_purify(w, Purify.channel_done(w.data, cell), "channel", cell, player)


func _on_channel_broken(why: String) -> void:
	print("EVENSONG_PURIFY channel broken: %s" % why)


func _on_purify_refused(what: String, why: String) -> void:
	print("EVENSONG_PURIFY %s refused: %s" % [what, why])


## F held aimed at an altar tile (Config.ALTAR_PICKUP_HOLD_TICKS, AltarMove.pickup_refusal) picks the altar up; letting go
## or aiming away starts the count over. Then, while `p` carries it, the ghost shows where a click would put it.
## M5-fix: a frame counts only by AltarMove.hold_counts (no action, no channel running, no downed player in revive reach:
## the host's rule, so a channel can never finish while its paladin carries the altar, and a revive never lifts it).
func step_altar_hold(p: Player) -> void:
	if not purify_on or p == null or not is_instance_valid(p):
		return
	var w: GameWorld = _world_of(p)
	if w == null:
		return
	if not p.carrying_altar:
		if p.interact_held and AltarMove.hold_counts(p, players_on(w.map_id)) \
				and AltarMove.pickup_refusal(w.data, p.class_id(), p.sim_position, p.aim_cell).is_empty():
			p.altar_hold_ticks += 1
			if p.altar_hold_ticks >= Config.ALTAR_PICKUP_HOLD_TICKS:
				pick_up_altar(p)
		else:
			p.altar_hold_ticks = 0
	_show_altar_ghost(p)


## While player `p` carries the altar the ghost shows where a click would put it down, gold where the placing rules allow
## (on this machine's world: in a session the host decides, M5c), dark red where not; nothing otherwise.
func _show_altar_ghost(p: Player) -> void:
	if ghost == null or p == null or not is_instance_valid(p):
		return
	var w: GameWorld = _world_of(p)
	if w == null or not p.carrying_altar:
		ghost.show_at(Rect2i(), false)
		return
	var rect: Rect2i = AltarMove.place_rect(p.sim_position, p.aim_cell)
	# M7c: worked out again only when the footprint, the world, a body's or a heretic's tile change, and every
	# GHOST_RECHECK_TICKS (like the build ghost): M7b's seal check (Building.reaches from the nine new spawn slots) takes
	# about 24 ms, and done every tick it held the host below 60 ticks a second while someone carried the altar (its
	# clients' clocks then ran ahead of its states: the M5c `altar` session's other players were drawn past their newest
	# state). The host still decides the put down with the full rule (SessionHost._altar_place).
	var bodies: Array[Vector2] = bodies_on(w.map_id)
	var heretics: Array[Vector2] = heretics_on(w.map_id)
	_altar_ghost_ticks += 1
	var key: Array = [rect, w.revision, _altar_ghost_ticks / GHOST_RECHECK_TICKS, _cells_of(bodies), _cells_of(heretics)]
	if key != _altar_ghost_key:
		_altar_ghost_key = key
		_altar_ghost_ok = AltarMove.place_refusal(w.data, rect, bodies, heretics).is_empty()
	ghost.show_at(rect, _altar_ghost_ok)


## M7c: the carried altar's ghost: the answer, what it was worked out for, the ticks shown.
var _altar_ghost_key: Array = []
var _altar_ghost_ok: bool = false
var _altar_ghost_ticks: int = 0


## M7c: the tiles of feet `points` (a ghost's cache key).
static func _cells_of(points: Array[Vector2]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pt: Vector2 in points:
		out.append(Aim.feet_cell(pt))
	return out


## Player `p` takes the altar out of the world and carries it (AltarMove.pickup_edits).
func pick_up_altar(p: Player) -> void:
	var w: GameWorld = _world_of(p)
	if w == null or not w.data.altar_rect.has_area():
		return
	var from: Rect2i = w.data.altar_rect
	for e: EditLog.WorldEdit in AltarMove.pickup_edits(w.data):
		w.apply_edit(e)  # the world keeps where it stood (GameWorld.last_altar_rect: the set-down's last fallback)
	p.altar_hold_ticks = 0
	p.set_carrying_altar(true)
	print("EVENSONG_ALTAR picked up who=%s class=%s from=%d,%d" % [p.name, p.class_id(), from.position.x, from.position.y])


## The feet of the players on map `map_id` (bodies a footprint may not cover) and of its live heretics.
func bodies_on(map_id: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for q: Player in players_on(map_id):
		out.append(q.sim_position)
	return out


func heretics_on(map_id: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if _in_session():
		return net.bots.foe_positions() if map_id == net.local_map() else out  # M5c: as this machine has them
	if arenas.has(map_id):
		for h: HereticSim in arenas[map_id].heretics:
			if h.alive():
				out.append(h.pos)
	return out


func _on_altar_place_requested(cell: Vector2i) -> void:
	place_altar(player, cell)


## Player `p` carrying the altar puts it down aiming at tile `cell` (AltarMove.place_rect / place_refusal). Returns ""
## or why not.
func place_altar(p: Player, cell: Vector2i) -> String:
	var w: GameWorld = _world_of(p)
	if w == null or not p.carrying_altar:
		return AltarMove.WHY_NO_ALTAR
	var rect: Rect2i = AltarMove.place_rect(p.sim_position, cell)
	var why: String = AltarMove.place_refusal(w.data, rect, bodies_on(w.map_id), heretics_on(w.map_id))
	if not why.is_empty():
		print("EVENSONG_ALTAR place refused at=%d,%d who=%s: %s" % [rect.position.x, rect.position.y, p.name, why])
		return why
	_put_altar(w, p, rect, "placed")
	return ""


## The carrier `p` went down: the altar comes down at the nearest allowed place around it (AltarMove.set_down_fallback:
## then ignoring the heretics, then around where it last stood, GameWorld.last_altar_rect). M5-fix: never over anything,
## and when nothing allows it (no place within Config.ALTAR_SET_DOWN_SEARCH_TILES of either) `p` keeps it (logged once;
## README "알려진 문제 (M5-fix)"). Returns whether it came down.
func set_altar_down(p: Player) -> bool:
	var w: GameWorld = _world_of(p)
	if w == null:
		return false
	var rect: Rect2i = AltarMove.set_down_fallback(w.data, p.sim_position, w.last_altar_rect, bodies_on(w.map_id),
		heretics_on(w.map_id))
	if not rect.has_area():
		p.altar_set_down_failed = true
		print("EVENSONG_ALTAR set down failed who=%s: no place allows it, still carried" % p.name)
		return false
	_put_altar(w, p, rect, "set down")
	return true


## M5-fix: every carrier that is down or dead now sets the altar down, once a tick after the combat (offline
## _physics_process; the host's SessionHost._check_carriers). A carrier for whom no place was found tries again once it
## is up again (Player.altar_set_down_failed).
func check_carriers() -> void:
	if not purify_on:
		return
	var all: Array[Player] = [player]
	all.append_array(allies)
	for p: Player in all:
		if p == null or not is_instance_valid(p) or not p.carrying_altar:
			continue
		if p.vitals.alive():
			p.altar_set_down_failed = false
		elif not p.altar_set_down_failed:
			set_altar_down(p)


## M5-fix: world `w` has no altar and nobody here carries it (a client playing on after it lost the host while the host
## or another client carried it): it comes back where it last stood (`w.last_altar_rect`), or at the nearest place the
## placing rules allow around that (with `bodies`, ignoring heretics: the offline arena is not set up yet), or, with no
## place known (joined while it was carried), around the local player. Returns the footprint, empty when none allowed
## it (then a respawn waits as while it is carried; logged).
func restore_altar(w: GameWorld, bodies: Array[Vector2]) -> Rect2i:
	var from: Vector2 = player.sim_position if player != null and is_instance_valid(player) and player.data == w.data \
		else Vector2(w.data.size * Config.TILE) / 2.0
	return restore_altar_at(w, from, bodies)


## restore_altar's work: where it last stood if the placing rules allow (with `bodies`), else the nearest allowed place
## around that, else around `from` (AltarMove.set_down_fallback, home first); the edits go into `w`.
static func restore_altar_at(w: GameWorld, from: Vector2, bodies: Array[Vector2]) -> Rect2i:
	var none: Array[Vector2] = []
	var rect: Rect2i = AltarMove.set_down_fallback(w.data, from, w.last_altar_rect, bodies, none, true)
	if not rect.has_area():
		print("EVENSONG_ALTAR restore failed: no place allows it (last stood %s)" % w.last_altar_rect)
		return rect
	for e: EditLog.WorldEdit in AltarMove.place_edits(rect):
		w.apply_edit(e)
	print("EVENSONG_ALTAR restored at=%d,%d (the host went while it was carried) light=%d,%d" % [rect.position.x,
		rect.position.y, roundi(w.data.altar_center_px().x), roundi(w.data.altar_center_px().y)])
	return rect


func _put_altar(w: GameWorld, p: Player, rect: Rect2i, what: String) -> void:
	for e: EditLog.WorldEdit in AltarMove.place_edits(rect):
		w.apply_edit(e)
	p.set_carrying_altar(false)
	ghost.show_at(Rect2i(), false)
	altar_moves += 1
	print("EVENSONG_ALTAR %s at=%d,%d who=%s light=%d,%d" % [what, rect.position.x, rect.position.y, p.name,
		roundi(w.data.altar_center_px().x), roundi(w.data.altar_center_px().y)])


## The surface's altar moved (GameWorld.altar_moved): the arena works out its light and spawn tiles again, and the
## dummies stand on the new spawn slots facing it (they stay where they were while it is carried).
func _on_altar_moved() -> void:
	if arenas.has(Config.MAP_SURFACE):
		arenas[Config.MAP_SURFACE].sync_world()
	if not world.data.altar_rect.has_area():
		return
	var slot: int = 1
	for d: Character in dummies:
		if not is_instance_valid(d) or not d.name.begins_with("Dummy_"):
			continue
		d.position = world.spawn_point(slot)
		d.direction = RigData.facing_toward(d.position, world.data.altar_center_px()) as RigData.Dir
		slot += 1


## The channels under way on the shown map, for its PurifyView (one per channelling player).
func _show_purify() -> void:
	var w: GameWorld = current_world()
	if w == null or w.purify_view == null:
		return
	var list: Array[PurifyView.Channel] = []
	for q: Player in players_on(current_map):
		if q.channel_tick > 0:
			list.append(PurifyView.Channel.new(q.channel_cell, q.channel_tick))
	if not list.is_empty() or not w.purify_view.channels.is_empty():
		w.purify_view.show_channels(list)


func _on_action_started(item: StringName, anim: int, target: Vector2i) -> void:
	if _in_session():
		return  # the session logs actions itself
	print("EVENSONG_ACTION start item=%s action=%s facing=%s target=%d,%d" % [item, RigData.ANIM_NAMES[anim],
		RigData.DIR_NAMES[player.facing], target.x, target.y])


## Screenshot / test flags (core/cli_options.gd).
func _apply_test_options(options: CliOptions) -> void:
	if options.start_map != Config.MAP_SURFACE:
		travel(options.start_map)
	if options.test_select > 0:
		player.inventory.select(options.test_select - 1)
	if options.test_inventory:
		hud.set_open(true)
	if options.test_aim != null:
		var aim: Vector2 = options.test_aim
		player.test_aim = aim
	if not options.test_action.is_empty():
		player.freeze_action(options.test_action[0], options.test_action[1])
	if options.test_action_lineup > -2:
		spawn_action_lineup(options.test_action_lineup)
	if options.test_at != null:
		var at: Vector2i = options.test_at
		player.teleport(Arena.spawn_feet(at))
		camera.follow()
	if not options.test_ally.is_empty():
		add_ally(options.test_ally, options.test_ally_down)
	if options.test_down:
		player.take_hit(Config.PLAYER_HP_MAX)
	if options.test_shrine_hp > 0 and arenas.has(current_map) and arenas[current_map].shrine_rect().has_area():
		arenas[current_map].shrine_hp = options.test_shrine_hp
	if arenas.has(current_map):
		for c: Vector2i in options.test_heretics:
			arenas[current_map].spawn_heretic(Arena.spawn_feet(c))
		combat_views[current_map].sync(players_on(current_map))
	if not options.test_fields.is_empty():
		apply_test_fields(options.test_fields)  # M5a
	put_test_build(current_world(), options.test_build)  # M7b: pieces put down without the rules (screenshots, tests)
	for d: Vector2i in options.test_durability:
		var st: ItemStack = player.inventory.stack_at(d.x)  # M7a: a worn item for screenshots and tests
		if st != null and st.max_durability() > 0:
			st.durability = clampi(d.y, 0, st.max_durability())
			player.inventory.changed.emit()
	if options.test_wear > 0:
		equip_armor(options.test_wear - 1)
	if arenas.has(Config.MAP_DUNGEON):
		for c: Vector2i in options.test_dungeon_heretics:
			arenas[Config.MAP_DUNGEON].spawn_heretic(Arena.spawn_feet(c))
		combat_views[Config.MAP_DUNGEON].sync(players_on(Config.MAP_DUNGEON))
	marker.refresh()


## M7b: --test-build's pieces (entries [tile, piece item id or &"door_open"]) into world `w` without the building rules.
## M7c: a session's host does the same before anyone joins (SessionHost._setup_forests).
static func put_test_build(w: GameWorld, entries: Array[Array]) -> void:
	for entry: Array in entries:
		var bc: Vector2i = entry[0]
		var bpiece: StringName = entry[1]
		var be: EditLog.WorldEdit = Building.edit_for(bpiece, bc)
		if bpiece == &"door_open":
			be = EditLog.WorldEdit.new(WorldData.Layer.WALL, bc, Walls.pack(Walls.KIND_DOOR_OPEN, 0))
		w.apply_edit(be)


## The local class doing every body action, frozen at `frame` (-1 = each action's middle frame): a
## row facing south and a row facing east, around a point south of the altar. The local player is
## hidden there and the camera follows it.
func spawn_action_lineup(frame: int) -> void:
	for d: Character in dummies:
		d.get_parent().remove_child(d)
		d.free()
	dummies.clear()
	var center: Vector2 = world.data.altar_center_px() + Vector2(LINEUP_CENTER)
	player.teleport(center)
	player.local_input = false
	player.visible = false
	var n: int = RigData.ACTION_ANIMS.size()
	for row: int in 2:
		for i: int in n:
			var anim: int = RigData.ACTION_ANIMS[i]
			var c: Character = Character.new()
			c.name = StringName("Lineup_%s_%d" % [RigData.ANIM_NAMES[anim], row])
			c.animate = false
			c.class_id = player.class_id()
			c.direction = RigData.Dir.SOUTH if row == 0 else RigData.Dir.EAST
			c.show_action(anim, frame if frame >= 0 else RigData.frame_count(anim) / 2)
			c.position = center + Vector2((i - (n - 1) / 2.0) * LINEUP_STEP, -30 + row * 80).round()
			world.entities.add_child(c)
			dummies.append(c)
	camera.follow()


func _on_net_ended(reason: String, code: int) -> void:
	var options: CliOptions = CliOptions.current()
	if options.net_out.is_empty() and code == NetSession.EXIT_FAILED and reason == "lost the host" and player != null:
		net.continue_offline()  # alone now: the keys drive the player as offline, its inventory is its own
		_go_offline_combat()
		return
	get_tree().quit(code)

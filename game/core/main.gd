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
var _gave: bool = false
var _debug_action: int = 0

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
	worlds[Config.MAP_SURFACE] = world
	if options.host or options.join:
		get_window().title = "Evensong (%s, %s)" % ["host" if options.host else "client",
			options.class_id if not options.class_id.is_empty() else Config.DEFAULT_CLASS]
		net.local_player_ready.connect(_on_local_player_ready)
		net.local_map_changed.connect(_on_local_map_changed)
		net.ended.connect(_on_net_ended)
		add_dungeon(options.host)  # the host makes the dungeon; a client gets it from the host
		for id: int in worlds:
			net.worlds[id] = worlds[id]
		net.start(world, options)
		return
	add_dungeon()
	spawn(options.class_id if not options.class_id.is_empty() else Config.DEFAULT_CLASS)
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


## M3a: takes the local player to map `to` (offline): its arrival point there (the dungeon: south of
## the exit stairs; the surface: south of the entrance), facing south, its action stopped.
func travel(to: int) -> void:
	if player == null or to == current_map or not worlds.has(to) or _in_session():
		return
	_show_map(to)
	var w: GameWorld = worlds[to]
	player.get_parent().remove_child(player)
	w.entities.add_child(player)
	player.set_world(w.data, w.arrival_point())
	_follow(player)
	marker.refresh()
	print("EVENSONG_MAP travel to=%s feet=%d,%d" % [Config.MAP_NAMES[to], roundi(player.sim_position.x),
		roundi(player.sim_position.y)])


func _physics_process(delta: float) -> void:
	if bot == null or player == null or _in_session():
		return
	var a: NetBot.Action = bot.step(player.sim_position)
	player.tick_controls(a.dir, a.mouse, a.aiming, a.use_pressed, a.use_held, delta)
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
	player.setup(world.data, local_class, world.spawn_point(0), Config.SPAWN_FACING)
	player.action_started.connect(_on_action_started)
	player.action_impact.connect(_on_action_impact)
	player.place_requested.connect(_on_place_requested)
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


func _on_local_player_ready(p: Player) -> void:
	player = p
	_follow(p)
	_bind(p)


## M3b: the session put the local player on map `map_id`: show it, the camera and the marker with it.
func _on_local_map_changed(map_id: int) -> void:
	_show_map(map_id)
	if player != null:
		_follow(player)
	marker.refresh()
	print("EVENSONG_MAP travel to=%s feet=%d,%d" % [Config.MAP_NAMES[map_id], roundi(player.sim_position.x),
		roundi(player.sim_position.y)])


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not is_instance_valid(player):
		return
	if event.is_action_pressed(&"hotbar_prev"):
		select_hotbar(-1)
	elif event.is_action_pressed(&"hotbar_next"):
		select_hotbar(1)
	elif event.is_action_pressed(&"toggle_inventory"):
		hud.toggle_open()
	elif event.is_action_pressed(&"interact"):
		pick_up()
	elif event.is_action_pressed(&"debug_drop"):
		drop_selected()
	elif event.is_action_pressed(&"debug_give"):
		give_debug_kit()
	elif event.is_action_pressed(&"debug_action"):
		debug_next_action()


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


## F: pick up what lies on the target tile (offline: at once; in a session: a request).
func pick_up() -> void:
	if _in_session():
		net.queue_op(request(NetProtocol.Op.PICKUP))
		return
	var cell: Vector2i = Aim.target_cell(player.sim_position, player.aim_sector)
	var data: WorldData = current_world().data
	var to: int = WorldItems.travel(data, player.sim_position, cell)
	if to >= 0:
		travel(to)
		return
	_apply_offline(WorldItems.pickup(data, player.sim_position, player.class_id(), player.inventory, cell),
		"pickup", cell)


## F7 (debug): drop the selected stack on the target tile.
func drop_selected() -> void:
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
func _on_action_impact(item: StringName, _anim: int, target: Vector2i) -> void:
	if item != Mining.PICKAXE or _in_session() or player == null:
		return
	var w: GameWorld = current_world()
	var r: Mining.Result = Mining.strike(w.data, player.sim_position, player.class_id(), player.inventory, target)
	if r.why == Mining.WHY_NO_WALL:
		return  # a swing at open ground (the surface): nothing to report, as in M2
	for e: EditLog.WorldEdit in r.edits:
		w.apply_edit(e)
	print("EVENSONG_MINE at=%d,%d class=%s %s" % [target.x, target.y, player.class_id(),
		r.describe() if r.ok() else "refused: " + r.why])


## M3a, offline: a click with a torch selected puts it on the target tile.
func _on_place_requested(slot: int, cell: Vector2i) -> void:
	if _in_session() or player == null:
		return
	_apply_offline(WorldItems.place(current_world().data, player.sim_position, player.inventory, slot, cell), "place", cell)


func _on_action_started(item: StringName, anim: int, target: Vector2i) -> void:
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
	marker.refresh()


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
		return
	get_tree().quit(code)

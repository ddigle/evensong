class_name Main
extends Node2D
## Root of scenes/main.tscn, the run scene (M1 + M2a).
##
## Offline (no --host / --join): the world (world.tscn without its free camera), the local player
## (class from --class, Config.DEFAULT_CLASS without it) on spawn slot 0, the other slice classes as
## static dummies on the next slots facing the altar (so all five signatures show), and a
## PlayerCamera centred on the local player. M2a: the local player has `controls` on (mouse aim,
## hotbar use, body actions, actors/player.gd), the HUD shows its hotbar (ui/hud.gd) and a
## TargetMarker shows the aimed tile (world/target_marker.gd, between the ground and the entities).
## In a session (--host / --join, net/session.gd): no dummies; the session creates every player
## and hands over the local one, which the camera follows. The HUD shows its (local) inventory; aim
## and actions stay off in sessions in M2a. When the session ends with --net-out (a test instance),
## or with a refusal or a failed join, the process quits with the session's code; a client that
## loses its host without --net-out plays on alone.
##
## Keys (PROVISIONAL, README "임시값"): WASD / arrows move (8 ways), mouse aims, left click uses
## the selected hotbar item, Q / E select the hotbar slot left / right, Tab shows the inventory.
## Development keys: F3 debug lines, F4 evening + altar light on / off, F5 give the debug kit, F6 play
## the next body action (all eight, also magic and throw that no item plays yet).

## Feet offset (px) from the altar centre where --test-action-lineup puts the camera.
const LINEUP_CENTER: Vector2i = Vector2i(0, 110)
const LINEUP_STEP: int = 56

var player: Player
var dummies: Array[Character] = []
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
	if options.host or options.join:
		get_window().title = "Evensong (%s, %s)" % ["host" if options.host else "client",
			options.class_id if not options.class_id.is_empty() else Config.DEFAULT_CLASS]
		net.local_player_ready.connect(_on_local_player_ready)
		net.ended.connect(_on_net_ended)
		net.start(world, options)
		return
	spawn(options.class_id if not options.class_id.is_empty() else Config.DEFAULT_CLASS)
	_apply_test_options(options)


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
	player = Player.new()
	player.name = &"LocalPlayer"
	player.controls = true
	player.setup(world.data, local_class, world.spawn_point(0), Config.SPAWN_FACING)
	player.action_started.connect(_on_action_started)
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
	camera.bounds = world.map_rect_px()
	camera.make_current()
	camera.follow()


## Points the HUD and the target marker at the local player; the first time, gives the --give items.
func _bind(p: Player) -> void:
	if hud == null:
		return
	hud.bind(p.inventory)
	marker.player = p
	marker.map_cells = world.data.size
	marker.refresh()
	if not _gave:
		_gave = true
		for entry: Array in CliOptions.current().give:
			var id: StringName = entry[0]
			var count: int = entry[1]
			var grade: int = entry[2]
			p.inventory.add(id, count, grade)


func _on_local_player_ready(p: Player) -> void:
	player = p
	_follow(p)
	_bind(p)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not is_instance_valid(player):
		return
	if event.is_action_pressed(&"hotbar_prev"):
		player.inventory.select_offset(-1)
	elif event.is_action_pressed(&"hotbar_next"):
		player.inventory.select_offset(1)
	elif event.is_action_pressed(&"toggle_inventory"):
		hud.toggle_open()
	elif event.is_action_pressed(&"debug_give"):
		give_debug_kit()
	elif event.is_action_pressed(&"debug_action"):
		debug_next_action()


## F5: every item of ItemDB.debug_kit() into the local player's inventory (what does not fit is lost).
func give_debug_kit() -> void:
	for entry: Array in ItemDB.debug_kit():
		var id: StringName = entry[0]
		var count: int = entry[1]
		var grade: int = entry[2] if entry.size() > 2 else -1
		player.inventory.add(id, count, grade)
	print("EVENSONG_ITEMS debug kit given: %s" % player.inventory.describe())


## F6: the next of the eight body actions toward the current aim, whatever is selected (offline).
func debug_next_action() -> void:
	if not player.controls or player.action_anim >= 0:
		return
	player.start_action(RigData.ACTION_ANIMS[_debug_action % RigData.ACTION_ANIMS.size()], &"debug")
	_debug_action += 1


func _on_action_started(item: StringName, anim: int, target: Vector2i) -> void:
	print("EVENSONG_ACTION start item=%s action=%s facing=%s target=%d,%d" % [item, RigData.ANIM_NAMES[anim],
		RigData.DIR_NAMES[player.facing], target.x, target.y])


## Screenshot / test flags (core/cli_options.gd).
func _apply_test_options(options: CliOptions) -> void:
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
		net.continue_offline()
		player.controls = true  # alone now: aim and actions as offline (M2a)
		return
	get_tree().quit(code)

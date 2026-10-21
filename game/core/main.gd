class_name Main
extends Node2D
## Root of scenes/main.tscn, the run scene (M1).
##
## Offline (no --host / --join): the world (world.tscn without its free camera), the local player
## (class from --class, Config.DEFAULT_CLASS without it) on spawn slot 0, the other slice classes as
## static dummies on the next slots facing the altar (so all five signatures show), and a
## PlayerCamera centred on the local player.
## In a session (--host / --join, net/session.gd): no dummies; the session creates every player
## and hands over the local one, which the camera follows. When the session ends with --net-out (a
## test instance), or with a refusal or a failed join, the process quits with the session's code;
## a client that loses its host without --net-out plays on alone.
##
## Keys: WASD / arrows move (8 ways, provisional), F4 evening + altar light on / off, F3 debug lines.

var player: Player
var dummies: Array[Character] = []

@onready var world: GameWorld = $World
@onready var camera: PlayerCamera = $Camera
@onready var net: NetSession = $Net


func _ready() -> void:
	if world.data == null:
		world.generate(CliOptions.current().world_seed)
	var options: CliOptions = CliOptions.current()
	if not options.errors.is_empty():
		return  # the Cli autoload reports the bad flags and quits
	if options.host or options.join:
		get_window().title = "Evensong (%s, %s)" % ["host" if options.host else "client",
			options.class_id if not options.class_id.is_empty() else Config.DEFAULT_CLASS]
		net.local_player_ready.connect(_on_local_player_ready)
		net.ended.connect(_on_net_ended)
		net.start(world, options)
		return
	spawn(options.class_id if not options.class_id.is_empty() else Config.DEFAULT_CLASS)


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
	player.setup(world.data, local_class, world.spawn_point(0), Config.SPAWN_FACING)
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


func _follow(target: Player) -> void:
	camera.target = target
	camera.bounds = world.map_rect_px()
	camera.make_current()
	camera.follow()


func _on_local_player_ready(p: Player) -> void:
	player = p
	_follow(p)


func _on_net_ended(reason: String, code: int) -> void:
	var options: CliOptions = CliOptions.current()
	if options.net_out.is_empty() and code == NetSession.EXIT_FAILED and reason == "lost the host" and player != null:
		net.continue_offline()
		return
	get_tree().quit(code)

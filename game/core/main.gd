class_name Main
extends Node2D
## Root of scenes/main.tscn, the run scene (M1): the world (world.tscn without its free camera),
## the local player (class from --class, Config.DEFAULT_CLASS without it) on spawn slot 0, the other
## slice classes as static dummies on the next slots facing the altar (so all five signatures show),
## and a PlayerCamera centred on the local player.
##
## Keys: WASD / arrows move (8 ways, provisional), F4 evening + altar light on / off, F3 debug lines.

var player: Player
var dummies: Array[Character] = []

@onready var world: GameWorld = $World
@onready var camera: PlayerCamera = $Camera


func _ready() -> void:
	if world.data == null:
		world.generate(CliOptions.current().world_seed)
	var options: CliOptions = CliOptions.current()
	spawn(options.class_id if not options.class_id.is_empty() else Config.DEFAULT_CLASS)


## (Re)creates the local player and the dummies for a local class.
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
	player.setup(world.data, local_class, world.spawn_point(0), RigData.Dir.SOUTH)
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
	camera.target = player
	camera.bounds = world.map_rect_px()
	camera.make_current()
	camera.follow()

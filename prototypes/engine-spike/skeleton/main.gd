extends Control
## Spike menu (res://main.tscn): lists the module scenes res://<module>/<module>.tscn.
## Keys 1-9 open a scene; F10 (SpikeCli) comes back here.

const Modules := preload("res://skeleton/modules.gd")
const TITLE: String = "Evensong engine spike"

var modules: PackedStringArray = []

@onready var label: Label = $Margin/Label


func _ready() -> void:
	modules = Modules.list_modules()
	label.text = build_text(modules)


static func build_text(mods: PackedStringArray) -> String:
	var lines: PackedStringArray = [
		"%s  (Godot %s)" % [TITLE, Engine.get_version_info().string],
		"",
		"Spike scenes:",
	]
	if mods.is_empty():
		lines.append("  (none yet)")
	for i: int in mods.size():
		lines.append("  %d. %s   %s" % [i + 1, mods[i], Modules.scene_path(mods[i])])
	lines.append("")
	lines.append("1-9: open a scene    F10: back to this menu")
	return "\n".join(lines)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index: int = key.keycode - KEY_1
	if index >= 0 and index < mini(modules.size(), 9):
		get_tree().change_scene_to_file(Modules.scene_path(modules[index]))

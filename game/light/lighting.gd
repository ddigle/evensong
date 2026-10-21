class_name Lighting
extends Node2D
## Evening darkness + the altar light, toggled together (F4, action toggle_evening; --no-evening
## starts with them off). M1 has one constant evening, no day/night cycle: the surface light is an
## open question (? gameplay-design §3.1), so the colour is provisional (Config.EVENING_COLOR).
##   Evening    CanvasModulate (multiplies the whole canvas; unshaded items such as flames skip it)
##   AltarLight light/altar_light.gd

var evening: CanvasModulate
var altar_light: AltarLight
var evening_on: bool = true


func _init() -> void:
	evening = CanvasModulate.new()
	evening.name = &"Evening"
	evening.color = Config.EVENING_COLOR
	add_child(evening)
	altar_light = AltarLight.new()
	altar_light.name = &"AltarLight"
	add_child(altar_light)


func setup(zone: SafeZone, on: bool = true) -> void:
	altar_light.setup(zone)
	set_evening(on)


## Evening darkness and the altar light on / off together (off = the art's own colours).
func set_evening(on: bool) -> void:
	evening_on = on
	evening.visible = on
	altar_light.set_lit(on)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_evening"):
		set_evening(not evening_on)
		get_viewport().set_input_as_handled()

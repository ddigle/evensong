class_name SafeZone
extends RefCounted
## The altar's safe zone (game-concept §9.3: the altar's light = safety). One rule,
## is_in_safe_zone(), used by the game logic and by the light textures (light/light_gen.gd
## evaluates it for every texel), so what is lit is what the rules call safe.
##
## The radius is provisional (Config.SAFE_RADIUS_TILES, ? not decided).

var center: Vector2 = Vector2.ZERO
var radius: float = 0.0


func _init(p_center: Vector2 = Vector2.ZERO, p_radius: float = 0.0) -> void:
	center = p_center
	radius = p_radius


## The zone of a world's altar (empty zone if the world has no altar).
static func for_world(data: WorldData) -> SafeZone:
	if not data.altar_rect.has_area():
		return SafeZone.new(Vector2.ZERO, 0.0)
	return SafeZone.new(data.altar_center_px(), Config.safe_radius_px())


## THE rule: a world point is safe if it lies within `radius` px of the altar centre.
func is_in_safe_zone(pos: Vector2) -> bool:
	return radius > 0.0 and pos.distance_squared_to(center) <= radius * radius

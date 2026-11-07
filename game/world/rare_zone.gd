class_name RareZone
extends RefCounted
## M11b: the archer's rare zone (game-concept §12 "컬렉션은 아처 구역 1개"; size, distance and the rule of the place are PROVISIONAL, Config
## "M11b"): exactly one disc on the surface, chosen from the world seed on open land, far from the altar and clear of the corruption.
## It lives in WorldData.rare_zone. It edits no tile (the generated world's hashes stay): what shows it is a picture
## (world/rare_zone_view.gd), and what it rules is where the rare creatures live (combat/creatures.gd).
##
## Anyone may walk in. The docs' "구역별 클래스 잠금" reads here as: only the archer can hunt or capture in it (● "희귀 생물 포획·사냥은 아처만";
## README "M11b 구역 접근"): nothing stops a body at its rim.
##
## place() has its own random stream (Config.RARE_ZONE_SALT with the world seed): no generator, heretic, prayer or herd stream moves.
## It tries Config.RARE_ZONE_TRIES random centres, then walks every tile, so a map with any good site gets a zone; a map with none (a
## test's little map) gets null, and then no rare creature spawns.

## The middle tile and the radius in tiles.
var center: Vector2i = Vector2i.ZERO
var radius: int = 0


func _init(p_center: Vector2i = Vector2i.ZERO, p_radius: int = 0) -> void:
	center = p_center
	radius = p_radius


## The middle in world px (the middle tile's centre).
func center_px() -> Vector2:
	return (Vector2(center) + Vector2(0.5, 0.5)) * Config.TILE


func radius_px() -> float:
	return float(radius * Config.TILE)


## Whether a feet box at `feet` lies wholly in the zone, `inset` px inside its rim.
func holds(feet: Vector2, inset: float = 0.0) -> bool:
	var box: Rect2 = Movement.feet_box(feet)
	var r: float = radius_px() - inset
	var mid: Vector2 = center_px()
	for p: Vector2 in [box.position, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), box.end]:
		if mid.distance_to(p) > r:
			return false
	return true


## Whether tile `c`'s centre lies in the zone.
func has_tile(c: Vector2i) -> bool:
	return center_px().distance_to((Vector2(c) + Vector2(0.5, 0.5)) * Config.TILE) <= radius_px()


## Every tile whose centre lies in the zone, row by row.
func tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(center.y - radius, center.y + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			if has_tile(Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out


## Whether tile `c` of `data` counts as open land for a zone: grass with nothing that blocks a walker on it.
static func open_tile(data: WorldData, c: Vector2i) -> bool:
	return data.terrain_at(c) == Terrain.GRASS and not Movement.is_blocked(data, c)


## Whether a zone of `r` tiles may be centred on tile `c` of `data` (the rows of Config "M11b").
static func site_ok(data: WorldData, c: Vector2i, r: int) -> bool:
	if data == null or data.map_id != Config.MAP_SURFACE:
		return false
	var edge: int = r + Config.RARE_ZONE_EDGE_TILES
	if c.x < edge or c.y < edge or c.x >= data.size.x - edge or c.y >= data.size.y - edge:
		return false
	var z: RareZone = RareZone.new(c, r)
	if data.altar_rect.has_area() \
			and z.center_px().distance_to(data.altar_center_px()) < Config.RARE_ZONE_MIN_ALTAR_TILES * Config.TILE:
		return false
	var clear: int = r + Config.RARE_ZONE_ASH_CLEARANCE_TILES
	for y: int in range(c.y - clear, c.y + clear + 1):
		for x: int in range(c.x - clear, c.x + clear + 1):
			if data.get_value(WorldData.Layer.CORRUPTION, Vector2i(x, y)) != 0:
				return false
	var all: Array[Vector2i] = z.tiles()
	var open: int = 0
	for t: Vector2i in all:
		if open_tile(data, t):
			open += 1
	return open * 100 >= all.size() * Config.RARE_ZONE_MIN_OPEN_PCT


## The zone of the world `data` of seed `world_seed` (the same seed and map: the same zone), null when no site allows one or on another
## map than the surface.
static func place(data: WorldData, world_seed: int) -> RareZone:
	if data == null or data.map_id != Config.MAP_SURFACE:
		return null
	var r: int = Config.RARE_ZONE_RADIUS_TILES
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([world_seed, Config.RARE_ZONE_SALT])
	for i: int in Config.RARE_ZONE_TRIES:
		var c: Vector2i = Vector2i(rng.randi_range(0, data.size.x - 1), rng.randi_range(0, data.size.y - 1))
		if site_ok(data, c, r):
			return RareZone.new(c, r)
	for y: int in data.size.y:
		for x: int in data.size.x:
			if site_ok(data, Vector2i(x, y), r):
				return RareZone.new(Vector2i(x, y), r)
	return null


func describe() -> String:
	return "%d,%d/%d" % [center.x, center.y, radius]

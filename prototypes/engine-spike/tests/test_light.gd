extends "res://tests/spike_test.gd"
## Light module (res://light/): headless checks of how the demo is wired and of the generated
## images (light textures, flame mask, normal maps). What it looks like is checked by
## res://light/capture_light.gd with a real renderer (numbers in notes/light.md).

const LightGen := preload("res://light/light_gen.gd")
const DemoScript := preload("res://light/light_demo.gd")
const Modules := preload("res://skeleton/modules.gd")

const LIGHT_CENTRE: Vector2 = Vector2(240, 124)


func run() -> Array[String]:
	_check_light_amount()
	_check_light_images()
	_check_normal_encoding()
	_check_entry_scene()
	var demo: DemoScript = (load("res://light/light_demo.tscn") as PackedScene).instantiate() as DemoScript
	if not check_not_null(demo, "light_demo.tscn instantiates with light_demo.gd"):
		return failures
	demo.animate = false
	add_node(demo)
	await await_frames(2)
	_check_evening(demo)
	_check_altar_light(demo)
	_check_safe_zone_rule(demo)
	_check_actor_light_split(demo)
	_check_flames(demo)
	_check_normal_maps(demo)
	_check_occluder(demo)
	_check_scene_layout(demo)
	_check_radius_change(demo)
	return failures


func _check_light_amount() -> void:
	var r: float = 112.0
	var band: float = 16.0
	for edge: int in [LightGen.Edge.HARD, LightGen.Edge.DITHER, LightGen.Edge.BANDED, LightGen.Edge.SMOOTH]:
		var edge_name: String = LightGen.EDGE_NAMES[edge]
		check_eq(LightGen.light_amount(0.0, r, edge, band, 0, 0), 1.0, "%s: centre fully lit" % edge_name)
		check_eq(LightGen.light_amount(r - band - 0.1, r, edge, band, 0, 0), 1.0, "%s: core fully lit" % edge_name)
		check_eq(LightGen.light_amount(r + 0.01, r, edge, band, 0, 0), 0.0, "%s: nothing past the radius" % edge_name)
	check_eq(LightGen.light_amount(r - 0.5, r, LightGen.Edge.HARD, band, 0, 0), 1.0, "hard: lit up to the radius")
	check_eq(LightGen.light_amount(r - 4.0, r, LightGen.Edge.BANDED, band, 0, 0), LightGen.BAND_LEVELS[1], "banded: outer band")
	check_eq(LightGen.light_amount(r - 12.0, r, LightGen.Edge.BANDED, band, 0, 0), LightGen.BAND_LEVELS[0], "banded: inner band")
	# Bayer thresholds: 16 distinct values in (0,1), pattern repeats every 4 px in world space
	var seen: Dictionary = {}
	for y: int in 4:
		for x: int in 4:
			seen[LightGen.bayer_threshold(x, y)] = true
			check_eq(LightGen.bayer_threshold(x + 4, y - 8), LightGen.bayer_threshold(x, y), "bayer repeats every 4 px")
	check_eq(seen.size(), 16, "bayer has 16 thresholds")


func _check_light_images() -> void:
	var r: int = 112
	var hard: Image = LightGen.safe_zone_light_image(r, LightGen.Edge.HARD, 16)
	check_eq(hard.get_size(), Vector2i(2 * r, 2 * r), "light texture is 2R x 2R (texture_scale 1 = 1 texel per pixel)")
	check_eq(hard.get_pixel(r, r).a, 1.0, "hard: centre alpha 1")
	check_eq(hard.get_pixel(2 * r - 1, r).a, 1.0, "hard: last texel on the axis lit (d = R - 0.5)")
	check_eq(hard.get_pixel(0, 0).a, 0.0, "hard: corner dark")
	check_eq(hard.get_pixel(r, r).r, 1.0, "light texture is white (alpha carries the amount)")
	var levels: Dictionary = {}
	var dither: Image = LightGen.safe_zone_light_image(r, LightGen.Edge.DITHER, 16, Vector2i(128, 12))
	var banded: Image = LightGen.safe_zone_light_image(r, LightGen.Edge.BANDED, 16)
	var banded_levels: Dictionary = {}
	var band_lit: Array[int] = [0, 0, 0, 0]
	var band_all: Array[int] = [0, 0, 0, 0]
	for y: int in 2 * r:
		for x: int in 2 * r:
			levels[dither.get_pixel(x, y).a8] = true
			banded_levels[banded.get_pixel(x, y).a8] = true
			var d: float = Vector2(float(x) + 0.5 - r, float(y) + 0.5 - r).length()
			if d > float(r - 16) and d <= float(r):
				var q: int = clampi(int((d - float(r - 16)) / 4.0), 0, 3)
				band_all[q] += 1
				if dither.get_pixel(x, y).a > 0.5:
					band_lit[q] += 1
	check_eq(levels.size(), 2, "dither: only on/off texels (got %s)" % str(levels.keys()))
	check_eq(banded_levels.size(), LightGen.BAND_LEVELS.size() + 2, "banded: core + bands + dark")
	var prev: float = 2.0
	for q: int in 4:
		var frac: float = float(band_lit[q]) / float(maxi(band_all[q], 1))
		check(frac < prev, "dither gets sparser towards the radius (quarter %d: %.2f)" % [q, frac])
		prev = frac
	var smooth: Image = LightGen.safe_zone_light_image(r, LightGen.Edge.SMOOTH, 16)
	var last: float = 2.0
	for x: int in range(r + r - 20, 2 * r):
		var a: float = smooth.get_pixel(x, r).a
		check(a <= last, "smooth: alpha falls monotonically at x=%d" % x)
		last = a


func _check_normal_encoding() -> void:
	var up: Color = LightGen.encode_normal(Vector3(0.0, -1.0, 0.0))
	check_near(up.g, 1.0, 0.001, "normal facing up the screen has green 1 (Godot 2D, Y+ up)")
	var flat: Color = LightGen.encode_normal(Vector3(0.0, 0.0, 1.0))
	check_eq(Color8(flat.r8, flat.g8, flat.b8), Color8(128, 128, 255), "flat normal = (128,128,255)")
	var n: Vector3 = Vector3(0.3, -0.4, 0.866).normalized()
	check(LightGen.decode_normal(LightGen.encode_normal(n)).is_equal_approx(n), "normal encode/decode round trip")


func _check_entry_scene() -> void:
	check_has(Modules.list_modules(), "light", "menu finds the light module")
	var packed: PackedScene = load(Modules.scene_path("light")) as PackedScene
	if check_not_null(packed, "res://light/light.tscn loads"):
		var state: SceneState = packed.get_state()
		check_eq(state.get_node_count(), 2, "light.tscn = root + instanced light_demo.tscn")
	var capture: Script = load("res://light/capture_light.gd") as Script
	check(capture != null and capture.can_instantiate(), "capture_light.gd parses")


func _check_evening(demo: DemoScript) -> void:
	var evening: CanvasModulate = demo.get_node_or_null("Evening") as CanvasModulate
	if not check_not_null(evening, "Evening CanvasModulate"):
		return
	check(evening.visible, "evening darkness on")
	var c: Color = evening.color
	check(c.r < 0.6 and c.g < 0.6 and c.b < 0.6, "evening darkens (%s)" % c)
	check(c.r >= c.g and c.g >= c.b, "evening is warm, never blue (art brief: warm shadows) %s" % c)
	var total: Color = c + demo.altar_light_color * demo.altar_light_energy
	check_between(LightGen.luma(total), 0.9, 1.15, "evening + altar light ~ painted colours inside the zone")


func _check_altar_light(demo: DemoScript) -> void:
	var light: PointLight2D = demo.altar_light
	check(light.enabled, "altar light on")
	check_eq(light.global_position, LIGHT_CENTRE, "altar light at the centre of the 3x3 lamps, on a whole pixel")
	check_eq(light.texture_scale, 1.0, "light texture_scale 1 (texel = base pixel, dither stays crisp)")
	check_eq(demo.safe_radius_px(), 112, "default safe radius 7 tiles = 112 px")
	check_eq(demo.light_reach_px(), 112.0, "light reach = safe radius")
	check_eq(demo.light_image.get_size(), Vector2i(224, 224), "light image 2R")
	check_eq(light.blend_mode, Light2D.BLEND_MODE_ADD, "additive light")
	check(light.shadow_enabled, "altar light casts shadows")
	check_eq(light.shadow_filter, Light2D.SHADOW_FILTER_NONE, "hard pixel shadows")
	check(light.height > 0.0, "light height set for normal maps")
	check_eq(demo.edge_mode, LightGen.Edge.DITHER, "default edge = dither")
	var lantern: PointLight2D = demo.lantern
	check(lantern.get_parent() == demo.hero_outside, "lantern carried by the hero outside the zone")
	check(lantern.texture != null and lantern.enabled, "lantern on")
	check(not lantern.shadow_enabled, "lantern without shadows")


## The picture and the rule share one number: in hard mode a texel is lit exactly when
## is_in_safe_zone() says its pixel centre is inside.
func _check_safe_zone_rule(demo: DemoScript) -> void:
	check(demo.is_in_safe_zone(LIGHT_CENTRE), "centre is safe")
	check(demo.is_in_safe_zone(LIGHT_CENTRE + Vector2(112, 0)), "radius is safe")
	check(not demo.is_in_safe_zone(LIGHT_CENTRE + Vector2(112.5, 0)), "past the radius is not safe")
	demo.edge_mode = LightGen.Edge.HARD
	demo.apply_settings()
	var img: Image = demo.light_image
	var origin: Vector2 = LIGHT_CENTRE - Vector2(112, 112)
	var mismatches: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var lit: bool = img.get_pixel(x, y).a > 0.5
			if lit != demo.is_in_safe_zone(origin + Vector2(float(x) + 0.5, float(y) + 0.5)):
				mismatches += 1
	check_eq(mismatches, 0, "hard light texels == is_in_safe_zone()")
	demo.edge_mode = LightGen.Edge.DITHER
	demo.apply_settings()
	var dither: Image = demo.light_image
	var outside_lit: int = 0
	for y: int in dither.get_height():
		for x: int in dither.get_width():
			if dither.get_pixel(x, y).a > 0.5 and not demo.is_in_safe_zone(origin + Vector2(float(x) + 0.5, float(y) + 0.5)):
				outside_lit += 1
	check_eq(outside_lit, 0, "dither never lights outside the safe zone")
	var actor: Image = demo.actor_light_image
	var actor_mismatches: int = 0
	for y: int in actor.get_height():
		for x: int in actor.get_width():
			if (actor.get_pixel(x, y).a > 0.5) != demo.is_in_safe_zone(origin + Vector2(float(x) + 0.5, float(y) + 0.5)):
				actor_mismatches += 1
	check_eq(actor_mismatches, 0, "actor light (hard edge, dither mode) texels == is_in_safe_zone()")


## Characters are on light layer 2 and get their own hard-edged altar light, so the dithered
## ground edge does not draw a checkerboard on them.
func _check_actor_light_split(demo: DemoScript) -> void:
	var actor_light: PointLight2D = demo.altar_light_actors
	if not check_not_null(actor_light, "AltarLightActors"):
		return
	check(demo.actor_light_split, "actor light split on by default")
	check_eq(actor_light.global_position, demo.altar_light.global_position, "actor light shares the altar light centre")
	check(actor_light.enabled, "actor light on")
	check_eq(actor_light.range_item_cull_mask, DemoScript.LIGHT_LAYER_ACTORS, "actor light reaches only layer 2")
	check_eq(demo.altar_light.range_item_cull_mask, DemoScript.LIGHT_LAYER_WORLD, "world light reaches only layer 1")
	check_eq(actor_light.texture.get_size(), demo.altar_light.texture.get_size(), "actor light has the same reach")
	check_eq(actor_light.texture_scale, 1.0, "actor light texture_scale 1")
	check(actor_light.shadow_enabled, "actor light casts the wall shadow on characters too")
	check((demo.occluder.occluder_light_mask & actor_light.shadow_item_cull_mask) != 0, "actor light sees the occluder")
	var alphas: Dictionary = {}
	for y: int in demo.actor_light_image.get_height():
		for x: int in demo.actor_light_image.get_width():
			alphas[demo.actor_light_image.get_pixel(x, y).a8] = true
	check_eq(alphas.size(), 2, "actor light texture is hard (on/off only)")
	for item: CanvasItem in [demo.hero_inside, demo.hero_outside, demo.walker]:
		check_eq(item.light_mask, DemoScript.LIGHT_LAYER_ACTORS, "%s on light layer 2" % item.name)
	for item: CanvasItem in [demo.ground, demo.altar, demo.wall]:
		check_eq(item.light_mask, DemoScript.LIGHT_LAYER_WORLD, "%s on light layer 1" % item.name)
	check_eq(demo.lantern.range_item_cull_mask, DemoScript.LIGHT_LAYER_WORLD | DemoScript.LIGHT_LAYER_ACTORS,
		"lantern lights both layers")
	demo.actor_light_split = false
	demo.apply_settings()
	check(not actor_light.enabled, "split off: actor light off")
	check_eq(demo.altar_light.range_item_cull_mask, DemoScript.LIGHT_LAYER_WORLD | DemoScript.LIGHT_LAYER_ACTORS,
		"split off: world light reaches characters")
	demo.actor_light_split = true
	demo.apply_settings()
	check(actor_light.enabled and demo.altar_light.range_item_cull_mask == DemoScript.LIGHT_LAYER_WORLD, "split on again")


func _check_flames(demo: DemoScript) -> void:
	var mat: CanvasItemMaterial = demo.flames.material as CanvasItemMaterial
	if check_not_null(mat, "flames have a CanvasItemMaterial"):
		check_eq(mat.light_mode, CanvasItemMaterial.LIGHT_MODE_UNSHADED, "flames unshaded (ignore evening and lights)")
	check(demo.flames.get_parent() == demo.altar, "flames drawn with the altar")
	check_eq(demo.flames.offset, demo.altar.offset, "flame overlay aligned to the altar art")
	var flame: Image = demo.flame_image
	check_eq(LightGen.count_opaque(flame), 81, "9 lamps x 9 flame pixels")
	var brightest: float = 0.0
	var min_flame: float = 999.0
	var lit: Image = demo.altar_lit_image
	for y: int in lit.get_height():
		for x: int in lit.get_width():
			if lit.get_pixel(x, y).a > 0.5:
				brightest = maxf(brightest, LightGen.luma(lit.get_pixel(x, y)) * 255.0)
			if flame.get_pixel(x, y).a > 0.5:
				min_flame = minf(min_flame, LightGen.luma(flame.get_pixel(x, y)) * 255.0)
	var core: float = 0.0
	for y: int in flame.get_height():
		for x: int in flame.get_width():
			if flame.get_pixel(x, y).a > 0.5:
				core = maxf(core, LightGen.luma(flame.get_pixel(x, y)) * 255.0)
	check_near(core, brightest, 0.01, "the brightest pixel of the altar art is a flame pixel")
	check_near(core, 246.0, 1.0, "flame core luma 246 (art brief §5.7)")
	check(min_flame >= DemoScript.FLAME_MIN_LUMA, "flame mask keeps only bright pixels")
	demo.flame_mode = DemoScript.FlameMode.SHADED
	demo.apply_settings()
	check(demo.flames.material == null, "shaded flame mode removes the material")
	demo.flame_mode = DemoScript.FlameMode.UNSHADED
	demo.apply_settings()


func _check_normal_maps(demo: DemoScript) -> void:
	var ct: CanvasTexture = demo.altar.texture as CanvasTexture
	if not check_not_null(ct, "altar uses a CanvasTexture"):
		return
	check(ct.normal_texture != null, "altar CanvasTexture has a normal map")
	check(ct.diffuse_texture == DemoScript.ALTAR_LIT, "altar diffuse = altar_v04.png")
	var nm: Image = demo.altar_normal_image
	check_eq(nm.get_size(), demo.altar_lit_image.get_size(), "normal map size = altar size")
	# altar art: opaque x 0..46, top face rows 5..39, front face rows 40..46
	check(LightGen.decode_normal(nm.get_pixel(0, 20)).x < -0.2, "west rim faces west")
	check(LightGen.decode_normal(nm.get_pixel(46, 20)).x > 0.2, "east rim faces east")
	check(LightGen.decode_normal(nm.get_pixel(24, 5)).y < -0.2, "north rim faces north")
	check(LightGen.decode_normal(nm.get_pixel(24, 43)).y > 0.5, "front face faces south")
	var z_sum: float = 0.0
	var n: int = 0
	for y: int in range(10, 36):
		for x: int in range(6, 41):
			z_sum += LightGen.decode_normal(nm.get_pixel(x, y)).z
			n += 1
	check(z_sum / float(n) > 0.85, "top face mostly faces the viewer (mean z %.2f)" % (z_sum / float(n)))
	var wall_ct: CanvasTexture = demo.wall.texture as CanvasTexture
	check(wall_ct != null and wall_ct.normal_texture != null, "wall block normal-mapped too")
	demo.normal_maps_enabled = false
	demo.apply_settings()
	check(demo.altar.texture == DemoScript.ALTAR_LIT, "normals off = plain texture")
	demo.normal_maps_enabled = true
	demo.apply_settings()
	check(demo.altar.texture == ct, "normals on = CanvasTexture again")


func _check_occluder(demo: DemoScript) -> void:
	var occ: LightOccluder2D = demo.occluder
	if not check_not_null(occ.occluder, "wall has an OccluderPolygon2D"):
		return
	var poly: PackedVector2Array = occ.occluder.polygon
	check_eq(poly.size(), 4, "occluder = wall footprint rectangle")
	var bounds: Rect2 = Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		bounds = bounds.expand(p)
	check_eq(bounds, Rect2(-16, -16, 32, 16), "occluder covers the front-face rows (ground footprint)")
	check_eq(occ.occluder.cull_mode, OccluderPolygon2D.CULL_COUNTER_CLOCKWISE,
		"CCW cull: the wall itself stays lit, only the ground behind is shadowed")
	check((occ.occluder_light_mask & demo.altar_light.shadow_item_cull_mask) != 0, "altar light sees the occluder")
	check(demo.is_in_safe_zone(demo.wall.global_position), "wall stands inside the light")


func _check_scene_layout(demo: DemoScript) -> void:
	check(demo.world.y_sort_enabled, "world layer is y-sorted")
	var ground: TileMapLayer = demo.ground
	check_eq(ground.tile_set.tile_size, Vector2i(16, 16), "16 px tiles")
	check(ground.get_used_rect().encloses(Rect2i(0, 0, 30, 17)), "grass covers the 480x270 view")
	for hero: Sprite2D in [demo.hero_inside, demo.hero_outside, demo.walker]:
		check_eq(hero.texture.get_size(), Vector2(192, 96), "%s uses the walk sheet" % hero.name)
		check_eq(Vector2i(hero.hframes, hero.vframes), Vector2i(6, 3), "%s: 6 frames x 3 directions" % hero.name)
	check(demo.is_in_safe_zone(demo.hero_inside.global_position), "HeroInside is inside")
	check(not demo.is_in_safe_zone(demo.hero_outside.global_position), "HeroOutside is outside")
	var d: float = demo.walker.global_position.distance_to(LIGHT_CENTRE)
	check_between(d, 96.0, 112.0, "walker starts on the dithered edge")


func _check_radius_change(demo: DemoScript) -> void:
	demo.safe_radius_tiles = 5.0
	demo.apply_settings()
	check_eq(demo.light_reach_px(), 80.0, "radius 5 tiles -> light reach 80 px")
	check_eq(demo.altar_light_actors.texture.get_size(), Vector2(160, 160), "actor light follows the radius")
	check(demo.is_in_safe_zone(LIGHT_CENTRE + Vector2(0, 80)), "rule follows the radius (inside)")
	check(not demo.is_in_safe_zone(LIGHT_CENTRE + Vector2(0, 81)), "rule follows the radius (outside)")
	demo.safe_radius_tiles = 7.0
	demo.apply_settings()
	check_eq(demo.light_reach_px(), 112.0, "radius back to 7 tiles")

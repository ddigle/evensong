extends "res://tests/base_test.gd"
## Light: the safe-zone rule = the light textures (every texel of the hard actor light equals
## SafeZone.is_in_safe_zone(), the dithered ground light never lights a texel outside it and fully
## lights the inner disc), light nodes (position, scale, masks, cached textures that never change),
## light layers of ground / altar / characters, the altar art on its footprint, unshaded flames
## (mask = 81 pixels of the lit art), evening on / off.
##
## What the screen shows is checked separately in a window (tools/check_render.gd, README).


func run() -> Array[String]:
	_check_rule()
	_check_hard_texture()
	_check_dither_texture()
	_check_flame_mask()
	await _check_world_nodes()
	return failures


func _default_zone() -> SafeZone:
	return SafeZone.for_world(SurfaceGen.generate(Config.DEFAULT_SEED))


func _check_rule() -> void:
	var zone: SafeZone = _default_zone()
	check_eq(zone.center, Vector2(1016, 760), "zone centre = altar centre (whole pixel)")
	check_eq(zone.radius, float(Config.SAFE_RADIUS_TILES * Config.TILE), "zone radius = SAFE_RADIUS_TILES")
	check(zone.is_in_safe_zone(zone.center), "centre is safe")
	check(zone.is_in_safe_zone(zone.center + Vector2(0, -zone.radius)), "radius is inclusive")
	check(not zone.is_in_safe_zone(zone.center + Vector2(0, -zone.radius - 0.001)), "outside the radius is not safe")
	check(not SafeZone.new(Vector2.ZERO, 0.0).is_in_safe_zone(Vector2.ZERO), "an empty zone is never safe")
	var no_altar: WorldData = WorldData.new(Vector2i(8, 8))
	check_eq(SafeZone.for_world(no_altar).radius, 0.0, "no altar -> empty zone")


func _alpha_at(img: Image, x: int, y: int) -> int:
	return img.get_pixel(x, y).a8


## Hard texture: every texel = the rule at its centre.
func _check_hard_texture() -> void:
	var zone: SafeZone = _default_zone()
	var t0: int = Time.get_ticks_usec()
	var img: Image = LightGen.zone_light_image(zone, LightGen.Edge.HARD, 0)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	var size: int = LightGen.texture_size(zone)
	check_eq(size, 2 * (Config.SAFE_RADIUS_TILES * Config.TILE + 1), "texture size")
	check_eq(img.get_size(), Vector2i(size, size), "hard image size")
	var origin: Vector2i = LightGen.texture_origin(zone)
	check_eq(Vector2(origin + Vector2i(size, size) / 2), zone.center, "texture centred on the zone centre")
	var mismatches: int = 0
	var lit: int = 0
	var partial: int = 0
	var data: PackedByteArray = img.get_data()
	for y: int in size:
		for x: int in size:
			var a: int = data[(y * size + x) * 4 + 3]
			if a != 0 and a != 255:
				partial += 1
			var inside: bool = zone.is_in_safe_zone(Vector2(origin + Vector2i(x, y)) + Vector2(0.5, 0.5))
			if inside != (a == 255):
				mismatches += 1
			if a == 255:
				lit += 1
	check_eq(mismatches, 0, "hard light: every one of %d texels = is_in_safe_zone()" % (size * size))
	check_eq(partial, 0, "hard light alpha is 0 or 255")
	check_between(float(lit), PI * zone.radius * zone.radius * 0.98, PI * zone.radius * zone.radius * 1.02, "lit area ~ pi r^2")
	# Border ring empty.
	var border_lit: int = 0
	for i: int in size:
		border_lit += int(_alpha_at(img, i, 0) > 0) + int(_alpha_at(img, i, size - 1) > 0)
		border_lit += int(_alpha_at(img, 0, i) > 0) + int(_alpha_at(img, size - 1, i) > 0)
	check_eq(border_lit, 0, "texture border ring is dark")
	note("light image %dx%d built in %.1f ms (GDScript, once per zone)" % [size, size, ms])


## Dither texture: lit texels are a subset of the zone; the inner disc is fully lit; the band
## (radius - SAFE_EDGE_BAND_PX .. radius) is a 0/255 pattern that thins out towards the radius.
func _check_dither_texture() -> void:
	var zone: SafeZone = _default_zone()
	var img: Image = LightGen.zone_light_image(zone, LightGen.Edge.DITHER, Config.SAFE_EDGE_BAND_PX)
	var size: int = LightGen.texture_size(zone)
	var origin: Vector2i = LightGen.texture_origin(zone)
	var inner: float = zone.radius - Config.SAFE_EDGE_BAND_PX
	var outside_lit: int = 0
	var inner_dark: int = 0
	var partial: int = 0
	var band_in: Array[int] = [0, 0]   # lit, total in the inner half of the band
	var band_out: Array[int] = [0, 0]  # lit, total in the outer half
	var data: PackedByteArray = img.get_data()
	for y: int in size:
		for x: int in size:
			var a: int = data[(y * size + x) * 4 + 3]
			if a != 0 and a != 255:
				partial += 1
			var p: Vector2 = Vector2(origin + Vector2i(x, y)) + Vector2(0.5, 0.5)
			var d: float = p.distance_to(zone.center)
			if not zone.is_in_safe_zone(p):
				outside_lit += int(a > 0)
			elif d <= inner:
				inner_dark += int(a == 0)
			elif d <= inner + Config.SAFE_EDGE_BAND_PX / 2.0:
				band_in[0] += int(a > 0)
				band_in[1] += 1
			else:
				band_out[0] += int(a > 0)
				band_out[1] += 1
	check_eq(outside_lit, 0, "dither light: no lit texel outside the safe zone")
	check_eq(inner_dark, 0, "dither light: inner disc fully lit")
	check_eq(partial, 0, "dither alpha is 0 or 255 (pixel-art edge)")
	var f_in: float = float(band_in[0]) / maxf(1.0, band_in[1])
	var f_out: float = float(band_out[0]) / maxf(1.0, band_out[1])
	check(f_in > f_out, "band thins out towards the radius (%.2f -> %.2f)" % [f_in, f_out])
	check_between(f_in, 0.5, 1.0, "inner half of the band mostly lit")
	check_between(f_out, 0.0, 0.5, "outer half of the band mostly dark")
	# Dither pattern is anchored to world pixels (same texel for the same world pixel).
	var px: Vector2i = Vector2i(roundi(zone.center.x) + 100, roundi(zone.center.y) + 30)
	check_eq(LightGen.light_at(zone, LightGen.Edge.DITHER, Config.SAFE_EDGE_BAND_PX, px),
		1.0 if _alpha_at(img, px.x - origin.x, px.y - origin.y) == 255 else 0.0, "light_at = texel")
	note("dither band: %.0f%% lit in the inner half, %.0f%% in the outer half" % [f_in * 100.0, f_out * 100.0])


func _check_flame_mask() -> void:
	var lit: Image = LightGen.to_rgba8(Altar.LIT.get_image())
	var unlit: Image = LightGen.to_rgba8(Altar.UNLIT.get_image())
	var mask: Image = Altar.flame_image()
	check_eq(mask.get_size(), Vector2i(48, 57), "flame mask covers the altar art")
	check_eq(LightGen.count_opaque(mask), 81, "flame mask = 81 pixels (9 lamps x 9)")
	var wrong: int = 0
	for y: int in mask.get_height():
		for x: int in mask.get_width():
			var m: Color = mask.get_pixel(x, y)
			if m.a8 == 0:
				continue
			var a: Color = lit.get_pixel(x, y)
			var b: Color = unlit.get_pixel(x, y)
			if m != a or a == b or LightGen.luma8(a) < Config.FLAME_MIN_LUMA:
				wrong += 1
	check_eq(wrong, 0, "every flame pixel = the lit art colour, differs from unlit, bright")
	check(Altar.flame_image() == mask, "flame mask cached")
	check(Altar.flame_texture() == Altar.flame_texture(), "flame texture cached")


func _check_world_nodes() -> void:
	var packed: PackedScene = load("res://scenes/world.tscn") as PackedScene
	var world: GameWorld = packed.instantiate() as GameWorld
	world.auto_generate = false
	add_node(world)
	await await_frames(1)
	world.generate(Config.DEFAULT_SEED)
	var zone: SafeZone = world.safe_zone
	var light: AltarLight = world.lighting.altar_light
	check_eq(light.global_position, zone.center, "altar light at the zone centre")
	for l: PointLight2D in [light.ground_light, light.actor_light]:
		check_eq(l.texture_scale, 1.0, "%s texture_scale 1 (texel = pixel)" % l.name)
		check_eq(l.global_position, zone.center, "%s at the zone centre" % l.name)
		check(is_equal_approx(l.energy, Config.ALTAR_LIGHT_ENERGY), "%s energy" % l.name)
		check_eq(l.color, Config.ALTAR_LIGHT_COLOR, "%s colour" % l.name)
		check_eq(l.blend_mode, Light2D.BLEND_MODE_ADD, "%s adds light" % l.name)
		check(not l.shadow_enabled, "%s casts no shadow (M1)" % l.name)
		check(l.enabled, "%s on" % l.name)
	check_eq(light.ground_light.range_item_cull_mask, Config.LIGHT_LAYER_WORLD, "ground light lights the world layer only")
	check_eq(light.actor_light.range_item_cull_mask, Config.LIGHT_LAYER_ACTORS, "actor light lights characters only")
	var ground_tex: ImageTexture = light.ground_light.texture as ImageTexture
	var actor_tex: ImageTexture = light.actor_light.texture as ImageTexture
	check(ground_tex == AltarLight.texture_for(zone, LightGen.Edge.DITHER, Config.SAFE_EDGE_BAND_PX), "ground light uses the cached dither texture")
	check(actor_tex == AltarLight.texture_for(zone, LightGen.Edge.HARD, 0), "actor light uses the cached hard texture")
	check(ground_tex.get_image().get_data() == LightGen.zone_light_image(zone, LightGen.Edge.DITHER, Config.SAFE_EDGE_BAND_PX).get_data(),
		"ground light texture = the dither image of the zone")
	check(actor_tex.get_image().get_data() == LightGen.zone_light_image(zone, LightGen.Edge.HARD, 0).get_data(),
		"actor light texture = the hard image of the zone")
	# Regenerating the same world and toggling the evening never swaps or rebuilds a texture.
	var count: int = AltarLight.cached_texture_count()
	world.generate(Config.DEFAULT_SEED)
	world.lighting.set_evening(false)
	world.lighting.set_evening(true)
	check(light.ground_light.texture == ground_tex and light.actor_light.texture == actor_tex, "textures kept across regenerate / toggle")
	check_eq(AltarLight.cached_texture_count(), count, "no new light textures")
	# A different seed moves nothing here (the altar is always at the map centre), so the same
	# textures are reused; a smaller map moves the zone and adds one cached pair.
	world.generate(Config.DEFAULT_SEED, Vector2i(64, 48))
	check_eq(AltarLight.cached_texture_count(), count + 2, "a new zone adds its two textures once")
	check_eq(world.lighting.altar_light.global_position, world.safe_zone.center, "light follows the new zone")
	world.generate(Config.DEFAULT_SEED)
	check(light.ground_light.texture == ground_tex, "back to the first zone: the first texture again")
	check_eq(AltarLight.cached_texture_count(), count + 2, "still no rebuild")

	# Evening.
	var evening: CanvasModulate = world.lighting.evening
	check_eq(evening.color, Config.EVENING_COLOR, "evening colour")
	check(evening.visible and world.lighting.evening_on, "evening on after generate")
	world.lighting.set_evening(false)
	check(not evening.visible and not light.ground_light.enabled and not light.actor_light.enabled, "evening off = no darkness, no light")
	world.lighting.set_evening(true)
	check(evening.visible and light.is_lit(), "evening back on")

	# Light layers: ground chunks + altar = world, characters = actors.
	for key: Vector2i in world.ground.chunk_keys():
		if world.ground.chunk_layer(key).light_mask != Config.LIGHT_LAYER_WORLD:
			fail("ground chunk %s light_mask" % key)
	checks += 1
	var altar: Altar = world.altar
	check_eq(altar.sprite.light_mask, Config.LIGHT_LAYER_WORLD, "altar on the world light layer")
	var c: Character = Character.new()
	c.class_id = "cleric"
	world.entities.add_child(c)
	var sprites: int = 0
	for node: Node in c.rig.get_children():
		var s: Sprite2D = node as Sprite2D
		check_eq(s.light_mask, Config.LIGHT_LAYER_ACTORS, "character sprite %s on the actor light layer" % s.name)
		sprites += 1
	check_eq(sprites, 5, "body + 4 slot sprites")

	# Altar on its footprint.
	var fp: Rect2i = Rect2i(world.data.altar_rect.position * Config.TILE, world.data.altar_rect.size * Config.TILE)
	check_eq(altar.art_origin(), fp.position, "altar art top-left on the footprint top-left")
	check_eq(Vector2i(altar.sprite.global_position), fp.position, "altar sprite placed there")
	check_eq(altar.global_position, Vector2(fp.get_center().x, fp.end.y), "altar node at the footprint bottom centre (y-sort)")
	var art: Image = LightGen.to_rgba8(Altar.LIT.get_image())
	var used: Rect2i = art.get_used_rect()
	check_eq(fp.position.y + used.end.y, fp.end.y, "art's bottom row on the footprint's last pixel row")
	check(Rect2i(fp.position, Vector2i(48, 48)).encloses(Rect2i(fp.position + used.position, used.size)), "opaque art inside the footprint")
	# Flames: unshaded, on top of the altar sprite at the same origin.
	var mat: CanvasItemMaterial = altar.flames.material as CanvasItemMaterial
	check(mat != null and mat.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "flames are unshaded")
	check(altar.flames.get_parent() == altar.sprite and altar.flames.position == Vector2.ZERO, "flames drawn over the altar art")
	check(altar.flames.texture == Altar.flame_texture(), "flames use the cached mask texture")

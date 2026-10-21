class_name LightGen
extends RefCounted
## Image generators for the altar light (static, no state; all run headless so tests can check
## the exact texels the renderer gets).
##
## - zone_light_image(): PointLight2D texture of a SafeZone at texture_scale 1 (one texel = one
##   world pixel). Every texel asks SafeZone.is_in_safe_zone() at its centre: outside -> 0. Inside,
##   HARD is fully lit; DITHER is fully lit up to radius - band and then fades out with a 4x4 Bayer
##   pattern anchored to world pixels, so the lit texels are always a subset of the safe zone.
##   One empty texel ring around the disc keeps the texture border dark.
## - emissive_mask(): flame pixels = pixels that differ between lit and unlit art and are bright.

enum Edge { HARD, DITHER }

## 4x4 Bayer matrix (row-major). Threshold for cell i is (BAYER4[i] + 0.5) / 16.
const BAYER4: PackedInt32Array = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


static func bayer_threshold(x: int, y: int) -> float:
	return (float(BAYER4[posmod(y, 4) * 4 + posmod(x, 4)]) + 0.5) / 16.0


## Texture size in texels for a zone: 2 * (ceil(radius) + 1), even, centred on the zone centre.
static func texture_size(zone: SafeZone) -> int:
	return 2 * (ceili(zone.radius) + 1)


## World pixel covered by texel (0, 0) (the zone centre must be a whole pixel).
static func texture_origin(zone: SafeZone) -> Vector2i:
	var half: int = texture_size(zone) / 2
	return Vector2i(roundi(zone.center.x), roundi(zone.center.y)) - Vector2i(half, half)


## Light amount (0 or 1) of the world pixel `px` (its centre is tested).
static func light_at(zone: SafeZone, edge: Edge, band: int, px: Vector2i) -> float:
	var p: Vector2 = Vector2(px) + Vector2(0.5, 0.5)
	if not zone.is_in_safe_zone(p):
		return 0.0
	if edge == Edge.HARD or band <= 0:
		return 1.0
	var d: float = p.distance_to(zone.center)
	var inner: float = zone.radius - float(band)
	if d <= inner:
		return 1.0
	var t: float = (zone.radius - d) / float(band)  # 1 at the inner edge of the band, 0 at the radius
	return 1.0 if t > bayer_threshold(px.x, px.y) else 0.0


## White RGB, alpha = light amount (Godot adds light.rgb * light.a * energy).
static func zone_light_image(zone: SafeZone, edge: Edge, band: int) -> Image:
	var size: int = texture_size(zone)
	var origin: Vector2i = texture_origin(zone)
	var data: PackedByteArray = PackedByteArray()
	data.resize(size * size * 4)
	var i: int = 0
	for y: int in size:
		for x: int in size:
			var a: int = 255 if light_at(zone, edge, band, origin + Vector2i(x, y)) > 0.5 else 0
			data[i] = 255
			data[i + 1] = 255
			data[i + 2] = 255
			data[i + 3] = a
			i += 4
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)


static func luma8(c: Color) -> float:
	return 0.299 * c.r8 + 0.587 * c.g8 + 0.114 * c.b8


static func to_rgba8(img: Image) -> Image:
	var out: Image = img.duplicate() as Image
	if out.is_compressed():
		out.decompress()
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	return out


## Pixels opaque in both images that differ and are at least `min_luma` bright (0-255) in `lit`,
## with their lit colours; everything else transparent.
static func emissive_mask(lit: Image, unlit: Image, min_luma: float) -> Image:
	var a: Image = to_rgba8(lit)
	var b: Image = to_rgba8(unlit)
	var w: int = a.get_width()
	var h: int = a.get_height()
	var out: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	if b.get_width() != w or b.get_height() != h:
		push_error("LightGen.emissive_mask: size mismatch %s vs %s" % [a.get_size(), b.get_size()])
		return out
	for y: int in h:
		for x: int in w:
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if ca.a8 < 128 or cb.a8 < 128 or ca.to_rgba32() == cb.to_rgba32():
				continue
			if luma8(ca) >= min_luma:
				out.set_pixel(x, y, ca)
	return out


static func count_opaque(img: Image) -> int:
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a8 >= 128:
				n += 1
	return n

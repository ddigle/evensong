extends RefCounted
## Image generators for the light spike (static helpers, no state). All of it runs headless,
## so tests can check the exact pixels the renderer will get.
##
## - safe_zone_light_image(): PointLight2D texture whose edge is the altar's safe-zone radius,
##   with a hard, ordered-dither, banded or smooth edge (texture_scale 1 = one texel per base pixel)
## - emissive_mask(): flame pixels = pixels that differ between the lit and the unlit altar art
##   and are bright (drawn again on top with an unshaded material so the evening never darkens them)
## - normal_map(): normal map from alpha (edge bevel) + luminance (mortar lines) + a front-face row
##   for low top-down objects, for CanvasTexture.normal_texture
## - wall_block_image(): one 2x1-tile stone block (top face + front face) in the altar's palette

enum Edge { HARD, DITHER, BANDED, SMOOTH }

const EDGE_NAMES: PackedStringArray = ["hard", "dither", "banded", "smooth"]

## 4x4 Bayer matrix (row-major). Threshold for cell i is (BAYER4[i] + 0.5) / 16.
const BAYER4: PackedInt32Array = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## Light amounts of the BANDED edge, outer band last.
const BAND_LEVELS: PackedFloat32Array = [0.6, 0.3]

## Outline colour of the project's pixel art (concept-art-brief §5.7).
const OUTLINE: Color = Color8(26, 23, 20)


static func edge_from_name(edge_name: String) -> int:
	var i: int = EDGE_NAMES.find(edge_name)
	return i if i >= 0 else Edge.DITHER


static func bayer_threshold(x: int, y: int) -> float:
	return (float(BAYER4[posmod(y, 4) * 4 + posmod(x, 4)]) + 0.5) / 16.0


## Light amount (0..1) at distance `d` from the centre. `band` is the edge width in pixels.
## (wx, wy) are world pixel coordinates, used by the dither so overlapping lights share a pattern.
static func light_amount(d: float, radius: float, edge: int, band: float, wx: int, wy: int) -> float:
	if d > radius:
		return 0.0
	var inner: float = radius - band
	if d <= inner or band <= 0.0:
		return 1.0
	var t: float = (radius - d) / band  # 1 at the inner edge of the band, 0 at the radius
	match edge:
		Edge.HARD:
			return 1.0
		Edge.DITHER:
			return 1.0 if t > bayer_threshold(wx, wy) else 0.0
		Edge.BANDED:
			var steps: int = BAND_LEVELS.size()
			var k: int = clampi(int(floor((1.0 - t) * float(steps))), 0, steps - 1)
			return BAND_LEVELS[k]
		_:  # SMOOTH
			return smoothstep(0.0, 1.0, t)


## (2*radius)^2 texture for a PointLight2D with texture_scale 1.0 centred on a whole pixel:
## texel (x, y) covers world pixel (origin.x + x, origin.y + y) where origin = light position - radius.
## White RGB, alpha = light amount (Godot adds light.rgb * light.a).
static func safe_zone_light_image(radius: int, edge: int, band: int, origin: Vector2i = Vector2i.ZERO) -> Image:
	var size: int = radius * 2
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var r: float = float(radius)
	for y: int in size:
		for x: int in size:
			var dx: float = float(x) + 0.5 - r
			var dy: float = float(y) + 0.5 - r
			var a: float = light_amount(sqrt(dx * dx + dy * dy), r, edge, float(band), origin.x + x, origin.y + y)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return img


static func luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


static func to_rgba8(img: Image) -> Image:
	var out: Image = img.duplicate() as Image
	if out.is_compressed():
		out.decompress()
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	return out


## Pixels that are opaque in both images, differ, and are at least `min_luma` bright in `lit`.
## Returns an image of the same size with only those pixels (lit colours), the rest transparent.
static func emissive_mask(lit: Image, unlit: Image, min_luma: float) -> Image:
	var a: Image = to_rgba8(lit)
	var b: Image = to_rgba8(unlit)
	var w: int = a.get_width()
	var h: int = a.get_height()
	var out: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	if b.get_width() != w or b.get_height() != h:
		push_error("emissive_mask: size mismatch")
		return out
	for y: int in h:
		for x: int in w:
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if ca.a < 0.5 or cb.a < 0.5:
				continue
			if ca.to_rgba32() == cb.to_rgba32():
				continue
			if luma(ca) * 255.0 >= min_luma:
				out.set_pixel(x, y, ca)
	return out


static func count_opaque(img: Image) -> int:
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a >= 0.5:
				n += 1
	return n


## Encodes a unit normal (x right, y DOWN the screen, z towards the viewer) the way Godot's 2D
## shader decodes it: green high = facing up the screen (OpenGL style, Y+ up).
static func encode_normal(n: Vector3) -> Color:
	return Color(n.x * 0.5 + 0.5, 0.5 - n.y * 0.5, n.z * 0.5 + 0.5, 1.0)


static func decode_normal(c: Color) -> Vector3:
	return Vector3(c.r * 2.0 - 1.0, 1.0 - c.g * 2.0, c.b * 2.0 - 1.0)


## Normal map for a low top-down sprite.
## - height = distance to the nearest transparent pixel (capped at `bevel` px), so silhouettes get a
##   rounded edge, plus `detail` x luminance so dark mortar lines/cracks read as grooves
## - rows >= `front_face_top` (the vertical front face of a 3/4 object) face south (towards the
##   viewer's feet): normal (gx, 1, front_z), -1 disables it
static func normal_map(diffuse: Image, bevel: float = 2.0, detail: float = 1.0, strength: float = 1.0,
		front_face_top: int = -1, front_z: float = 0.6) -> Image:
	var src: Image = to_rgba8(diffuse)
	var w: int = src.get_width()
	var h: int = src.get_height()
	var height: PackedFloat32Array = PackedFloat32Array()
	height.resize(w * h)
	var reach: int = int(ceil(bevel))
	for y: int in h:
		for x: int in w:
			var c: Color = src.get_pixel(x, y)
			if c.a < 0.5:
				height[y * w + x] = 0.0
				continue
			var best: float = bevel
			for oy: int in range(-reach, reach + 1):
				for ox: int in range(-reach, reach + 1):
					var d: float = sqrt(float(ox * ox + oy * oy))
					if d >= best:
						continue
					var sx: int = x + ox
					var sy: int = y + oy
					if sx < 0 or sy < 0 or sx >= w or sy >= h or src.get_pixel(sx, sy).a < 0.5:
						best = d
			height[y * w + x] = best / bevel + detail * (luma(c) - 0.5)
	var out: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			if src.get_pixel(x, y).a < 0.5:
				out.set_pixel(x, y, encode_normal(Vector3(0.0, 0.0, 1.0)))
				continue
			# Sobel gradient, scaled so a ramp of 1 per pixel gives 1
			var gx: float = 0.0
			var gy: float = 0.0
			for o: int in range(-1, 2):
				var wgt: float = 2.0 if o == 0 else 1.0
				gx += wgt * (_h(height, w, h, x + 1, y + o) - _h(height, w, h, x - 1, y + o))
				gy += wgt * (_h(height, w, h, x + o, y + 1) - _h(height, w, h, x + o, y - 1))
			gx /= 8.0
			gy /= 8.0
			var n: Vector3
			if front_face_top >= 0 and y >= front_face_top:
				n = Vector3(-gx * strength, 1.0, front_z).normalized()
			else:
				n = Vector3(-gx * strength, -gy * strength, 1.0).normalized()
			out.set_pixel(x, y, encode_normal(n))
	return out


## Height at (x, y); outside the image counts as transparent (height 0), like the bevel.
static func _h(height: PackedFloat32Array, w: int, h: int, x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= w or y >= h:
		return 0.0
	return height[y * w + x]


## 32x32 stone block: top face rows 0-15, front face rows 16-31, outline #1a1714.
## Colours are taken from altar_v04 so it sits in the same palette.
static func wall_block_image() -> Image:
	var top_hi: Color = Color8(157, 145, 127)
	var top: Color = Color8(143, 130, 114)
	var top_lo: Color = Color8(125, 112, 95)
	var seam: Color = Color8(107, 94, 79)
	var face_hi: Color = Color8(90, 80, 71)
	var face: Color = Color8(74, 66, 58)
	var face_lo: Color = Color8(61, 54, 48)
	var mortar: Color = Color8(46, 42, 38)
	var img: Image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			var c: Color
			if x == 0 or x == 31 or y == 0 or y == 31:
				c = OUTLINE
			elif y < 16:
				c = top
				if y <= 2:
					c = top_hi
				elif y >= 14:
					c = top_lo
				if (x == 15 and y > 2 and y < 14) or (y == 8 and x > 15 and x < 31) or (y == 6 and x > 0 and x < 15):
					c = seam
			else:
				c = face
				if y == 16:
					c = face_hi
				elif y == 30:
					c = face_lo
				var course: int = (y - 17) / 5
				if (y - 17) % 5 == 4 and y < 30:
					c = mortar
				elif y > 16 and y < 30 and posmod(x + course * 5, 10) == 0:
					c = mortar
			img.set_pixel(x, y, c)
	return img

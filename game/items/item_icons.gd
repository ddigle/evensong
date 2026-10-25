class_name ItemIcons
extends RefCounted
## Inventory icons. Items with art load their PNG (art/items/, 04-env candidates). Tools (and, M3a, the
## torch, drawn as a small lit lantern like the ground lantern it is placed as; M4a, the cleric's holy
## light, a gold sunburst; M6a, the alchemy table) have no icon art
## anywhere in assets/ yet, so their icons are PROVISIONAL placeholders drawn here from 16x16
## character maps (README "임시값"): the brief §4 palette's ash black outline and faith golds, the
## warm iron greys and copper of the 04-env items, no cool greys. Replace them when tool icons exist.
## M7a (PLACEHOLDERS too): a tier-1 weapon's icon is its base weapon's map with a small gold tier mark at the top left
## (TIER_MARK); the armour piece has a map of its own; the stations and the storage chest are their placed 04-env picture
## shrunk to fit 16x16 (fit_icon: the opaque box scaled down by a whole-pixel nearest step, centred on the bottom).

const SIZE: int = 16
## Map characters -> colour (brief §4 base / faith rows, 04-env iron and copper item colours).
const PALETTE: Dictionary[String, Color] = {
	"k": Color8(0x1a, 0x17, 0x14),  # outline (§4 base)
	"d": Color8(0x6f, 0x55, 0x22),  # wood dark (§4 faith)
	"w": Color8(0x9c, 0x6a, 0x1f),  # wood (§4 faith)
	"l": Color8(0xc9, 0x93, 0x2b),  # wood light (§4 faith)
	"m": Color8(0xa3, 0x9d, 0x92),  # iron (04-env iron)
	"h": Color8(0xd2, 0xcb, 0xb8),  # iron light (04-env iron)
	"g": Color8(0xf4, 0xc9, 0x5d),  # gold (§4 faith)
	"o": Color8(0x8c, 0x4a, 0x22),  # copper dark (04-env copper)
	"c": Color8(0xc0, 0x6a, 0x2e),  # copper (04-env copper)
	"C": Color8(0xdf, 0x90, 0x3f),  # copper light (04-env copper)
	"s": Color8(0xef, 0xe3, 0xc6),  # bow string (§4 faith ivory)
	# M6a: the potion colours (● brief §5.7 R29: healing red, buff amber / orange, poison = the poison herb's
	# yellow with rust spots; the "지금 그림" values there: buff #e0861a, rust #c4421c, poison #d5ce40, #a5a132).
	"r": Color8(0xb8, 0x2e, 0x24),  # healing red
	"a": Color8(0xe0, 0x86, 0x1a),  # buff amber
	"y": Color8(0xd5, 0xce, 0x40),  # poison yellow
	"Y": Color8(0xa5, 0xa1, 0x32),  # poison yellow dark
	"u": Color8(0xc4, 0x42, 0x1c),  # rust spot
}

## Plain Arrays on purpose: in Godot 4.7.2 a const Dictionary[..., PackedStringArray] built from
## array literals reads back garbage (24 empty strings) and crashed image_from_map (measured, M2a).
const MAPS: Dictionary[StringName, Array] = {
	&"pickaxe": [
		"................",
		"....kkkkkk......",
		"...khhhhmmkk....",
		"..kmkkkkkdmmk...",
		"..kk....kdkkmk..",
		".......kdwk.kmk.",
		"......kdwk...kk.",
		".....kdwk.......",
		"....kdwk........",
		"...kdwk.........",
		"..kdwk..........",
		".kdwk...........",
		".kwk............",
		"..k.............",
		"................",
		"................",
	],
	&"hoe": [
		"................",
		"..........kkk...",
		".........kdwk...",
		"........kdwkkkkk",
		".......kdwkkmhhk",
		"......kdwk.kmhmk",
		".....kdwk..kmhmk",
		"....kdwk...kkkkk",
		"...kdwk.........",
		"..kdwk..........",
		".kdwk...........",
		"kdwk............",
		"kwk.............",
		".k..............",
		"................",
		"................",
	],
	&"sickle": [
		"................",
		"......kkkk......",
		"....kkhhhhkk....",
		"...khmkkkkmhk...",
		"..kmk....kkmhk..",
		"..kk.......kmk..",
		"...........kmk..",
		"..........kmhk..",
		".....kk..kmhk...",
		"....kdk.kmhk....",
		"...kdwkkhmk.....",
		"..kdwk.kkk......",
		".kdwk...........",
		".kwk............",
		"..k.............",
		"................",
	],
	&"watering_can": [
		"................",
		"................",
		"....kkkkk.......",
		"...kk...kk......",
		"..kk.....kk..kkk",
		".kkkkkkkkkk..kCk",
		".kCCCCCCCok..kck",
		".kCccccccok.kck.",
		".kcccccccokkck..",
		".kcccccccocck...",
		".kcccccccokk....",
		".kcccccccok.....",
		".kooooooook.....",
		"..kkkkkkkk......",
		"................",
		"................",
	],
	&"sword": [
		"................",
		"............kkk.",
		"...........khhk.",
		"..........khmhk.",
		".........khmhk..",
		"........khmhk...",
		".......khmhk....",
		"...kk.khmhk.....",
		"...kgkkmhk......",
		"....kgkmk.......",
		"....kdkgk.......",
		"...kdwkkgk......",
		"..kdwk..kk......",
		".kggk...........",
		".kkk............",
		"................",
	],
	&"torch": [
		"................",
		"......kkkk......",
		".....kggggk.....",
		"....kgkkkkgk....",
		"....kkllllkk....",
		"....kglggggk....",
		"....kgggllgk....",
		"....kgllgggk....",
		"....kkggggkk....",
		"....kgkkkkgk....",
		".....kmmmmk.....",
		"....kkkkkkkk....",
		"....kmhhhhmk....",
		"....kkkkkkkk....",
		"................",
		"................",
	],
	&"bow": [
		"................",
		".....kkk........",
		".....kdwkk......",
		"......kkwlk.....",
		"......ks.kwk....",
		"......ks..kwk...",
		"......ks...kwk..",
		"......ks...kwk..",
		"......ks...kwk..",
		"......ks...kwk..",
		"......ks..kwk...",
		"......ks.kwk....",
		"......kkkwlk....",
		".....kdwkk......",
		".....kkk........",
		"................",
	],
	# M4a: the cleric's holy light (the magic action's bolt): a small gold sunburst, ivory core.
	&"holy_light": [
		"................",
		".......kk.......",
		".......kgk......",
		"..kk...kgk...kk.",
		"..kgkk.kgk.kkgk.",
		"...kgkkkgkkkgk..",
		"....kkgllgkkk...",
		".kkkkglssslgkkk.",
		"kggggllsssllgggk",
		".kkkkglssslgkkk.",
		"....kkglllgkk...",
		"...kgkkkgkkkgk..",
		"..kgkk.kgk.kkgk.",
		"..kk...kgk...kk.",
		".......kgk......",
		".......kk.......",
	],
	# M6a: the alchemy table (no item art; the placed table is 04-env alchemy_table_v05): a small wooden table
	# with the three potions on it (red, amber, yellow with a rust spot).
	&"alchemy_table": [
		"................",
		"................",
		"..kk...kk...kk..",
		".krrk.kaak.kyyk.",
		".krrk.kaak.kyyk.",
		".krrk.kaak.kyuk.",
		"kkkkkkkkkkkkkkkk",
		"kllllllllllllllk",
		"kwwwwwwwwwwwwwwk",
		"kkkkkkkkkkkkkkkk",
		".kdk........kdk.",
		".kdk........kdk.",
		".kdk........kdk.",
		".kdk........kdk.",
		".kkk........kkk.",
		"................",
	],
	# M7a: the tier-1 armour (a banded iron shirt with gold shoulders and a copper hem; no armour art exists).
	&"armor_t1": [
		"................",
		"....kk....kk....",
		"...kggk..kggk...",
		"..kmhgkkkkghmk..",
		".kmhhhmggmhhhmk.",
		".kkkkkkkkkkkkkk.",
		"..kmhhhhhhhhmk..",
		"..kkkkkkkkkkkk..",
		"...kmhhchhhmk...",
		"...kkkkkkkkkk...",
		"...kmhhchhhmk...",
		"...kkkkkkkkkk...",
		"...kocococock...",
		"...kkkkkkkkkk...",
		"................",
		"................",
	],
}
## M7a: the tier mark drawn over a tier-1 weapon's base icon (top left, 3x3, gold with an ash-black edge).
const TIER_MARK: Array = ["kgk", "ggg", "kgk"]

static var _cache: Dictionary[StringName, Texture2D] = {}


## Icon of an item (null for unknown items or a missing file).
static func texture_for(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var def: ItemDB.ItemDef = ItemDB.get_def(id)
	var tex: Texture2D = null
	if def != null:
		if not def.icon_code.is_empty():
			var img: Image = image_from_map(def.icon_code)
			if img != null:
				if def.tier >= 1 and not def.base.is_empty():
					_mark_tier(img)  # M7a: a tier-1 weapon = its base weapon's icon + the tier mark
				tex = ImageTexture.create_from_image(img)
		elif def.icon_fit and ResourceLoader.exists(def.icon_path):
			tex = ImageTexture.create_from_image(fit_icon(LightGen.to_rgba8((load(def.icon_path) as Texture2D).get_image())))
		elif ResourceLoader.exists(def.icon_path):
			tex = load(def.icon_path) as Texture2D
			if tex != null and def.icon_region.has_area():
				# M6a: an icon cut from a strip (the potions, ItemDB.STRIP_POTIONS) becomes its own 16x16 image.
				var strip: Image = LightGen.to_rgba8(tex.get_image())
				tex = ImageTexture.create_from_image(strip.get_region(def.icon_region))
	_cache[id] = tex
	return tex


## The 16x16 RGBA image of a code-drawn icon, or null.
static func image_from_map(code: StringName) -> Image:
	if not MAPS.has(code):
		return null
	var rows: Array = MAPS[code]
	var img: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var height: int = mini(rows.size(), SIZE)
	for y: int in height:
		var row: String = rows[y]
		var width: int = mini(row.length(), SIZE)
		for x: int in width:
			var ch: String = row[x]
			if PALETTE.has(ch):
				img.set_pixel(x, y, PALETTE[ch])
	return img


## M7a: draws TIER_MARK at the top left of `img`.
static func _mark_tier(img: Image) -> void:
	for y: int in TIER_MARK.size():
		var row: String = TIER_MARK[y]
		for x: int in row.length():
			if PALETTE.has(row[x]):
				img.set_pixel(x, y, PALETTE[row[x]])


## M7a: a 16x16 icon from a placed picture (`src`, RGBA8): its opaque box (alpha >= 128) shrunk by the smallest whole
## step that fits 16x16 (every step-th pixel, nearest; no new colours), centred across and standing on the bottom row.
static func fit_icon(src: Image) -> Image:
	var lo: Vector2i = Vector2i(src.get_width(), src.get_height())
	var hi: Vector2i = Vector2i(-1, -1)
	for y: int in src.get_height():
		for x: int in src.get_width():
			if src.get_pixel(x, y).a8 >= 128:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	var out: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	if hi.x < 0:
		return out
	var box: Vector2i = hi - lo + Vector2i.ONE
	var step: int = maxi(ceili(float(maxi(box.x, box.y)) / SIZE), 1)
	var w: int = ceili(float(box.x) / step)
	var h: int = ceili(float(box.y) / step)
	var at: Vector2i = Vector2i((SIZE - w) / 2, SIZE - h)
	for y: int in h:
		for x: int in w:
			var p: Color = src.get_pixel(lo.x + x * step, lo.y + y * step)
			if p.a8 >= 128:
				out.set_pixel(at.x + x, at.y + y, Color(p.r, p.g, p.b, 1.0))
	return out

class_name ItemIcons
extends RefCounted
## Inventory icons. Items with art load their PNG (art/items/, 04-env candidates). Tools have no
## icon art anywhere in assets/ yet, so their icons are PROVISIONAL placeholders drawn here from 16x16
## character maps (README "임시값"): the brief §4 palette's ash black outline and faith golds, the
## warm iron greys and copper of the 04-env items, no cool greys. Replace them when tool icons exist.

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
}

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
				tex = ImageTexture.create_from_image(img)
		elif ResourceLoader.exists(def.icon_path):
			tex = load(def.icon_path) as Texture2D
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

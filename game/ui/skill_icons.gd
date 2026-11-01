class_name SkillIcons
extends RefCounted
## M9a: the HUD's skill icons (PLACEHOLDERS drawn in code from 12x12 character maps in ItemIcons.PALETTE colours: no skill
## art exists): one per built skill, a dim diamond for a skill that is named but not built yet (M9b: all fifteen are built, the
## diamond stays for a skill without a map), a lock for the choice slot (not in the slice), and the 3x5 "R" glyph for the
## signature key (the HUD's digits draw 1 2 3). Layout values are IMPL.

const SIZE: int = 12
## Plain Arrays (a const Dictionary of PackedStringArray built from literals reads back garbage in 4.7.2, README "규칙").
const MAPS: Dictionary[StringName, Array] = {
	&"taunt": [
		"............",
		"..g..kk..g..",
		"...gkggkg...",
		"....kggk....",
		".g..kggk..g.",
		"....kggk....",
		"....kggk....",
		".....kk.....",
		"............",
		".....kk.....",
		"....kggk....",
		".....kk.....",
	],
	&"piercing_arrow": [
		".........khk",
		"........khhk",
		".......kmhk.",
		"......kwkk..",
		".....kwk....",
		"....kwk.....",
		"...kwk......",
		"..kwk.......",
		".ksk........",
		"kssk........",
		"gsk.........",
		"gg..........",
	],
	&"heal": [
		"............",
		"....kkkk....",
		"....kggk....",
		"....kggk....",
		".kkkkggkkkk.",
		".kgggssgggk.",
		".kgggssgggk.",
		".kkkkggkkkk.",
		"....kggk....",
		"....kggk....",
		"....kkkk....",
		"............",
	],
	&"ground_slam": [
		"............",
		"..kkkkkk....",
		".khhhhmmk...",
		"..kkkdwkk...",
		".....kwk....",
		".....kwk....",
		".....kwk....",
		"..o..kwk..o.",
		"...o.kkk.o..",
		".oo..ooo..oo",
		"cccccccccccc",
		"oooooooooooo",
	],
	&"potion_throw": [
		"......kk....",
		".....kssk...",
		"......kk....",
		".....kkkk...",
		"....krrrrk..",
		"...krrrrrrk.",
		"...krrsrrrk.",
		"...krrrrrrk.",
		"....krrrrk..",
		".....kkkk...",
		"s.s.........",
		".s.s........",
	],
	# M9b: the weapon skills (a sword striking a gold star, three arrows fanning from a bow, a gold-and-ivory burst, a pickaxe
	# striking copper sparks, a sickle's sweep) and the signatures (a gold shield with an ivory cross, arrows falling into an amber
	# ring, an ivory halo round a gold cross, rocks falling into a rust ring, a healing-red cloud).
	&"crushing_blow": [
		".....kk.....",
		"....kddk....",
		"..kgggggggk.",
		"....khmk....",
		"....khmk....",
		"....khmk....",
		"....khmk....",
		".g..khmk..g.",
		"..g.khmk.g..",
		"...g.kk.g...",
		".gggssssggg.",
		"...g.gg.g...",
	],
	&"fan_shot": [
		".k...kk...k.",
		"khk.khhk.khk",
		".w...ww...w.",
		".w...ww...w.",
		"..w..ww..w..",
		"..w..ww..w..",
		"...w.ww.w...",
		"...w.ww.w...",
		"....wwwww...",
		"...kddddk...",
		"..kd....dk..",
		"..ss....ss..",
	],
	&"holy_burst": [
		".....gg.....",
		".g...gg...g.",
		"..g.gssg.g..",
		"...gssssg...",
		"..gssssssg..",
		"ggssssssssgg",
		"ggssssssssgg",
		"..gssssssg..",
		"...gssssg...",
		"..g.gssg.g..",
		".g...gg...g.",
		".....gg.....",
	],
	&"heavy_strike": [
		".kkkkkkkk...",
		"khhhhhmmmk..",
		"kmkkkdkkkmk.",
		"kk..kwk..kk.",
		"....kwk.....",
		"....kwk.....",
		"....kwk.....",
		".C..kwk..C..",
		"..C.kkk.C...",
		".C.C...C.C..",
		"..cCCcCCc...",
		"oooooooooooo",
	],
	&"sweep": [
		"....kkkkk...",
		"..kkhhhhhk..",
		".khh....khk.",
		"khk......kk.",
		"kk......kwk.",
		"s.......kwk.",
		".s......kwk.",
		"..s.....kwk.",
		"...ss...kdk.",
		".....ss.kdk.",
		"........kdk.",
		"........kkk.",
	],
	&"guardian_oath": [
		".kkkkkkkkkk.",
		".kggggggggk.",
		".kgggssgggk.",
		".kgggssgggk.",
		".kgssssssgk.",
		".kgssssssgk.",
		".kgggssgggk.",
		"..kggssggk..",
		"..kggssggk..",
		"...kggggk...",
		"....kggk....",
		".....kk.....",
	],
	&"arrow_rain": [
		"s.s.........",
		".w......s.s.",
		".w..s.s..w..",
		".w...w...w..",
		".h...w...w..",
		".....w...h..",
		".....h......",
		"............",
		"..a..a..a...",
		".aaaaaaaaaa.",
		"a..........a",
		".aaaaaaaaaa.",
	],
	&"blessing": [
		"...ssssss...",
		"..s......s..",
		".s...gg...s.",
		"s....gg....s",
		"s..gggggg..s",
		"s..gggggg..s",
		"s....gg....s",
		"s....gg....s",
		".s...gg...s.",
		"..s......s..",
		"...ssssss...",
		"............",
	],
	&"rockfall": [
		"..kk........",
		".kmhk...kk..",
		".kmmk..kmhk.",
		"..kk...kmmk.",
		".....kk.kk..",
		"....kmhk....",
		"....kmmk....",
		".....kk.....",
		"............",
		".uuuuuuuuuu.",
		"u..........u",
		".uuuuuuuuuu.",
	],
	&"healing_mist": [
		"....rrrr....",
		"..rrssssrr..",
		".rsssrrsssr.",
		"rssssrrssssr",
		"rssrrrrrrssr",
		"rssrrrrrrssr",
		"rssssrrssssr",
		".rsssrrsssr.",
		"..rrssssrr..",
		"....rrrr....",
		".s..s..s..s.",
		"s..s..s..s..",
	],
}
## A named skill not built yet (M9b): a dim iron diamond.
const LATER_MAP: Array = [
	"............",
	".....mm.....",
	"....m..m....",
	"...m....m...",
	"..m......m..",
	".m........m.",
	".m........m.",
	"..m......m..",
	"...m....m...",
	"....m..m....",
	".....mm.....",
	"............",
]
## The choice slot (● R42 "선택 스킬 — 해금 풀", not in the slice count): a lock.
const LOCK_MAP: Array = [
	"............",
	"....kkkk....",
	"...kmkkmk...",
	"...km..mk...",
	"...km..mk...",
	"..kkkkkkkk..",
	"..kmmmmmmk..",
	"..kmmkkmmk..",
	"..kmmkkmmk..",
	"..kmmmmmmk..",
	"..kkkkkkkk..",
	"............",
]
## The signature key's glyph, 3x5 like Hud.DIGITS.
const R_GLYPH: Array = ["110", "101", "110", "101", "101"]

static var _textures: Dictionary[StringName, ImageTexture] = {}


static func image_from(rows: Array) -> Image:
	var img: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in mini(rows.size(), SIZE):
		var row: String = rows[y]
		for x: int in mini(row.length(), SIZE):
			var ch: String = row[x]
			if ItemIcons.PALETTE.has(ch):
				img.set_pixel(x, y, ItemIcons.PALETTE[ch])
	return img


## The map for skill `id` (a built skill's own, else the "later" diamond).
static func map_for(id: StringName) -> Array:
	if MAPS.has(id):
		return MAPS[id]
	return LATER_MAP


static func texture_for(id: StringName) -> ImageTexture:
	if not _textures.has(id):
		_textures[id] = ImageTexture.create_from_image(image_from(map_for(id)))
	return _textures[id]


static func lock_texture() -> ImageTexture:
	if not _textures.has(&"_lock"):
		_textures[&"_lock"] = ImageTexture.create_from_image(image_from(LOCK_MAP))
	return _textures[&"_lock"]

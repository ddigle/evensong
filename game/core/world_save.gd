class_name WorldSave
extends RefCounted
## M13a (● game-concept §2 "영속 월드", §12 R54 "저장"): a whole world as one file, the host's (offline = hosting alone, the same file).
## capture() writes the live world, read() checks a file and gives it back (Saved), the apply_* functions put the saved sim state into
## sims a caller has just set up for the loaded maps (Main.open_world). README "M13a" lists every piece of world state and whether it is
## saved, made again from the seed or reset, with the reason.
##
## The rule of what a load gives: **the saved world as it is the moment all its players leave it** (the game's own "the map emptied" rule,
## Arena.on_emptied, BossFight.on_emptied / reset: heretics stay where they stand but forget their targets, an attack under way stops,
## the shots, thrown bottles, strikes and zones in the air are gone, the spawn timer starts over, an awake boss is back asleep at home
## with its pillars whole and its adds gone). Everything that is not a player and outlives a map emptying is saved: every tile of both maps
## (the snapshot's layers: terrain, walls and their cracks, ore, gatherables and crops, corruption and purified ground, the placeables:
## the altar, stations, chests, trees and stumps, built pieces, doors, lanterns, the merchant, the broken shrine, death bags), the drops
## and the next drop id, the chests' contents, the shop's stock and its clock, the rare zone, the collection (entries and kills), the
## world's progress (the altar's tier, the boss defeated), a sleeping boss's pillar hits, every crop's growth and water left, every tree's
## axe hits and every stump's regrowth time, the heretics (where, home, HP, a poison running), the shrine's HP, the creatures (all of
## them, and the deaths waiting to respawn), every random stream's state (the arenas', the herd's, the boss's), the next ids (heretics,
## creatures, the boss's), the prayers made (the next prayer's directions) and the deaths (the next death bag's draw). Player node ids die
## with the process: every field holding one is cleared at load (a heretic's target, threat, taunt and poisoner, a creature's snare
## holder and poisoner, the boss's threat, a pillar's breaker). A carried altar is written put back where it last stood (the placing
## rules; the live game is not touched): nobody carries anything into a load.
##
## File (README "M13a 파일 형식"; little-endian like the wire):
##   header  "EVSW", u16 FORMAT_VERSION, u16 flags (0), u32 section count
##   section 4 ASCII bytes tag, u32 payload length, payload
##   footer  md5 of every byte before it (16 bytes)
## Sections (version 1: each exactly once, any order; an unknown or missing tag refuses the file):
##   META  i64 seed, i64 saved (unix s), i64 world ticks, u32 deaths, u32 prayers, u16 protocol (diagnostic), u8 n + name
##   ITEM  u16 n + n x (u8 len + id): ItemDB's ids in index order (the maps' stacks are indices): the game's table must start with them
##   MAP0  the surface, MAP1 the dungeon: u8 map id, u32 raw size, 16 B content hash (md5), u32 next drop id, u16 x4 the altar's last
##         footprint, then the map's WorldSnapshot.raw_bytes compressed with zstd (the late-join snapshot's form, its decoder's checks)
##   ARN0  ARN1  a map's arena: u8 1 (0 = none), i64 random state, u32 next id, u32 spawn timer, i32 shrine HP, u16 n heretics + n x
##         HERETIC_BYTES
##   FRM0  FRM1  a map's farm: u8 1, u32 n + n x (u32 tile index, u32 growth ticks in its stage, u32 water left), tile order
##   FOR0  FOR1  a map's forest: u8 1, u32 n + n x (u16 x, u16 y, u16 axe hits), u32 n + n x (u16 x, u16 y, u32 regrowth ticks left)
##   SHOP  u8 1, u32 clock, u32 restocks
##   HERD  u8 1, i64 random state, u32 clock, u32 next id, u16 n + n x creature, u16 n + n x (u8 len + kind, u32 due)
##   BOSS  u8 1, i64 random state, u32 next id, u8 state (0 asleep, 1 awake, 2 dead), u32 clock, u32 state ticks, u8 n + n x (u16 hits,
##         u8 fallen)
## A file that does not read (wrong magic, version, md5, a section or a value out of range, a map whose content hash after decoding is
## not the one saved) is refused whole: read() returns a Saved with `error` and no world (never half a world).

const MAGIC: PackedByteArray = [0x45, 0x56, 0x53, 0x57]
## The file format's version (bumped when a section changes; an older or newer file is refused with both numbers).
const FORMAT_VERSION: int = 1
const HEADER_BYTES: int = 12
const FOOTER_BYTES: int = 16
const SECTION_HEADER: int = 8
const TAGS: PackedStringArray = ["META", "ITEM", "MAP0", "MAP1", "ARN0", "ARN1", "FRM0", "FRM1", "FOR0", "FOR1", "SHOP", "HERD", "BOSS"]
## The maps a world file holds (the slice's two, Config.MAP_SURFACE and MAP_DUNGEON).
const MAPS: Array[int] = [Config.MAP_SURFACE, Config.MAP_DUNGEON]
## IMPL: the most bytes a world file may have (two maps' largest snapshots and their sims fit many times; a bigger file is refused before
## it is read), and the most heretics, creatures and waiting respawns a section may hold.
const MAX_FILE_BYTES: int = 32 * 1024 * 1024
const MAX_ACTORS: int = 4096
const BOSS_ASLEEP: int = 0
const BOSS_AWAKE: int = 1
const BOSS_DEAD: int = 2


## What capture() needs of a running world (Main's offline game; M13b: a session host's).
class Live:
	extends RefCounted
	var name: String = ""
	var maps: Dictionary[int, WorldData] = {}
	## Where each map's altar last stood (GameWorld.last_altar_rect): a carried altar is written put back there.
	var last_altar: Dictionary[int, Rect2i] = {}
	var arenas: Dictionary[int, Arena] = {}
	var farms: Dictionary[int, Farm] = {}
	var forests: Dictionary[int, Forest] = {}
	var prayers: int = 0
	var deaths: int = 0
	var ticks: int = 0


## A heretic as a file keeps it (the fields that outlive a map emptying; the rest is cleared at load).
class HereticRecord:
	extends RefCounted
	var id: int = 0
	var pos: Vector2 = Vector2.ZERO
	var home: Vector2 = Vector2.ZERO
	var facing: int = 0
	var state: int = 0
	var state_ticks: int = 0
	var hp: int = 0
	var cooldown: int = 0
	var stuck: int = 0
	var poison_damage: int = 0
	var poison_ticks: int = 0
	var poison_timer: int = 0
	var lit_out: bool = false
	var clock: int = 0


class ArenaRecord:
	extends RefCounted
	var rng_state: int = 0
	var next_id: int = 1
	var spawn_timer: int = 0
	var shrine_hp: int = 0
	var heretics: Array[HereticRecord] = []


class FarmRecord:
	extends RefCounted
	## Tile index -> (growth ticks in its stage, water ticks left).
	var plots: Dictionary[int, Vector2i] = {}


class ForestRecord:
	extends RefCounted
	var hits: Dictionary[Vector2i, int] = {}
	var regrow: Dictionary[Vector2i, int] = {}


class CreatureRecord:
	extends RefCounted
	var id: int = 0
	var kind: StringName = &""
	var pos: Vector2 = Vector2.ZERO
	var home: Vector2 = Vector2.ZERO
	var facing: int = 0
	var state: int = 0
	var state_ticks: int = 0
	var hp: int = 0
	var target: Vector2 = Vector2.ZERO
	var flee_from: Vector2 = Vector2.ZERO
	var idle_ticks: int = 0
	var walking: bool = false
	var stun_ticks: int = 0
	var slow_pct: int = 0
	var slow_ticks: int = 0
	var poison_damage: int = 0
	var poison_ticks: int = 0
	var poison_timer: int = 0
	var clock: int = 0
	var flash_ticks: int = 0
	var bound: bool = false
	var refused_ticks: int = 0


class HerdRecord:
	extends RefCounted
	var rng_state: int = 0
	var clock: int = 0
	var next_id: int = 1
	var creatures: Array[CreatureRecord] = []
	## [kind (StringName), due (int)] per waiting respawn, in order.
	var waiting: Array[Array] = []


class BossRecord:
	extends RefCounted
	var rng_state: int = 0
	var next_id: int = 1
	var state: int = BOSS_ASLEEP
	var clock: int = 0
	var state_ticks: int = 0
	var hits: PackedInt32Array = PackedInt32Array()
	var fallen: Array[bool] = []


## What read() gives: the world, or `error` (then nothing else is set).
class Saved:
	extends RefCounted
	var error: String = ""
	var name: String = ""
	var world_seed: int = 0
	var saved_unix: int = 0
	var ticks: int = 0
	var deaths: int = 0
	var prayers: int = 0
	var protocol: int = 0
	var maps: Dictionary[int, WorldData] = {}
	var hashes: Dictionary[int, String] = {}
	var last_altar: Dictionary[int, Rect2i] = {}
	var arenas: Dictionary[int, ArenaRecord] = {}
	var farms: Dictionary[int, FarmRecord] = {}
	var forests: Dictionary[int, ForestRecord] = {}
	var has_shop_clock: bool = false
	var shop_clock: int = 0
	var shop_restocks: int = 0
	var herd: HerdRecord = null
	var boss: BossRecord = null
	## Which file it came from (SaveStore.candidates: the file, its .tmp or its .bak; load_from).
	var path: String = ""
	## Why the files tried before it did not read ("" = it was the first: the file itself).
	var skipped: String = ""

	func ok() -> bool:
		return error.is_empty()

	## One line for the log and `--list-worlds`.
	func describe() -> String:
		var surface: WorldData = maps.get(Config.MAP_SURFACE, null)
		var progress: WorldProgress = surface.progress if surface != null else null
		var col: Collection = surface.collection if surface != null else null
		return "seed=%d ticks=%d tier=%d boss=%s collection=%d saved=%s" % [world_seed, ticks,
			progress.altar_tier if progress != null else 0, "defeated" if progress != null and progress.boss_defeated else "alive",
			col.count() if col != null else 0, Time.get_datetime_string_from_unix_time(saved_unix, true)]


## Bounds-checked little-endian reading: a read past the end returns 0 and turns `ok` off (no engine error, no exception).
class Reader:
	extends RefCounted
	var bytes: PackedByteArray
	var at: int = 0
	var ok: bool = true

	func _init(p_bytes: PackedByteArray, p_at: int = 0) -> void:
		bytes = p_bytes
		at = p_at

	func _has(n: int) -> bool:
		if not ok or at < 0 or at + n > bytes.size():
			ok = false
			return false
		return true

	func u8() -> int:
		if not _has(1):
			return 0
		at += 1
		return bytes.decode_u8(at - 1)

	func u16() -> int:
		if not _has(2):
			return 0
		at += 2
		return bytes.decode_u16(at - 2)

	func u32() -> int:
		if not _has(4):
			return 0
		at += 4
		return bytes.decode_u32(at - 4)

	func s32() -> int:
		if not _has(4):
			return 0
		at += 4
		return bytes.decode_s32(at - 4)

	func s64() -> int:
		if not _has(8):
			return 0
		at += 8
		return bytes.decode_s64(at - 8)

	## A float that must be finite (NaN or infinity turns `ok` off).
	func f64() -> float:
		if not _has(8):
			return 0.0
		at += 8
		var v: float = bytes.decode_double(at - 8)
		if not is_finite(v):
			ok = false
			return 0.0
		return v

	func vec() -> Vector2:
		var x: float = f64()
		var y: float = f64()
		return Vector2(x, y)

	func take(n: int) -> PackedByteArray:
		if n < 0 or not _has(n):
			return PackedByteArray()
		at += n
		return bytes.slice(at - n, at)

	## u8 length + that many ASCII bytes (a byte outside 0x20..0x7e turns `ok` off).
	func text() -> String:
		var n: int = u8()
		var raw: PackedByteArray = take(n)
		for b: int in raw:
			if b < 0x20 or b > 0x7e:
				ok = false
				return ""
		return raw.get_string_from_ascii() if ok else ""

	func done() -> bool:
		return ok and at == bytes.size()


## Little-endian writing onto the end of `bytes`.
class Writer:
	extends RefCounted
	var bytes: PackedByteArray = PackedByteArray()

	func _grow(n: int) -> int:
		var at: int = bytes.size()
		bytes.resize(at + n)
		return at

	func u8(v: int) -> void:
		bytes.encode_u8(_grow(1), clampi(v, 0, 0xFF))

	func u16(v: int) -> void:
		bytes.encode_u16(_grow(2), clampi(v, 0, 0xFFFF))

	func u32(v: int) -> void:
		bytes.encode_u32(_grow(4), clampi(v, 0, 0xFFFFFFFF))

	func s32(v: int) -> void:
		bytes.encode_s32(_grow(4), clampi(v, -0x80000000, 0x7FFFFFFF))

	func s64(v: int) -> void:
		bytes.encode_s64(_grow(8), v)

	func f64(v: float) -> void:
		bytes.encode_double(_grow(8), v)

	func vec(v: Vector2) -> void:
		f64(v.x)
		f64(v.y)

	func text(s: String) -> void:
		var raw: PackedByteArray = s.to_ascii_buffer()
		u8(mini(raw.size(), 255))
		bytes.append_array(raw.slice(0, mini(raw.size(), 255)))

	func put(b: PackedByteArray) -> void:
		bytes.append_array(b)


# --- writing -------------------------------------------------------------------------------------------------------

## The file of world `live` now (the class comment's form). Reads the live world, never changes it.
static func capture(live: Live) -> PackedByteArray:
	var sections: Dictionary[String, PackedByteArray] = {}
	var surface: WorldData = live.maps.get(Config.MAP_SURFACE, null)
	var meta: Writer = Writer.new()
	meta.s64(surface.world_seed if surface != null else 0)
	meta.s64(int(Time.get_unix_time_from_system()))
	meta.s64(live.ticks)
	meta.u32(live.deaths)
	meta.u32(live.prayers)
	meta.u16(NetProtocol.VERSION)
	meta.text(live.name)
	sections["META"] = meta.bytes
	var items: Writer = Writer.new()
	var ids: Array[StringName] = ItemDB.ids()
	items.u16(ids.size())
	for id: StringName in ids:
		items.text(String(id))
	sections["ITEM"] = items.bytes
	for m: int in MAPS:
		var data: WorldData = live.maps.get(m, null)
		var last: Rect2i = live.last_altar.get(m, Rect2i())
		sections["MAP%d" % m] = _map_bytes(data, last)
		var arena: Arena = live.arenas.get(m, null)
		sections["ARN%d" % m] = _arena_bytes(arena)
		var farm: Farm = live.farms.get(m, null)
		sections["FRM%d" % m] = _farm_bytes(farm)
		var forest: Forest = live.forests.get(m, null)
		sections["FOR%d" % m] = _forest_bytes(forest)
	var shop: Writer = Writer.new()
	if surface != null and surface.shop != null:
		shop.u8(1)
		shop.u32(surface.shop.clock)
		shop.u32(surface.shop.restocks)
	else:
		shop.u8(0)
	sections["SHOP"] = shop.bytes
	var surface_arena: Arena = live.arenas.get(Config.MAP_SURFACE, null)
	sections["HERD"] = _herd_bytes(surface_arena.herd if surface_arena != null else null)
	var dungeon_arena: Arena = live.arenas.get(Config.MAP_DUNGEON, null)
	sections["BOSS"] = _boss_bytes(dungeon_arena.boss if dungeon_arena != null else null)
	var out: Writer = Writer.new()
	out.put(MAGIC)
	out.u16(FORMAT_VERSION)
	out.u16(0)
	out.u32(TAGS.size())
	for tag: String in TAGS:
		out.put(tag.to_ascii_buffer())
		out.u32(sections[tag].size())
		out.put(sections[tag])
	out.put(WorldSnapshot.md5(out.bytes))
	return out.bytes


## A map's section: its snapshot bytes as the file keeps them (a carried altar put back on a copy), its content hash, its next drop id
## and where its altar last stood. A missing map: map id 255 and nothing more (refused at load: a world file holds both).
static func _map_bytes(data: WorldData, last: Rect2i) -> PackedByteArray:
	var w: Writer = Writer.new()
	if data == null:
		w.u8(255)
		return w.bytes
	var raw: PackedByteArray = WorldSnapshot.raw_bytes(data)
	var hash: String = data.content_hash()
	if data.map_id == Config.MAP_SURFACE and not data.altar_rect.has_area() and last.has_area():
		var copy: WorldData = WorldSnapshot.decode_raw(raw)
		if copy != null:
			var none: Array[Vector2] = []
			var rect: Rect2i = AltarMove.set_down_fallback(copy, Arena.spawn_feet(last.get_center()), last, none, none, true)
			if rect.has_area():
				for e: EditLog.WorldEdit in AltarMove.place_edits(rect):
					EditLog.apply_to_data(copy, e)
				raw = WorldSnapshot.raw_bytes(copy)
				hash = copy.content_hash()
				last = rect
	w.u8(data.map_id)
	w.u32(raw.size())
	w.put(hash.hex_decode())
	w.u32(data.drop_serial)
	for v: int in [last.position.x, last.position.y, last.size.x, last.size.y]:
		w.u16(v)
	var packed: PackedByteArray = raw.compress(WorldSnapshot.COMPRESSION)
	w.u32(packed.size())
	w.put(packed)
	return w.bytes


static func _arena_bytes(a: Arena) -> PackedByteArray:
	var w: Writer = Writer.new()
	if a == null:
		w.u8(0)
		return w.bytes
	w.u8(1)
	w.s64(a.rng.state)
	w.u32(a.next_id)
	w.u32(a.spawn_timer)
	w.s32(a.shrine_hp)
	# An awake boss resets at load (the map emptying's rule): the adds it called leave with that reset, so they are not written.
	var adds: Array[int] = []
	if a.boss != null and a.boss.sim != null and a.boss.sim.awake():
		adds = a.boss.sim.adds
	var kept: Array[HereticSim] = []
	for h: HereticSim in a.heretics:
		if not adds.has(h.id):
			kept.append(h)
	w.u16(mini(kept.size(), MAX_ACTORS))
	for i: int in mini(kept.size(), MAX_ACTORS):
		var h: HereticSim = kept[i]
		w.u32(h.id)
		w.vec(h.pos)
		w.vec(h.home)
		w.u8(h.facing)
		w.u8(h.state)
		w.u32(h.state_ticks)
		w.s32(h.hp)
		w.u32(h.cooldown)
		w.u32(h.stuck)
		w.u32(h.poison_damage)
		w.u32(h.poison_ticks)
		w.u32(h.poison_timer)
		w.u8(1 if h.lit_out else 0)
		w.u32(h.clock)
	return w.bytes


static func _farm_bytes(f: Farm) -> PackedByteArray:
	var w: Writer = Writer.new()
	if f == null:
		w.u8(0)
		return w.bytes
	w.u8(1)
	var keys: Array[int] = []
	keys.assign(f.plots.keys())
	keys.sort()
	w.u32(keys.size())
	for i: int in keys:
		w.u32(i)
		w.u32(f.plots[i].progress)
		w.u32(f.plots[i].water_left)
	return w.bytes


static func _sorted_cells(d: Dictionary[Vector2i, int]) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	keys.assign(d.keys())
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return keys


static func _forest_bytes(f: Forest) -> PackedByteArray:
	var w: Writer = Writer.new()
	if f == null:
		w.u8(0)
		return w.bytes
	w.u8(1)
	var hit_cells: Array[Vector2i] = _sorted_cells(f.hits)
	w.u32(hit_cells.size())
	for c: Vector2i in hit_cells:
		w.u16(c.x)
		w.u16(c.y)
		w.u16(f.hits[c])
	var stumps: Array[Vector2i] = _sorted_cells(f.regrow)
	w.u32(stumps.size())
	for c: Vector2i in stumps:
		w.u16(c.x)
		w.u16(c.y)
		w.u32(f.regrow[c])
	return w.bytes


static func _herd_bytes(h: Creatures) -> PackedByteArray:
	var w: Writer = Writer.new()
	if h == null:
		w.u8(0)
		return w.bytes
	w.u8(1)
	w.s64(h.rng.state)
	w.u32(h.clock)
	w.u32(h.next_id)
	var n: int = mini(h.list.size(), MAX_ACTORS)
	w.u16(n)
	for i: int in n:
		var c: CreatureSim = h.list[i]
		w.u32(c.id)
		w.text(String(c.kind))
		w.vec(c.pos)
		w.vec(c.home)
		w.u8(c.facing)
		w.u8(c.state)
		w.u32(c.state_ticks)
		w.s32(c.hp)
		w.vec(c.target)
		w.vec(c.flee_from)
		w.u32(c.idle_ticks)
		w.u8(1 if c.walking else 0)
		w.u32(c.stun_ticks)
		w.u8(c.slow_pct)
		w.u32(c.slow_ticks)
		w.u32(c.poison_damage)
		w.u32(c.poison_ticks)
		w.u32(c.poison_timer)
		w.u32(c.clock)
		w.u8(c.flash_ticks)
		w.u8(1 if c.bound else 0)
		w.u8(c.refused_ticks)
	var waits: int = mini(h.waiting.size(), MAX_ACTORS)
	w.u16(waits)
	for i: int in waits:
		w.text(String(h.waiting[i].kind))
		w.u32(h.waiting[i].due)
	return w.bytes


static func _boss_bytes(f: BossFight) -> PackedByteArray:
	var w: Writer = Writer.new()
	if f == null or f.sim == null:
		w.u8(0)
		return w.bytes
	w.u8(1)
	w.s64(f.rng.state)
	w.u32(f.next_id)
	var state: int = BOSS_DEAD if f.sim.state == BossSim.State.DEAD else (BOSS_AWAKE if f.sim.awake() else BOSS_ASLEEP)
	w.u8(state)
	w.u32(f.sim.clock)
	w.u32(f.sim.state_ticks)
	var n: int = mini(f.pillars.size(), NetProtocol.PILLARS_MAX)
	w.u8(n)
	for i: int in n:
		w.u16(f.pillars[i].hits)
		w.u8(1 if f.pillars[i].fallen else 0)
	return w.bytes


# --- reading -------------------------------------------------------------------------------------------------------

static func _refused(why: String) -> Saved:
	var s: Saved = Saved.new()
	s.error = why
	return s


## The world in file bytes `bytes`, or a Saved with `error` (the class comment's checks; nothing half made).
static func read(bytes: PackedByteArray) -> Saved:
	if bytes.size() < HEADER_BYTES + FOOTER_BYTES:
		return _refused("not a world file (%d bytes)" % bytes.size())
	if bytes.slice(0, 4) != MAGIC:
		return _refused("not a world file (no EVSW mark)")
	var version: int = bytes.decode_u16(4)
	if version != FORMAT_VERSION:
		return _refused("world file format %d, this game reads %d" % [version, FORMAT_VERSION])
	var body: PackedByteArray = bytes.slice(0, bytes.size() - FOOTER_BYTES)
	if WorldSnapshot.md5(body) != bytes.slice(bytes.size() - FOOTER_BYTES):
		return _refused("damaged (its checksum does not match: cut short or changed)")
	var r: Reader = Reader.new(body, 6)
	var flags: int = r.u16()
	var count: int = r.u32()
	if flags != 0 or count != TAGS.size():
		return _refused("%d sections (flags %d), version %d has %d" % [count, flags, FORMAT_VERSION, TAGS.size()])
	var sections: Dictionary[String, PackedByteArray] = {}
	for i: int in count:
		var tag_bytes: PackedByteArray = r.take(4)
		var n: int = r.u32()
		var payload: PackedByteArray = r.take(n)
		if not r.ok:
			return _refused("section %d is cut short" % i)
		var tag: String = tag_bytes.get_string_from_ascii() if _ascii(tag_bytes) else "?"
		if not TAGS.has(tag) or sections.has(tag):
			return _refused("unknown or repeated section '%s'" % tag)
		sections[tag] = payload
	if not r.done():
		return _refused("bytes after the last section")
	var s: Saved = Saved.new()
	var why: String = _read_meta(sections["META"], s)
	if why.is_empty():
		why = _read_items(sections["ITEM"])
	for m: int in MAPS:
		if why.is_empty():
			why = _read_map(sections["MAP%d" % m], m, s)
	for m: int in MAPS:
		if why.is_empty():
			why = _read_arena(sections["ARN%d" % m], m, s)
		if why.is_empty():
			why = _read_farm(sections["FRM%d" % m], m, s)
		if why.is_empty():
			why = _read_forest(sections["FOR%d" % m], m, s)
	if why.is_empty():
		why = _read_shop(sections["SHOP"], s)
	if why.is_empty():
		why = _read_herd(sections["HERD"], s)
	if why.is_empty():
		why = _read_boss(sections["BOSS"], s)
	if not why.is_empty():
		return _refused(why)
	return s


static func _ascii(b: PackedByteArray) -> bool:
	for v: int in b:
		if v < 0x20 or v > 0x7e:
			return false
	return true


static func _read_meta(bytes: PackedByteArray, s: Saved) -> String:
	var r: Reader = Reader.new(bytes)
	s.world_seed = r.s64()
	s.saved_unix = r.s64()
	s.ticks = r.s64()
	s.deaths = r.u32()
	s.prayers = r.u32()
	s.protocol = r.u16()
	s.name = r.text()
	if not r.done() or s.ticks < 0:
		return "META is not one"
	return ""


static func _read_items(bytes: PackedByteArray) -> String:
	var r: Reader = Reader.new(bytes)
	var n: int = r.u16()
	var ids: Array[StringName] = ItemDB.ids()
	if n > ids.size():
		return "saved with %d item kinds, this game knows %d" % [n, ids.size()]
	for i: int in n:
		var id: String = r.text()
		if r.ok and StringName(id) != ids[i]:
			return "item %d is '%s' in the file, '%s' in this game (the item table changed)" % [i, id, ids[i]]
	if not r.done():
		return "ITEM is not one"
	return ""


static func _read_map(bytes: PackedByteArray, m: int, s: Saved) -> String:
	var r: Reader = Reader.new(bytes)
	var map_id: int = r.u8()
	var raw_size: int = r.u32()
	var hash: String = r.take(16).hex_encode()
	var serial: int = r.u32()
	var last: Rect2i = Rect2i(r.u16(), r.u16(), r.u16(), r.u16())
	var packed_size: int = r.u32()
	var packed: PackedByteArray = r.take(packed_size)
	if not r.done() or map_id != m:
		return "map %d's section is not one" % m
	var data: WorldData = WorldSnapshot.unpack(packed, raw_size)
	if data == null or data.map_id != m:
		return "map %s does not decode" % Config.MAP_NAMES[m]
	if data.content_hash() != hash:
		return "map %s decodes to another world (hash %s, saved %s)" % [Config.MAP_NAMES[m], data.content_hash(), hash]
	if serial < 1 or serial > 0x7FFFFFFF:
		return "map %s's next drop id %d" % [Config.MAP_NAMES[m], serial]
	if last.has_area() and not Rect2i(Vector2i.ZERO, data.size).encloses(last):
		return "map %s's last altar place lies off the map" % Config.MAP_NAMES[m]
	data.drop_serial = serial
	data.boss_site = null  # the boss fight comes from the seed and BOSS (apply_boss), not from the snapshot's site
	if data.collection != null:
		data.collection.take_fresh()  # decoding registers every entry as new: nothing new happened (no log line, no benefit line)
	if data.world_seed != s.world_seed:
		return "map %s has seed %d, the world %d" % [Config.MAP_NAMES[m], data.world_seed, s.world_seed]
	s.maps[m] = data
	s.hashes[m] = hash
	s.last_altar[m] = last
	return ""


## Whether `p` is inside map `data` (px) with a little slack (feet may sit on the edge).
static func _on_map(p: Vector2, data: WorldData) -> bool:
	var size: Vector2 = Vector2(data.size * Config.TILE)
	return p.x >= 0.0 and p.y >= 0.0 and p.x <= size.x and p.y <= size.y


static func _read_arena(bytes: PackedByteArray, m: int, s: Saved) -> String:
	var r: Reader = Reader.new(bytes)
	var has: int = r.u8()
	if has == 0:
		return "" if r.done() else "arena %d is not one" % m
	var data: WorldData = s.maps[m]
	var a: ArenaRecord = ArenaRecord.new()
	a.rng_state = r.s64()
	a.next_id = r.u32()
	a.spawn_timer = r.u32()
	a.shrine_hp = r.s32()
	var n: int = r.u16()
	if has != 1 or a.shrine_hp < 0 or a.shrine_hp > Config.SHRINE_HP or a.next_id < 1 or n > MAX_ACTORS:
		return "arena %d's numbers are out of range" % m
	var ids: Dictionary[int, bool] = {}
	for i: int in n:
		var h: HereticRecord = HereticRecord.new()
		h.id = r.u32()
		h.pos = r.vec()
		h.home = r.vec()
		h.facing = r.u8()
		h.state = r.u8()
		h.state_ticks = r.u32()
		h.hp = r.s32()
		h.cooldown = r.u32()
		h.stuck = r.u32()
		h.poison_damage = r.u32()
		h.poison_ticks = r.u32()
		h.poison_timer = r.u32()
		var lit: int = r.u8()
		h.clock = r.u32()
		h.lit_out = lit == 1
		if not r.ok or h.id < 1 or h.id >= a.next_id or ids.has(h.id) or not _on_map(h.pos, data) or not _on_map(h.home, data) \
				or h.facing > RigData.Dir.WEST or h.state >= HereticSim.STATE_NAMES.size() or h.hp < 0 or h.hp > 0xFFFF or lit > 1 \
				or h.state_ticks > 0x7FFFFFFF or h.cooldown > 0x7FFFFFFF or h.poison_ticks > 0x7FFFFFFF:
			return "arena %d's heretic %d is not one" % [m, i]
		ids[h.id] = true
		a.heretics.append(h)
	if not r.done():
		return "arena %d is not one" % m
	s.arenas[m] = a
	return ""


static func _read_farm(bytes: PackedByteArray, m: int, s: Saved) -> String:
	var r: Reader = Reader.new(bytes)
	var has: int = r.u8()
	if has == 0:
		return "" if r.done() else "farm %d is not one" % m
	var cells: int = s.maps[m].size.x * s.maps[m].size.y
	var n: int = r.u32()
	if has != 1 or n > cells:
		return "farm %d is not one" % m
	var f: FarmRecord = FarmRecord.new()
	var last: int = -1
	for i: int in n:
		var index: int = r.u32()
		var progress: int = r.u32()
		var water: int = r.u32()
		if not r.ok or index <= last or index >= cells or progress > 0x7FFFFFFF or water > 0x7FFFFFFF:
			return "farm %d's plot %d is not one" % [m, i]
		last = index
		f.plots[index] = Vector2i(progress, water)
	if not r.done():
		return "farm %d is not one" % m
	s.farms[m] = f
	return ""


static func _read_forest(bytes: PackedByteArray, m: int, s: Saved) -> String:
	var r: Reader = Reader.new(bytes)
	var has: int = r.u8()
	if has == 0:
		return "" if r.done() else "forest %d is not one" % m
	var data: WorldData = s.maps[m]
	var f: ForestRecord = ForestRecord.new()
	var n: int = r.u32()
	if has != 1 or n > data.size.x * data.size.y:
		return "forest %d is not one" % m
	for i: int in n:
		var c: Vector2i = Vector2i(r.u16(), r.u16())
		var hits: int = r.u16()
		if not r.ok or not data.in_bounds(c) or f.hits.has(c):
			return "forest %d's tree %d is not one" % [m, i]
		f.hits[c] = hits
	var k: int = r.u32()
	if k > data.size.x * data.size.y:
		return "forest %d is not one" % m
	for i: int in k:
		var c: Vector2i = Vector2i(r.u16(), r.u16())
		var left: int = r.u32()
		if not r.ok or not data.in_bounds(c) or f.regrow.has(c) or left > 0x7FFFFFFF:
			return "forest %d's stump %d is not one" % [m, i]
		f.regrow[c] = left
	if not r.done():
		return "forest %d is not one" % m
	s.forests[m] = f
	return ""


static func _read_shop(bytes: PackedByteArray, s: Saved) -> String:
	var r: Reader = Reader.new(bytes)
	var has: int = r.u8()
	if has == 1:
		s.has_shop_clock = true
		s.shop_clock = r.u32()
		s.shop_restocks = r.u32()
	if has > 1 or not r.done() or s.shop_clock > 0x7FFFFFFF or s.shop_restocks > 0x7FFFFFFF:
		return "SHOP is not one"
	return ""


static func _read_herd(bytes: PackedByteArray, s: Saved) -> String:
	var r: Reader = Reader.new(bytes)
	var has: int = r.u8()
	if has == 0:
		return "" if r.done() else "HERD is not one"
	var data: WorldData = s.maps[Config.MAP_SURFACE]
	var h: HerdRecord = HerdRecord.new()
	h.rng_state = r.s64()
	h.clock = r.u32()
	h.next_id = r.u32()
	var n: int = r.u16()
	if has != 1 or h.next_id < 1 or h.next_id > NetProtocol.CREATURE_ID_MAX or n > MAX_ACTORS or h.clock > 0x7FFFFFFF:
		return "HERD's numbers are out of range"
	var ids: Dictionary[int, bool] = {}
	for i: int in n:
		var c: CreatureRecord = CreatureRecord.new()
		c.id = r.u32()
		c.kind = StringName(r.text())
		c.pos = r.vec()
		c.home = r.vec()
		c.facing = r.u8()
		c.state = r.u8()
		c.state_ticks = r.u32()
		c.hp = r.s32()
		c.target = r.vec()
		c.flee_from = r.vec()
		c.idle_ticks = r.u32()
		var walking: int = r.u8()
		c.stun_ticks = r.u32()
		c.slow_pct = r.u8()
		c.slow_ticks = r.u32()
		c.poison_damage = r.u32()
		c.poison_ticks = r.u32()
		c.poison_timer = r.u32()
		c.clock = r.u32()
		c.flash_ticks = r.u8()
		var bound: int = r.u8()
		c.refused_ticks = r.u8()
		c.walking = walking == 1
		c.bound = bound == 1
		if not r.ok or c.id < 1 or c.id > NetProtocol.CREATURE_ID_MAX or ids.has(c.id) or not Config.CREATURES.has(c.kind) \
				or not _on_map(c.pos, data) or not _on_map(c.home, data) or c.facing > RigData.Dir.WEST \
				or c.state >= CreatureSim.STATE_NAMES.size() or c.hp < 0 or c.hp > 0xFFFF or walking > 1 or bound > 1 \
				or c.slow_pct > 100 or c.state_ticks > 0x7FFFFFFF or c.idle_ticks > 0x7FFFFFFF or c.poison_ticks > 0x7FFFFFFF \
				or c.stun_ticks > 0x7FFFFFFF or c.slow_ticks > 0x7FFFFFFF or c.clock > 0x7FFFFFFF:
			return "HERD's creature %d is not one" % i
		ids[c.id] = true
		h.creatures.append(c)
	var waits: int = r.u16()
	if waits > MAX_ACTORS:
		return "HERD's waiting respawns are out of range"
	for i: int in waits:
		var kind: StringName = StringName(r.text())
		var due: int = r.u32()
		if not r.ok or not Config.CREATURES.has(kind) or due > 0x7FFFFFFF:
			return "HERD's waiting respawn %d is not one" % i
		h.waiting.append([kind, due])
	if not r.done():
		return "HERD is not one"
	s.herd = h
	return ""


static func _read_boss(bytes: PackedByteArray, s: Saved) -> String:
	var r: Reader = Reader.new(bytes)
	var has: int = r.u8()
	if has == 0:
		return "" if r.done() else "BOSS is not one"
	var b: BossRecord = BossRecord.new()
	b.rng_state = r.s64()
	b.next_id = r.u32()
	b.state = r.u8()
	b.clock = r.u32()
	b.state_ticks = r.u32()
	var n: int = r.u8()
	var broken: int = BossFight.Pillar.hits_per_state() * 3
	if has != 1 or b.state > BOSS_DEAD or n > NetProtocol.PILLARS_MAX or b.next_id < 1 or b.clock > 0x7FFFFFFF \
			or b.state_ticks > 0x7FFFFFFF:
		return "BOSS's numbers are out of range"
	for i: int in n:
		var hits: int = r.u16()
		var fallen: int = r.u8()
		if not r.ok or hits > broken or fallen > 1:
			return "BOSS's pillar %d is not one" % i
		b.hits.append(hits)
		b.fallen.append(fallen == 1)
	if not r.done():
		return "BOSS is not one"
	s.boss = b
	return ""


## The world in file `path` and, when it does not read, the next of SaveStore.candidates (its .tmp, its .bak): the first that reads,
## with `path` set to the file it came from; else a Saved with every file's refusal in `error`. A missing file: error "missing".
static func load_from(path: String) -> Saved:
	var tried: PackedStringArray = []
	for p: String in SaveStore.candidates(path):
		var bytes: PackedByteArray = SaveStore.read_bytes(p, MAX_FILE_BYTES)
		var s: Saved = read(bytes) if not bytes.is_empty() else _refused("empty, unreadable or larger than %d bytes" % MAX_FILE_BYTES)
		if s.ok():
			s.path = p
			s.skipped = "; ".join(tried)
			return s
		tried.append("%s: %s" % [p.get_file(), s.error])
	return _refused("missing" if tried.is_empty() else "; ".join(tried))


# --- putting the saved sims back (after the caller set its sims up on the loaded maps) ---------------------------------------

## Arena `a` (set up on the loaded map) takes its saved state, then the map empties (the class comment's rule).
static func apply_arena(a: Arena, rec: ArenaRecord) -> void:
	if a == null or rec == null:
		return
	a.rng.state = rec.rng_state
	a.next_id = rec.next_id
	a.spawn_timer = rec.spawn_timer
	a.shrine_hp = rec.shrine_hp if a.shrine_rect().has_area() else 0
	a.heretics.clear()
	for r: HereticRecord in rec.heretics:
		var h: HereticSim = HereticSim.new()
		h.id = r.id
		h.pos = r.pos
		h.home = r.home
		h.facing = r.facing
		h.state = r.state
		h.state_ticks = r.state_ticks
		h.hp = r.hp
		h.cooldown = r.cooldown
		h.stuck = r.stuck
		h.poison_damage = r.poison_damage
		h.poison_ticks = r.poison_ticks
		h.poison_timer = r.poison_timer
		h.lit_out = r.lit_out
		h.clock = r.clock
		a.heretics.append(h)
	a.occupied = true
	a.idle_tick()  # on_emptied: nobody is there (targets, an attack under way, the air, the spawn timer)


## The herd (set up on the loaded surface: its first fill is replaced) takes its saved state. A snare's hold and a poison's thrower were
## players of the process that saved it: released and nobody's.
static func apply_herd(h: Creatures, rec: HerdRecord) -> void:
	if h == null or rec == null:
		return
	h.rng.state = rec.rng_state
	h.clock = rec.clock
	h.next_id = rec.next_id
	h.list.clear()
	for r: CreatureRecord in rec.creatures:
		var c: CreatureSim = CreatureSim.new()
		c.id = r.id
		c.kind = r.kind
		c.pos = r.pos
		c.home = r.home
		c.facing = r.facing
		c.state = r.state
		c.state_ticks = r.state_ticks
		c.hp = r.hp
		c.target = r.target
		c.flee_from = r.flee_from
		c.idle_ticks = r.idle_ticks
		c.walking = r.walking
		c.stun_ticks = r.stun_ticks
		c.slow_pct = r.slow_pct
		c.slow_ticks = r.slow_ticks
		c.poison_damage = r.poison_damage
		c.poison_ticks = r.poison_ticks
		c.poison_timer = r.poison_timer
		c.clock = r.clock
		c.flash_ticks = r.flash_ticks
		c.bound = r.bound
		c.refused_ticks = r.refused_ticks
		h.list.append(c)
	h.waiting.clear()
	for row: Array in rec.waiting:
		var w: Creatures.Respawn = Creatures.Respawn.new()
		w.kind = row[0]
		w.due = row[1]
		h.waiting.append(w)
	h.edits.clear()
	h.kills.clear()
	h.refusals.clear()


## The boss fight (set up from the seed and the world's progress: asleep, or dead with its pillars as rubble) takes its random stream and
## ids; a boss that slept when saved keeps its clock and its pillars' hits (an awake one: the reset, which BossFight.setup already is).
static func apply_boss(f: BossFight, rec: BossRecord) -> void:
	if f == null or rec == null or f.sim == null:
		return
	f.rng.state = rec.rng_state
	f.next_id = rec.next_id
	if rec.state == BOSS_AWAKE:
		return
	f.sim.clock = rec.clock
	if rec.state == BOSS_DEAD and f.sim.state == BossSim.State.DEAD:
		f.sim.state_ticks = rec.state_ticks
	if rec.state == BOSS_ASLEEP and f.sim.state == BossSim.State.SLEEP:
		for i: int in mini(rec.hits.size(), f.pillars.size()):
			if rec.hits[i] != f.pillars[i].hits or rec.fallen[i] != f.pillars[i].fallen:
				f.set_pillar_hits(i, rec.hits[i])


## The farm (set up on the loaded map: every field's timer at its stage's start) takes the saved timers of the fields it has.
static func apply_farm(f: Farm, rec: FarmRecord) -> void:
	if f == null or rec == null:
		return
	for i: int in f.plots:
		if rec.plots.has(i):
			f.plots[i].progress = rec.plots[i].x
			f.plots[i].water_left = rec.plots[i].y


## The forest (set up on the loaded map: no axe hits, every stump's whole time) takes the saved hits of the trees still standing and the
## saved time of the stumps it has.
static func apply_forest(f: Forest, rec: ForestRecord) -> void:
	if f == null or rec == null:
		return
	f.hits.clear()
	for c: Vector2i in rec.hits:
		if Forest.is_tree(f.data, c):
			f.hits[c] = rec.hits[c]
	for c: Vector2i in rec.regrow:
		if f.regrow.has(c):
			f.regrow[c] = rec.regrow[c]

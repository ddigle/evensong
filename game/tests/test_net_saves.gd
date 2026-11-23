extends "res://tests/test_net_combat.gd"
## M13b: saving in sessions, in one process: the real SessionHost and SessionClient flows on the rig of tests/test_net_combat.gd (the host's
## messages captured and delivered in order), with ● R54 on (rig_duplicates false: one player per class). tests/test_net_keep.gd runs the
## real processes (the files, leaving and rejoining, the host restarting, four players).
##   - a joiner's character (the sheet before its hello, as SessionClient.on_opened sends it): the host's member holds exactly it (no start
##     kit), the client gets it back in its inventory message (the seen items too); without a sheet a joiner is a new character (the kit)
##   - the class rule: the host's own class is taken, a second archer is refused with the classes taken (the client's line names the free
##     ones), a leaver frees its class and its slot
##   - hostile characters refused as "character" with the reason (oversize, an unknown item, a count past the stack, a class the hello does
##     not say, another version) and nothing of them in the world; a sheet from a peer already in, a second sheet, a sheet whose peer left
##   - a version 14 hello after a sheet is refused as "version" (not "character"): what an older client hears
##   - the host's own saved character (NetSession.character) and a saved world opened by the host (NetSession.loaded): its sims as the file
##     had them, and the world the host writes again equals what it opened, section by section

const SaveWorldTest := preload("res://tests/test_save_world.gd")
const TestNet := preload("res://tests/test_net.gd")
const PALADIN: String = "paladin"
const ARCHER: String = "archer"
const CLERIC: String = "cleric"


func run() -> Array[String]:
	rig_duplicates = false
	await _check_join_with_character()
	await _check_new_character()
	await _check_class_rule()
	await _check_hostile_characters()
	await _check_old_hello()
	await _check_host_character()
	await _check_host_opens_world()
	return failures


## A client of `class_id` bringing `character` (null: a new one) joins as SessionClient.on_opened does it: its sheet (if any) and then its
## hello reach the host in that order; returns once welcomed (or refused: then c.s.over).
func _join_as_client(r: Rig, peer: int, class_id: String, character: CharacterSave.Sheet) -> Client:
	var c: Client = Client.new()
	c.peer = peer
	c.surface = _world(Config.MAP_SURFACE, false)
	c.dungeon = _world(Config.MAP_DUNGEON, false)
	c.dungeon.visible = false
	c.s = CaptureSession.new()
	c.s.name = StringName("ClientNet%d" % peer)
	add_node(c.s)
	c.s.set_physics_process(false)
	c.s.set_process(false)
	c.s.world = c.surface
	c.s.worlds = {Config.MAP_SURFACE: c.surface, Config.MAP_DUNGEON: c.dungeon}
	c.s.options = CliOptions.new()
	c.s.options.class_id = class_id
	c.s.role = NetSession.Role.CLIENT
	c.s.character = character
	c.s.client = SessionClient.new(c.s)
	r.clients.append(c)
	c.s.client.on_opened()
	var order: PackedStringArray = []
	for msg: Array in c.s.take_for(1):
		var kind: String = msg[1]
		var payload: PackedByteArray = msg[2]
		order.append(kind)
		if kind == "sheet":
			r.host.on_sheet(peer, payload)
		elif kind == "hello":
			r.host.on_hello(peer, payload)
	check_eq(order, PackedStringArray(["sheet", "hello"] if character != null else ["hello"]),
		"peer %d: the character goes before the hello (%s)" % [peer, ", ".join(order)])
	for msg2: Array in r.s.take_for(peer):
		if str(msg2[1]) == "refused":
			var refusal: PackedByteArray = msg2[2]
			c.s.client.on_refused(refusal)
			return c
		r.down.append([r.s.tick, peer, msg2[1], msg2[2]])
	for i: int in 6:
		_tick(r)
		if c.s.active:
			break
	_tick(r, 2)
	return c


## Every slot, the selection, the armour and its durability of `inv` are `c`'s.
func _holds(inv: Inventory, c: CharacterSave.Sheet) -> bool:
	if inv.selected != c.selected:
		return false
	for i: int in Config.INVENTORY_SLOTS:
		var a: ItemStack = inv.stack_at(i)
		var b: ItemStack = c.stacks[i]
		if (a == null) != (b == null):
			return false
		if a != null and (a.id != b.id or a.count != b.count or a.grade != b.grade or a.durability != b.durability):
			return false
	if (inv.armor == null) != (c.armor == null):
		return false
	return inv.armor == null or (inv.armor.id == c.armor.id and inv.armor.durability == c.armor.durability)


func _check_join_with_character() -> void:
	var r: Rig = _rig(PALADIN)
	var bob: CharacterSave.Sheet = TestNet.rich_sheet(ARCHER)
	var c: Client = _join_as_client(r, 101, ARCHER, bob)
	var m: NetMember = member_of_peer(r, 101)
	if not check(c.s.active and m != null, "a client with its character is welcomed (%s)" % c.s.end_reason):
		_free_rig(r)
		return
	check(_holds(m.player.inventory, bob), "the host's member holds exactly the character it brought (no start kit): %s" %
		m.player.inventory.describe())
	check(m.player.inventory.has_seen(&"stone_a") and m.player.inventory.has_seen(&"bow_t1"), "and what it has seen")
	check(_holds(c.s.local.player.inventory, bob), "the client got it back from the host: %s" % c.s.local.player.inventory.describe())
	check(c.s.local.player.inventory.has_seen(&"stone_a"), "with the seen items (the character it writes is the host's)")
	check(_log_has_line(r, "joined peer=101", "character=bob-2"), "the host's log names the character")
	check_eq(r.host.characters_in, 1, "one character came in")
	var back: CharacterSave.Sheet = CharacterSave.from_inventory("bob-2", ARCHER, c.s.local.player.inventory)
	check(_holds(c.s.local.player.inventory, back) and back.money() == 250, "what the client would write is what it brought (%s)" %
		back.describe())
	_free_rig(r)


func _check_new_character() -> void:
	var r: Rig = _rig(PALADIN)
	var c: Client = _join_as_client(r, 102, CLERIC, null)
	var m: NetMember = member_of_peer(r, 102)
	if check(c.s.active and m != null, "a client without a character is welcomed"):
		var weapon: StringName = Config.CLASS_WEAPONS[CLERIC]
		check(m.player.inventory.stack_at(Config.START_WEAPON_SLOT) != null
			and m.player.inventory.stack_at(Config.START_WEAPON_SLOT).id == weapon, "a new character: the start kit (M12's way)")
		check(_log_has_line(r, "joined peer=102", "character=new"), "the host's log says new")
	_free_rig(r)


func _check_class_rule() -> void:
	var r: Rig = _rig(PALADIN)
	var p: Client = _join_as_client(r, 110, PALADIN, TestNet.rich_sheet(PALADIN))
	check(p.s.over and p.s.client.refused_reason == "class_taken" and member_of_peer(r, 110) == null,
		"● R54: a paladin cannot join a paladin host (%s)" % p.s.end_reason)
	check_eq(p.s.client.refused_taken, PackedStringArray([PALADIN]), "the refusal says the host's class is taken")
	check(p.s.end_reason.contains("free: miner, archer, cleric, herbalist"), "the client's line names the free classes (%s)" %
		p.s.end_reason)
	var a1: Client = _join_as_client(r, 111, ARCHER, null)
	check(a1.s.active, "an archer joins")
	var a2: Client = _join_as_client(r, 112, ARCHER, TestNet.rich_sheet(ARCHER))
	check(a2.s.over and a2.s.client.refused_reason == "class_taken", "a second archer is refused")
	check_eq(a2.s.client.refused_taken, PackedStringArray([PALADIN, ARCHER]), "the classes taken: paladin, archer")
	check(_log_has_line(r, "refused peer=112", "class=archer taken=paladin,archer"), "the host's log says so")
	var slot: int = member_of_peer(r, 111).slot
	r.host.on_peer_disconnected(111)
	check(member_of_peer(r, 111) == null and not r.host.roster.taken_classes().has(ARCHER), "the archer leaves: its class is free")
	var a3: Client = _join_as_client(r, 113, ARCHER, TestNet.rich_sheet(ARCHER))
	var m3: NetMember = member_of_peer(r, 113)
	check(a3.s.active and m3 != null and m3.slot == slot, "another archer takes the class and the slot (%s)" % a3.s.end_reason)
	check_eq(r.host.refusals.get("class_taken", 0), 2, "two refusals as class_taken")
	_free_rig(r)


func _check_hostile_characters() -> void:
	var r: Rig = _rig(PALADIN)
	var good: PackedByteArray = NetProtocol.encode_sheet(TestNet.rich_sheet(ARCHER))
	var huge: PackedByteArray = PackedByteArray()
	huge.resize(Config.NET_SHEET_MAX_BYTES * 4)
	var unknown: PackedByteArray = good.duplicate()
	unknown[5] = ItemDB.count() + 7
	var too_many: PackedByteArray = good.duplicate()
	too_many[11] = 255  # the money slot's count: past its stack (a negative count written as a byte)
	var older: PackedByteArray = NetProtocol.encode_sheet(TestNet.rich_sheet(ARCHER), NetProtocol.VERSION - 1)
	var cases: Array = [
		[huge, ARCHER, "bytes, at most"], [unknown, ARCHER, "unknown item"], [too_many, ARCHER, "count 255"],
		[good, CLERIC, "the character's class is archer, the hello says cleric"], [older, ARCHER, "version %d" % (NetProtocol.VERSION - 1)],
	]
	var peer: int = 120
	var drops: int = r.surface.data.drops.size()
	var hash: String = r.surface.data.content_hash()
	for case: Array in cases:
		peer += 1
		var bytes: PackedByteArray = case[0]
		var class_id: String = case[1]
		var want: String = case[2]
		r.host.on_sheet(peer, bytes)
		r.host.on_hello(peer, NetProtocol.encode_hello(NetProtocol.class_index(class_id)))
		var msgs: Array[Array] = r.s.take_for(peer)
		var got: PackedByteArray = msgs[0][2] if msgs.size() == 1 else PackedByteArray()
		var refusal: NetProtocol.RefusalMsg = NetProtocol.decode_refusal_msg(got)
		check(msgs.size() == 1 and refusal.name == "character" and refusal.why.contains(want) and member_of_peer(r, peer) == null,
			"a hostile character is refused as character: %s (%s)" % [want, refusal.why])
	check(r.surface.data.drops.size() == drops and r.surface.data.content_hash() == hash and r.s.members.size() == 1,
		"nothing of them is in the world")
	var a: Client = _join_as_client(r, 130, ARCHER, TestNet.rich_sheet(ARCHER))
	var bad_before: int = r.s.bad_messages
	r.host.on_sheet(130, good)
	check(a.s.active and r.s.bad_messages == bad_before + 1, "a sheet from a player already in: malformed, ignored")
	r.host.on_sheet(131, good)
	r.host.on_sheet(131, good)
	check_eq(r.s.bad_messages, bad_before + 2, "a second sheet before the hello: malformed")
	r.host.on_peer_disconnected(131)
	check(not r.host.pending_sheets.has(131), "a peer that leaves before its hello takes its sheet with it")
	_free_rig(r)


## What a version 14 client hears from this host: its hello is 3 bytes as ever, so it is refused as "version" before anything else is read
## (even a sheet in front of it: a v14 client sends none, a hostile one gains nothing).
func _check_old_hello() -> void:
	var r: Rig = _rig(PALADIN)
	r.host.on_sheet(140, NetProtocol.encode_sheet(TestNet.rich_sheet(ARCHER)))
	r.host.on_hello(140, NetProtocol.encode_hello(NetProtocol.class_index(ARCHER), NetProtocol.VERSION - 1))
	var msgs: Array[Array] = r.s.take_for(140)
	var payload: PackedByteArray = msgs[0][2] if msgs.size() == 1 else PackedByteArray()
	check(msgs.size() == 1 and payload.size() == 1 and NetProtocol.decode_refusal(payload) == "version" and member_of_peer(r, 140) == null,
		"a version %d hello: refused as version in one byte (what it reads)" % (NetProtocol.VERSION - 1))
	check(NetProtocol.encode_hello(0).size() == NetProtocol.HELLO_SIZE and NetProtocol.HELLO_SIZE == 3,
		"the hello stays 3 bytes (an older or newer host reads its version)")
	_free_rig(r)


func _check_host_character() -> void:
	var c: CharacterSave.Sheet = TestNet.rich_sheet(CLERIC)
	var r: Rig = _rig_with(CLERIC, null, c)
	check(_holds(r.s.local.player.inventory, c), "the host plays its own saved character: %s" % r.s.local.player.inventory.describe())
	check_eq(r.host.characters_in, 1, "counted")
	_free_rig(r)


## A world saved by the offline game (tests/test_save_world.gd's rich world, as the offline save writes it) opened by a host: the host's
## sims take it, and the world the host writes from its session equals the file it opened in every section but META's time and the surface
## map (the merchant may step aside for the host's own player: M8a's rule, as offline). A second open of the host's file writes the same
## file again (nothing drifts across a host restart).
func _check_host_opens_world() -> void:
	var helper: SaveWorldTest = SaveWorldTest.new()
	var rich: SaveWorldTest.Rig = helper._rich()
	failures.append_array(helper.failures)
	rich.quiesce()
	var file: PackedByteArray = rich.capture()
	var saved: WorldSave.Saved = WorldSave.read(file)
	if not check(saved.ok(), "the rich world reads: %s" % saved.error):
		return
	var r: Rig = _rig_with(PALADIN, saved, null)
	var first: PackedByteArray = WorldSave.capture(r.host.live_world("rig", saved.ticks))
	var a: Dictionary[String, PackedByteArray] = SaveWorldTest.sections_of(file)
	var b: Dictionary[String, PackedByteArray] = SaveWorldTest.sections_of(first)
	var differ: PackedStringArray = []
	for tag: String in WorldSave.TAGS:
		if tag != "META" and tag != "MAP0" and a.get(tag, PackedByteArray()) != b.get(tag, PackedByteArray()):
			differ.append(tag)
	check(differ.is_empty(), "a host that opens a world writes it back the same: every sim section (differ: %s)" % ", ".join(differ))
	# The surface map (MAP0): only the merchant may have stepped aside (M8a's rule: the host's own player stands on its spawn slot). Every
	# other cell of every layer, the drops and the chests are the file's.
	var pristine: WorldData = WorldSave.read(file).maps[Config.MAP_SURFACE]
	var live: WorldData = r.surface.data
	var moved: PackedStringArray = []
	var other: PackedStringArray = []
	for layer: int in WorldData.LAYER_COUNT:
		var x: PackedByteArray = pristine.layers[layer]
		var y: PackedByteArray = live.layers[layer]
		for i: int in mini(x.size(), y.size()):
			if x[i] == y[i]:
				continue
			var c: Vector2i = Vector2i(i % pristine.size.x, i / pristine.size.x)
			if layer == WorldData.Layer.PLACEABLE and (x[i] == WorldData.PLACEABLE_MERCHANT or y[i] == WorldData.PLACEABLE_MERCHANT):
				moved.append("%d,%d:%d>%d" % [c.x, c.y, x[i], y[i]])
			else:
				other.append("layer %d %d,%d:%d>%d" % [layer, c.x, c.y, x[i], y[i]])
	var chests_same: bool = pristine.chests.size() == live.chests.size()
	for key: Vector2i in pristine.chests:
		chests_same = chests_same and live.chests.has(key) and live.chests[key].describe() == pristine.chests[key].describe()
	check(other.is_empty() and moved.size() <= 2 and pristine.drops.size() == live.drops.size() and chests_same
		and pristine.drop_serial == live.drop_serial, "the surface as the file had it but the merchant's step (moved %s, other %s)" % [
		", ".join(moved), ", ".join(other)])
	note("a host opening the rich world: the merchant %s" % (", ".join(moved) if not moved.is_empty() else "stayed"))
	var host_herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	check(host_herd.list.size() == saved.herd.creatures.size() and host_herd.next_id == saved.herd.next_id, "the herd as saved (%d)" %
		host_herd.list.size())
	check(r.host.arenas[Config.MAP_SURFACE].heretics.size() == saved.arenas[Config.MAP_SURFACE].heretics.size(), "the heretics as saved")
	check(r.host.deaths == saved.deaths and r.host.prayer.prayers == saved.prayers, "the deaths and prayers counted")
	check(r.surface.data.progress.altar_tier == saved.maps[Config.MAP_SURFACE].progress.altar_tier and r.surface.data.progress.altar_tier > 0,
		"the altar's tier")
	_free_rig(r)
	var again: WorldSave.Saved = WorldSave.read(first)
	var r2: Rig = _rig_with(PALADIN, again, null)
	var second: PackedByteArray = WorldSave.capture(r2.host.live_world("rig", again.ticks))
	var c: Dictionary[String, PackedByteArray] = SaveWorldTest.sections_of(second)
	var drift: PackedStringArray = []
	for tag: String in WorldSave.TAGS:
		if tag != "META" and b.get(tag, PackedByteArray()) != c.get(tag, PackedByteArray()):
			drift.append(tag)
	check(drift.is_empty(), "the host's file opened by a host again writes the same file (drift: %s)" % ", ".join(drift))
	note("a host opening the rich world: %d B in, %d B out" % [file.size(), first.size()])
	_free_rig(r2)


## A host rig like tests/test_net_combat.gd's _rig, with a saved world opened (its maps in the worlds, NetSession.loaded) and its own
## saved character (NetSession.character), set before on_opened as Main does.
func _rig_with(host_class: String, saved: WorldSave.Saved, character: CharacterSave.Sheet) -> Rig:
	var r: Rig = Rig.new()
	r.surface = _world(Config.MAP_SURFACE, saved == null)
	r.dungeon = _world(Config.MAP_DUNGEON, saved == null)
	if saved != null:
		r.surface.load_data(saved.maps[Config.MAP_SURFACE])
		r.dungeon.load_data(saved.maps[Config.MAP_DUNGEON])
	r.dungeon.visible = false
	r.s = CaptureSession.new()
	r.s.name = &"HostNet"
	add_node(r.s)
	r.s.set_physics_process(false)
	r.s.set_process(false)
	r.s.world = r.surface
	r.s.worlds = {Config.MAP_SURFACE: r.surface, Config.MAP_DUNGEON: r.dungeon}
	r.s.options = CliOptions.new()
	r.s.options.class_id = host_class
	r.s.options.test_no_spawns = true
	r.s.options.test_no_creatures = true
	r.s.role = NetSession.Role.HOST
	r.s.give_allowed = true
	r.s.transport = OpenTransport.new()
	r.s.loaded = saved
	r.s.character = character
	r.host = SessionHost.new(r.s)
	r.s.host = r.host
	r.s.active = true
	r.host.on_opened()
	return r


func _log_has_line(r: Rig, start: String, part: String) -> bool:
	for line: String in r.s.logged:
		if line.begins_with(start.get_slice(" ", 0)) and line.contains(start.get_slice(" ", 1)) and line.contains(part):
			return true
	return false

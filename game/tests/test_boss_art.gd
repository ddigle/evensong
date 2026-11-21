extends "res://tests/base_test.gd"
## M12 boss art (README "M12 보스 그림"): the heretic leader drawn from its own sheets (03-pixel PixelLab 17차 boss_leader_v03 = v02 with
## the re-taken rows, byte copies: test_actors) in place of M12a's code-drawn placeholder. Pictures only: the fight, its timing and the wire are M12's (test_boss,
## test_boss_keeps, test_net_boss). What it checks:
##   sheets   the six sheets and their flame masks load with the art step's cells (body 56x48, action 64x64 with the body cell at (4, 6))
##            and columns (BossSim.FIRST_COLUMN + FRAME_COUNTS, the heretic's counts), rows south / east / north; every cell drawn, no
##            semi-transparent pixel; the feet on the feet row; the action sheets' start and end columns = the walk's first frame on the
##            same feet; the sheet's west is not drawn (the view mirrors east); the held telegraph columns differ between the attack and
##            the cast in every row
##   glow     each glow texture = its sheet's pixels exactly where the mask burns (read from the PNG files apart), demon orange only
##   states   asleep, walking (and walking home), every attack's telegraph held and its blow (the cleave on the attack sheet, the volley
##            and the burn on the cast sheet, the burn's raise held over its whole cast), the hit flash standing, a stun (also cutting an
##            attack), dead (frame by frame, then lying on the last frame): the sheet, the frame and the source rect the view shows
##   view     west = the east row mirrored (and its light), the overlay on the body's rect and place, unshaded, the hit flash on both;
##            the light on the frame's flame (the centroid of its mask pixels, measured here from the PNG) for every frame of every sheet
##            in four directions, kept where it was on a frame without fire; dead: the light out, the ember kept; the marks over the
##            tallest picture (poison, taunt, slow and stun shown, gone with the effects); the shadow as drawn wider than the hem, its
##            ember tint while exposed; the body on the actors' light layer, the fire over it; no placeholder part left (staff, flame
##            sprite, derived sheet)
##   box      the M11a hit-box rule on the sheets (Config.BOSS hit_height_px = the tallest picture +-2, 2r between the narrowest and
##            the widest standing picture + 2) and this step's choice in it: 2r within the south / north body (staff and fire cut)
##   columns  the blow columns written here (attack 5, 3, 3; cast 4, 3, 3), so the sheet -> column mapping is pinned, not only its
##            constants
##   re-takes what the v03 re-takes (17차 다시 뽑기) were made to fix, measured on the sheets: the attack south sweeps across the front
##            (every column the cleave shows from the held one: cocked on the right, the blow low on the right, then low in front on the
##            fan, then swept to the left), the hurt north's frames a hit shows (0-2, the stun's 1 among them) keep the staff's shaft
##            down to the ground, apart from the robe (a clear column between them, as in the start picture), the cast east's blow holds
##            the brazier out in front with the face showing, the death south lies with its staff fallen (no brazier held up on a
##            standing staff)

## The body's rows for the box's width (the art step's body centring: the lowest 18 rows) and the staff's side cut away, in cell x:
## south the staff is left of x 16, north right of x 38 (03-pixel prompts.md 17차 "가로 맞춤": raw x 13 / 34 plus the shift 2 / 5).
const BODY_ROWS: int = 18
const STAFF_CUT_SOUTH: int = 15
const STAFF_CUT_NORTH: int = 39
## The re-takes' checks (picture measurements, README "M12 보스 그림" 다시 뽑기 (v03)): the east face's candle gold (the face the
## re-take shows, mapped to the palette's candle gold by the art step), the hood's rows (px over the feet), the lying picture's most
## height and its brazier's most height over the feet (v02's standing staff held it 40-42 px up), the shaft's rows (px over the feet)
## and the clear rows between the robe and the shaft, the sideways sweep (px from the middle line) and the low blow (px over the feet).
const FACE_GOLD: Color = Color8(0xf4, 0xc9, 0x5d)
const HOOD_OVER_FEET: int = 26
const LYING_MAX_PX: int = 32
const LYING_FIRE_MAX_PX: int = 12
const SHAFT_ROWS_OVER_FEET: Vector2i = Vector2i(5, 15)
const SWEEP_SIDE_PX: float = 8.0
const SWEEP_FRONT_PX: float = 6.0
const SWEEP_LOW_PX: float = 8.0
const SHAFT_GAP_MIN_ROWS: int = 6

var _nodes: Array[Node] = []
## The PNGs read apart from the imported textures (Image.load_from_file of the res:// files), per sheet.
var _png: Dictionary[int, Image] = {}
var _png_em: Dictionary[int, Image] = {}


func run() -> Array[String]:
	_load_pngs()
	_check_sheets()
	_check_glow()
	_check_states()
	_check_view()
	_check_light()
	_check_box_and_marks()
	_check_retakes()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


func view() -> BossView:
	var v: BossView = BossView.new()
	_nodes.append(v)
	return v


func boss(state: int, facing: int = RigData.Dir.SOUTH) -> BossSim:
	var b: BossSim = BossSim.new()
	b.pos = Vector2(200.25, 120.75)
	b.facing = facing
	b.state = state
	b.hp = 100
	b.hp_max = 100
	return b


func _load_pngs() -> void:
	for a: int in BossView.SHEETS.size():
		_png[a] = LightGen.to_rgba8(Image.load_from_file(ProjectSettings.globalize_path(BossView.SHEETS[a].resource_path)))
		_png_em[a] = LightGen.to_rgba8(Image.load_from_file(ProjectSettings.globalize_path(BossView.EMISSIVE[a].resource_path)))


## The opaque pixels' box of `img` inside `r` (end exclusive), or an empty Rect2i.
static func opaque_box(img: Image, r: Rect2i) -> Rect2i:
	var lo: Vector2i = Vector2i(1 << 20, 1 << 20)
	var hi: Vector2i = Vector2i(-1, -1)
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			if img.get_pixel(x, y).a8 > 0:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	if hi.x < 0:
		return Rect2i()
	return Rect2i(lo, hi - lo + Vector2i.ONE)


# --- the sheets ---------------------------------------------------------------------------------------------------------------

func _check_sheets() -> void:
	check_eq(Array(BossSim.ANIM_NAMES.slice(0, 5)), Array(HereticSim.ANIM_NAMES), "the first five sheets are the heretic's animations")
	for a5: int in 5:
		check_eq(BossSim.FRAME_COUNTS[a5], HereticSim.FRAME_COUNTS[a5], "%s: the heretic's frame count" % BossSim.ANIM_NAMES[a5])
		check_eq(BossSim.FIRST_COLUMN[a5], HereticSim.FIRST_COLUMN[a5], "%s: the heretic's first column" % BossSim.ANIM_NAMES[a5])
	check_eq(BossSim.FRAME_COUNTS[BossSim.Anim.CAST], 8, "the cast: 8 frames")
	check_eq(BossSim.FRAME_COUNTS[BossSim.Anim.DEATH] * Config.HERETIC_DEATH_FRAME_TICKS, NetProtocol.boss_death_ticks(),
		"the wire's death time is this sheet's")
	check_eq(BossView.BODY_CELL, Vector2i(56, 48), "the body cell")
	check_eq(BossView.ACTION_CELL, Vector2i(64, 64), "the action cell")
	check_eq(BossView.feet_in_cell(BossSim.Anim.IDLE), Vector2i(28, 48), "the body cell's feet: under the bottom row, x 27.5 + 0.5")
	check_eq(BossView.feet_in_cell(BossSim.Anim.CAST), Vector2i(32, 54), "the action cell's feet: the body cell at (4, 6)")
	for a: int in BossView.SHEETS.size():
		var nm: String = BossSim.ANIM_NAMES[a]
		var c: Vector2i = BossView.cell(a)
		var want: Vector2i = Vector2i(c.x * BossView.columns(a), c.y * RigData.ROWS)
		var tex: Texture2D = BossView.SHEETS[a]
		check_eq(tex.resource_path.get_file(), "boss_leader_v03_%s.png" % nm, "%s: its sheet file" % nm)
		check_eq(Vector2i(tex.get_size()), want, "%s: %d columns of %s, three rows" % [nm, BossView.columns(a), c])
		check_eq(Vector2i(BossView.EMISSIVE[a].get_size()), want, "%s: its mask the same size" % nm)
		check_eq(Vector2i(_png[a].get_size()), want, "%s: the PNG file the same" % nm)
		check_eq(BossView.EMISSIVE[a].resource_path.get_file(), "boss_leader_v03_%s_emissive.png" % nm, "%s: its mask file" % nm)
		var img: Image = _png[a]
		var semi: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				var al: int = img.get_pixel(x, y).a8
				if al != 0 and al != 255:
					semi += 1
		check_eq(semi, 0, "%s: no semi-transparent pixel" % nm)
		var feet_row: int = BossView.feet_in_cell(a).y - 1
		for row: int in RigData.ROWS:
			for col: int in BossView.columns(a):
				var r: Rect2i = Rect2i(Vector2i(col * c.x, row * c.y), c)
				var box: Rect2i = opaque_box(img, r)
				if not check(box.has_area(), "%s row %d column %d drawn" % [nm, row, col]):
					continue
				var bottom: int = box.end.y - 1 - r.position.y
				if a == BossSim.Anim.IDLE:
					check_eq(bottom, feet_row, "%s %s %d: on the feet row" % [nm, RigData.DIR_NAMES[row], col])
				elif a == BossSim.Anim.WALK:
					check_between(bottom, feet_row - 2, feet_row, "%s %s %d: on the feet row (a step 2 px up at most)" % [nm,
						RigData.DIR_NAMES[row], col])
	# The action sheets' start and end columns: the walk's first frame (the art step's KEY) with its own lowest row on the feet row (the
	# walk north's first frame steps 2 px up in its sheet: the art step puts the key's feet on the feet row).
	var walk: Image = _png[BossSim.Anim.WALK]
	for a2: int in [BossSim.Anim.ATTACK, BossSim.Anim.CAST]:
		for row2: int in RigData.ROWS:
			var wr: Rect2i = BossView.frame_rect(BossSim.Anim.WALK, row2, 0)
			var lift: int = wr.end.y - opaque_box(walk, wr).end.y
			for col2: int in [0, BossView.columns(a2) - 1]:
				var bad: int = 0
				var at: Vector2i = Vector2i(col2 * BossView.ACTION_CELL.x, row2 * BossView.ACTION_CELL.y)
				for y2: int in BossView.ACTION_CELL.y:
					for x2: int in BossView.ACTION_CELL.x:
						var inside: Vector2i = Vector2i(x2, y2) - BossView.ACTION_AT - Vector2i(0, lift)
						var want_c: Color = Color(0, 0, 0, 0)
						if Rect2i(Vector2i.ZERO, BossView.BODY_CELL).has_point(inside):
							want_c = walk.get_pixel(inside.x, row2 * BossView.BODY_CELL.y + inside.y)
						var got_c: Color = _png[a2].get_pixel(at.x + x2, at.y + y2)
						if (got_c.a8 > 0 or want_c.a8 > 0) and got_c != want_c:
							bad += 1
				check_eq(bad, 0, "%s %s column %d: the walk's first frame on the feet row (%d px down)" % [BossSim.ANIM_NAMES[a2],
					RigData.DIR_NAMES[row2], col2, lift])
	# The blow columns: the art step's candidates (03-pixel prompts.md 17차 "game/에 넘길 것" and 17차 다시 뽑기 7), not the heretic's
	# 3, 4, 5. The v03 attack south's 5 (README "M12 보스 그림" 다시 뽑기 (v03): 6 was tried, its blow hidden behind a target to the
	# south).
	check_eq(Array(BossSim.HIT_COLUMN_ATTACK), [5, 3, 3], "the attack's blow columns (south, east, north)")
	check_eq(Array(BossSim.HIT_COLUMN_CAST), [4, 3, 3], "the cast's blow columns")
	# Cleave and cast read apart: their held telegraph columns differ in every row (and their blows).
	for row3: int in RigData.ROWS:
		for k: int in [0, 1]:
			var ca: int = BossSim.hit_column(BossSim.Anim.ATTACK, row3) - 1 + k
			var cc: int = BossSim.hit_column(BossSim.Anim.CAST, row3) - 1 + k
			var ia: Image = _png[BossSim.Anim.ATTACK].get_region(Rect2i(ca * 64, row3 * 64, 64, 64))
			var ic: Image = _png[BossSim.Anim.CAST].get_region(Rect2i(cc * 64, row3 * 64, 64, 64))
			var differ: int = 0
			for y3: int in 64:
				for x3: int in 64:
					if ia.get_pixel(x3, y3) != ic.get_pixel(x3, y3):
						differ += 1
			check(differ > 150, "%s: the attack's %s column %d and the cast's %d differ (%d px)" % [RigData.DIR_NAMES[row3],
				"held" if k == 0 else "blow", ca, cc, differ])
		var hit_a: int = BossSim.hit_column(BossSim.Anim.ATTACK, row3)
		var hit_c: int = BossSim.hit_column(BossSim.Anim.CAST, row3)
		check(hit_a >= 2 and hit_c >= 2, "a raise column before each blow")


# --- the glow -----------------------------------------------------------------------------------------------------------------

func _check_glow() -> void:
	for a: int in BossView.SHEETS.size():
		var nm: String = BossSim.ANIM_NAMES[a]
		var g: Image = LightGen.to_rgba8(BossView.glow_texture(a).get_image())
		check_eq(g.get_size(), _png[a].get_size(), "%s: its glow the sheet's size" % nm)
		var wrong: int = 0
		var lit: int = 0
		var orange: int = 0
		for y: int in g.get_height():
			for x: int in g.get_width():
				var burns: bool = _png_em[a].get_pixel(x, y).a8 >= BossView.GLOW_MIN_ALPHA
				var want: Color = _png[a].get_pixel(x, y) if burns else Color(0, 0, 0, 0)
				var got: Color = g.get_pixel(x, y)
				if (got.a8 > 0 or want.a8 > 0) and got != want:
					wrong += 1
				if burns:
					lit += 1
					if got.a8 == 255 and got.h * 360.0 <= 30.0:
						orange += 1
		check_eq(wrong, 0, "%s: the glow = the sheet's pixels where its mask burns, nothing else" % nm)
		check(lit > 100, "%s: fire to glow (%d px)" % [nm, lit])
		check_eq(orange, lit, "%s: every glowing pixel opaque demon orange or blood" % nm)
		note("%s: %d fire px" % [nm, lit])
	check(BossView.glow_texture(BossSim.Anim.IDLE) == BossView.glow_texture(BossSim.Anim.IDLE), "cached")


# --- the states -> sheet and frame ----------------------------------------------------------------------------------------

## Shows `b` on view `v` and checks its sheet, frame and source rect.
func expect(v: BossView, b: BossSim, a: int, f: int, what: String) -> void:
	v.show_sim(b)
	check_eq(v.anim, a, "%s: the %s sheet" % [what, BossSim.ANIM_NAMES[a]])
	check_eq(v.frame, f, "%s: frame %d" % [what, f])
	check(v.body.texture == BossView.SHEETS[a], "%s: drawn from the %s sheet" % [what, BossSim.ANIM_NAMES[a]])
	check_eq(Rect2i(v.body.region_rect), BossView.frame_rect(a, RigData.sheet_row(b.facing), f), "%s: its cell" % what)


func _check_states() -> void:
	var v: BossView = view()
	# Asleep and standing: idle, 12 ticks a frame.
	var b: BossSim = boss(BossSim.State.SLEEP)
	for t: int in [0, 11, 12, 36, 47, 48]:
		b.clock = t
		expect(v, b, BossSim.Anim.IDLE, (t / HereticSim.IDLE_FRAME_TICKS) % 4, "asleep at %d" % t)
	b.state = BossSim.State.CHASE
	b.clock = 25
	expect(v, b, BossSim.Anim.IDLE, 2, "awake, standing")
	# Walking (and walking home): 7 ticks a frame over 6.
	b.walking = true
	for t2: int in [0, 6, 7, 41, 42, 50]:
		b.clock = t2
		expect(v, b, BossSim.Anim.WALK, (t2 / HereticSim.WALK_FRAME_TICKS) % 6, "walking at %d" % t2)
	b.state = BossSim.State.RETURN
	b.clock = 14
	expect(v, b, BossSim.Anim.WALK, 2, "walking home")
	# The hit flash standing: hurt frames 0..2 over the flash.
	var hb: BossSim = boss(BossSim.State.CHASE)
	for fl: int in [Config.HIT_FLASH_TICKS, Config.HIT_FLASH_TICKS - 2, 1]:
		hb.flash_ticks = fl
		expect(v, hb, BossSim.Anim.HURT, mini((Config.HIT_FLASH_TICKS - fl) / 2, 5), "flashing (%d)" % fl)
	check(v.body.modulate == Player.HIT_FLASH and v.glow.modulate == Player.HIT_FLASH, "the flash on the body and its fire")
	# Every attack in every row: the raise frames at the heretic's frame time, the column before the blow held to the blow tick, then
	# the blow's column on the blow tick (the cleave on the attack sheet, the volley and the burn on the cast sheet). The blow columns
	# are written here (the art step's candidates, rows south / east / north), not read from BossSim.hit_column: a wrong sheet -> column
	# mapping (the cast on the attack's columns, the two swapped, a row off by one) fails here and not only the constants' check above.
	var ft: int = Config.HERETIC_ATTACK_FRAME_TICKS
	var blow_columns: Dictionary[int, Array] = {BossSim.Anim.ATTACK: [5, 3, 3], BossSim.Anim.CAST: [4, 3, 3]}
	for dir: int in 4:
		var row: int = RigData.sheet_row(dir)
		for atk: int in [BossSim.Attack.CLEAVE, BossSim.Attack.VOLLEY, BossSim.Attack.BURN]:
			var sheet: int = BossSim.Anim.ATTACK if atk == BossSim.Attack.CLEAVE else BossSim.Anim.CAST
			var nm: String = "%s %s" % [BossSim.ATTACK_NAMES[atk], RigData.DIR_NAMES[dir]]
			var want_blow: int = blow_columns[sheet][row]
			check_eq(BossSim.hit_column(sheet, row), want_blow, "%s: its blow column" % nm)
			check_eq(BossSim.hit_frame(sheet, row), want_blow - BossSim.FIRST_COLUMN[sheet], "%s: its blow frame" % nm)
			var held: int = want_blow - 1 - BossSim.FIRST_COLUMN[sheet]
			var blow: int = BossSim.strike_tick(atk) if atk != BossSim.Attack.BURN else BossSim.attack_int(atk, "cast_ticks")
			var ab: BossSim = boss(BossSim.State.ATTACK, dir)
			ab.attack = atk
			ab.state_ticks = 0
			expect(v, ab, sheet, 0, "%s: its first frame" % nm)
			ab.state_ticks = ft
			expect(v, ab, sheet, mini(1, held), "%s: the raise" % nm)
			ab.state_ticks = blow - 1
			expect(v, ab, sheet, held, "%s: the telegraph held a tick before the blow" % nm)
			check_eq(v.body.region_rect.position.x, float((want_blow - 1) * 64), "%s: held on the column before the blow" % nm)
			if atk == BossSim.Attack.BURN:
				check_eq(BossSim.attack_length(atk), blow, "the burn stands its cast only: its raise is all it shows")
				continue
			ab.state_ticks = blow
			expect(v, ab, sheet, held + 1, "%s: the blow" % nm)
			check_eq(v.body.region_rect.position.x, float(want_blow * 64), "%s: on its blow column" % nm)
			ab.state_ticks = blow + ft
			expect(v, ab, sheet, held + 2, "%s: after the blow" % nm)
			ab.state_ticks = BossSim.attack_length(atk) - 1
			expect(v, ab, sheet, mini(held + 1 + (BossSim.attack_length(atk) - 1 - blow) / ft, 7), "%s: its last tick" % nm)
	# The rule is M12a's (BossSim.attack_frame) on the boss's own columns.
	for t3: int in 60:
		check_eq(BossSim.attack_frame(BossSim.Anim.ATTACK, 1, BossSim.Attack.CLEAVE, t3),
			mini(t3 / ft, 1) if t3 < 36 else mini(2 + (t3 - 36) / ft, 7), "the cleave east at %d" % t3)
	# A stun holds the hurt pose's stun frame, mid-attack too.
	var sb: BossSim = boss(BossSim.State.ATTACK, RigData.Dir.EAST)
	sb.attack = BossSim.Attack.VOLLEY
	sb.state_ticks = 20
	sb.stun_ticks = 30
	expect(v, sb, BossSim.Anim.HURT, Config.SKILL_STUN_FRAME, "stunned mid-volley")
	sb.state = BossSim.State.CHASE
	sb.walking = true
	expect(v, sb, BossSim.Anim.HURT, Config.SKILL_STUN_FRAME, "stunned walking")
	check(v.marks.shown.has(EffectMarks.Kind.STUN), "its stun mark")
	# Dead: the death frames 6 ticks each, then lying on the last.
	var db: BossSim = boss(BossSim.State.DEAD, RigData.Dir.NORTH)
	for t4: int in [0, 5, 6, 30, 41, 42, 999]:
		db.state_ticks = t4
		expect(v, db, BossSim.Anim.DEATH, mini(t4 / Config.HERETIC_DEATH_FRAME_TICKS, 6), "dead at %d" % t4)
	check_eq(v.frame, BossSim.FRAME_COUNTS[BossSim.Anim.DEATH] - 1, "lying on the last frame")
	check(not v.light.enabled and not v.light.visible, "dead: its light out")
	check(v.glow.visible and v.glow.texture == BossView.glow_texture(BossSim.Anim.DEATH), "dead: the fallen brazier's ember still drawn")
	check(v.marks.shown.is_empty(), "dead: no marks")
	db.flash_ticks = 3
	v.show_sim(db)
	check(v.body.modulate == Color.WHITE, "dead: no flash")


# --- the view -----------------------------------------------------------------------------------------------------------------

func _check_view() -> void:
	var v: BossView = view()
	check(v.get_node_or_null(^"Rig/Staff") == null and v.get_node_or_null(^"Rig/Flame") == null
		and v.get_node_or_null(^"Rig/FlameGlow") == null, "no placeholder staff or flame sprite")
	check(v.glow.material == FixtureView.unshaded_material(), "the fire drawn unshaded")
	check_eq(v.glow.get_parent(), v.rig, "the fire in the rig (mirrored with the body)")
	check_eq(v.light.color, Config.HERETIC_FIRE_LIGHT_COLOR, "the orange light")
	check(is_equal_approx(v.light.energy, Config.BOSS_FIRE_LIGHT_ENERGY), "its energy")
	var b: BossSim = boss(BossSim.State.CHASE, RigData.Dir.EAST)
	b.clock = 14
	v.show_sim(b)
	check_eq(v.position, Vector2(200, 121), "on its feet (rounded)")
	check_eq(v.rig.scale, Vector2.ONE, "east as drawn")
	var east_rect: Rect2 = v.body.region_rect
	var east_light: Vector2 = v.light.position
	b.facing = RigData.Dir.WEST
	v.show_sim(b)
	check_eq(v.rig.scale, Vector2(-1.0, 1.0), "west = east mirrored (R19)")
	check_eq(v.body.region_rect, east_rect, "west uses the east row")
	check_eq(v.light.position, Vector2(-east_light.x, east_light.y), "its light mirrored")
	check(v.body.texture is CompressedTexture2D, "the imported sheet itself (no derived texture)")
	for dir: int in 4:
		for a: int in BossView.SHEETS.size():
			var vb: BossSim = boss(BossSim.State.CHASE, dir)
			_pose(vb, a, 1)
			v.show_sim(vb)
			check_eq(v.glow.region_rect, v.body.region_rect, "%s %s: the fire on the body's frame" % [BossSim.ANIM_NAMES[a],
				RigData.DIR_NAMES[dir]])
			check_eq(v.glow.position, v.body.position, "its place")
			check(v.glow.texture == BossView.glow_texture(v.anim), "the glow of that sheet")
			check_eq(Vector2i(v.body.position), -BossView.feet_in_cell(v.anim), "the cell's feet on the node")
	# The shadow: wider than the hem of every standing frame (it shows either side of the robe).
	var widest_hem: int = 0
	for a2: int in [BossSim.Anim.IDLE, BossSim.Anim.WALK]:
		for row: int in RigData.ROWS:
			for f: int in BossSim.FRAME_COUNTS[a2]:
				var r: Rect2i = BossView.frame_rect(a2, row, f)
				var box: Rect2i = opaque_box(_png[a2], Rect2i(Vector2i(r.position.x, r.end.y - 1), Vector2i(r.size.x, 1)))
				widest_hem = maxi(widest_hem, box.size.x)
	# Measured on the rows the view draws (BossView.shadow_rows), not on the constant.
	var rows: Array[Rect2] = BossView.shadow_rows()
	var drawn_w: int = 0
	for rr: Rect2 in rows:
		drawn_w = maxi(drawn_w, roundi(rr.size.x))
	note("hem: widest feet row %d px, shadow %s drawn %d px wide in %d rows" % [widest_hem, BossView.SHADOW_SIZE, drawn_w, rows.size()])
	check(drawn_w > widest_hem, "the shadow drawn wider than the hem (%d px over %d)" % [drawn_w, widest_hem])
	check_eq(drawn_w, BossView.SHADOW_SIZE.x + 1, "its widest row: SHADOW_SIZE.x and the middle pixel")
	check(rows.size() <= BossView.SHADOW_SIZE.y + 2, "a flat ellipse (%d rows)" % rows.size())
	# The body on the actors' light layer (lit by the torches and its own fire, as a heretic) and the fire drawn over it.
	check_eq(v.body.light_mask, Config.LIGHT_LAYER_ACTORS, "the body on the actors' light layer")
	check_eq(v.light_mask, Config.LIGHT_LAYER_ACTORS, "the view too")
	check(v.glow.get_index() > v.body.get_index(), "the fire drawn over the body")
	# Exposed: the shadow's ember tint follows it, then back.
	var xb: BossSim = boss(BossSim.State.CHASE)
	xb.exposed_ticks = 30
	v.show_sim(xb)
	check(v.exposed and v.shadow_colour() == BossView.SHADOW_EXPOSED, "exposed: the ember-tinted shadow")
	xb.exposed_ticks = 0
	v.show_sim(xb)
	check(not v.exposed and v.shadow_colour() == BossView.SHADOW, "no longer exposed: the plain shadow")
	check(BossView.SHADOW_EXPOSED != BossView.SHADOW, "the two shadows differ")
	# The marks besides the stun (test_boss_art's states check the stun): poison, taunt and slow over it.
	var mb: BossSim = boss(BossSim.State.CHASE)
	mb.poison_ticks = 30
	mb.taunt_ticks = 30
	mb.taunt_by = 7
	mb.slow_ticks = 30
	mb.slow_pct = 50
	v.show_sim(mb)
	check(v.marks.shown.has(EffectMarks.Kind.POISON), "its poison mark")
	check(v.marks.shown.has(EffectMarks.Kind.TAUNT), "its taunt mark")
	check(v.marks.shown.has(EffectMarks.Kind.SLOW), "its slow mark")
	check(not v.marks.shown.has(EffectMarks.Kind.STUN), "no stun mark without a stun")
	mb.poison_ticks = 0
	mb.taunt_ticks = 0
	mb.slow_ticks = 0
	v.show_sim(mb)
	check(v.marks.shown.is_empty(), "the marks gone with the effects")


## Sets `b` to show sheet `a` at frame `f` (a state that shows it).
static func _pose(b: BossSim, a: int, f: int) -> void:
	b.walking = a == BossSim.Anim.WALK
	b.clock = f * (HereticSim.WALK_FRAME_TICKS if a == BossSim.Anim.WALK else HereticSim.IDLE_FRAME_TICKS)
	b.state = BossSim.State.CHASE
	b.state_ticks = 0
	b.stun_ticks = 0
	b.flash_ticks = 0
	match a:
		BossSim.Anim.ATTACK, BossSim.Anim.CAST:
			b.state = BossSim.State.ATTACK
			b.attack = BossSim.Attack.CLEAVE if a == BossSim.Anim.ATTACK else BossSim.Attack.VOLLEY
			var pre: int = BossSim.hit_frame(a, b.row())
			var blow: int = BossSim.picture_blow_tick(b.attack)
			b.state_ticks = f * Config.HERETIC_ATTACK_FRAME_TICKS if f < pre else blow + (f - pre) * Config.HERETIC_ATTACK_FRAME_TICKS
		BossSim.Anim.HURT:
			b.flash_ticks = Config.HIT_FLASH_TICKS - 2 * f
		BossSim.Anim.DEATH:
			b.state = BossSim.State.DEAD
			b.state_ticks = f * Config.HERETIC_DEATH_FRAME_TICKS


# --- the light ----------------------------------------------------------------------------------------------------------------

func _check_light() -> void:
	var v: BossView = view()
	var frames: int = 0
	var placed: int = 0
	var no_fire: int = 0
	for dir: int in 4:
		var row: int = RigData.sheet_row(dir)
		var mirror: float = -1.0 if RigData.is_mirrored(dir) else 1.0
		for a: int in BossView.SHEETS.size():
			var count: int = BossSim.FRAME_COUNTS[a] if a != BossSim.Anim.HURT else 3
			for f: int in count:
				var b: BossSim = boss(BossSim.State.CHASE, dir)
				_pose(b, a, f)
				v.show_sim(b)
				if v.anim != a or v.frame != f:
					fail("%s %s %d: posed as %s %d" % [BossSim.ANIM_NAMES[a], RigData.DIR_NAMES[dir], f, BossSim.ANIM_NAMES[v.anim], v.frame])
					continue
				frames += 1
				# The centroid of the frame's mask pixels in the PNG, from the feet.
				var r: Rect2i = BossView.frame_rect(a, row, f)
				var sum: Vector2 = Vector2.ZERO
				var n: int = 0
				for y: int in range(r.position.y, r.end.y):
					for x: int in range(r.position.x, r.end.x):
						if _png_em[a].get_pixel(x, y).a8 > 0:
							sum += Vector2(x - r.position.x + 0.5, y - r.position.y + 0.5)
							n += 1
				if n == 0:
					no_fire += 1
					continue
				var want: Vector2 = sum / n - Vector2(BossView.feet_in_cell(a))
				want.x *= mirror
				if absf(v.light.position.x - want.x) <= 0.5 and absf(v.light.position.y - want.y) <= 0.5:
					placed += 1
				else:
					fail("%s %s %d: the light at %s, the flame's middle %s" % [BossSim.ANIM_NAMES[a], RigData.DIR_NAMES[dir], f,
						v.light.position, want])
				check_eq(v.light.enabled, a != BossSim.Anim.DEATH, "its light on while it lives")
	note("light: %d frames, %d on their flame, %d without fire" % [frames, placed, no_fire])
	check_eq(placed + no_fire, frames, "the light on the flame of every frame with fire")
	check_eq(frames, 4 * (6 + 4 + 8 + 3 + 7 + 8), "every frame seen (the hurt frames 0-2 a hit shows)")
	# A frame without fire keeps the light where it was (none in this art: one made so for the check, then put back).
	var b2: BossSim = boss(BossSim.State.CHASE, RigData.Dir.SOUTH)
	_pose(b2, BossSim.Anim.IDLE, 0)
	v.show_sim(b2)
	var before: Vector2 = v.light.position
	var cache: PackedVector2Array = BossView._fire[BossSim.Anim.WALK]
	var held: PackedVector2Array = cache.duplicate()
	cache[0] = BossView.NO_FIRE
	BossView._fire[BossSim.Anim.WALK] = cache
	_pose(b2, BossSim.Anim.WALK, 0)
	v.show_sim(b2)
	check_eq(v.anim, BossSim.Anim.WALK, "a frame without fire shown")
	check_eq(v.light.position, before, "the light kept where it was")
	BossView._fire[BossSim.Anim.WALK] = held
	v.show_sim(b2)
	check(v.light.position != before, "and on the flame again with fire")


# --- the box and the marks ----------------------------------------------------------------------------------------------------

func _check_box_and_marks() -> void:
	var tallest: int = 0
	var tallest_at: String = ""
	var widest: int = 0
	var narrowest: int = 1 << 20
	for a: int in BossView.SHEETS.size():
		var feet: Vector2i = BossView.feet_in_cell(a)
		for row: int in RigData.ROWS:
			for f: int in BossSim.FRAME_COUNTS[a]:
				var r: Rect2i = BossView.frame_rect(a, row, f)
				var box: Rect2i = opaque_box(_png[a], r)
				var h: int = feet.y - (box.position.y - r.position.y)
				if h > tallest:
					tallest = h
					tallest_at = "%s %s %d" % [BossSim.ANIM_NAMES[a], RigData.DIR_NAMES[row], f]
				if a == BossSim.Anim.IDLE or a == BossSim.Anim.WALK:
					widest = maxi(widest, box.size.x)
					narrowest = mini(narrowest, box.size.x)
	note("boss sheets: tallest %d px (%s), standing %d..%d px wide; box %d tall, %d wide" % [tallest, tallest_at, narrowest, widest,
		roundi(Config.BOSS["hit_height_px"]), roundi(2.0 * Config.BOSS["hit_radius_px"])])
	check_eq(BossView.TALLEST_PX, tallest, "TALLEST_PX is the sheets' tallest picture")
	# The M11a hit-box rule: height = the tallest picture +-2; the width within the standing pictures (+2).
	check(absi(roundi(Config.BOSS["hit_height_px"]) - tallest) <= 2, "the box's height is the picture's (+-2)")
	var w: int = roundi(2.0 * Config.BOSS["hit_radius_px"])
	check(w <= widest + 2 and w >= narrowest, "its width within the standing pictures (%d in %d..%d)" % [w, narrowest, widest + 2])
	# M12 boss art's choice (README "M12 보스 그림" 판정 상자): 2r = the south / north body. The body: the lowest BODY_ROWS rows of each
	# standing frame, its fire left out and the staff's side cut (STAFF_CUT: the art step's raw cut plus its shift, in cell x). A wider
	# radius (to take in the staff and the brazier, a human's call: README) means changing this check with it.
	var body_lo: int = 1 << 20
	var body_hi: int = 0
	for a2: int in [BossSim.Anim.IDLE, BossSim.Anim.WALK]:
		for row2: int in [0, 2]:
			for f2: int in BossSim.FRAME_COUNTS[a2]:
				var r2: Rect2i = BossView.frame_rect(a2, row2, f2)
				var low: int = opaque_box(_png[a2], r2).end.y - 1
				var x_lo: int = 1 << 20
				var x_hi: int = -1
				for y2: int in range(low - BODY_ROWS + 1, low + 1):
					for x2: int in range(r2.position.x, r2.end.x):
						var cx: int = x2 - r2.position.x
						if (row2 == 0 and cx <= STAFF_CUT_SOUTH) or (row2 == 2 and cx >= STAFF_CUT_NORTH):
							continue
						if _png[a2].get_pixel(x2, y2).a8 > 0 and _png_em[a2].get_pixel(x2, y2).a8 < BossView.GLOW_MIN_ALPHA:
							x_lo = mini(x_lo, cx)
							x_hi = maxi(x_hi, cx)
				body_lo = mini(body_lo, x_hi - x_lo + 1)
				body_hi = maxi(body_hi, x_hi - x_lo + 1)
	note("south / north standing body (staff and fire cut): %d..%d px wide" % [body_lo, body_hi])
	check(w >= body_lo and w <= body_hi, "2r within the south / north body (%d in %d..%d; a wider radius: change this check too)" % [w,
		body_lo, body_hi])
	check(Config.BOSS["hit_height_px"] > Config.BODY_HIT_HEIGHT_PX and Config.BOSS["hit_radius_px"] > Config.BODY_HIT_RADIUS_PX,
		"a bigger box than a heretic's")
	# The marks: their bottom row MARKS_GAP rows over the tallest picture.
	var v: BossView = view()
	check_eq(v.marks.position, Vector2(0, -BossView.MARKS_LIFT), "the marks lifted")
	var bottom_row: int = EffectMarks.MARK_Y - BossView.MARKS_LIFT + EffectMarks.SIZE - 1
	check_eq(-tallest - 1 - bottom_row, BossView.MARKS_GAP, "the marks %d rows clear of the hood's tip" % BossView.MARKS_GAP)
	check(BossView.MARKS_GAP >= 1, "never touching it")


# --- the re-takes (v03) -------------------------------------------------------------------------------------------------------

## The flame's middle (its mask pixels' centroid, from the feet) in sheet column `col` of sheet `a`, row `row`, read from the PNG, or
## BossView.NO_FIRE; its pixels (from the feet) are appended to `out`.
func _flame(a: int, row: int, col: int, out: Array[Vector2i] = []) -> Vector2:
	var c: Vector2i = BossView.cell(a)
	var feet: Vector2i = BossView.feet_in_cell(a)
	var sum: Vector2 = Vector2.ZERO
	var n: int = 0
	for y: int in c.y:
		for x: int in c.x:
			if _png_em[a].get_pixel(col * c.x + x, row * c.y + y).a8 >= BossView.GLOW_MIN_ALPHA:
				sum += Vector2(x + 0.5, y + 0.5)
				n += 1
				out.append(Vector2i(x, y) - feet)
	return BossView.NO_FIRE if n == 0 else sum / n - Vector2(feet)


func _check_retakes() -> void:
	# The attack south (v02: the staff held level to the right, a thrust), every column the cleave shows from the telegraph's held one
	# (the blow + 2 is the last: the cleave's after-pause is 18 ticks), each column's flame measured on the PNG: cocked on the right
	# while the telegraph holds, the blow low on the right (the brazier still in sight: a target stands in the fan to the south, in
	# front of anything lower in front of the feet), then low in front over the fan, then swept to the left.
	var hit: int = BossSim.hit_column(BossSim.Anim.ATTACK, 0)
	var held_at: Vector2 = _flame(BossSim.Anim.ATTACK, 0, hit - 1)
	var blow_at: Vector2 = _flame(BossSim.Anim.ATTACK, 0, hit)
	var then_at: Vector2 = _flame(BossSim.Anim.ATTACK, 0, hit + 1)
	var last_at: Vector2 = _flame(BossSim.Anim.ATTACK, 0, hit + 2)
	note("attack south's flame from the feet: held %s, blow %s, then %s, last %s" % [held_at, blow_at, then_at, last_at])
	check(held_at.x > SWEEP_SIDE_PX, "the attack south held cocked on the right (flame x %.1f)" % held_at.x)
	check(blow_at.x > SWEEP_SIDE_PX and blow_at.y >= -SWEEP_LOW_PX, "its blow low on the right (flame %s)" % blow_at)
	check(absf(then_at.x) <= SWEEP_FRONT_PX and then_at.y >= -2.0, "then low in front, on the fan (flame %s)" % then_at)
	check(hit + 2 < BossView.columns(BossSim.Anim.ATTACK) and last_at.x < -SWEEP_SIDE_PX,
		"the cleave's last shown column (%d): swept to the left (flame x %.1f)" % [hit + 2, last_at.x])
	# The hurt north (v02: the brazier floated at the shoulder, no shaft): every frame a hit shows keeps the shaft right of the robe's
	# edge down to the ground (a pixel in each row from SHAFT_ROWS_OVER_FEET.y to .x px over the feet), apart from the robe: the first
	# column on the staff's side clear in most of those rows, as in the start picture (the first re-paint lay on the robe's outline and
	# read as a thicker robe edge).
	var hurt: Image = _png[BossSim.Anim.HURT]
	for f: int in 3:
		var r: Rect2i = BossView.frame_rect(BossSim.Anim.HURT, 2, f)
		var rows: int = 0
		for up: int in range(SHAFT_ROWS_OVER_FEET.x, SHAFT_ROWS_OVER_FEET.y + 1):
			var y: int = r.position.y + BossView.BODY_FEET.y - up
			for x: int in range(r.position.x + STAFF_CUT_NORTH + 1, r.end.x):
				if hurt.get_pixel(x, y).a8 > 0 and _png_em[BossSim.Anim.HURT].get_pixel(x, y).a8 < BossView.GLOW_MIN_ALPHA:
					rows += 1
					break
		check_eq(rows, SHAFT_ROWS_OVER_FEET.y - SHAFT_ROWS_OVER_FEET.x + 1, "hurt north %d: the staff's shaft down to the ground%s" % [f,
			" (the stun's frame)" if f == Config.SKILL_STUN_FRAME else ""])
		var clear: int = 0
		for up2: int in range(SHAFT_ROWS_OVER_FEET.x, SHAFT_ROWS_OVER_FEET.y + 1):
			if hurt.get_pixel(r.position.x + STAFF_CUT_NORTH, r.position.y + BossView.BODY_FEET.y - up2).a8 == 0:
				clear += 1
		check(clear >= SHAFT_GAP_MIN_ROWS, "hurt north %d: the shaft apart from the robe (%d clear rows of %d)" % [f, clear,
			SHAFT_ROWS_OVER_FEET.y - SHAFT_ROWS_OVER_FEET.x + 1])
	# The cast east (v02: the brazier at the face): the blow holds it out in front (its flame all ahead of where the start picture's
	# flame sits before the face) and the face shows in the held and the blow columns (its candle gold in the hood's rows; the start
	# picture shows none).
	var hit_e: int = BossSim.hit_column(BossSim.Anim.CAST, 1)
	var key_px: Array[Vector2i] = []
	_flame(BossSim.Anim.CAST, 1, 0, key_px)
	var blow_px: Array[Vector2i] = []
	_flame(BossSim.Anim.CAST, 1, hit_e, blow_px)
	var key_front: int = -(1 << 20)
	for p: Vector2i in key_px:
		key_front = maxi(key_front, p.x)
	var blow_back: int = 1 << 20
	for p2: Vector2i in blow_px:
		blow_back = mini(blow_back, p2.x)
	check(blow_back > key_front, "the cast east's blow: its flame ahead of the face (from x %d; the start picture's flame to x %d)" % [
		blow_back, key_front])
	var hood_end: int = BossView.feet_in_cell(BossSim.Anim.CAST).y - HOOD_OVER_FEET + 1
	for col: int in [0, hit_e - 1, hit_e]:
		var gold: int = 0
		var ox: int = col * BossView.ACTION_CELL.x
		var oy: int = BossView.ACTION_CELL.y
		for y2: int in range(oy, oy + hood_end):
			for x2: int in range(ox, ox + BossView.ACTION_CELL.x):
				if _png[BossSim.Anim.CAST].get_pixel(x2, y2) == FACE_GOLD \
						and _png_em[BossSim.Anim.CAST].get_pixel(x2, y2).a8 < BossView.GLOW_MIN_ALPHA:
					gold += 1
		if col == 0:
			check_eq(gold, 0, "the cast east's start picture: the face behind the brazier")
		else:
			check(gold >= 4, "the cast east's column %d: the face shows (%d px)" % [col, gold])
	# The death south (v02: lying with the staff still upright beside it, the brazier 40 px up): the lying frames low, the brazier on
	# the ground.
	for f2: int in range(4, BossSim.FRAME_COUNTS[BossSim.Anim.DEATH]):
		var rd: Rect2i = BossView.frame_rect(BossSim.Anim.DEATH, 0, f2)
		var h: int = BossView.BODY_FEET.y - (opaque_box(_png[BossSim.Anim.DEATH], rd).position.y - rd.position.y)
		var fire: Array[Vector2i] = []
		_flame(BossSim.Anim.DEATH, 0, f2, fire)
		var top: int = 0
		for p3: Vector2i in fire:
			top = maxi(top, -p3.y)
		check(h <= LYING_MAX_PX, "death south %d lies low (%d px)" % [f2, h])
		check(not fire.is_empty() and top <= LYING_FIRE_MAX_PX, "death south %d: the staff fallen, its brazier on the ground (%d px up)" % [
			f2, top])

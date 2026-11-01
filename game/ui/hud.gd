class_name Hud
extends CanvasLayer
## Minimal HUD (M2a): the hotbar strip at the bottom centre (icons, stack counts, the selected slot)
## and, toggled with Tab, the rest of the inventory as a grid above it (display only). Drawn in code
## on its own canvas layer, so neither the camera nor the evening darkness touch it. No text: counts
## use a 3x5 pixel digit set drawn here (no font dependency). Colours from brief §4 (base and faith
## rows), no cool greys. The sacred-fire UI layer (game-concept §10) is not this; it is 2차.
## Layout values are IMPL.
## M4a (bind_player): the local player's HP and stamina bars at the top left; while down, two bars at the
## top centre (the time left before it dies, the revive so far, plus the give-up hold under them); while
## dead, the respawn countdown in seconds (the 3x5 digits drawn 3x) at the top centre (the death spot and
## its bag stay in view in the middle). PLACEHOLDERS drawn in
## code (no HUD art exists), kept small for 480x270 at integer scale (● R31).
## M6a: the local player's effects (buff, poison) as small icons under the stamina bar with a 1 px time-left bar
## (EffectMarks, PLACEHOLDERS), and the crafting panel (`crafting`, ui/crafting_panel.gd) that Main opens with Tab
## at a station.
## M7a (PLACEHOLDERS drawn in code): a durability bar in every slot whose item is worn (draw_durability: 14x2 px at the
## slot's bottom, gold over half, amber, rust under a quarter; a broken item's bar is all rust), the armour slot left of
## the hotbar (shown while the inventory is open or armour is worn: the worn piece and its bar, else a dim armour
## outline; a click on it while the inventory is open takes the armour off: armor_clicked), and the chest panel
## (`chest`, ui/chest_panel.gd) that Main opens with F at a storage chest.
## M8a: the merchant's shop panel (`shop`, ui/shop_panel.gd) that Main opens with F at the merchant.
## M9a (PLACEHOLDERS drawn in code, offline: only for a player with `skills_on`; a session draws none until M9c): the skill row
## right of the hotbar (SKILL_GAP apart): the slots 1 2 3 R (slot frames like the hotbar's, the skill's icon (SkillIcons), the key
## in the bottom-right corner like a stack count; a cooling slot is veiled from the top by the share of its cooldown left with a
## gold sweep line at the veil's edge; the choice slot 3 is locked (dark, a lock: not in the slice); a named skill not built
## yet (M9b) shows a dim diamond; a refused key's slot is framed red for Config.SKILL_REFUSED_SHOW_TICKS), and above it the class
## resource: a bar in the class's colour with an ivory tick where the signature's cost is, or (the herbalist, whose material is
## items) one pip per healing herb carried.

signal armor_clicked

const SLOT: int = 18                 # slot square, px (16 px icon + 1 px frame)
const GAP: int = 2                   # between slots
const BOTTOM: int = 4                # hotbar distance from the viewport's bottom edge
const ROW_GAP: int = 4               # between the hotbar and the inventory grid
const FILL: Color = Color(0.180, 0.165, 0.149, 0.86)     # #2e2a26 (§4 base), a little see-through
const FRAME: Color = Color8(0x4a, 0x42, 0x3a)            # §4 base
const FRAME_DARK: Color = Color8(0x1a, 0x17, 0x14)       # §4 base (ash black)
const SELECT: Color = Color8(0xf4, 0xc9, 0x5d)           # §4 faith gold
const SELECT_INNER: Color = Color8(0x9c, 0x6a, 0x1f)     # §4 faith
const DIGIT: Color = Color8(0xef, 0xe3, 0xc6)            # §4 faith ivory
const FINE_MARK: Color = Color8(0xf4, 0xc9, 0x5d)        # grade 상급 dot
## M4a bars (IMPL layout): HP and stamina at the top left, the down bars at the top centre.
const BAR_AT: Vector2i = Vector2i(4, 4)
const HP_BAR: Vector2i = Vector2i(60, 4)
const STAMINA_BAR: Vector2i = Vector2i(60, 2)
const DOWN_BAR: Vector2i = Vector2i(80, 3)
const DOWN_TOP: int = 24
const COUNT_SCALE: int = 3
const COUNT_TOP: int = 40
const HP_FILL: Color = Color8(0xb8, 0x43, 0x2f)          # warm rust red
const HP_LOST: Color = Color8(0x4a, 0x23, 0x1c)
const STAMINA_FILL: Color = Color8(0xf4, 0xc9, 0x5d)     # §4 faith gold
const STAMINA_LOW: Color = Color8(0x9c, 0x6a, 0x1f)      # §4 faith (below the dash cost)
const BLEED_FILL: Color = Color8(0xa3, 0x49, 0x2c)
const REVIVE_FILL: Color = Color8(0xf4, 0xc9, 0x5d)
const GIVE_UP_FILL: Color = Color8(0xef, 0xe3, 0xc6)
## IMPL (named in M6-fix): px between the HUD's effect icons, and from the stamina bar down to them.
const EFFECT_ICON_GAP: int = 3
## M6a: an effect's time-left bar (§4 faith ivory).
const EFFECT_LEFT: Color = Color8(0xef, 0xe3, 0xc6)
## M7a: the durability bar (IMPL: its place in a slot and its colours: §4 faith gold, the buff amber, the HP rust), and
## the armour slot's gap from the hotbar and the dim outline of an empty one.
const DUR_AT: Vector2i = Vector2i(2, 14)
const DUR_SIZE: Vector2i = Vector2i(14, 2)
const DUR_HIGH: Color = Color8(0xf4, 0xc9, 0x5d)
const DUR_MID: Color = Color8(0xe0, 0x86, 0x1a)
const DUR_LOW: Color = Color8(0xb8, 0x43, 0x2f)
const ARMOR_GAP: int = 6
const ARMOR_EMPTY: Color = Color(1.0, 1.0, 1.0, 0.28)
## M9a (IMPL): the skill row's gap from the hotbar, the icon's place in a slot, the resource bar's height and its gap above the
## slots (from the bar's frame to the slots), the herbalist's pips, and the colours: the cooldown veil (translucent ash black),
## the sweep line (faith gold), a refused slot's frame (rust), the locked slot's fill (ash black), the signature cost tick (faith
## ivory) and each class meter (paladin conviction faith gold, archer focus buff amber, cleric faith ivory, miner endurance
## copper, the herbalist's herbs healing red).
const SKILL_GAP: int = 6
const SKILL_ICON_AT: Vector2i = Vector2i(3, 3)
const SKILL_BAR_H: int = 2
const SKILL_BAR_GAP: int = 2
const SKILL_PIP: Vector2i = Vector2i(5, 2)
const SKILL_PIP_GAP: int = 1
const SKILL_VEIL: Color = Color(0.102, 0.090, 0.078, 0.72)
const SKILL_SWEEP: Color = Color8(0xf4, 0xc9, 0x5d)
const SKILL_REFUSED: Color = Color8(0xb8, 0x43, 0x2f)
const SKILL_LOCKED_FILL: Color = Color8(0x1a, 0x17, 0x14)
const SKILL_COST_MARK: Color = Color8(0xef, 0xe3, 0xc6)
const RESOURCE_COLOURS: Dictionary[String, Color] = {
	"paladin": Color8(0xf4, 0xc9, 0x5d), "archer": Color8(0xe0, 0x86, 0x1a), "cleric": Color8(0xef, 0xe3, 0xc6),
	"miner": Color8(0xc0, 0x6a, 0x2e), "herbalist": Color8(0xb8, 0x2e, 0x24),
}
## The inner area a cooldown veil covers (inside the slot's two frames: 14 x 14 at (2, 2)).
const SKILL_INNER: Rect2i = Rect2i(2, 2, 14, 14)
## 3x5 digits, rows top to bottom, "1" = lit. Plain Arrays (see items/item_icons.gd MAPS).
const DIGITS: Array[Array] = [
	["111", "101", "101", "101", "111"], ["010", "110", "010", "010", "111"], ["111", "001", "111", "100", "111"],
	["111", "001", "011", "001", "111"], ["101", "101", "111", "001", "001"], ["111", "100", "111", "001", "111"],
	["111", "100", "111", "101", "111"], ["111", "001", "010", "010", "010"], ["111", "101", "111", "101", "111"],
	["111", "101", "111", "001", "111"],
]

var inventory: Inventory
## The inventory grid above the hotbar is shown (Tab).
var open: bool = false
var canvas: Node2D
## M4a: the local player whose vitals the bars show (null: no bars).
var player: Player
## M6a: the crafting panel (ui/crafting_panel.gd), drawn over the rest.
var crafting: CraftingPanel
## M7a: the storage chest panel (ui/chest_panel.gd).
var chest: ChestPanel
## M8a: the shop panel (ui/shop_panel.gd).
var shop: ShopPanel
var _shown: String = ""


func _init() -> void:
	layer = 10
	name = &"Hud"
	canvas = Node2D.new()
	canvas.name = &"Canvas"
	add_child(canvas)
	canvas.draw.connect(_draw_hud)
	crafting = CraftingPanel.new()
	add_child(crafting)
	chest = ChestPanel.new()
	add_child(chest)
	shop = ShopPanel.new()
	add_child(shop)


func _ready() -> void:
	get_viewport().size_changed.connect(canvas.queue_redraw)


## Shows `inv` (the local player's inventory).
func bind(inv: Inventory) -> void:
	if inventory != null and inventory.changed.is_connected(canvas.queue_redraw):
		inventory.changed.disconnect(canvas.queue_redraw)
		inventory.changed.disconnect(_refresh_crafting)
	inventory = inv
	if inventory != null:
		inventory.changed.connect(canvas.queue_redraw)
		inventory.changed.connect(_refresh_crafting)
	chest.inventory = inv
	canvas.queue_redraw()


## M6a: the open crafting panel follows the inventory (unlocks, dimmed rows).
func _refresh_crafting() -> void:
	if crafting.is_open():
		crafting.refresh()
	if chest.is_open():
		chest.queue_redraw()
	if shop.is_open():
		shop.queue_redraw()  # M8a: the money held, the sell marks


## M4a: shows `p`'s HP, stamina, down and respawn state.
func bind_player(p: Player) -> void:
	player = p
	_shown = ""
	canvas.queue_redraw()


func _process(_delta: float) -> void:
	var key: String = vitals_key() + "|" + skills_key()
	if key != _shown:
		_shown = key
		canvas.queue_redraw()


## M9a: what the skill row shows now (redrawn when it changes): per slot its veil height and refusal mark, the resource.
func skills_key() -> String:
	if player == null or not is_instance_valid(player) or not player.skills_on:
		return ""
	var parts: PackedStringArray = [player.class_id(), str(Skills.resource_of(player))]
	for slot: int in SkillState.SLOT_COUNT:
		parts.append("%d/%d" % [skill_veil_rows(player, slot), 1 if player.skills.shows_refusal(slot) else 0])
	return "/".join(parts)


## M9a: the rows of a slot's inner area its cooldown veil covers (0 = ready): the share of the cooldown left, rounded up.
static func skill_veil_rows(p: Player, slot: int) -> int:
	var left: int = p.skills.cooldown(slot)
	if left <= 0:
		return 0
	var full: int = maxi(Skills.cooldown_ticks(Skills.kit_skill(p.class_id(), slot)), left)
	return clampi(ceili(float(left) / full * SKILL_INNER.size.y), 1, SKILL_INNER.size.y)


## What the bars show now (redrawn when it changes).
func vitals_key() -> String:
	if player == null or not is_instance_valid(player):
		return ""
	var v: Vitals = player.vitals
	return "%d/%d/%d/%d/%d/%d/%d/%d" % [v.life, v.hp, v.stamina, v.life_ticks, v.revive_ticks, v.give_up_ticks,
		effect_fill(v.buff_ticks, Config.BUFF_TICKS), effect_fill(v.poison_ticks, Config.POISON_TICKS)]


## M6a: the time-left bar's width (px, 0..EffectMarks.SIZE) for `ticks` left of an effect whose longest
## duration is the largest of `durations` (by grade); -1 when it is not on.
static func effect_fill(ticks: int, durations: PackedInt32Array) -> int:
	if ticks <= 0:
		return -1
	var longest: int = 1
	for d: int in durations:
		longest = maxi(longest, d)
	return clampi(ceili(float(ticks) / longest * EffectMarks.SIZE), 1, EffectMarks.SIZE)


## M6a: the top-left of the HUD's effect icon `i` (in EffectMarks.kinds_of order), EFFECT_ICON_GAP below the
## stamina bar and apart.
static func effect_icon_at(i: int) -> Vector2i:
	return BAR_AT + Vector2i(i * (EffectMarks.SIZE + EFFECT_ICON_GAP), HP_BAR.y + 3 + STAMINA_BAR.y + EFFECT_ICON_GAP)


## The respawn countdown in whole seconds (rounded up) for a dead player's vitals.
static func respawn_seconds(v: Vitals) -> int:
	return ceili(float(maxi(Config.RESPAWN_TICKS - v.life_ticks, 0)) / Config.NET_TICK_RATE)


func set_open(value: bool) -> void:
	open = value
	canvas.queue_redraw()


func toggle_open() -> void:
	set_open(not open)


## Top-left of slot `i` in viewport px for a view of `view` px (hotbar at the bottom centre, the other
## slots in rows of hotbar_size above it, bottom row first).
static func slot_origin(i: int, hotbar: int, view: Vector2i) -> Vector2i:
	var width: int = hotbar * SLOT + (hotbar - 1) * GAP
	var left: int = (view.x - width) / 2
	var bottom: int = view.y - BOTTOM - SLOT
	if i < hotbar:
		return Vector2i(left + i * (SLOT + GAP), bottom)
	var k: int = i - hotbar
	var row: int = k / hotbar
	var col: int = k % hotbar
	return Vector2i(left + col * (SLOT + GAP), bottom - ROW_GAP - SLOT - row * (SLOT + GAP))


func view_size() -> Vector2i:
	return Vector2i(canvas.get_viewport_rect().size)


func _draw_hud() -> void:
	_draw_vitals()
	_draw_skill_row()  # M9a
	if inventory == null:
		return
	var view: Vector2i = view_size()
	var count: int = inventory.size() if open else inventory.hotbar_size
	for i: int in count:
		var o: Vector2i = slot_origin(i, inventory.hotbar_size, view)
		_draw_slot(o, inventory.stack_at(i), i == inventory.selected)
	if open or inventory.armor != null:
		_draw_armor_slot(armor_slot_origin(inventory.hotbar_size, view))


## M7a: top-left of the armour slot (left of the hotbar's first slot, ARMOR_GAP apart).
static func armor_slot_origin(hotbar: int, view: Vector2i) -> Vector2i:
	return slot_origin(0, hotbar, view) - Vector2i(ARMOR_GAP + SLOT, 0)


## M9a: top-left of skill slot `slot` (Skills.Slot: 1 2 3 R from the left), SKILL_GAP right of the hotbar's last slot.
static func skill_slot_origin(slot: int, hotbar: int, view: Vector2i) -> Vector2i:
	var last: Vector2i = slot_origin(hotbar - 1, hotbar, view)
	return Vector2i(last.x + SLOT + SKILL_GAP + slot * (SLOT + GAP), last.y)


## M9a: the resource bar's inside (its 1 px dark frame around it): over the skill row, one px in from its ends.
static func skill_bar_rect(hotbar: int, view: Vector2i) -> Rect2i:
	var o: Vector2i = skill_slot_origin(0, hotbar, view)
	var w: int = SkillState.SLOT_COUNT * SLOT + (SkillState.SLOT_COUNT - 1) * GAP
	return Rect2i(Vector2i(o.x + 1, o.y - SKILL_BAR_GAP - 1 - SKILL_BAR_H), Vector2i(w - 2, SKILL_BAR_H))


## M9a: how many herb pips fit the bar.
static func skill_pips(hotbar: int, view: Vector2i) -> int:
	return (skill_bar_rect(hotbar, view).size.x + SKILL_PIP_GAP) / (SKILL_PIP.x + SKILL_PIP_GAP)


## M9a: the x (from the bar's left) of the ivory tick marking the signature's cost on a bar `w` px wide for a meter of `cap`.
static func skill_cost_x(cost: int, cap: int, w: int) -> int:
	return clampi(ceili(float(cost) * w / maxi(cap, 1)) - 1, 0, w - 1)


## M9a: the skill row (see the class comment).
func _draw_skill_row() -> void:
	if player == null or not is_instance_valid(player) or not player.skills_on:
		return
	var view: Vector2i = view_size()
	var hotbar: int = inventory.hotbar_size if inventory != null else Config.HOTBAR_SLOTS
	var class_id: String = player.class_id()
	for slot: int in SkillState.SLOT_COUNT:
		var o: Vector2i = skill_slot_origin(slot, hotbar, view)
		var r: Rect2i = Rect2i(o, Vector2i(SLOT, SLOT))
		var locked: bool = slot == Skills.Slot.CHOICE
		canvas.draw_rect(Rect2(r), SKILL_LOCKED_FILL if locked else FILL)
		var refused: bool = player.skills.shows_refusal(slot)
		_frame(r, SKILL_REFUSED if refused else FRAME_DARK)
		_frame(r.grow(-1), SKILL_REFUSED if refused else FRAME)
		var tex: Texture2D = SkillIcons.lock_texture() if locked else SkillIcons.texture_for(Skills.kit_skill(class_id, slot))
		canvas.draw_texture(tex, Vector2(o + SKILL_ICON_AT))
		var rows: int = skill_veil_rows(player, slot)
		if rows > 0:
			var veil: Rect2i = Rect2i(o + SKILL_INNER.position, Vector2i(SKILL_INNER.size.x, rows))
			canvas.draw_rect(Rect2(veil), SKILL_VEIL)
			canvas.draw_rect(Rect2(Vector2(veil.position.x, veil.end.y - 1), Vector2(veil.size.x, 1)), SKILL_SWEEP)
		_draw_key(slot, o + Vector2i(SLOT - 3, SLOT - 3))
	var bar: Rect2i = skill_bar_rect(hotbar, view)
	var colour: Color = RESOURCE_COLOURS.get(class_id, SKILL_COST_MARK)
	var cap: int = Skills.resource_cap(class_id)
	if cap > 0:
		_bar(bar.position, bar.size, float(player.skills.resource) / cap, colour, FILL)
		var cx: int = skill_cost_x(Skills.signature_cost(class_id), cap, bar.size.x)
		canvas.draw_rect(Rect2(Vector2(bar.position.x + cx, bar.position.y), Vector2(1, bar.size.y)), SKILL_COST_MARK)
		return
	# The herbalist: one pip per healing herb carried (the bar's frame, the pips lit from the left).
	canvas.draw_rect(Rect2(bar.grow(1)), FRAME_DARK)
	var have: int = Skills.resource_of(player)
	for i: int in skill_pips(hotbar, view):
		var at: Vector2 = Vector2(bar.position.x + i * (SKILL_PIP.x + SKILL_PIP_GAP), bar.position.y)
		canvas.draw_rect(Rect2(at, Vector2(SKILL_PIP)), colour if i < have else FILL)


## M9a: a skill slot's key (1 2 3 in the HUD's digits, R in SkillIcons.R_GLYPH) with its shadow, bottom-right at `bottom_right`.
func _draw_key(slot: int, bottom_right: Vector2i) -> void:
	var rows: Array = DIGITS[slot + 1] if slot < Skills.Slot.SIGNATURE else SkillIcons.R_GLYPH
	var x: int = bottom_right.x - 2
	var y: int = bottom_right.y - 4
	for pass_i: int in 2:
		var color: Color = FRAME_DARK if pass_i == 0 else DIGIT
		var shift: int = 1 if pass_i == 0 else 0
		for dy: int in 5:
			for dx: int in 3:
				if str(rows[dy])[dx] == "1":
					canvas.draw_rect(Rect2(Vector2(x + dx + shift, y + dy + shift), Vector2.ONE), color)


## M7a: the armour slot: the worn piece (and its bar), else a dim armour outline.
func _draw_armor_slot(o: Vector2i) -> void:
	var r: Rect2i = Rect2i(o, Vector2i(SLOT, SLOT))
	canvas.draw_rect(Rect2(r), FILL)
	_frame(r, FRAME_DARK)
	_frame(r.grow(-1), FRAME)
	var tex: Texture2D = ItemIcons.texture_for(&"armor_t1")
	if inventory.armor == null:
		if tex != null:
			canvas.draw_texture(tex, Vector2(o + Vector2i(1, 1)), ARMOR_EMPTY)
		return
	var worn: Texture2D = ItemIcons.texture_for(inventory.armor.id)
	if worn != null:
		canvas.draw_texture(worn, Vector2(o + Vector2i(1, 1)))
	if inventory.armor.worn():
		draw_durability(canvas, o, inventory.armor.durability, inventory.armor.max_durability())


## M7a: a durability bar on `ci` in the slot at `o` for `left` of `full` points (nothing when full or no durability):
## DUR_SIZE at DUR_AT over the ash black, gold over half, amber over a quarter, rust under; broken = all rust.
static func draw_durability(ci: CanvasItem, o: Vector2i, left: int, full: int) -> void:
	if full <= 0 or left >= full:
		return
	var at: Vector2 = Vector2(o + DUR_AT)
	if left <= 0:
		ci.draw_rect(Rect2(at, Vector2(DUR_SIZE)), DUR_LOW)
		return
	ci.draw_rect(Rect2(at, Vector2(DUR_SIZE)), FRAME_DARK)
	var ratio: float = float(left) / full
	var w: int = clampi(ceili(ratio * DUR_SIZE.x), 1, DUR_SIZE.x)
	var c: Color = DUR_HIGH if ratio > 0.5 else (DUR_MID if ratio > 0.25 else DUR_LOW)
	ci.draw_rect(Rect2(at, Vector2(w, DUR_SIZE.y)), c)


## M7a: a click on the armour slot while the inventory is open takes the worn armour off (Main).
func _input(event: InputEvent) -> void:
	if not open or inventory == null or not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var o: Vector2i = armor_slot_origin(inventory.hotbar_size, view_size())
	if Rect2(Rect2i(o, Vector2i(SLOT, SLOT))).has_point(canvas.get_local_mouse_position()):
		armor_clicked.emit()
		get_viewport().set_input_as_handled()


func _draw_slot(o: Vector2i, stack: ItemStack, selected: bool) -> void:
	var r: Rect2i = Rect2i(o, Vector2i(SLOT, SLOT))
	canvas.draw_rect(Rect2(r), FILL)
	_frame(r, SELECT if selected else FRAME_DARK)
	_frame(r.grow(-1), SELECT_INNER if selected else FRAME)
	if stack == null:
		return
	var tex: Texture2D = ItemIcons.texture_for(stack.id)
	if tex != null:
		canvas.draw_texture(tex, Vector2(o + Vector2i(1, 1)))
	if stack.grade == ItemDB.Grade.FINE:
		canvas.draw_rect(Rect2(Vector2(o + Vector2i(2, 2)), Vector2(2, 2)), FINE_MARK)
	if stack.count > 1:
		_draw_number(stack.count, o + Vector2i(SLOT - 3, SLOT - 3))
	if stack.worn():
		draw_durability(canvas, o, stack.durability, stack.max_durability())  # M7a


## M4a: the HP and stamina bars, the down bars, the respawn countdown.
func _draw_vitals() -> void:
	if player == null or not is_instance_valid(player):
		return
	var v: Vitals = player.vitals
	var view: Vector2i = view_size()
	_bar(BAR_AT, HP_BAR, float(v.hp) / Config.PLAYER_HP_MAX, HP_FILL, HP_LOST)
	var st_color: Color = STAMINA_FILL if v.stamina >= Config.DASH_STAMINA else STAMINA_LOW
	_bar(BAR_AT + Vector2i(0, HP_BAR.y + 3), STAMINA_BAR, float(v.stamina) / Config.STAMINA_MAX, st_color, FILL)
	# M6a: an icon per effect (EffectMarks), its time left as a 1 px bar under it.
	var kinds: Array[int] = EffectMarks.kinds_of(v)
	for i: int in kinds.size():
		var at: Vector2i = effect_icon_at(i)
		canvas.draw_texture(EffectMarks.texture(kinds[i]), Vector2(at))
		var fill: int = effect_fill(v.buff_ticks, Config.BUFF_TICKS) if kinds[i] == EffectMarks.Kind.BUFF \
			else effect_fill(v.poison_ticks, Config.POISON_TICKS)
		canvas.draw_rect(Rect2(Vector2(at + Vector2i(0, EffectMarks.SIZE + 1)), Vector2(EffectMarks.SIZE, 1)), FRAME_DARK)
		canvas.draw_rect(Rect2(Vector2(at + Vector2i(0, EffectMarks.SIZE + 1)), Vector2(fill, 1)), EFFECT_LEFT)
	if v.life == Vitals.Life.DOWN:
		var at: Vector2i = Vector2i((view.x - DOWN_BAR.x) / 2, DOWN_TOP)
		_bar(at, DOWN_BAR, 1.0 - float(v.life_ticks) / Config.DOWN_TICKS, BLEED_FILL, FILL)
		_bar(at + Vector2i(0, DOWN_BAR.y + 3), DOWN_BAR, clampf(float(v.revive_ticks) / Config.REVIVE_TICKS, 0.0, 1.0),
			REVIVE_FILL, FILL)
		if v.give_up_ticks > 0:
			_bar(at + Vector2i(0, 2 * (DOWN_BAR.y + 3)), Vector2i(DOWN_BAR.x, 1),
				float(v.give_up_ticks) / Config.GIVE_UP_HOLD_TICKS, GIVE_UP_FILL, FILL)
	elif v.life == Vitals.Life.DEAD:
		var n: int = respawn_seconds(v)
		var w: int = (str(n).length() * 4 - 1) * COUNT_SCALE
		_draw_number_scaled(n, Vector2i((view.x - w) / 2, COUNT_TOP), COUNT_SCALE)


## A bar at `at` of `size` filled `ratio` (0..1) with `fill` over `back`, in a 1 px dark frame.
func _bar(at: Vector2i, size: Vector2i, ratio: float, fill: Color, back: Color) -> void:
	var r: Rect2i = Rect2i(at - Vector2i.ONE, size + Vector2i(2, 2))
	canvas.draw_rect(Rect2(r), FRAME_DARK)
	canvas.draw_rect(Rect2(Vector2(at), Vector2(size)), back)
	var w: int = clampi(ceili(clampf(ratio, 0.0, 1.0) * size.x), 0, size.x)
	if w > 0:
		canvas.draw_rect(Rect2(Vector2(at), Vector2(w, size.y)), fill)


## `n` in the 3x5 digits drawn `zoom` times, top-left at `at`, with a dark shadow.
func _draw_number_scaled(n: int, at: Vector2i, zoom: int) -> void:
	var x: int = at.x
	for ch: String in str(n):
		var rows: Array = DIGITS[ch.to_int()]
		for pass_i: int in 2:
			var color: Color = FRAME_DARK if pass_i == 0 else DIGIT
			var shift: int = zoom / 2 if pass_i == 0 else 0
			for dy: int in 5:
				for dx: int in 3:
					if str(rows[dy])[dx] == "1":
						canvas.draw_rect(Rect2(Vector2(x + dx * zoom + shift, at.y + dy * zoom + shift), Vector2(zoom, zoom)),
							color)
		x += 4 * zoom


## A 1 px frame just inside `r` (whole pixels: four filled strips).
func _frame(r: Rect2i, color: Color) -> void:
	canvas.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), color)
	canvas.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), color)
	canvas.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), color)
	canvas.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), color)


## Draws `n` right-aligned so its bottom-right pixel is at `bottom_right`, with a dark shadow.
func _draw_number(n: int, bottom_right: Vector2i) -> void:
	var text: String = str(n)
	var x: int = bottom_right.x - (text.length() * 4 - 1) + 1
	var y: int = bottom_right.y - 5 + 1
	for ch: String in text:
		var rows: Array = DIGITS[ch.to_int()]
		for dy: int in 5:
			for dx: int in 3:
				if str(rows[dy])[dx] == "1":
					canvas.draw_rect(Rect2(Vector2(x + dx + 1, y + dy + 1), Vector2.ONE), FRAME_DARK)
		for dy: int in 5:
			for dx: int in 3:
				if str(rows[dy])[dx] == "1":
					canvas.draw_rect(Rect2(Vector2(x + dx, y + dy), Vector2.ONE), DIGIT)
		x += 4

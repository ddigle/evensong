class_name Config
extends RefCounted
## Game-wide constants.
##
## Three kinds, kept apart so the human can review them (game/README.md "임시값"):
##   ●  decided in docs/ (binding)
##   PROVISIONAL  a docs proposal (○) or open question (?) that M1 needs a value for. Each one names
##                the doc that leaves it open. Change it only after the human decides.
##   IMPL  an implementation choice made by an agent (not a design decision).

# --- ● decided ------------------------------------------------------------------------------

## ● 16px tiles (gameplay-design §3.1, R18).
const TILE: int = 16
## ● internal resolution 480x270, viewport stretch, integer scale, aspect expand (game-concept §7·§13, R31).
const VIEW_SIZE: Vector2i = Vector2i(480, 270)
## ● default window = 4x at 1080p (game-concept §7, R31).
const WINDOW_SIZE: Vector2i = Vector2i(1920, 1080)
## ● up to 9 players (game-concept §7, R11). Enforced by the host (stage G3).
const MAX_PLAYERS: int = 9
## ● slice classes (game-concept §12, R23).
const CLASSES: PackedStringArray = ["paladin", "miner", "archer", "cleric", "herbalist"]
## ● character frames 32x32, feet on frame row y=31 (concept-art-brief §5.6, R20·R26).
const CHAR_FRAME: Vector2i = Vector2i(32, 32)

# --- PROVISIONAL (○ / ?) --------------------------------------------------------------------

## PROVISIONAL (○ surface size not decided, gameplay-design §3.1 R12 "경계 있는 하나의 연속 맵").
## Surface start area in tiles.
const MAP_SIZE: Vector2i = Vector2i(128, 96)
## PROVISIONAL (? altar safe radius not decided, game-concept §7·§9.3; spike used 7 tiles = 112 px).
const SAFE_RADIUS_TILES: int = 7
## PROVISIONAL (○ R29 altar footprint 3x3 tiles, concept-art-brief §5.7).
const ALTAR_FOOTPRINT: Vector2i = Vector2i(3, 3)
## PROVISIONAL (○ fields inside the altar light, game-concept §9.7 / gameplay-design §3.8).
## Tilled soil patches the generator places inside the safe radius: count and size range (tiles).
const SOIL_PATCH_COUNT: int = 3
const SOIL_PATCH_MIN: Vector2i = Vector2i(2, 2)
const SOIL_PATCH_MAX: Vector2i = Vector2i(4, 3)
## PROVISIONAL (○ 2~3 fixed corruption zones, game-concept §12: an unmarked bullet in a section
## headed "제안"; the count inside that range, their size and distance are not decided either).
const ASH_ZONE_COUNT: int = 3
const ASH_ZONE_RADIUS_MIN: int = 5
const ASH_ZONE_RADIUS_MAX: int = 8
## PROVISIONAL (not in docs): grass tiles kept between the safe radius and any ash cell.
const ASH_CLEARANCE_TILES: int = 4
## PROVISIONAL (not in docs; M1 spec asks for ~64-80 px/s): walk speed in px/s, the same in all
## 8 directions (diagonals are normalised). 72 px/s = 4.5 tiles/s.
const WALK_SPEED: float = 72.0
## PROVISIONAL (? surface light: day/night vs eternal dusk, gameplay-design §3.1, game-concept §7).
## M1 shows one constant evening (no cycle), switchable off with F4. Warm grey so shadows stay
## brown, never blue (game-concept §10). Spike light module value.
const EVENING_COLOR: Color = Color(0.40, 0.34, 0.31)
## PROVISIONAL (spike light module values): altar light colour and energy, added on top of the
## evening (inside ~ evening + energy * colour = about the painted colours).
const ALTAR_LIGHT_COLOR: Color = Color(1.0, 0.97, 0.91)
const ALTAR_LIGHT_ENERGY: float = 0.65
## PROVISIONAL (? safe radius edge not decided; spike suggested a dithered edge for the ground
## and a hard-edged copy for characters): width of the ground light's dithered band in px,
## inside the radius (no lit pixel ever lies outside the safe zone).
const SAFE_EDGE_BAND_PX: int = 16
## PROVISIONAL (not in docs; M1 spec "20-30 Hz"): host player-state batches per second. The host
## sends one every NET_TICK_RATE / NET_STATE_HZ physics ticks while anyone's state changes, then one
## reliable keyframe, then nothing until someone moves again.
const NET_STATE_HZ: int = 20
## PROVISIONAL (not in docs; M1 spec "~100 ms"): how far behind the newest host state a client
## draws the other players (interpolation buffer). 2 batch intervals at 20 Hz.
const NET_INTERP_DELAY_MS: int = 100
## PROVISIONAL (? not decided whether two players may play the same class; the party UI proposal is
## 3x3 = one per class, gameplay-design §5 ○). M1 allows duplicates; true makes the host refuse a
## class that is already taken (refusal "class_taken").
const NET_UNIQUE_CLASSES: bool = false
## PROVISIONAL (not in docs; the nearest rule is "부활 지점: 제단", gameplay-design §2.6·§5 ○): a
## player appears on a free SPAWN_SLOTS place around the altar (alone, as host or joining) facing
## this way.
const SPAWN_FACING: RigData.Dir = RigData.Dir.SOUTH

# --- PROVISIONAL, M2a (items, hotbar, aim, body actions) ------------------------------------

## PROVISIONAL (not in docs; gameplay-design §1 ○ only says weapons and tools are switched on the
## hotbar with Q / E): hotbar slots per player.
const HOTBAR_SLOTS: int = 8
## PROVISIONAL (not in docs): inventory slots per player; the hotbar is the first HOTBAR_SLOTS of them.
const INVENTORY_SLOTS: int = 24
## PROVISIONAL (not in docs): stack size per item kind (items/item_db.gd).
const STACK_TOOL: int = 1
const STACK_MATERIAL: int = 99
const STACK_GATHERABLE: int = 99
## PROVISIONAL (not in docs; ● gameplay-design §2.1 R12 only decides the aim type, "에임형 (마우스
## 방향 스킬샷)"): the player faces the mouse while aiming = the use button held, an action
## playing, or the mouse moved within the last AIM_HOLD_SEC seconds. Otherwise the facing follows
## the movement as in M1 (Movement.facing_for).
const AIM_HOLD_SEC: float = 1.0
## PROVISIONAL (not in docs): length of one body action frame in simulation ticks (6 = 0.1 s). An
## action lasts its frame count times this (pickaxe 0.6 s, sword 0.8 s, throw 0.7 s).
const ACTION_FRAME_TICKS: int = 6
## PROVISIONAL (not in docs): a body action locks movement (and the facing) until it ends.
const ACTION_LOCKS_MOVEMENT: bool = true
## PROVISIONAL (○ gameplay-design §3.2 "홀드하면 연속", said for mining): holding the use button
## starts the action again as soon as it ends.
const ACTION_REPEAT_WHILE_HELD: bool = true

# --- PROVISIONAL, M2b (gatherables, drops, pickup) ------------------------------------------

## PROVISIONAL (○ brief §5.7 slice range "야생 약초·균류 채집물" and game-concept §12 name the wild
## herbs and fungi, not how many or where; the stones are not in the docs: the agent took them from
## the 04-env/prompts.md batch label "칸 0~19 채집물"): gatherables SurfaceGen scatters over clean
## grass outside the altar light, per item id, in this order. The three wild herbs (the herbs of the
## ● R28 crops: healing, buff, poison; wild ones are the agent's reading of "야생 약초"), the four
## clean mushrooms and the four clean stones. The herb clump is an item but is not scattered.
const GATHER_ON_GRASS: Dictionary[StringName, int] = {
	&"wild_healing": 8, &"wild_buff": 8, &"wild_poison": 8,
	&"mushroom_a": 4, &"mushroom_b": 4, &"mushroom_c": 4, &"mushroom_d": 4,
	&"stone_a": 6, &"stone_b": 5, &"stone_c": 5, &"stone_mossy": 4,
}
## PROVISIONAL (04-env/prompts.md marks these three "오염 쪽"; counts not in docs): gatherables on ash.
const GATHER_ON_ASH: Dictionary[StringName, int] = {&"mushroom_ash": 6, &"stone_veined": 4, &"stone_mould": 4}
## PROVISIONAL (not in docs; the stage-4 mockups put the gatherables outside the light, the fields
## inside): gatherables lie at least this many tiles beyond the safe radius (cell centres).
const GATHER_CLEARANCE_TILES: int = 1
## PROVISIONAL (not in docs): gatherables lie at least this many tiles inside the map edge
## (SurfaceGen.gatherable_spot_ok).
const GATHER_EDGE_TILES: int = 2
## PROVISIONAL (○ gameplay-design §3.2 "마우스 방향의 인접 타일", said for mining; §3.4 ○ "F로 식물·드롭
## 줍기"): F, a use and the debug drop act on the target tile, which must be within this many tiles
## (Chebyshev) of the feet tile and not the feet tile itself. The host refuses anything further.
const REACH_TILES: int = 1

# --- PROVISIONAL, M3a (maps, the first dungeon, mining, torches) ----------------------------

## PROVISIONAL (○ game-concept §12 "지상 시작 구역 + 첫 던전 1개" and gameplay-design §3.1 ○ "던전 =
## 별도 맵": that it is a separate map is a proposal, its size is not in the docs): the first dungeon's
## size in tiles. About 2 x 3 screens.
const DUNGEON_SIZE: Vector2i = Vector2i(64, 48)
## PROVISIONAL (not in docs): rooms the generator tries to place (the arrival room and the shrine room
## included), their size range in tiles (walls not counted; the top row of a room is the face of its
## north wall), the rock kept between two rooms and to the map edge, and the width of corridors.
const DUNGEON_ROOM_COUNT: int = 7
const DUNGEON_ROOM_MIN: Vector2i = Vector2i(7, 6)
const DUNGEON_ROOM_MAX: Vector2i = Vector2i(12, 9)
const DUNGEON_ROOM_GAP: int = 3
const DUNGEON_CORRIDOR_WIDTH: int = 3
## PROVISIONAL (not in docs): unbreakable bedrock ring around the dungeon, in tiles.
const DUNGEON_BORDER_TILES: int = 2
## PROVISIONAL (○ brief §5.7 slice range "광맥 1~2종"; which kinds, how many and how big are not in the
## docs; the 04-env candidates are copper and iron): ore veins per kind and their size range in tiles.
const DUNGEON_VEINS: Dictionary[StringName, int] = {&"copper": 9, &"iron": 5}
const DUNGEON_VEIN_SIZE_MIN: int = 2
const DUNGEON_VEIN_SIZE_MAX: int = 5
## PROVISIONAL (not in docs; the 04-env dungeon mockup hangs wall torches on a room's north wall):
## decorative wall torches the generator hangs on room north walls, one every this many tiles, two
## beside the exit stairs in the arrival room, as decoration with a small light. A spot that is not
## plain rock with a face below moves to the nearest good one on that wall; every room whose north
## wall has a good spot gets at least one, and the arrival room always one (the exit is placed so
## that it leaves a spot, and the arrival room's torches come before the ore veins;
## DungeonGen._place_wall_torches, M3-fix). A wall torch falls with its wall when the wall is mined
## (Mining.strike).
const DUNGEON_WALL_TORCH_SPACING: int = 6
## PROVISIONAL (○ game-concept §12: the first dungeon is the first corruption source; the heretic
## shrine's size is not in the docs, the 04-env candidate heretic_shrine_v02 is 48 px wide): the
## shrine's footprint in tiles, kept in the room farthest from the arrival. Its fire is off and it
## cannot be destroyed in M3a (destroying it is M4).
const SHRINE_FOOTPRINT: Vector2i = Vector2i(3, 2)
## PROVISIONAL (not in docs; ○ gameplay-design §3.1 "지상의 입구로 진입"): the surface dungeon entrance's
## footprint and where SurfaceGen tries to put it: this many tiles from the altar footprint's top-left
## cell (east of the altar, outside its light); if that spot is not clear the generator searches
## outward for the nearest clear one.
const ENTRANCE_FOOTPRINT: Vector2i = Vector2i(2, 1)
const ENTRANCE_OFFSET_TILES: Vector2i = Vector2i(10, 1)
## PROVISIONAL (not in docs): the exit stairs in the dungeon (2 tiles of the arrival room's north wall
## face, below unbreakable rock). The arrival point is just south of them.
const EXIT_FOOTPRINT: Vector2i = Vector2i(2, 1)
## PROVISIONAL (not in docs; part of the arrival point above): a player arriving on a map stands in the
## middle of the tiles just south of the entrance / exit stairs, its feet this many px above that tile
## row's bottom edge (DungeonGen.arrival_below; named in M3-fix, the value M3a used).
const ARRIVAL_FEET_INSET_PX: int = 4
## PROVISIONAL (● gameplay-design §3.0 R11 miner row: everyone mines "느리고 1×1, 경도 상한", the miner
## "3×3 고속, 상위 경도"; gameplay-design §3.1 (no ●/○ mark) "벽 타일에 경도 등급. 곡괭이 등급이 경도
## 이상이어야 파괴 … 상위 광석은 상위 곡괭이"; the numbers are not in the docs): hardness grade of each wall
## kind / ore, the highest grade a common player and the miner can break, hits a tile takes before it
## breaks, and hits one pickaxe swing deals (the miner's swing counts double: "고속"). §3.1's pickaxe
## tiers are NOT modelled: there is one pickaxe (no grade) and the class cap below stands in for the
## pickaxe grade (README "임시값", for the human to confirm).
const HARDNESS_ROCK: int = 1
const HARDNESS_COPPER: int = 1
const HARDNESS_IRON: int = 2
const HARDNESS_CAP_COMMON: int = 1
const HARDNESS_CAP_MINER: int = 2
const WALL_HITS_ROCK: int = 6
const WALL_HITS_COPPER: int = 8
const WALL_HITS_IRON: int = 10
const MINING_POWER_COMMON: int = 1
const MINING_POWER_MINER: int = 2
## PROVISIONAL (not in docs): the swing lands on this frame of the pickaxe action (0-based; the 4th of
## 6 frames is where the pick hits the ground in 03-pixel base_body_v02_pickaxe).
const MINING_IMPACT_FRAME: int = 3
## PROVISIONAL (● the miner mines 3×3, R11; whether the 3×3 is centred on the hit tile or reaches away
## from the player is not in the docs): true = the 3×3 starts at the hit tile and extends away from the
## player (centred across the swing), false = centred on the hit tile.
const MINER_AREA_AWAY: bool = true
## PROVISIONAL (not in docs; ○ gameplay-design §3.2 "채굴 시 드롭은 인벤토리로 자동"): what breaking a
## rock tile gives (the stone gatherable; an ore tile gives its ore item instead); what does not fit
## the inventory lies on the broken tile as a drop.
const MINED_ROCK_ITEM: StringName = &"stone_a"
## PROVISIONAL (not in docs; the 04-env dungeon mockups are not darkened): the dungeon's darkness
## (CanvasModulate). It has no altar and so no altar light.
const DUNGEON_DARK_COLOR: Color = Color(0.13, 0.11, 0.10)
## PROVISIONAL (gameplay-design §3.0 ● R11 lists the torch in the basic kit, "기본 키트 (횃불, 발판)";
## how far it lights and whether it counts as safety are not in the docs: it is light only, the safe
## zone stays the altar's): a placed torch's light radius (px), colour and energy, and a decorative
## wall torch's radius and energy.
const TORCH_LIGHT_RADIUS_PX: int = 80
const TORCH_LIGHT_COLOR: Color = Color(1.0, 0.86, 0.62)
const TORCH_LIGHT_ENERGY: float = 0.95
const WALL_TORCH_LIGHT_RADIUS_PX: int = 48
const WALL_TORCH_LIGHT_ENERGY: float = 0.8

# --- PROVISIONAL, M4a (health, stamina, dash, basic attacks, death, the heretic, spawning) -----
# Offline first (M4a); M4b brings all of it to sessions, the host deciding. README "임시값" M4a.

## PROVISIONAL (○ gameplay-design §2.4 "HP + 방어력 … 스태미나(대시·방패)"; no numbers in the docs): a
## player's hit points and stamina. No armour or defence stat (equipment is M7): damage is taken whole
## (PLAYER_DEFENCE = 0).
const PLAYER_HP_MAX: int = 100
const PLAYER_DEFENCE: int = 0
const STAMINA_MAX: int = 100
## PROVISIONAL (not in docs): stamina comes back one point every STAMINA_REGEN_TICKS ticks (30 / s),
## starting STAMINA_REGEN_DELAY_TICKS after it was spent.
const STAMINA_REGEN_TICKS: int = 2
const STAMINA_REGEN_DELAY_TICKS: int = 30
## PROVISIONAL (○ gameplay-design §2.5 "모두 대시 1회 (스태미나)"; cost, cooldown, distance, speed and
## invulnerability are not in the docs): Space dashes once: costs DASH_STAMINA, lasts DASH_TICKS at
## DASH_SPEED px/s (= 40 px) in the held direction (the facing without one) with the same wall /
## fixture / altar collision as walking (Movement.step), cannot start again for DASH_COOLDOWN_TICKS,
## and while it lasts the player takes no damage when DASH_INVULNERABLE. It does not start during a
## body action, a stagger or while down.
const DASH_STAMINA: int = 35
const DASH_TICKS: int = 10
const DASH_SPEED: float = 240.0
const DASH_COOLDOWN_TICKS: int = 30
const DASH_INVULNERABLE: bool = true
## PROVISIONAL (not in docs): a hit staggers a player for HURT_TICKS (no moving, no new action or dash;
## the playing action is cut off) while base_body_v02_hurt plays at HURT_FRAME_TICKS a frame, and no
## further damage lands for HURT_INVULN_TICKS. The heretic uses the same stagger rule
## (HERETIC_HURT_FRAME_TICKS).
const HURT_FRAME_TICKS: int = 3
const HURT_TICKS: int = 18
const HURT_INVULN_TICKS: int = 30
## PROVISIONAL (not in docs): friendly fire. Off: players' attacks never hurt players.
const FRIENDLY_FIRE: bool = false
## PROVISIONAL (gameplay-design §2.6 ● R12 writes the flow: "다운 상태 → 아군이 F 홀드로 소생 (성직자는 즉시,
## 다른 클래스는 5초) → 30초 넘기면 사망"; recorded here as values): at 0 HP a player goes DOWN
## (base_body_v02_death, DEATH_FRAME_TICKS a frame, then lying); another player within REVIVE_REACH_PX
## holding F revives it, a cleric at once (REVIVE_TICKS_CLERIC 0), anyone else after REVIVE_TICKS; after
## DOWN_TICKS down it dies. The down timer keeps running during a revive; letting go resets the revive.
const DEATH_FRAME_TICKS: int = 6
const DOWN_TICKS: int = 30 * 60
const REVIVE_TICKS: int = 5 * 60
const REVIVE_TICKS_CLERIC: int = 0
## PROVISIONAL (not in docs): how near (feet to feet, px) a reviver stands, and the HP a revived player
## gets back.
const REVIVE_REACH_PX: float = 24.0
const REVIVE_HP: int = 30
## PROVISIONAL (not in docs; alone nobody can revive you): holding F this long while down gives up (dies
## at once) instead of waiting out DOWN_TICKS.
const GIVE_UP_HOLD_TICKS: int = 60
## PROVISIONAL (gameplay-design §2.6 ● "부활 지점: 제단", §5 ○; the delay and the HP are not in the docs):
## a dead player comes back after RESPAWN_TICKS at its altar spawn slot on the surface with RESPAWN_HP.
const RESPAWN_TICKS: int = 5 * 60
const RESPAWN_HP: int = PLAYER_HP_MAX
## PROVISIONAL (gameplay-design §2.6 ○ "스택마다 절반 또는 무작위 3종. 슬라이스에서 정한다"): what part of
## the inventory's materials and consumables (every kind but tools; tools and equipment stay) falls in
## the death bag. DEATH_DROP_HALF: half of every such stack (rounded up). DEATH_DROP_KINDS: every stack
## of DEATH_DROP_RANDOM_KINDS item kinds picked at random.
const DEATH_DROP_HALF: int = 0
const DEATH_DROP_KINDS: int = 1
const DEATH_DROP_RULE: int = DEATH_DROP_HALF
const DEATH_DROP_RANDOM_KINDS: int = 3
## PROVISIONAL (not in docs; gameplay-design §2.1 ● real-time, aimed; §1 ○ "좌클릭: 기본 공격 / 들고 있는
## 도구 사용", "광부는 곡괭이가 무기이자 도구"; the skill kit is ? §2.2): each class's basic attack is the
## weapon item of its class held in the hotbar, used with left click like any tool (anyone may use any
## weapon). Paladin sword (melee arc), archer bow (arrow), cleric holy light (bolt, the magic action),
## miner pickaxe (melee; it mines a wall instead when the target tile is a wall), herbalist sickle
## (melee; not in the docs).
const CLASS_WEAPONS: Dictionary[String, StringName] = {
	"paladin": &"sword", "archer": &"bow", "cleric": &"holy_light", "miner": &"pickaxe", "herbalist": &"sickle",
}
## PROVISIONAL (not in docs; supersedes M2a's empty start offline): the offline local player starts with
## its class weapon in this hotbar slot (0-based; the last, so the debug kit and --give keep their M2 /
## M3 slots). M4b: in a session the host gives every player its class weapon there when it joins.
const START_WEAPON_SLOT: int = 7
## PROVISIONAL (not in docs): attacks by weapon item: [kind (Combat.Kind: 0 melee, 1 arrow, 2 bolt),
## damage, reach px (melee: feet to feet; shots: travel), arc degrees (melee), hit frame (0-based frame
## of the body action that hits / lets go; the pickaxe's is MINING_IMPACT_FRAME, one impact for mining
## and fighting), shot speed px/s]. The attack rate is the action's length (Config.ACTION_FRAME_TICKS a
## frame, repeated while held).
const WEAPON_ATTACKS: Dictionary[StringName, Array] = {
	&"sword": [0, 14, 26.0, 120.0, 4, 0.0],
	&"pickaxe": [0, 10, 22.0, 90.0, 3, 0.0],
	&"sickle": [0, 8, 22.0, 120.0, 3, 0.0],
	&"bow": [1, 12, 160.0, 0.0, 6, 220.0],
	&"holy_light": [2, 10, 128.0, 0.0, 3, 150.0],
}
## PROVISIONAL (not in docs; ● game-concept §12 slice "이단 적 1종(근접)" in the 03-pixel hand-off): one
## heretic's hit points and the damage of its knife.
const HERETIC_HP: int = 40
const HERETIC_DAMAGE: int = 12
## PROVISIONAL (not in docs): chase speed (px/s, slower than walking so a player can get away).
const HERETIC_SPEED: float = 46.0
## PROVISIONAL (○ gameplay-design §2.3 aggro "위협" until M9; here the nearest player only): a heretic
## targets the nearest player on its map that is up, within HERETIC_SIGHT_PX with no wall between, and
## gives up beyond HERETIC_LEASH_PX from where it spawned (walks back home).
const HERETIC_SIGHT_PX: float = 112.0
const HERETIC_LEASH_PX: float = 256.0
## PROVISIONAL (not in docs): starts its attack when the target is this near (feet to feet), the knife
## lands on everyone up within HERETIC_HIT_REACH_PX in a HERETIC_HIT_ARC_DEG arc, and it waits
## HERETIC_ATTACK_COOLDOWN_TICKS after an attack.
const HERETIC_ATTACK_RANGE_PX: float = 22.0
const HERETIC_HIT_REACH_PX: float = 28.0
const HERETIC_HIT_ARC_DEG: float = 120.0
const HERETIC_ATTACK_COOLDOWN_TICKS: int = 45
## PROVISIONAL (? hit column, 03-pixel/prompts.md 13차 "M4에 넘길 것": candidates south 3-4, east 4-5,
## north 5-6): the attack sheet column (1 = the first played column) the knife lands on, south / east /
## north (west = east). The first of each pair.
const HERETIC_HIT_COLUMN: PackedInt32Array = [3, 4, 5]
## PROVISIONAL (not in docs; 13차 asks for the attack / hurt / death frame times): the telegraph (the
## knife raised, the columns before the hit column, the last of them held) lasts HERETIC_TELEGRAPH_TICKS
## in every direction; the rest of the attack plays at HERETIC_ATTACK_FRAME_TICKS a frame; hurt and death
## at their own frame times; a dead heretic lies HERETIC_CORPSE_TICKS more, then is gone.
const HERETIC_TELEGRAPH_TICKS: int = 30
const HERETIC_ATTACK_FRAME_TICKS: int = 6
const HERETIC_HURT_FRAME_TICKS: int = 3
const HERETIC_DEATH_FRAME_TICKS: int = 6
const HERETIC_CORPSE_TICKS: int = 120
## PROVISIONAL (not in docs): a hit staggers a heretic (hurt frames, its chase stops) but does not cut off
## an attack it has started (false), so a fast weapon cannot keep it from ever striking; true = it does.
const HERETIC_HURT_INTERRUPTS_ATTACK: bool = false
## PROVISIONAL (game-concept §9.3: the altar's safe radius = light, spawn suppression, corruption
## resistance; whether an enemy walks into the light is not written): false = a heretic never steps into
## the altar light, never targets or hurts a player inside it.
const HERETIC_ENTERS_LIGHT: bool = false
## PROVISIONAL (not in docs): what a heretic does when its target steps into the light: stands at the
## edge facing it this many seconds, then walks home (0 = turns back at once). M4-fix: the seconds count
## from when it started watching, hits included (a hit staggers it but does not start the wait over), so
## shooting it from inside the light cannot keep it at the edge (README "M4a 빛 가장자리").
const HERETIC_LIGHT_EDGE_WAIT_SEC: float = 4.0
## PROVISIONAL (not in docs; the M3a row keeps torches light only): true would make a torch's light count
## as the altar's for heretics (no entering, no targeting, no spawning). Off.
const TORCH_LIGHT_IS_SAFE: bool = false
## PROVISIONAL (game-concept §9.3 spawn suppression ●/○ as written there; numbers not in docs): heretics
## alive at once per map (surface, dungeon), ticks between spawn tries on a map with a player on it (the
## first one interval after the map is entered), the least distance (px) from every player, how far
## around the corruption zones the surface spawns reach (tiles), and how far (walking tiles from the
## arrival point) the dungeon spawns stay from the arrival room.
const HERETIC_CAP_SURFACE: int = 4
const HERETIC_CAP_DUNGEON: int = 6
const HERETIC_SPAWN_INTERVAL_TICKS: int = 480
const HERETIC_SPAWN_MIN_PLAYER_PX: float = 160.0
const HERETIC_SPAWN_ASH_REACH_TILES: int = 2
const HERETIC_SPAWN_ARRIVAL_MIN_TILES: int = 14
## PROVISIONAL (● gameplay-design §3.0 paladin row "오염 원천은 누구나 전투로 파괴 가능"; its HP is not in
## the docs): the heretic shrine's hit points. When broken it stays a broken (blocking) placeable and
## the dungeon spawns no more heretics (SHRINE_STOPS_SPAWNS; the docs make the first dungeon the first
## corruption source, game-concept §12; what breaking it does is not written).
const SHRINE_HP: int = 150
const SHRINE_STOPS_SPAWNS: bool = true
## PROVISIONAL (not in docs; M4-fix moved the first two here from the IMPL rows, values unchanged, because
## they decide whether a shot hits): a shot (arrow, bolt) is drawn SHOT_DRAW_LIFT_PX above its ground point
## and hits a body (a heretic; a player only with FRIENDLY_FIRE) when the drawn shot is inside the body's
## drawn box: BODY_HIT_RADIUS_PX either side of the feet, from the feet up BODY_HIT_HEIGHT_PX (the heretic
## sheets' figure: opaque rows 3..31 of the 32 px walk cell, measured). The aim is measured from where the
## shot is drawn leaving the shooter (Combat.aim_origin) to the mouse, so the drawn shot flies through the
## cursor and a click anywhere on the figure hits (README "M4-fix 화살 조준").
const BODY_HIT_RADIUS_PX: float = 8.0
const SHOT_DRAW_LIFT_PX: int = 12
const BODY_HIT_HEIGHT_PX: float = 28.0

# --- PROVISIONAL, M4b (combat in sessions: the host decides, README "임시값" M4b) ----------------

## PROVISIONAL (not in docs; ● host authority, game-concept §13): how a client draws the host's enemies.
## Positions, HP, hurt and death are drawn NET_INTERP_DELAY_MS behind the newest host state like the
## other players; true = a heretic's attack (the wind-up, the knife raised: the telegraph) is drawn from
## the newest state at once, without that delay, so a player sees it as early as the wire allows
## (net/net_combat.gd). false = the attack waits for the delay like the rest.
const NET_ENEMY_WINDUP_FRESH: bool = true

# --- PROVISIONAL, M6a (crafting, the alchemy table, potions, drinking, the potion throw, effects) ---
# Offline first (M6a); in a session crafting, drinking, throwing and effects stay off until M6b (as M3a and
# M4a did). README "임시값" M6a.

## PROVISIONAL (○ gameplay-design §3.5 "작업대 근처에서 Tab"; how near is not in the docs): Tab opens the
## crafting panel while the feet tile is within this many tiles (Chebyshev) of a station's footprint
## (items/crafting.gd). Farther, Tab shows the inventory as before (M2a).
const STATION_REACH_TILES: int = 2
## PROVISIONAL (○ gameplay-design §3.5 "레시피는 재료를 처음 획득했을 때 해금 (그라운디드 분석기 방식)"): true = a
## recipe shows in the panel once its player has had every one of its input items (any grade) in the
## inventory; false = every recipe of the station shows from the start. Default true: it is the one rule the
## docs propose, and in the slice it costs nothing (the inputs are the wild herbs, and picking them is the
## loop's first step), so the human can judge it in play; false is there for testing.
const RECIPES_UNLOCK_ON_FIRST_GET: bool = true
## PROVISIONAL (○ game-concept §9.7 "조제는 연금술대 자리의 조제대에서 한다"; its size is not in the docs): the
## alchemy table's footprint in tiles. The 48x32 04-env art (alchemy_table_v05) stands on it with its back
## half over the tile behind, like the shrine and the entrance arch (art taller than the footprint).
const ALCHEMY_FOOTPRINT: Vector2i = Vector2i(3, 1)
## PROVISIONAL (not in docs): a potion stack's size.
const STACK_POTION: int = 10
## PROVISIONAL (● game-concept §12 R28: one potion per crop, healing / buff / status; the amounts are not in
## the docs): wild herbs of a kind per potion (one potion out). The potion's grade is the herbs' grade.
const POTION_HERBS: int = 2
## PROVISIONAL (● gameplay-design §3.0 R11 herbalist row: FINE (상급) potions and status potions are the
## herbalist's; whether anyone else may brew the COMMON healing and buff potions is not written): true =
## anyone may (the row's "공용 수행" column limits the grade, not the verb), false = only the herbalist brews.
const COMMON_POTIONS_ANYONE: bool = true
## PROVISIONAL (not in docs): a healing potion's HP by grade [none, COMMON, FINE] (drunk or splashed).
const POTION_HEAL_HP: PackedInt32Array = [0, 30, 50]
## PROVISIONAL (not in docs; the one buff of M6a): the buff potion raises walking speed (not the dash) to this
## percent for this many ticks, by grade [none, COMMON, FINE].
const BUFF_SPEED_PCT: PackedInt32Array = [100, 125, 140]
const BUFF_TICKS: PackedInt32Array = [0, 20 * 60, 30 * 60]
## PROVISIONAL (○ gameplay-design §2.4 "상태이상: 약초사 담당. 중독·둔화·취약·출혈"; the one status effect of
## M6a is poison, the poison potion's; numbers not in docs): damage per poison tick by grade, ticks between
## two, and how long it lasts by grade (300 ticks = 10 poison ticks). It hits the HP without a stagger, an
## invulnerability or a defence, and does not cut off an action (a player's) or an attack (a heretic's).
const POISON_DAMAGE: PackedInt32Array = [0, 2, 3]
const POISON_INTERVAL_TICKS: int = 30
const POISON_TICKS: PackedInt32Array = [0, 300, 300]
## PROVISIONAL (not in docs): a buff or poison on someone who already has one: the time left becomes the
## longer of the two and the strength the larger (no stacking).
const EFFECT_REFRESH_KEEPS_STRONGER: bool = true
## PROVISIONAL (not in docs): a player's buff and poison end when it goes down (and so when it dies); a
## heretic's poison ends when it dies.
const EFFECTS_END_ON_DOWN: bool = true
## PROVISIONAL (not in docs; no drink art exists, 03-pixel has no drink action): drinking plays this body
## action (the cleric's magic action, "기도·치료" in brief §5.6) and the potion works on DRINK_EFFECT_FRAME
## (0-based); a hit before that cuts the drink off and nothing is used.
const DRINK_ANIM: int = RigData.Anim.MAGIC
const DRINK_EFFECT_FRAME: int = 3
## PROVISIONAL (not in docs): drinking a healing potion at full HP is refused (nothing used); false = it is
## drunk and wasted.
const DRINK_AT_FULL_HP: bool = false
## PROVISIONAL (not in docs): drinking the poison potion poisons the drinker (true; the one way a player gets
## the status in M6a, friendly fire being off); false = it is refused.
const DRINK_POISON_HARMS: bool = true
## PROVISIONAL (○ gameplay-design §2.2: the herbalist's identity skill is the potion throw; §3.0 puts potions
## with the herbalist): only the herbalist throws (true); false = anyone throws.
const THROW_HERBALIST_ONLY: bool = true
## PROVISIONAL (not in docs): the thrown bottle flies from the thrower's body point toward the mouse, at
## most THROW_RANGE_PX, at THROW_SPEED px/s over bodies (lobbed), stopped by what stops a shot (walls,
## blocking placeables); where it lands it splashes everyone within THROW_SPLASH_RADIUS_PX of the splash
## point with no wall between. It leaves the hand on THROW_RELEASE_FRAME (0-based) of the throw action.
const THROW_RANGE_PX: float = 96.0
const THROW_SPEED: float = 192.0
const THROW_SPLASH_RADIUS_PX: float = 24.0
const THROW_RELEASE_FRAME: int = 3

# --- PROVISIONAL, M6b (potions and crafting in sessions: the host decides, README "임시값" M6b) -----------

## PROVISIONAL (not in docs; ● gameplay-design §2.6 names the revive: F held next to a downed ally, the cleric at
## once): a thrown healing potion that splashes a downed player gets it up (true) or not (false: it heals only
## the players who are up, a downed one still needs F). Default false: §2.6 gives the revive one way, and a
## potion that revives from 6 tiles away would make the cleric's instant revive (● §2.6) one of two.
const THROW_HEAL_REVIVES: bool = false

# --- PROVISIONAL, M5a (fields, seeds, watering, growth, harvest, withering) -------------------------------
# Offline first (M5a); in a session farming stays off until M5c (as M3a, M4a and M6a did). README "임시값" M5a.
# ● decided and followed as written: the three crops (game-concept §12 R28) and who plants what (§12 R37: the
# healing and buff herbs anyone at COMMON grade, poison-herb seeds the herbalist only). Everything below is ○ or
# not in the docs.

## PROVISIONAL (○ game-concept §9.7 / gameplay-design §3.8 "밭은 제단 빛(반경) 안에서만 일군다"): true = the hoe tills a
## grass tile only while the whole tile (its four corners) lies inside the altar's safe radius, the rule SurfaceGen
## used for the M1 soil patches (Farming.in_light); false = any grass tile of the surface (soil still never next to
## ash: no soil + ash tile art, WorldData.can_set_terrain).
const TILL_ONLY_IN_LIGHT: bool = true
## PROVISIONAL (not in docs): a seed stack's size.
const STACK_SEED: int = 99
## PROVISIONAL (not in docs; no merchant until M8): picking a wild herb (a gatherable, not a drop) also gives this many
## seeds of its crop (offline in M5a; a session's pickup is M2b's until M5c). The wild herb is the crop's wild plant.
const SEEDS_PER_WILD_HERB: int = 1
## PROVISIONAL (○ §9.7 "물주기 → 성장 단계"; how long water lasts is not in the docs): a watered tile stays wet this
## many ticks (watering again starts the count over), then dries.
const WATER_TICKS: int = 60 * 60
## PROVISIONAL (○ §9.7 "씨앗 → 성장 4~6단계 → 수확물"; the 04-env crops_v03 sheet draws stages 0..4): ticks of growth a
## crop needs per stage (0 seed -> 1 -> 2 -> 3 -> 4 ripe). A crop grows only while its tile is wet and it has not
## withered.
const CROP_STAGE_TICKS: int = 40 * 60
## PROVISIONAL (○ §9.7 / gameplay-design §3.8 "약초사는 성장이 빠르고"): a crop the herbalist planted grows at this
## percent of the common speed (200 = each stage takes half as long).
const CROP_HERBALIST_GROWTH_PCT: int = 200
## PROVISIONAL (○ §9.7 "약초사는 … 상급 등급을 거두며"; ● gameplay-design §3.4 lets the picker decide a wild herb's grade):
## true = the harvester decides (the herbalist's harvest is FINE, anyone else's COMMON), false = the planter (a crop the
## herbalist planted gives FINE to whoever harvests it).
const CROP_GRADE_BY_HARVESTER: bool = true
## PROVISIONAL (not in docs): what one ripe crop gives: herbs of its kind (the wild herbs' items, so the M6 potions
## brew from them) and seeds of its kind. What does not fit the inventory lies on the tile (like mining, M3a).
const CROP_HARVEST_HERBS: int = 2
const CROP_HARVEST_SEEDS: int = 1
## PROVISIONAL (○ §9.7 / gameplay-design §3.8 "오염에 닿은 작물은 시든다"; "닿은" is not defined): a crop withers while a
## corrupted tile (CORRUPTION layer) lies within this many tiles of it (Chebyshev, its own tile included). 2 is the
## nearest a field can lie to the ash: no tile art has soil and ash corners, so soil stays a tile away from ash.
const CROP_CORRUPTION_REACH_TILES: int = 2
## PROVISIONAL (not in docs): seeds go only where the crop would grow (true: not outside the light, not next to
## corruption, see Farming.withers_at); false = on any tilled soil (and it withers at once there).
const PLANT_ONLY_WHERE_IT_GROWS: bool = true
## PROVISIONAL (not in docs): crops grow, dry and wither on every map every tick, whether or not a player is on it
## (true); false = only on maps with a player (like the heretics, M4a).
const FARM_RUNS_WITHOUT_PLAYERS: bool = true
## PROVISIONAL (not in docs): the action frame (0-based) on which the hoe tills and the one on which the watering can
## waters (read off the 03-pixel sheets: the blade hits the soil on the hoe's 4th frame, like the pickaxe; the water
## reaches the ground on the can's 6th).
const HOE_IMPACT_FRAME: int = 3
const WATER_IMPACT_FRAME: int = 5

# --- IMPL (agent choices) -------------------------------------------------------------------

## IMPL: seed used when no --seed is given.
const DEFAULT_SEED: int = 1
## IMPL: ground view chunk size in display cells (TileMapLayer per chunk, spike RESULTS §3).
const GROUND_CHUNK: int = 32
## IMPL: TileMapLayer rendering quadrant for ground chunks (a canvas item takes at most 15 lights,
## spike RESULTS §4; 8 cells = 128 px squares).
const GROUND_QUADRANT: int = 8
## IMPL: weight of each inner-tile variant against the plain Wang tile (weight 1).
const VARIANT_WEIGHT: float = 0.25
## IMPL: ash edge raggedness: noise amplitude in tiles and frequency per tile.
const ASH_EDGE_NOISE_TILES: float = 3.0
const ASH_EDGE_NOISE_FREQUENCY: float = 0.2
## IMPL: free camera pan speed (px/s) in world.tscn (map viewer; main.tscn uses PlayerCamera).
const FREE_CAMERA_SPEED: float = 240.0
## IMPL: default host port for --host. Tests use a block of NET_TEST_PORT_COUNT ports from
## NET_TEST_PORT_FIRST by default (tests/run_all.gd: -- --port-base=<n> or EVENSONG_TEST_PORT_BASE
## picks another, the runner probes the whole block first).
const DEFAULT_PORT: int = 24600
const NET_TEST_PORT_FIRST: int = 24621
const NET_TEST_PORT_LAST: int = 24640
const NET_TEST_PORT_COUNT: int = NET_TEST_PORT_LAST - NET_TEST_PORT_FIRST + 1
## IMPL: the fixed simulation tick (= the project's physics ticks per second, Godot default 60).
## Host and clients step every player with Movement.step(..., NET_TICK) once per input frame.
const NET_TICK_RATE: int = 60
const NET_TICK: float = 1.0 / NET_TICK_RATE
## IMPL: client input packets per second (every 2nd tick). Each packet repeats every input frame the
## host has not acknowledged yet (at most NET_MAX_FRAMES_PER_PACKET), so a lost packet costs nothing.
const NET_INPUT_HZ: int = 30
const NET_MAX_FRAMES_PER_PACKET: int = 32
## IMPL: host rate limit per client: one input frame per tick, with a burst allowance of this many
## frames (0.5 s) for packets that arrive bunched.
const NET_INPUT_BURST: int = 30
## IMPL: the host keeps up to this many received frames per client waiting and applies one per tick
## (more when it falls behind), so other players see a client walk smoothly.
const NET_INPUT_JITTER_FRAMES: int = 3
## IMPL: when a client has fallen behind (bunched packets, a host hitch), the host applies at most
## this many of its frames per tick: others see it catch up at 4x walking speed instead of a jump.
const NET_INPUT_CATCH_UP_FRAMES: int = 4
## IMPL: late join world snapshot (net/world_snapshot.gd): the compressed world goes out in chunks
## of at most this many bytes (one chunk + headers fits one ~1400 B UDP datagram, no ENet
## fragmentation), at most this many chunks per host tick to each joiner (8 KB per tick = 480 KB/s).
const NET_SNAPSHOT_CHUNK_BYTES: int = 1024
const NET_SNAPSHOT_CHUNKS_PER_TICK: int = 8
## IMPL: connection limits. ENet accepts more peers than MAX_PLAYERS so the host can tell a tenth
## player "full" instead of the transport silently dropping it (the host does the counting).
const NET_TRANSPORT_PEER_LIMIT: int = 16
## IMPL: ENet packet throttle per connection (interval ms, acceleration, deceleration;
## ENetPacketPeer.throttle_configure). ENet lowers the throttle by `deceleration` on every
## acknowledgement whose round trip is more than 2 x variance above the previous epoch's lowest, and
## a low throttle drops that share of unreliable packets (our state batches) and shrinks the window of
## reliable data in flight. With both ends polling at 60 Hz the round trip is quantised (about 16 or
## 33 ms on localhost) and drifts with the frames' phase; with frequent reliable messages (a host
## editing every 4 ticks) the throttle fell to 0 in about 1.5 s and a walking client got no state
## batch for seconds (measured, H-fix). M1 traffic is small (at most about 23 KB/s for 9 players), so
## the throttle never lowers: deceleration 0. Interval and acceleration are ENet's defaults.
const NET_ENET_THROTTLE: Vector3i = Vector3i(5000, 2, 0)
## IMPL (M2b): a player's requests ride on its input frames (one per frame). Pick up, drop and give:
## the host takes at most one every NET_OP_INTERVAL_TICKS ticks per player, with a burst of
## NET_OP_BURST, and refuses the rest as "rate". A use is bounded by the action it starts (one at a
## time; a refused use costs a check and a counter), a hotbar select by the frames themselves (it
## changes no world state, and a client predicts it, so a "rate" refusal would leave its hotbar
## wrong). Ten a second is above anyone pressing keys and well below a client spamming every frame.
const NET_OP_INTERVAL_TICKS: int = 6
const NET_OP_BURST: int = 4
## IMPL (M2b): local requests (keys, --give) waiting for a frame (NetSession.queue_op); one beyond
## this is dropped and logged. A client's --give list of the debug kit's items fits.
const NET_LOCAL_OPS_MAX: int = 64
## IMPL (M2b): the host logs a member's refused requests per reason: the first this many, then every
## NET_REFUSAL_LOG_EVERY-th (with the count). The counters (results) count every one.
const NET_REFUSAL_LOG_FIRST: int = 8
const NET_REFUSAL_LOG_EVERY: int = 60
## IMPL (M3-fix): the host keeps at most this many finished streams (joins and map entries,
## SessionHost.streams_done) and a client at most this many left maps (SessionClient.left_maps) for
## the test results; older ones are dropped, so a client travelling up and down all session long does
## not grow them without bound.
const NET_STREAM_RECORDS_MAX: int = 64
## IMPL (M2b): most items lying on the ground at once (a debug drop beyond it is refused), so a
## spamming client cannot grow the world or the late-join snapshot without bound.
const MAX_DROPS: int = 256
## IMPL: a join that has not been welcomed after this long fails (ENet itself gives up after ~31 s).
const NET_CONNECT_TIMEOUT_SEC: float = 10.0
## IMPL: the host drops a connection that has not said hello after this long, and a refused one
## that is still connected after REFUSE_GRACE (the refused client normally leaves by itself).
const NET_HELLO_TIMEOUT_SEC: float = 5.0
const NET_REFUSE_GRACE_SEC: float = 2.0
## IMPL: class of the local player when --class is not given.
const DEFAULT_CLASS: String = "paladin"
## IMPL: seconds per frame. Walk = the stage-3 walk GIFs (120 ms); idle (4 breathing frames) slower.
const WALK_FRAME_TIME: float = 0.12
const IDLE_FRAME_TIME: float = 0.2
## IMPL: collision box at the feet (half width, height in px): Rect2(x - 5, y - 4, 10, 4).
## Movement collides this box with the map bounds and with blocked cells (the altar footprint).
const FEET_HALF_WIDTH: float = 5.0
const FEET_HEIGHT: float = 4.0
## IMPL: extra room (px, beyond the feet box) the feet keep from the altar footprint's west and
## east faces while they are level with it (feet between its top and bottom edge, where the
## character is drawn behind the altar). The base body reaches 9 px right and 9 px left of the feet
## in its widest frame (any direction, walk or idle) and the altar art is opaque from column 0 to 46
## of its 48 px footprint, so with (5, 3) a body pressed against either face touches the art
## without going behind it. Carried gear on the back or arm can still reach behind the edge (README).
## tests/test_actors.gd measures it again from the sheets and the art.
const ALTAR_SIDE_CLEARANCE: Vector2i = Vector2i(5, 3)
## IMPL: the feet stay at least this far below the map's top edge, so the head (frame row 4 =
## 28 px above the feet) never leaves the map.
const HEAD_ROOM_PX: float = 28.0
## IMPL (the places; spawning around the altar at all is PROVISIONAL, see SPAWN_FACING): spawn
## slots around the altar, feet offsets in px from the altar centre. Slot 0 = local player (G2); G3
## hands them out to joining players (up to Config.MAX_PLAYERS). All lie inside the safe zone and
## outside the footprint (tests/test_actors.gd).
const SPAWN_SLOTS: Array[Vector2i] = [
	Vector2i(-54, 8), Vector2i(54, 8), Vector2i(0, -26), Vector2i(-36, 52), Vector2i(36, 52),
	Vector2i(-54, -30), Vector2i(54, -30), Vector2i(-80, 30), Vector2i(80, 30),
]
## IMPL: canvas light layers (CanvasItem.light_mask / Light2D.range_item_cull_mask bits). The
## ground and the altar get the dithered altar light, characters a hard-edged copy (spike RESULTS §4).
const LIGHT_LAYER_WORLD: int = 1
const LIGHT_LAYER_ACTORS: int = 2
## IMPL (M3a): map ids. Each player is on exactly one map; the surface is 0, the first dungeon 1.
const MAP_SURFACE: int = 0
const MAP_DUNGEON: int = 1
## IMPL (M3b): how many maps exist (map ids 0..MAP_COUNT - 1); decoders refuse any other map id.
const MAP_COUNT: int = 2
const MAP_NAMES: PackedStringArray = ["surface", "dungeon"]
## IMPL (M3a): the dungeon's wall faces (measured from 04-env tiles_dungeon_v02): a wall tile's front
## face starts this many px below the wall tile's centre row and is FACE_HEIGHT_PX tall, so it covers
## the tile below the wall (blocked: collision = what is drawn) and 3 px of the next one.
const FACE_TOP_PX: int = 3
const FACE_HEIGHT_PX: int = 24
## IMPL: flame mask = pixels that differ between altar_v04 and altar_v04_unlit and are at least
## this bright (0-255 luma). Keeps the 81 flame pixels (9 lamps x 9), drops the warm glow on the
## stone (spike light module value).
const FLAME_MIN_LUMA: float = 148.0
## IMPL (M4a): ticks a hit flash shows on a character, a heretic or the shrine; a shot moves in steps of
## at most SHOT_STEP_PX inside a tick (M4-fix: and every tile between two steps counts, Combat.cells_on_line,
## so it never slips between two walls that touch at a corner). The hit box and the draw lift are
## PROVISIONAL rows above (M4-fix).
const HIT_FLASH_TICKS: int = 6
const SHOT_STEP_PX: float = 2.0
## IMPL (M4a, named in M4-fix, values unchanged): a spawn try picks this many random spawn tiles before it
## gives up until the next interval; a heretic is home within HERETIC_HOME_ARRIVE_PX, walks home rather
## than idles when farther than HERETIC_HOME_IDLE_PX, makes the spot it is stuck at its home after
## HERETIC_HOME_STUCK_TICKS without getting closer; an axis closer than HERETIC_AXIS_DEAD_ZONE_PX is not
## walked along (no jitter on a straight line).
const HERETIC_SPAWN_TRIES: int = 24
const HERETIC_HOME_ARRIVE_PX: float = 1.5
const HERETIC_HOME_IDLE_PX: float = 2.0
const HERETIC_HOME_STUCK_TICKS: int = 60
const HERETIC_AXIS_DEAD_ZONE_PX: float = 0.5
## IMPL (M4b): a map's enemy batch goes out at once on a tick a heretic starts an attack (not on the next
## 20 Hz batch tick: up to 2 ticks earlier on the telegraph's clock).
const NET_ENEMY_SEND_ON_ATTACK: bool = true
## IMPL (M4b; M4-fix: counted against host time): while a member is "timed" (its vitals run a timer,
## Vitals.idle false: stagger, invulnerability, dash, down, dead, stamina coming back; or a body action
## plays) the host keeps its clock debt: +1 per host tick, -1 per frame of it the host runs. Its frames may never
## run ahead of host time (no frame while the debt is 0: a client cannot fast-forward a stagger or a dash
## cooldown with saved-up frames), and when they fall more than this many ticks behind with its vitals
## running, the host steps it itself with an empty frame each tick (a client that stops sending, or sends
## a frame now and then, cannot hold its down time, its respawn or its invulnerability). The debt starts at
## 0 whenever the member is idle, so a client that stood still and is hit only owes the ticks until it
## hears of the hit (about a round trip): 30 ticks covers a one-way delay of about 200 ms with no host step.
const NET_HOST_STEPS_AFTER_TICKS: int = 30
## IMPL (M6a): a splash shows this many ticks (code-drawn frames, combat/combat_view.gd); the thrown bottle
## is drawn this many px higher at the middle of its flight (an arc on top of SHOT_DRAW_LIFT_PX).
const SPLASH_SHOW_TICKS: int = 18
const THROW_ARC_PX: float = 10.0
## IMPL (M5a): a field tile's VEGETATION value (items/farming.gd): FIELD_BASE + crop kind * FIELD_KIND_STEP + stage *
## FIELD_STAGE_STEP + flags (withered 4, wet 2, planted by the herbalist 1). Gatherables use 1..15, so 64.. is free and
## every field value (64..223) fits a byte.
const FIELD_BASE: int = 64
const FIELD_KIND_STEP: int = 40
const FIELD_STAGE_STEP: int = 8


static func safe_radius_px() -> float:
	return float(SAFE_RADIUS_TILES * TILE)

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
## decorative wall torches the generator hangs on room north walls, one every this many tiles (at
## least one per room), as decoration with a small light.
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
## PROVISIONAL (● gameplay-design §3.0 R11 miner row: everyone mines "느리고 1×1, 경도 상한", the miner
## "3×3 고속, 상위 경도"; ○ §3.1 "벽 타일에 경도 등급"; the numbers are not in the docs): hardness grade of
## each wall kind / ore, the highest grade a common player and the miner can break, hits a tile takes
## before it breaks, and hits one pickaxe swing deals (the miner's swing counts double: "고속").
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
## this is dropped and logged. A client's --give list of the debug kit's 23 items fits.
const NET_LOCAL_OPS_MAX: int = 64
## IMPL (M2b): the host logs a member's refused requests per reason: the first this many, then every
## NET_REFUSAL_LOG_EVERY-th (with the count). The counters (results) count every one.
const NET_REFUSAL_LOG_FIRST: int = 8
const NET_REFUSAL_LOG_EVERY: int = 60
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


static func safe_radius_px() -> float:
	return float(SAFE_RADIUS_TILES * TILE)

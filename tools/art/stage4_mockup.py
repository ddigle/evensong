# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""4단계 본 제작 통합: 작은 손질, 목업, 후보 시트 (2026-10-21 밤, 생성 없음, 무료).

기록: assets/concept/04-env/prompts.md "본 제작 (2026-10-21 밤)".
실행 (어디서 돌려도 된다. 경로는 이 파일 기준):
    uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I tools/art/stage4_mockup.py all

  fix         통합 손질 3개: item_holy_water_c_v03 (가운데 붉은 점 2px), item_offering_cup_v03 (굽 달린 잔 -> 굽 없는 잔),
              prop_barrel_smashed_v03 (와인빛 #301412 4px -> 따뜻한 갈흑)
  surface     stage4_mockup_v04_day(.png 3배, _1x) / _eve (제단 빛 밖을 어둡게, 불꽃·후광은 빛)
  dungeon     stage4_dungeon_v05 (.png 3배, _1x): 왼쪽 = 지상의 던전 입구 둘레, 오른쪽 = 던전 방
  candidates  stage4_candidates_v01.png: ? 결정 대기 후보를 나란히 (3배, 라벨)

손질 2 통합 (s3, 2026-10-22 새벽, 생성 없음. 기록은 prompts.md "본 제작 손질 2"). 위 출력은 바이트까지 그대로 다시 나온다:
  fix2        prop_candles_black_b_v04 (s1 v03에 s2 아이템 검은 초와 같은 잿빛 테),
              prop_lantern_ground_v03_lit / _v03_emissive (s1의 24px 땅 랜턴에 s2와 같은 규칙의 켜짐판)
  surface5    stage4_mockup_v05_day / _eve: v03 소품·흙길·모루·작업대·아이템, 늘린 랜턴 기둥(저녁에 켜짐 + 빛),
              v03 촛대와 성물 제작대에 공유 불꽃
  dungeon6    stage4_dungeon_v06: v03 위협 소품·창고 구석·던전 소품(바닥에서 뗀 판)·아이템, 켜진 땅 랜턴 v03
  scale       stage4_scale_compare_v01.png: 옛 소품(v02)과 새 소품(v03)을 캐릭터 옆에 (3배)
  rules       손질 2의 채택 후보 전부에 손질 규칙 검사 (색 수, 밝기, 차가운 회색, 반투명, 외곽선)
  all         위 모두 (rules 제외)

화면은 480x270 (game-concept §7, R31). 캐릭터는 03-pixel 기본 몸 걷기 v02 첫 프레임 + 표식 레이어
(R27 방식: 레이어는 v01 걷기 첫 프레임에 그렸으므로 남 +4, 동 +3, 북 +4 내려 붙인다. 서쪽은 동쪽 합성의 좌우 반전).
"""
import json
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ENV = os.path.join(ROOT, "assets", "concept", "04-env")
PIX = os.path.join(ROOT, "assets", "concept", "03-pixel")
T = (0, 0, 0, 0)
OUT = (0x1A, 0x17, 0x14, 255)
SW, SH = 480, 270
K = 3   # mockup scale (brief §7 판정 배율. 1080p 실제 화면은 4배)


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


_cache = {}


def load(name, d=ENV):
    key = (d, name)
    if key not in _cache:
        _cache[key] = Image.open(os.path.join(d, name)).convert("RGBA")
    return _cache[key].copy()


def save(im, name):
    im.save(os.path.join(ENV, name))
    print("wrote", name, im.size)


def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def paste(dst, src, xy):
    x, y = int(xy[0]), int(xy[1])
    sx0, sy0 = max(0, -x), max(0, -y)
    sx1, sy1 = min(src.width, dst.width - x), min(src.height, dst.height - y)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    dst.alpha_composite(src.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))


def bbox(im):
    a = np.asarray(im)[..., 3]
    ys, xs = np.nonzero(a)
    return xs.min(), ys.min(), xs.max(), ys.max()


def font(size):
    for f in ("malgun.ttf", "NanumGothic.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


# =====================================================================================
# fix: 통합 손질 (작은 것 3개, v02 -> v03)
# =====================================================================================
def fix():
    hw = load("item_holy_water_c_v02.png")
    px = hw.load()
    assert px[7, 8][:3] == (0x62, 0x00, 0x04) and px[7, 10][:3] == (0x62, 0x00, 0x04)
    px[7, 8] = hx("6f5522")       # 금빛 띠의 짙은 금 (같은 줄의 띠 색)
    px[7, 10] = hx("dfc69c")      # 상아빛 물
    save(hw, "item_holy_water_c_v03.png")

    cup = np.array(load("item_offering_cup_v02.png"))
    cup[10, 6:10] = OUT           # 잔 몸통 밑을 외곽선으로 닫고
    cup[11:, :] = 0               # 굽과 다리(11~14줄)를 지운 뒤
    out = np.zeros_like(cup)
    out[4:15] = cup[0:11]         # 바닥에 닿게 4px 내림
    save(Image.fromarray(out), "item_offering_cup_v03.png")

    br = np.array(load("prop_barrel_smashed_v02.png"))
    m = (br[..., 0] == 0x30) & (br[..., 1] == 0x14) & (br[..., 2] == 0x12) & (br[..., 3] > 0)
    assert m.sum() == 4, m.sum()
    br[m] = hx("2c1f1a")
    save(Image.fromarray(br), "prop_barrel_smashed_v03.png")

    # 손질 전후 (8배, 왼쪽 v02 -> 오른쪽 v03), 바탕은 잿빛 땅 색
    pairs = [("item_holy_water_c", 16), ("item_offering_cup", 16), ("prop_barrel_smashed", 32)]
    k = 8
    W = sum((s * 2 * k + 40) for _, s in pairs) + 20
    sheet = Image.new("RGBA", (W, 32 * k + 60), (107, 94, 79, 255))
    d = ImageDraw.Draw(sheet)
    x = 20
    for name, s in pairs:
        d.text((x, 8), f"{name}  v02 -> v03", font=font(16), fill=(239, 227, 198))
        paste(sheet, up(load(f"{name}_v02.png"), k), (x, 40))
        paste(sheet, up(load(f"{name}_v03.png"), k), (x + s * k + 10, 40))
        x += s * 2 * k + 40
    save(sheet.convert("RGB"), "stage4_fix4_small_compare.png")


# =====================================================================================
# characters (03-pixel)
# =====================================================================================
DIRROW = {"S": 0, "E": 1, "N": 2}
SIG_SHIFT = {"S": 4, "E": 3, "N": 4}
SIG_FILES = {"miner": "sig_miner_pickaxe_v01.png", "archer": "sig_archer_bow_v01.png",
             "herbalist": "sig_herbalist_pouch_v02.png"}


def character(cls, d):
    """32 x 40 image, feet on row 39. Returns (image, emissive)."""
    flip = d == "W"
    dd = "E" if flip else d
    r = DIRROW[dd]
    walk = load("base_body_v02_walk.png", PIX)
    body = walk.crop((0, r * 32, 32, r * 32 + 32))
    im = Image.new("RGBA", (32, 40), T)
    em = Image.new("RGBA", (32, 40), T)
    paste(im, body, (0, 8))
    if cls == "paladin":
        lay = load("sig_paladin_shield_v01.png", PIX).crop((0, r * 32, 32, r * 32 + 32))
        paste(im, lay, (0, 8 + SIG_SHIFT[dd]))
    elif cls in SIG_FILES:
        lay = load(SIG_FILES[cls], PIX).crop((r * 32, 0, r * 32 + 32, 32))
        paste(im, lay, (0, 8 + SIG_SHIFT[dd]))
    elif cls == "cleric":
        x0, y0, x1, _ = bbox(body)
        top_xs = np.nonzero(np.asarray(body)[y0, :, 3])[0]
        cx = (top_xs.min() + top_xs.max() + 1) // 2
        halo = load("sig_cleric_halo_v01.png", PIX)
        paste(em, halo, (cx - 6, 8 + y0 - 5))
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
        em = em.transpose(Image.FLIP_LEFT_RIGHT)
    return im, em


def miner_strike():
    """광부 곡괭이 동작 동쪽 4번째 프레임 (64 칸, 발 줄 y47). 손에 든 도구가 표식이라 등 표식은 숨김 (R27)."""
    sh = load("base_body_v02_pickaxe.png", PIX)
    return sh.crop((3 * 64, 64, 4 * 64, 128))


# =====================================================================================
# flames (a3, flame_*_v01): frame i of a 5-frame strip
# =====================================================================================
def flame(name, i):
    s = load(name)
    w = s.width // 5
    return s.crop((i * w, 0, (i + 1) * w, s.height))


LAMP_ORIGINS = [(9, 5), (22, 5), (35, 5), (9, 15), (22, 15), (35, 15), (9, 25), (22, 25), (35, 25)]


def altar_lit():
    """altar_v04_litbase + 공유 불꽃 1프레임씩(등잔마다 위상을 어긋나게). Returns (base, emissive)."""
    base = load("altar_v04_litbase.png")
    em = Image.new("RGBA", base.size, T)
    for i, xy in enumerate(LAMP_ORIGINS):
        paste(em, flame("flame_small_v01.png", (i * 3) % 4), xy)
    return base, em


# light props: prop file -> (flame strip, top-left of the flame in prop coordinates)
LIGHT_ANCHORS = {
    "prop_candle_stand_a_v02.png": ("flame_small_v01.png", (14, -5)),
    "prop_candle_stand_b_v02.png": ("flame_small_v01.png", (15, -4)),
    "prop_fire_basket_v02.png": ("flame_large_v01.png", (13, -2)),
    "prop_campfire_ring_v02.png": ("flame_large_v01.png", (13, 4)),
    "prop_wall_torch_a_v02.png": ("flame_large_v01.png", (9, -4)),
}


# =====================================================================================
# scene: sprites sorted by foot line, plus an emissive layer
# =====================================================================================
class Scene:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.items = []    # (foot_y, order, image, xy, emissive or None)
        self.decals = []   # ground decals, drawn before sprites
        self.n = 0

    def decal(self, im, xy):
        self.decals.append((im, xy))

    def put(self, im, x, foot, em=None, phase=0):
        """x = canvas left, foot = y of the ground line (bottom opaque row + 1)."""
        if isinstance(im, str):
            name = im
            im = load(name)
            if name in LIGHT_ANCHORS:
                strip, (fx, fy) = LIGHT_ANCHORS[name]
                e = Image.new("RGBA", (im.width + 16, im.height + 16), T)
                paste(e, flame(strip, phase % 4), (fx + 8, fy + 8))
                em = (e, (-8, -8))
        _, _, _, by = bbox(im)
        y = foot - by - 1
        self.items.append((foot, self.n, im, (x, y), em))
        self.n += 1

    def put_char(self, cls, d, fx, fy):
        im, em = character(cls, d)
        self.items.append((fy, self.n, im, (fx - 16, fy - 40), (em, (0, 0))))
        self.n += 1

    def render(self, ground):
        base = ground.copy()
        emis = Image.new("RGBA", base.size, T)
        for im, xy in self.decals:
            paste(base, im, xy)
        for foot, _, im, (x, y), em in sorted(self.items, key=lambda t: (t[0], t[1])):
            paste(base, im, (x, y))
            if em is not None:
                e, (ox, oy) = em
                paste(emis, e, (x + ox, y + oy))
                # 빛 픽셀 아래의 바탕은 그대로 두고, 빛은 맨 위에 다시 얹는다(어둡게 하지 않는 층)
                paste(base, e, (x + ox, y + oy))
        return base, emis


# =====================================================================================
# ground: corner (Wang) tilesets from PixelLab JSON layouts
# =====================================================================================
def wang(png, js, d=ENV):
    sheet = load(png, d)
    data = json.load(open(js, encoding="utf-8"))
    tiles = {}
    for t in data["tileset_data"]["tiles"]:
        c = t["corners"]
        b = t["bounding_box"]
        key = (c["NW"], c["NE"], c["SW"], c["SE"])
        tiles.setdefault(key, sheet.crop((b["x"], b["y"], b["x"] + 16, b["y"] + 16)))
    return tiles


GRASS = ["tiles_grass_base_v02.png"] + [f"tiles_grass_var_{i}_v02.png" for i in range(1, 5)]
ASH = [f"tiles_ash_plain_{i}_v01.png" for i in range(1, 4)]


def surface_ground(V, watered, seed, path_png="tiles_grass-path_v02.png", path_js="tiles_grass-path_v01.json"):
    """V: (rows+1) x (cols+1) vertex terrain, 'G' grass + one of P (path) / S (soil) / A (ash) per cell."""
    js_path = os.path.join(ENV, path_js)
    js_soil = os.path.join(ENV, "tiles_grass-soil_v01.json")
    js_ash = os.path.join(PIX, "tiles_grass-corruption_v02.json")
    sets = {"P": wang(path_png, js_path), "S": wang("tiles_grass-soil_v03.png", js_soil),
            "A": wang("tiles_grass-corruption_v05.png", js_ash)}
    sw = wang("tiles_grass-soil_v03_watered.png", js_soil)
    inner = {"P": [sets["P"][("lower",) * 4]] + [load(f"tiles_path_var_{i}_v01.png") for i in (1, 2, 3)],
             "S": [sets["S"][("lower",) * 4], load("tiles_soil_var_1_v01.png"), load("tiles_soil_var_2_v01.png")],
             "A": [load(n) for n in ASH]}
    inner_w = [sw[("lower",) * 4], load("tiles_soil_var_1_v01_watered.png"), load("tiles_soil_var_2_v01_watered.png")]
    grass = [load(n) for n in GRASS]
    rnd = random.Random(seed)
    rows, cols = len(V) - 1, len(V[0]) - 1
    im = Image.new("RGBA", (cols * 16, rows * 16), T)
    kind = {}
    for cy in range(rows):
        for cx in range(cols):
            cs = (V[cy][cx], V[cy][cx + 1], V[cy + 1][cx], V[cy + 1][cx + 1])
            other = set(cs) - {"G"}
            if not other:
                t = grass[0] if rnd.random() < 0.55 else rnd.choice(grass[1:])
                kind[(cx, cy)] = "G"
            else:
                assert len(other) == 1, (cx, cy, cs)
                X = other.pop()
                key = tuple("upper" if c == "G" else "lower" for c in cs)
                if key == ("lower",) * 4:
                    pool = inner_w if (X == "S" and (cx, cy) in watered) else inner[X]
                    t = pool[0] if rnd.random() < 0.4 else rnd.choice(pool[1:])
                else:
                    t = (sw if (X == "S" and (cx, cy) in watered) else sets[X])[key]
                kind[(cx, cy)] = X if key == ("lower",) * 4 else X.lower()
            paste(im, t, (cx * 16, cy * 16))
    return im, kind


def vgrid(cols, rows, fill="G"):
    return [[fill] * (cols + 1) for _ in range(rows + 1)]


def vrect(V, x0, y0, x1, y1, v):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            V[y][x] = v


# =====================================================================================
# eve lighting: 4 levels, ordered dither, warm (no blue) darkening
# =====================================================================================
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0


def darken(base, emis, lights, ash_amount=None):
    """lights: (cx, cy, r_in, r_out). 빛 밖은 따뜻한 어둠 3단 (풀 0.42/0.38/0.35, 잿빛 땅 0.54/0.50/0.47, 목업 v03과 같은 값 - 오염은 덜 어둡게, brief §5.7 요령)."""
    h, w = base.height, base.width
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    lit = np.zeros((h, w))
    for cx, cy, r0, r1 in lights:
        d = np.hypot(xx - cx, (yy - cy) * 1.15)
        lit = np.maximum(lit, np.clip((r1 - d) / (r1 - r0), 0, 1))
    b = BAYER[(yy.astype(int) % 4), (xx.astype(int) % 4)]
    lvl = np.clip(np.floor((1 - lit) * 3 + b), 0, 3).astype(int)      # 0 lit .. 3 dark
    dark_g = np.array([0.42, 0.38, 0.35])
    dark_a = np.array([0.54, 0.50, 0.47])
    amt = np.zeros((h, w)) if ash_amount is None else ash_amount
    dark = dark_g[None, None, :] * (1 - amt[..., None]) + dark_a[None, None, :] * amt[..., None]
    f = 1 - (1 - dark) * (lvl[..., None] / 3.0)
    a = np.asarray(base).astype(float)
    a[..., :3] = a[..., :3] * f
    out = Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8))
    out.alpha_composite(emis)
    return out


def finish(img, name):
    img = img.convert("RGB")
    save(img, f"{name}_1x.png")
    save(up(img, K), f"{name}.png")


# =====================================================================================
# surface mockup (480 x 270)
# =====================================================================================
ASH_EDGE = [26, 26, 25, 25, 24, 24, 25, 25, 25, 25, 25, 25, 25, 26, 26, 25, 25, 26]   # first ash vertex per row


def surface_map():
    cols, rows = 30, 17
    V = vgrid(cols, rows)
    for y in range(rows + 1):
        for x in range(ASH_EDGE[y], cols + 1):
            V[y][x] = "A"
    vrect(V, 0, 10, 23, 12, "P")       # 큰길: 왼쪽 끝에서 오염 땅 앞까지
    vrect(V, 15, 7, 17, 10, "P")       # 제단 앞으로 갈라지는 길
    vrect(V, 6, 2, 11, 6, "S")         # 밭 5 x 4 칸 (제단 빛 안)
    vrect(V, 20, 14, 23, 15, "S")      # 오염 옆 작은 밭 (시든 작물)
    watered = {(x, 5) for x in range(6, 11)}
    return V, watered


def surface():
    V, watered = surface_map()
    ground, kind = surface_ground(V, watered, 20261021)
    sc = Scene(SW, SH)
    rnd = random.Random(4)

    # 오염 장식: 잿빛 칸 안에만 흩뿌림 (칸에 고정하지 않음)
    ash_cells = [c for c, k in kind.items() if k == "A"]
    decals = (["decal_crack_1_v01.png", "decal_crack_2_v01.png", "decal_crack_3_v01.png", "decal_crack_4_v01.png"] * 2
              + ["decal_vein_1_v01.png", "decal_vein_2_v01.png", "decal_vein_3_v01.png"]
              + ["decal_bone_1_v01.png", "decal_bone_2_v01.png", "decal_bone_3_v01.png",
                 "decal_mould_1_v01.png", "decal_mould_2_v01.png", "decal_mould_3_v01.png"]
              + ["decal_rubble_1_v01.png", "decal_rubble_2_v01.png", "decal_rubble_3_v01.png", "decal_rubble_4_v01.png"] * 2)
    taken = []
    for name in decals:
        for _ in range(200):
            cx, cy = rnd.choice(ash_cells)
            x, y = cx * 16 + rnd.randint(0, 10), cy * 16 + rnd.randint(0, 10)
            if all(abs(x - tx) > 12 or abs(y - ty) > 10 for tx, ty in taken):
                taken.append((x, y))
                sc.decal(load(name), (x, y))
                break
    # 풀 쪽 경계의 잿빛 얼룩
    for i, y in enumerate((20, 70, 118, 190, 236)):
        ex = ASH_EDGE[min(17, y // 16)] * 16
        sc.decal(load(f"decal_ashcreep_{i % 3 + 1}_v01.png"), (ex - 26 - (i % 2) * 6, y))

    # 밭 작물 (crops_v03: 줄 회복·버프·독초, 칸 0~4단계·수확·시듦)
    crops = load("crops_v03_sheet.png")

    def crop(r, c):
        return crops.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16))
    for r in range(3):
        for i in range(5):
            sc.put(crop(r, i), (6 + i) * 16, (2 + r) * 16 + 16)
    for i, (r, stage) in enumerate(((0, 1), (1, 2), (2, 1), (0, 3), (1, 0))):         # 물 준 줄
        sc.put(crop(r, stage), (6 + i) * 16, 5 * 16 + 16)
    for i in range(3):                                                                    # 시든 작물
        sc.put(crop(i, 6), (20 + i) * 16, 14 * 16 + 16)

    # 제단과 둘레
    alt, alt_em = altar_lit()
    sc.items.append((109, -1, alt, (232, 52), (alt_em, (0, 0))))
    sc.put("prop_candle_stand_a_v02.png", 200, 106, phase=1)
    sc.put("prop_candle_stand_b_v02.png", 268, 106, phase=3)
    sc.put("storage_chest_v02.png", 296, 118)
    sc.put("prop_barrel_a_v02.png", 342, 116)
    sc.put("prop_sack_a_v02.png", 364, 120)
    # 작업대: 기본 작업대·모루·조제대는 밭 아래, 성물 제작대는 제단 오른쪽 위
    sc.put("alchemy_table_v05.png", 92, 134)
    sc.put("workbench_v02.png", 144, 134)
    sc.put("anvil_v02.png", 196, 136)
    sc.put("relic_bench_v02.png", 324, 56)
    # 조명
    sc.put("prop_fire_basket_v02.png", 292, 54, phase=2)
    sc.put("prop_campfire_ring_v02.png", 230, 246, phase=0)
    sc.put("prop_lantern_post_a_v02.png", 30, 150)
    sc.put("prop_lantern_post_c_v02.png", 318, 150)
    # 채집물 (풀밭 가장자리, 빛 밖)
    for name, x, foot in (("item_wild_herb_clump_v02.png", 8, 30), ("item_mushroom_a_v02.png", 30, 58),
                          ("item_stone_a_v02.png", 56, 24), ("item_sticks_a_v02.png", 12, 96),
                          ("item_wild_healing_v02.png", 50, 104), ("item_mushroom_d_v02.png", 66, 70),
                          ("item_wild_healing_v02.png", 8, 236), ("item_wild_buff_v02.png", 34, 250),
                          ("item_mushroom_c_v02.png", 66, 232), ("item_stone_mossy_v02.png", 100, 252),
                          ("item_sticks_b_v02.png", 128, 228), ("item_mushroom_b_v02.png", 160, 262),
                          ("item_stone_b_v02.png", 210, 18),
                          ("item_wild_buff_v02.png", 348, 236), ("item_wild_poison_v02.png", 370, 82),
                          ("crop_poison_wild_v01.png", 378, 200), ("item_wild_poison_v02.png", 360, 256)):
        sc.put(name, x, foot)
    # 위협 소품 (잿빛 땅)
    for name, x, foot in (("prop_bone_pile_a_v02.png", 406, 40), ("prop_idol_broken_a_v02.png", 446, 62),
                          ("prop_ritual_stone_a_v02.png", 420, 104), ("prop_brazier_dark_a_v02.png", 446, 150),
                          ("prop_skull_stake_v02.png", 404, 186), ("prop_bramble_dead_b_v02.png", 446, 214),
                          ("prop_boulder_corrupt_v02.png", 410, 262), ("item_mushroom_ash_v02.png", 452, 252),
                          ("item_skull_small_a_v02.png", 430, 140), ("item_mould_clump_v02.png", 460, 98),
                          ("item_stone_veined_v02.png", 424, 220)):
        sc.put(name, x, foot)
    # 다섯 클래스
    sc.put_char("cleric", "S", 256, 142)
    sc.put_char("herbalist", "W", 190, 98)
    sc.put_char("miner", "N", 212, 166)
    sc.put_char("paladin", "W", 330, 186)
    sc.put_char("archer", "E", 372, 168)

    base, emis = sc.render(ground)
    day = base.crop((0, 0, SW, SH))
    finish(day, "stage4_mockup_v04_day")

    lights = [(256, 84, 100, 150),           # 제단 빛 (안전 반경)
              (216, 74, 6, 34), (284, 74, 6, 34),    # 촛대
              (308, 28, 12, 54),             # 불 바구니
              (246, 224, 16, 64)]            # 모닥불
    h, w = base.height, base.width
    edge_px = np.array([ASH_EDGE[min(len(ASH_EDGE) - 1, int(y // 16))] * 16 for y in range(h)], float)
    xx = np.arange(w)[None, :].astype(float)
    ash_amt = np.clip((xx - (edge_px[:, None] - 12)) / 20.0, 0, 1)
    eve = darken(base, emis, lights, ash_amt).crop((0, 0, SW, SH))
    finish(eve, "stage4_mockup_v04_eve")


# =====================================================================================
# dungeon (left: surface entrance on ash ground, right: a dungeon room)
# =====================================================================================
def dungeon_ground(cols, rows, seed, ore):
    js = os.path.join(ENV, "tiles_dungeon_v01.json")
    tiles = wang("tiles_dungeon_v02.png", js)
    var = load("tiles_dungeon_v02_var.png")
    floors = [tiles[("lower",) * 4]] + [var.crop((i * 16, 0, i * 16 + 16, 16)) for i in range(3)]
    tops = [tiles[("upper",) * 4]] + [var.crop((i * 16, 0, i * 16 + 16, 16)) for i in (3, 4)]
    V = vgrid(cols, rows, "lower")
    for y in range(rows + 1):
        for x in range(cols + 1):
            if y <= 2 or x <= 1 or x >= cols - 1 or y >= rows - 1:
                V[y][x] = "upper"
    for x in range(2, cols - 1):
        V[3][x] = "transition"
    rnd = random.Random(seed)
    im = Image.new("RGBA", (cols * 16, rows * 16), T)
    for cy in range(rows):
        for cx in range(cols):
            key = (V[cy][cx], V[cy][cx + 1], V[cy + 1][cx], V[cy + 1][cx + 1])
            if (cx, cy) in ore:
                t = load(ore[(cx, cy)])
            elif key == ("lower",) * 4:
                t = floors[0] if rnd.random() < 0.5 else rnd.choice(floors[1:])
            elif key == ("upper",) * 4:
                t = tops[0] if rnd.random() < 0.5 else rnd.choice(tops[1:])
            else:
                t = tiles[key]
            paste(im, t, (cx * 16, cy * 16))
    return im


def dungeon_left(full, allem):
    """left panel of the dungeon mockup: the surface entrance on ash ground (v05 and v06 share it)."""
    # --- left panel: surface entrance (ash) 160 px ---
    cols, rows = 10, 17
    V = vgrid(cols, rows)
    edge = [3, 3, 2, 2, 2, 3, 3, 3, 2, 2, 2, 3, 3, 2, 2, 2, 3, 3]
    for y in range(rows + 1):
        for x in range(edge[y], cols + 1):
            V[y][x] = "A"
    g, kind = surface_ground(V, set(), 77)
    sc = Scene(160, 272)
    rnd = random.Random(9)
    ash_cells = [c for c, k in kind.items() if k == "A" and not (2 <= c[0] <= 7 and 5 <= c[1] <= 11)]
    taken = []
    for name in (["decal_crack_1_v01.png", "decal_crack_2_v01.png", "decal_crack_4_v01.png", "decal_vein_1_v01.png",
                  "decal_vein_3_v01.png", "decal_bone_2_v01.png", "decal_mould_1_v01.png", "decal_mould_3_v01.png",
                  "decal_rubble_1_v01.png", "decal_rubble_3_v01.png"]):
        for _ in range(200):
            cx, cy = rnd.choice(ash_cells)
            x, y = cx * 16 + rnd.randint(0, 10), cy * 16 + rnd.randint(0, 10)
            if all(abs(x - tx) > 12 or abs(y - ty) > 10 for tx, ty in taken):
                taken.append((x, y))
                sc.decal(load(name), (x, y))
                break
    for i, y in enumerate((30, 120, 200)):
        sc.decal(load(f"decal_ashcreep_{i + 1}_v01.png"), (edge[y // 16] * 16 - 22, y))
    ent = load("dungeon_entrance_set_v01.png")       # 96 x 72, arch at (24, 12)
    sc.items.append((156, -1, ent, (36, 84), None))
    sc.put("prop_skull_stake_v02.png", 112, 52)
    sc.put("prop_bramble_dead_a_v02.png", 54, 60)
    sc.put("prop_bone_pile_b_v02.png", 116, 246)
    sc.put("item_skull_small_b_v02.png", 62, 230)
    sc.put("item_mushroom_ash_v02.png", 136, 120)
    sc.put_char("paladin", "N", 84, 206)
    sc.put_char("cleric", "N", 106, 220)
    lb, le = sc.render(g)
    paste(full, lb.crop((0, 0, 158, 272)), (0, 0))
    paste(allem, le.crop((0, 0, 158, 272)), (0, 0))


DUNGEON_ORE = {(4, 0): "tiles_ore_copper_a_v02.png", (5, 1): "tiles_ore_copper_b_v02.png",
               (14, 0): "tiles_ore_iron_a_v02.png", (19, 8): "tiles_ore_iron_b_v02.png",
               (0, 12): "tiles_ore_copper_a_v02.png"}


def dungeon():
    full = Image.new("RGBA", (SW, 272), OUT)
    allem = Image.new("RGBA", (SW, 272), T)
    dungeon_left(full, allem)

    # --- right panel: dungeon room 320 px ---
    cols, rows = 20, 17
    ore = {(4, 0): "tiles_ore_copper_a_v02.png", (5, 1): "tiles_ore_copper_b_v02.png",
           (14, 0): "tiles_ore_iron_a_v02.png", (19, 8): "tiles_ore_iron_b_v02.png", (0, 12): "tiles_ore_copper_a_v02.png"}
    g = dungeon_ground(cols, rows, 5, ore)
    sc = Scene(320, 272)
    tops = load("wall_crack_top_v01.png")
    faces = load("wall_crack_face_v01.png")
    for stage, cx in ((1, 7), (2, 11), (3, 16)):
        sc.decal(tops.crop(((stage - 1) * 16, 0, stage * 16, 16)), (cx * 16, 16))
        sc.decal(faces.crop(((stage - 1) * 16, 0, stage * 16, 24)), (cx * 16, 32 + 3))
    sc.decal(load("prop_cobweb_v02.png"), (31, 31))
    for name, x, foot in (("prop_wall_torch_a_v02.png", 76, 62), ("prop_wall_torch_a_v02.png", 216, 62)):
        sc.put(name, x, foot, phase=x)
    sc.put("prop_mine_frame_v02.png", 136, 72)
    sc.put("prop_beam_broken_v02.png", 104, 82)
    # 이단의 제단 (오염 원천) 둘레, 불은 ? 색이 정해질 때까지 꺼둠
    sc.put("heretic_shrine_v02.png", 52, 160)
    sc.put("prop_brazier_dark_c_v02.png", 22, 160)
    sc.put("prop_candles_black_a_v02.png", 100, 156)
    sc.put("prop_skull_pile_v02.png", 30, 196)
    sc.put("prop_offering_bowl_v02.png", 92, 186)
    # 창고 구석
    for name, x, foot in (("prop_crate_a_v02.png", 18, 252), ("prop_barrel_b_v02.png", 44, 252),
                          ("prop_sack_b_v02.png", 66, 254), ("prop_jar_clay_v02.png", 92, 250),
                          ("prop_pottery_broken_v02.png", 118, 254), ("prop_chain_a_v02.png", 150, 232)):
        sc.put(name, x, foot)
    # 잔해·기둥 토막·석순 (석순 a는 광부 자리를 비우려고 (262, 140)에서 옮김, a5 손질)
    for name, x, foot in (("prop_rubble_a_v02.png", 172, 100), ("prop_pillar_stub_a_v02.png", 250, 96),
                          ("prop_stalagmite_a_v02.png", 242, 196), ("prop_rubble_c_v02.png", 196, 252),
                          ("prop_stalagmite_b_v02.png", 280, 250), ("prop_pillar_stub_c_v02.png", 140, 132),
                          ("item_ore_copper_a_v02.png", 120, 96), ("item_ore_iron_a_v02.png", 232, 214)):
        sc.put(name, x, foot)
    # 오른쪽 벽의 철 광맥 칸 (19, 8)을 곡괭이로 치는 광부 (곡괭이 날 끝 = 벽 가장자리 x 294).
    # 보스 구역의 광부 지형 요소는 game-concept §12의 ? 항목이라 목업 본 판에 넣지 않는다.
    # 기둥 후보(boss_pillar_candA_v02)는 후보 시트에만 둔다 (이단의 불을 꺼 둔 것과 같은 처리, a5 손질)
    strike = miner_strike()
    sc.items.append((144, 999, strike, (250, 144 - 48), None))
    sc.put_char("archer", "E", 166, 160)
    sc.put_char("herbalist", "S", 196, 222)
    rb, re_ = sc.render(g)
    paste(full, rb, (160, 0))
    paste(allem, re_, (160, 0))
    finish(full.crop((0, 0, SW, SH)), "stage4_dungeon_v05")


# =====================================================================================
# candidates sheet (? items, human decides; nothing chosen here)
# =====================================================================================
def grass_patch(w, h, seed):
    rnd = random.Random(seed)
    g = [load(n) for n in GRASS]
    im = Image.new("RGBA", (w * 16, h * 16), T)
    for y in range(h):
        for x in range(w):
            paste(im, g[0] if rnd.random() < 0.55 else rnd.choice(g[1:]), (x * 16, y * 16))
    return im


def ash_patch(w, h, seed):
    rnd = random.Random(seed)
    g = [load(n) for n in ASH]
    im = Image.new("RGBA", (w * 16, h * 16), T)
    for y in range(h):
        for x in range(w):
            paste(im, rnd.choice(g), (x * 16, y * 16))
    return im


def build_from_sheet(sheet_name):
    sh = load(sheet_name)
    caps = [sh.crop(((i % 8) * 16, (i // 8) * 16, (i % 8) * 16 + 16, (i // 8) * 16 + 16)) for i in range(16)]
    corners = [sh.crop((i * 16, 32, i * 16 + 16, 48)) for i in range(4)]
    floors = [sh.crop((64 + i * 16, 32, 80 + i * 16, 48)) for i in range(3)]
    faces = {k: sh.crop((i * 16, 48, i * 16 + 16, 72)) for i, k in enumerate(("single", "left", "mid", "right"))}
    doors = [sh.crop((64 + i * 16, 48, 80 + i * 16, 72)) for i in range(2)]
    return dict(caps=caps, corners=corners, floors=floors, faces=faces, doors=doors)


def assemble(bs, walls, doors, floors, base):
    """a3 시트 배치 규칙 그대로 (stage4_handdrawn.py assemble과 같음)."""
    N_, E_, S_, W_ = 1, 2, 4, 8
    im = base.copy()
    w, h = im.width // 16, im.height // 16
    for (x, y) in sorted(floors):
        paste(im, bs["floors"][(x * 7 + y * 3) % 3], (x * 16, y * 16))
    solid = set(walls) | set(doors)

    def has(x, y):
        return (x, y) in solid
    for y in range(h):
        for x in range(w):
            if not has(x, y):
                continue
            mask = (N_ if has(x, y - 1) else 0) | (E_ if has(x + 1, y) else 0) | \
                   (S_ if has(x, y + 1) else 0) | (W_ if has(x - 1, y) else 0)
            paste(im, bs["caps"][mask], (x * 16, y * 16))
            for i, (dx, dy, a, b) in enumerate(((1, -1, N_, E_), (-1, -1, N_, W_), (1, 1, S_, E_), (-1, 1, S_, W_))):
                if mask & a and mask & b and not has(x + dx, y + dy):
                    paste(im, bs["corners"][i], (x * 16, y * 16))
        for x in range(w):
            if not has(x, y) or has(x, y + 1):
                continue
            lf = has(x - 1, y) and not has(x - 1, y + 1)
            rf = has(x + 1, y) and not has(x + 1, y + 1)
            if (x, y) in doors:
                t = bs["doors"][doors[(x, y)]]
            else:
                t = bs["faces"][{(0, 0): "single", (0, 1): "left", (1, 1): "mid", (1, 0): "right"}[(lf, rf)]]
            paste(im, t, (x * 16, (y + 1) * 16))
    return im


def room(x0, y0, x1, y1, door_x, door_state):
    walls, floors = set(), set()
    for x in range(x0, x1 + 1):
        walls.add((x, y0))
        walls.add((x, y1))
    for y in range(y0, y1 + 1):
        walls.add((x0, y))
        walls.add((x1, y))
    for x in range(x0 + 1, x1):
        for y in range(y0 + 1, y1 + 1):
            floors.add((x, y))
    walls.discard((door_x, y1))
    return walls, {(door_x, y1): door_state}, floors


def candidates():
    k = 3
    F, FS = font(20), font(15)
    panels = []   # (title, subtitle lines, image at 1x)

    # 1. 제단 업그레이드 1단계
    g = grass_patch(22, 7, 3)
    for i, (name, cap) in enumerate((("altar_v04.png", "지금 (v04)"), ("altar_up1_candA_v01.png", "candA 켜짐"),
                                     ("altar_up1_candA_v01_unlit.png", "candA 꺼짐"), ("altar_up1_candB_v01.png", "candB 켜짐"),
                                     ("altar_up1_candB_v01_unlit.png", "candB 꺼짐"))):
        im = load(name)
        paste(g, im, (6 + i * 70 + (4 if name == "altar_v04.png" else 0), 12 if name == "altar_v04.png" else 6))
    cleric, em = character("cleric", "S")
    paste(g, cleric, (6 + 70 + 12, 70))
    paste(g, em, (6 + 70 + 12, 70))
    panels.append(("? 제단 업그레이드 1단계 모습 (brief §5.7)",
                   ["candA = 문서 안: 받침 단 + 윗면 네 모서리 금 촛대 + 앞면 금 테 상아 천 (26색)",
                    "candB = 받침 단 + 앞 모서리의 키 큰 금 등잔대 둘(큰 불꽃) + 앞면 윗줄 금박 (23색)",
                    "둘 다 56x64, altar_v04 몸체 그대로. 받침 때문에 3x3 칸보다 옆으로 3~4px 넓다"],
                   g, ["지금 (v04)", "candA 켜짐", "candA 꺼짐", "candB 켜짐", "candB 꺼짐"], 70))

    # 2. 건설 벽 재질
    g = grass_patch(22, 8, 7)
    for idx, sheet in enumerate(("build_stone_candA_v01.png", "build_wood_candB_v01.png")):
        bs = build_from_sheet(sheet)
        x0 = 1 + idx * 11
        walls, doors, floors = room(x0, 1, x0 + 6, 5, x0 + 3, idx)
        walls |= {(x0 + 8, 1), (x0 + 8, 2), (x0 + 8, 3), (x0 + 9, 3)}
        part = assemble(bs, walls, doors, floors, Image.new("RGBA", g.size, T))
        paste(g, part, (0, 0))
    for cls, d, fx in (("paladin", "S", 20), ("herbalist", "E", 196)):
        im, em = character(cls, d)
        paste(g, im, (fx, 7 * 16 + 4 - 40 + 10))
    panels.append(("? 건설 벽 재질 (brief §5.7 / gameplay-design §3.3)",
                   ["candA = 돌만: 제단 회색 마름돌 윗면 + 24px 벽돌 앞면, 판석 바닥, 문짝만 나무 (16색)",
                    "candB = 나무 + 돌: 돌 기초 위 나무 벽, 엇갈린 널판 바닥 (14색). 나무는 game-concept §12 ?(나무를 슬라이스에 넣을지)에 달림",
                    "왼쪽 방 = candA (문 닫힘), 오른쪽 방 = candB (문 열림). 같은 이웃 마스크 16장 + 안쪽 모서리 4장 배치"],
                   g, ["candA 돌만", "candB 나무 + 돌"], 176))

    # 3. 이단 쪽 불 색
    g = ash_patch(22, 5, 11)
    dk = Image.new("RGBA", g.size, (26, 23, 20, 150))
    g.alpha_composite(dk)
    shrine = load("heretic_shrine_v02.png")
    for idx, cand in enumerate(("candA", "candB")):
        x0 = 8 + idx * 176
        s = Image.new("RGBA", (48, 56), T)
        paste(s, shrine, (0, 8))
        for (fx, fy, size) in ((21, 11, "small"), (3, 30, "large"), (37, 30, "large")):
            paste(s, flame(f"flame_heretic_{size}_{cand}_v01.png", 0), (fx, fy))
        paste(g, s, (x0, 12))
        paste(g, load("prop_candles_black_b_v02.png"), (x0 + 56, 36))
        paste(g, flame(f"flame_heretic_small_{cand}_v01.png", 1), (x0 + 56 + 15, 36 + 2 - 7))
        for i in range(4):
            paste(g, flame(f"flame_heretic_large_{cand}_v01.png", i), (x0 + 96 + i * 12, 30))
        paste(g, flame("flame_large_v01.png", 0), (x0 + 96 + 2, 56))
        paste(g, flame("flame_small_v01.png", 0), (x0 + 112, 59))
    panels.append(("? 이단 쪽 불의 색 (brief §5.7)",
                   ["candA = 촛불 금빛: 거룩한 불과 같은 계열, 갈라진 혀 모양으로만 다름. 심 #f4c95d (거룩한 심 #fff6dc보다 한 단 낮음)",
                    "candB = 악마 주황: brief §4 악마 줄만 (#ff7a1a 심 / #c8321f / #8f1a1a / #5c1010, 연기 #2a0808)",
                    "각 판: 이단의 제단 v02 위 (그림 설명용, 제단 파일은 그대로), 검은 초, 큰 불 4프레임, 오른쪽 아래 작은 둘 = 거룩한 공유 불꽃(비교)"],
                   g, ["candA 촛불 금빛", "candB 악마 주황"], 176))

    # 4. 보스 구역의 광부 지형 요소
    dun = load("tiles_dungeon_v02.png")
    fl = dun.crop((32, 32, 48, 48))
    g = Image.new("RGBA", (22 * 16, 5 * 16), T)
    for y in range(5):
        for x in range(22):
            paste(g, fl, (x * 16, y * 16))
    for i, name in enumerate(("boss_pillar_candA_v01_b.png", "boss_pillar_candA_v02.png")):
        paste(g, load(name), (12 + i * 48, 10))
    strike = miner_strike()
    paste(g, strike, (60, 10 + 61 - 47))
    panels.append(("? 보스 구역의 광부 지형 요소 (game-concept §12)",
                   ["candA = 문서 안 '부수면 잔해가 떨어지는 금 간 받침 기둥' (32x64). 다른 안(candB)은 만들지 않았다",
                    "왼쪽 = 생성 원본 b, 가운데 = 손질판 v02 (던전 따뜻한 회색, 손으로 금 하나). 상태 4단계는 이 안이 정해지면 손으로 만든다"],
                   g, ["원본 b", "손질 v02"], 48))

    W = 22 * 16 * k + 40
    blocks = []
    for title, lines, im, caps, step in panels:
        big = up(im, k)
        hgt = 30 + 22 * len(lines) + 8 + big.height + 12
        b = Image.new("RGBA", (W, hgt), (26, 23, 20, 255))
        d = ImageDraw.Draw(b)
        d.text((20, 6), title, font=F, fill=(244, 201, 93))
        for i, ln in enumerate(lines):
            d.text((20, 34 + 22 * i), ln, font=FS, fill=(239, 227, 198))
        y0 = 34 + 22 * len(lines) + 4
        paste(b, big, (20, y0))
        for i, c in enumerate(caps):
            d.text((20 + (6 + i * step) * k, y0 + 2), c, font=FS, fill=(255, 255, 255), stroke_width=2,
                   stroke_fill=(26, 23, 20))
        blocks.append(b)
    head = Image.new("RGBA", (W, 50), (26, 23, 20, 255))
    ImageDraw.Draw(head).text((20, 12), "4단계 본 제작 후보 시트 (2026-10-21 밤). 사람이 고를 ? 항목. 아무것도 고르지 않았다. 3배",
                              font=F, fill=(239, 227, 198))
    blocks.insert(0, head)
    out = Image.new("RGBA", (W, sum(b.height for b in blocks)), (26, 23, 20, 255))
    y = 0
    for b in blocks:
        paste(out, b, (0, y))
        y += b.height
    save(out.convert("RGB"), "stage4_candidates_v01.png")


# =====================================================================================
# 손질 2 통합 (s3, 2026-10-22 새벽): s1 크기 고침(size 24) + s2 손질을 목업에 넣는다. 생성 없음.
# 위의 fix / surface / dungeon / candidates 출력(v04·v05·v01)은 건드리지 않는다.
# =====================================================================================
def _fix5():
    """s2 script (tools/art/stage4_fix5.py): same candle rim / lit-glass rules, imported, not copied."""
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import stage4_fix5
    return stage4_fix5


# ground lantern v03 (s1, 24 x 24): the two glass panes are open (transparent) between the bars,
# rows 12-16, x9-10 and x13-14. '.' keeps the pixel. Same colours/levels as the s2 lit lanterns:
# glass body <= #f4c95d, the core #fff6dc next to the centre bar (the flame sits behind it).
GROUND_V03_LIT = ((9, 12), ["B....B",
                            "HH..HH",
                            "HE..EH",
                            "HH..HH",
                            "D....D"])


def fix2():
    f5 = _fix5()
    # 1. black candles b (s1 v03): 10 near-black colours, a dark lump on the dungeon floor at 1x.
    #    s2's item rule: wax just inside the outer outline on the left / top -> ash rim #8c7b66,
    #    upper-left corners #b2a693. No flame colour (heretic fire colour is still ?).
    src = load("prop_candles_black_b_v03.png")
    out, n = f5.candle_rim(src)
    assert n > 0
    save(out, "prop_candles_black_b_v04.png")
    print("  candles_black_b rim px", n)
    # 2. ground lantern v03 lit pair (s2 made lit pairs for the v02 lanterns only)
    unlit = load("prop_lantern_ground_v03.png")
    px = unlit.load()
    (x0, y0), rows = GROUND_V03_LIT
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != ".":
                assert px[x0 + x, y0 + y][3] == 0, (x0 + x, y0 + y)     # only the open panes
    lit = unlit.copy()
    f5.overlay(lit, (x0, y0), rows, f5.GLOW)
    em = f5.emissive_from(lit, unlit)
    bx = f5.glow_box(lit, unlit)
    save(lit, "prop_lantern_ground_v03_lit.png")
    save(em, "prop_lantern_ground_v03_emissive.png")
    print("  lantern_ground_v03_lit glass box", bx, "glow centre", ((bx[0] + bx[2] + 1) / 2, (bx[1] + bx[3] + 1) / 2))


# flames for the v03 light props: file -> [(flame strip, flame frame top-left in prop coordinates)]
# (anchors from the s2 record: candle stands grew to 32 x 40, relic bench v03 has a cold wick)
LIGHTS_V5 = {
    "prop_candle_stand_a_v03.png": [("flame_small_v01.png", (14, 0))],
    "prop_candle_stand_b_v03.png": [("flame_small_v01.png", (15, -1))],
    "prop_candle_stand_c_v03.png": [("flame_small_v01.png", (15, -1)), ("flame_small_v01.png", (7, 4)),
                                    ("flame_small_v01.png", (22, 4))],
    "relic_bench_v03.png": [("flame_small_v01.png", (37, -4))],
    "prop_fire_basket_v02.png": [("flame_large_v01.png", (13, -2))],
    "prop_campfire_ring_v02.png": [("flame_large_v01.png", (13, 4))],
    "prop_wall_torch_a_v02.png": [("flame_large_v01.png", (9, -4))],
}
# lit lanterns: glow centre in file coordinates (s2 record; ground v03 from fix2) = engine point light
GLOW_V5 = {
    "prop_lantern_post_a_v03_lit.png": (23, 21),
    "prop_lantern_post_b_v03_lit.png": (22.5, 18),
    "prop_lantern_post_c_v03_lit.png": (16, 14.5),
    "prop_lantern_ground_v02_lit.png": (16, 22),
    "prop_lantern_wall_v02_lit.png": (16.5, 22),
    "prop_lantern_ground_v03_lit.png": (12, 14.5),
}


class Scene5(Scene):
    """Scene with multi-flame light props and lit lanterns. put5 returns the canvas top-left."""

    def put5(self, name, x, foot, phase=0):
        im = load(name)
        em = None
        if name in LIGHTS_V5:
            e = Image.new("RGBA", (im.width + 16, im.height + 16), T)
            for i, (strip, (fx, fy)) in enumerate(LIGHTS_V5[name]):
                paste(e, flame(strip, (phase + i * 2) % 4), (fx + 8, fy + 8))
            em = (e, (-8, -8))
        elif name.endswith("_lit.png"):
            # the glowing glass does not darken at evening (same layer as the flames)
            mask = load(name.replace("_lit.png", "_emissive.png")).getchannel("A")
            em = (Image.composite(im, Image.new("RGBA", im.size, T), mask), (0, 0))
        _, _, _, by = bbox(im)
        y = foot - by - 1
        self.items.append((foot, self.n, im, (x, y), em))
        self.n += 1
        return x, y


def flame_lights(name, xy, r=(6, 34)):
    """eve light circles for the flames of a light prop placed at xy (canvas top-left)."""
    out = []
    for strip, (fx, fy) in LIGHTS_V5[name]:
        w = 4 if "small" in strip else 6
        h = 7 if "small" in strip else 10
        out.append((xy[0] + fx + w / 2, xy[1] + fy + h / 2, r[0], r[1]))
    return out


def ash_decals(sc, kind, rnd):
    """surface v04 decal scatter (same names, order and rules)."""
    ash_cells = [c for c, k in kind.items() if k == "A"]
    decals = (["decal_crack_1_v01.png", "decal_crack_2_v01.png", "decal_crack_3_v01.png", "decal_crack_4_v01.png"] * 2
              + ["decal_vein_1_v01.png", "decal_vein_2_v01.png", "decal_vein_3_v01.png"]
              + ["decal_bone_1_v01.png", "decal_bone_2_v01.png", "decal_bone_3_v01.png",
                 "decal_mould_1_v01.png", "decal_mould_2_v01.png", "decal_mould_3_v01.png"]
              + ["decal_rubble_1_v01.png", "decal_rubble_2_v01.png", "decal_rubble_3_v01.png", "decal_rubble_4_v01.png"] * 2)
    taken = []
    for name in decals:
        for _ in range(200):
            cx, cy = rnd.choice(ash_cells)
            x, y = cx * 16 + rnd.randint(0, 10), cy * 16 + rnd.randint(0, 10)
            if all(abs(x - tx) > 12 or abs(y - ty) > 10 for tx, ty in taken):
                taken.append((x, y))
                sc.decal(load(name), (x, y))
                break
    for i, y in enumerate((20, 70, 118, 190, 236)):
        ex = ASH_EDGE[min(17, y // 16)] * 16
        sc.decal(load(f"decal_ashcreep_{i % 3 + 1}_v01.png"), (ex - 26 - (i % 2) * 6, y))


def surface5_scene(lit):
    """v04 layout with the new files. lit = evening (lanterns lit). Returns (base, emissive, light circles)."""
    V, watered = surface_map()
    ground, kind = surface_ground(V, watered, 20261021, "tiles_grass-path_v03.png", "tiles_grass-path_v03.json")
    sc = Scene5(SW, SH)
    ash_decals(sc, kind, random.Random(4))
    lights = [(256, 84, 100, 150)]                       # 제단 빛 (안전 반경, v04와 같음)

    crops = load("crops_v03_sheet.png")

    def crop(r, c):
        return crops.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16))
    for r in range(3):
        for i in range(5):
            sc.put(crop(r, i), (6 + i) * 16, (2 + r) * 16 + 16)
    for i, (r, stage) in enumerate(((0, 1), (1, 2), (2, 1), (0, 3), (1, 0))):         # 물 준 줄
        sc.put(crop(r, stage), (6 + i) * 16, 5 * 16 + 16)
    for i in range(3):                                                                    # 시든 작물
        sc.put(crop(i, 6), (20 + i) * 16, 14 * 16 + 16)

    # 제단과 둘레: 촛대 v03 (32x40, 공유 불꽃), 공유 창고 + v03 통·상자·자루 (size 24)
    alt, alt_em = altar_lit()
    sc.items.append((109, -1, alt, (232, 52), (alt_em, (0, 0))))
    for name, x, foot, ph in (("prop_candle_stand_a_v03.png", 200, 106, 1), ("prop_candle_stand_b_v03.png", 268, 106, 3)):
        lights += flame_lights(name, sc.put5(name, x, foot, ph))
    sc.put5("storage_chest_v02.png", 296, 118)
    for name, x, foot in (("prop_barrel_a_v03.png", 338, 117), ("prop_crate_a_v03.png", 353, 121),
                          ("prop_sack_a_v03.png", 370, 119), ("prop_barrel_c_v03.png", 282, 130),
                          ("prop_sack_small_v03.png", 296, 132)):
        sc.put5(name, x, foot)
    # 작업대: 조제대 v05, 기본 작업대 v03, 모루 v03, 성물 제작대 v03 (빈 심지 + 공유 불꽃)
    sc.put5("alchemy_table_v05.png", 92, 134)
    sc.put5("workbench_v03.png", 144, 134)
    sc.put5("anvil_v03.png", 196, 136)
    lights += flame_lights("relic_bench_v03.png", sc.put5("relic_bench_v03.png", 324, 56, 2), (4, 26))
    # 작업대 옆에 떨어진 재료 (v03 정면 아이콘; 정면 여부는 사람 확인 대기, v02도 둠)
    for name, x, foot in (("item_planks_a_v03.png", 150, 150), ("item_ingot_iron_a_v03.png", 222, 146),
                          ("item_stone_block_v03.png", 80, 150), ("item_cloth_a_v03.png", 312, 70)):
        sc.put5(name, x, foot)
    # 조명: 불 바구니·모닥불 (v04와 같음), 랜턴 기둥 v03 셋 (낮 꺼짐, 저녁 켜짐 + 빛)
    sc.put5("prop_fire_basket_v02.png", 292, 54, 2)
    sc.put5("prop_campfire_ring_v02.png", 230, 246, 0)
    lights += [(308, 28, 12, 54), (246, 224, 16, 64)]
    for name, x, foot in (("prop_lantern_post_a_v03", 30, 150), ("prop_lantern_post_c_v03", 318, 150),
                          ("prop_lantern_post_b_v03", 96, 214)):
        nm = f"{name}_lit.png" if lit else f"{name}.png"
        xy = sc.put5(nm, x, foot)
        gx, gy = GLOW_V5[f"{name}_lit.png"]
        if lit:
            lights.append((xy[0] + gx, xy[1] + gy, 5, 32))      # smaller than the altar pool (safety = altar light)
    # 채집물 (v04와 같음. 나뭇가지는 game-concept §12 ?(나무)와 닿을 수 있어 기록에 적음)
    for name, x, foot in (("item_wild_herb_clump_v02.png", 8, 30), ("item_mushroom_a_v02.png", 30, 58),
                          ("item_stone_a_v02.png", 56, 24), ("item_sticks_a_v02.png", 12, 96),
                          ("item_wild_healing_v02.png", 50, 104), ("item_mushroom_d_v02.png", 66, 70),
                          ("item_wild_healing_v02.png", 8, 236), ("item_wild_buff_v02.png", 34, 250),
                          ("item_mushroom_c_v02.png", 66, 232), ("item_stone_mossy_v02.png", 100, 252),
                          ("item_sticks_b_v02.png", 128, 228), ("item_mushroom_b_v02.png", 160, 262),
                          ("item_stone_b_v02.png", 210, 18),
                          ("item_wild_buff_v02.png", 348, 236), ("item_wild_poison_v02.png", 370, 82),
                          ("crop_poison_wild_v01.png", 378, 200), ("item_wild_poison_v02.png", 360, 256)):
        sc.put5(name, x, foot)
    # 위협 소품 (잿빛 땅. 곰팡이 덩이만 v03)
    for name, x, foot in (("prop_bone_pile_a_v02.png", 406, 40), ("prop_idol_broken_a_v02.png", 446, 62),
                          ("prop_ritual_stone_a_v02.png", 420, 104), ("prop_brazier_dark_a_v02.png", 446, 150),
                          ("prop_skull_stake_v02.png", 404, 186), ("prop_bramble_dead_b_v02.png", 446, 214),
                          ("prop_boulder_corrupt_v02.png", 410, 262), ("item_mushroom_ash_v02.png", 452, 252),
                          ("item_skull_small_a_v02.png", 430, 140), ("item_mould_clump_v03.png", 458, 98),
                          ("item_stone_veined_v02.png", 424, 220)):
        sc.put5(name, x, foot)
    sc.put_char("cleric", "S", 256, 142)
    sc.put_char("herbalist", "W", 190, 98)
    sc.put_char("miner", "N", 212, 166)
    sc.put_char("paladin", "W", 330, 186)
    sc.put_char("archer", "E", 372, 168)
    base, emis = sc.render(ground)
    return base, emis, lights


def surface5():
    base, _, _ = surface5_scene(False)
    finish(base.crop((0, 0, SW, SH)), "stage4_mockup_v05_day")
    base, emis, lights = surface5_scene(True)
    h, w = base.height, base.width
    edge_px = np.array([ASH_EDGE[min(len(ASH_EDGE) - 1, int(y // 16))] * 16 for y in range(h)], float)
    xx = np.arange(w)[None, :].astype(float)
    ash_amt = np.clip((xx - (edge_px[:, None] - 12)) / 20.0, 0, 1)
    eve = darken(base, emis, lights, ash_amt).crop((0, 0, SW, SH))
    finish(eve, "stage4_mockup_v05_eve")


def dungeon6():
    full = Image.new("RGBA", (SW, 272), OUT)
    allem = Image.new("RGBA", (SW, 272), T)
    dungeon_left(full, allem)          # 왼쪽 판(지상의 던전 입구)은 v05와 같다

    cols, rows = 20, 17
    g = dungeon_ground(cols, rows, 5, DUNGEON_ORE)
    sc = Scene5(320, 272)
    tops = load("wall_crack_top_v01.png")
    faces = load("wall_crack_face_v01.png")
    for stage, cx in ((1, 7), (2, 11), (3, 16)):
        sc.decal(tops.crop(((stage - 1) * 16, 0, stage * 16, 16)), (cx * 16, 16))
        sc.decal(faces.crop(((stage - 1) * 16, 0, stage * 16, 24)), (cx * 16, 32 + 3))
    sc.decal(load("prop_cobweb_v02.png"), (31, 31))
    for x in (76, 216):                       # 플레이어가 놓는 횃불 (공유 불꽃, v05와 같음)
        sc.put5("prop_wall_torch_a_v02.png", x, 62, x)
    sc.put5("prop_mine_frame_v02.png", 136, 72)
    sc.put5("prop_beam_broken_v02.png", 104, 82)
    # 이단의 제단 둘레 (불은 ? 색이 정해질 때까지 꺼 둠): v03 위협 소품 (size 24) + 검은 초 b v04
    sc.put5("heretic_shrine_v02.png", 52, 160)
    for name, x, foot in (("prop_brazier_dark_c_v03.png", 24, 160), ("prop_candles_black_a_v03.png", 102, 157),
                          ("prop_candles_black_b_v04.png", 118, 170), ("prop_skull_pile_v03.png", 34, 196),
                          ("prop_offering_bowl_v03.png", 94, 188), ("prop_bone_cage_v03.png", 128, 200),
                          ("item_candle_black_a_v03.png", 36, 174), ("item_bone_charm_v03.png", 70, 204)):
        sc.put5(name, x, foot)
    # 창고 구석 (v03 size 24) + 플레이어가 놓은 켜진 땅 랜턴 v03
    for name, x, foot in (("prop_crate_a_v03.png", 20, 252), ("prop_barrel_b_v03.png", 40, 252),
                          ("prop_sack_b_v03.png", 58, 254), ("prop_jar_clay_v03.png", 80, 250),
                          ("prop_pottery_broken_v03.png", 100, 254), ("prop_barrel_c_v03.png", 30, 236),
                          ("prop_lantern_ground_v03_lit.png", 124, 252), ("prop_chain_a_v02.png", 150, 232)):
        sc.put5(name, x, foot)
    # 잔해·기둥 토막·석순 v03 (바닥에서 뗀 판), 광석 아이템
    for name, x, foot in (("prop_rubble_a_v03.png", 172, 100), ("prop_pillar_stub_a_v03.png", 250, 97),
                          ("prop_stalagmite_a_v03.png", 242, 197), ("prop_rubble_c_v03.png", 196, 253),
                          ("prop_stalagmite_b_v03.png", 280, 251), ("prop_pillar_stub_c_v03.png", 140, 133),
                          ("item_ore_copper_a_v02.png", 120, 96), ("item_ore_iron_a_v02.png", 232, 214),
                          ("item_ore_iron_c_v03.png", 262, 226)):
        sc.put5(name, x, foot)
    # 오른쪽 벽 철 광맥 칸을 치는 광부 (v05와 같은 자리. 보스 구역 요소 ?는 넣지 않음)
    strike = miner_strike()
    sc.items.append((144, 999, strike, (250, 144 - 48), None))
    sc.put_char("archer", "E", 166, 160)
    sc.put_char("herbalist", "S", 196, 222)
    rb, re_ = sc.render(g)
    paste(full, rb, (160, 0))
    paste(allem, re_, (160, 0))
    finish(full.crop((0, 0, SW, SH)), "stage4_dungeon_v06")


# =====================================================================================
# scale compare: old (v02) and new (v03) props on one ground line next to the character, 3x
# =====================================================================================
SCALE_ROWS = [
    ("grass", [("char",), ("prop_crate_a_v02", "prop_crate_a_v03"), ("prop_barrel_a_v02", "prop_barrel_a_v03"),
               ("prop_barrel_b_v02", "prop_barrel_b_v03"), ("prop_barrel_c_v02", "prop_barrel_c_v03"),
               ("prop_barrel_tipped_v02", "prop_barrel_tipped_v03"), ("prop_sack_a_v02", "prop_sack_a_v03"),
               ("prop_sack_b_v02", "prop_sack_b_v03", "prop_sack_small_v03"), ("storage_chest_v02",), ("char",)]),
    ("grass", [("char",), ("prop_crate_smashed_v02", "prop_crate_smashed_v03"),
               ("prop_barrel_smashed_v03", "prop_barrel_smashed_v04"),
               ("prop_pottery_broken_v02", "prop_pottery_broken_v03"), ("prop_jar_clay_v02", "prop_jar_clay_v03"),
               ("prop_lantern_ground_v02", "prop_lantern_ground_v03", "prop_lantern_ground_v03_lit"),
               ("workbench_v03",), ("char",)]),
    ("grass", [("char",), ("prop_lantern_post_a_v02", "prop_lantern_post_a_v03"),
               ("prop_lantern_post_b_v02", "prop_lantern_post_b_v03"), ("prop_lantern_post_c_v02", "prop_lantern_post_c_v03"),
               ("prop_candle_stand_a_v02", "prop_candle_stand_a_v03"), ("prop_candle_stand_b_v02", "prop_candle_stand_b_v03"),
               ("prop_candle_stand_c_v02", "prop_candle_stand_c_v03"), ("char",)]),
    ("dungeon", [("char",), ("prop_offering_bowl_v02", "prop_offering_bowl_v03"),
                 ("prop_candles_black_a_v02", "prop_candles_black_a_v03"),
                 ("prop_candles_black_b_v02", "prop_candles_black_b_v03", "prop_candles_black_b_v04"),
                 ("prop_skull_pile_v02", "prop_skull_pile_v03"), ("prop_brazier_dark_c_v02", "prop_brazier_dark_c_v03"),
                 ("prop_bone_cage_v02", "prop_bone_cage_v03"), ("char",)]),
]
# flames shown on the candle stands (old v02 anchors = surface v04 LIGHT_ANCHORS; candelabrum c from the s2 record)
SCALE_FLAMES_V02 = {"prop_candle_stand_a_v02": [(14, -5)], "prop_candle_stand_b_v02": [(15, -4)],
                    "prop_candle_stand_c_v02": [(15, -4), (7, 1), (22, 1)]}


def _strip_sprite(name):
    """sprite cropped to its opaque columns, rows kept from the top of the opaque box to the bottom."""
    if name == "char":
        im, _ = character("base", "S")       # bare base body, no signature (03-pixel walk v02, 28 px)
    else:
        im = load(f"{name}.png")
        fl = [("flame_small_v01.png", a) for a in SCALE_FLAMES_V02.get(name, [])] + LIGHTS_V5.get(f"{name}.png", [])
        if fl:
            big = Image.new("RGBA", (im.width, im.height + 8), T)
            paste(big, im, (0, 8))
            for i, (strip, (fx, fy)) in enumerate(fl):
                paste(big, flame(strip, i % 4), (fx, fy + 8))
            im = big
    x0, y0, x1, y1 = bbox(im)
    return im.crop((x0, y0, x1 + 1, y1 + 1))


def scale_compare():
    k = 3
    fnt = ImageFont.load_default(size=13)     # Pillow's bundled font: same bytes with the pinned pillow
    fl_e = (255, 246, 220)
    rows_img = []
    floor = load("tiles_dungeon_v02.png").crop((32, 32, 48, 48))
    for ground, groups in SCALE_ROWS:
        sprites = [[(n, _strip_sprite(n)) for n in g] for g in groups]
        top = max(im.height for grp in sprites for _, im in grp)
        H = top + 14
        W = sum(sum(im.width for _, im in grp) + 3 * (len(grp) - 1) for grp in sprites) + 10 * len(sprites) + 10
        if ground == "grass":
            g = grass_patch((W + 15) // 16, (H + 15) // 16, 21).crop((0, 0, W, H))
        else:
            g = Image.new("RGBA", (W, H), T)
            for yy in range(0, H, 16):
                for xx in range(0, W, 16):
                    paste(g, floor, (xx, yy))
        base_y = H - 6                         # ground line (bottom opaque row + 1)
        x = 8
        labels = []    # one label per group: name + opaque height of each file (prop only, no flame)
        for grp in sprites:
            gx = x
            hs = []
            for n, im in grp:
                paste(g, im, (x, base_y - im.height))
                if n == "char":
                    hs.append(f"{im.height}")
                else:
                    _, y0, _, y1 = bbox(load(f"{n}.png"))
                    hs.append(f"{n[-3:]} {y1 - y0 + 1}")
                x += im.width + 3
            x += 10 - 3
            n0 = grp[0][0]
            labels.append((gx, n0, "character " + hs[0] if n0 == "char"
                           else n0.replace("prop_", "")[:-4] + ": " + " -> ".join(hs)))
        big = up(g, k)
        d = ImageDraw.Draw(big)
        # dashed guides: character height (28) and one tile (16) above the ground line
        ch_h = _strip_sprite("char").height
        for hgt, col in ((ch_h, (244, 201, 93)), (16, (239, 227, 198))):
            yy = (base_y - hgt) * k
            for xx in range(0, big.width, 12):
                d.line((xx, yy, xx + 5, yy), fill=col, width=1)
        band = Image.new("RGBA", (big.width, 34), (26, 23, 20, 255))
        db = ImageDraw.Draw(band)
        for i, (lx, n, text) in enumerate(labels):
            db.text((lx * k, 2 + (i % 2) * 16), text, font=fnt, fill=fl_e if n != "char" else (244, 201, 93))
        blk = Image.new("RGBA", (big.width, big.height + band.height), (26, 23, 20, 255))
        paste(blk, band, (0, 0))
        paste(blk, big, (0, band.height))
        rows_img.append(blk)
    W = max(r.width for r in rows_img) + 20
    head = Image.new("RGBA", (W, 30), (26, 23, 20, 255))
    ImageDraw.Draw(head).text((10, 8), "stage 4 scale: old v02 (left of each group) -> new v03/v04, character 28 px "
                                       "(gold dashes), one tile 16 px (pale dashes), 3x. Numbers = version and opaque height of the file in px (flames not counted).",
                              font=fnt, fill=(239, 227, 198))
    out = Image.new("RGBA", (W, head.height + sum(r.height + 8 for r in rows_img)), (26, 23, 20, 255))
    paste(out, head, (0, 0))
    y = head.height
    for r in rows_img:
        paste(out, r, (10, y))
        y += r.height + 8
    save(out.convert("RGB"), "stage4_scale_compare_v01.png")


# =====================================================================================
# rules: brief §5.7 hand-fix rules on every adoption candidate of this pass (s1, s2, s3)
# =====================================================================================
RULES_DROPPED = {"prop_barrel_smashed_v04.png"}      # s3: not adopted (reads as an intact barrel with a ring)
RULES_THREAT = ("prop_offering_bowl", "prop_candles_black", "prop_skull_pile", "prop_brazier_dark", "prop_bone_cage",
                "item_mould_clump", "item_candle_black", "item_bone_charm")


def rule_files():
    """adoption candidates of 손질 2: s1 18 (size 24 props, smashed barrel v04 dropped), s2 49, s3 3."""
    s1 = [f"prop_{n}_v03.png" for n in ("crate_a", "barrel_a", "barrel_b", "barrel_c", "barrel_tipped", "crate_smashed",
                                        "sack_a", "sack_b", "sack_small", "pottery_broken", "jar_clay", "lantern_ground",
                                        "offering_bowl", "candles_black_a", "candles_black_b", "skull_pile",
                                        "brazier_dark_c", "bone_cage")]
    s2 = [f"prop_{n}_v03.png" for n in ("lantern_post_a", "lantern_post_b", "lantern_post_c", "candle_stand_a",
                                        "candle_stand_b", "candle_stand_c", "rubble_a", "rubble_b", "rubble_c",
                                        "pillar_stub_a", "pillar_stub_b", "pillar_stub_c", "stalagmite_a", "stalagmite_b")]
    s2 += [f"prop_lantern_post_{c}_v03_{k}.png" for c in "abc" for k in ("lit", "emissive")]
    s2 += [f"prop_lantern_{n}_v02_{k}.png" for n in ("ground", "wall") for k in ("lit", "emissive")]
    s2 += ["relic_bench_v03.png", "anvil_v03.png", "workbench_v03.png", "tiles_grass-path_v03.png",
           "build_stone_candA_v02.png", "build_wood_candB_v02.png"]
    s2 += [f"altar_up1_candA_v02{s}.png" for s in ("", "_unlit", "_litbase", "_emissive")]
    s2 += [f"item_{n}_v03.png" for n in ("mould_clump", "leather_c", "candle_black_a", "candle_black_b", "ore_iron_c",
                                         "bone_charm", "stone_block", "ingot_copper_a", "ingot_copper_b", "ingot_iron_a",
                                         "ingot_iron_b", "planks_a", "planks_b", "planks_c", "cloth_a")]
    s3 = ["prop_candles_black_b_v04.png", "prop_lantern_ground_v03_lit.png", "prop_lantern_ground_v03_emissive.png"]
    names = sorted(s1 + s2 + s3)
    assert len(names) == len(set(names)) == 70 and not set(names) & RULES_DROPPED, len(names)
    return names


def rules(names=None):
    import colorsys
    names = names or rule_files()
    fl_e = (0xFF, 0xF6, 0xDC)
    lum = lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
    bad = []
    for n in names:
        im = load(n)
        a = np.asarray(im)
        alphas = sorted(set(np.unique(a[..., 3]).tolist()))
        op = a[..., 3] > 0
        cols = {tuple(int(v) for v in c[:3]) for c in a[op]}
        if n.endswith("_emissive.png"):
            lv = sorted({c[0] for c in cols})
            ok = set(alphas) <= {0, 255} and all(c[0] == c[1] == c[2] for c in cols)
            print(f"{n}: emissive levels {lv}, alpha {alphas} -> {'OK' if ok else 'CHECK'}")
            bad += [] if ok else [n]
            continue
        kind = "item" if n.startswith("item_") else ("tile" if n.startswith(("tiles_", "build_")) else "object")
        limit = {"item": 16, "object": 24, "tile": None}[kind]
        side = "threat" if n.startswith(RULES_THREAT) or "rubble" in n or "pillar" in n or "stalagmite" in n else "life"
        maxl = max(lum(c) for c in cols if c != fl_e)
        core = fl_e in cols
        cool = [c for c in cols if c[2] > c[0] and colorsys.rgb_to_hsv(*[v / 255 for v in c])[1] < 0.35]
        # outline: opaque pixels with a transparent (or off-canvas) 4-neighbour
        pad = np.pad(op, 1)
        edge = op & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
        is_out = (a[..., 0] == 0x1A) & (a[..., 1] == 0x17) & (a[..., 2] == 0x14)
        out_pct = 100.0 * (edge & is_out).sum() / max(edge.sum(), 1)
        cap = 226.0 if kind == "tile" else 215.0
        ok_n = limit is None or len(cols) <= limit
        ok = ok_n and maxl <= cap and not cool and set(alphas) <= {0, 255} and (kind == "tile" or out_pct >= 90)
        print(f"{n}: {kind}/{side} {len(cols)} colours (<= {limit or '-'}), max luma {maxl:.1f}"
              f"{' + flame core 245.7' if core else ''}, alpha {alphas}, cool greys {len(cool)}, "
              f"outline {out_pct:.0f}% of edge px -> {'OK' if ok else 'CHECK'}")
        bad += [] if ok else [n]
    print(f"{len(names)} files, CHECK: {bad if bad else 'none'}")
    return bad


def main(what):
    if what in ("fix", "all"):
        fix()
    if what in ("surface", "all"):
        surface()
    if what in ("dungeon", "all"):
        dungeon()
    if what in ("candidates", "all"):
        candidates()
    if what in ("fix2", "all"):
        fix2()
    if what in ("surface5", "all"):
        surface5()
    if what in ("dungeon6", "all"):
        dungeon6()
    if what in ("scale", "all"):
        scale_compare()
    if what == "rules":
        rules()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "all")

# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""4단계 소품 크기 고침 (s1, 2026-10-22): size-24 re-generation of the small real-world props of the size-32 bundle.
기록: assets/concept/04-env/_records/s1.md (prompts.md에는 통합 때 옮긴다).

usage (어디서 돌려도 된다. 경로는 이 파일 기준):
    uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I tools/art/stage4_props24.py

Reads  04-env/props24_v01_sheet.png (raw review sheet of PixelLab object aa947894-a736-4170-848b-a3615b4861a1,
       192x192, 8x8 cells of 24px, index = row*8 + col), 04-env/crops_v03_sheet.png, 04-env/items_v04_strip.png
       (reference colours for the soft snap, as in stage4_props.py), and for the scale check the v02 props,
       workbench_v02, storage_chest_v02, grass / dungeon tiles and 03-pixel/base_body_v02_walk.png.
Writes 04-env/prop_<name>_v03.png (24x24; barrel_smashed is _v04 because the integrator's _v03 exists),
       04-env/props24_v02_sheet.png (keepers, packed 8 per row in bundle-index order),
       04-env/stage4_s1_scale_check.png (top-left: the 480-wide panel at 1x; below: the same panel at 3x).
       No text is drawn, so the output does not depend on installed fonts (byte-identical on rerun).

The rules are copied from tools/art/stage4_props.py (a2, brief sec.5.7 손질 규칙) without editing that file
(it runs its whole pipeline at import time, so it cannot be imported):
 1 alpha 0/255, drop the baked ground-shadow colours reachable from the border (none in this bundle), specks <= 2 px
 2 sprite-specific edits (SPECIAL below)
 3 cool to warm greys (B > R greys, blue hues, dead-neutral greys -> warm grey of the same luma)
 4 family snaps (threat violet / olive mould, life greens; same rules as a2)
 5 luma cap 215
 6 outline #1a1714 (near-black -> outline, dark boundary -> outline, bright boundary gets an outside px)
 7 colour reduction to <= 24 (CIELAB closest pair, palette stays a subset)
 8 soft snap to brief sec.4 / crops_v03 / items_v04 colours within dE76 6
"""
import colorsys
import os
import random

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ENV = os.path.join(ROOT, "assets", "concept", "04-env")
PIX = os.path.join(ROOT, "assets", "concept", "03-pixel")
CELL = 24
OUT = (0x1a, 0x17, 0x14)

# ---- keepers: bundle index -> (file name stem, replaces v02 prop?, threat side?)
# object ids are the completed objects promoted with select_object_frames (tag s1-stage4-props24)
KEEP = {
    2: ("crate_a", True, False),
    10: ("barrel_a", True, False),
    14: ("barrel_b", True, False),
    18: ("barrel_c", True, False),          # small keg
    22: ("barrel_tipped", True, False),
    27: ("crate_smashed", True, False),
    29: ("barrel_smashed", True, False),    # -> _v04 (integrator wrote _v03)
    32: ("sack_a", True, False),
    37: ("sack_b", True, False),
    39: ("sack_small", False, False),       # new: shorter sack (no v02)
    42: ("pottery_broken", True, False),
    44: ("jar_clay", True, False),
    48: ("lantern_ground", True, False),
    51: ("offering_bowl", True, True),
    54: ("candles_black_a", True, True),
    57: ("candles_black_b", True, True),
    58: ("skull_pile", True, True),
    61: ("brazier_dark_c", True, True),
    62: ("bone_cage", True, True),
}
VERSION = {"barrel_smashed": "v04"}
OBJ = {  # bundle index -> promoted object id (select_object_frames, same order as KEEP)
    2: "175fcadd-a829-48cb-9ec6-3e63c7d2b9e6", 10: "6d0ccd43-b4a7-4798-9dd0-8f9e50648535",
    14: "d68dc272-813a-4b60-b4a4-c81be8ef120e", 18: "9afd79b7-8662-44dc-b268-fe1d3d850ff6",
    22: "38915679-dd83-4c0a-b7a3-28bc7fdf62a3", 27: "78993911-3b66-453b-b410-888c03d1471a",
    29: "e806c273-7e4f-4937-8a8b-d592841acc3c", 32: "08d200bf-9b0a-4ab2-afd4-4f7d6f44629e",
    37: "fa9b5fb0-c429-4b88-a168-53c170534c40", 39: "992b8c5b-d205-4e2e-bf09-a396e6923269",
    42: "c3965197-b019-443a-a1eb-dd577aca5c6d", 44: "7f37e126-4f0f-4ea8-9661-3130d4e7f0a8",
    48: "84e5890c-60fd-40fb-8b29-48a2f60881ad", 51: "a1376664-fa0d-44e6-b33e-e7afd3a60349",
    54: "6fea5bfd-26b2-46f8-9770-d529dba3fc4d", 57: "1e8cb15c-d9ad-4635-995e-dbe2cc3f5c44",
    58: "9db9ede8-8271-4ae4-9873-dc8cd2f88ec8", 61: "aa1dfb2b-4514-4188-8024-a40328426754",
    62: "ccd7aac0-6bb6-42c6-bc41-45f307ac2bfb"}
assert sorted(OBJ) == sorted(KEEP)


def out_name(stem):
    return f"prop_{stem}_{VERSION.get(stem, 'v03')}.png"


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def hsv(c):
    h, s, v = colorsys.rgb_to_hsv(*(t / 255 for t in c))
    return h * 360, s, v


def lab(c):
    rgb = np.array(c, float) / 255
    rgb = np.where(rgb > 0.04045, ((rgb + 0.055) / 1.055) ** 2.4, rgb / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = m @ rgb / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])


def warm_grey(L, ratio=(1.047, 0.991, 0.924)):
    return tuple(int(max(0, min(255, round(L * k)))) for k in ratio)


def cap(c, limit=215.0):
    L = luma(c)
    if L <= limit:
        return c
    k = limit / L
    return tuple(int(v * k) for v in c)


def by_luma(c, ramp):
    L = luma(c)
    return min(ramp, key=lambda r: abs(luma(r) - L))


def by_lab(c, ramp):
    return min(ramp, key=lambda r: float(np.linalg.norm(lab(c) - lab(r))))


# ---------------------------------------------------------------- palettes (same as stage4_props.py)
BRIEF4 = [hx(s) for s in "1a1714 2e2a26 4a423a 6b5e4f 8c7b66 f4c95d c9932b 9c6a1f efe3c6 6f5522 3b1f4d 5e2d7a "
          "8a5fb0 6f8f3a d8d2c0 2a0808 5c1010 8f1a1a c8321f ff7a1a".split()]
COPPER = [hx(s) for s in ("5b2e15", "8c4a22", "c06a2e", "df903f", "eaa63a")]
IRON = [hx(s) for s in ("34302d", "5e5953", "a39d92", "d2cbb8")]
RUST = [hx(s) for s in ("6e3624", "a5552f")]
GREENS = [hx(s) for s in ("284624", "2b4220", "3c6c32", "456a33", "589a48", "5f8a4a", "82ae68", "88c468",
                          "a8cc8c", "b4dc8c")]
MOULD = [hx(s) for s in ("4b6127", "6f8f3a")]
VIOLET = [hx("3b1f4d"), hx("5e2d7a")]
# light wood-shaving ramp of workbench_v02 (a1): the generator's gold-yellow "grain" read as gold coins
STRAW = [hx(s) for s in ("e2c49c", "caa275", "a47b55", "6e523f")]


def ref_palette():
    cols = set(BRIEF4)
    for f in ("crops_v03_sheet.png", "items_v04_strip.png"):
        im = Image.open(os.path.join(ENV, f)).convert("RGBA")
        cols |= {p[:3] for p in im.getdata() if p[3] > 127}
    cols |= set(COPPER + IRON + RUST + MOULD)
    return sorted(c for c in cols if luma(c) >= 25 and c != hx("2a0808"))


REF = ref_palette()
REF_LAB = np.array([lab(c) for c in REF])


def family(threat, c):
    """a2 family() for props: life greens -> crops_v03 greens, threat olive -> mould pair, threat violet -> brief."""
    h, s, v = hsv(c)
    L = luma(c)
    if L < 30:
        return None
    if not threat and 65 <= h <= 170 and s >= 0.2:
        return by_lab(c, GREENS)
    if threat and 55 <= h <= 140 and s >= 0.15:
        return by_luma(c, MOULD)
    if threat and 250 <= h <= 345 and s >= 0.3 and L < 120:
        return VIOLET[0] if L < 50 else VIOLET[1]
    return None


def cool_to_warm(c, threat):
    h, s, v = hsv(c)
    r, g, b = c
    L = luma(c)
    if threat and 250 <= h <= 345 and s >= 0.3 and L >= 30:
        return c
    if L < 40 and 240 <= h <= 345:
        return warm_grey(L)
    if threat and 250 <= h <= 345 and s >= 0.2:
        return c
    if b > r + 2 and s < 0.35:
        return warm_grey(luma(c))
    if 170 <= h <= 260 and s >= 0.35:
        return warm_grey(luma(c))
    if s < 0.05 and b >= r - 2:
        return warm_grey(luma(c))
    return c


def specks(a):
    op = a[..., 3] > 0
    h, w = op.shape
    seen = np.zeros_like(op)
    for y in range(h):
        for x in range(w):
            if op[y, x] and not seen[y, x]:
                comp, st = [], [(y, x)]
                seen[y, x] = True
                while st:
                    cy, cx = st.pop()
                    comp.append((cy, cx))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and op[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True
                                st.append((ny, nx))
                if len(comp) <= 2:
                    for cy, cx in comp:
                        a[cy, cx] = 0
    return a


SHADOW_KEYS = {0x625b53, 0x55524d}  # the size-32 bundle's baked ground ellipse colours


def strip_ground(a):
    """a2 rule v2: remove the baked ground-shadow colours where reachable from the border through transparent or
    shadow pixels (4-connected); guard at 25% of the opaque pixels. Returns (array, px removed)."""
    h, w = a.shape[:2]
    op = a[..., 3] > 0
    key = (a[..., 0].astype(int) << 16) | (a[..., 1].astype(int) << 8) | a[..., 2].astype(int)
    shadow = op & np.isin(key, list(SHADOW_KEYS))
    passable = ~op | shadow
    bg = np.zeros((h, w), bool)
    st = [(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)]
    while st:
        y, x = st.pop()
        if not (0 <= y < h and 0 <= x < w) or bg[y, x] or not passable[y, x]:
            continue
        bg[y, x] = True
        st.extend([(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)])
    kill = bg & shadow
    if kill.sum() > 0.25 * op.sum():
        return a, -int(kill.sum())
    a[kill] = 0
    return a, int(kill.sum())


def outline(a, add_from=80.0):
    h, w = a.shape[:2]
    op = a[..., 3] > 0
    rgb = a[..., :3].astype(int)
    L = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    a[op & (L < 25), :3] = OUT
    adds, selfs = [], []
    for y in range(h):
        for x in range(w):
            if not op[y, x]:
                continue
            nb = [(y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)]
            edge = any(not (0 <= ny < h and 0 <= nx < w) for ny, nx in nb)
            empty = [(ny, nx) for ny, nx in nb if 0 <= ny < h and 0 <= nx < w and not op[ny, nx]]
            if not edge and not empty:
                continue
            if L[y, x] < 40:
                selfs.append((y, x))
            elif add_from is None or L[y, x] < add_from:
                continue
            elif edge:
                selfs.append((y, x))
            else:
                adds.extend(empty)
    for y, x in selfs:
        a[y, x, :3] = OUT
    added = 0
    for y, x in sorted(set(adds)):
        a[y, x] = (*OUT, 255)
        added += 1
    return a, added


def recolour(a, fn):
    op = a[..., 3] > 0
    cols = {tuple(int(v) for v in a[y, x, :3]) for y, x in zip(*np.where(op))}
    m = {c: fn(c) for c in cols}
    for y, x in zip(*np.where(op)):
        c = tuple(int(v) for v in a[y, x, :3])
        if m[c] is not None and m[c] != c:
            a[y, x, :3] = m[c]
    return a


def reduce(a, limit):
    op = a[..., 3] > 0
    px = [tuple(int(v) for v in a[y, x, :3]) for y, x in zip(*np.where(op))]
    counts = {}
    for c in px:
        counts[c] = counts.get(c, 0) + 1
    mapping = {c: c for c in counts}
    live = dict(counts)
    labs = {c: lab(c) for c in live}
    while len(live) > limit:
        best = None
        keys = sorted(c for c in live if c != OUT)
        for i, c1 in enumerate(keys):
            for c2 in keys[i + 1:]:
                d = float(np.linalg.norm(labs[c1] - labs[c2]))
                if best is None or d < best[0]:
                    best = (d, c1, c2)
        _, c1, c2 = best
        keep, drop = (c1, c2) if live[c1] >= live[c2] else (c2, c1)
        live[keep] += live.pop(drop)
        for k, v in mapping.items():
            if v == drop:
                mapping[k] = keep
    for y, x in zip(*np.where(op)):
        c = tuple(int(v) for v in a[y, x, :3])
        a[y, x, :3] = mapping[c]
    return a


def soft_snap(c):
    if c == OUT:
        return c
    d = np.linalg.norm(REF_LAB - lab(c), axis=1)
    j = int(np.argmin(d))
    return REF[j] if d[j] < 6 else c


# ---------------------------------------------------------------- sprite-specific edits
def special(stem, a):
    """Returns (array, note). Coordinates are cell coordinates (x, y) of the raw 24x24 cell."""
    note = ""
    if stem == "lantern_ground":
        # the ring handle's opening was drawn pure white (#fefefe, 2 px) and read as a lit glass;
        # the lantern body glass is already dark -> open the ring (transparent)
        for x, y in ((11, 4), (12, 4)):
            assert tuple(int(v) for v in a[y, x, :3]) == (0xfe, 0xfe, 0xfe), (x, y, a[y, x])
            a[y, x] = 0
        note = "ring opening 2px white -> transparent"
    if stem == "sack_small":
        # "grain" came out as saturated gold-yellow (#e8af28 #e09b01 #fad96e #c1730b) and read as gold coins
        n = 0
        op = a[..., 3] > 0
        for y, x in zip(*np.where(op)):
            c = tuple(int(v) for v in a[y, x, :3])
            h, s, v = hsv(c)
            if 30 <= h <= 50 and s >= 0.55 and luma(c) >= 90:
                a[y, x, :3] = by_luma(c, STRAW[:3])
                n += 1
        note = f"gold grain {n}px -> straw ramp"
    if stem in ("candles_black_a", "candles_black_b"):
        # black wax is drawn with luma 0-24 inside the body, which the outline rule (luma < 25 -> #1a1714) would
        # turn into one flat outline blob. Interior near-black (all 4 neighbours opaque) is lifted to a warm dark
        # grey of luma 28 + 0.9 x original (as a1 lifted the anvil body), so the wax keeps its shading inside
        # the #1a1714 outline; the boundary stays outline.
        op = a[..., 3] > 0
        h, w = op.shape
        n = 0
        for y, x in zip(*np.where(op)):
            if not all(0 <= y + dy < h and 0 <= x + dx < w and op[y + dy, x + dx]
                       for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                continue
            c = tuple(int(v) for v in a[y, x, :3])
            if luma(c) < 25:
                a[y, x, :3] = warm_grey(28 + 0.9 * luma(c))
                n += 1
        note = f"interior black wax {n}px lifted"
    return a, note


def fix(cell, stem, threat):
    a = cell.copy()
    a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
    a[a[..., 3] == 0] = 0
    a, ground = strip_ground(a)
    a = specks(a)
    a, note = special(stem, a)
    a = recolour(a, lambda c: cool_to_warm(c, threat))
    a = recolour(a, lambda c: family(threat, c))
    if threat:
        a = recolour(a, lambda c: VIOLET[0] if c == hx("381a29") else None)
    a = recolour(a, lambda c: cap(c))
    a, added = outline(a, add_from=80.0)
    a = reduce(a, 24)
    a = recolour(a, soft_snap)
    return a, ground, added, note


def ncols(a):
    op = a[..., 3] > 0
    return len({tuple(int(v) for v in a[y, x, :3]) for y, x in zip(*np.where(op))})


def maxl(a):
    op = a[..., 3] > 0
    return max(luma(tuple(int(v) for v in a[y, x, :3])) for y, x in zip(*np.where(op)))


def bb(a):
    ys, xs = np.nonzero(a[..., 3])
    return xs.min(), ys.min(), xs.max(), ys.max()


def run_props():
    sh = np.array(Image.open(os.path.join(ENV, "props24_v01_sheet.png")).convert("RGBA"))
    keep = sorted(KEEP)
    rows = (len(keep) + 7) // 8
    outsh = np.zeros((rows * CELL, 8 * CELL, 4), np.uint8)
    for k, i in enumerate(keep):
        stem, _, threat = KEEP[i]
        x, y = (i % 8) * CELL, (i // 8) * CELL
        raw = sh[y:y + CELL, x:x + CELL].copy()
        fixed, ground, added, note = fix(raw, stem, threat)
        Image.fromarray(fixed).save(os.path.join(ENV, out_name(stem)))
        ox, oy = (k % 8) * CELL, (k // 8) * CELL
        outsh[oy:oy + CELL, ox:ox + CELL] = fixed
        x0, y0, x1, y1 = bb(fixed)
        print(f"#{i:02d} {out_name(stem):30s} {'threat' if threat else 'life  '} cols {ncols(raw):2d}->{ncols(fixed):2d} "
              f"maxluma {maxl(raw):5.1f}->{maxl(fixed):5.1f} ground {ground} outline+ {added:2d} "
              f"bbox w{x1 - x0 + 1} h{y1 - y0 + 1} base y{y1}  {note}")
    Image.fromarray(outsh).save(os.path.join(ENV, "props24_v02_sheet.png"))
    print("wrote props24_v02_sheet.png", outsh.shape[1], "x", outsh.shape[0])


# ---------------------------------------------------------------- scale check
T = (0, 0, 0, 0)


def load(name, d=ENV):
    return Image.open(os.path.join(d, name)).convert("RGBA")


def trim(im):
    x0, y0, x1, y1 = bb(np.asarray(im))
    return im.crop((x0, y0, x1 + 1, y1 + 1))


def character():
    walk = load("base_body_v02_walk.png", PIX)
    return trim(walk.crop((0, 0, 32, 32)))  # south, first walk frame (03-pixel, R25)


def band(kind, w, h, seed):
    rnd = random.Random(seed)
    if kind == "grass":
        tiles = [load("tiles_grass_base_v02.png")] + [load(f"tiles_grass_var_{i}_v02.png") for i in range(1, 5)]
        p0 = 0.55
    else:
        dun = load("tiles_dungeon_v02.png")
        var = load("tiles_dungeon_v02_var.png")
        tiles = [dun.crop((32, 32, 48, 48))] + [var.crop((i * 16, 0, i * 16 + 16, 16)) for i in range(3)]
        p0 = 0.5
    im = Image.new("RGBA", (w, h), T)
    for ty in range(0, h, 16):
        for tx in range(0, w, 16):
            t = tiles[0] if rnd.random() < p0 else rnd.choice(tiles[1:])
            im.alpha_composite(t, (tx, ty))
    return im


def row_items(seq, kind, seed, W=480, H=40, ground=34, gap=3, pair_gap=1):
    """seq: list of groups; each group is a list of sprites placed with pair_gap between them, gap between groups.
    Every sprite stands with its lowest opaque row on the ground line."""
    im = band(kind, W, H, seed)
    x = 6
    for group in seq:
        for j, sp in enumerate(group):
            s = trim(sp)
            im.alpha_composite(s, (x, ground - s.height + 1))
            x += s.width + (pair_gap if j < len(group) - 1 else 0)
        x += gap + 6
        assert x <= W, ("row too wide", x)
    return im


def scale_check():
    ch = character()
    old = lambda n: load(f"prop_{n}_v02.png")
    new = lambda n: load(out_name(n))
    life1 = [[ch], [load("workbench_v02.png")], [load("storage_chest_v02.png")], [ch],
             [old("crate_a"), new("crate_a")], [old("barrel_a"), new("barrel_a")],
             [old("barrel_b"), new("barrel_b")], [old("barrel_c"), new("barrel_c")], [ch]]
    life2 = [[ch], [old("sack_a"), new("sack_a"), new("sack_small")], [old("sack_b"), new("sack_b")],
             [old("jar_clay"), new("jar_clay")], [old("pottery_broken"), new("pottery_broken")],
             [old("lantern_ground"), new("lantern_ground")], [ch]]
    life3 = [[ch], [old("barrel_tipped"), new("barrel_tipped")], [old("crate_smashed"), new("crate_smashed")],
             [load("prop_barrel_smashed_v03.png"), new("barrel_smashed")],
             [new("barrel_a"), new("sack_small"), new("barrel_c"), new("crate_a"), new("sack_a")],
             [load("storage_chest_v02.png")], [ch]]
    threat = [[ch], [old("offering_bowl"), new("offering_bowl")], [old("candles_black_a"), new("candles_black_a")],
              [old("candles_black_b"), new("candles_black_b")], [old("skull_pile"), new("skull_pile")], [ch]]
    threat2 = [[ch], [old("brazier_dark_c"), new("brazier_dark_c")], [old("bone_cage"), new("bone_cage")],
               [load("prop_bone_pile_a_v02.png")], [load("prop_brazier_dark_a_v02.png")], [ch]]
    rows = [row_items(life1, "grass", 1), row_items(life2, "grass", 2), row_items(life3, "grass", 3),
            row_items(threat, "dungeon", 4), row_items(threat2, "dungeon", 5)]
    W, H = 480, sum(r.height for r in rows)
    panel = Image.new("RGBA", (W, H), T)
    y = 0
    for r in rows:
        panel.alpha_composite(r, (0, y))
        y += r.height
    k = 3
    big = panel.resize((W * k, H * k), Image.NEAREST)
    pad = 12
    sheet = Image.new("RGBA", (W * k, H + pad + H * k), (26, 23, 20, 255))
    sheet.alpha_composite(panel, (0, 0))
    sheet.alpha_composite(big, (0, H + pad))
    sheet.convert("RGB").save(os.path.join(ENV, "stage4_s1_scale_check.png"))
    print("wrote stage4_s1_scale_check.png", sheet.size)


if __name__ == "__main__":
    run_props()
    scale_check()

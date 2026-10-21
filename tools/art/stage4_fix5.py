# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""4단계 약한 것 손질 (s2, brief §5.7 손질 규칙). 생성 없음, 손으로 고침.
기록: assets/concept/04-env/prompts.md "## 본 제작 손질 2" ### 2. 손질 (s2). 고친 것은 "본 제작" 4절 "4. 약한 것"에서 골랐다.
(처음 적었던 _records/s2.md는 커밋되지 않았다.)

Run (paths are relative to this file, any cwd):
  uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I \
      tools/art/stage4_fix5.py [all|tall|lit|bench|anvil|workbench|path|dungeon|items|build|altar|compare|check]

Inputs are only our own stage-4 files in assets/concept/04-env (v01/v02). Outputs are new v03
(or v02 for files that had only v01) files in the same folder; old files are never overwritten.
Every pixel is placed by a rule or an ASCII grid in this file, no randomness, so re-running
reproduces the files byte for byte. The compare sheet uses Pillow's bundled default font
(ImageFont.load_default, same bytes with the pinned pillow 11.3.0).
"""
import colorsys
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ENV = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "concept", "04-env"))
T = (0, 0, 0, 0)


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def load(name):
    return Image.open(os.path.join(ENV, name)).convert("RGBA")


WRITTEN = []


OWN_V02 = ("build_stone_candA_v02", "build_wood_candB_v02", "altar_up1_candA_v02")   # had only v01


def save(im, name):
    # only new files of this pass: *_v03*, the three v02 above, lit variants of v02 lanterns, the compare sheet
    assert ("_v03" in name or name.startswith(OWN_V02) or name == "stage4_s2_compare.png"
            or name.endswith(("_v02_lit.png", "_v02_emissive.png"))), name
    p = os.path.join(ENV, name)
    if isinstance(im, Image.Image):
        im.save(p, optimize=True)
    else:
        with open(p, "wb") as f:
            f.write(im)
    WRITTEN.append(name)
    return p


def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def paste(dst, src, xy):
    dst.alpha_composite(src, (int(xy[0]), int(xy[1])))


def art(rows, cmap, w=None):
    h = len(rows)
    w = w or max(len(r) for r in rows)
    im = Image.new("RGBA", (w, h), T)
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in (".", " "):
                continue
            px[x, y] = cmap[ch]
    return im


def overlay(im, xy, rows, cmap):
    """Write an ASCII patch onto im in place; '.' keeps the pixel, ' ' makes it transparent."""
    px = im.load()
    x0, y0 = xy
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == ".":
                continue
            px[x0 + x, y0 + y] = T if ch == " " else cmap[ch]


def recolour(im, table):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            c = px[x, y]
            if c[3] and c in table:
                px[x, y] = table[c]
    return out


def colours(im):
    return {c[:3] for c in im.getdata() if c[3]}


# ---- shared colours (all from stage-4 files or brief §4) ----
OUT = hx("1a1714")      # outline, ash black
D24 = hx("24201c")
D2E = hx("2e2a26")
D3D = hx("3d3630")
G4A = hx("4a423a")
G5A = hx("5a5044")
G5B = hx("5a5047")
G6B = hx("6b5e4f")
G7D = hx("7d705f")
G89 = hx("897c6c")
G8C = hx("8c7b66")
WB = hx("2b1a14")
FL_E = hx("fff6dc")     # holy flame core (lum 245.7), same value as the altar flame
GOLD1 = hx("f4c95d")
GOLD2 = hx("c9932b")
GOLD3 = hx("9c6a1f")
GOLD4 = hx("6f5522")
HALO = hx("a48d6b")
HOLY_LEVELS = {FL_E: 255, GOLD1: 205, GOLD2: 150, GOLD3: 100}   # same levels as flame_*_v01_emissive


# =====================================================================================
# (1) tall props: lantern posts about 42 px, candle stands 34 px (character is about 30 px)
# =====================================================================================
# name: (canvas height, insert before old row, source rows cycled for the new stem rows,
#        rows added, stem columns x0..x1-1 that the source rows may hold)
TALL = {
    "lantern_post_a": (48, 25, (21, 22, 23, 24, 25, 26, 27, 28), 13, (10, 14)),
    "lantern_post_b": (48, 24, (21, 22, 23), 14, (11, 14)),
    "lantern_post_c": (48, 21, (19, 20, 21, 22), 12, (14, 18)),
    "candle_stand_a": (40, 19, (17, 18), 3, (15, 18)),
    "candle_stand_b": (40, 20, (20,), 5, (15, 18)),
    "candle_stand_c": (40, 22, (21,), 5, (15, 18)),
}
# flame_small_v01 frame top-left (old 32 x 32 coordinates). a and b are the mockup's
# LIGHT_ANCHORS (stage4_mockup.py); c = the three candle wicks of the candelabra.
CANDLE_FLAMES_V02 = {"candle_stand_a": [(14, -5)], "candle_stand_b": [(15, -4)],
                     "candle_stand_c": [(15, -4), (7, 1), (22, 1)]}


def lengthen(im, name):
    canvas_h, at, src, n, (c0, c1) = TALL[name]
    a = np.array(im)
    for r in src:
        outside = np.concatenate([a[r, :c0, 3], a[r, c1:, 3]])
        assert not outside.any(), (name, r)     # source rows hold only the stem
    new_rows = [a[src[i % len(src)]] for i in range(n)]
    body = np.concatenate([a[:at], np.array(new_rows), a[at:]], axis=0)
    off = canvas_h - body.shape[0]
    assert off >= 0, (name, off)
    out = np.zeros((canvas_h, a.shape[1], 4), np.uint8)
    out[off:] = body
    return Image.fromarray(out), off


def height(im):
    a = np.asarray(im)[..., 3]
    ys = np.nonzero(a.any(axis=1))[0]
    return int(ys.max() - ys.min() + 1), int(ys.min()), int(ys.max())


ANCHORS = {}   # file name -> notes for the record (printed by `all`)


def make_tall():
    res = {}
    for name in TALL:
        src = load(f"prop_{name}_v02.png")
        im, off = lengthen(src, name)
        h0, h1 = height(src)[0], height(im)
        res[name] = (src, im, off)
        if name.startswith("candle"):
            fl = [(x, y + off) for (x, y) in CANDLE_FLAMES_V02[name]]
            ANCHORS[f"prop_{name}_v03.png"] = f"canvas 32x{im.height}, height {h0}->{h1[0]} px, " \
                f"foot row y{h1[2]}, flame_small top-left {fl}"
        else:
            ANCHORS[f"prop_{name}_v03.png"] = f"canvas 32x{im.height}, height {h0}->{h1[0]} px, foot row y{h1[2]}"
        save(im, f"prop_{name}_v03.png")
    return res


# =====================================================================================
# (2) lit lanterns: glass glows (holy flame colours, max = flame core #fff6dc like the shared
#     flames; glass body <= #f4c95d 205), emissive mask with the a3 flame levels
# =====================================================================================
GLOW = {"E": FL_E, "H": GOLD1, "B": GOLD2, "D": GOLD3, "h": HALO}
# name: (top-left of the patch in v02 coordinates, rows). '.' keeps the v02 pixel.
LIT = {
    "lantern_post_a": ((21, 16), ["BHHB",
                                  "HEEH",
                                  "BEEB",
                                  "DBBD"]),
    "lantern_post_b": ((21, 14), ["HHH",
                                  "HEH",
                                  "BEB",
                                  "DBD"]),
    "lantern_post_c": ((14, 9), ["BHHB",
                                 "HEEH",
                                 "DBBD"]),
    "lantern_ground": ((15, 19), ["BB",
                                  "HH",
                                  "HE",
                                  "EE",
                                  "HH",
                                  "BD"]),
    "lantern_wall": ((13, 19), ["BH...HB",
                                "HH...HH",
                                "HE...EH",
                                "HE...EH",
                                "HH...HH",
                                "DB...BD"]),
}


def emissive_from(lit, unlit):
    m = Image.new("RGBA", lit.size, T)
    a, b, d = lit.load(), unlit.load(), m.load()
    for y in range(lit.height):
        for x in range(lit.width):
            if a[x, y] != b[x, y] and a[x, y] in HOLY_LEVELS:
                v = HOLY_LEVELS[a[x, y]]
                d[x, y] = (v, v, v, 255)
    return m


def glow_box(lit, unlit):
    a, b = np.asarray(lit), np.asarray(unlit)
    ys, xs = np.nonzero((a != b).any(axis=2))
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def make_lit(tall):
    res = {}
    for name, (xy, rows) in LIT.items():
        base = load(f"prop_{name}_v02.png")
        lit = base.copy()
        overlay(lit, xy, rows, GLOW)
        if name in TALL:
            unlit_v3 = tall[name][1]
            lit_v3, _ = lengthen(lit, name)
            stem = f"prop_{name}_v03"
        else:
            # ground / wall lantern: the unlit sprite stays v02, so the lit pair is a v02 variant
            # (like altar_v04_unlit). s1 re-made the ground lantern at size 24 as prop_lantern_ground_v03,
            # a different sprite: no lit pair for it here.
            unlit_v3, lit_v3 = base, lit
            stem = f"prop_{name}_v02"
        em = emissive_from(lit_v3, unlit_v3)
        x0, y0, x1, y1 = glow_box(lit_v3, unlit_v3)
        ANCHORS[f"{stem}_lit.png"] = (f"glass box ({x0},{y0})-({x1},{y1}), glow centre "
                                      f"({(x0 + x1 + 1) / 2:g}, {(y0 + y1 + 1) / 2:g}); unlit pair "
                                      f"{'prop_' + name + '_v03.png' if name in TALL else 'prop_' + name + '_v02.png'}")
        save(lit_v3, f"{stem}_lit.png")
        save(em, f"{stem}_emissive.png")
        res[name] = (unlit_v3, lit_v3, em)
    return res


# =====================================================================================
# (3) relic bench: the 3 px static candle flame -> cold wick, the shared flame sits on it
# =====================================================================================
BENCH_FLAME = (37, -4)   # flame_small_v01 frame top-left; bottom row (y2) covers the wick at x38
# v02 had 27 colours (brief section 5.7 notes it); the three closest low-count pairs (CIELAB dE76 < 2.2,
# not visible at 8x) are merged so the bench meets the 24-colour object rule
BENCH_MERGE = {hx("432f29"): hx("402c25"),    # dE 1.6, 28 px
               hx("a97358"): hx("a76f54"),    # dE 1.7, 18 px
               hx("6c4e41"): hx("67493c")}    # dE 2.1, 7 px


def make_bench():
    im = load("relic_bench_v02.png")
    px = im.load()
    flame = {(38, 0), (37, 1), (38, 1), (39, 1), (37, 2), (38, 2), (39, 2)}
    for (x, y) in flame:
        assert px[x, y] in (GOLD1, GOLD2, GOLD3), (x, y, px[x, y])
        px[x, y] = T
    assert px[38, 3] == D2E and px[37, 3] == OUT and px[39, 3] == OUT
    px[38, 2] = OUT                          # cold wick standing 1 px above the candle top
    im = recolour(im, BENCH_MERGE)
    ANCHORS["relic_bench_v03.png"] = f"flame_small top-left {BENCH_FLAME} (bottom row y2 on the wick x38)"
    save(im, "relic_bench_v03.png")
    return im


# =====================================================================================
# (4) anvil: lift the iron ramp so the body reads at 1x (warm greys kept, max 205)
# =====================================================================================
ANVIL_IRON = [("302c29", 72), ("4b4440", 100), ("6d645d", 122), ("7d736b", 134),
              ("888076", 144), ("979088", 157), ("a8a29b", 172), ("d0ccc9", 205)]   # (v02 colour, new luma)


def scale_to(c, L):
    k = L / luma(c)
    return tuple(int(min(255, round(v * k))) for v in c[:3]) + (255,)


def make_anvil():
    im = load("anvil_v02.png")
    table = {hx(s): scale_to(hx(s), L) for s, L in ANVIL_IRON}
    for a, b in table.items():
        assert b[0] >= b[1] >= b[2], (a, b)      # stays a warm grey (R >= G >= B)
    out = recolour(im, table)
    save(out, "anvil_v03.png")
    return im, out


# =====================================================================================
# (5) workbench: the faint mallet / saw are repainted as clear outlined shapes
# =====================================================================================
WB_COL = {"A": OUT, "K": hx("dbb089"), "N": hx("ae7f5a"), "T": hx("977148"), "S": hx("856144"),
          "C": hx("6e523f"), "I": hx("b6906f"), "P": hx("a0795b"), "F": hx("b8b1aa"), "G": hx("e4d3c6"),
          "B": hx("897b6f"), "E": hx("6e6562")}
WB_ROW_BASE = {7: "K", 8: "K", 9: "N", 10: "K", 11: "K"}     # plain tabletop colour per row
WB_TOOLS = [   # x 5..29, rows 4..10. '.' keeps the cleaned tabletop
    # mallet: head x6-9 (seen end-on), dark handle x10-14 rows 8-9 on the tabletop.
    # saw: steel blade x16-23 against the back edge, teeth row 9, handle x24-27 with a grip hole.
    #5    10   15   20   25
    ".AAAA....................",   # 4
    ".ATTA..............AAAA..",   # 5
    ".ASSA..............ATTA..",   # 6  (row 6 = table back outline elsewhere)
    ".ASSA......AFFFFFFFASSA..",   # 7
    ".ASSASSSSS.ABBBBBBBAS.A..",   # 8
    ".ACCACCCCC..BABABABASSA..",   # 9
    ".AAAA..............AAAA..",   # 10
]


def make_workbench():
    im = load("workbench_v02.png")
    px = im.load()
    for y in range(7, 12):                       # wipe the old dark tool marks off the tabletop
        for x in range(5, 28):
            if luma(px[x, y]) < 120 or px[x, y] == WB_COL["B"]:   # dark marks and grey steel specks
                px[x, y] = WB_COL[WB_ROW_BASE[y]]
    for y in (4, 5):                             # the old mallet stuck up above the back edge
        for x in range(16, 25):
            px[x, y] = T
    for x in range(16, 25):
        px[x, 6] = OUT
    overlay(im, (5, 4), WB_TOOLS, WB_COL)
    save(im, "workbench_v03.png")
    return im


# =====================================================================================
# (6) grass <-> path edge: the dark green teeth read as a hedge at 3x -> one step lighter
# =====================================================================================
# The edge greens move to lighter edge greens already in the tileset (no new colours). Tried at 4x:
# one step (P->J, J->G, C->L) still read as a hedge band; this table keeps a thin darker tip.
# These colours occur only in the edge band (asserted: none in the all-grass tile).
PATH_EDGE_SOFTEN = {hx("445d37"): hx("57734a"),    # darkest tooth tips (81) -> 102
                    hx("57734a"): hx("6e9762"),    # dark teeth (102) -> 133
                    hx("668260"): hx("6e9762"),    # band (118) -> 133
                    hx("677160"): hx("778768")}    # grey-green band (108) -> 127


def make_path():
    im = load("tiles_grass-path_v02.png")
    js = json.load(open(os.path.join(ENV, "tiles_grass-path_v01.json"), encoding="utf-8"))
    for t in js["tileset_data"]["tiles"]:
        if all(v == "upper" for v in t["corners"].values()):
            b = t["bounding_box"]
            grass = im.crop((b["x"], b["y"], b["x"] + 16, b["y"] + 16))
            assert not (colours(grass) & {c[:3] for c in PATH_EDGE_SOFTEN}), "edge colour inside the grass tile"
    out = recolour(im, PATH_EDGE_SOFTEN)
    save(out, "tiles_grass-path_v03.png")
    # same layout and corners: the v01 JSON is copied byte for byte (it holds no download URL)
    raw = open(os.path.join(ENV, "tiles_grass-path_v01.json"), "rb").read()
    assert b"http" not in raw
    save(raw, "tiles_grass-path_v03.json")
    return im, out


# =====================================================================================
# (7) dungeon warm-grey props: separate them from the same-family floor at 1x
# =====================================================================================
DUNGEON_PROPS = ["rubble_a", "rubble_b", "rubble_c", "pillar_stub_a", "pillar_stub_b", "pillar_stub_c",
                 "stalagmite_a", "stalagmite_b"]
# Tried on the dungeon floor at 1x / 2x / 3x (scratch): lifting only the lit faces (luma >= 120,
# 25-35 %) barely helped; lifting every colour from luma 60 up by 30 % of the way to 215 plus the
# contact shadow separated all eight at 1x without turning them sand-bright (max 213).
LIFT_FROM = 60
LIFT_K = 0.30
SHADOW = D24             # contact shadow, between the outline (24) and the floor joints (43)


def lift(c):
    L = luma(c)
    if L < LIFT_FROM:
        return c
    return scale_to(c, min(215.0, L + (215.0 - L) * LIFT_K))


def contact_shadow(im, rows=4):
    """Opaque shadow cast down-right by the lowest `rows` rows of the sprite: the sprite mask
    shifted by (+1,+1) and (+2,+1), kept where the canvas is empty."""
    a = np.array(im)
    op = a[..., 3] > 0
    ys = np.nonzero(op.any(axis=1))[0]
    base = op.copy()
    base[: ys.max() - rows + 1] = False
    sh = np.zeros_like(op)
    for dx in (1, 2):
        sh[1:, dx:] |= base[:-1, :-dx]
    sh &= ~op
    a[sh] = SHADOW
    return Image.fromarray(a), int(sh.sum())


def make_dungeon():
    res = {}
    for name in DUNGEON_PROPS:
        im = load(f"prop_{name}_v02.png")
        cols = colours(im)
        out = recolour(im, {c + (255,): lift(c + (255,)) for c in cols if c + (255,) != OUT})
        out, n = contact_shadow(out)
        ANCHORS[f"prop_{name}_v03.png"] = f"lit faces lifted, {n} contact-shadow px"
        save(out, f"prop_{name}_v03.png")
        res[name] = (im, out)
    return res


# =====================================================================================
# (8) items (16 x 16)
# =====================================================================================
# -- recolours ------------------------------------------------------------------------
# leather c: max luma 58 -> the clay-brown ramp of the altar lamps (stage4_handdrawn CL1..CL5), shading order kept
LEATHER_C = {"351103": "4a2c1d", "3d1307": "4a2c1d", "361c0b": "4a2c1d", "3e241a": "5e3722", "492312": "5e3722",
             "513223": "7a4a2e", "5b2e15": "94603a"}
# black candles: a warm ash rim light on the left / top edge (no flame colour: the heretic fire
# colour is an open ?), so the black wax separates from the #4a423a / #6b5e4f dungeon floor
CANDLE_RIM = hx("8c7b66")      # brief section 4 ash ramp
CANDLE_TOP = hx("b2a693")      # ash highlight (a2 ASH ramp)

# -- redraws (aligned front views and new silhouettes) ----------------------------------
STONE_BLOCK = {"A": OUT, "E": hx("bfa584"), "L": hx("a48d62"), "B": hx("9c8065"), "I": hx("55382d"),
               "G": hx("8c7b66"), "H": hx("7e6452"), "J": hx("605046"), "F": hx("614839")}
STONE_BLOCK_ROWS = [
    "................",
    "................",
    "................",
    ".AAAAAAAAAAAAAA.",
    ".AEEEEEEEEEEEEA.",
    ".ALBBBBBBBBBBBA.",
    ".AIIIIIIIIIIIIA.",
    ".AGGGGGGGGGGGHA.",
    ".AGHHHHHHHHHHFA.",
    ".AHHHHJHHHHHHFA.",
    ".AHHHHHHHHHGHFA.",
    ".AHGHHHHHHHHHFA.",
    ".AHHHHHHHJHHHFA.",
    ".AFFFFFFFFFFFIA.",
    ".AAAAAAAAAAAAAA.",
    "................",
]
INGOT_ONE = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "....AAAAAAAA....",
    "...AhhhhhhhhA...",
    "...ABBBBBBBBA...",
    "..AdBBBBBBBBdA..",
    "..AdBBBBBBBBdA..",
    ".AdCCCCCCCCCCdA.",
    ".AAAAAAAAAAAAAA.",
    "................",
    "................",
    "................",
]
INGOT_TWO = [
    "................",
    "................",
    "................",
    ".....AAAAAA.....",
    "....AhhhhhhA....",
    "....ABBBBBBA....",
    "...AdBBBBBBdA...",
    "...AdCCCCCCdA...",
    "..AAAAAAAAAAAA..",
    "..AhhhhhhhhhhA..",
    "..ABBBBBBBBBBA..",
    ".AdBBBBBBBBBBdA.",
    ".AdCCCCCCCCCCdA.",
    ".AAAAAAAAAAAAAA.",
    "................",
    "................",
]
COPPER_MAP = {"A": OUT, "h": hx("df903f"), "B": hx("c06a2e"), "C": hx("8c4a22"), "d": hx("5b2e15")}
IRON_MAP = {"A": OUT, "h": hx("d2cbb8"), "B": hx("a39d92"), "C": hx("5e5953"), "d": hx("34302d")}
WOOD_MAP = {"A": OUT, "L": hx("ce965e"), "E": hx("bc8440"), "D": hx("a05f22"), "N": hx("8a4414"),
            "g": hx("65310a"), "e": hx("5c2a0e")}
PLANKS_A = [   # three boards stacked with staggered ends (an even stack read as a chest of drawers)
    "................",
    "................",
    "................",
    "................",
    "....AAAAAAAAAAA.",
    "....ALLLLLLLLLA.",
    "....AEEgggEEEDA.",
    ".AAAAAAAAAAAAAA.",
    ".ALLLLLLLLLLA...",
    ".AEEEEggEEEDA...",
    ".AAAAAAAAAAAAAA.",
    "...ALLLLLLLLLLA.",
    "...AEgggEEEEEDA.",
    "...ADDDDDDDDDDA.",
    "...AAAAAAAAAAAA.",
    "................",
]
PLANKS_B = [   # one long thin board lying flat: top face with grain and a knot, front edge
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "AAAAAAAAAAAAAAA.",
    "ALLLLLLLLLLLLLA.",
    "AEEgggEEEEeEEDA.",
    "ADDDDDDDDDDDDDA.",
    "AAAAAAAAAAAAAAA.",
    "................",
    "................",
    "................",
    "................",
    "................",
]
PLANKS_C = [   # two thin boards, the short one lying on the long one
    "................",
    "................",
    "................",
    "................",
    "................",
    "...AAAAAAAAA....",
    "...ALLLLLLLA....",
    "...AEEggEEDA....",
    "AAAAAAAAAAAAAAA.",
    "ALLLLLLLLLLLLLA.",
    "AEEEEEgggEEEEDA.",
    "ADDDDDDDDDDDDDA.",
    "AAAAAAAAAAAAAAA.",
    "................",
    "................",
    "................",
]
CLOTH_MAP = {"A": OUT, "D": hx("e6d3ac"), "F": hx("cdb28e"), "J": hx("c6a178"), "I": hx("a48d62"),
             "N": hx("9c8065"), "K": hx("7e6452")}
CLOTH_A = [    # folded linen, front view: top face, three folds with soft creases
    "................",
    "................",
    "................",
    "................",
    "...AAAAAAAAAA...",
    "..ADDDDDDDDDDA..",
    ".ADDDDDDDDDDDDA.",
    ".AFFFFFFFFFFFFA.",
    ".AIJJJJJJJJJJIA.",
    ".ADFFFFFFFFFFNA.",
    ".AIJJJJJJJJJJIA.",
    ".AFFFFFFFFFFFNA.",
    ".AINNNNNNNNNNKA.",
    "..AAAAAAAAAAAA..",
    "................",
    "................",
]
MOULD_MAP = {"A": OUT, "O": hx("6f8f3a"), "M": hx("4b6127"), "d": D2E}
MOULD = [      # flat olive mould patch: low lobed blob, darker rim, a few dark pores
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "....AAA...AA....",
    "..AAOOOAAAOOA...",
    ".AOOOdOOOOOOMA..",
    "AMOOOOOOMOOOdOA.",
    "AMOdOOOOOOOOOMA.",
    ".AMMOOOOdOMMMA..",
    "..AAMMMMMMAAA...",
    "....AAAAAA......",
    "................",
    "................",
]
ORE_MAP = {"A": OUT, "F": hx("d2cbb8"), "G": hx("a39d92"), "D": hx("5e5953"), "E": hx("34302d"),
           "R": hx("a5552f"), "r": hx("6e3624")}
ORE_C = [      # one chunky iron lump + a small piece leaning on it (v02 was five loose crumbs)
    "................",
    "................",
    "................",
    "......AAAA......",
    "....AAGFGGAA....",
    "...AGGDGGDGGA...",
    "..AGDDRrDDGDA...",
    "..AGDrRDDDFDDA..",
    ".AGDDDDGFDDDDAA.",
    ".AGDDRDDDDrDDAGA",
    ".ADDDrRDDDDDEAGA",
    "..AEDDDDDDEEADDA",
    "...AAEEEEEAAAAA.",
    ".....AAAAA......",
    "................",
    "................",
]
CHARM_MAP = {"A": OUT, "C": hx("6b472c"), "F": hx("452a1e"), "E": hx("dfc69c"), "K": hx("cdb28e"),
             "G": hx("a39d8d")}
CHARM = [      # closed cord loop with two fangs and a bone pendant (v02 read as loose crumbs; an open
    "................",   # V cord read as a slingshot, so the loop is closed)
    ".....AAAAAA.....",
    "....ACCCCCCA....",
    "...ACAAAAAACA...",
    "..AECA....ACEA..",
    "..AKCA....ACKA..",
    "..AGACA..ACAGA..",
    "...A.ACAACA.A...",
    "......AFFA......",
    ".....AEAAEA.....",
    ".....AEKKGA.....",
    "......AKGA......",
    "......AKGA......",
    ".....AEKKGA.....",
    ".....AEAAGA.....",
    "......A..A......",
]
ITEM_DRAWN = {
    "stone_block": (STONE_BLOCK_ROWS, STONE_BLOCK),
    "ingot_copper_a": (INGOT_ONE, COPPER_MAP), "ingot_copper_b": (INGOT_TWO, COPPER_MAP),
    "ingot_iron_a": (INGOT_ONE, IRON_MAP), "ingot_iron_b": (INGOT_TWO, IRON_MAP),
    "planks_a": (PLANKS_A, WOOD_MAP), "planks_b": (PLANKS_B, WOOD_MAP), "planks_c": (PLANKS_C, WOOD_MAP),
    "cloth_a": (CLOTH_A, CLOTH_MAP), "mould_clump": (MOULD, MOULD_MAP), "ore_iron_c": (ORE_C, ORE_MAP),
    "bone_charm": (CHARM, CHARM_MAP),
}


def exterior(im):
    """Transparent pixels connected (4-way) to the canvas border."""
    w, h = im.size
    px = im.load()
    seen = set()
    st = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while st:
        x, y = st.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h) or px[x, y][3]:
            continue
        seen.add((x, y))
        st += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return seen


def candle_rim(im):
    """Wax pixels just inside the outer silhouette on the left or top (outline px between them and
    the outside) -> ash rim; where both (the upper-left corners) -> highlight. Inner lines untouched."""
    out = im.copy()
    px, src = out.load(), im.load()
    w, h = im.size
    ext = exterior(im)

    def outside(x, y):
        return not (0 <= x < w and 0 <= y < h) or (x, y) in ext
    done = 0
    for y in range(h):
        for x in range(w):
            c = src[x, y]
            if not c[3] or c == OUT or luma(c) >= 100:
                continue
            left = x > 0 and src[x - 1, y] == OUT and outside(x - 2, y)
            top = y > 0 and src[x, y - 1] == OUT and outside(x, y - 2)
            if left or top:
                px[x, y] = CANDLE_TOP if (left and top) else CANDLE_RIM
                done += 1
    return out, done


def make_items():
    res = {}
    for name, (rows, cmap) in ITEM_DRAWN.items():
        im = art(rows, cmap, 16)
        assert im.size == (16, 16), name
        save(im, f"item_{name}_v03.png")
        res[name] = (load(f"item_{name}_v02.png"), im)
    lc = load("item_leather_c_v02.png")
    out = recolour(lc, {hx(a): hx(b) for a, b in LEATHER_C.items()})
    save(out, "item_leather_c_v03.png")
    res["leather_c"] = (lc, out)
    for n in ("candle_black_a", "candle_black_b"):
        src = load(f"item_{n}_v02.png")
        out, k = candle_rim(src)
        save(out, f"item_{n}_v03.png")
        res[n] = (src, out)
    return res


# =====================================================================================
# (9) built walls (both ? candidates, same fix, no choice between them): doors 8 -> 12 px
# =====================================================================================
# Sheet layout is the a3 one (stage4_handdrawn.py build_sheet); only the two door tiles
# (x64-95, y48-71) change, drawn over the sheet's own middle face tile (x32-47, y48-71).
W1, W2, W4, W5, W6 = hx("402c25"), hx("51372e"), hx("67493c"), hx("8d6250"), hx("a76f54")
DOOR_MAP = {"K": OUT, "o": G6B, "5": W5, "4": W4, "2": W2, "b": D2E, "g": GOLD2, "t": G7D,
            "w": WB, "f": G4A, "P": W1, "q": W2, "7": W6, "6": W4}   # same keys as a3 DOOR_MAP


def door_rows(top, body, band_rows=(), band="", handle=None, bottom="", last="", total=24):
    rows = list(top)
    while len(rows) < total - 2:
        r = len(rows)
        if r in band_rows:
            rows.append(band)
        elif handle and r == handle[0]:
            rows.append(handle[1])
        elif bottom and r >= total - 4:
            rows.append(bottom)
        else:
            rows.append(body)
    rows += [last, "." * 16]
    assert all(len(r) == 16 for r in rows) and len(rows) == total
    return rows


# leaf 12 px (x2-13) inside a 1 px frame; the stone arch steps out to the tile edge
STONE_TOP_C = ["................", "....oooooooo....", "..oooKKKKKKooo..", ".ooKK542542KKoo.", ".oK5425425425Ko."]
STONE_TOP_O = ["................", "....oooooooo....", "..oooKKKKKKooo..", ".ooKK5wwwwwKKoo.", ".oK54wwwwwwwwKo."]
DOORS = {
    "stone": (
        door_rows(STONE_TOP_C, "oK542542542542Ko", (9, 17), "oKbbbbbbbbbbbbKo",
                  handle=(13, "oK5425425425g2Ko"), last="oKttttttttttttKo"),
        door_rows(STONE_TOP_O, "oK54wwwwwwwwwwKo", (9, 17), "oKb4wwwwwwwwwwKo",
                  bottom="oK54ffffffffffKo", last="oKttttttttttttKo")),
    "wood": (
        door_rows(["................"] * 3 + [".PPPPPPPPPPPPPP.", ".PqqqqqqqqqqqqP."], ".P762762762762P.",
                  (9, 16), ".P222222222222P.", handle=(13, ".P7627627627g2P."), last=".PttttttttttttP."),
        door_rows(["................"] * 3 + [".PPPPPPPPPPPPPP.", ".PqqqqqqqqqqqqP."], ".P76wwwwwwwwwwP.",
                  (9, 16), ".P22wwwwwwwwwwP.", bottom=".P76ffffffffffP.", last=".PttttttttttttP."))
}
# candA only: the placed stone floor one step darker (base #7d705f -> #6b5e4f, joints and specks
# follow), so the room floor no longer matches the wall cap (#8f8272 family). Same flagstone
# pattern, colours already on the sheet. candB's plank floor already differs from its wall top.
FLOOR_DARKER = {G7D: G6B, G89: G7D, G6B: G5B, G5B: G4A}


def make_build():
    res = {}
    for material, cand in (("stone", "candA"), ("wood", "candB")):
        src = load(f"build_{material}_{cand}_v01.png")
        sh = src.copy()
        mid = src.crop((32, 48, 48, 72))
        for i, rows in enumerate(DOORS[material]):
            d = mid.copy()
            d.alpha_composite(art(rows, DOOR_MAP, 16))
            sh.paste(d, (64 + i * 16, 48))
        if material == "stone":
            fl = recolour(sh.crop((64, 32, 112, 48)), FLOOR_DARKER)
            sh.paste(fl, (64, 32))
        save(sh, f"build_{material}_{cand}_v02.png")
        res[cand] = (src, sh)
    return res


def sheet_parts(sh):
    caps = [sh.crop(((i % 8) * 16, (i // 8) * 16, (i % 8) * 16 + 16, (i // 8) * 16 + 16)) for i in range(16)]
    corners = [sh.crop((i * 16, 32, i * 16 + 16, 48)) for i in range(4)]
    floors = [sh.crop((64 + i * 16, 32, 80 + i * 16, 48)) for i in range(3)]
    faces = {k: sh.crop((i * 16, 48, i * 16 + 16, 72)) for i, k in enumerate(("single", "left", "mid", "right"))}
    doors = [sh.crop((64 + i * 16, 48, 80 + i * 16, 72)) for i in range(2)]
    return dict(caps=caps, corners=corners, floors=floors, faces=faces, doors=doors)


def assemble(bs, walls, doors, floors, base):
    """a3 sheet rules (same as stage4_handdrawn.assemble / stage4_mockup.assemble)."""
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


GRASS_TILES = ["tiles_grass_base_v02.png"] + [f"tiles_grass_var_{i}_v02.png" for i in range(1, 5)]


def grass_ground(w, h):
    g = [load(n) for n in GRASS_TILES]
    im = Image.new("RGBA", (w * 16, h * 16), T)
    for y in range(h):
        for x in range(w):
            paste(im, g[0] if (x * 5 + y * 3) % 4 else g[1 + (x + y) % 4], (x * 16, y * 16))   # fixed pattern
    return im


def build_room_panel(sheet):
    """Two small rooms (door closed / open) on grass, 14 x 8 cells."""
    base = grass_ground(14, 8)
    bs = sheet_parts(sheet)
    w1, d1, f1 = room(1, 1, 6, 5, 3, 0)
    w2, d2, f2 = room(8, 1, 12, 5, 10, 1)
    return assemble(bs, w1 | w2, {**d1, **d2}, f1 | f2, base)


# =====================================================================================
# (10) altar upgrade candA: 26 -> 24 colours with the same look (still a ? candidate)
# =====================================================================================
# The two least visible merges (CIELAB dE76, pixel count in the lit sprite):
#   #8a5a34 -> #94603a  dE 3.2, 18 px (lit clay lamp body; #94603a is the next step of the same ramp)
#   #ad9c7a -> #a48d6b  dE 5.9, 12 px (deepest cloth fold; #a48d6b = lamp light spill on stone)
# The closer pairs (#897c6c/#8f8272 2.3, #958877/#8f8272 2.4) are the stone texture (250-400 px each).
ALTAR_MERGE = {hx("8a5a34"): hx("94603a"), hx("ad9c7a"): hx("a48d6b")}


def make_altar():
    res = {}
    for suf in ("", "_unlit", "_litbase"):
        src = load(f"altar_up1_candA_v01{suf}.png")
        out = recolour(src, ALTAR_MERGE)
        save(out, f"altar_up1_candA_v02{suf}.png")
        res[suf] = (src, out)
    em = load("altar_up1_candA_v01_emissive.png")       # flames are not touched: same mask
    save(em, "altar_up1_candA_v02_emissive.png")
    return res


# =====================================================================================
# (11) before / after sheet (4x) and rule check
# =====================================================================================
PIX = os.path.normpath(os.path.join(ENV, "..", "03-pixel"))
K4 = 4
BG = (26, 23, 20, 255)
TXT = (239, 227, 198, 255)


def flame0():
    """flame_small_v01 frame 0 (the shared flame), cut from the a3 strip."""
    return load("flame_small_v01.png").crop((0, 0, 4, 7))


def character():
    return Image.open(os.path.join(PIX, "base_body_v02_walk.png")).convert("RGBA").crop((0, 0, 32, 32))


def dungeon_floor(w, h):
    js = json.load(open(os.path.join(ENV, "tiles_dungeon_v01.json"), encoding="utf-8"))
    sheet = load("tiles_dungeon_v02.png")
    for t in js["tileset_data"]["tiles"]:
        if all(v == "lower" for v in t["corners"].values()):
            b = t["bounding_box"]
            fl = sheet.crop((b["x"], b["y"], b["x"] + 16, b["y"] + 16))
    var = load("tiles_dungeon_v02_var.png")
    tiles = [fl] + [var.crop((i * 16, 0, i * 16 + 16, 16)) for i in range(3)]
    im = Image.new("RGBA", (w * 16, h * 16), T)
    for y in range(h):
        for x in range(w):
            paste(im, tiles[0] if (x * 3 + y * 5) % 3 else tiles[1 + (x + 2 * y) % 3], (x * 16, y * 16))
    return im


def path_map(png, cols=12, rows=6):
    js = json.load(open(os.path.join(ENV, "tiles_grass-path_v01.json"), encoding="utf-8"))
    sheet = load(png)
    tiles = {}
    for t in js["tileset_data"]["tiles"]:
        c, b = t["corners"], t["bounding_box"]
        tiles[(c["NW"], c["NE"], c["SW"], c["SE"])] = sheet.crop((b["x"], b["y"], b["x"] + 16, b["y"] + 16))
    V = ["0000000000000",
         "0001111000000",
         "1111111111111",
         "1111111111111",
         "0000000111000",
         "0000000111000",
         "0000000000000"]
    g = grass_ground(cols, rows)
    for y in range(rows):
        for x in range(cols):
            cs = tuple("lower" if V[yy][xx] == "1" else "upper"
                       for yy, xx in ((y, x), (y, x + 1), (y + 1, x), (y + 1, x + 1)))
            if cs != ("upper",) * 4:
                paste(g, tiles[cs], (x * 16, y * 16))
    return g


def darkened(im, k=0.4):
    a = np.asarray(im).astype(float)
    a[..., :3] *= k
    return Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8))


def row_strip(items, gap=4, pad=4, bg=None, h=None):
    """items: list of images (bottom-aligned). bg: background image tiled under the strip or None."""
    h = h or max(i.height for i in items) + 2 * pad
    w = sum(i.width for i in items) + gap * (len(items) - 1) + 2 * pad
    if bg is None:
        s = Image.new("RGBA", (w, h), (64, 58, 50, 255))
    else:
        s = Image.new("RGBA", (w, h), T)
        for y in range(0, h, bg.height):
            for x in range(0, w, bg.width):
                paste(s, bg, (x, y))
    x = pad
    for i in items:
        paste(s, i, (x, h - pad - i.height))
        x += i.width + gap
    return s


def with_flames(im, anchors, top=8):
    """Sprite with `top` empty rows added above and flame_small frame 0 at each anchor (preview only;
    the bottom stays where it was so strips stay foot-aligned)."""
    c = Image.new("RGBA", (im.width, im.height + top), T)
    paste(c, im, (0, top))
    f = flame0()
    for (x, y) in anchors:
        paste(c, f, (x, y + top))
    return c


def make_compare(R):
    font = ImageFont.load_default(size=14)
    sections = []
    tall, lit = R["tall"], R["lit"]
    grass16 = load("tiles_grass_base_v02.png")
    ch = character()
    # 1 tall props with the character for scale; candle stands carry the shared flame at their anchors
    before = [tall[n][0] for n in TALL]
    after = []
    for n in TALL:
        im = tall[n][1]
        if n.startswith("candle"):
            im = with_flames(im, [(x, y + tall[n][2]) for (x, y) in CANDLE_FLAMES_V02[n]])
        after.append(im)
    sections.append(("tall props  v02 | v03 (posts 42 px, stands 34 px; flame_small at the recorded anchors)",
                     row_strip([ch] + before + [ch] + after, bg=grass16)))
    # 2 lit lanterns on a darkened ground: unlit | lit
    dark = darkened(grass16)
    pairs = []
    for n in LIT:
        pairs += [lit[n][0], lit[n][1]]
    sections.append(("lanterns  unlit | lit (glass = holy flame colours, emissive mask beside each file)",
                     row_strip(pairs, bg=dark)))
    # 3 bench / anvil / workbench
    bench = R["bench"]
    sections.append(("relic bench v02 | v03 | v03 + shared flame;  anvil v02 | v03;  workbench v02 | v03",
                     row_strip([load("relic_bench_v02.png"), bench, with_flames(bench, [BENCH_FLAME]),
                                R["anvil"][0], R["anvil"][1], load("workbench_v02.png"), R["workbench"]],
                               bg=grass16)))
    # 4 path edge
    sections.append(("grass-path  v02 | v03 (edge teeth lighter, thin dark tip kept)",
                     row_strip([path_map("tiles_grass-path_v02.png"), path_map("tiles_grass-path_v03.png")],
                               gap=8, bg=None)))
    # 5 dungeon props on the dungeon floor
    dfl = dungeon_floor(1, 1)
    d0 = [R["dungeon"][n][0] for n in DUNGEON_PROPS]
    d1 = [R["dungeon"][n][1] for n in DUNGEON_PROPS]
    sections.append(("dungeon props  v02 (top) | v03 (bottom): lift + contact shadow",
                     row_strip(d0, bg=dfl)))
    sections.append(("", row_strip(d1, bg=dfl)))
    # 6 items: v02 | v03 pairs, on dungeon floor (first row) and grass (second row)
    it = R["items"]
    names = list(ITEM_DRAWN) + ["leather_c", "candle_black_a", "candle_black_b"]
    pairs = []
    for n in names:
        pairs += [it[n][0], it[n][1]]
    sections.append(("items  v02 | v03 pairs on the dungeon floor and on grass", row_strip(pairs, gap=2, bg=dfl)))
    sections.append(("", row_strip(pairs, gap=2, bg=grass16)))
    # 7 build rooms: v01 | v02
    b = R["build"]
    sections.append(("built walls  candA v01 | v02 (12 px doors, darker floor)",
                     row_strip([build_room_panel(b["candA"][0]), build_room_panel(b["candA"][1])], gap=8)))
    sections.append(("built walls  candB v01 | v02 (12 px doors)",
                     row_strip([build_room_panel(b["candB"][0]), build_room_panel(b["candB"][1])], gap=8)))
    # 8 altar candA: v01 | v02 (lit and unlit)
    a = R["altar"]
    sections.append(("altar_up1_candA  v01 | v02 lit, v01 | v02 unlit (26 -> 24 colours)",
                     row_strip([a[""][0], a[""][1], a["_unlit"][0], a["_unlit"][1]], gap=8, bg=grass16)))
    W = max(s.width for _, s in sections) * K4 + 16
    H = sum(s.height * K4 + (24 if t else 4) for t, s in sections) + 8
    sheet = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    y = 8
    for title, s in sections:
        if title:
            d.text((8, y), title, font=font, fill=TXT)
            y += 20
        paste(sheet, up(s, K4), (8, y))
        y += s.height * K4 + 4
    save(sheet.convert("RGB"), "stage4_s2_compare.png")


def check():
    rows = []
    bad = []
    for name in sorted(set(WRITTEN)):
        if not name.endswith(".png") or name == "stage4_s2_compare.png":
            continue
        im = load(name)
        a = np.asarray(im)
        alphas = set(np.unique(a[..., 3]).tolist())
        cols = colours(im)
        if name.endswith("_emissive.png"):
            rows.append(f"{name}: emissive levels {sorted({c[0] for c in cols})}, alpha {sorted(alphas)}")
            if not alphas <= {0, 255}:
                bad.append(name)
            continue
        kind = "item" if name.startswith("item_") else ("tiles" if name.startswith(("tiles_", "build_")) else "object")
        limit = {"item": 16, "object": 24, "tiles": 99}[kind]
        maxl = max(luma(c) for c in cols if c != FL_E[:3])
        cap = 226.0 if kind == "tiles" else 215.0     # grass flower dots up to 226 (a4 record)
        flame = FL_E[:3] in cols
        cool = [c for c in cols if c[2] > c[0] + 2 and colorsys.rgb_to_hsv(*[v / 255 for v in c])[1] < 0.35]
        has_out = OUT[:3] in cols
        ok = alphas <= {0, 255} and len(cols) <= limit and maxl <= cap and not cool and (has_out or kind == "tiles")
        rows.append(f"{name}: {len(cols)} colours (<= {limit if limit < 99 else '-'}), max luma {maxl:.1f}"
                    f"{' + flame core 245.7' if flame else ''}, alpha {sorted(alphas)}, cool greys {len(cool)}, "
                    f"outline {'yes' if has_out else 'no'} -> {'OK' if ok else 'CHECK'}")
        if not ok:
            bad.append(name)
    print("\n".join(rows))
    print("CHECK:", bad if bad else "all OK")
    return bad


def main(what):
    R = {}
    if what in ("all", "tall", "lit", "compare"):
        R["tall"] = make_tall()
    if what in ("all", "lit", "compare"):
        R["lit"] = make_lit(R["tall"])
    if what in ("all", "bench", "compare"):
        R["bench"] = make_bench()
    if what in ("all", "anvil", "compare"):
        R["anvil"] = make_anvil()
    if what in ("all", "workbench", "compare"):
        R["workbench"] = make_workbench()
    if what in ("all", "path", "compare"):
        R["path"] = make_path()
    if what in ("all", "dungeon", "compare"):
        R["dungeon"] = make_dungeon()
    if what in ("all", "items", "compare"):
        R["items"] = make_items()
    if what in ("all", "build", "compare"):
        R["build"] = make_build()
    if what in ("all", "altar", "compare"):
        R["altar"] = make_altar()
    if what in ("all", "compare"):
        make_compare(R)
    for k, v in ANCHORS.items():
        print(f"{k}: {v}")
    if what in ("all", "check"):
        if what == "check":
            main("all")
            return
        check()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "all")

# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""4단계 본 제작 손그림 (밤 작업 a3, brief §5.7 본 제작 "손"). No generation.
기록: assets/concept/04-env/prompts.md "본 제작 (2026-10-21 밤)" 3절.

Run (paths are relative to this file, any cwd):
  uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I \
      tools/art/stage4_handdrawn.py [all|check]

Every pixel is placed by this script (ASCII grids or simple rules). Inputs are only our own
stage-4 assets in assets/concept/04-env. Outputs go to the same folder. Deterministic
(fixed random seeds), so re-running reproduces the files byte for byte.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ENV = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "concept", "04-env"))


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


T = (0, 0, 0, 0)

# ---- colours (all taken from existing stage-4 assets or brief §4) ----
OUT = hx("1a1714")      # outline, ash black
WB = hx("2b1a14")       # warm black (altar lamp shadow)
D24 = hx("24201c")      # dungeon deep
D2E = hx("2e2a26")
D3C = hx("3c3630")
D3D = hx("3d3630")
G4A = hx("4a423a")
G5A = hx("5a5044")      # dungeon speck
G5B = hx("5a5047")      # altar face highlight
G6B = hx("6b5e4f")
G7D = hx("7d705f")
G89 = hx("897c6c")
G8C = hx("8c7b66")
G8F = hx("8f8272")
G95 = hx("958877")
G9D = hx("9d917f")
HALO = hx("a48d6b")     # altar lamp light spill on stone
# entrance stones
E7C = hx("7c6d5a")
EA6 = hx("a69782")
EAD = hx("ad9f89")
E96 = hx("968671")
E5C = hx("5c5145")
E54 = hx("544a3f")
E3B = hx("3b342d")
# faith
FL_E = hx("fff6dc")     # altar flame core (lum 245) - brightest pixel on screen
GOLD1 = hx("f4c95d")
GOLD2 = hx("c9932b")
GOLD3 = hx("9c6a1f")
GOLD4 = hx("6f5522")
IV1 = hx("e2d6b8")      # cloth highlight (lum 214 <= 215)
IV2 = hx("d4c6a5")
IV3 = hx("c9b994")
IV4 = hx("ad9c7a")
# clay lamp
CL1 = hx("94603a")
CL2 = hx("8a5a34")
CL3 = hx("7a4a2e")
CL4 = hx("5e3722")
CL5 = hx("4a2c1d")
# wood (relic bench)
W1 = hx("402c25")
W2 = hx("51372e")
W3 = hx("614438")
W4 = hx("67493c")
W5 = hx("8d6250")
W6 = hx("a76f54")
W7 = hx("b38264")
# threat
BONE = hx("d8d2c0")
VI1 = hx("3b1f4d")
VI2 = hx("5e2d7a")
OLV = hx("6f8f3a")
OLV2 = hx("4b6127")
MOSS2 = hx("4b5e27")
BLD1 = hx("5c1010")
BLD2 = hx("2a0808")
DM1 = hx("ff7a1a")
DM2 = hx("c8321f")
DM3 = hx("8f1a1a")


def art(rows, cmap, w=None):
    rows = [r for r in rows]
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


def load(name):
    return Image.open(os.path.join(ENV, name)).convert("RGBA")


def save(im, name):
    p = os.path.join(ENV, name)
    im.save(p, optimize=True)
    return p


def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def strip(frames, gap=0):
    w = sum(f.width for f in frames) + gap * (len(frames) - 1)
    h = max(f.height for f in frames)
    s = Image.new("RGBA", (w, h), T)
    x = 0
    for f in frames:
        s.alpha_composite(f, (x, 0))
        x += f.width + gap
    return s


def paste(dst, src, xy):
    dst.alpha_composite(src, (int(xy[0]), int(xy[1])))


def font(size=10):
    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def label(im, xy, text, size=12, fill=(239, 227, 198, 255)):
    d = ImageDraw.Draw(im)
    d.text(xy, text, font=font(size), fill=fill)


def board(w, h, bg=(26, 23, 20, 255)):
    return Image.new("RGBA", (w, h), bg)


def tile_fill(dst, tile, box):
    x0, y0, x1, y1 = box
    for y in range(y0, y1, tile.height):
        for x in range(x0, x1, tile.width):
            dst.alpha_composite(tile.crop((0, 0, min(tile.width, x1 - x), min(tile.height, y1 - y))), (x, y))


def emissive(frame, levels):
    """Emissive mask: RGB = glow level (grey), A = 255 on glowing pixels, 0 elsewhere."""
    m = Image.new("RGBA", frame.size, T)
    src, dst = frame.load(), m.load()
    for y in range(frame.height):
        for x in range(frame.width):
            c = src[x, y]
            if c[3] == 0:
                continue
            v = levels.get(c[:3], 0)
            if v:
                dst[x, y] = (v, v, v, 255)
    return m


# =====================================================================================
# (2) flames
# =====================================================================================
HOLY = {"E": FL_E, "H": GOLD1, "B": GOLD2, "D": GOLD3}
HOLY_LEVELS = {FL_E[:3]: 255, GOLD1[:3]: 205, GOLD2[:3]: 150, GOLD3[:3]: 100}

# small: 4 x 7, anchor = bottom row (y6) sits on the wick / lamp rim, flame columns x1-x2.
# frame 0 is pixel-identical to the static flame of altar_v04.
FLAME_S = [
    ["....", "....", "....", ".H..", ".HH.", ".EE.", ".EE."],
    ["....", "....", "..D.", "..H.", ".HH.", ".EE.", ".EE."],
    ["....", "....", "....", "..H.", ".HH.", ".EE.", ".EE."],
    ["....", "....", ".D..", ".H..", ".HH.", ".EE.", ".EE."],
    ["....", "....", "....", "....", "....", "....", ".BD."],   # ember (unlit)
]
# large: 6 x 10, anchor = bottom row (y9), centre between x2 and x3 (building lights, braziers)
FLAME_L = [
    ["......", "......", "..D...", "..H...", "..HH..", ".HHH..", ".HEEH.", ".HEEH.", ".BEEB.", "..BB.."],
    ["......", "...D..", "...H..", "..HH..", "..HHH.", ".HHEH.", ".HEEH.", ".HEEH.", ".BEEB.", "..BB.."],
    ["......", "......", "......", "...D..", "..HH..", ".HHHH.", "BHEEH.", ".HEEHB", ".BEEB.", "..BB.."],
    ["..D...", "..H...", "..H...", ".HH...", ".HHH..", ".HEHH.", ".HEEH.", ".HEEH.", ".BEEB.", "..BB.."],
    ["......", "......", "......", "......", "......", "......", "......", "......", "...D..", "..BD.."],
]

# heretic fire: ragged, split tongues, a loose spark. Slots 1 core, 2 body, 3 edge, 4 tip, 5 smoke.
HER_A = {"1": GOLD1, "2": GOLD2, "3": GOLD3, "4": GOLD4, "5": D2E}           # candA candle gold
HER_B = {"1": DM1, "2": DM2, "3": DM3, "4": BLD1, "5": BLD2}               # candB demonic orange
HER_A_LEVELS = {GOLD1[:3]: 205, GOLD2[:3]: 150, GOLD3[:3]: 100, GOLD4[:3]: 60}
HER_B_LEVELS = {DM1[:3]: 205, DM2[:3]: 150, DM3[:3]: 100, BLD1[:3]: 60}
HER_S = [
    [".....", "...4.", "...3.", ".4.3.", ".322.", ".2112", "3211.", ".313."],
    [".....", ".....", ".4...", ".3.4.", ".23..", "3212.", ".2112", ".313."],
    ["..5..", ".....", "...4.", ".4.3.", ".232.", ".2113", "3211.", ".313."],
    [".....", ".4...", ".3...", ".3.4.", ".223.", "2112.", ".2113", ".313."],
    [".....", ".....", ".....", ".....", ".....", ".5...", ".....", ".34.."],
]
HER_L = [   # 8 x 13, anchor = bottom row (y12), centre between x3 and x4
    [".....4..", "..4..3..", "..3..34.", ".32.323.", ".22.22..", ".2232224", "32212223", ".2211122",
     "32111122", ".2111123", ".2311132", "..32223.", "...333.."],
    ["......4.", "...4..3.", "..43..3.", "..32.32.", ".322.22.", ".22322.3", "3221223.", ".2211122",
     "32111123", ".2111122", ".2311132", "..32223.", "...333.."],
    [".4......", ".3...4..", ".34..3..", ".32.32..", "322.22.4", ".2232223", ".2212122", "32211122",
     ".2111122", "32111123", ".2311132", "..32223.", "...333.."],
    ["....5...", "........", ".4...4..", ".3..43..", ".32.32.4", ".223223.", "3221222.", ".2211123",
     "32111122", ".2111122", ".2311132", "..32223.", "...333.."],
    ["........", "........", "........", "........", "........", "........", "...5....", "........",
     "....5...", "........", "........", "...4....", "..3433.."],
]


def make_flames():
    out = {}
    sets = [
        ("flame_small_v01", FLAME_S, HOLY, HOLY_LEVELS),
        ("flame_large_v01", FLAME_L, HOLY, HOLY_LEVELS),
        ("flame_heretic_small_candA_v01", HER_S, HER_A, HER_A_LEVELS),
        ("flame_heretic_small_candB_v01", HER_S, HER_B, HER_B_LEVELS),
        ("flame_heretic_large_candA_v01", HER_L, HER_A, HER_A_LEVELS),
        ("flame_heretic_large_candB_v01", HER_L, HER_B, HER_B_LEVELS),
    ]
    for name, frames, cmap, levels in sets:
        fr = [art(f, cmap) for f in frames]
        out[name] = fr
        save(strip(fr), name + ".png")
        save(strip([emissive(f, levels) for f in fr]), name + "_emissive.png")
    return out


# =====================================================================================
# (1) breakable wall crack overlays (dungeon wall top = rock, face = brick courses)
# =====================================================================================
# x crack, s shadow side, l fresh lip (lit side of the break), m fresh chipped face,
# d deep hole, r rubble crumb
CRACK_TOP_MAP = {"x": OUT, "s": D2E, "l": G8C, "m": G6B, "d": D24, "r": G5A}
CRACK_TOP = [
    [  # stage 1: one jagged hairline from the hit point
        "................",
        "................",
        "................",
        "................",
        "....x...........",
        "....xx..........",
        "....llxx........",
        "......lx........",
        ".......xxx......",
        ".......llxx.....",
        "..........x.....",
        "..........xl....",
        "..........l.....",
        "................",
        "................",
        "................",
    ],
    [  # stage 2: longer, two branches
        "................",
        "..x.............",
        "..xx............",
        "..lx............",
        "...xx...........",
        "...lxx..........",
        "....llxx........",
        "......lxxxx.....",
        "......xxxxlxx...",
        ".....xxl.l.llxx.",
        "....xxl......lx.",
        "...xxl........x.",
        "...ll.........l.",
        "................",
        "................",
        "................",
    ],
    [  # stage 3: network to the edges, a sunken chunk at the hit point, crumbs
        ".x..........x...",
        ".xx.........x...",
        "..xx.......xx...",
        "..lxx......xl...",
        "...lxx....xx.xx.",
        "....lxx...xlxxl.",
        ".....lxxddxxl...",
        "......xddddx....",
        "...xx.xdddmxx...",
        "..xxl.xmmmlxxx..",
        ".xxl..lxxxl..xx.",
        "xxl...xx....lxxl",
        ".l...xxl.....l..",
        ".....xl.........",
        "....xxl...r.....",
        "....l....r.r....",
    ],
]
CRACK_FACE_MAP = {"x": OUT, "s": D24, "l": G5A, "L": G6B, "d": D24, "r": G4A, "R": G6B}
# 16 x 24. Row 0 = row 3 of the 32-px column under a wall cap in tiles_dungeon_v02
# (tile at x48,y0 over tile at x48,y16): rows 0-1 cap lip, bricks from row 2, floor shadow 22-23.
CRACK_FACE = [
    [
        "................",
        "................",
        "......x.........",
        "......xx........",
        "......lx........",
        ".......xx.......",
        "........x.......",
        "........xx......",
        "........lx......",
        ".........x......",
        ".........l......",
    ] + ["................"] * 13,
    [
        "....x...........",
        "....xx..........",
        "....lxx.........",
        ".....lx.........",
        "......xx........",
        "......lxx...x...",
        "........x..xx...",
        "........xxxxl...",
        "........lxx.....",
        "..........x.....",
        "..........xx....",
        "..........lx....",
        "...........xx...",
        "...........lx...",
        "............l...",
    ] + ["................"] * 9,
    [
        "..x.......x.....",
        "..xx......x.....",
        "..lxx....xx.....",
        "...lxx..xxl.....",
        "....lxddxl..xx..",
        ".....xdddx.xxl..",
        "..xx.xdLLxxxl...",
        ".xxl.lxLLlx.....",
        ".xl...lxxxx.....",
        ".l......xddx....",
        "........xdLLx...",
        ".......xxLLLxx..",
        "......xxl.lxxl..",
        ".....xxl....lxx.",
        ".....xl......lx.",
        "....xxl.......xl",
        "....xl........l.",
        "....l...........",
        "................",
        "................",
        "................",
        "....R.....r.....",
        "...rRr...rR.R...",
        "..r.r.....r.....",
    ],
]


def make_cracks():
    tops = [art(r, CRACK_TOP_MAP) for r in CRACK_TOP]
    faces = [art(r, CRACK_FACE_MAP) for r in CRACK_FACE]
    save(strip(tops), "wall_crack_top_v01.png")
    save(strip(faces), "wall_crack_face_v01.png")
    return tops, faces


def crack_preview(tops, faces):
    dun = load("tiles_dungeon_v02.png")
    rock = dun.crop((0, 96, 16, 112))
    col = dun.crop((48, 0, 64, 32))
    floor = dun.crop((32, 32, 48, 48))
    cols = 4
    scene = Image.new("RGBA", (16 * cols, 16 + 32 + 16), T)
    for i in range(cols):
        paste(scene, rock, (16 * i, 0))
        paste(scene, col, (16 * i, 16))
        paste(scene, floor, (16 * i, 48))
        if i:
            paste(scene, tops[i - 1], (16 * i, 0))
            paste(scene, faces[i - 1], (16 * i, 16 + 3))
    k = 4
    big = up(scene, k)
    sheet = board(big.width + 16, big.height + 40)
    paste(sheet, big, (8, 30))
    for i, t in enumerate(["0 (no damage)", "stage 1", "stage 2", "stage 3"]):
        label(sheet, (8 + 16 * k * i + 4, 8), t, 13)
    return sheet, scene


# =====================================================================================
# (3) built wall / door / floor candidates (open ?: stone only = candA, wood + stone = candB)
# =====================================================================================
N_, E_, S_, W_ = 1, 2, 4, 8
FACE_H = 24   # same face height as the dungeon wall (rows 3-26 of the column in tiles_dungeon_v02)


def _tex(fn, w=16, h=16):
    im = Image.new("RGBA", (w, h), T)
    px = im.load()
    for y in range(h):
        for x in range(w):
            c = fn(x, y)
            if c is not None:
                px[x, y] = c
    return im


def stone_cap_tex():
    # ashlar in the altar-top greys, 2 courses of 7 px + 1 px joint, period 16 both ways
    spk = {(3, 3): G89, (11, 2): G89, (5, 11): G89, (13, 12): G89, (9, 5): G95, (1, 13): G95}

    def f(x, y):
        course, yy = divmod(y, 8)
        if yy == 7:
            return G6B
        joints = (7, 15) if course == 0 else (3, 11)
        if x in joints:
            return G6B
        bx = (x - (0 if course == 0 else 4)) % 8
        if (x, y) in spk:
            return spk[(x, y)]
        if yy == 0:
            return G9D
        if bx == 0:
            return G95
        if yy == 6:
            return G89
        return G8F
    return _tex(f)


def stone_face_tex():
    # brick courses like the altar front face: lip row, 3-px courses, dark joints, ground line
    def f(x, y):
        if y == 0:
            return G5B
        if y == FACE_H - 1:
            return OUT
        if y % 4 == 0:
            return D3D
        course = (y // 4) % 2
        joints = (7, 15) if course == 0 else (3, 11)
        if x in joints:
            return D2E
        bx = (x - (0 if course == 0 else 4)) % 8
        if y % 4 == 1 and bx in (0, 1):
            return G5B
        if y >= FACE_H - 3:                 # ambient occlusion near the ground
            return D3D if (x + y) % 4 == 0 else G4A
        return G4A
    return _tex(f, 16, FACE_H)


def wood_cap_tex(orient):
    # top of a timber wall: boards 3 px + 1 px gap along the run; butt joints staggered
    butts = {0: 5, 1: 13, 2: 9, 3: 1}

    def fh(x, y):
        b, yy = divmod(y, 4)
        if yy == 3:
            return W1
        if x == butts[b]:
            return W2
        if yy == 0:
            return W6
        if yy == 2:
            return W4
        if (x * 7 + b * 3) % 11 == 0:
            return W4
        return W5
    if orient == "h":
        return _tex(fh)
    if orient == "v":
        return _tex(lambda x, y: fh(y, x))

    # post top (corner / junction / lone cell): plain bevelled square, end-grain checks only
    def fp(x, y):
        if x in (0, 15) or y in (0, 15):
            return W2
        if x == 1 or y == 1:
            return W6
        if x == 14 or y == 14:
            return W3
        if (x, y) in ((5, 6), (6, 6), (10, 9)):
            return W3
        if (x, y) in ((4, 10), (5, 10), (6, 10), (9, 4), (10, 4)):
            return W4
        return W5
    return _tex(fp)


def wood_face_tex():
    # vertical planks (4 px) over a stone footing: the "wood + stone" wall
    def f(x, y):
        if y == FACE_H - 1:
            return OUT
        if y == 0:
            return W7
        if y == 1:
            return W5
        if y == 2:
            return W1
        if y == 17:
            return G8F
        if y >= 18:
            off = 0 if y < 20 else 2
            if y == 20 or (x + off) % 5 == 4:
                return G4A
            return G7D if y in (18, 21) else G6B
        px = x % 4
        if px == 3:
            return W1
        if px == 0:
            return W6
        if (x, y) in ((5, 7), (13, 5), (9, 12), (1, 14)):
            return W3
        return W5 if y < 10 else W4
    return _tex(f, 16, FACE_H)


def cap_tile(mask, tex, edge):
    t = tex.copy()
    px = t.load()
    n, e, s, w = mask & N_, mask & E_, mask & S_, mask & W_
    if not n:
        for x in range(16):
            px[x, 1] = edge["n_hi"]
            px[x, 0] = edge["out"]
    if not s:
        for x in range(16):
            px[x, 14] = edge["s_sh"]
            px[x, 15] = edge["out"]
    if not w:
        for y in range(16):
            if px[1, y] != edge["out"]:
                px[1, y] = edge["w_hi"]
            px[0, y] = edge["out"]
    if not e:
        for y in range(16):
            if px[14, y] != edge["out"]:
                px[14, y] = edge["e_sh"]
            px[15, y] = edge["out"]
    # round the two top corners when both sides are open (the bottom ones meet the face)
    if not n and not w:
        px[0, 0] = T
    if not n and not e:
        px[15, 0] = T
    return t


def face_tile(kind, tex, out, hi, sh):
    """kind: single / left / mid / right (whether the neighbouring wall cells also show a face)."""
    t = tex.copy()
    px = t.load()
    last = t.height - 1
    if kind in ("single", "left"):
        for y in range(last):
            px[1, y] = hi
            px[0, y] = out
        px[0, last] = out
    if kind in ("single", "right"):
        for y in range(last):
            px[14, y] = sh
            px[15, y] = out
        px[15, last] = out
    return t


def inner_corners(out):
    res = []
    for (x, y) in ((15, 0), (0, 0), (15, 15), (0, 15)):   # NE, NW, SE, SW
        t = Image.new("RGBA", (16, 16), T)
        t.putpixel((x, y), out)
        res.append(t)
    return res


def _door(top, body, rows_total=FACE_H, band_rows=(), handle=None, bottom="", last=""):
    rows = list(top)
    while len(rows) < rows_total - 2:
        r = len(rows)
        if r in band_rows:
            rows.append(body[1])
        elif handle and r == handle[0]:
            rows.append(handle[1])
        elif bottom and r >= rows_total - 4:
            rows.append(bottom)
        else:
            rows.append(body[0])
    rows.append(last)
    rows.append("................")
    return rows


DOOR_STONE_CLOSED = _door(
    ["................", "................", ".....oooooo.....", "....ooKKKKoo....",
     "...ooK5425Koo...", "..ooK542542Koo.."],
    ["..oK54254254Ko..", "..oKbbbbbbbbKo.."], band_rows=(9, 17),
    handle=(13, "..oK5425425gKo.."), last="..oKttttttttKo..")
DOOR_STONE_OPEN = _door(
    ["................", "................", ".....oooooo.....", "....ooKKKKoo....",
     "...ooK5wwwKoo...", "..ooK54wwwwKoo.."],
    ["..oK54wwwwwwKo..", "..oKb4wwwwwwKo.."], band_rows=(9, 17),
    bottom="..oK54ffffffKo..", last="..oKttttttttKo..")
DOOR_WOOD_CLOSED = _door(
    ["................", "................", "................", "...PPPPPPPPPP...",
     "...PqqqqqqqqP..."],
    ["...P76276276P...", "...P22222222P..."], band_rows=(9, 16),
    handle=(13, "...P7627627gP..."), last="...PttttttttP...")
DOOR_WOOD_OPEN = _door(
    ["................", "................", "................", "...PPPPPPPPPP...",
     "...PqqqqqqqqP..."],
    ["...P76wwwwwwP...", "...P22wwwwwwP..."], band_rows=(9, 16),
    bottom="...P76ffffffP...", last="...PttttttttP...")
DOOR_MAP = {"K": OUT, "o": G6B, "5": W5, "4": W4, "2": W2, "b": D2E, "g": GOLD2, "t": G7D,
            "w": WB, "f": G4A, "P": W1, "q": W2, "7": W6, "6": W4}


def floor_stone(var):
    # placed stone floor: a darker, cosier grey than the wall cap; joint on the cell edge
    k = ("h", "v", "q")[var]
    spk = {0: [(3, 3), (11, 10), (5, 12)], 1: [(12, 4), (4, 10), (2, 2)], 2: [(10, 3), (3, 11), (12, 12)]}[var]

    def f(x, y):
        if x == 15 or y == 15:
            return G6B
        if k == "h" and (y == 7 or (y > 7 and x == 7)):
            return G6B
        if k == "v" and (x == 9 or (x > 9 and y == 8)):
            return G6B
        if k == "q" and (x == 7 or y == 7):
            return G6B
        if (x, y) in spk:
            return G5B
        hi = x == 0 or y == 0
        hi |= k == "h" and (y == 8 or (y > 7 and x == 8))
        hi |= k == "v" and (x == 10 or (x > 9 and y == 9))
        hi |= k == "q" and (x == 8 or y == 8)
        return G89 if hi else G7D
    return _tex(f)


def floor_wood(var):
    butts = {0: (3, 11, 7, 14), 1: (9, 1, 13, 5), 2: (6, 14, 2, 10)}[var]
    knot = {0: (12, 5), 1: (4, 9), 2: (10, 1)}[var]

    def f(x, y):
        b, yy = divmod(y, 4)
        if yy == 3:
            return W3
        if x == butts[b]:
            return W2
        if (x, y) == knot:
            return W3
        if yy == 0:
            return W6
        return W5 if yy == 1 else W4
    return _tex(f)


MATERIALS = {
    "stone": dict(cap=lambda m: stone_cap_tex(), face=stone_face_tex,
                  edge=dict(out=OUT, n_hi=G9D, w_hi=G95, e_sh=G7D, s_sh=G7D),
                  face_hi=G5B, face_sh=D3D,
                  door=(DOOR_STONE_CLOSED, DOOR_STONE_OPEN), floor=floor_stone),
    "wood": dict(cap=None, face=wood_face_tex,
                 edge=dict(out=OUT, n_hi=W7, w_hi=W6, e_sh=W3, s_sh=W3),
                 face_hi=W6, face_sh=W2,
                 door=(DOOR_WOOD_CLOSED, DOOR_WOOD_OPEN), floor=floor_wood),
}


def wood_cap_for(mask):
    h = bool(mask & (E_ | W_))
    v = bool(mask & (N_ | S_))
    if h and not v:
        return wood_cap_tex("h")
    if v and not h:
        return wood_cap_tex("v")
    return wood_cap_tex("post")


def build_set(material):
    m = MATERIALS[material]
    caps = []
    for mask in range(16):
        tex = m["cap"](mask) if m["cap"] else wood_cap_for(mask)
        caps.append(cap_tile(mask, tex, m["edge"]))
    corners = inner_corners(OUT)
    ftex = m["face"]()
    faces = {k: face_tile(k, ftex, OUT, m["face_hi"], m["face_sh"]) for k in ("single", "left", "mid", "right")}
    doors = []
    for rows in m["door"]:
        d = faces["mid"].copy()
        paste(d, art(rows, DOOR_MAP, 16), (0, 0))
        doors.append(d)
    floors = [m["floor"](v) for v in range(3)]
    return dict(caps=caps, corners=corners, faces=faces, doors=doors, floors=floors)


# sheet layout (128 x 72):
#   y 0-31  caps by neighbour mask (N=1 E=2 S=4 W=8), index = mask, 8 per row
#   y32-47  inner-corner dots NE NW SE SW (x 0-63), floors A B C (x 64-111)
#   y48-71  faces single / left end / middle / right end (x 0-63), door closed, door open (x 64-95)
def build_sheet(bs):
    sh = Image.new("RGBA", (128, 72), T)
    for i, c in enumerate(bs["caps"]):
        paste(sh, c, ((i % 8) * 16, (i // 8) * 16))
    for i, c in enumerate(bs["corners"]):
        paste(sh, c, (i * 16, 32))
    for i, f in enumerate(bs["floors"]):
        paste(sh, f, (64 + i * 16, 32))
    for i, k in enumerate(("single", "left", "mid", "right")):
        paste(sh, bs["faces"][k], (i * 16, 48))
    for i, d in enumerate(bs["doors"]):
        paste(sh, d, (64 + i * 16, 48))
    return sh


def ground_tiles(names, w, h, seed):
    tiles = [load(n) for n in names]
    rnd = random.Random(seed)
    im = Image.new("RGBA", (w * 16, h * 16), T)
    for y in range(h):
        for x in range(w):
            paste(im, tiles[0] if rnd.random() < 0.5 else rnd.choice(tiles[1:]), (x * 16, y * 16))
    return im


GRASS = ["tiles_grass_base_v02.png"] + [f"tiles_grass_var_{i}_v02.png" for i in range(1, 5)]
ASH = ["tiles_ash_plain_1_v01.png", "tiles_ash_plain_2_v01.png", "tiles_ash_plain_3_v01.png"]


def assemble(bs, walls, doors, floors, base):
    """walls: set of (cx, cy); doors: {(cx, cy): 0 closed | 1 open} (door cells are wall cells);
    floors: set of cells. Cap = the wall cell. Face (16 x 24) hangs from the cell below when that
    cell is not a wall, like the dungeon wall. Rows are drawn north to south."""
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


def make_build():
    out = {}
    for material, cand in (("stone", "candA"), ("wood", "candB")):
        bs = build_set(material)
        save(build_sheet(bs), f"build_{material}_{cand}_v01.png")
        out[material] = bs
    return out


def _room(x0, y0, x1, y1, door_x, door_state):
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


def build_preview(sets, flames):
    W, H = 24, 12
    base = ground_tiles(GRASS, W, H, 7)
    panels = []
    for material, title in (("stone", "candA  stone only (altar-stone greys, dungeon wall shape, 24 px face)"),
                            ("wood", "candB  wood + stone (timber wall on a stone footing, plank floor)")):
        bs = sets[material]
        walls, doors, floors = _room(1, 1, 8, 7, 4, 0)
        w2, d2, f2 = _room(11, 2, 15, 7, 13, 1)
        walls |= w2
        doors.update(d2)
        floors |= f2
        for c in ((18, 1), (18, 2), (18, 3), (19, 3), (20, 3), (20, 2), (21, 3), (18, 7), (19, 7), (20, 7), (19, 8)):
            walls.add(c)
        im = assemble(bs, walls, doors, floors, base)
        panels.append((title, im))
    sbs, wbs = sets["stone"], sets["wood"]
    walls, doors, floors = _room(1, 1, 8, 7, 4, 0)
    mixed = assemble(sbs, walls, doors, floors, base)
    ww, wd, wf = _room(10, 2, 15, 7, 12, 1)
    paste(mixed, assemble(wbs, ww, wd, wf, Image.new("RGBA", base.size, T)), (0, 0))
    panels.append(("candB in use: stone house and wood annexe side by side", mixed))
    k = 4
    sheet = board(W * 16 * k + 16, len(panels) * (H * 16 * k + 34) + 8)
    y = 8
    for title, im in panels:
        label(sheet, (10, y), title, 16)
        paste(sheet, up(im, k), (8, y + 24))
        y += H * 16 * k + 34
    return sheet


# =====================================================================================
# (4) altar upgrade stage 1 (open ?: look). candA = the brief's proposal, candB = second idea
# =====================================================================================
# altar_v04: body = rows 5..47 of the 48x57 file (47 x 43). Static lamp flames = FLAME_S frame 0
# with the flame canvas (4 x 7) at these top-left points (file coordinates):
LAMP_ORIGINS = [(9, 5), (22, 5), (35, 5), (9, 15), (22, 15), (35, 15), (9, 25), (22, 25), (35, 25)]
AX, AY = 4, 12          # altar body top-left inside the 56 x 64 upgrade canvas
UP_W, UP_H = 56, 64

CANDLESTICK = [          # 6 x 12, gold, ivory candle; flame canvas sits at (+1, -7)
    ".KabK.",
    ".KabK.",
    ".KabK.",
    "KhhhgK",
    "KdggdK",
    ".KhgK.",
    ".KhgK.",
    "KhhggK",
    ".KhgK.",
    "KhhhgK",
    "KgdddK",
    ".KKKK.",
]
LAMPSTAND = [            # 8 x 23, tall gold lamp stand for candB; large flame canvas at (+1, -9)
    ".KhhhgK.",
    "KhhhhggK",
    ".KdggdK.",
    "..KhgK..",
    "..KhgK..",
    "..KhgK..",
    ".KhhggK.",
    "..KhgK..",
    "..KhgK..",
    "..KhgK..",
    "..KhgK..",
    "..KhgK..",
    "..KhgK..",
    ".KhhggK.",
    "..KhgK..",
    "..KhgK..",
    "..KhgK..",
    ".KhhhgK.",
    "KhhhhggK",
    "KhhgggdK",
    "KggddddK",
    "KdddddKK",
    ".KKKKKK.",
]
STICK_MAP = {"K": OUT, "a": IV1, "b": IV3, "h": GOLD1, "g": GOLD2, "d": GOLD3}


def altar_litbase(lit):
    """altar_v04 lit with the static flame pixels removed (light spill and oil glow kept),
    so the animated flame can be drawn on top."""
    return strip_lamp_flames(lit, LAMP_ORIGINS)


def strip_lamp_flames(img, origins):
    # the static flames are #fff6dc / #f4c95d pixels inside each 4 x 7 flame box (lamp 2 leans
    # right, the others left); light spill (#a48d6b) above the rim, oil glow (#c9932b) in the rim row
    base = img.copy()
    px = base.load()
    n = 0
    for (ox, oy) in origins:
        for y in range(7):
            for x in range(4):
                if px[ox + x, oy + y] in (FL_E, GOLD1):
                    px[ox + x, oy + y] = GOLD2 if y == 6 else HALO
                    n += 1
    assert n == 7 * len(origins), n
    return base


def pedestal(canvas):
    px = canvas.load()
    x0, x1 = AX - 3, AX + 46 + 3            # outline columns
    y0 = AY - 3                              # back outline row
    yb = AY + 42                             # altar bottom outline row
    yt0, yt1 = yb + 1, yb + 3                # front tread rows
    yr0, yr1 = yb + 4, yb + 7                # riser rows
    yo = yb + 8                              # bottom outline
    for y in range(y0, yo + 1):
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or y in (y0, yo)
            if edge:
                c = OUT
            elif y <= yt1:
                c = G89
                if y == y0 + 1:
                    c = G95
                if y == yt0 or x in (AX - 1, AX + 47):
                    c = G7D                              # shade next to the altar body
                if y == yt1 and (x - x0) % 13 != 0:
                    c = G95                              # tread nosing catches the light
                if y >= yt0 and (x - x0) % 13 == 0:
                    c = G7D                              # slab joints
            else:
                c = G4A
                if y == yr0:
                    c = G5B
                if y == yr1 or (x - x0) % 13 == 6:
                    c = D3D
            px[x, y] = c
    # round the front-bottom and back corners by one pixel
    for (x, y) in ((x0, y0), (x1, y0), (x0, yo), (x1, yo)):
        px[x, y] = T


def cloth(canvas):
    """ivory altar frontal with gold trim, laid over the front rim and hanging down the face."""
    px = canvas.load()
    L, R = AX + 8, AX + 38            # outline columns of the cloth
    b = AY                            # body row 0
    for x in range(L + 1, R):
        px[x, b + 32] = OUT
        px[x, b + 33] = GOLD1 if (x - L) % 3 == 1 else GOLD2
        px[x, b + 34] = IV1
        px[x, b + 35] = IV1
        for y in range(b + 36, b + 41):
            k = (x - L - 2) % 6          # soft vertical folds: crest, body, shade, deep shade
            c = {0: IV1, 1: IV2, 2: IV2, 3: IV3, 4: IV3, 5: IV2}[k]
            if k == 4 and y >= b + 38:
                c = IV4
            px[x, y] = c
        px[x, b + 41] = GOLD1 if (x - L) % 2 else GOLD2
        px[x, b + 42] = GOLD3 if (x - L) % 2 else OUT        # fringe over the bottom outline
        if (x - L) % 2:
            px[x, b + 43] = GOLD3                            # fringe tips on the step
    for y in range(b + 33, b + 42):
        px[L, y] = OUT
        px[R, y] = OUT
        if y >= b + 34:
            px[L + 1, y] = GOLD1
            px[R - 1, y] = GOLD2
    px[L + 1, b + 42] = OUT
    px[R - 1, b + 42] = OUT


def gold_band(canvas):
    """candB: gilded top row on the front face (no cloth)."""
    px = canvas.load()
    b = AY
    for x in range(AX + 2, AX + 45):
        px[x, b + 35] = GOLD1 if x % 2 else GOLD2
        px[x, b + 36] = GOLD3


def place_stick(canvas, sx, sy, lit, rows=CANDLESTICK, flame=None, foff=(1, -7)):
    paste(canvas, art(rows, STICK_MAP), (sx, sy))
    fx, fy = sx + foff[0], sy + foff[1]
    if lit:
        paste(canvas, flame, (fx, fy))
    else:
        cx = sx + foff[0] + (1 if rows is CANDLESTICK else 2)
        canvas.putpixel((cx, sy - 1), OUT)                    # cold wick
    return (fx, fy)


def make_altar_up(cand, lit):
    src = load("altar_v04.png") if lit else load("altar_v04_unlit.png")
    body = src.crop((0, 5, 47, 48))
    im = Image.new("RGBA", (UP_W, UP_H), T)
    pedestal(im)
    paste(im, body, (AX, AY))
    anchors = []
    small = art(FLAME_S[0], HOLY)
    large = art(FLAME_L[0], HOLY)
    if cand == "candA":
        anchors += [("candle", place_stick(im, AX + 0, AY - 5, lit, flame=small))]
        anchors += [("candle", place_stick(im, AX + 41, AY - 5, lit, flame=small))]
        cloth(im)
        anchors += [("candle", place_stick(im, AX + 0, AY + 22, lit, flame=small))]
        anchors += [("candle", place_stick(im, AX + 41, AY + 22, lit, flame=small))]
    else:
        gold_band(im)
        anchors += [("stand", place_stick(im, AX - 4, AY + 22, lit, rows=LAMPSTAND, flame=large, foff=(1, -10)))]
        anchors += [("stand", place_stick(im, AX + 43, AY + 22, lit, rows=LAMPSTAND, flame=large, foff=(1, -10)))]
    lamps = [("lamp", (ox + AX, oy - 5 + AY)) for (ox, oy) in LAMP_ORIGINS]
    return im, lamps + anchors


def make_altar():
    res = {}
    for cand in ("candA", "candB"):
        lit, anchors = make_altar_up(cand, True)
        unlit, _ = make_altar_up(cand, False)
        save(lit, f"altar_up1_{cand}_v01.png")
        save(unlit, f"altar_up1_{cand}_v01_unlit.png")
        # lit base for the animated flames: draw the lit sprite, then take the flames back off
        base = strip_lamp_flames(lit, [xy for kind, xy in anchors if kind == "lamp"])
        pb = base.load()
        for kind, (fx, fy) in anchors:
            if kind == "lamp":
                continue
            fr = art((FLAME_L if kind == "stand" else FLAME_S)[0], HOLY)
            for y in range(fr.height):
                for x in range(fr.width):
                    if fr.getpixel((x, y))[3]:
                        pb[fx + x, fy + y] = unlit.getpixel((fx + x, fy + y))
        save(base, f"altar_up1_{cand}_v01_litbase.png")
        full = Image.new("RGBA", lit.size, T)
        for kind, (fx, fy) in anchors:
            fr = art((FLAME_L if kind == "stand" else FLAME_S)[0], HOLY)
            paste(full, emissive(fr, HOLY_LEVELS), (fx, fy))
        save(full, f"altar_up1_{cand}_v01_emissive.png")
        res[cand] = (lit, unlit, base, anchors)
    # lit base for the existing altar too (same flame anchors), so altar_v04 can animate
    save(altar_litbase(load("altar_v04.png")), "altar_v04_litbase.png")
    return res


# =====================================================================================
# (5) dungeon entrance surroundings + scattered corruption decals
# =====================================================================================
# stairs overlay: same 48 x 48 frame as dungeon_entrance_v02. Replaces the vague rubble at the
# bottom of the opening with four treads that step down into the dark (nearest = lightest).
STAIRS = [
    # rows 20..34 of the 48 x 48 frame, columns 15..32 (18 wide)
    "KKKKKKKKKKKKKKKKKK",   # 20 dark beyond the last tread
    "K33333333333333.3K",   # 21 tread 4 nosing (worn gap)
    "KoooooooooooooooKK",   # 22 tread 4
    "KKKKKKKKKKKKKKKKKK",   # 23 drop
    "K5555555555.555555",   # 24 tread 3 nosing
    "Kw4444444444444w4K",   # 25 tread 3
    "KKKKKKKKKKKKKKKKKK",   # 26 drop
    "K777777.7777777777",   # 27 tread 2 nosing
    "Kg8888888888888g8K",   # 28 tread 2
    "Kg888888888888888K",   # 29
    "dKKKKKKKKKKKKKKKKd",   # 30 drop
    "dAAAAAAAAAAAAAAAAd",   # 31 tread 1 nosing (lit edge)
    "d9999999m99999999d",   # 32 tread 1, worn middle
    "d99999mmmmm999999d",   # 33
    "d799999m999999997d",   # 34 meets the sill
]
STAIRS_MAP = {"K": OUT, "o": D2E, "3": E3B, "5": E5C, "4": E54, "w": G4A, "7": E7C, "8": G6B, "g": E5C,
              "A": EA6, "9": G8C, "m": E96, "d": D2E}

RUBBLE = {   # angular chunks: lit top (a/b), darker front face (c/s)
    "block": ["..KKKK.", ".KaaabK", "KaabbbK", "KcccccK", "KscccsK", ".KKKKK."],
    "chunk": [".KK..", "KabK.", "KbbbK", "KccsK", ".KKK."],
    "slab": ["...KKKK.", ".KKaabbK", "KaabbbbK", "KcccccsK", ".KKKKKK."],
    "bit": [".K.", "KaK", "KcK", ".K."],
    "pebble": ["ab", "cs"],
    "grit": ["b.", ".s"],
}
RUBBLE_MAP = {"K": OUT, "a": EAD, "b": G8C, "c": E7C, "s": E5C, "m": OLV, "M": MOSS2}


def rubble(kind, moss=False):
    im = art(RUBBLE[kind], RUBBLE_MAP)
    if moss and im.width >= 5:
        im.putpixel((2, 1), OLV)
        im.putpixel((3, 1), MOSS2)
    return im


ENT_W, ENT_H, ENT_OX, ENT_OY = 96, 72, 24, 12   # ring canvas; the arch frame (48 x 48) sits at (24, 12)


def make_entrance():
    stairs = Image.new("RGBA", (48, 48), T)
    paste(stairs, art(STAIRS, STAIRS_MAP), (15, 20))
    save(stairs, "dungeon_entrance_stairs_v01.png")

    rnd = random.Random(31)
    ring = Image.new("RGBA", (ENT_W, ENT_H), T)
    px = ring.load()
    # disturbed, ash-stained ground around the base: dithered, thinning outward, path left clear
    cx, cy = ENT_OX + 24, ENT_OY + 44
    for y in range(ENT_H):
        for x in range(ENT_W):
            dx, dy = (x - cx) / 44.0, (y - cy) / 22.0
            d = (dx * dx + dy * dy) ** 0.5
            if d > 1.0 or (ENT_OX + 10 <= x <= ENT_OX + 37 and ENT_OY + 2 <= y <= ENT_OY + 42):
                continue
            if abs(x - cx) < 9 and y > ENT_OY + 42:
                continue                                   # the trodden path stays clean
            p = 0.34 * (1.0 - d) ** 1.3
            if rnd.random() < p:
                px[x, y] = rnd.choice([G4A, G4A, E3B, D2E, G6B])
    # hand-placed fallen stones (arch blocks), then smaller rubble, then grit
    placed = [("block", 9, 46, True), ("slab", 74, 50, False), ("block", 15, 60, False),
              ("chunk", 64, 60, True), ("chunk", 18, 38, False), ("bit", 75, 41, False),
              ("bit", 28, 56, False), ("chunk", 80, 58, False), ("bit", 60, 54, True), ("slab", 4, 54, False)]
    for kind, x, y, moss in placed:
        paste(ring, rubble(kind, moss), (x, y))
    for _ in range(30):
        a = rnd.uniform(0, 6.283)
        r = rnd.uniform(0.55, 1.0)
        x = int(cx + math.cos(a) * 42 * r)
        y = int(cy + math.sin(a) * 20 * r)
        if abs(x - cx) < 9 and y > ENT_OY + 42:
            continue
        if ENT_OX + 9 <= x <= ENT_OX + 38 and y <= ENT_OY + 42:
            continue
        if 0 <= x < ENT_W - 2 and 0 <= y < ENT_H - 2:
            paste(ring, rubble(rnd.choice(["pebble", "pebble", "grit", "bit"])), (x, y))
    save(ring, "dungeon_entrance_debris_v01.png")

    full = Image.new("RGBA", (ENT_W, ENT_H), T)
    paste(full, ring, (0, 0))
    paste(full, load("dungeon_entrance_v02.png"), (ENT_OX, ENT_OY))
    paste(full, stairs, (ENT_OX, ENT_OY))
    save(full, "dungeon_entrance_set_v01.png")
    return stairs, ring, full


CRACK_DECALS = [
    ["KK.......", ".dKK.....", "..dKKK...", "....dKK.K", ".....wKKw", "..KK...w.", ".Kw......"],
    ["....K.......", "....KK......", "KK...dK.....", ".wKK..dKKK..", "...dKKKw.dKK", "......K....w", "......wK....",
     ".......w...."],
    ["..K....", "..dK...", "...K...", "..KK...", ".Kd.KK.", ".K...wK", "Kw....w", "w......", "..KK...", "...w..."],
    ["K.............", "dKK.......KK..", "..dKKK..KKd...", ".....dKKw..KK.", "........w...dK", "..............w"],
]
VEIN_DECALS = [
    ["KK......", ".KvK....", "...KvK..", ".....KKw"],
    [".....K..", "....KK..", "...KvK..", "..KvK...", ".KK.....", "Kw......"],
    ["KK..........", ".dKvK....K..", "....KKvvKKw.", "..........w."],
]
ASH_DECALS = [   # solid, wind-blown ash patches for the grass side of the boundary (no dot halo)
    ["..gg......", ".gggwg.gg.", "gggggggggg", ".ggwgggg..", "...gg.g..."],
    ["....ggg......", "..gggggggg...", ".gggwgggpggg.", "ggggggggwgggg", ".ggg.gggggg..", "......gg....."],
    [".gg.g..", "ggwggg.", "gggggg.", ".gggwgg", "..g.g.."],
]
DECAL_MAP = {"K": OUT, "d": D2E, "w": G4A, "v": VI1, "V": VI2, "o": G6B, "g": G6B, "p": G8C}


def make_decals():
    out = []
    for i, rows in enumerate(CRACK_DECALS, 1):
        im = art(rows, DECAL_MAP)
        save(im, f"decal_crack_{i}_v01.png")
        out.append(("crack", im))
    for i, rows in enumerate(VEIN_DECALS, 1):
        im = art(rows, DECAL_MAP)
        if i == 2:
            im.putpixel((3, 3), VI2)            # one brighter violet point, nothing larger
        save(im, f"decal_vein_{i}_v01.png")
        out.append(("vein", im))
    ash_map = dict(DECAL_MAP, o=G4A, g=G6B, d=D2E)
    for i, rows in enumerate(ASH_DECALS, 1):
        im = art(rows, ash_map)
        save(im, f"decal_ashcreep_{i}_v01.png")
        out.append(("ash", im))
    for i, kind in enumerate(("block", "chunk", "bit", "pebble"), 1):
        im = rubble(kind, moss=(i == 1))
        save(im, f"decal_rubble_{i}_v01.png")
        out.append(("rubble", im))
    return out


# =====================================================================================
# previews (x4) and checks
# =====================================================================================
TXT = (239, 227, 198, 255)


def titled(panels, k=4, gap=12, bg=(26, 23, 20, 255), title_size=15):
    """panels: list of (title, image). Each scaled by k, stacked vertically with a title line."""
    w = max(im.width * k for _, im in panels) + 2 * gap
    h = sum(im.height * k + 26 + gap for _, im in panels) + gap
    sheet = board(w, h, bg)
    y = gap
    for t, im in panels:
        label(sheet, (gap, y), t, title_size)
        paste(sheet, up(im, k), (gap, y + 22))
        y += im.height * k + 26 + gap
    return sheet


def row(items, gap=4, h=None, bg=T):
    h = h or max(i.height for i in items)
    w = sum(i.width for i in items) + gap * (len(items) + 1)
    im = Image.new("RGBA", (w, h + 2 * gap), bg)
    x = gap
    for i in items:
        paste(im, i, (x, gap + (h - i.height)))
        x += i.width + gap
    return im


def preview_cracks(tops, faces):
    dun = load("tiles_dungeon_v02.png")
    rock = dun.crop((0, 96, 16, 112))
    col = dun.crop((48, 0, 64, 32))
    floor = dun.crop((32, 32, 48, 48))
    blocks = []
    for s in range(4):
        b = Image.new("RGBA", (48, 80), T)
        for i in range(3):
            paste(b, rock, (16 * i, 0))
            paste(b, rock, (16 * i, 16))
            paste(b, col, (16 * i, 32))
            paste(b, floor, (16 * i, 64))
        if s:
            paste(b, tops[s - 1], (16, 16))
            paste(b, faces[s - 1], (16, 32 + 3))
        blocks.append(b)
    strip_ = row(blocks, 8, bg=(26, 23, 20, 255))
    ov = Image.new("RGBA", (3 * 20, 16 + 24 + 8), (60, 54, 48, 255))
    for i in range(3):
        paste(ov, tops[i], (2 + 20 * i, 2))
        paste(ov, faces[i], (2 + 20 * i, 22))
    return titled([
        ("wall cracks: undamaged / stage 1 / stage 2 / stage 3 (overlay on the middle cell; top 16x16 + face 16x24)", strip_),
        ("the overlays alone (wall_crack_top_v01 row 1, wall_crack_face_v01 row 2)", ov),
    ]), strip_


def preview_cracks_full(tops, faces):
    sheet, strip_ = preview_cracks(tops, faces)
    # append a true 1x copy at the bottom so the in-game size can be judged
    out = board(sheet.width, sheet.height + strip_.height + 30)
    paste(out, sheet, (0, 0))
    label(out, (12, sheet.height), "1x (in-game size before the x4 screen scale)", 13)
    paste(out, strip_, (12, sheet.height + 18))
    return out


def anim_altar_frames(base, anchors, phase_seed=0, heretic=None):
    """4 frames; each light gets its own phase so the lamps do not flicker in sync."""
    frames = []
    small = [art(f, HOLY) for f in FLAME_S]
    large = [art(f, HOLY) for f in FLAME_L]
    for t in range(4):
        im = base.copy()
        for i, (kind, (fx, fy)) in enumerate(anchors):
            fr = (large if kind == "stand" else small)[(t + i * 3 + phase_seed) % 4]
            paste(im, fr, (fx, fy))
        frames.append(im)
    return frames


def preview_flames(fl, altar_res):
    k = 8
    strips = []
    for name in ("flame_small_v01", "flame_large_v01", "flame_heretic_small_candA_v01",
                 "flame_heretic_small_candB_v01", "flame_heretic_large_candA_v01", "flame_heretic_large_candB_v01"):
        strips.append((name + "  (frames 1-4 loop, 5 = ember / unlit)", row(fl[name], 3, bg=(46, 42, 38, 255))))
    emis = [("emissive masks (grey = glow level, transparent = no glow)", row(
        [load("flame_small_v01_emissive.png"), load("flame_large_v01_emissive.png"),
         load("flame_heretic_large_candA_v01_emissive.png"), load("flame_heretic_large_candB_v01_emissive.png")],
        4, bg=(0, 0, 0, 255)))]
    top = titled(strips + emis, k=k)
    # context at x4: altar_v04 animated frame 0..3 side by side, relic bench candle, heretic shrine candA/B
    v4base = load("altar_v04_litbase.png")
    v4anchors = [("lamp", xy) for xy in LAMP_ORIGINS]
    v4f = anim_altar_frames(v4base, v4anchors)
    shrine = load("heretic_shrine_v02.png")
    her = []
    for cand in ("candA", "candB"):
        s = Image.new("RGBA", (48, 56), T)
        paste(s, shrine, (0, 8))
        for (fx, fy, size) in ((21, 11, "small"), (3, 30, "large"), (37, 30, "large")):
            fr = fl[f"flame_heretic_{size}_{cand}_v01"][0]
            paste(s, fr, (fx, fy) if size == "small" else (fx, fy))
        her.append(s)
    ctx = titled([("altar_v04 with the shared flame, frames 1-4 (each lamp offset in phase)", row(v4f, 6, bg=(26, 23, 20, 255))),
                  ("heretic fire on the shrine (illustration only, shrine unchanged): candA candle gold | candB demonic orange",
                   row(her, 10, bg=(26, 23, 20, 255)))], k=4)
    out = board(max(top.width, ctx.width), top.height + ctx.height)
    paste(out, top, (0, 0))
    paste(out, ctx, (0, top.height))
    # animated gif: altar_v04, upgrade candA, upgrade candB, relic-bench-style candle
    gif = []
    a_base, a_anch = altar_res["candA"][2], altar_res["candA"][3]
    b_base, b_anch = altar_res["candB"][2], altar_res["candB"][3]
    fa = anim_altar_frames(a_base, a_anch, 1)
    fb = anim_altar_frames(b_base, b_anch, 2)
    hs = [art(f, HER_A) for f in HER_L]
    hb = [art(f, HER_B) for f in HER_L]
    for t in range(4):
        scene = ground_tiles(GRASS, 12, 5, 11)
        dark = Image.new("RGBA", (40, 80), (26, 23, 20, 255))
        paste(scene, v4f[t], (4, 12))
        paste(scene, fa[t], (54, 6))
        paste(scene, fb[t], (114, 6))
        f = Image.new("RGBA", (192 + 40, 80), (26, 23, 20, 255))
        paste(f, scene, (0, 0))
        paste(dark, hs[t], (6, 30))
        paste(dark, hb[t], (24, 30))
        paste(f, dark, (192, 0))
        gif.append(up(f, 4).convert("P", palette=Image.ADAPTIVE, colors=255))
    gif[0].save(os.path.join(ENV, "stage4_a3_flames_preview.gif"), save_all=True, append_images=gif[1:],
                duration=140, loop=0, disposal=2, optimize=False)
    return out


def preview_altar(res):
    grass = ground_tiles(GRASS, 23, 5, 3)
    sc = grass.copy()
    paste(sc, load("altar_v04.png"), (6, 9))
    x = 62
    for cand in ("candA", "candB"):
        lit, unlit = res[cand][0], res[cand][1]
        paste(sc, lit, (x, 2))
        paste(sc, unlit, (x + 60, 2))
        x += 122
    sc = sc.crop((0, 0, x + 2, sc.height))
    t = ("altar_v04 (now) | candA lit, unlit (pedestal step, gold corner candlesticks, ivory cloth with gold trim) | "
         "candB lit, unlit (pedestal step, two tall gold lamp stands, gilded face rim)")
    sheet = titled([(t, sc)], k=4, title_size=14)
    out = board(sheet.width, sheet.height + sc.height + 30)
    paste(out, sheet, (0, 0))
    label(out, (12, sheet.height), "1x", 13)
    paste(out, sc, (12, sheet.height + 18))
    return out


def preview_entrance(full, decals):
    W, H = 14, 7
    ash = ground_tiles(ASH, W, H, 5)
    grass = ground_tiles(GRASS, W, H, 6)
    before = ash.copy()
    paste(before, load("dungeon_entrance_v02.png"), (24 + 40, 12 + 30))
    after = ash.copy()
    # grass on the left third with ash creep at the edge, to show the non-cell-locked decals
    paste(after, grass.crop((0, 0, 48, H * 16)), (0, 0))
    rnd = random.Random(4)
    paste(after, full, (40, 30))
    by_kind = {}
    for kind, im in decals:
        by_kind.setdefault(kind, []).append(im)
    spots = [("ash", 38, 10), ("ash", 44, 40), ("ash", 36, 78), ("ash", 42, 98), ("ash", 30, 56),
             ("crack", 150, 8), ("crack", 196, 22), ("crack", 66, 6), ("crack", 182, 90), ("crack", 100, 102),
             ("vein", 120, 16), ("vein", 206, 70), ("vein", 60, 100),
             ("rubble", 168, 104), ("rubble", 210, 44)]
    for kind, x, y in spots:
        paste(after, rnd.choice(by_kind[kind]), (x, y))
    for im, (x, y) in zip([load(f"decal_bone_{i}_v01.png") for i in (1, 2, 3)] +
                          [load(f"decal_mould_{i}_v01.png") for i in (1, 2)],
                          ((140, 20), (190, 104), (76, 90), (212, 12), (130, 96))):
        paste(after, im, (x, y))
    dsheet = row([im for _, im in decals], 4, bg=(107, 94, 79, 255))
    dgrass = ground_tiles(GRASS, 6, 2, 2)
    xx = 3
    for kind, im in decals:
        if kind in ("ash", "rubble"):
            paste(dgrass, im, (xx, 6))
            xx += im.width + 4
    sheet = titled([
        ("dungeon_entrance_v02 now (ash ground)", before),
        ("with stairs overlay + debris ring (dungeon_entrance_set_v01), scattered decals; grass edge on the left with ash creep",
         after),
        ("new decals on ash: crack 1-4, vein 1-3, ash creep 1-3, rubble 1-4", dsheet),
        ("ash creep and rubble on grass (for the grass side of the boundary)", dgrass.crop((0, 0, max(xx, 16), 32))),
    ], k=4, title_size=14)
    return sheet, after


def preview_build(sets):
    sheets = [("build_stone_candA_v01 (layout: see 04-env/prompts.md)",
               build_sheet(sets["stone"])),
              ("build_wood_candB_v01 (same layout)", build_sheet(sets["wood"]))]
    a = titled(sheets, k=4)
    b = build_preview(sets, None)
    out = board(max(a.width, b.width), a.height + b.height)
    paste(out, b, (0, 0))
    paste(out, a, (0, b.height))
    return out


# ---- checks -------------------------------------------------------------------------
REF_FILES = ["altar_v04.png", "altar_v04_unlit.png", "relic_bench_v02.png", "tiles_dungeon_v02.png",
             "tiles_dungeon_v02_var.png", "dungeon_entrance_v02.png", "heretic_shrine_v02.png",
             "tiles_grass-corruption_v05.png", "tiles_ash_plain_1_v01.png", "decal_bone_1_v01.png",
             "decal_mould_1_v01.png", "alchemy_table_v05.png", "items_v04_strip.png", "crops_v03_sheet.png"]
BRIEF4 = ["1a1714", "2e2a26", "4a423a", "6b5e4f", "8c7b66", "f4c95d", "c9932b", "9c6a1f", "efe3c6", "6f5522",
          "3b1f4d", "5e2d7a", "8a5fb0", "6f8f3a", "d8d2c0", "2a0808", "5c1010", "8f1a1a", "c8321f", "ff7a1a"]


def colours(im):
    return {p[:3] for p in im.getdata() if p[3]}


def check(outputs):
    allowed = set()
    for f in REF_FILES:
        allowed |= colours(load(f))
    allowed |= {hx(c)[:3] for c in BRIEF4}
    lines = []
    ok = True
    for name in outputs:
        im = load(name)
        cs = colours(im)
        if name.endswith("_emissive.png"):
            lines.append(f"{name:44s} mask, {len(cs)} grey levels")
            continue
        extra = cs - allowed
        top = max((lum(c) for c in cs), default=0)
        cool = [c for c in cs if c[2] > c[0] + 5 and sum(c) < 200 and c not in (VI1[:3], VI2[:3])]
        lines.append(f"{name:44s} {im.width}x{im.height} colours={len(cs):3d} max_lum={top:5.1f} "
                     f"outside_palette={len(extra)} cool_dark={len(cool)}")
        if extra:
            ok = False
            lines.append("    outside: " + " ".join('#%02x%02x%02x' % c for c in sorted(extra)))
    return ok, lines


OUTPUTS = [
    "wall_crack_top_v01.png", "wall_crack_face_v01.png",
    "flame_small_v01.png", "flame_small_v01_emissive.png", "flame_large_v01.png", "flame_large_v01_emissive.png",
    "flame_heretic_small_candA_v01.png", "flame_heretic_small_candA_v01_emissive.png",
    "flame_heretic_small_candB_v01.png", "flame_heretic_small_candB_v01_emissive.png",
    "flame_heretic_large_candA_v01.png", "flame_heretic_large_candA_v01_emissive.png",
    "flame_heretic_large_candB_v01.png", "flame_heretic_large_candB_v01_emissive.png",
    "build_stone_candA_v01.png", "build_wood_candB_v01.png",
    "altar_up1_candA_v01.png", "altar_up1_candA_v01_unlit.png", "altar_up1_candA_v01_litbase.png",
    "altar_up1_candA_v01_emissive.png",
    "altar_up1_candB_v01.png", "altar_up1_candB_v01_unlit.png", "altar_up1_candB_v01_litbase.png",
    "altar_up1_candB_v01_emissive.png", "altar_v04_litbase.png",
    "dungeon_entrance_stairs_v01.png", "dungeon_entrance_debris_v01.png", "dungeon_entrance_set_v01.png",
] + [f"decal_crack_{i}_v01.png" for i in range(1, 5)] + [f"decal_vein_{i}_v01.png" for i in range(1, 4)] \
  + [f"decal_ashcreep_{i}_v01.png" for i in range(1, 4)] + [f"decal_rubble_{i}_v01.png" for i in range(1, 5)]


def main(what):
    if what in ("all",):
        fl = make_flames()
        tops, faces = make_cracks()
        sets = make_build()
        res = make_altar()
        stairs, ring, full = make_entrance()
        decals = make_decals()
        save(preview_cracks_full(tops, faces), "stage4_a3_cracks_preview.png")
        save(preview_flames(fl, res), "stage4_a3_flames_preview.png")
        save(preview_build(sets), "stage4_a3_build_preview.png")
        save(preview_altar(res), "stage4_a3_altar_preview.png")
        sheet, after = preview_entrance(full, decals)
        save(sheet, "stage4_a3_entrance_preview.png")
        save(after, "stage4_a3_entrance_preview_1x.png")
    if what in ("all", "check"):
        ok, lines = check(OUTPUTS)
        print("\n".join(lines))
        print("palette check:", "OK" if ok else "FAIL")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "all")

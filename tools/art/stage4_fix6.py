# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""4단계 검토 뒤 고침 (s4, 2026-10-22, 생성 없음, 무료). 손질 2 검토에서 맞다고 본 것만 고친다.
기록: assets/concept/04-env/prompts.md "## 본 제작 손질 2" ### 검토 뒤 고침 (s4).

Run (paths are relative to this file, any cwd):
  uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I \
      tools/art/stage4_fix6.py [all|props|boards|compare|rules|check]

  props    prop_barrel_a_v04 / prop_barrel_b_v04 / prop_sack_a_v04: the s1 v03 files with two body-only rows
           deleted (the inverse of s2's row insertion), so they are no taller than the shared storage chest (19).
           prop_{rubble,pillar_stub,stalagmite}_*_v04: s2's lift (same target luma as v03) done in CIELAB L* only,
           keeping the a*/b* of v02, so the brightening no longer raises the chroma; same contact shadow as v03.
  boards   stage4_mockup_v06_day / _eve (v05 layout, barrel a / sack a v04) and stage4_dungeon_v07 (v06 layout,
           barrel b v04, dungeon props v04), through stage4_mockup.SWAP. Everything else is the s3 board.
  compare  stage4_s4_compare.png (3x, Pillow's bundled font): character, storage chest, barrels / sack v02 -> v03 -> v04
           on grass; the eight dungeon props v02 -> v03 -> v04 on the dungeon floor.
  rules    brief sec.5.7 hand-fix rule check of the s4 files (stage4_mockup.rules).
  check    numbers for the record: heights against the character's body rows and the chest, board tops,
           dungeon chroma, door sizes, the ground lantern's open panes, outline ratio without the baked shadow.
  all      props, boards, compare (not rules / check)

Inputs are only our own stage-4 files (04-env) and 03-pixel base_body_v02_walk.png. Old files are never
overwritten (save() only accepts the names above). No randomness: re-running reproduces every file byte for byte.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import stage4_fix5 as f5        # noqa: E402  (s2: lift rule, contact shadow, door grids)
import stage4_mockup as sm      # noqa: E402  (s3: boards, scale sheet, rule check)

ENV = sm.ENV
OUT = (0x1A, 0x17, 0x14)

SHORTEN = {   # s1 v03 file -> rows deleted (body-only rows; checked in shorten())
    "prop_barrel_a": (13, 14),    # middle stave band y12-15 -> y12, y15 (21 -> 19 = chest)
    "prop_barrel_b": (13, 14),    # middle stave band y12-16 -> y12, y15, y16 (20 -> 18)
    "prop_sack_a": (13, 14),      # sack body y10-19 (20 -> 18 = top of the s1 sack target 12-18)
}
DUNGEON = f5.DUNGEON_PROPS
OWN = ({f"{n}_v04.png" for n in SHORTEN} | {f"prop_{n}_v04.png" for n in DUNGEON}
       | {f"{b}{s}.png" for b in ("stage4_mockup_v06_day", "stage4_mockup_v06_eve", "stage4_dungeon_v07") for s in ("", "_1x")}
       | {"stage4_s4_compare.png"})


def save(im, name):
    assert name in OWN, name
    im.save(os.path.join(ENV, name))
    print("wrote", name, im.size)


def load(name, d=ENV):
    return Image.open(os.path.join(d, name)).convert("RGBA")


def opaque_height(im):
    ys = np.nonzero(np.asarray(im)[..., 3].any(axis=1))[0]
    return int(ys[-1] - ys[0] + 1)


# =====================================================================================
# props: shorter barrels / sack, dungeon props lifted in L* only
# =====================================================================================
def shorten(im, rows):
    """Delete `rows`; everything above moves down, the foot row stays. Each deleted row must be body only:
    the same opaque span as the nearest kept row above it, and #1a1714 only at its two ends (no hoop / tie)."""
    a = np.array(im)
    op = a[..., 3] > 0
    span = lambda y: (int(np.nonzero(op[y])[0].min()), int(np.nonzero(op[y])[0].max()))
    for y in rows:
        above = max(r for r in range(y) if r not in rows)
        assert span(y) == span(above), (y, span(y), above, span(above))
        x0, x1 = span(y)
        inner = a[y, x0 + 1:x1]
        assert not ((inner[:, 0] == 0x1A) & (inner[:, 1] == 0x17) & (inner[:, 2] == 0x14)).any(), y
    keep = [y for y in range(a.shape[0]) if y not in rows]
    out = np.zeros_like(a)
    out[len(rows):] = a[keep]
    return Image.fromarray(out)


def _lin(v):
    v /= 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def _gam(v):
    v = min(1.0, max(0.0, v))
    return 255.0 * (12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055)


_WP = (0.95047, 1.0, 1.08883)
_M = ((0.4124564, 0.3575761, 0.1804375), (0.2126729, 0.7151522, 0.0721750), (0.0193339, 0.1191920, 0.9503041))
_MI = ((3.2404542, -1.5371385, -0.4985314), (-0.9692660, 1.8760108, 0.0415560), (0.0556434, -0.2040259, 1.0572252))


def lab(c):
    r, g, b = (_lin(float(v)) for v in c[:3])
    xyz = [(m[0] * r + m[1] * g + m[2] * b) / w for m, w in zip(_M, _WP)]
    f = [t ** (1 / 3) if t > (6 / 29) ** 3 else t / (3 * (6 / 29) ** 2) + 4 / 29 for t in xyz]
    return 116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])


def lab_rgb(L, A, B):
    fy = (L + 16) / 116
    fx, fz = fy + A / 500, fy - B / 200
    inv = lambda t: t ** 3 if t > 6 / 29 else 3 * (6 / 29) ** 2 * (t - 4 / 29)
    x, y, z = inv(fx) * _WP[0], inv(fy) * _WP[1], inv(fz) * _WP[2]
    return tuple(_gam(m[0] * x + m[1] * y + m[2] * z) for m in _MI)


def lift_lstar(c):
    """s2's lift (luma L -> L + (215 - L) * 0.30 from luma 60 up) reached by raising CIELAB L* only."""
    L0 = f5.luma(c)
    if L0 < f5.LIFT_FROM:
        return tuple(c[:3]) + (255,)
    target = min(215.0, L0 + (215.0 - L0) * f5.LIFT_K)
    Ls, A, B = lab(c)
    lo, hi = Ls, 100.0
    for _ in range(60):
        mid = (lo + hi) / 2
        if f5.luma(lab_rgb(mid, A, B)) < target:
            lo = mid
        else:
            hi = mid
    best = None
    for Lx in (lo, hi):        # round to the 8-bit colour whose luma is closest to the target
        rgb = tuple(int(v + 0.5) for v in lab_rgb(Lx, A, B))
        d = abs(f5.luma(rgb) - target)
        if best is None or d < best[0]:
            best = (d, rgb)
    return best[1] + (255,)


def props():
    for base, rows in SHORTEN.items():
        im = shorten(load(f"{base}_v03.png"), rows)
        save(im, f"{base}_v04.png")
        print(f"  {base}: v03 {opaque_height(load(f'{base}_v03.png'))} -> v04 {opaque_height(im)}")
    for n in DUNGEON:
        src = load(f"prop_{n}_v02.png")
        table = {c + (255,): lift_lstar(c) for c in f5.colours(src) if c != OUT}
        out = f5.recolour(src, table)
        out, k = f5.contact_shadow(out)
        save(out, f"prop_{n}_v04.png")
        v3 = load(f"prop_{n}_v03.png")
        same_alpha = (np.asarray(v3)[..., 3] == np.asarray(out)[..., 3]).all()
        print(f"  {n}: {len(f5.colours(out))} colours, shadow {k} px, alpha mask = v03: {same_alpha}")


# =====================================================================================
# boards and compare sheet
# =====================================================================================
BOARD_SWAP = {"prop_barrel_a_v03.png": "prop_barrel_a_v04.png", "prop_sack_a_v03.png": "prop_sack_a_v04.png",
              "prop_barrel_b_v03.png": "prop_barrel_b_v04.png"}
BOARD_SWAP.update({f"prop_{n}_v03.png": f"prop_{n}_v04.png" for n in DUNGEON})


def boards():
    sm.SWAP.clear()
    sm.SWAP.update(BOARD_SWAP)
    sm.save = save              # same writer, but only the s4 names are accepted
    try:
        sm.surface5("stage4_mockup_v06_day", "stage4_mockup_v06_eve")
        sm.dungeon6("stage4_dungeon_v07")
    finally:
        sm.SWAP.clear()


S4_ROWS = [
    ("grass", [("char",), ("storage_chest_v02",),
               ("prop_barrel_a_v02", "prop_barrel_a_v03", "prop_barrel_a_v04"),
               ("prop_barrel_b_v02", "prop_barrel_b_v03", "prop_barrel_b_v04"),
               ("prop_sack_a_v02", "prop_sack_a_v03", "prop_sack_a_v04"),
               ("prop_crate_a_v03",), ("prop_jar_clay_v03",), ("prop_lantern_ground_v03",), ("char",)]),
    ("dungeon", [("char",)] + [(f"prop_{n}_v02", f"prop_{n}_v03", f"prop_{n}_v04") for n in DUNGEON] + [("char",)]),
]
S4_HEAD = ("s4 fix, 3x: v02 -> v03 -> v04 in each group. Gold dashes = character 28 px, ivory = shared storage chest "
           "19 px, brown = character shoulders 13 px. Numbers = version and opaque height of the file in px.")
S4_GUIDES = ((None, (244, 201, 93)), (19, (239, 227, 198)), (13, (164, 123, 85)))


def compare():
    sm.save = save
    sm.scale_compare(S4_ROWS, "stage4_s4_compare.png", S4_HEAD, S4_GUIDES)


def s4_files():
    return sorted([f"{n}_v04.png" for n in SHORTEN] + [f"prop_{n}_v04.png" for n in DUNGEON])


def rules():
    return sm.rules(s4_files())


# =====================================================================================
# check: numbers for the record
# =====================================================================================
LEVELS = [(11, "몸통·허리"), (13, "어깨"), (14, "목(옷깃)"), (17, "턱·얼굴 아래"), (21, "눈 높이"), (28, "머리카락")]
CHEST = 19


def level(h):
    return next(name for top, name in LEVELS if h <= top)


def chroma_stats(name):
    a = np.asarray(load(name))
    cs, hs, ls = [], [], []
    for c in a[a[..., 3] > 0][:, :3]:
        t = tuple(int(v) for v in c)
        if t in (OUT, f5.SHADOW[:3]):
            continue
        L, A, B = lab(t)
        cs.append(math.hypot(A, B))
        hs.append(math.degrees(math.atan2(B, A)))
        ls.append(f5.luma(t))
    return sum(cs) / len(cs), sum(hs) / len(hs), sum(ls) / len(ls)


def outline_pct(im, ignore=()):
    a = np.asarray(im)
    op = a[..., 3] > 0
    for c in ignore:
        op &= ~((a[..., 0] == c[0]) & (a[..., 1] == c[1]) & (a[..., 2] == c[2]))
    pad = np.pad(op, 1)
    edge = op & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    is_out = (a[..., 0] == 0x1A) & (a[..., 1] == 0x17) & (a[..., 2] == 0x14)
    return 100.0 * (edge & is_out).sum() / max(edge.sum(), 1)


def enclosed_transparent(im):
    """transparent pixels not reachable from the canvas border (4-neighbour flood fill)"""
    a = np.asarray(im)[..., 3] == 0
    h, w = a.shape
    seen = np.zeros_like(a)
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if 0 <= x < w and 0 <= y < h and a[y, x] and not seen[y, x]:
            seen[y, x] = True
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return sorted((int(x), int(y)) for y, x in zip(*np.nonzero(a & ~seen)))


def check():
    walk = load("base_body_v02_walk.png", sm.PIX).crop((0, 0, 32, 32))
    op = np.asarray(walk)[..., 3] > 0
    ys = np.nonzero(op.any(axis=1))[0]
    char_h = int(ys[-1] - ys[0] + 1)
    print(f"character (base body walk v02 S frame 0): {char_h} px; row widths from the feet:")
    for y in range(ys[-1], ys[0] - 1, -1):
        xs = np.nonzero(op[y])[0]
        print(f"  h{ys[-1] - y + 1:2d} (y{y}) width {len(xs):2d}  -> {level(ys[-1] - y + 1)}")
    print("\nprops: height, % of character, body level reached, against the storage chest (19)")
    names = ["storage_chest_v02", "prop_barrel_a_v03", "prop_barrel_a_v04", "prop_barrel_b_v03", "prop_barrel_b_v04",
             "prop_barrel_c_v03", "prop_barrel_tipped_v03", "prop_crate_a_v03", "prop_crate_smashed_v03",
             "prop_sack_a_v03", "prop_sack_a_v04", "prop_sack_b_v03", "prop_sack_small_v03", "prop_jar_clay_v03",
             "prop_pottery_broken_v03", "prop_lantern_ground_v03", "prop_offering_bowl_v03", "prop_candles_black_a_v03",
             "prop_candles_black_b_v04", "prop_skull_pile_v03", "prop_brazier_dark_c_v03", "prop_bone_cage_v03"]
    for n in names:
        h = opaque_height(load(f"{n}.png"))
        cmp_ = "=" if h == CHEST else (">" if h > CHEST else "<")
        print(f"  {n:28s} {h:2d}  {100 * h / char_h:3.0f}%  {level(h):8s} chest {cmp_} ({h - CHEST:+d})")
    print("\nday boards next to the chest (top = foot - height; chest foot 118):")
    for tag, files in (("v05", ("prop_barrel_a_v03", "prop_sack_a_v03")), ("v06", ("prop_barrel_a_v04", "prop_sack_a_v04"))):
        tops = {"chest": 118 - opaque_height(load("storage_chest_v02.png"))}
        tops.update({files[0]: 117 - opaque_height(load(f"{files[0]}.png")),
                     files[1]: 119 - opaque_height(load(f"{files[1]}.png"))})
        print(f"  {tag}: {tops}")
    for a_, b_ in (("stage4_mockup_v05_day_1x", "stage4_mockup_v06_day_1x"), ("stage4_mockup_v05_eve_1x", "stage4_mockup_v06_eve_1x"),
                   ("stage4_dungeon_v06_1x", "stage4_dungeon_v07_1x")):
        d = (np.asarray(load(f"{a_}.png")) != np.asarray(load(f"{b_}.png"))).any(axis=2)
        yy, xx = np.nonzero(d)
        print(f"  {a_} -> {b_}: {int(d.sum())} px differ, box x{xx.min()}-{xx.max()} y{yy.min()}-{yy.max()}")
    print("\ndungeon props: mean CIELAB chroma / hue / mean luma (outline and baked shadow left out)")
    print("  sec.4 base greys:", ", ".join(f"#{s} C {math.hypot(*lab(f5.hx(s))[1:]):.1f}" for s in ("4a423a", "6b5e4f", "8c7b66")))
    fl = load("tiles_dungeon_v02.png").crop((32, 32, 48, 48))
    for n in DUNGEON:
        row = [chroma_stats(f"prop_{n}_{v}.png") for v in ("v02", "v03", "v04")]
        v4 = load(f"prop_{n}_v04.png")
        print(f"  {n:14s} C " + " -> ".join(f"{c:4.1f}" for c, _, _ in row)
              + "  hue " + " -> ".join(f"{h:4.1f}" for _, h, _ in row)
              + "  luma " + " -> ".join(f"{lu:5.1f}" for _, _, lu in row)
              + f"  outline {outline_pct(v4):.0f}% (without shadow {outline_pct(v4, [f5.SHADOW[:3]]):.0f}%)")
    a = np.asarray(fl)
    cs = [math.hypot(*lab(tuple(int(v) for v in c))[1:]) for c in a.reshape(-1, 4)[:, :3]]
    print(f"  floor tile (tiles_dungeon_v02 inner) mean C {sum(cs) / len(cs):.1f}")
    print("\nbuilt-wall doors (stage4_fix5.DOORS, tile 16 x 24):")
    for mat in ("stone", "wood"):
        closed, opened = f5.DOORS[mat]
        leaf = [x for x in range(16) if closed[12][x] not in ".oKP"]
        passage_rows = [y for y, r in enumerate(opened) if "w" in r or "f" in r]
        passage_w = max(r.count("w") + r.count("f") for r in opened)
        top = min(y for y, r in enumerate(closed) if r.strip("."))
        print(f"  {mat}: leaf x{leaf[0]}-{leaf[-1]} = {len(leaf)} px, open passage {passage_w} px wide, "
              f"rows {passage_rows[0]}-{passage_rows[-1]} = {len(passage_rows)} px tall, door top row {top} -> threshold row 22 "
              f"= {22 - top + 1} px")
    enc = enclosed_transparent(load("prop_lantern_ground_v03.png"))
    print(f"\nprop_lantern_ground_v03 (unlit): {len(enc)} enclosed transparent px: {enc}")


def main(what):
    try:
        sys.stdout.reconfigure(encoding="utf-8")     # Korean level names on a cp949 console / pipe
    except (AttributeError, ValueError):
        pass
    if what in ("props", "all"):
        props()
    if what in ("boards", "all"):
        boards()
    if what in ("compare", "all"):
        compare()
    if what == "rules":
        rules()
    if what == "check":
        check()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "all")

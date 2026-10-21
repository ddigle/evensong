# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""4단계 본 제작 손질 (밤 작업 a1): 흙길 타일, 기본 작업대·모루·공유 창고, 보스 기둥 후보. Free, no generation.
기록: assets/concept/04-env/prompts.md "본 제작 (2026-10-21 밤)" 1절.

Run (paths are relative to this file, any cwd):
    uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I \
        tools/art/stage4_path_objects.py path [--base RRGGBB]
    ... stage4_path_objects.py objects
    ... stage4_path_objects.py preview

path     tiles_grass-path_v01.png (raw, tileset cace8d41) -> tiles_grass-path_v02.png
         + interior variants tiles_path_var_1..3_v01.png
objects  *_v01_<pick>.png (raw map objects) -> *_v02.png (warm greys, #1a1714 outline, colour count,
         highlights <= 215)
preview  stage4_a1_preview_v01.png (4x) next to the existing stage-4 tiles and objects
"""
import colorsys
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
ENV = os.path.join(ROOT, 'assets', 'concept', '04-env')
sys.path.insert(0, HERE)
from regrass import regrass, delavender  # noqa: E402

OUTLINE = (0x1a, 0x17, 0x14)


def hexrgb(v):
    return (v >> 16) & 255, (v >> 8) & 255, v & 255


def keyof(a):
    a = a.astype(np.uint32)
    return (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]


def hls_shift(v, deg):
    """Same rule and rounding as regrass._selftest: HLS hue + deg, lightness and saturation kept."""
    r, g, b = (c / 255 for c in hexrgb(v))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb((h + deg / 360) % 1, l, s)
    return (int(round(r * 255)) << 16) | (int(round(g * 255)) << 8) | int(round(b * 255))


def hls(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h / 360, l, s)
    return (int(round(r * 255)) << 16) | (int(round(g * 255)) << 8) | int(round(b * 255))


def remap(a, table, mask=None):
    """Exact colour replace on opaque pixels (masks from the original keys, no chaining)."""
    k = keyof(a[..., :3])
    region = a[..., 3] > 0
    if mask is not None:
        region &= mask
    hits = {}
    for src, dst in table.items():
        m = (k == src) & region
        if m.any():
            a[m, 0], a[m, 1], a[m, 2] = hexrgb(dst)
            hits[src] = int(m.sum())
    return hits


# ---------------------------------------------------------------- path tileset
# Greens on the grass side of the new grass<->path edge that are not in regrass GRASS_LUT. Same +15 deg rule
# as regrass (brief sec.4: "남은 옛 초록을 찾아 표에 더하고"). Kept in this file so tools/art/regrass.py
# stays untouched by parallel agents; the integrator may merge it into regrass as PATH_EDGE_LUT.
PATH_EDGE_GREENS = [0x8aa568, 0x7b9762, 0x6e8260, 0x7f8768, 0x6b7160, 0xcfe38f]
# Grey edge teeth (one cool, h274): warm dark greens on the same lightness, hue of the regrassed tufts.
PATH_EDGE_DARKS = {0x60605f: hls(100, 0.37, 0.22), 0x4d4950: hls(100, 0.29, 0.26)}
# Raw path colours (flood region from the path base only, so grass flowers of the same colour stay).
PATH_SRC = [0xf3cda1, 0xfbddb8, 0xd6b095, 0x8e7f7e]


def path_palette(base):
    """Packed-earth ramp derived from one base colour (HLS)."""
    r, g, b = (c / 255 for c in hexrgb(base))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    h *= 360
    return {
        'base': base,
        'light': hls(h + 2, min(l + 0.08, 0.80), s * 0.95),   # pebble top
        'shade': hls(h - 3, l - 0.10, s * 0.95),              # pebble underside, lip under the grass
        'dark': hls(h - 5, l - 0.20, s * 0.90),               # crumbs, deepest lip
    }


def flood(mask_ok, seeds):
    out = np.zeros_like(mask_ok)
    stack = list(zip(*np.where(seeds)))
    h, w = mask_ok.shape
    while stack:
        y, x = stack.pop()
        if out[y, x] or not mask_ok[y, x]:
            continue
        out[y, x] = True
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < h and 0 <= xx < w and not out[yy, xx] and mask_ok[yy, xx]:
                stack.append((yy, xx))
    return out


def scatter(a, pal, x0, y0, rng, n):
    """Pebbles and crumbs inside one 16px tile on clean path base only, 1px away from the tile border."""
    base = pal['base']
    k = keyof(a[..., :3])
    placed = 0
    tries = 0
    while placed < n and tries < 400:
        tries += 1
        x, y = x0 + rng.randint(1, 13), y0 + rng.randint(1, 12)
        kind = rng.choice(['p1', 'p1', 'p2', 'crumb'])
        cells = [(x - 1 + i, y - 1 + j) for i in range(4) for j in range(4)]
        if any(not (x0 <= cx < x0 + 16 and y0 <= cy < y0 + 16) or k[cy, cx] != base for cx, cy in cells):
            continue
        if kind == 'p1':
            a[y, x, :3] = hexrgb(pal['light'])
            a[y + 1, x, :3] = hexrgb(pal['shade'])
        elif kind == 'p2':
            a[y, x, :3] = hexrgb(pal['light'])
            a[y, x + 1, :3] = hexrgb(pal['light'])
            a[y + 1, x, :3] = hexrgb(pal['shade'])
            a[y + 1, x + 1, :3] = hexrgb(pal['shade'])
        else:
            a[y, x, :3] = hexrgb(pal['dark'])
        k = keyof(a[..., :3])
        placed += 1
    return placed


def do_path(base_hex):
    raw = Image.open(os.path.join(ENV, 'tiles_grass-path_v01.png')).convert('RGBA')
    img = regrass(raw)                                            # 8 grass greens, exact +15 deg
    img = delavender(img, box=(0, 48, 16, 64))                   # 2 lavender px in the all-grass tile
    a = np.array(img)
    log = {}
    edge = {g: hls_shift(g, 15) for g in PATH_EDGE_GREENS}
    log['edge greens +15'] = remap(a, edge)
    log['edge darks'] = remap(a, PATH_EDGE_DARKS)
    pal = path_palette(int(base_hex, 16))
    k = keyof(a[..., :3])
    ok = np.isin(k, PATH_SRC)
    region = flood(ok, k == 0xf3cda1)
    log['path px'] = int(region.sum())
    log['path'] = remap(a, {0xf3cda1: pal['base'], 0xfbddb8: pal['base'],   # grid pebbles removed
                            0xd6b095: pal['shade'], 0x8e7f7e: pal['dark']}, region)
    rng = random.Random(20261021)
    base = pal['base']
    for ty in range(4):
        for tx in range(4):
            x0, y0 = tx * 16, ty * 16
            nb = int((keyof(a[y0:y0 + 16, x0:x0 + 16, :3]) == base).sum())
            scatter(a, pal, x0, y0, rng, round(nb / 70))
    out = Image.fromarray(a)
    out.save(os.path.join(ENV, 'tiles_grass-path_v02.png'))
    # interior variants from the all-path tile (32,16): same border pixels, new scatter inside
    interior = np.array(out)[16:32, 32:48].copy()
    clean = interior.copy()
    kk = keyof(clean[..., :3])
    for src in (pal['light'], pal['shade'], pal['dark']):
        m = kk == src
        clean[m, 0], clean[m, 1], clean[m, 2] = hexrgb(base)
    for i, n in enumerate((2, 4, 5), 1):
        v = clean.copy()
        scatter(v, pal, 0, 0, random.Random(1000 + i), n)
        Image.fromarray(v).save(os.path.join(ENV, 'tiles_path_var_%d_v01.png' % i))
    print('palette', {k2: '#%06x' % v2 for k2, v2 in pal.items()})
    print('edge greens', {'#%06x' % s: '#%06x' % d for s, d in edge.items()})
    print('edge darks', {'#%06x' % s: '#%06x' % d for s, d in PATH_EDGE_DARKS.items()})
    for k2, v2 in log.items():
        print(k2, v2 if not isinstance(v2, dict) else {'#%06x' % s: n for s, n in v2.items()})
    ncol = len(np.unique(keyof(np.array(out)[..., :3])))
    print('tiles_grass-path_v02.png colours', ncol)


# ---------------------------------------------------------------- objects
def luma(rgb):
    rgb = np.asarray(rgb, float)
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def hls_arr(a):
    """Per-pixel HLS of an HxWx(3|4) uint8 array -> (h deg, l, s) float arrays."""
    rgb = a[..., :3].astype(float) / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    l = (mx + mn) / 2
    d = mx - mn
    s = np.where(d == 0, 0, d / np.where(l < 0.5, mx + mn, 2 - mx - mn + 1e-9))
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(l)
    nz = d > 0
    rc = np.where(nz, (mx - r) / np.where(nz, d, 1), 0)
    gc = np.where(nz, (mx - g) / np.where(nz, d, 1), 0)
    bc = np.where(nz, (mx - b) / np.where(nz, d, 1), 0)
    h = np.where(r == mx, bc - gc, np.where(g == mx, 2 + rc - bc, 4 + gc - rc))
    h = np.where(nz, (h / 6) % 1, 0) * 360
    return h, l, s


def set_hls(a, m, h, l, s):
    for y, x in zip(*np.where(m)):
        r, g, b = colorsys.hls_to_rgb((h[y, x] % 360) / 360, float(l[y, x]), float(s[y, x]))
        a[y, x, :3] = (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))


def grey_for_luma(Y, h=31, s=0.14):
    """Warm grey (hue h, HLS saturation s) whose Rec.601 luma is Y."""
    lo, hi = 0.0, 1.0
    for _ in range(30):
        mid = (lo + hi) / 2
        r, g, b = colorsys.hls_to_rgb(h / 360, mid, s)
        if 0.299 * r * 255 + 0.587 * g * 255 + 0.114 * b * 255 < Y:
            lo = mid
        else:
            hi = mid
    r, g, b = colorsys.hls_to_rgb(h / 360, lo, s)
    return int(round(r * 255)), int(round(g * 255)), int(round(b * 255))


def warm_cool_greys(a, region=None, h_to=28, s_to=0.09):
    """Blue / violet / neutral greys -> warm greys of the same luma (brief sec.5.7 손질 규칙)."""
    h, l, s = hls_arr(a)
    op = a[..., 3] > 0
    cool = op & (((h >= 180) & (h <= 335) & (s <= 0.45)) | (s < 0.05))
    cool &= luma(a[..., :3]) > 30           # near-black is handled by the outline pass
    if region is not None:
        cool &= region
    for y, x in zip(*np.where(cool)):
        a[y, x, :3] = grey_for_luma(luma(a[y, x, :3]), h_to, s_to)
    return int(cool.sum())


def clamp_luma(a, ymax=215):
    """Highlights brighter than ymax are darkened (HLS lightness only) so the altar flame (246) stays brightest."""
    n = 0
    for y, x in zip(*np.where((a[..., 3] > 0) & (luma(a[..., :3]) > ymax))):
        r, g, b = (c / 255 for c in a[y, x, :3])
        hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
        while ll > 0:
            ll -= 0.005
            rr, gg, bb = colorsys.hls_to_rgb(hh, ll, ss)
            if 0.299 * rr * 255 + 0.587 * gg * 255 + 0.114 * bb * 255 <= ymax:
                break
        a[y, x, :3] = (int(rr * 255), int(gg * 255), int(bb * 255))
        n += 1
    return n


def outline(a, dark_y=75, black_y=42):
    """#1a1714 outline: near-black lines -> #1a1714; outermost pixels that are already dark are recoloured,
    outermost light pixels get a new outline pixel outside them (no detail lost)."""
    op = a[..., 3] > 0
    Y = luma(a[..., :3])
    blk = op & (Y < black_y)
    a[blk, :3] = OUTLINE
    hgt, wid = op.shape
    pad = np.pad(op, 1)
    edge = op & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    Y = luma(a[..., :3])
    a[edge & (Y < dark_y), :3] = OUTLINE
    light_edge = edge & (Y >= dark_y)
    add = np.zeros_like(op)
    for y, x in zip(*np.where(light_edge)):
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < hgt and 0 <= xx < wid and not op[yy, xx]:
                add[yy, xx] = True
    a[add, :3] = OUTLINE
    a[add, 3] = 255
    a[op, 3] = 255                           # no half-transparent pixels
    return int(blk.sum()), int((edge & (Y < dark_y)).sum()), int(add.sum())


def despeckle(a, min_size):
    """Remove 8-connected opaque bits smaller than min_size px (left over after removing ground tufts)."""
    op = a[..., 3] > 0
    seen = np.zeros_like(op)
    hgt, wid = op.shape
    removed = 0
    for sy, sx in zip(*np.where(op)):
        if seen[sy, sx]:
            continue
        comp, stack = [], [(sy, sx)]
        seen[sy, sx] = True
        while stack:
            y, x = stack.pop()
            comp.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < hgt and 0 <= xx < wid and op[yy, xx] and not seen[yy, xx]:
                        seen[yy, xx] = True
                        stack.append((yy, xx))
        if len(comp) < min_size:
            for y, x in comp:
                a[y, x] = 0
            removed += len(comp)
    return removed


def _lab(rgb):
    c = np.asarray(rgb, float) / 255
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    xyz = c @ np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]]).T
    xyz /= np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def reduce_colours(a, n, keep=(0x1a1714,)):
    """Merge the closest pair (CIELAB) into the more frequent colour until <= n colours. keep never moves."""
    op = a[..., 3] > 0
    merged = 0
    while True:
        k = keyof(a[..., :3])[op]
        cols, cnt = np.unique(k, return_counts=True)
        if len(cols) <= n:
            return merged
        lab = _lab(np.stack([cols >> 16, (cols >> 8) & 255, cols & 255], -1))
        d = np.linalg.norm(lab[:, None] - lab[None], axis=-1)
        np.fill_diagonal(d, 1e9)
        for i, c in enumerate(cols):
            if c in keep:                    # the outline neither moves nor absorbs other colours
                d[i, :] = 1e9
                d[:, i] = 1e9
        i, j = np.unravel_index(np.argmin(d), d.shape)
        src, dst = (cols[i], cols[j]) if cnt[i] < cnt[j] else (cols[j], cols[i])
        full = keyof(a[..., :3])
        m = (full == src) & op
        a[m, 0], a[m, 1], a[m, 2] = hexrgb(int(dst))
        merged += 1


def ncolours(a):
    return len(np.unique(keyof(a[..., :3])[a[..., 3] > 0]))


def report(name, a, notes):
    Y = luma(a[..., :3])[a[..., 3] > 0]
    print('%-34s colours %2d  max luma %.0f  %s' % (name, ncolours(a), Y.max(), notes))


def fix_workbench():
    a = np.array(Image.open(os.path.join(ENV, 'workbench_v01_b.png')).convert('RGBA'))
    h, l, s = hls_arr(a)
    op = a[..., 3] > 0
    Y = luma(a[..., :3])
    # the yellow-gold coil ("curled shavings") and its olive shades -> pale wood shavings
    yellow = op & (h >= 36) & (h <= 58) & (s >= 0.28)
    ramp = [(180, 0xe2c49c), (140, 0xcaa275), (100, 0xa47b55), (0, 0x6e523f)]
    for y, x in zip(*np.where(yellow)):
        for t, c in ramp:
            if Y[y, x] >= t:
                a[y, x, :3] = hexrgb(c)
                break
    n_cool = warm_cool_greys(a)
    n_clamp = clamp_luma(a)
    ol = outline(a)
    # hand: a 1px stray beside the left leg
    a[21, 13] = 0
    a[21, 12, :3] = OUTLINE
    merged = reduce_colours(a, 20)
    Image.fromarray(a).save(os.path.join(ENV, 'workbench_v02.png'))
    report('workbench_v02.png', a, 'yellow->shavings %d, cool %d, clamp %d, outline %s, merged %d'
           % (int(yellow.sum()), n_cool, n_clamp, ol, merged))


def fix_anvil():
    a = np.array(Image.open(os.path.join(ENV, 'anvil_v01_b.png')).convert('RGBA'))
    h, l, s = hls_arr(a)
    op = a[..., 3] > 0
    rows = np.arange(a.shape[0])[:, None] * np.ones(a.shape[1], int)[None]
    # grass tufts at the foot of the stump: not part of the object
    green = op & (h >= 80) & (h <= 170) & (s >= 0.2)
    a[green] = 0
    op = a[..., 3] > 0
    # cool / violet ground bits around the roots (rows >= 24, outside the stump) -> removed
    h, l, s = hls_arr(a)
    roots = op & (rows >= 24) & (h >= 180) & (h <= 335)
    cols = np.arange(a.shape[1])[None] * np.ones(a.shape[0], int)[:, None]
    roots &= (cols <= 9) | (cols >= 25) | (rows >= 28)
    a[roots] = 0
    specks = despeckle(a, 4)
    op = a[..., 3] > 0
    h, l, s = hls_arr(a)
    Y = luma(a[..., :3])
    # anvil + tongs (rows < 16): orange "hot" top face and pink glints -> polished warm steel
    # (iron ramp of the stage-4 iron ore: #34302d #5e5953 #a39d92, shine #d2cbb8)
    top = op & (rows < 16) & ~((h >= 180) & (h <= 335)) & (s >= 0.12) & (Y >= 42)
    for y, x in zip(*np.where(top)):
        a[y, x, :3] = grey_for_luma(min(Y[y, x] + 10, 205), 32, 0.07)
    # iron body (rows < 16, the rest): violet near-black and blue greys -> warm iron, lifted so the body
    # keeps its form inside the #1a1714 outline (Y' = 22 + 0.9 Y)
    body = op & (rows < 16) & ~top
    for y, x in zip(*np.where(body)):
        a[y, x, :3] = grey_for_luma(22 + 0.9 * Y[y, x], 26, 0.08)
    # stump (rows >= 16): saturated red-orange wood and its wine-dark lines -> calmer warm brown
    # (hue 24, saturation x0.72); cool pixels left in the stump -> warm greys
    h, l, s = hls_arr(a)
    stump = (a[..., 3] > 0) & (rows >= 16) & ((h <= 40) | (h >= 330)) & (s >= 0.2)
    set_hls(a, stump, np.full_like(h, 24.0), l, s * 0.72)
    n_cool = warm_cool_greys(a, region=rows >= 16, h_to=26, s_to=0.08)
    n_clamp = clamp_luma(a)
    ol = outline(a, black_y=24)
    # hand: one root nub left at the stump's bottom-right corner
    a[27, 24, :3] = OUTLINE
    a[27, 25] = 0
    a[28, 24] = 0
    merged = reduce_colours(a, 20)
    Image.fromarray(a).save(os.path.join(ENV, 'anvil_v02.png'))
    report('anvil_v02.png', a, 'green %d, roots %d, specks %d, steel top %d, body %d, stump %d, cool %d, clamp %d, '
           'outline %s, merged %d' % (int(green.sum()), int(roots.sum()), specks, int(top.sum()), int(body.sum()),
                                      int(stump.sum()), n_cool, n_clamp, ol, merged))


def fix_chest():
    a = np.array(Image.open(os.path.join(ENV, 'storage_chest_v01_f.png')).convert('RGBA'))
    # neutral grey iron bands -> warm iron (same ramp family as the anvil)
    n_cool = warm_cool_greys(a, h_to=28, s_to=0.08)
    n_clamp = clamp_luma(a)
    ol = outline(a)
    merged = reduce_colours(a, 20)
    Image.fromarray(a).save(os.path.join(ENV, 'storage_chest_v02.png'))
    report('storage_chest_v02.png', a, 'cool %d, clamp %d, outline %s, merged %d' % (n_cool, n_clamp, ol, merged))


def fix_pillar():
    """Threat side (dungeon). Sandy tan stone -> the dungeon tile ramp (hue ~31, saturation ~0.14), by luma
    rank, a little lighter than the floor so it stands out; navy crack lines -> #1a1714."""
    a = np.array(Image.open(os.path.join(ENV, 'boss_pillar_candA_v01_b.png')).convert('RGBA'))
    op = a[..., 3] > 0
    Y = luma(a[..., :3])
    cracks = op & (Y < 20)
    a[cracks, :3] = OUTLINE
    stone = op & ~cracks
    y0, y1 = Y[stone].min(), Y[stone].max()
    lo, hi = PILLAR_RANGE
    for y, x in zip(*np.where(stone)):
        t = (Y[y, x] - y0) / (y1 - y0)
        a[y, x, :3] = grey_for_luma(lo + t * (hi - lo), 31, 0.15)
    # crack lip: the stone pixel right below / right of a crack line catches light, so the crack reads at 1x
    lip = np.zeros_like(op)
    lip[1:, :] |= cracks[:-1, :]
    lip[:, 1:] |= cracks[:, :-1]
    lip &= stone
    Yn = luma(a[..., :3])
    for y, x in zip(*np.where(lip)):
        a[y, x, :3] = grey_for_luma(min(Yn[y, x] + 22, hi), 31, 0.15)
    # one hand-drawn fresh crack on the lit right half of the middle blocks (the raw cracks follow the block
    # joints and read as masonry once recoloured); lip on its right side
    Yn = luma(a[..., :3])
    for x, y in PILLAR_CRACK:
        a[y, x, :3] = OUTLINE
    for x, y in PILLAR_CRACK:
        if (x + 1, y) not in PILLAR_CRACK and stone[y, x + 1]:
            a[y, x + 1, :3] = grey_for_luma(min(Yn[y, x + 1] + 22, hi), 31, 0.15)
    ol = outline(a)
    merged = reduce_colours(a, 14)
    Image.fromarray(a).save(os.path.join(ENV, 'boss_pillar_candA_v02.png'))
    report('boss_pillar_candA_v02.png', a, 'cracks %d, stone %d (luma %.0f..%.0f -> %d..%d), lip %d, outline %s, '
           'merged %d' % (int(cracks.sum()), int(stone.sum()), y0, y1, lo, hi, int(lip.sum()), ol, merged))


PILLAR_RANGE = (58, 172)
PILLAR_CRACK = [(21, 29), (20, 30), (20, 31), (19, 32), (19, 33), (20, 34), (20, 35), (19, 36), (19, 37),
                (18, 38), (18, 39), (19, 40), (19, 41), (18, 42)]


# ---------------------------------------------------------------- preview
def wang_lut(sheet, meta, names=('lower', 'upper')):
    import json
    d = json.load(open(os.path.join(ENV, meta), encoding='utf-8'))
    im = Image.open(os.path.join(ENV, sheet)).convert('RGBA')
    lut = {}
    for t in d['tileset_data']['tiles']:
        c, bb = t['corners'], t['bounding_box']
        lut[(c['NW'], c['NE'], c['SW'], c['SE'])] = im.crop((bb['x'], bb['y'], bb['x'] + 16, bb['y'] + 16))
    return lut


def tile(name):
    return Image.open(os.path.join(ENV, name)).convert('RGBA')


def surface_panel(rng):
    """12x9 tiles: grass (v02 interior + variants), the new grass<->path set, a patch of grass<->soil v03."""
    path_v = ['GGGGGGGGGGGGG', 'GGGGGGGGGGGGG', 'GGGGGGGGGGGGG', 'GGGGGGGGGGGGG', 'GGGGGPPGGGGGG',
              'PPPPPPPPPPPPP', 'PPPPPPPPPPPPP', 'GGGGGGGGGGGGG', 'GGGGGGGGGGGGG', 'GGGGGGGGGGGGG']
    soil_v = ['GGGGGGGGGGGGG', 'GSSGGGGGGGGGG', 'GSSGGGGGGGGGG', 'GGGGGGGGGGGGG'] + ['G' * 13] * 6
    plut = wang_lut('tiles_grass-path_v02.png', 'tiles_grass-path_v01.json')
    slut = wang_lut('tiles_grass-soil_v03.png', 'tiles_grass-soil_v01.json')
    grass = [tile('tiles_grass_base_v02.png')] * 3 + [tile('tiles_grass_var_%d_v02.png' % i) for i in range(1, 5)]
    paths = [plut[('lower',) * 4]] * 2 + [tile('tiles_path_var_%d_v01.png' % i) for i in range(1, 4)]
    soils = [slut[('lower',) * 4]] + [tile('tiles_soil_var_%d_v01.png' % i) for i in (1, 2)]
    out = Image.new('RGBA', (12 * 16, 9 * 16))
    for y in range(9):
        for x in range(12):
            for grid, lut, mark, inner in ((soil_v, slut, 'S', soils), (path_v, plut, 'P', paths)):
                cs = (grid[y][x], grid[y][x + 1], grid[y + 1][x], grid[y + 1][x + 1])
                if mark in cs:
                    key = tuple('lower' if c == mark else 'upper' for c in cs)
                    t = rng.choice(inner) if key == ('lower',) * 4 else lut[key]
                    break
            else:
                t = rng.choice(grass)
            out.paste(t, (x * 16, y * 16))
    for name, pos in (('altar_v04.png', (64, 2)), ('storage_chest_v02.png', (116, 26)),
                      ('workbench_v02.png', (6, 108)), ('anvil_v02.png', (62, 108)),
                      ('relic_bench_v02.png', (100, 108))):
        out.alpha_composite(tile(name), pos)
    return out


def dungeon_panel(rng):
    """6x9 tiles of dungeon v02 (north wall: top, wall-top/front, front/floor, then floor + variants)."""
    dlut = wang_lut('tiles_dungeon_v02.png', 'tiles_dungeon_v01.json')
    var = tile('tiles_dungeon_v02_var.png')
    floors = [dlut[('lower',) * 4]] * 2 + [var.crop((i * 16, 0, i * 16 + 16, 16)) for i in range(3)]
    out = Image.new('RGBA', (6 * 16, 9 * 16))
    for x in range(6):
        out.paste(dlut[('upper',) * 4], (x * 16, 0))
        out.paste(dlut[('upper', 'upper', 'transition', 'transition')], (x * 16, 16))
        out.paste(dlut[('transition', 'transition', 'lower', 'lower')], (x * 16, 32))
        for y in range(3, 9):
            out.paste(rng.choice(floors), (x * 16, y * 16))
    out.alpha_composite(tile('boss_pillar_candA_v02.png'), (34, 62))
    return out


def do_preview():
    from PIL import ImageDraw, ImageFont
    rng = random.Random(7)
    s, d = surface_panel(rng), dungeon_panel(rng)
    pairs = [('workbench_v01_b.png', 'workbench_v02.png'), ('anvil_v01_b.png', 'anvil_v02.png'),
             ('storage_chest_v01_f.png', 'storage_chest_v02.png'),
             ('boss_pillar_candA_v01_b.png', 'boss_pillar_candA_v02.png')]
    pad = 4
    row2_w = sum(tile(a).width + tile(b).width + 3 * pad for a, b in pairs) + pad
    row2_h = 64 + 2 * pad
    W = max(s.width + d.width + 3 * pad, row2_w)
    H = s.height + 2 * pad + row2_h + 10
    sheet = Image.new('RGBA', (W, H), (40, 35, 31, 255))
    sheet.alpha_composite(s, (pad, pad))
    sheet.alpha_composite(d, (s.width + 2 * pad, pad))
    y0 = s.height + 2 * pad + 10
    x = pad
    for a, b in pairs:
        for name in (a, b):
            im = tile(name)
            bg = Image.new('RGBA', im.size, (122, 138, 90, 255) if 'pillar' not in name else (107, 94, 79, 255))
            bg.alpha_composite(im)
            sheet.alpha_composite(bg, (x, y0 + 64 - im.height))
            x += im.width + pad
        x += pad
    big = sheet.resize((W * 4, H * 4), Image.NEAREST)
    dr = ImageDraw.Draw(big)
    try:
        font = ImageFont.truetype('arial.ttf', 18)
    except OSError:
        font = ImageFont.load_default()
    dr.text((pad * 4, (s.height + 2 * pad) * 4 + 6),
            'raw -> hand-fixed: workbench b, anvil b, shared chest f, boss pillar candA b (open ? item, candidate)',
            fill=(244, 201, 93, 255), font=font)
    big.save(os.path.join(ENV, 'stage4_a1_preview_v01.png'))
    print('stage4_a1_preview_v01.png', big.size)


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    if cmd == 'preview':
        do_preview()
    elif cmd == 'path':
        base = '#c8a073'
        if '--base' in sys.argv:
            base = sys.argv[sys.argv.index('--base') + 1]
        do_path(base.lstrip('#'))
    elif cmd == 'objects':
        fix_workbench()
        fix_anvil()
        fix_chest()
        fix_pillar()
    else:
        print(__doc__)

# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow>=10", "numpy>=1.26"]
# ///
"""regrass.py: human decision (1) of 2026-10-17. The grass greens move +15 deg of HLS hue toward green,
away from the sick-olive corruption signal #6f8f3a (option (a) of fix2/grass/hue_proposals.png;
brief sec.4 R23 proposal "life greens vs corruption green").

It is a fixed colour-to-colour lookup table, not a filter. Only the exact grass colours listed below change.
Every other colour (soil, ash, olive mould #6f8f3a, flowers, outlines, violet veins, bone) stays byte-identical.
Lightness and HLS saturation are unchanged: each target is the source with H + 15 deg, rounded to 8 bit.
Alpha is untouched. No resampling. The tables are idempotent: no target is also a source key, so running
regrass twice gives the same result as running it once.

Tables
  GRASS_LUT      the 8 greens of the v02 all-grass (upper) tile of tiles_grass-corruption_v02 and of
                 grass_var_1..4. They are also the only greens in tiles_grass-corruption_v04 (the olive
                 #6f8f3a there is not in the table and stays).
  SOIL_EDGE_LUT  opt-in (soil_edges=True). 6 extra greens/yellows that exist only on the grass side of the
                 grass<->soil transition tiles (tiles_grass-soil_v01/v02/_watered): 4 light blade tips and
                 2 dry-rim yellows. Same +15 rule. Recommended for soil sheets: without it those 61 px
                 stay at the old hue and read as yellow specks (some are weed-coloured) in the green field.

Also here
  delavender(img, box=None)  #786d87 lavender-grey fleck -> WARM_CREAM. Only for grass tiles: the old
                 tiles_grass-corruption_v02 sheet uses #786d87 on its corrupted side (277 px), so pass a box
                 when the image holds anything but grass.

Python use:
    from regrass import regrass, GRASS_LUT
    out = regrass(Image.open('tiles_grass-corruption_v04.png'))              # 8 grass greens only
    out = regrass(Image.open('tiles_grass-soil_v02.png'), soil_edges=True)   # + the soil-edge pixels
    Both soil sheets (v02 and v02_watered) need soil_edges=True; the corruption v04 sheet has no edge extras.
    The soil sheet's all-grass tile (0,48) is the original interior tile and still has 2 lavender px:
    delavender(img, box=(0, 48, 16, 64)).

CLI:
    python regrass.py in.png out.png [--soil-edges] [--delavender]
    python regrass.py --selftest
"""
import colorsys
import sys

import numpy as np
from PIL import Image

HUE_SHIFT_DEG = 15

# source -> target. Comment: HLS before -> after (h in degrees).
GRASS_LUT = {
    0x99bd5a: 0x80bd5a,   # base           h81.8 s0.43 l0.55 -> h97.0
    0x96ba55: 0x7dba55,   # base streak    h81.4 s0.42 l0.53 -> h96.2
    0x9ab95e: 0x83b95e,   # base soft      h80.4 s0.39 l0.55 -> h95.6
    0x90b45c: 0x7ab45c,   # base shade     h84.5 s0.37 l0.53 -> h99.5
    0x84a651: 0x6fa651,   # tuft dark      h84.0 s0.34 l0.48 -> h98.8
    0x74934a: 0x62934a,   # tuft darkest   h85.5 s0.33 l0.43 -> h100.3
    0x99c256: 0x7ec256,   # blade light    h82.8 s0.47 l0.55 -> h97.8
    0xc1d178: 0xabd178,   # blade tip      h70.8 s0.49 l0.65 -> h85.6  (3 deg from olive, but l0.65 vs 0.39)
}

# Opt-in, grass<->soil sheet only. Positions (soil v02, x,y) are in the survey: light tips sit in pairs on
# the lower grass edge, the dry-rim pair sits on the grass rim next to the soil lip.
SOIL_EDGE_LUT = {
    0xcbe192: 0xb7e192,   # light tip pair h76.7 s0.57 l0.73 -> h91.9
    0x9dd135: 0x76d135,   # bright blade   h80.0 s0.63 l0.51 -> h95.0
    0xb1c64c: 0x92c64c,   # blade          h70.3 s0.52 l0.54 -> h85.6
    0xd3d261: 0xb7d361,   # yellow tip     h59.5 s0.56 l0.60 -> h74.7
    # dry rim: unshifted these are near-copies of the poison weed (dE2000 5.1 to weed mid #a5a132; and
    # #d3d261 above is dE 3.8 from weed light #d5ce40). Shifted, every edge colour moves away from the weed
    # and toward the new field; only #a5a256 (18 px) moves toward olive, dE2000 12.4 -> 9.0, which is still
    # farther than the field's own darkest tuft #62934a (4.8). Recommended: soil_edges=True on soil sheets.
    0xa5a256: 0x94a556,   # dry rim        h57.7 s0.31 l0.49 -> h72.9
    0xbfb554: 0xaebf54,   # dry rim light  h54.4 s0.46 l0.54 -> h69.5
}

LAVENDER = 0x786d87      # cool lavender-grey fleck in the original interior tile (B > R, off-palette)
WARM_CREAM = 0xe6d3b0    # h39 s0.52 l0.80, lum 213 (below the altar flame core #efe3c6, lum 227)


def _rgb(v):
    return (v >> 16) & 255, (v >> 8) & 255, v & 255


def _apply(img, table, box=None):
    """Exact colour replace on opaque pixels; returns a new image in RGBA or RGB (input mode kept when
    it is RGB/RGBA; anything else is converted to RGBA)."""
    mode = img.mode if img.mode in ('RGB', 'RGBA') else 'RGBA'
    a = np.array(img.convert(mode))
    rgb = a[..., :3].astype(np.uint32)
    key = (rgb[..., 0] << 16) | (rgb[..., 1] << 8) | rgb[..., 2]
    region = np.ones(key.shape, bool)
    if box is not None:
        x0, y0, x1, y1 = box
        region[:] = False
        region[y0:y1, x0:x1] = True
    if mode == 'RGBA':
        region &= a[..., 3] > 0
    counts = {}
    for src, dst in table.items():
        m = (key == src) & region           # masks come from the ORIGINAL keys, so no chained remaps
        n = int(m.sum())
        if n:
            a[m, 0], a[m, 1], a[m, 2] = _rgb(dst)
            counts[src] = n
    return Image.fromarray(a), counts      # uint8 HxWx3 / HxWx4 -> RGB / RGBA


def regrass(img, soil_edges=False, return_counts=False):
    """Recolour only the grass greens by +15 deg HLS hue (fixed LUT). Every other colour is untouched."""
    table = dict(GRASS_LUT)
    if soil_edges:
        table.update(SOIL_EDGE_LUT)
    out, counts = _apply(img, table)
    return (out, counts) if return_counts else out


def delavender(img, box=None, return_counts=False):
    """#786d87 -> WARM_CREAM, optionally only inside box=(x0, y0, x1, y1)."""
    out, counts = _apply(img, {LAVENDER: WARM_CREAM}, box)
    return (out, counts) if return_counts else out


def _selftest():
    """Re-derive both tables from colorsys and check exactness, idempotence and no collisions."""
    for table in (GRASS_LUT, SOIL_EDGE_LUT):
        for src, dst in table.items():
            r, g, b = (v / 255 for v in _rgb(src))
            h, l, s = colorsys.rgb_to_hls(r, g, b)
            want = colorsys.hls_to_rgb((h + HUE_SHIFT_DEG / 360) % 1, l, s)
            want = tuple(int(round(v * 255)) for v in want)
            assert want == _rgb(dst), ('#%06x' % src, want, '#%06x' % dst)
    keys = set(GRASS_LUT) | set(SOIL_EDGE_LUT)
    vals = list(GRASS_LUT.values()) + list(SOIL_EDGE_LUT.values())
    assert not keys & set(vals), 'a target is also a source: not idempotent'
    assert len(set(vals)) == len(vals), 'two sources map to one target'
    protected = {0x6f8f3a, 0x3b1f4d, 0x5e2d7a, 0x1a1714, 0x2e2a26, 0x4a423a, 0x6b5e4f, 0x8c7b66, 0xd8d2c0,
                 0xf4c95d, 0xc9932b, 0x9c6a1f, 0xefe3c6, 0x6f5522, 0xd5ce40, 0xa5a132}
    assert not (keys | set(vals)) & protected, 'a brief palette colour is in the table'
    print('selftest ok: %d grass + %d soil-edge entries, all exact +%d deg, idempotent, no collisions'
          % (len(GRASS_LUT), len(SOIL_EDGE_LUT), HUE_SHIFT_DEG))


if __name__ == '__main__':
    args = [x for x in sys.argv[1:] if not x.startswith('--')]
    flags = {x for x in sys.argv[1:] if x.startswith('--')}
    if '--selftest' in flags:
        _selftest()
        sys.exit(0)
    if len(args) != 2:
        print(__doc__)
        sys.exit(2)
    src = Image.open(args[0])
    out, counts = regrass(src, soil_edges='--soil-edges' in flags, return_counts=True)
    if '--delavender' in flags:
        out, lav = delavender(out, return_counts=True)
        counts.update(lav)
    out.save(args[1])
    total = sum(counts.values())
    print('%s -> %s: %d px recoloured' % (args[0], args[1], total))
    for k, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        dst = GRASS_LUT.get(k, SOIL_EDGE_LUT.get(k, WARM_CREAM))
        print('   #%06x -> #%06x  %d px' % (k, dst, n))

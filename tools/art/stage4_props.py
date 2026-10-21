# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""4단계 본 제작 소품 묶음 손질 (밤 작업 a2): size-32 props bundle and size-16 items bundle (brief sec.5.7 손질 규칙).
기록: assets/concept/04-env/prompts.md "본 제작 (2026-10-21 밤)" 2절.

usage: uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I tools/art/stage4_props.py assets/concept/04-env
Reads  <env>/props32_v01_sheet.png, <env>/items16_v01_sheet.png (raw review sheets, 8x8 cells, index = row*8+col)
Writes <env>/prop_<name>_v02.png (32x32), <env>/item_<name>_v02.png (16x16),
       <env>/props32_v02_sheet.png, <env>/items16_v02_sheet.png (keepers only, packed 8 per row, index order)
       and prints a per-sprite report (colours before/after, max luma, outline px added).

Steps per sprite (in order):
 1 alpha to 0/255, drop 8-connected specks of <= 2 px
 2 sprite-specific edits (lantern glass to unlit, recolours listed in SPECIAL)
 3 outline: near-black (luma < 25) -> #1a1714; every boundary pixel with luma < 40 -> #1a1714;
   a boundary pixel with luma >= 40 gets #1a1714 on its transparent 4-neighbours (closed 1px outline),
   or becomes #1a1714 itself when it touches the canvas edge. Cobweb is exempt (thread art, no outline).
 4 cool to warm: blue-leaning greys (B > R) and any blue hue -> warm grey of the same luma
   (ratio of brief iron #5e5953: R 1.047, G 0.991, B 0.924 of luma); threat sprites keep violet as
   brief violet #3b1f4d / #5e2d7a (no bright violet face)
 5 family snaps: copper, iron + rust, life greens (crops_v03 greens), poison yellow + rust pod,
   buff amber, healing red, threat olive mould, ash
 6 brightness cap: any colour with luma > 215 is scaled down to luma 215 (hue kept)
 7 colour reduction: merge the closest pair in CIELAB (rarer colour -> commoner) until
   props <= 24 colours, items <= 16 colours (outline counted); palette stays a subset
 8 soft snap: a colour within dE76 6 of a reference colour (brief sec.4, crops_v03, items_v04) becomes it
"""
import colorsys
import sys

import numpy as np
from PIL import Image

# ---- keeper names and promoted object ids (record: prompts.md 본 제작 2절 표)
PROPS = {  # size-32 bundle index -> name
 0: "bone_pile_a", 1: "bone_pile_b", 2: "bone_pile_c", 3: "idol_broken_a", 4: "idol_broken_b", 5: "idol_broken_c",
 6: "ritual_stone_a", 7: "ritual_stone_b", 8: "ritual_stone_c", 9: "brazier_dark_a", 10: "brazier_dark_b", 11: "brazier_dark_c",
 12: "candles_black_a", 13: "candles_black_b", 14: "offering_bowl", 15: "bramble_dead_a", 16: "bramble_dead_b", 17: "skull_stake",
 18: "rag_stake", 19: "bone_cage", 20: "skull_pile", 21: "boulder_corrupt", 22: "wall_torch_a", 23: "wall_torch_b",
 25: "lantern_post_a", 26: "lantern_post_b", 27: "lantern_post_c", 28: "candle_stand_a", 29: "candle_stand_b", 30: "candle_stand_c",
 31: "lantern_ground", 32: "lantern_wall", 33: "wall_sconce", 34: "fire_basket", 35: "campfire_ring", 36: "rubble_a", 37: "rubble_b",
 38: "rubble_c", 39: "pillar_stub_a", 40: "pillar_stub_b", 41: "pillar_stub_c", 42: "chain_a", 43: "chain_b", 44: "chain_c", 45: "crate_a",
 48: "barrel_a", 49: "barrel_b", 50: "barrel_c", 51: "barrel_tipped", 52: "crate_smashed", 53: "barrel_smashed", 54: "sack_a", 55: "sack_b",
 56: "mine_frame", 57: "beam_broken", 58: "stalagmite_a", 59: "stalagmite_b", 60: "cobweb", 61: "pottery_broken", 62: "jar_clay"}
PROP_IDS = """452e8745-0393-424b-a52a-d41888ac16ee b9c4e44a-0cb8-430b-b784-dc009adbdec6 2d5f84f1-376c-4488-9a36-6dcff3c67622
01fa40aa-66f1-4a82-8259-9548394616fd 2050311d-6e68-4ac3-b05b-87db99b1d211 dedb472c-00a2-4e89-a41e-08f7507e9e76
a9a6b8d8-e9a5-494b-a293-a7a8a1f054c6 708ebcb5-b4f0-4310-8ea9-3668b3e8e028 faf6c411-4f8b-4b77-92c8-0152aa019551
6df72ade-33d7-4dd8-8cf0-aadc8f1c2b55 d185ed1a-b225-4da2-ab40-a9f7350ab7e7 205c322c-e768-4a0f-9bd6-793c7f4cf6c3
eccc6b32-a814-4c81-961c-1c868d03e4b9 a30e0b0c-220e-4ceb-82f1-96ad654f1f39 f856ee94-bef8-4290-ae6d-548ae221293b
214ce0c4-d5b7-4b8c-9481-23d6e575a11e 0247d21a-e59b-49e9-b41f-f2b3ae689c0e 30f41f1a-7b91-4f91-82d0-a5393855f822
c187ee93-6d92-4b0c-8bea-4bfe23e67c66 09baa729-9e92-4337-ba6a-6b32c6a651be 615d6df3-b405-4542-b76b-41e3860005ba
5a1d72fb-713a-43ee-aefb-05af267e4532 ae6ae041-f0fe-4687-b282-ab899f5d3b2a ba2917bd-e740-4bb9-b0f5-05fe1ffd6ac9
64d703e7-04ed-426b-9f3b-946491943313 5eee75ee-4008-4156-b80e-4b02ba162858 28088a65-cd05-4099-90e8-92b25ab0ffa9
c285f17c-4589-4646-a91a-19a246b4e3df 2f2e8ca3-8ca0-4f5e-8772-771e69e61f67 2160e5a4-7ddd-437b-831e-83728bb09749
bd2fe0f4-1393-4def-9dea-67088b62bb0b 34f428e6-439b-4fea-8be0-411775f36306 cac5436b-f0f4-41f5-83c0-fb4b12b20b34
512b64f0-0bb2-4f54-93ae-824dfcf2db4d 61efcca1-057f-42ac-88f5-b805e06aa038 9b603d6c-127b-4f63-96e1-e11f63c323b5
ff2fe46d-53f7-42e7-8b91-65a183eb2923 6eef1212-a02b-41c1-80b2-6b5382b566c5 d6ea7401-d1d4-4b7f-8e26-5cd4eafe2223
5d25de31-9da7-4c14-bbce-274da29a5c01 df9135a0-0d4d-4154-b27a-5f17c646709f 5e7b8c59-68d2-49e7-9d91-df8f9fbfd2f2
498fb625-7047-4077-8cc5-b13ccc5444c5 3deb0fb6-eed0-44c7-ba7b-c868fdc2fb41 1d357612-e45b-4f1a-9fe7-3d17267be8d8
8f2440de-10e4-45cb-bfde-41de01ec38e7 758a4c5d-81f7-4607-9bc3-1f0d95fa640a 52ba74d0-a8f7-482d-839f-fb79df6a97c5
955e9ff1-cf73-4149-ad63-c5341c546e7e a08e5796-f4c8-4037-a611-34d4b62cd1da 4c768a14-59ab-4f3f-be06-ef71bc9f99bd
9b288997-1aea-440a-b5e1-bbcaf8b1594a 17f10194-30b3-4934-9e5a-656beea17976 29106b2e-e1a0-4c62-a97e-4fd5b3dc830f
6ad767de-eb55-48dc-a569-6202c427a558 1486fa54-1164-46fe-8d54-7adb5a252709 e277cb56-a477-4841-b3de-c2e79e83398f
879d6272-9243-4afb-af40-1f20f973d7dd c8bd1fcd-4d69-49c1-ab56-6b57fc5f306f 60e27027-e3ca-450b-84a0-df9ae98b72cd""".split()
ITEMS = {  # size-16 bundle index -> name
 0: "stone_a", 1: "stone_b", 2: "stone_c", 3: "stone_mossy", 4: "sticks_a", 5: "sticks_b", 6: "sticks_c", 7: "wild_healing",
 8: "wild_buff", 9: "wild_poison", 10: "wild_herb_clump", 11: "sprig_healing", 12: "sprig_buff", 13: "sprig_poison",
 14: "mushroom_a", 15: "mushroom_b", 16: "mushroom_c", 17: "mushroom_d", 18: "mushroom_ash", 20: "skull_small_a",
 21: "skull_small_b", 22: "bones_small_a", 23: "bones_small_b", 24: "candle_black_a", 25: "candle_black_b", 26: "stone_veined",
 27: "stone_mould", 28: "mould_clump", 31: "thorn_twig", 32: "rag_bloody", 33: "bone_charm", 34: "ash_heap", 35: "offering_cup",
 36: "ore_copper_a", 37: "ore_copper_b", 38: "ore_copper_c", 39: "ore_iron_a", 40: "ore_iron_b", 41: "ore_iron_c",
 42: "ingot_copper_a", 43: "ingot_copper_b", 44: "ingot_iron_a", 45: "ingot_iron_b", 46: "planks_a", 47: "planks_b",
 48: "planks_c", 49: "cloth_a", 50: "cloth_b", 51: "cloth_c", 52: "leather_a", 53: "leather_b", 54: "leather_c", 55: "bone_a",
 56: "bone_b", 57: "bone_c", 58: "holy_water_a", 59: "holy_water_b", 60: "holy_water_c", 61: "stone_block", 62: "log", 63: "rope"}
ITEM_IDS = """c18b684a-bc57-42e7-a8d3-017ec01fd3fe 28a3636e-6251-4987-a205-df720d6d714e 130b21f1-a7f8-4a63-b48a-e469a9cacab3
d24337b4-e63a-4c57-977d-9ae77f6c673c 253b2d2d-f4d2-4276-8c96-78179ba51f76 09aa9bfa-e249-4f60-9ce0-e8d4d48ed08d
55132edd-cfc2-4d65-b92d-b8b295d6e38e 1db54696-9bed-4826-a606-cc06ebec5ea8 e2b9c26d-2b16-480a-8840-27f7b7149ce2
1111645b-db44-4783-a4ef-dbaaaf542d73 e72be1f2-5596-4216-8c88-11dce80b7bf3 35355681-6ecd-459f-b63f-270b03b3cdee
15971333-9775-4d4d-810f-562135b46436 a3990eab-1c54-4943-a675-0d6cae8b64c1 1967cde2-e1c5-4e45-94b9-444b4996dbda
e721c9b8-62c2-408d-ba15-592917c5007b 55ed3ab5-ed82-4738-adc1-1bfc014dd2c8 9002f96d-03c3-47c1-8ddc-94d3d767fac7
eb0de9ed-5333-4a7a-938e-20b4abe45ca0 562d10b3-bd93-4a6d-afa7-be427739e23d aa2e5dce-1211-4e0b-85a3-33d25eade048
34935482-0e08-4a95-9572-391bf93664ff cf1a01e3-784f-44c2-ba60-665aed1ba34b 9a8439ef-319d-43c4-9716-96f51df05b0b
652c6db4-5078-4f6f-a65d-191fd345ed0e 571e42d9-9244-429a-9f79-f43f06c994f1 0bc0ee91-f46a-4438-afd5-5224816d0d6c
1f61b344-eb77-4704-ae11-3b55823cafc0 066e1f2f-6f72-4e3f-a879-f9626547c442 8996de6c-b153-4a16-a23f-a4833f417291
10e743a5-78ce-4c9c-9e64-87824262eae0 2c9b503f-e3ed-409a-8e66-319dcd8055e1 cc87139b-4a5c-4683-ab20-b047ca903bac
f5876336-33ac-46a3-8daf-1fa161cb68f9 27547824-0d9c-43ba-9780-ee8e45388bc7 5e3b8b08-d474-40fb-9229-a4e552bd3cc0
ddfb5003-1837-4f79-a528-b414a20d8af4 74dff024-6a8d-4e47-b7bf-aeb6940ea1d8 e74f2f7f-5007-4678-9c0a-0d9973303442
d0aa31e4-d655-4cd5-b9d4-ada7e0697f65 e088f9ef-dc32-4adc-9aaf-125046549645 5bb1d4af-3661-417a-8823-c42a87ef3cc5
171a0e9c-b207-4a62-9c5b-48a78cf42840 934d6864-ef83-4562-9aaa-52c42b33245e bfc7b2a0-7cad-4754-b56c-f7432185528c
fe0bb7a5-bcd5-4aed-a7fd-6d4e2233d4f2 411f0a01-bb51-4e85-922a-b40feff87c56 7660b5db-3141-4d75-8d57-59ec74819abe
ab6fa979-5cec-4a08-ac6f-12546bae3eea e97c8a73-d196-4018-a3c6-ce9e767845fd b9f46571-9386-449f-95d1-d117e4ab155f
6a5e6552-f176-4231-b34d-48fe1fc7176d f94e9b2f-e033-4b5d-a77f-ebc04ef6b579 ddaabffb-6022-4b79-9069-0117f0c2c527
00af7fc1-a4eb-4320-9795-8a2457f63399 b27a0fe8-e4c4-4595-8ff8-2b8fbca30bf3 5e5d9dfd-3369-4c15-a6f8-79ee28143e4b
c4d3240f-74b1-4df4-b9a0-fa7bd5c7be25 0fd7d2fd-4794-4698-bed2-873073554d8b bccc9788-ba14-4c3e-80f4-6c6f3b889892
4e48ddfb-eacb-46e6-9514-982671715f8d""".split()
assert len(PROP_IDS) == len(PROPS) == 60 and len(ITEM_IDS) == len(ITEMS) == 61
PROP_OBJ = dict(zip(sorted(PROPS), PROP_IDS))
ITEM_OBJ = dict(zip(sorted(ITEMS), ITEM_IDS))


ENV = sys.argv[1]
OUT = (0x1a, 0x17, 0x14)


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


def de(a, b):
    return float(np.linalg.norm(lab(a) - lab(b)))


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
    return min(ramp, key=lambda r: de(c, r))


# ---------------------------------------------------------------- palettes
BRIEF4 = [hx(s) for s in "1a1714 2e2a26 4a423a 6b5e4f 8c7b66 f4c95d c9932b 9c6a1f efe3c6 6f5522 3b1f4d 5e2d7a "
          "8a5fb0 6f8f3a d8d2c0 2a0808 5c1010 8f1a1a c8321f ff7a1a".split()]
COPPER = [hx(s) for s in ("5b2e15", "8c4a22", "c06a2e", "df903f", "eaa63a")]
IRON = [hx(s) for s in ("34302d", "5e5953", "a39d92", "d2cbb8")]
RUST = [hx(s) for s in ("6e3624", "a5552f")]
GREENS = [hx(s) for s in ("284624", "2b4220", "3c6c32", "456a33", "589a48", "5f8a4a", "82ae68", "88c468",
                          "a8cc8c", "b4dc8c")]
POISON_Y = [hx(s) for s in ("45390f", "6e6620", "a5a132", "d5ce40")]
POD = [hx(s) for s in ("5b2e15", "c4421c")]
BUFF_O = [hx(s) for s in ("723f0e", "a3520f", "e0861a", "f4c95d")]
RED = [hx(s) for s in ("5c1010", "c41e24", "f5674c")]
MOULD = [hx(s) for s in ("4b6127", "6f8f3a")]
VIOLET = [hx("3b1f4d"), hx("5e2d7a")]
ASH = [hx(s) for s in ("2e2a26", "4a423a", "6b5e4f", "8c7b66", "b2a693")]
GOLD = [hx(s) for s in ("6f5522", "9c6a1f", "c9932b", "f4c95d")]
GLASS = {"d": hx("2e2a26"), "m": hx("4a423a"), "hi": hx("6b5e4f")}


def ref_palette():
    cols = set(BRIEF4)
    for f in ("crops_v03_sheet.png", "items_v04_strip.png"):
        im = Image.open(f"{ENV}/{f}").convert("RGBA")
        cols |= {p[:3] for p in im.getdata() if p[3] > 127}
    cols |= set(COPPER + IRON + RUST + MOULD)
    # no near-black targets (outline stays the only near-black) and no demon-row black #2a0808 in wood
    return sorted(c for c in cols if luma(c) >= 25 and c != hx("2a0808"))


REF = ref_palette()
REF_LAB = np.array([lab(c) for c in REF])

THREAT_PROPS = set(range(0, 22))
THREAT_ITEMS = {18, 20, 21, 22, 23, 24, 25, 26, 27, 28, 31, 32, 33, 34, 35}

# sprite-specific notes are written to the record by hand; the code is the source of truth
LANTERN_GLASS = {  # prop index -> (x0, y0, x1, y1) box holding the lit glass (luma >= 165 inside -> unlit glass)
    25: (20, 15, 24, 19), 26: (20, 13, 24, 18), 27: (14, 8, 17, 12), 32: (12, 18, 20, 26)}
DROP_PX = {26: [(9, 29), (15, 29)]}  # stray bluish-white specks under lantern_post_b's feet


def family(kind, i, c):
    """Return a replacement colour for c, or None to leave it. kind 'p' (prop) or 'i' (item)."""
    h, s, v = hsv(c)
    L = luma(c)
    if L < 30:
        return None  # outline and near-black shading are handled by outline()
    n = (PROPS if kind == "p" else ITEMS)[i]
    threat = (i in THREAT_PROPS) if kind == "p" else (i in THREAT_ITEMS)
    if n.startswith(("ore_copper", "ingot_copper", "ore_iron", "ingot_iron")):
        return None  # rank_ramps() handles metals
    if n in ("wild_poison", "sprig_poison"):
        if (h < 18 or h > 340) and s >= 0.5 and L >= 40:
            return by_luma(c, POD)
        if 15 <= h <= 80 and s >= 0.3:
            return by_luma(c, POISON_Y)
    if n in ("wild_buff", "sprig_buff") and 12 <= h < 50 and s >= 0.45:
        return by_luma(c, BUFF_O)
    if n in ("wild_healing", "sprig_healing") and (h < 15 or h > 335) and s >= 0.45:
        return by_luma(c, RED)
    if n == "holy_water_c" and (h < 20 or h > 330) and s >= 0.4:
        return by_luma(c, GOLD)  # red band read as blood; holy water stays faith gold
    if not threat and 65 <= h <= 170 and s >= 0.2:
        return by_lab(c, GREENS)  # life greens = the crops_v03 greens (never the sick olive)
    if threat and 55 <= h <= 140 and s >= 0.15:
        return by_luma(c, MOULD)
    if threat and 250 <= h <= 345 and s >= 0.3 and L < 120:
        return VIOLET[0] if L < 50 else VIOLET[1]
    if kind == "p" and n == "bone_pile_c" and 18 <= h <= 50 and s >= 0.22:
        return by_luma(c, ASH)  # the "ash mound" came out sand-coloured
    return None


def rank_ramps(a, n):
    """Metals: the sprite's colours of one family, sorted by luma, are split evenly over the ramp
    (darkest group -> first ramp colour). Keeps the shading order, no gold step for copper."""
    groups = []
    if n.startswith(("ore_copper", "ingot_copper")):
        groups.append((lambda h, s, L: (h <= 45 or h >= 350) and s >= 0.35 and L >= 30, COPPER[:4]))
    if n.startswith(("ore_iron", "ingot_iron")):
        groups.append((lambda h, s, L: L >= 30 and (s < 0.3 or 180 < h < 330), IRON))
        groups.append((lambda h, s, L: L >= 30 and (h <= 45 or h >= 340) and s >= 0.3, RUST))
    for sel, ramp in groups:
        op = a[..., 3] > 0
        cols = sorted({tuple(int(v) for v in a[y, x, :3]) for y, x in zip(*np.where(op))
                       if sel(*hsv(tuple(int(v) for v in a[y, x, :3]))[:2],
                              luma(tuple(int(v) for v in a[y, x, :3])))}, key=luma)
        m = {c: ramp[min(len(ramp) - 1, k * len(ramp) // max(1, len(cols)))] for k, c in enumerate(cols)}
        a = recolour(a, lambda c: m.get(c))
    return a


def cool_to_warm(c, threat):
    h, s, v = hsv(c)
    r, g, b = c
    L = luma(c)
    if threat and 250 <= h <= 345 and s >= 0.3 and L >= 30:
        return c  # violet, handled by family()
    if L < 40 and 240 <= h <= 345:
        return warm_grey(L)  # purplish near-blacks
    if threat and 250 <= h <= 345 and s >= 0.2:
        return c
    if b > r + 2 and s < 0.35:
        return warm_grey(luma(c))
    if 170 <= h <= 260 and s >= 0.35:
        return warm_grey(luma(c))
    if s < 0.05 and b >= r - 2:  # dead-neutral greys lean cold next to the warm palette
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


def strip_ground(a):
    """Props only, on raw colours: remove the baked opaque ground shadow / ground stain.
    Background = flood from the canvas border through every pixel that is not near-black (luma < 25),
    4-connected. Opaque background pixels with luma < 115 lie outside the object's outline and are dim:
    they are the drawn ground patch (#625b53 / #55524d grey ellipse, brown stains) and become transparent.
    Bright outside pixels (unoutlined bone tips etc.) stay and get an outline later.
    Guard: if that would remove more than 35% of the opaque pixels the outline is leaky; nothing is removed."""
    # v2 of this rule: the global flood above leaked through outline gaps, so only the two colours the
    # generator uses for its ground ellipse are removed, and only where reachable from the canvas border
    # through transparent or shadow-coloured pixels (4-connected).
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


SHADOW_KEYS = {0x625b53, 0x55524d}


def outline(a, exempt=False, add_from=40.0):
    """add_from: a boundary pixel at least this bright gets #1a1714 on its transparent side;
    None = never add (thin plant / twig art). Darker boundary pixels become #1a1714 themselves."""
    h, w = a.shape[:2]
    op = a[..., 3] > 0
    added = 0
    if exempt:
        return a, 0
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
                continue  # dim edge (baked ground shadow) or no-add art: leave as drawn
            elif edge:
                selfs.append((y, x))
            else:
                adds.extend(empty)
    for y, x in selfs:
        a[y, x, :3] = OUT
    for y, x in set(adds):
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
        keys = [c for c in live if c != OUT]
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


def fix(cell, kind, i):
    a = cell.copy()
    a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
    a[a[..., 3] == 0] = 0
    for (x, y) in DROP_PX.get(i, []) if kind == "p" else []:
        a[y, x] = 0
    n = (PROPS if kind == "p" else ITEMS)[i]
    global LAST_GROUND
    LAST_GROUND = 0
    if kind == "p" and n != "cobweb":
        a, LAST_GROUND = strip_ground(a)
    a = specks(a)
    threat = (i in THREAT_PROPS) if kind == "p" else (i in THREAT_ITEMS)
    if kind == "p" and i in LANTERN_GLASS:
        x0, y0, x1, y1 = LANTERN_GLASS[i]
        glass = [(y, x) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)
                 if a[y, x, 3] and luma(tuple(int(v) for v in a[y, x, :3])) >= 165]
        top = min(y for y, _ in glass) if glass else 0
        for y, x in glass:
            a[y, x, :3] = GLASS["m"]
        for y, x in glass:  # one dull reflection pixel at the top-left of each pane, darker bottom row
            if y == top and (y, x - 1) not in glass:
                a[y, x, :3] = GLASS["hi"]
        bottom = max(y for y, _ in glass) if glass else 0
        for y, x in glass:
            if y == bottom:
                a[y, x, :3] = GLASS["d"]
    if kind == "i" and n == "stone_veined":
        sv = {hx("0d1523"): OUT, hx("121e3c"): VIOLET[0], hx("685668"): hx("6b5e4f"),
              hx("756e75"): hx("8c7b66"), hx("8c8b8f"): hx("a39d92"), hx("a1a0a0"): hx("b2a693")}
        a = recolour(a, lambda c: sv.get(c))
    if kind == "p" and n == "cobweb":
        a = recolour(a, lambda c: cap(warm_grey(luma(c), (1.06, 1.0, 0.86))))
    a = recolour(a, lambda c: cool_to_warm(c, threat))
    a = rank_ramps(a, n)
    a = recolour(a, lambda c: family(kind, i, c))
    if kind == "p" and threat:
        a = recolour(a, lambda c: VIOLET[0] if c == hx("381a29") else None)
    a = recolour(a, lambda c: cap(c))
    no_add = n.startswith(("wild_", "sprig_", "bramble_dead"))
    a, added = outline(a, exempt=(n == "cobweb"), add_from=None if no_add else (80.0 if kind == "p" else 40.0))
    a = reduce(a, 24 if kind == "p" else 16)
    a = recolour(a, soft_snap)
    return a, added


def ncols(a):
    op = a[..., 3] > 0
    return len({tuple(int(v) for v in a[y, x, :3]) for y, x in zip(*np.where(op))})


def maxl(a):
    op = a[..., 3] > 0
    return max(luma(tuple(int(v) for v in a[y, x, :3])) for y, x in zip(*np.where(op)))


def run(sheet, cell, kind, names, prefix, out_sheet):
    sh = np.array(Image.open(f"{ENV}/{sheet}").convert("RGBA"))
    keep = sorted(names)
    rows = (len(keep) + 7) // 8
    outsh = np.zeros((rows * cell, 8 * cell, 4), np.uint8)
    for k, i in enumerate(keep):
        x, y = (i % 8) * cell, (i // 8) * cell
        raw = sh[y:y + cell, x:x + cell].copy()
        fixed, added = fix(raw, kind, i)
        Image.fromarray(fixed).save(f"{ENV}/{prefix}_{names[i]}_v02.png")
        ox, oy = (k % 8) * cell, (k // 8) * cell
        outsh[oy:oy + cell, ox:ox + cell] = fixed
        print(f"{kind}{i:02d} {names[i]:16s} cols {ncols(raw):2d}->{ncols(fixed):2d}  maxluma "
              f"{maxl(raw):5.1f}->{maxl(fixed):5.1f}  outline px added {added}  ground px removed {LAST_GROUND}")
    Image.fromarray(outsh).save(f"{ENV}/{out_sheet}")
    print("saved", out_sheet, outsh.shape[1], "x", outsh.shape[0])


run("props32_v01_sheet.png", 32, "p", PROPS, "prop", "props32_v02_sheet.png")
run("items16_v01_sheet.png", 16, "i", ITEMS, "item", "items16_v02_sheet.png")

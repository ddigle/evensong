# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow>=10"]
# ///
"""2등신 체형 비교 샘플. Tiny Farm RPG 구조(32x32 프레임, 2등신, 1px 어두운 외곽선)를 북극성 v6 색으로 손으로 찍는다.
생성 AI는 쓰지 않는다. 9클래스의 도구·옷은 모든 안에서 같고, 체형과 종족 표시만 바뀐다.
  A  = 전원 같은 체형, 종족 표시 없음      A' = 같은 체형 + 엘프 귀·드워프 수염      B = 종족별 체형

실행: uv run tools/art/chibi_sample.py <출력 폴더>   (고정 버전은 chibi_sample.py.lock)
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = (30, 20, 18)
C = {
    "skin": ((214, 164, 122), (172, 120, 86)), "skin_elf": ((226, 196, 164), (186, 150, 120)),
    "skin_dw": ((206, 142, 104), (160, 100, 70)),
    "steel": ((132, 128, 126), (88, 84, 86), (178, 172, 164)), "iron": ((86, 80, 80), (58, 52, 54), (122, 114, 108)),
    "gold": ((220, 164, 70), (160, 108, 44)), "ivory": ((222, 210, 184), (170, 156, 132)),
    "leather": ((128, 88, 58), (92, 62, 42)), "dleather": ((78, 60, 48), (52, 40, 34)),
    "olive": ((112, 112, 64), (78, 78, 46)), "charcoal": ((66, 60, 64), (44, 40, 44)),
    "tan": ((168, 132, 92), (126, 96, 66)), "boots": ((64, 46, 36), (44, 32, 26)),
    "hair_brown": ((96, 64, 42), (66, 44, 30)), "hair_dark": ((56, 44, 38), (38, 30, 26)),
    "hair_silver": ((206, 202, 190), (158, 154, 146)), "hair_ash": ((178, 160, 120), (134, 118, 88)),
    "beard_red": ((150, 84, 46), (110, 60, 34)), "beard_grey": ((150, 144, 136), (108, 102, 96)),
    "wood": ((120, 82, 50), (86, 58, 36)), "flame": ((255, 214, 110), (240, 150, 60)),
    "glow_blue": ((214, 236, 240), (150, 196, 214)), "rune": ((255, 190, 90), (210, 120, 40)),
    "leaf": ((122, 138, 70), (86, 100, 50)),
}
EYE = (36, 26, 24)


class Spr:
    def __init__(s):
        s.p = {}

    def px(s, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            s.p[(x, y)] = c

    def rect(s, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                s.px(x, y, c)

    def block(s, x0, y0, x1, y1, ramp, edge="r"):
        """filled box, shadow on the right (or bottom) edge, optional highlight on the left."""
        s.rect(x0, y0, x1, y1, ramp[0])
        if "r" in edge:
            s.rect(x1, y0, x1, y1, ramp[1])
        if "b" in edge:
            s.rect(x0, y1, x1, y1, ramp[1])
        if len(ramp) > 2 and "l" in edge:
            s.rect(x0, y0, x0, y1, ramp[2])

    def outline(s):
        add = {}
        for (x, y) in s.p:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in s.p:
                    add[q] = OUT
        for q, c in add.items():
            s.px(*q, c)

    def image(s):
        im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        for (x, y), c in s.p.items():
            im.putpixel((x, y), c + (255,))
        return im


BODY = {  # head w/h, torso w/h, legs h, arm w
    "human": dict(hw=12, hh=9, tw=10, th=6, lh=4, aw=2),
    "big": dict(hw=12, hh=9, tw=14, th=7, lh=4, aw=3),
    "elf": dict(hw=11, hh=9, tw=8, th=7, lh=6, aw=2),
    "dwarf": dict(hw=12, hh=9, tw=13, th=5, lh=2, aw=3),
}


def build(cls, body, markers):
    s = Spr()
    b = dict(BODY[body])
    cx, bottom = 16, 29
    tx0 = cx - b["tw"] // 2
    tx1 = tx0 + b["tw"] - 1
    ty1 = bottom - b["lh"]
    ty0 = ty1 - b["th"] + 1
    hx0 = cx - b["hw"] // 2
    hx1 = hx0 + b["hw"] - 1
    hy1 = ty0
    hy0 = hy1 - b["hh"] + 1
    a = dict(cx=cx, tx0=tx0, tx1=tx1, ty0=ty0, ty1=ty1, hx0=hx0, hx1=hx1, hy0=hy0, hy1=hy1, aw=b["aw"],
             lhand=(tx0 - b["aw"], ty1), rhand=(tx1 + b["aw"], ty1), race=markers)
    k = CLASSES[cls]
    skin = C[{"elf": "skin_elf", "dwarf": "skin_dw"}.get(markers, "skin")]
    # legs / robe
    if k.get("robe"):
        s.block(tx0, ty0, tx1, bottom, C[k["cloth"]])
        s.rect(tx0 - 1, bottom - 1, tx1 + 1, bottom, C[k["cloth"]][1])
    else:
        gap = tx0 + b["tw"] // 2
        s.block(tx0 + 1, ty1 + 1, gap - 1, bottom, C[k.get("legs", "boots")])
        s.block(gap + 1, ty1 + 1, tx1 - 1, bottom, C[k.get("legs", "boots")])
        s.rect(tx0 + 1, bottom, gap - 1, bottom, C["boots"][1])
        s.rect(gap + 1, bottom, tx1 - 1, bottom, C["boots"][1])
        s.block(tx0, ty0, tx1, ty1, C[k["cloth"]])
    # arms with hands
    arm = C[k.get("arm", k["cloth"])]
    s.block(tx0 - b["aw"], ty0 + 1, tx0 - 1, ty1, arm)
    s.block(tx1 + 1, ty0 + 1, tx1 + b["aw"], ty1, arm)
    s.rect(tx0 - b["aw"], ty1, tx0 - 1, ty1, skin[0] if not k.get("gloves") else C[k["gloves"]][0])
    s.rect(tx1 + 1, ty1, tx1 + b["aw"], ty1, skin[1] if not k.get("gloves") else C[k["gloves"]][1])
    for f in k.get("torso", []):
        f(s, a)
    # head: skin face, hair cap, eyes
    s.rect(hx0, hy0 + 1, hx1, hy1, skin[0])
    s.rect(hx0 + 1, hy0, hx1 - 1, hy0, skin[0])
    s.rect(hx1, hy0 + 4, hx1, hy1, skin[1])
    hair = C[k.get("hair", "hair_brown")]
    s.rect(hx0, hy0 + 1, hx1, hy0 + 3, hair[0])
    s.rect(hx0 + 1, hy0, hx1 - 1, hy0, hair[0])
    s.rect(hx0, hy0 + 4, hx0, hy0 + 6, hair[0])
    s.rect(hx1, hy0 + 4, hx1, hy0 + 6, hair[1])
    s.rect(hx1 - 3, hy0 + 1, hx1 - 1, hy0 + 2, hair[1])
    s.px(hx0 + 2, hy0 + 1, tuple(min(255, v + 30) for v in hair[0]))
    ey = hy0 + 5
    s.rect(cx - 3, ey, cx - 3, ey + 1, EYE)
    s.rect(cx + 2, ey, cx + 2, ey + 1, EYE)
    if markers == "dwarf":
        beard = C[k.get("beard", "beard_red")]
        s.rect(hx0 + 1, ey + 2, hx1 - 1, hy1, beard[0])
        s.rect(tx0 + 2, ty0, tx1 - 2, ty0 + 2, beard[0])
        s.rect(tx0 + 4, ty0 + 3, tx1 - 4, ty0 + 3, beard[1])
        s.rect(hx1 - 1, ey + 2, hx1 - 1, hy1, beard[1])
        s.px(cx - 1, ey + 1, skin[1])
    for f in k.get("head", []):
        f(s, a)
    if markers == "elf":
        for dx, dy in ((1, 0), (1, -1), (2, -1), (2, -2), (3, -3)):
            s.px(hx0 - dx, ey + dy, skin[0])
            s.px(hx1 + dx, ey + dy, skin[1])
    for f in k.get("gear", []):
        f(s, a)
    s.outline()
    for f in k.get("glow", []):
        f(s, a)
    return s.image()


# ---- class parts -------------------------------------------------------------------------------------------
def helm(s, a):  # closed great helm over the whole head
    x0, x1, y0, y1 = a["hx0"], a["hx1"], a["hy0"], a["hy1"]
    s.rect(x0, y0 + 1, x1, y1, C["steel"][0])
    s.rect(x0 + 1, y0, x1 - 1, y0, C["steel"][0])
    s.rect(x1, y0 + 1, x1, y1, C["steel"][1])
    s.rect(x0 + 1, y0 + 1, x0 + 2, y0 + 3, C["steel"][2])
    s.rect(x0 + 2, y0 + 6, x1 - 2, y0 + 6, OUT)
    s.rect(a["cx"], y0 + 4, a["cx"], y1 - 1, OUT)
    s.rect(x0, y1, x1, y1, C["gold"][0])


def tabard(s, a):
    s.rect(a["cx"] - 2, a["ty0"] + 2, a["cx"] + 1, a["ty1"] + 2, C["ivory"][0])
    s.rect(a["cx"] + 1, a["ty0"] + 2, a["cx"] + 1, a["ty1"] + 2, C["ivory"][1])
    s.rect(a["tx0"], a["ty0"] + 1, a["tx1"], a["ty0"] + 1, C["gold"][0])


def kite_shield(s, a):  # on the figure's left arm = viewer's right
    x0 = a["tx1"] - 1
    y0 = a["ty0"] - 1
    for i in range(10):
        w = 6 if i < 6 else 6 - (i - 5) * 2
        if w <= 0:
            break
        off = (6 - w) // 2
        s.rect(x0 + off, y0 + i, x0 + off + w - 1, y0 + i, C["steel"][0])
        s.px(x0 + off + w - 1, y0 + i, C["steel"][1])
    s.rect(x0 + 1, y0 + 1, x0 + 1, y0 + 4, C["steel"][2])
    s.rect(x0 + 2, y0 + 1, x0 + 3, y0 + 1, C["gold"][0])
    s.rect(x0 + 2, y0 + 1, x0 + 2, y0 + 6, C["gold"][0])


def hood(color):
    def f(s, a):
        x0, x1, y0, y1 = a["hx0"], a["hx1"], a["hy0"], a["hy1"]
        r = C[color]
        s.rect(x0 - 1, y0 + 1, x1 + 1, y0 + 4, r[0])
        s.rect(x0, y0, x1, y0, r[0])
        s.rect(x0 - 1, y0 + 5, x0, y1, r[0])
        s.rect(x1, y0 + 5, x1 + 1, y1, r[1])
        s.rect(x1 - 3, y0 + 1, x1 + 1, y0 + 2, r[1])
        s.px(a["cx"], y0 - 1, r[0])
    return f


def shadow_face(s, a):  # thief: face in the hood's shadow, eyes glint
    x0, x1, y0, y1 = a["hx0"], a["hx1"], a["hy0"], a["hy1"]
    s.rect(x0 + 1, y0 + 5, x1 - 1, y1 - 1, C["dleather"][1])
    s.rect(x0 + 1, y1 - 1, x1 - 1, y1, C["dleather"][0])
    s.px(a["cx"] - 3, y0 + 5, (236, 214, 170))
    s.px(a["cx"] + 2, y0 + 5, (236, 214, 170))


def staff_candle(s, a):
    x, y = a["lhand"][0] - 1, a["lhand"][1]
    s.rect(x, a["hy0"] - 1, x, y + 2, C["wood"][0])
    s.rect(x - 1, a["hy0"] - 2, x + 1, a["hy0"] - 2, C["gold"][0])
    s.rect(x, a["hy0"] - 4, x, a["hy0"] - 3, C["ivory"][0])


def candle_flame(s, a):
    x = a["lhand"][0] - 1
    s.px(x, a["hy0"] - 5, C["flame"][0])
    s.px(x, a["hy0"] - 6, C["flame"][1])


def sash(s, a):
    s.rect(a["tx0"], a["ty1"] - 2, a["tx1"], a["ty1"] - 2, C["gold"][0])
    s.rect(a["cx"] - 1, a["ty0"] + 1, a["cx"], a["ty1"] + 4, C["gold"][1])


def wide_hat(s, a):
    x0, x1, y0 = a["hx0"], a["hx1"], a["hy0"]
    s.rect(x0 - 3, y0 + 3, x1 + 3, y0 + 3, C["tan"][0])
    s.rect(x0 - 2, y0 + 4, x1 + 2, y0 + 4, C["tan"][1])
    s.rect(x0 + 2, y0 - 1, x1 - 2, y0 + 2, C["tan"][0])
    s.rect(x1 - 2, y0 - 1, x1 - 2, y0 + 2, C["tan"][1])
    s.rect(x0 + 2, y0 + 2, x1 - 2, y0 + 2, C["leaf"][0])


def satchel(s, a):
    s.rect(a["tx0"] + 1, a["ty0"], a["tx1"] - 1, a["ty0"], C["leather"][1])
    s.block(a["tx1"] - 2, a["ty1"] - 2, a["tx1"] + 2, a["ty1"] + 1, C["leather"])


def herb_bundle(s, a):  # sickle in the viewer-left hand
    x, y = a["lhand"]
    s.rect(x, y - 2, x, y + 1, C["wood"][0])
    for dx, dy in ((0, -3), (-1, -4), (-2, -5), (-2, -6), (-1, -7), (0, -7)):
        s.px(x + dx, y + dy, C["steel"][2])
    s.px(x - 3, y - 5, C["steel"][0])


def daggers(s, a):  # a long knife in each hand, blades angled out
    for (x, y), d in ((a["lhand"], -1), (a["rhand"], 1)):
        s.px(x, y + 1, C["gold"][1])
        for i in range(4):
            s.px(x + d * (i // 2), y - 1 - i, C["steel"][2] if i < 3 else C["steel"][0])


def silver_hair(s, a):
    x0, x1, y0, y1 = a["hx0"], a["hx1"], a["hy0"], a["hy1"]
    r = C["hair_silver"]
    s.rect(x0 - 1, y0 + 2, x0, y1 + 3, r[0])
    s.rect(x1, y0 + 2, x1 + 1, y1 + 3, r[1])


def orb(s, a):  # glowing orb floating over the viewer-right hand
    x, y = a["rhand"][0] + 1, a["rhand"][1] - 4
    s.rect(x - 1, y - 2, x + 1, y, C["glow_blue"][0])
    s.rect(x - 2, y - 1, x + 2, y - 1, C["glow_blue"][0])
    s.px(x + 1, y, C["glow_blue"][1])
    s.px(x - 1, y - 2, (255, 255, 255))


def orb_glow(s, a):
    x, y = a["rhand"][0] + 1, a["rhand"][1] - 4
    for q in ((x - 3, y - 3), (x + 3, y - 3), (x, y - 5), (x + 3, y + 1)):
        if s.p.get(q) in (None, OUT):
            s.px(*q, C["glow_blue"][1])


def long_hair(color):
    def f(s, a):
        r = C[color]
        s.rect(a["hx0"] - 1, a["hy0"] + 3, a["hx0"], a["hy1"] + 2, r[0])
        s.rect(a["hx1"], a["hy0"] + 3, a["hx1"] + 1, a["hy1"] + 2, r[1])
    return f


def bow(s, a):  # tall recurve bow in the viewer-left hand, bulging outwards
    x = a["lhand"][0] - 1
    top, bot = a["hy0"] - 2, min(30, a["ty1"] + 4)
    n = bot - top
    for y in range(top, bot + 1):
        t = (y - top) / n
        dx = 3 if 0.3 <= t <= 0.7 else (2 if 0.15 <= t <= 0.85 else (1 if 0.05 < t < 0.95 else 0))
        s.px(x - dx, y, C["wood"][0])
        if dx >= 2:
            s.px(x - dx + 1, y, C["wood"][1])
    s.rect(x, top + 1, x, bot - 1, C["ivory"][1])


def quiver(s, a):
    x = a["tx1"] + 1
    s.rect(x, a["hy0"] + 2, x + 1, a["ty0"] + 2, C["leather"][0])
    s.px(x, a["hy0"] + 1, C["ivory"][0])
    s.px(x + 1, a["hy0"] + 1, C["leaf"][0])
    s.rect(a["tx0"], a["ty0"], a["tx1"], a["ty0"], C["leather"][1])


def miner_helmet(s, a):
    x0, x1, y0 = a["hx0"], a["hx1"], a["hy0"]
    s.rect(x0 - 1, y0 + 3, x1 + 1, y0 + 3, C["iron"][1])
    s.rect(x0, y0, x1, y0 + 2, C["iron"][0])
    s.rect(x0 + 1, y0 - 1, x1 - 1, y0 - 1, C["iron"][0])
    s.rect(x1 - 2, y0 - 1, x1, y0 + 2, C["iron"][1])
    s.rect(x0 + 1, y0, x0 + 2, y0, C["iron"][2])
    s.rect(a["cx"] - 1, y0 + 1, a["cx"], y0 + 2, C["flame"][0])


def lamp_glow(s, a):
    s.px(a["cx"] - 1, a["hy0"] - 2, C["flame"][1])
    s.px(a["cx"], a["hy0"] - 2, C["flame"][1])


def pickaxe(s, a):
    x, y = a["rhand"]
    for i in range(9):
        s.px(x - i // 2 + 1, y - i, C["wood"][0])
    hx, hy = x - 3, y - 9
    s.rect(hx - 2, hy, hx + 5, hy, C["steel"][0])
    s.px(hx - 3, hy + 1, C["steel"][1])
    s.px(hx + 6, hy + 1, C["steel"][1])
    s.rect(hx - 1, hy - 1, hx + 4, hy - 1, C["steel"][2])


def belt(s, a):
    s.rect(a["tx0"], a["ty1"] - 1, a["tx1"], a["ty1"] - 1, C["leather"][1])
    s.px(a["cx"], a["ty1"] - 1, C["gold"][0])


def iron_cap(s, a):
    x0, x1, y0 = a["hx0"], a["hx1"], a["hy0"]
    s.rect(x0, y0, x1, y0 + 3, C["iron"][0])
    s.rect(x1 - 2, y0, x1, y0 + 3, C["iron"][1])
    s.rect(x0, y0 + 3, x1, y0 + 3, C["gold"][1])
    s.px(x0 - 1, y0 + 1, C["ivory"][1])
    s.px(x1 + 1, y0 + 1, C["ivory"][1])


def apron(color):
    def f(s, a):
        s.rect(a["cx"] - 3, a["ty0"] + 2, a["cx"] + 2, a["ty1"] + 2, C[color][0])
        s.rect(a["cx"] + 2, a["ty0"] + 2, a["cx"] + 2, a["ty1"] + 2, C[color][1])
    return f


def hammer(s, a):  # rune hammer, big iron head with a glowing rune
    x, y = a["lhand"]
    s.rect(x, y - 7, x, y + 1, C["wood"][0])
    s.block(x - 3, y - 11, x + 3, y - 7, C["iron"], edge="rl")
    s.rect(x - 1, y - 10, x + 1, y - 10, C["rune"][0])
    s.px(x, y - 9, C["rune"][0])


def rune_glow(s, a):
    x, y = a["lhand"]
    s.px(x, y - 12, C["rune"][1])


def goggles(s, a):
    y = a["hy0"] + 3
    s.rect(a["hx0"], y, a["hx1"], y, C["leather"][1])
    s.rect(a["cx"] - 4, y - 1, a["cx"] - 2, y, C["gold"][0])
    s.rect(a["cx"] + 1, y - 1, a["cx"] + 3, y, C["gold"][0])
    s.px(a["cx"] - 3, y - 1, C["glow_blue"][1])
    s.px(a["cx"] + 2, y - 1, C["glow_blue"][1])


def wrench(s, a):  # big wrench raised in the viewer-left hand
    x, y = a["lhand"]
    for i in range(8):
        s.px(x - (i // 4), y - i, C["steel"][0])
        s.px(x - (i // 4) + 1, y - i, C["steel"][1])
    tx, ty = x - 3, y - 11
    s.rect(tx, ty, tx + 4, ty + 2, C["steel"][0])
    s.rect(tx + 1, ty, tx + 2, ty + 1, OUT)
    s.rect(tx + 4, ty, tx + 4, ty + 2, C["steel"][1])


def toolbelt(s, a):
    s.rect(a["tx0"], a["ty1"] - 1, a["tx1"], a["ty1"] - 1, C["leather"][1])
    s.px(a["tx0"] + 1, a["ty1"], C["steel"][2])
    s.px(a["tx1"] - 1, a["ty1"], C["gold"][0])


CLASSES = {
    "paladin": dict(cloth="steel", arm="steel", gloves="steel", legs="steel", torso=[tabard], head=[helm], gear=[kite_shield]),
    "cleric": dict(cloth="ivory", robe=True, hair="hair_brown", torso=[sash], head=[hood("ivory")], gear=[staff_candle], glow=[candle_flame]),
    "herbalist": dict(cloth="olive", hair="hair_brown", torso=[satchel], head=[wide_hat], gear=[herb_bundle]),
    "thief": dict(cloth="dleather", hair="hair_dark", head=[hood("dleather"), shadow_face], gear=[daggers]),
    "mage": dict(cloth="charcoal", robe=True, hair="hair_silver", head=[silver_hair], gear=[orb], glow=[orb_glow]),
    "archer": dict(cloth="leather", hair="hair_ash", torso=[quiver], head=[long_hair("hair_ash")], gear=[bow]),
    "miner": dict(cloth="leather", hair="hair_brown", beard="beard_red", torso=[belt], head=[miner_helmet], gear=[pickaxe], glow=[lamp_glow]),
    "runemaster": dict(cloth="iron", arm="iron", hair="hair_dark", beard="beard_grey", torso=[apron("leather")], head=[iron_cap], gear=[hammer], glow=[rune_glow]),
    "engineer": dict(cloth="tan", hair="hair_brown", beard="beard_red", torso=[toolbelt, apron("leather")], head=[goggles], gear=[wrench]),
}
ORDER = [("paladin", "human"), ("cleric", "human"), ("herbalist", "human"),
         ("thief", "elf"), ("mage", "elf"), ("archer", "elf"),
         ("miner", "dwarf"), ("runemaster", "dwarf"), ("engineer", "dwarf")]
NAMES = {"paladin": "팔라딘", "cleric": "성직자", "herbalist": "약초사", "thief": "시프", "mage": "마법사",
         "archer": "아처", "miner": "광부", "runemaster": "룬마스터", "engineer": "기술자"}


def variant(v, cls, race):
    if v == "A":
        return build(cls, "human", None)
    if v == "C":
        return build(cls, "human", race if race != "human" else None)
    return build(cls, "big" if cls == "paladin" else race, race if race != "human" else None)


def floor(w, h):
    import random
    rnd = random.Random(7)
    fw, fh = w, h
    w, h = (w + 15) // 16 * 16, (h + 15) // 16 * 16
    im = Image.new("RGBA", (w, h))
    base, mortar, hi, lo = (96, 86, 76), (58, 50, 46), (114, 104, 92), (82, 74, 66)
    for ty in range(0, h, 16):
        for tx in range(0, w, 16):
            off = 8 if (ty // 16) % 2 else 0
            for y in range(16):
                for x in range(16):
                    c = base
                    if y == 15 or (x + off) % 16 == 15:
                        c = mortar
                    elif y == 0 or (x + off) % 16 == 0:
                        c = hi
                    elif rnd.random() < 0.08:
                        c = lo
                    im.putpixel((tx + x, ty + y), c + (255,))
    return im.crop((0, 0, fw, fh))


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    rows = [("A", "A안  같은 체형, 종족 표시 없음 (도구·옷으로만 구분)"),
            ("C", "A'안  같은 체형 + 엘프 귀·드워프 수염"),
            ("B", "B안  종족별 체형 (인간 20 / 엘프 23 / 드워프 17px, 팔라딘은 넓게)")]
    step, lab = 26, 14
    W = 9 * step + 2 * 10 + 8
    rowh = 40
    # 1x scene: three option rows on the floor, plus a silhouette row for A and B
    scene = floor(W, rowh * 5)
    sil_rows = []
    for r, (v, _) in enumerate(rows):
        for i, (cls, race) in enumerate(ORDER):
            im = variant(v, cls, race)
            x = 6 + i * step + (i // 3) * 10
            scene.alpha_composite(im, (x, r * rowh + 6))
            im.save(out / f"{v}_{cls}.png")
    for r, v in enumerate(["A", "B"]):
        for i, (cls, race) in enumerate(ORDER):
            im = variant(v, cls, race)
            a = im.getchannel("A")
            sil = Image.new("RGBA", im.size, (24, 18, 16, 255))
            sil.putalpha(a)
            x = 6 + i * step + (i // 3) * 10
            scene.alpha_composite(sil, (x, (3 + r) * rowh + 6))
    scene.save(out / "sample_1x.png")
    Z = 4
    big = scene.resize((scene.width * Z, scene.height * Z), Image.NEAREST)
    pad_l = 380
    board = Image.new("RGBA", (big.width + pad_l, big.height + 60), (22, 18, 16, 255))
    board.alpha_composite(big, (pad_l, 60))
    d = ImageDraw.Draw(board)
    try:
        font = ImageFont.truetype("malgun.ttf", 22)
        small = ImageFont.truetype("malgun.ttf", 18)
    except OSError:
        font = small = ImageFont.load_default()
    labels = [t for _, t in rows] + ["A안 실루엣", "B안 실루엣"]
    for r, t in enumerate(labels):
        y = 60 + r * rowh * Z + 50
        words, line, lines = t.split(" "), "", []
        for w_ in words:
            if len(line) + len(w_) > 16:
                lines.append(line)
                line = w_
            else:
                line = (line + " " + w_).strip()
        lines.append(line)
        for j, ln in enumerate(lines):
            d.text((14, y + j * 28), ln, fill=(240, 200, 110), font=font)
    for i, (cls, race) in enumerate(ORDER):
        x = pad_l + (6 + i * step + (i // 3) * 10) * Z + 6
        d.text((x, 14), NAMES[cls], fill=(230, 220, 200), font=small)
    for g, nm in enumerate(["인간", "엘프", "드워프"]):
        x = pad_l + (6 + g * 3 * step + g * 10) * Z
        d.text((x, 38), nm, fill=(170, 160, 150), font=small)
    board.save(out / "sample_zoom.png")
    print("saved", out / "sample_zoom.png", board.size)


if __name__ == "__main__":
    main()

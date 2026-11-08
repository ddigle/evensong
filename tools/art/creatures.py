# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""M11 사냥감·희귀 생물 다섯 스프라이트 손질 (2026-11-08, 03-pixel/prompts.md "PixelLab 16차"). 생성 없음, 다시 돌리면 같은 파일.

실행 (어디서 돌려도 된다. 경로는 이 파일 기준. 고정 버전은 creatures.py.lock):
    uv run -q --python 3.14.6 --script tools/art/creatures.py
    또는 uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I tools/art/creatures.py
    (--python 3.14.6을 빼면 SSH·샌드박스 셸에서 uv가 3.14 바로가기를 못 읽을 수 있다, os error 448)
    raw <폴더>  PixelLab에서 내려받은 zip 다섯을 <폴더>/<kind>/에 푼 것에서 raw 시트(v01)를 묶는다(픽셀은 옮기기만)

kind: hare 토끼, deer 사슴, lamp_fox 등불 여우, silver_stag 은빛 수사슴, ash_owl 재 올빼미 (이름은 game/core/config.gd CREATURES, 자리 표시)
읽는 것 (03-pixel, PixelLab에서 받은 그대로):
    <kind>_v01_rotations.png   회전 남·동·북·서, 생성 캔버스 그대로 (hare·ash_owl 28, deer 48, lamp_fox 36, silver_stag 52)
    <kind>_v01_walk.png        걷기 템플릿 6장, 줄 남·동·북, 생성 캔버스 그대로
    base_body_v02_idle.png, heretic_v02_idle.png, merchant_v02_idle.png   크기 비교용
쓰는 것 (03-pixel):
    <kind>_v02_walk.png        CELL[kind] 칸, 줄 남·동·북, 6열, 발 = 칸 맨 아래 줄
    <kind>_v02_rotations.png   CELL[kind] 칸 4열 남·동·북·서 (서 = 동 좌우 반전, R19), 발 = 칸 맨 아래 줄
    creatures_v02_anims.gif    줄 = 생물 다섯, 칸 남·동·북·서(동 반전) 걷기, 3배, 프레임당 150ms (GIF_MS, 게임 값은 game/ 쪽에서 정함)
    creatures_v02_scale_check.png  위 1배, 아래 4배. 줄 남·동마다 기본 몸 · 이단 · 상인 idle 첫 프레임과 생물 다섯 회전.
                               빨간 선 = 발 줄. 글자는 그리지 않는다

손질 순서:
 1 손 고침 (raw 좌표 표, raw를 바꾸면 표를 다시 본다)
   - 사슴 남 2번 발밑 회색 덩어리 (DEER_BLOB): y >= 32의 #877f7c를 지운다
   - 올빼미 동 걷기 붉은 눈 (OWL_RED_EYE): #561021을 남쪽 눈동자 색 #211a1f로
   - 올빼미 북 (회전 + 걷기 0·1·2·4·5): 얼굴 상자 OWL_FACE 안, 실루엣 가장자리가 아닌 픽셀 중 밝지 않거나(L* < FEATHER_L)
     채도가 있는 것(눈·부리·얼굴 테)을 이웃의 밝은 깃털 색(8방향 중 가장 흔한 색)으로 덮는다. 다리·꼬리·목 줄은 그대로
   - 올빼미 북 3번(앞모습)은 고친 2번의 y <= 19를 쓰고 y 20~24에 가운데 꼬리(OWL_N3_TAIL)를 그려 넣는다
 2 떨어진 점 지우기: 불투명 픽셀 8방향 덩어리 중 SPECK 이하 크기 (16차 raw에는 없었다. 규칙만 둔다)
 3 외곽선: 실루엣 가장자리 픽셀이 밝으면(L* >= DARK_L) 바깥 1px를 그 생물의 외곽선 색(OUTLINE)으로.
   발 줄(아래 4에서 칸 맨 아래가 될 줄) 아래로는 더하지 않고 그 픽셀을 외곽선으로 바꾼다 (이단 13차와 같음).
   은빛 수사슴은 원본에 외곽선이 없어 여기서 둘레가 생긴다. 가로 맞춤 전에 해서 외곽선까지 넣은 무게중심으로 맞춘다
 4 칸에 놓기 (CELL, 4의 배수, 그림은 1배 그대로): 가로는 방향마다 걷기 6장의 무게중심 평균이 칸 가운데 축((W-1)/2)에
   오게 한 값(회전도 같은 값, 서 = 동 반전 때 몸이 옮겨지지 않게). 세로는 걷기는 방향마다 6장 중 가장 낮은 픽셀을,
   회전은 그림마다 가장 낮은 픽셀을 칸 맨 아래 줄에 (layers.py pivot·이단 걷기와 같은 규칙. 템플릿의 발 움직임은 그대로)
 5 검사: 칸 안에 들어가는지, 반투명 0, 프레임마다 한 덩어리, 가장자리 외곽선 비율. 키·폭(px)을 찍는다
"""
import json
import os
import sys
from collections import Counter

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
PIX = os.path.join(ROOT, "assets", "concept", "03-pixel")

KINDS = ("hare", "deer", "lamp_fox", "silver_stag", "ash_owl")
CANVAS = {"hare": 28, "deer": 48, "lamp_fox": 36, "silver_stag": 52, "ash_owl": 28}
CELL = {"hare": (24, 24), "deer": (40, 36), "lamp_fox": (36, 24), "silver_stag": (44, 44), "ash_owl": (16, 24)}  # (W, H), 4의 배수
DIRS = ("south", "east", "north")
ROT_DIRS = ("south", "east", "north", "west")
FRAMES = 6
SPECK = 2
DARK_L = 30
FEATHER_L = 85
# 생물마다 원본에서 가장자리에 가장 많이 쓰인 어두운 색. 수사슴은 원본에 외곽선이 없어 자기 발굽의 갈흑(#271c1b)
OUTLINE = {"hare": (0x35, 0x24, 0x2F), "deer": (0x41, 0x22, 0x2B), "lamp_fox": (0x1A, 0x14, 0x19),
           "silver_stag": (0x27, 0x1C, 0x1B), "ash_owl": (0x2B, 0x24, 0x28)}
DEER_BLOB = ("south", 2, 32, (0x87, 0x7F, 0x7C))           # 방향, 프레임, 이 줄부터 아래, 색
OWL_RED_EYE = ((0x56, 0x10, 0x21), (0x21, 0x1A, 0x1F))     # 동 걷기 눈: 이 색 -> 남쪽 눈동자 색
OWL_FACE = (10, 6, 18, 11)                                  # 북 얼굴 상자 x0, y0, x1, y1 (raw 28칸 좌표, 끝 제외)
OWL_N3_FROM = 2                                             # 북 3번의 몸(y <= 19)을 가져올 프레임
# 북 3번 꼬리 (y 20~24, x 10부터). o = 외곽선 #2b2428, w = 흰 깃 #fcfbfc, g = 밝은 회색 #dfdcdc, s = 회색 #c8c6c8, . = 빔.
# 2번(꼬리 오른쪽)과 4번(꼬리 왼쪽) 사이의 가운데 꼬리. 폭 7px(y 20·21, x 11~17)에서 끝 2px(y 24)로 좁아진다
OWL_N3_TAIL = (
    ".owwsgwo",   # y 20
    ".owwwwwo",   # y 21
    ".owwwwo.",   # y 22 (x 11~16)
    "..owwo..",   # y 23
    "...oo...",   # y 24
)
OWL_N3_COLOURS = {"o": (0x2B, 0x24, 0x28), "w": (0xFC, 0xFB, 0xFC), "g": (0xDF, 0xDC, 0xDC), "s": (0xC8, 0xC6, 0xC8)}
GIF_MS = 150
BG = (120, 140, 90, 255)     # 비교 그림 바탕 (풀빛, merchant.py와 같음)
FEET_LINE = (220, 40, 40, 255)


def load(name):
    return np.array(Image.open(os.path.join(PIX, name)).convert("RGBA"))


def save(a, name):
    Image.fromarray(np.ascontiguousarray(a)).save(os.path.join(PIX, name))
    print("wrote", name, a.shape[1], "x", a.shape[0])


def lstar(c):
    def lin(v):
        v = v / 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    y = 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])
    return 116 * (y ** (1 / 3) if y > 216 / 24389 else (24389 / 27 * y + 16) / 116) - 16


def chroma(c):
    return int(max(c[:3])) - int(min(c[:3]))


def pack_raw(src):
    """내려받은 zip을 푼 폴더(<src>/<kind>/Idle/...)에서 raw 시트 두 장씩을 만든다. 픽셀은 그대로 옮기기만 한다."""
    for k in KINDS:
        c = CANVAS[k]
        base = os.path.join(src, k)
        with open(os.path.join(base, "metadata.json"), encoding="utf-8") as fh:
            frames = json.load(fh)["states"][0]["frames"]
        rot = np.zeros((c, c * 4, 4), np.uint8)
        for i, d in enumerate(ROT_DIRS):
            a = np.array(Image.open(os.path.join(base, frames["rotations"][d])).convert("RGBA"))
            assert a.shape == (c, c, 4), (k, d, a.shape)
            rot[:, i * c:(i + 1) * c] = a
        save(rot, f"{k}_v01_rotations.png")
        (anim,) = frames["animations"].values()
        walk = np.zeros((c * 3, c * FRAMES, 4), np.uint8)
        for r, d in enumerate(DIRS):
            assert len(anim[d]) == FRAMES, (k, d)
            for i, p in enumerate(anim[d]):
                a = np.array(Image.open(os.path.join(base, p)).convert("RGBA"))
                assert a.shape == (c, c, 4), (k, d, i, a.shape)
                walk[r * c:(r + 1) * c, i * c:(i + 1) * c] = a
        save(walk, f"{k}_v01_walk.png")


# ---------------------------------------------------------------------------------------------
# 1 손 고침
# ---------------------------------------------------------------------------------------------
def fix_deer_blob(walk, log):
    d, i, y0, col = DEER_BLOB
    f = walk[d][i]
    hit = (f[:, :, 3] > 0) & np.all(f[:, :, :3] == col, axis=2)
    hit[:y0] = False
    n = int(hit.sum())
    assert n > 0
    f[hit] = 0
    log.append(f"deer blob walk {d} {i}: -{n} px #{col[0]:02x}{col[1]:02x}{col[2]:02x} at y >= {y0}")


def fix_owl_red_eye(walk, log):
    src, dst = OWL_RED_EYE
    for i, f in enumerate(walk["east"]):
        hit = (f[:, :, 3] > 0) & np.all(f[:, :, :3] == src, axis=2)
        f[hit, :3] = dst
        if hit.any():
            ys, xs = np.nonzero(hit)
            log.append(f"owl red eye walk east {i}: {int(hit.sum())} px at " +
                       " ".join(f"{x},{y}" for y, x in zip(ys, xs)))


def paint_face(f, log, tag):
    """얼굴 상자 안의 눈·부리·얼굴 테를 이웃의 밝은 깃털 색으로 덮어 뒤통수로 만든다."""
    x0, y0, x1, y1 = OWL_FACE
    op = f[:, :, 3] > 0
    H, W = op.shape

    def interior(y, x):
        return all(0 <= y + dy < H and 0 <= x + dx < W and op[y + dy, x + dx]
                   for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)))

    def feather(c):
        return lstar(c) >= FEATHER_L and chroma(c) <= 24

    todo = {(y, x) for y in range(y0, y1) for x in range(x0, x1)
            if op[y, x] and interior(y, x) and not feather(f[y, x])}
    total = len(todo)
    while todo:
        done = {}
        for y, x in sorted(todo):
            cnt = Counter(tuple(int(v) for v in f[y + dy, x + dx]) for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                          if (dy or dx) and (y + dy, x + dx) not in todo and op[y + dy, x + dx]
                          and feather(f[y + dy, x + dx]))
            if cnt:
                done[(y, x)] = sorted(cnt.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]
        assert done, (tag, sorted(todo))
        for (y, x), c in done.items():
            f[y, x] = c
        todo -= set(done)
    log.append(f"owl face {tag}: {total} px painted to back feathers")


def build_owl_n3(walk, log):
    f = walk["north"][OWL_N3_FROM].copy()
    f[20:] = 0
    for dy, row in enumerate(OWL_N3_TAIL):
        for dx, ch in enumerate(row):
            if ch != ".":
                f[20 + dy, 10 + dx] = (*OWL_N3_COLOURS[ch], 255)
    before = walk["north"][3]
    log.append(f"owl north 3: front view replaced by frame {OWL_N3_FROM} (y <= 19) + centre tail "
               f"({int((np.abs(before.astype(int) - f.astype(int)).sum(axis=2) > 0).sum())} px differ from raw)")
    walk["north"][3] = f


# ---------------------------------------------------------------------------------------------
# 2~4 공통 손질
# ---------------------------------------------------------------------------------------------
def components(op):
    H, W = op.shape
    seen = np.zeros_like(op)
    out = []
    for y in range(H):
        for x in range(W):
            if op[y, x] and not seen[y, x]:
                stack = [(y, x)]
                seen[y, x] = True
                comp = []
                while stack:
                    cy, cx = stack.pop()
                    comp.append((cy, cx))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < H and 0 <= nx < W and op[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True
                                stack.append((ny, nx))
                out.append(comp)
    return out


def drop_specks(f, log, tag):
    for comp in components(f[:, :, 3] > 0):
        if len(comp) <= SPECK:
            for cy, cx in comp:
                f[cy, cx] = 0
            log.append(f"speck {tag}: {len(comp)} px at {comp[0][1]},{comp[0][0]}")


def centre_x(f):
    w = (f[:, :, 3] > 0).sum(axis=0)
    return float((np.arange(f.shape[1]) * w).sum() / w.sum())


def bottom(f):
    return int(np.nonzero(f[:, :, 3] > 0)[0].max())


def place(f, W, H, ox, oy, tag):
    out = np.zeros((H, W, 4), np.uint8)
    ys, xs = np.nonzero(f[:, :, 3] > 0)
    assert xs.min() + ox >= 0 and xs.max() + ox <= W - 1 and ys.min() + oy >= 0 and ys.max() + oy <= H - 1, \
        (tag, xs.min() + ox, xs.max() + ox, ys.min() + oy, ys.max() + oy, W, H)
    out[ys + oy, xs + ox] = f[ys, xs]
    return out


def outline(f, col, ground, log, tag):
    """ground = 칸 맨 아래 줄이 될 줄 (raw 좌표). 그 아래와 캔버스 밖으로는 더하지 않고 그 픽셀을 외곽선으로."""
    op = f[:, :, 3] > 0
    H, W = op.shape
    add, own = set(), set()
    for y, x in zip(*np.nonzero(op)):
        if lstar(f[y, x]) < DARK_L:
            continue
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            ny, nx = y + dy, x + dx
            if not (0 <= ny <= ground and 0 <= nx < W):
                own.add((y, x))
            elif not op[ny, nx]:
                add.add((ny, nx))
    for y, x in sorted(add | own):
        f[y, x] = (*col, 255)
    if add or own:
        log.append(f"outline {tag}: +{len(add)} px outside, {len(own)} px recoloured on the feet row")


def edge_dark(f):
    op = f[:, :, 3] > 0
    H, W = op.shape
    edge = dark = 0
    for y, x in zip(*np.nonzero(op)):
        if any(not (0 <= y + dy < H and 0 <= x + dx < W) or not op[y + dy, x + dx]
               for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0))):
            edge += 1
            dark += lstar(f[y, x]) < DARK_L
    return dark / edge


def size(f):
    ys, xs = np.nonzero(f[:, :, 3] > 0)
    return int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)


def build(k, log, meas):
    c = CANVAS[k]
    W, H = CELL[k]
    walk_raw = load(f"{k}_v01_walk.png")
    rot_raw = load(f"{k}_v01_rotations.png")
    assert walk_raw.shape == (c * 3, c * FRAMES, 4) and rot_raw.shape == (c, c * 4, 4)
    walk = {d: [walk_raw[r * c:(r + 1) * c, i * c:(i + 1) * c].copy() for i in range(FRAMES)] for r, d in enumerate(DIRS)}
    rot = {d: rot_raw[:, i * c:(i + 1) * c].copy() for i, d in enumerate(DIRS)}

    if k == "deer":
        fix_deer_blob(walk, log)
    if k == "ash_owl":
        fix_owl_red_eye(walk, log)
        paint_face(rot["north"], log, "rot north")
        for i in (0, 1, 2, 4, 5):
            paint_face(walk["north"][i], log, f"walk north {i}")
        build_owl_n3(walk, log)

    for d in DIRS:
        for i, f in enumerate(walk[d]):
            drop_specks(f, log, f"{k} walk {d} {i}")
        drop_specks(rot[d], log, f"{k} rot {d}")

    axis = (W - 1) / 2
    walk_out = np.zeros((H * 3, W * FRAMES, 4), np.uint8)
    rot_out = np.zeros((H, W * 4, 4), np.uint8)
    for r, d in enumerate(DIRS):
        ground = max(bottom(f) for f in walk[d])
        for i, f in enumerate(walk[d]):
            outline(f, OUTLINE[k], ground, log, f"{k} walk {d} {i}")
        rground = bottom(rot[d])
        outline(rot[d], OUTLINE[k], rground, log, f"{k} rot {d}")
        ox = int(round(axis - sum(centre_x(f) for f in walk[d]) / FRAMES))
        oy = (H - 1) - ground
        cs = []
        for i, f in enumerate(walk[d]):
            g = place(f, W, H, ox, oy, f"{k} walk {d} {i}")
            walk_out[r * H:(r + 1) * H, i * W:(i + 1) * W] = g
            cs.append(centre_x(g))
        ry = (H - 1) - rground
        g = place(rot[d], W, H, ox, ry, f"{k} rot {d}")
        rot_out[:, r * W:(r + 1) * W] = g
        gaps = [(H - 1) - bottom(walk_out[r * H:(r + 1) * H, i * W:(i + 1) * W]) for i in range(FRAMES)]
        log.append(f"{k} {d}: cell x = raw x {ox:+d}, walk cell y = raw y {oy:+d}, rot {ry:+d}; "
                   f"walk centre x {min(cs):.2f}~{max(cs):.2f} (axis {axis}), rot centre x {centre_x(g):.2f}; "
                   f"walk feet gap per frame {gaps}")
    rot_out[:, 3 * W:4 * W] = rot_out[:, W:2 * W][:, ::-1]

    # 5 검사
    for name, sheet, rows, cols in (("walk", walk_out, 3, FRAMES), ("rot", rot_out, 1, 4)):
        assert not ((sheet[:, :, 3] > 0) & (sheet[:, :, 3] < 255)).any()
        for r in range(rows):
            for i in range(cols):
                f = sheet[r * H:(r + 1) * H, i * W:(i + 1) * W]
                n = len(components(f[:, :, 3] > 0))
                assert n == 1, (k, name, r, i, n)
    eds = [edge_dark(walk_out[r * H:(r + 1) * H, i * W:(i + 1) * W]) for r in range(3) for i in range(FRAMES)]
    eds += [edge_dark(rot_out[:, i * W:(i + 1) * W]) for i in range(4)]
    ncol = len({tuple(p[:3]) for p in np.concatenate([walk_out.reshape(-1, 4), rot_out.reshape(-1, 4)]) if p[3]})
    log.append(f"{k}: cell {W}x{H}, edge outline {min(eds):.0%}~{max(eds):.0%}, {ncol} colours")

    m = {}
    for r, d in enumerate(DIRS):
        rw, rh = size(rot_out[:, r * W:(r + 1) * W])
        ws = [size(walk_out[r * H:(r + 1) * H, i * W:(i + 1) * W]) for i in range(FRAMES)]
        m[d] = (rw, rh, min(w for w, _ in ws), max(w for w, _ in ws), min(h for _, h in ws), max(h for _, h in ws))
    meas[k] = m
    save(walk_out, f"{k}_v02_walk.png")
    save(rot_out, f"{k}_v02_rotations.png")
    return walk_out, rot_out


def anims_gif(sheets):
    sc = 3
    cw = max(CELL[k][0] for k in KINDS)
    gap = 2
    rows_h = [CELL[k][1] for k in KINDS]
    Wt = (cw * 4) * sc
    Ht = (sum(rows_h) + gap * (len(KINDS) - 1)) * sc
    frames = []
    for i in range(FRAMES):
        im = Image.new("RGBA", (Wt, Ht), BG)
        y = 0
        for k in KINDS:
            W, H = CELL[k]
            walk = sheets[k][0]
            for col in range(4):
                r = col if col < 3 else 1
                cell = walk[r * H:(r + 1) * H, i * W:(i + 1) * W]
                if col == 3:
                    cell = cell[:, ::-1]
                img = Image.fromarray(np.ascontiguousarray(cell)).resize((W * sc, H * sc), Image.NEAREST)
                im.alpha_composite(img, ((col * cw + (cw - W) // 2) * sc, y * sc))
            y += H + gap
        frames.append(im.convert("P", palette=Image.ADAPTIVE, colors=255))
    frames[0].save(os.path.join(PIX, "creatures_v02_anims.gif"), save_all=True, append_images=frames[1:],
                   duration=GIF_MS, loop=0, disposal=2)
    print("wrote creatures_v02_anims.gif", Wt, "x", Ht, f"{FRAMES} frames {GIF_MS} ms")


def scale_check(sheets):
    humans = [load("base_body_v02_idle.png"), load("heretic_v02_idle.png"), load("merchant_v02_idle.png")]
    gap = 4
    rows = []
    for r, d in enumerate(("south", "east")):
        cells = [h[r * 32:(r + 1) * 32, 0:32] for h in humans]
        for k in KINDS:
            W, H = CELL[k]
            cells.append(sheets[k][1][:, r * W:(r + 1) * W])
        rows.append(cells)
    Hmax = max(c.shape[0] for c in rows[0])
    # 1배 띠: 남 줄, 빈칸, 동 줄을 한 줄로. 4배: 남 줄, 동 줄
    w1 = sum(c.shape[1] + gap for c in rows[0]) * 2 + gap * 4
    big = 4
    w4 = (sum(c.shape[1] + gap for c in rows[0])) * big
    Wt = max(w1, w4)
    Ht = Hmax + gap + (Hmax * big + gap * big) * 2
    im = Image.new("RGBA", (Wt, Ht), BG)
    d = ImageDraw.Draw(im)
    x = 0
    for n, cells in enumerate(rows):
        for c in cells:
            im.alpha_composite(Image.fromarray(np.ascontiguousarray(c)), (x, Hmax - c.shape[0]))
            x += c.shape[1] + gap
        x += gap * 4
    d.line([(0, Hmax), (w1, Hmax)], fill=FEET_LINE)
    for n, cells in enumerate(rows):
        y0 = Hmax + gap + n * (Hmax * big + gap * big)
        x = 0
        for c in cells:
            img = Image.fromarray(np.ascontiguousarray(c)).resize((c.shape[1] * big, c.shape[0] * big), Image.NEAREST)
            im.alpha_composite(img, (x, y0 + (Hmax - c.shape[0]) * big))
            x += (c.shape[1] + gap) * big
        gy = y0 + Hmax * big
        d.line([(0, gy), (w4, gy)], fill=FEET_LINE)
    im.save(os.path.join(PIX, "creatures_v02_scale_check.png"))
    print("wrote creatures_v02_scale_check.png", Wt, "x", Ht)


def main(argv):
    if argv and argv[0] == "raw":
        pack_raw(argv[1])
        return
    log, meas, sheets = [], {}, {}
    for k in KINDS:
        sheets[k] = build(k, log, meas)
    anims_gif(sheets)
    scale_check(sheets)
    for line in log:
        print(line)
    print("size px (W x H): rotation | walk W range, H range")
    for k in KINDS:
        print(f"  {k}: " + "; ".join(f"{d} {m[0]}x{m[1]} | W {m[2]}~{m[3]}, H {m[4]}~{m[5]}" for d, m in meas[k].items()))


if __name__ == "__main__":
    main(sys.argv[1:])

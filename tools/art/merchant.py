# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""순례 상인 스프라이트 손질 (2026-11-01, 03-pixel/prompts.md "PixelLab 15차"). 생성 없음, 다시 돌리면 같은 파일.

실행 (어디서 돌려도 된다. 경로는 이 파일 기준. 고정 버전은 merchant.py.lock):
    uv run -q --python 3.14.6 --script tools/art/merchant.py
    또는 uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I tools/art/merchant.py
    (--python 3.14.6을 빼면 SSH·샌드박스 셸에서 uv가 3.14 바로가기를 못 읽을 수 있다, os error 448)

읽는 것 (03-pixel, PixelLab에서 받은 그대로):
    merchant_v01_rotations.png   회전 남·동·북·서 (character 5fd67914, v3 size 32)
    merchant_v01_idle.png        템플릿 breathing-idle, 줄 남·동·북, 32칸 4프레임
    base_body_v02_idle.png, heretic_v02_idle.png   크기·색 비교용
쓰는 것 (03-pixel):
    merchant_v02_idle.png        32칸, 줄 남·동·북, 4프레임, 발 y=31 (base_body_v02_idle과 같은 배치)
    merchant_v02_rotations.png   32칸 4열 남·동·북·서 (서 = 동 좌우 반전, R19), 발 y=31
    merchant_v02_anims.gif       줄 남·동·북·서(반전), idle 4프레임, 3배, 프레임당 200ms (게임 IDLE_FRAME_TIME 0.2초)
    merchant_v02_scale_check.png 위 1배, 아래 4배. 방향마다 기본 몸 · 상인 · 이단의 idle 첫 프레임. 빨간 선 = 발 줄 y=31.
                                 글자는 그리지 않는다

손질 순서:
 1 남쪽 얼굴 고정 (FACE): 템플릿이 프레임마다 눈·코를 다르게 그려(흰 눈빛, 옅은 파랑 점) 정면에서 얼굴이 깜빡인다.
   FACE_SRC 프레임의 얼굴 상자를 다른 프레임에 붙인다. 붙일 줄(dy)은 상자 위아래 둘레가 가장 잘 맞는 값을 고른다
 2 떨어진 점 지우기: 불투명 픽셀 8방향 덩어리 중 SPECK 이하 크기
 3 발 맞춤: idle은 프레임마다 가장 낮은 픽셀을 y=31 (서 있는 발이 숨쉬기 동안 뜨지 않게. 동쪽 0번만 원본에서 1px 낮다).
   회전은 그림마다 y=31
 4 가로 맞춤 (DX): 몸 무게중심이 기본 몸(남 15.3 · 동 15.4 · 북 15.8)과 같은 자리에 오게 방향마다 옮긴다.
   서 = 동 반전이 몸을 옮기지 않게 하는 것이 목적이다
 5 외곽선: 실루엣 가장자리 픽셀이 밝으면(L* >= DARK_L) 바깥 1px를 OUTLINE으로 (칸 밖·발 줄 아래로는 더하지 않음)
"""
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
PIX = os.path.join(ROOT, "assets", "concept", "03-pixel")

DIRS = ("south", "east", "north")
CELL = 32
GROUND = 31
FRAMES = 4
SPECK = 2
DX = {"south": 1, "east": 3, "north": 1}
FACE = (10, 9, 22, 15)       # 남쪽 얼굴 상자 x0, y0, x1, y1 (원본 32칸 좌표, 끝 제외)
FACE_SRC = 1                 # 흰 눈빛이 두 눈에 같이 있는 프레임
DARK_L = 30
OUTLINE = (2, 2, 1, 255)     # 원본 외곽선 색 (#020201)
BG = (120, 140, 90, 255)     # 비교 그림 바탕 (풀빛)


def load(name):
    return np.array(Image.open(os.path.join(PIX, name)).convert("RGBA"))


def save(a, name):
    Image.fromarray(a).save(os.path.join(PIX, name))


def lstar(c):
    def lin(v):
        v = v / 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    y = 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])
    return 116 * (y ** (1 / 3) if y > 216 / 24389 else (24389 / 27 * y + 16) / 116) - 16


def fix_face(frames, log):
    x0, y0, x1, y1 = FACE
    src = frames[FACE_SRC]
    box = src[y0:y1, x0:x1].copy()
    for i, f in enumerate(frames):
        if i == FACE_SRC:
            continue
        best = None
        for dy in (-1, 0, 1):
            ring = 0
            for yy in (y0 - 1, y1):
                a = src[yy, x0:x1]
                b = f[yy + dy, x0:x1]
                ring += int((np.abs(a.astype(int) - b.astype(int)).sum(axis=1) > 30).sum())
            if best is None or ring < best[0]:
                best = (ring, dy)
        dy = best[1]
        before = f[y0 + dy:y1 + dy, x0:x1]
        changed = int((np.abs(before.astype(int) - box.astype(int)).sum(axis=2) > 0).sum())
        f[y0 + dy:y1 + dy, x0:x1] = box
        log.append(f"face south {i}: dy {dy}, {changed} px from frame {FACE_SRC}")


def drop_specks(f, log, tag):
    op = f[:, :, 3] > 0
    seen = np.zeros_like(op)
    for y in range(CELL):
        for x in range(CELL):
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
                            if 0 <= ny < CELL and 0 <= nx < CELL and op[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True
                                stack.append((ny, nx))
                if len(comp) <= SPECK:
                    for cy, cx in comp:
                        f[cy, cx] = 0
                    log.append(f"speck {tag}: {len(comp)} px at {comp[0][1]},{comp[0][0]}")


def shift(f, dx, dy):
    out = np.zeros_like(f)
    ys, xs = np.nonzero(f[:, :, 3] > 0)
    assert xs.min() + dx >= 0 and xs.max() + dx < CELL and ys.min() + dy >= 0 and ys.max() + dy < CELL, (dx, dy)
    out[ys + dy, xs + dx] = f[ys, xs]
    return out


def outline(f, log, tag):
    op = f[:, :, 3] > 0
    add = []
    for y, x in zip(*np.nonzero(op)):
        if lstar(f[y, x]) < DARK_L:
            continue
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            ny, nx = y + dy, x + dx
            if 0 <= ny <= GROUND and 0 <= nx < CELL and not op[ny, nx]:
                add.append((ny, nx))
    for y, x in set(add):
        f[y, x] = OUTLINE
    if add:
        log.append(f"outline {tag}: +{len(set(add))} px")


def edge_dark(f):
    op = f[:, :, 3] > 0
    edge = dark = 0
    for y, x in zip(*np.nonzero(op)):
        if any(not (0 <= y + dy < CELL and 0 <= x + dx < CELL) or not op[y + dy, x + dx]
               for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0))):
            edge += 1
            dark += lstar(f[y, x]) < DARK_L
    return dark / edge


def centre_x(f):
    w = (f[:, :, 3] > 0).sum(axis=0)
    return float((np.arange(CELL) * w).sum() / w.sum())


def main():
    log = []
    idle_raw = load("merchant_v01_idle.png")
    rot_raw = load("merchant_v01_rotations.png")
    assert idle_raw.shape == (CELL * 3, CELL * FRAMES, 4) and rot_raw.shape == (CELL, CELL * 4, 4)

    idle = np.zeros_like(idle_raw)
    for r, d in enumerate(DIRS):
        frames = [idle_raw[r * CELL:(r + 1) * CELL, i * CELL:(i + 1) * CELL].copy() for i in range(FRAMES)]
        if d == "south":
            fix_face(frames, log)
        for i, f in enumerate(frames):
            drop_specks(f, log, f"idle {d} {i}")
            bottom = int(np.nonzero(f[:, :, 3] > 0)[0].max())
            g = shift(f, DX[d], GROUND - bottom)
            outline(g, log, f"idle {d} {i}")
            idle[r * CELL:(r + 1) * CELL, i * CELL:(i + 1) * CELL] = g
            log.append(f"idle {d} {i}: dy {GROUND - bottom}, dx {DX[d]}, centre x {centre_x(g):.2f}, "
                       f"edge outline {edge_dark(g):.0%}")
    save(idle, "merchant_v02_idle.png")

    rots = np.zeros_like(rot_raw)
    for c, d in enumerate(DIRS):
        f = rot_raw[:, c * CELL:(c + 1) * CELL].copy()
        drop_specks(f, log, f"rot {d}")
        bottom = int(np.nonzero(f[:, :, 3] > 0)[0].max())
        g = shift(f, DX[d], GROUND - bottom)
        outline(g, log, f"rot {d}")
        rots[:, c * CELL:(c + 1) * CELL] = g
    rots[:, 3 * CELL:4 * CELL] = rots[:, CELL:2 * CELL][:, ::-1]
    save(rots, "merchant_v02_rotations.png")

    # 움직이는 그림: 줄 남·동·북·서(동 반전), 3배
    sc = 3
    gif = []
    for i in range(FRAMES):
        im = Image.new("RGBA", (CELL * sc, CELL * 4 * sc), BG)
        for r in range(4):
            src = idle[(r if r < 3 else 1) * CELL:((r if r < 3 else 1) + 1) * CELL, i * CELL:(i + 1) * CELL]
            if r == 3:
                src = src[:, ::-1]
            im.alpha_composite(Image.fromarray(np.ascontiguousarray(src)).resize((CELL * sc, CELL * sc), Image.NEAREST),
                               (0, r * CELL * sc))
        gif.append(im.convert("P", palette=Image.ADAPTIVE, colors=255))
    gif[0].save(os.path.join(PIX, "merchant_v02_anims.gif"), save_all=True, append_images=gif[1:],
                duration=200, loop=0, disposal=2)

    # 크기 비교: 방향마다 기본 몸 · 상인 · 이단, 위 1배 아래 4배
    base = load("base_body_v02_idle.png")
    her = load("heretic_v02_idle.png")
    cells = []
    for r in range(3):
        for sheet in (base, idle, her):
            cells.append(sheet[r * CELL:(r + 1) * CELL, 0:CELL])
    n = len(cells)
    big = 4
    W = n * CELL * big
    H = CELL + 4 + CELL * big
    im = Image.new("RGBA", (W, H), BG)
    for k, c in enumerate(cells):
        cimg = Image.fromarray(np.ascontiguousarray(c))
        im.alpha_composite(cimg, (k * CELL * big + (CELL * big - CELL) // 2, 0))
        im.alpha_composite(cimg.resize((CELL * big, CELL * big), Image.NEAREST), (k * CELL * big, CELL + 4))
    d = ImageDraw.Draw(im)
    gy = CELL + 4 + GROUND * big + big - 1
    d.line([(0, gy), (W, gy)], fill=(220, 40, 40, 255))
    im.save(os.path.join(PIX, "merchant_v02_scale_check.png"))

    for line in log:
        print(line)


if __name__ == "__main__":
    main()

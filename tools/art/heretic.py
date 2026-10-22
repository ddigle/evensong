# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""이단 적 스프라이트 손질 (2026-10-22, 03-pixel/prompts.md "PixelLab 13차"). 생성 없음, 다시 돌리면 같은 파일.

실행 (어디서 돌려도 된다. 경로는 이 파일 기준. 고정 버전은 heretic.py.lock):
    uv run -q --script tools/art/heretic.py
    또는 uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I tools/art/heretic.py

읽는 것 (03-pixel, PixelLab에서 받은 그대로):
    chibi_heretic_v01_rotations.png       회전 남·동·북·서 (2차 character d47d48fa, 이번에 다시 받은 것과 픽셀까지 같음)
    heretic_v01_{walk,idle,hurt,death}.png 템플릿 동작, 줄 남·동·북, 32칸 (6 · 4 · 6 · 7 프레임)
    heretic_v01_attack_<판>_<방향>.png     v3 공격 9장 가로 줄 (첫 장 = 걷기 첫 프레임). 방향마다 캔버스가 다르다.
                                          a판(남·동·북)은 버린 판으로 기록만 남기고 b판(남·동·북)을 쓴다 (ATTACK_PICK)
    base_body_v02_idle.png                 크기 비교용 (기본 몸)
쓰는 것 (03-pixel):
    heretic_v02_{walk,idle,hurt,death}.png  32칸, 줄 남·동·북, 발 y=31 (base_body_v02와 같은 배치)
    heretic_v02_attack.png                  64칸 9열(첫 열 = 시작 그림), 줄 남·동·북, 32 프레임을 (16, 16)에 둔 좌표, 발 줄 y=47
    heretic_v02_rotations.png               32칸 4열 남·동·북·서 (서 = 동 좌우 반전, R19)
    heretic_v02_anims.gif                   줄 남·동·북·서(반전), 칸 idle·걷기·공격·피격·사망, 3배, 프레임당 130ms
    heretic_v02_scale_check.png             위 1배, 아래 4배. 칸마다 기본 몸 idle 첫 프레임과 이단 idle 첫 프레임 (남·동·북)
                                            빨간 선 = 발 줄 y=31, 파란 점 = 기본 몸 머리 꼭대기, 보라 점 = 이단 머리 꼭대기.
                                            글자는 그리지 않는다 (글꼴과 무관하게 같은 파일)

손질 순서 (프레임마다):
 1 색 묶음 나누기 → 위협 쪽 팔레트(PALETTE, 23색)의 같은 묶음 사다리에서 밝기(L*)가 가장 가까운 색으로.
   외곽선 #1a1714, 잿빛(두건), 멍든 자줏빛 회색(옷), 창백한 피부, 보라(맥·눈, brief §4 타락 줄), 녹(끈·칼 녹), 뼈(부적·칼날).
   회색의 파란 기운은 잿빛 사다리로 옮겨 없앤다. 생활 쪽(기본 몸) 갈색·베이지는 쓰지 않는다
 2 떨어진 점 지우기: 불투명 픽셀 8방향 덩어리 중 SPECK 이하 크기 (a판 공격 남 7~8번 발밑 피 점 등)
 3 북쪽(뒷모습) 템플릿 동작의 두건 뒤에 찍힌 보라·피부 점(EYE_SPOT px 이하)은 이웃의 가장 흔한 색으로 (fix_north_eyes)
 4 걷기 남쪽 칼 깜빡임: 6장 중 2번(오른손 칼)과 4번(왼손 칼)에만 칼이 있어 두 장에서 지운다 (WALK_SOUTH_KNIFE)
 5 발 맞춤: 32칸 동작은 방향마다 모든 프레임을 같은 만큼 내려 가장 낮은 픽셀이 y=31 (layers.py pivot과 같음).
   공격은 시작 그림 = 걷기 첫 프레임이므로 걷기의 이동값을 쓰고, v3 캔버스 속 시작 그림 위치(픽셀까지 일치)를 찾아 맞춘다 (10차 방식)
 6 외곽선: 발 맞춤 뒤 칸 좌표에서 실루엣 가장자리를 1px #1a1714로 닫는다 (outline). 템플릿은 두건 윗줄 외곽선이 잘려 있었다
 7 공격 남쪽(b판) 6·7번 꺼진 보라 눈을 5번에서 옮김 (ATTACK_SOUTH_EYES)
"""
import colorsys
import os
from collections import Counter

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
PIX = os.path.join(ROOT, "assets", "concept", "03-pixel")

DIRS = ("south", "east", "north")
CELL = 32
ACT = 64
GROUND = 31
SPECK = 3            # 이 크기(px) 이하로 떨어진 덩어리는 지운다
TEMPLATES = {"walk": 6, "idle": 4, "hurt": 6, "death": 7}
ATTACK_FRAMES = 9    # 시작 그림 + 8
# 채택한 공격 판 (prompts.md 13차 표). 판마다 raw 파일 heretic_v01_attack_<판>_<방향>.png
ATTACK_PICK = {"south": "b", "east": "b", "north": "b"}


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


# 위협 쪽 팔레트 (brief §4 기반·타락 줄 + 북극성 잿빛·뼈). 묶음 -> 어두운 것부터
RAMPS = {
    "outline": ["#1a1714"],
    "ash": ["#2f2b29", "#46413e", "#5d5854", "#77716c", "#928c86", "#b0aaa3"],
    "robe": ["#2a2027", "#3a2c37", "#4d3d49", "#61515d"],
    "skin": ["#7f7580", "#a69da6", "#ccc5c9"],
    "violet": ["#3b1f4d", "#5e2d7a", "#8a5fb0", "#b493cf"],
    "rust": ["#4a1c16", "#7a2f20", "#a3492c"],
    "bone": ["#a39c8c", "#d8d2c0"],
}
PALETTE = [hx(c) for r in RAMPS.values() for c in r]
OUT = hx(RAMPS["outline"][0])


def lstar(c):
    rgb = np.array(c, float) / 255
    rgb = np.where(rgb > 0.04045, ((rgb + 0.055) / 1.055) ** 2.4, rgb / 12.92)
    y = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
    return 116 * np.cbrt(y) - 16 if y > 0.008856 else 903.3 * y


RAMP_L = {k: [lstar(hx(c)) for c in v] for k, v in RAMPS.items()}


def family(c):
    """원본 색 -> 묶음 이름 (prompts.md 13차 "색 손질")"""
    r, g, b = c
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    hue = h * 360
    chroma = (max(c) - min(c)) / 255
    if l < 0.11:
        return "outline"
    if chroma < 0.06:
        return "bone" if l >= 0.80 else "ash"
    if 250 <= hue <= 335:                       # 보라 기운
        if chroma >= 0.24:
            return "violet"
        if l >= 0.58:
            return "skin"
        if chroma >= 0.15:
            return "violet"
        return "robe" if l < 0.40 else "skin"
    if 150 <= hue < 250:                        # 푸른 회색·흰빛 (두건, 칼날 빛)
        return "bone" if l >= 0.80 else "ash"
    if hue < 50 or hue > 335:                   # 빨강·주황·연어색 (끈, 칼)
        if chroma < 0.15:
            return "ash"
        return "bone" if l >= 0.68 else "rust"
    return "bone" if l >= 0.5 else "ash"        # 노랑·초록 기운 몇 px


_cache = {}


def map_colour(c):
    if c not in _cache:
        fam = family(c)
        L = lstar(c)
        ramp = RAMP_L[fam]
        i = int(np.argmin([abs(L - x) for x in ramp]))
        _cache[c] = hx(RAMPS[fam][i])
    return _cache[c]


def recolour(frame):
    out = frame.copy()
    op = frame[..., 3] > 0
    for y, x in zip(*np.nonzero(op)):
        out[y, x, :3] = map_colour(tuple(int(v) for v in frame[y, x, :3]))
        out[y, x, 3] = 255
    out[~op] = 0
    return out


def components(op):
    """8방향 연결 덩어리 (label 배열, 크기 목록)"""
    h, w = op.shape
    lab = np.zeros((h, w), int)
    sizes = [0]
    n = 0
    for y0, x0 in zip(*np.nonzero(op)):
        if lab[y0, x0]:
            continue
        n += 1
        stack = [(y0, x0)]
        lab[y0, x0] = n
        size = 0
        while stack:
            y, x = stack.pop()
            size += 1
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and op[yy, xx] and not lab[yy, xx]:
                        lab[yy, xx] = n
                        stack.append((yy, xx))
        sizes.append(size)
    return lab, sizes


def drop_specks(frame, log, tag):
    op = frame[..., 3] > 0
    lab, sizes = components(op)
    out = frame.copy()
    for i, s in enumerate(sizes):
        if i and s <= SPECK:
            out[lab == i] = 0
            log.append(f"{tag}: speck {s}px removed")
    return out


FACE = {hx(c) for c in RAMPS["violet"] + RAMPS["skin"]}
EYE_SPOT = 4         # 뒷모습 두건에 찍힌 보라·피부 점의 최대 크기 (사망 북 3번의 눈빛이 4px)


def fill_from_neighbours(frame, mask):
    out = frame.copy()
    h, w = mask.shape
    for y, x in zip(*np.nonzero(mask)):
        cnt = Counter()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                yy, xx = y + dy, x + dx
                if (dy or dx) and 0 <= yy < h and 0 <= xx < w and not mask[yy, xx] and frame[yy, xx, 3]:
                    cnt[tuple(int(v) for v in frame[yy, xx, :3])] += 1
        if cnt:
            out[y, x, :3] = cnt.most_common(1)[0][0]
    return out


def fix_north_eyes(frame, log, tag):
    """뒷모습에는 눈이 없다. 템플릿이 두건 뒤(프레임 위쪽 60%)에 찍은 보라·피부 점(EYE_SPOT px 이하 덩어리)을
    이웃의 가장 흔한 색으로. 공격 북쪽은 손을 머리 위로 들므로 하지 않는다 (clean에서 거름)"""
    rgb = frame[..., :3]
    op = frame[..., 3] > 0
    ys = np.nonzero(op.any(axis=1))[0]
    if not len(ys):
        return frame
    top, bottom = ys.min(), ys.max()
    limit = top + int(0.6 * (bottom - top + 1))
    cand = np.zeros(op.shape, bool)
    for y, x in zip(*np.nonzero(op)):
        if y < limit and tuple(int(v) for v in rgb[y, x]) in FACE:
            cand[y, x] = True
    lab, sizes = components(cand)
    mask = np.zeros(op.shape, bool)
    for i, s in enumerate(sizes):
        if i and s <= EYE_SPOT:
            mask |= lab == i
    if mask.any():
        pts = ", ".join(f"({x},{y})" for y, x in zip(*np.nonzero(mask)))
        log.append(f"{tag}: {int(mask.sum())} face-colour px on the back of the hood {pts}")
        frame = fill_from_neighbours(frame, mask)
    return frame


# 걷기 남쪽 칼 (4번): 6장 중 2번 프레임(오른손 = 그림 왼쪽, 아래로 늘어진 칼)과 4번 프레임(왼손 = 그림 오른쪽,
# 옆으로 뻗은 칼날)에만 칼이 있어 걸을 때 깜빡인다. 두 장에서 칼을 지워 idle 남쪽(칼 없음)과 맞춘다.
# 원본(발 맞춤 전) 좌표. 2번: 손(8, 19) 아래 x <= 8, y 20~25의 칼 전체. 4번: 손(24~25, 20~21) 오른쪽 칼날과 그 외곽선.
WALK_SOUTH_KNIFE = {
    2: [(x, y) for y in range(20, 26) for x in range(0, 9)],
    4: [(26, 19), (26, 20), (27, 20), (26, 21), (27, 21), (28, 21), (24, 22), (25, 22), (26, 22), (27, 22), (28, 22)],
}


def fix_walk_south(frame, idx, log):
    cells = WALK_SOUTH_KNIFE.get(idx)
    if not cells:
        return frame
    out = frame.copy()
    n = 0
    for x, y in cells:
        if out[y, x, 3]:
            out[y, x] = 0
            n += 1
    # 지운 칸이 남은 몸(외곽선이 아닌 픽셀)에 4방향으로 닿으면 그 칸을 외곽선으로 (손 끝을 닫는다)
    op = out[..., 3] > 0
    closed = 0
    for x, y in cells:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            xx, yy = x + dx, y + dy
            if 0 <= xx < CELL and 0 <= yy < CELL and op[yy, xx] and tuple(int(v) for v in out[yy, xx, :3]) != OUT:
                out[y, x] = (*OUT, 255)
                closed += 1
                break
    log.append(f"walk south {idx}: knife {n}px removed, {closed} outline px closing the hand")
    return out


# 공격 남쪽(b판) 6·7번은 v3가 눈을 외곽선·피부색으로 다시 그려 보라 눈이 꺼진다. 얼굴은 5번과 같고 한 줄 아래다
# (코·두건 줄이 dy=+1에서 겹침). 5번의 보라 눈 픽셀(64칸 좌표 x 28~29·34~35, y 30~31)을 한 줄 내려 덮는다.
ATTACK_SOUTH_EYES = {"src": 5, "box": (28, 30, 36, 32), "to": {6: (0, 1), 7: (0, 1)}}


def fix_attack_south_eyes(frames, log):
    src = frames[ATTACK_SOUTH_EYES["src"]]
    x0, y0, x1, y1 = ATTACK_SOUTH_EYES["box"]
    violet = {hx(c) for c in RAMPS["violet"]}
    pts = [(x, y) for y in range(y0, y1) for x in range(x0, x1)
           if src[y, x, 3] and tuple(int(v) for v in src[y, x, :3]) in violet]
    for idx, (dx, dy) in ATTACK_SOUTH_EYES["to"].items():
        for x, y in pts:
            frames[idx][y + dy, x + dx] = src[y, x]
        log.append(f"attack south {idx}: {len(pts)} eye px copied from frame {ATTACK_SOUTH_EYES['src']}")


DARK_L = 30          # 이보다 어두운 가장자리 픽셀은 그 자리를 외곽선으로


def outline(cell, floor):
    """1px 외곽선 (brief §5.6 따뜻한 갈흑 1px, §5.7 손질 규칙과 같은 방식). 발 맞춤 뒤 칸 좌표에서 한다.
    실루엣 가장자리(4방향 이웃이 투명) 중 외곽선 색이 아닌 픽셀: 어두우면(L* < DARK_L) 그 자리를 외곽선으로,
    밝으면 바깥 투명 이웃에 외곽선 픽셀을 더한다. 칸 경계나 발 줄(floor) 아래로 나가는 밝은 픽셀은 그 자리를
    외곽선으로 (발 줄이 32칸 31, 64칸 47로 그대로 남게).
    템플릿 프레임은 머리 꼭대기가 원본 캔버스 위쪽(y=0)에 닿아 두건 윗줄 외곽선이 잘려 있었다"""
    out = cell.copy()
    op = cell[..., 3] > 0
    h, w = op.shape
    add = []
    recol = []
    for y, x in zip(*np.nonzero(op)):
        c = tuple(int(v) for v in cell[y, x, :3])
        if c == OUT:
            continue
        outside = []
        border = False
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            xx, yy = x + dx, y + dy
            if not (0 <= xx < w and 0 <= yy < h) or (yy > floor and not op[yy, xx]):
                border = True
            elif not op[yy, xx]:
                outside.append((xx, yy))
        if not outside and not border:
            continue
        if lstar(c) < DARK_L or border:
            recol.append((x, y))
        else:
            add.extend(outside)
    for x, y in recol:
        out[y, x, :3] = OUT
    for x, y in add:
        out[y, x] = (*OUT, 255)
    return out, len(recol), len(set(add))


def load(name):
    return np.asarray(Image.open(os.path.join(PIX, name)).convert("RGBA")).copy()


def cells_of(sheet, cw, ch, rows, cols):
    return [[sheet[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw].copy() for c in range(cols)] for r in range(rows)]


def clean(frame, row, log, tag, anim):
    f = recolour(frame)
    f = drop_specks(f, log, tag)
    if DIRS[row] == "north" and anim in TEMPLATES:
        f = fix_north_eyes(f, log, tag)
    return f


def bottom_row(frames):
    return max(int(np.nonzero((f[..., 3] > 0).any(axis=1))[0].max()) for f in frames)


def shift_down(frame, dy, size):
    out = np.zeros((size, size, 4), np.uint8)
    h, w = frame.shape[:2]
    ys = slice(max(0, dy), min(size, h + dy))
    src = slice(max(0, -dy), max(0, -dy) + (ys.stop - ys.start))
    out[ys, :w] = frame[src]
    return out


def locate(big, small):
    """v3 캔버스 첫 장에서 시작 그림(32칸)이 놓인 자리. 픽셀까지 같아야 한다"""
    H, W = big.shape[:2]
    h, w = small.shape[:2]
    for y in range(H - h + 1):
        for x in range(W - w + 1):
            win = big[y:y + h, x:x + w]
            if np.array_equal(win[..., 3] > 0, small[..., 3] > 0) and np.array_equal(
                    win[..., :3][small[..., 3] > 0], small[..., :3][small[..., 3] > 0]):
                return x, y
    raise SystemExit("start frame not found in v3 frame 0")


def save(arr, name):
    Image.fromarray(arr.astype(np.uint8)).save(os.path.join(PIX, name))


def sheet_from(rows, size):
    n = len(rows[0])
    out = np.zeros((size * len(rows), size * n, 4), np.uint8)
    for r, frames in enumerate(rows):
        for c, f in enumerate(frames):
            out[r * size:(r + 1) * size, c * size:(c + 1) * size] = f
    return out


def colours(arr):
    a = arr.reshape(-1, 4)
    return {tuple(int(v) for v in p[:3]) for p in a if p[3]}


def outlined(cell, stats, anim):
    floor = GROUND + (cell.shape[0] - CELL) // 2      # 32칸 31, 64칸 47
    out, recol, added = outline(cell, floor)
    s = stats.setdefault(anim, [0, 0])
    s[0] += recol
    s[1] += added
    return out


def main():
    log = []
    stats = {}
    shifts = {}
    sheets = {}
    raw_walk = cells_of(load("heretic_v01_walk.png"), CELL, CELL, 3, 6)

    # --- 32칸 템플릿 동작
    for anim, n in TEMPLATES.items():
        raw = cells_of(load(f"heretic_v01_{anim}.png"), CELL, CELL, 3, n)
        rows = []
        shifts[anim] = []
        for r in range(3):
            frames = []
            for i, f in enumerate(raw[r]):
                g = clean(f, r, log, f"{anim} {DIRS[r]} {i}", anim)
                if anim == "walk" and DIRS[r] == "south":
                    g = fix_walk_south(g, i, log)
                frames.append(g)
            dy = GROUND - bottom_row(frames)
            shifts[anim].append(dy)
            rows.append([outlined(shift_down(f, dy, CELL), stats, anim) for f in frames])
        sheets[anim] = rows

    # --- 64칸 공격 (첫 열 = 시작 그림 = 걷기 첫 프레임)
    rows = []
    for r, d in enumerate(DIRS):
        strip = load(f"heretic_v01_attack_{ATTACK_PICK[d]}_{d}.png")
        w = strip.shape[1] // ATTACK_FRAMES
        raw = [strip[:, i * w:(i + 1) * w].copy() for i in range(ATTACK_FRAMES)]
        sx, sy = locate(raw[0], raw_walk[r][0])
        ox, oy = 16 - sx, 16 + shifts["walk"][r] - sy
        frames = []
        for i, f in enumerate(raw):
            g = clean(f, r, log, f"attack {d} {i}", "attack")
            cell = np.zeros((ACT, ACT, 4), np.uint8)
            h, wf = g.shape[:2]
            ys, xs = np.nonzero(g[..., 3] > 0)
            if (ys + oy).min() < 0 or (ys + oy).max() >= ACT or (xs + ox).min() < 0 or (xs + ox).max() >= ACT:
                raise SystemExit(f"attack {d} {i} leaves the 64 cell")
            cell[oy:oy + h, ox:ox + wf] = np.where(g[..., 3:4] > 0, g, cell[oy:oy + h, ox:ox + wf])
            frames.append(outlined(cell, stats, "attack"))
        # 시작 그림 열 = 손질한 걷기 첫 프레임 (원본이 픽셀까지 같다는 것은 locate가 확인). 걷기 북쪽의 두건 점 고침이
        # 공격 쪽에는 걸리지 않으므로 (손을 머리 위로 듦) 그대로 옮겨 놓는다
        ref = np.zeros((ACT, ACT, 4), np.uint8)
        ref[16:48, 16:48] = sheets["walk"][r][0]
        if not np.array_equal(frames[0], ref):
            changed = int(np.any(frames[0] != ref, axis=2).sum())
            log.append(f"attack {d} 0: start column set to the cleaned walk frame 0 ({changed} px differ)")
            frames[0] = ref
        if d == "south" and ATTACK_PICK[d] == "b":
            fix_attack_south_eyes(frames, log)
        log.append(f"attack {d}: pick {ATTACK_PICK[d]}, start frame at ({sx}, {sy}) in the v3 canvas, "
                   f"walk shift +{shifts['walk'][r]}")
        rows.append(frames)
    sheets["attack"] = rows

    # --- 회전 (남·동·북 + 서 = 동 반전)
    rot = cells_of(load("chibi_heretic_v01_rotations.png"), CELL, CELL, 1, 4)[0]
    rot3 = [clean(rot[i], i, log, f"rotation {DIRS[i]}", "rotations") for i in range(3)]
    dy = GROUND - bottom_row(rot3)
    rot3 = [outlined(shift_down(f, dy, CELL), stats, "rotations") for f in rot3]
    rotations = rot3 + [rot3[1][:, ::-1].copy()]
    shifts["rotations"] = dy

    for anim in ("walk", "idle", "hurt", "death"):
        save(sheet_from(sheets[anim], CELL), f"heretic_v02_{anim}.png")
    save(sheet_from(sheets["attack"], ACT), "heretic_v02_attack.png")
    save(sheet_from([rotations], CELL), "heretic_v02_rotations.png")

    # --- 미리보기 GIF: 줄 남·동·북·서(동 반전), 칸 idle·걷기·공격·피격·사망. 32칸은 64칸 (16, 16)에 둔다
    order = ("idle", "walk", "attack", "hurt", "death")
    k = 3
    bg = (120, 120, 110, 255)
    nframes = 56
    gif = []
    for t in range(nframes):
        canvas = np.zeros((4 * ACT, len(order) * ACT, 4), np.uint8)
        canvas[:] = bg
        for c, anim in enumerate(order):
            for r in range(4):
                src_row = 1 if r == 3 else r
                frames = sheets[anim][src_row]
                first = 1 if anim == "attack" else 0
                seq = frames[first:]
                f = seq[t % len(seq)]
                if f.shape[0] == CELL:
                    big = np.zeros((ACT, ACT, 4), np.uint8)
                    big[16:48, 16:48] = f
                    f = big
                if r == 3:
                    f = f[:, ::-1]
                block = canvas[r * ACT:(r + 1) * ACT, c * ACT:(c + 1) * ACT]
                m = f[..., 3] > 0
                block[m] = f[m]
        im = Image.fromarray(canvas).convert("RGB").resize((canvas.shape[1] * k, canvas.shape[0] * k), Image.NEAREST)
        gif.append(im.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    gif[0].save(os.path.join(PIX, "heretic_v02_anims.gif"), save_all=True, append_images=gif[1:], duration=130,
                loop=0, disposal=1, optimize=False)

    # --- 크기 비교: 칸마다 기본 몸 idle 0 | 이단 idle 0 (남·동·북). 위 1배, 아래 4배
    base = cells_of(load("base_body_v02_idle.png"), CELL, CELL, 3, 4)
    pad = 4
    strip_w = 3 * (2 * CELL + pad) + pad
    one = np.zeros((CELL + 2 * pad, strip_w, 4), np.uint8)
    one[:] = bg
    heights = []
    for r in range(3):
        x0 = pad + r * (2 * CELL + pad)
        for j, f in enumerate((base[r][0], sheets["idle"][r][0])):
            blk = one[pad:pad + CELL, x0 + j * CELL:x0 + (j + 1) * CELL]
            m = f[..., 3] > 0
            blk[m] = f[m]
            ys = np.nonzero(m.any(axis=1))[0]
            heights.append((DIRS[r], "base" if j == 0 else "heretic", int(ys.min()), int(ys.max()),
                            int(ys.max() - ys.min() + 1)))
    big = np.kron(one, np.ones((4, 4, 1), np.uint8))
    for r in range(3):                      # 4배 쪽에만 기준선·점
        x0 = (pad + r * (2 * CELL + pad)) * 4
        big[(pad + GROUND) * 4 + 3, x0:x0 + 2 * CELL * 4] = (200, 40, 40, 255)
        for d, who, top, _, _ in [h for h in heights if h[0] == DIRS[r]]:
            xx = x0 + (0 if who == "base" else CELL * 4)
            col = (60, 110, 200, 255) if who == "base" else (150, 80, 200, 255)
            big[(pad + top) * 4 - 3:(pad + top) * 4 - 1, xx:xx + 6] = col
    gap = np.zeros((8, big.shape[1], 4), np.uint8)
    gap[:] = bg
    top_row = np.zeros((one.shape[0], big.shape[1], 4), np.uint8)
    top_row[:] = bg
    top_row[:, :one.shape[1]] = one
    save(np.concatenate([top_row, gap, big]), "heretic_v02_scale_check.png")

    # --- 보고
    for line in log:
        print(line)
    print("pivot shifts (south, east, north):", {k: v for k, v in shifts.items()})
    for anim, (recol, added) in stats.items():
        print(f"outline {anim}: {recol} edge px recoloured, {added} outline px added outside")
    for name in ("walk", "idle", "attack", "hurt", "death", "rotations"):
        arr = np.asarray(Image.open(os.path.join(PIX, f"heretic_v02_{name}.png")).convert("RGBA"))
        cs = colours(arr)
        dark = [c for c in cs if sum(c) < 200]
        cold_dark = [c for c in dark if c[2] > c[0] + 5]
        assert cs <= set(PALETTE), name
        op = arr[..., 3] > 0
        p = np.pad(op, 1)
        edge = op & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
        not_out = int((edge & np.any(arr[..., :3] != OUT, axis=2)).sum())
        print(f"heretic_v02_{name}.png {arr.shape[1]}x{arr.shape[0]}: {len(cs)} colours, "
              f"dark colours with B > R+5: {len(cold_dark)}, silhouette edge px {int(edge.sum())} "
              f"(not outline colour {not_out})")
    for d, who, top, bot, h in heights:
        print(f"idle frame 0 {d} {who}: top y{top} feet y{bot} height {h}px")


if __name__ == "__main__":
    main()

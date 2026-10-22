# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""이단 적 스프라이트 손질 (2026-10-22, 03-pixel/prompts.md "PixelLab 13차"). 생성 없음, 다시 돌리면 같은 파일.

실행 (어디서 돌려도 된다. 경로는 이 파일 기준. 고정 버전은 heretic.py.lock):
    uv run -q --python 3.14.6 --script tools/art/heretic.py
    또는 uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I tools/art/heretic.py
    (--python 3.14.6을 빼면 SSH·샌드박스 셸에서 uv가 3.14 바로가기를 못 읽을 수 있다, os error 448)

읽는 것 (03-pixel, PixelLab에서 받은 그대로):
    chibi_heretic_v01_rotations.png       회전 남·동·북·서 (2차 character d47d48fa, 이번에 다시 받은 것과 픽셀까지 같음)
    heretic_v01_{walk,idle,hurt,death}.png 템플릿 동작, 줄 남·동·북, 32칸 (6 · 4 · 6 · 7 프레임)
    heretic_v01_attack_<판>_<방향>.png     v3 공격 9장 가로 줄 (첫 장 = 걷기 첫 프레임). 방향마다 캔버스가 다르다.
                                          a판(남·동·북)은 버린 판으로 기록만 남기고 b판(남·동·북)을 쓴다 (ATTACK_PICK)
    base_body_v02_idle.png                 크기 비교용 (기본 몸)
    목업 바탕 (mockup): 04-env 4단계 판(stage4_mockup.py·stage4_fix6.py의 v06 저녁 지상, v07 던전)을 같은 코드로 다시 그림
쓰는 것 (03-pixel):
    heretic_v02_{walk,idle,hurt,death}.png  32칸, 줄 남·동·북, 발 y=31 (base_body_v02와 같은 배치)
    heretic_v02_attack.png                  64칸 9열(첫 열 = 시작 그림), 줄 남·동·북, 32 프레임을 (16, 16)에 둔 좌표, 발 줄 y=47
    heretic_v02_rotations.png               32칸 4열 남·동·북·서 (서 = 동 좌우 반전, R19)
    heretic_v02_anims.gif                   줄 남·동·북·서(반전), 칸 idle·걷기·공격·피격·사망, 3배, 프레임당 130ms
    heretic_v02_scale_check.png             위 1배, 아래 4배. 칸마다 기본 몸 idle 첫 프레임과 이단 idle 첫 프레임 (남·동·북)
                                            빨간 선 = 발 줄 y=31, 파란 점 = 기본 몸 머리 꼭대기, 보라 점 = 이단 머리 꼭대기.
                                            글자는 그리지 않는다 (글꼴과 무관하게 같은 파일)
    heretic_v02_mockup.png / _1x.png        480x270 (3배 / 1배): 저녁 오염 지대(제단 빛 밖)의 이단 둘(하나는 공격 중)과 아처
    heretic_v02_mockup_dungeon.png / _1x    480x270 (3배 / 1배): 던전 바닥의 이단 (4단계 v07 판에 얹음)

손질 순서 (프레임마다. 좌표는 원본 32칸 좌표, 13차 "손질" 표):
 1 색 묶음 나누기 → 위협 쪽 팔레트(PALETTE, 23색)의 같은 묶음 사다리에서 밝기(L*)가 가장 가까운 색으로.
   두건 잿빛은 L*를 LIFT만큼 올려 고른다(어두운 땅에서 몸이 땅과 같은 밝기로 묻히지 않게, 검토 뒤 고침)
 2 떨어진 점 지우기: 불투명 픽셀 8방향 덩어리 중 SPECK 이하 크기
 3 칼은 공격에만 (KNIFE): idle 동·북, 피격 남(0~5)·북(2)의 칼을 상자째 지운다. 걷기 남은 1차부터 지움
   (WALK_SOUTH_KNIFE). 사망은 손에서 떨어지는 칼로 두었다
 4 손에 남은 칼 자루·작은 흠 (BITS): idle 동·걷기 동 주먹의 녹빛 자루 → 이웃 색, 피격 남 주먹의 녹 → 피부,
   피격 동 다리 사이의 1px 뼈빛 칼날 → 이웃 색, 걷기 남 입의 녹 점 → 이웃 색, 걷기 남 오른손 찌꺼기(녹 → 이웃 색, 뼈 → 피부)
 5 얼굴 밖 보라 (violet_off_face): 템플릿 동작(걷기·idle·피격·사망) 남·동에서 얼굴 줄 아래 보라 점은 옷 사다리로
 6 북쪽(뒷모습) 두건 뒤에 찍힌 보라·피부 점(EYE_SPOT px 이하)은 이웃의 가장 흔한 색으로 (fix_north_eyes)
 7 동쪽 옆얼굴 (side_face): 보라 눈에 닿은 밝은 잿빛(L* >= FACE_L)은 남쪽 얼굴처럼 피부 사다리로
 8 칸 왼쪽에서 잘린 프레임 (CUT_LEFT): 사망 동 5·6, 피격 동 2를 오른쪽으로 옮기고 잘린 머리 뒤를 둥글게 늘인다
 9 발 맞춤: 걷기·idle은 방향마다 모든 프레임을 같은 만큼 내려 가장 낮은 픽셀이 y=31 (layers.py pivot과 같음).
   피격·사망은 첫 프레임(서 있는 자세)의 발을 y=31에 두고, 그러면 칸 밖으로 나가는 프레임만 그만큼 올린다.
   동쪽 줄(걷기·idle·공격·회전)은 EAST_DX만큼 오른쪽으로 (서 = 동 반전이 몸 무게중심을 거의 옮기지 않게).
   공격은 시작 그림 = 걷기 첫 프레임이므로 걷기의 이동값을 쓰고, v3 캔버스 속 시작 그림 위치(픽셀까지 일치)를 찾아 맞춘다
 10 외곽선: 발 맞춤 뒤 칸 좌표에서 실루엣 가장자리를 1px #1a1714로 닫고(outline), 잘린 두건 윗줄에 생기는 1px 빗살(teeth)은
   떼어 그 아래 픽셀을 외곽선으로 (fix_teeth)
 11 북쪽 두건 안의 외딴 외곽선 점(뒤통수의 구멍처럼 보임)은 이웃 색으로 (fix_north_dot)
 12 공격 남쪽(b판) 6·7번 꺼진 보라 눈을 5번에서 옮김 (ATTACK_SOUTH_EYES). 공격 동쪽은 한 번 베기로 프레임 순서를 고름
   (ATTACK_ORDER). 끝 그림(= 시작 그림, END_SAME px 이하로 다름)인 열은 손질한 걷기 첫 프레임으로
"""
import colorsys
import os
import sys
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
ACTIONS = ("hurt", "death")   # 첫 프레임 기준 발 맞춤
ATTACK_FRAMES = 9    # 시작 그림 + 8
# 채택한 공격 판 (prompts.md 13차 표). 판마다 raw 파일 heretic_v01_attack_<판>_<방향>.png
ATTACK_PICK = {"south": "b", "east": "b", "north": "b"}
# 공격 시트의 열 -> 원본 v3 프레임. 동(b)은 원본이 앞으로 베고(2) 허리 뒤로 당겼다(4~5) 다시 찌르는(6) 두 번 휘두르기라,
# 들어 올림(1)을 세 장 잡고 한 번 베기(2, 두 장) → 따라 내림(3) → 돌아옴(7, 8)만 쓴다. 남·북은 원본 순서 그대로
ATTACK_ORDER = {"east": [0, 1, 1, 1, 2, 2, 3, 7, 8]}
# 동쪽 줄을 오른쪽으로 옮기는 값 (걷기·idle·공격·회전). 두건이 뒤로 길어 몸 무게중심이 x 14로 반전 축(15.5)보다 2px 왼쪽이라
# 동↔서로 돌 때 3px씩 튀었다. +2면 기본 몸과 같은 자리(무게중심 15.7~16, 머리 15.2)
EAST_DX = 2
# 공격 동·북은 end_frame = 시작 그림이라 마지막 장(8)이 시작 그림과 4~5px만 다르다. 이 이하로 다르면 시작 그림 열처럼
# 손질한 걷기 첫 프레임으로 바꾼다 (공격이 끝나면 걷기·idle 자세로 정확히 돌아오게)
END_SAME = 8


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
FAMILY_OF = {hx(c): k for k, v in RAMPS.items() for c in v}
# 묶음별 밝기 올림(L*). 두건(잿빛)이 오염 잿빛 땅(L* 39)·던전 바닥(37)과 같은 밝기라 한 칸쯤 올린다 (검토 뒤 고침)
LIFT = {"ash": 9}


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


def nearest(fam, L):
    ramp = RAMP_L[fam]
    return hx(RAMPS[fam][int(np.argmin([abs(L - x) for x in ramp]))])


_cache = {}


def map_colour(c):
    if c not in _cache:
        fam = family(c)
        _cache[c] = nearest(fam, lstar(c) + LIFT.get(fam, 0))
    return _cache[c]


def col(frame, x, y):
    return tuple(int(v) for v in frame[y, x, :3])


def recolour(frame):
    out = frame.copy()
    op = frame[..., 3] > 0
    for y, x in zip(*np.nonzero(op)):
        out[y, x, :3] = map_colour(col(frame, x, y))
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


def fill_from_neighbours(frame, mask, avoid=()):
    """mask 픽셀을 8방향 이웃(mask 밖, 불투명, avoid 색 아님)의 가장 흔한 색으로. 이웃이 없으면 그대로"""
    out = frame.copy()
    h, w = mask.shape
    for y, x in zip(*np.nonzero(mask)):
        cnt = Counter()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                yy, xx = y + dy, x + dx
                if (dy or dx) and 0 <= yy < h and 0 <= xx < w and not mask[yy, xx] and frame[yy, xx, 3]:
                    c = col(frame, xx, yy)
                    if c not in avoid:
                        cnt[c] += 1
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


# 걷기 남쪽 칼 (1차 손질): 6장 중 2번 프레임(오른손 = 그림 왼쪽, 아래로 늘어진 칼)과 4번 프레임(왼손 = 그림 오른쪽,
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
            if 0 <= xx < CELL and 0 <= yy < CELL and op[yy, xx] and col(out, xx, yy) != OUT:
                out[y, x] = (*OUT, 255)
                closed += 1
                break
    log.append(f"walk south {idx}: knife {n}px removed, {closed} outline px closing the hand")
    return out


# 칼은 공격에만 (검토 뒤 고침). idle 동은 큰 뼈빛 칼날, idle 북은 오른손 아래 칼, 피격 남은 짧은 검 길이의 칼날(0~5),
# 피격 북은 2번에만 칼이 있어 idle·걷기·공격 사이에서 칼이 생겼다 사라졌다. 칼을 지우고 공격에서만 칼이 나오게 한다
# (칼이 보이면 공격이 온다는 예고). 상자 (x0, y0, x1, y1)는 원본 32칸 좌표, 양 끝 포함. 상자 안을 모두 지운다
# (칼날·칼의 외곽선. 손은 상자 밖). 지운 자리는 뒤의 외곽선 단계가 손 끝을 닫는다
KNIFE = {
    ("idle", "east"): {i: [(20, 18, 31, 25)] for i in range(4)},
    ("idle", "north"): {0: [(25, 20, 31, 26)],
                        1: [(25, 20, 31, 20), (24, 21, 31, 26)],
                        2: [(24, 21, 31, 26)],
                        3: [(25, 20, 31, 20), (24, 21, 31, 22), (25, 23, 31, 26)]},
    ("hurt", "south"): {0: [(0, 11, 6, 17), (0, 18, 7, 18)],
                        1: [(0, 11, 7, 15)],
                        2: [(0, 11, 8, 15), (0, 16, 7, 16)],
                        3: [(0, 20, 9, 26)],
                        4: [(0, 9, 6, 15), (0, 16, 5, 16)],
                        5: [(0, 9, 5, 16)]},
    ("hurt", "north"): {2: [(22, 22, 31, 26)]},
}
# 손에 남은 칼 자루·찌꺼기 (원본 좌표 상자, 고칠 묶음 -> 방법). "fill" = 이웃(같은 묶음·외곽선 제외)의 가장 흔한 색,
# "skin" = 같은 밝기의 피부 사다리 색 (손이 창백하게 남게)
BITS = {
    ("idle", "east"): {i: [((15, 19, 19, 25), {"rust": "fill"})] for i in range(4)},
    ("walk", "east"): {i: [((12, 19, 22, 27), {"rust": "fill"})] for i in range(6)},
    # 걷기 남: 3~5번 입의 녹 점(얼굴 상자), 3~5번 오른손에 남은 자루 찌꺼기(녹 → 이웃 색, 뼈 → 피부)
    ("walk", "south"): {i: [((11, 10, 20, 13), {"rust": "fill"}),
                            ((22, 17, 27, 21), {"rust": "fill", "bone": "skin"})] for i in range(6)},
    # 피격 남: 주먹 안의 녹빛 자루 → 피부 (주먹이 창백하게 남게. 이웃이 외곽선뿐인 프레임이 있다)
    ("hurt", "south"): {0: [((6, 14, 9, 18), {"rust": "skin"})],
                        1: [((5, 15, 8, 18), {"rust": "skin"})],
                        2: [((7, 15, 10, 18), {"rust": "skin"})],
                        3: [((8, 19, 12, 22), {"rust": "skin"})],
                        4: [((5, 14, 9, 18), {"rust": "skin"})],
                        5: [((5, 14, 9, 18), {"rust": "skin"})]},
    # 피격 동: 다리 사이를 대각선으로 지나는 1px 뼈빛 칼날(아래로 든 칼)과 녹 → 이웃 색 (손은 머리 높이라 상자 밖)
    ("hurt", "east"): {i: [((8, 18, 23, 26), {"bone": "fill", "rust": "fill"})] for i in range(6)},
    ("hurt", "north"): {2: [((20, 20, 23, 23), {"rust": "fill"})]},
}


def remove_knife(frame, boxes):
    out = frame.copy()
    n = 0
    for x0, y0, x1, y1 in boxes:
        blk = out[y0:y1 + 1, x0:x1 + 1]
        n += int((blk[..., 3] > 0).sum())
        blk[:] = 0
    return out, n


def fix_bits(frame, entries):
    out = frame.copy()
    done = Counter()
    for (x0, y0, x1, y1), how in entries:
        for fam, method in how.items():
            mask = np.zeros(out.shape[:2], bool)
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    if out[y, x, 3] and FAMILY_OF.get(col(out, x, y)) == fam:
                        mask[y, x] = True
            if not mask.any():
                continue
            if method == "fill":
                avoid = {hx(c) for c in RAMPS[fam]} | {OUT}
                out = fill_from_neighbours(out, mask, avoid)
            else:
                for y, x in zip(*np.nonzero(mask)):
                    out[y, x, :3] = nearest(method, lstar(col(out, x, y)))
            done[f"{fam}->{method}"] += int(mask.sum())
    return out, done


# 얼굴 밖 보라: 템플릿이 옷·신에 보라 점(눈빛 색)을 프레임마다 다른 자리에 찍어 깜빡였다. 그림 꼭대기에서 이 줄 수
# 아래의 보라는 같은 밝기의 옷 사다리 색으로 (남 = 눈 아래 볼까지 13줄, 동 = 옆얼굴 눈빛 줄기까지 17줄)
FACE_ROWS = {"south": 13, "east": 17}
VIOLET = {hx(c) for c in RAMPS["violet"]}


def violet_off_face(frame, d):
    if d not in FACE_ROWS:
        return frame, 0
    out = frame.copy()
    ys = np.nonzero((frame[..., 3] > 0).any(axis=1))[0]
    limit = ys.min() + FACE_ROWS[d]
    n = 0
    for y, x in zip(*np.nonzero(frame[..., 3] > 0)):
        if y >= limit and col(frame, x, y) in VIOLET:
            out[y, x, :3] = nearest("robe", lstar(col(frame, x, y)))
            n += 1
    return out, n


# 동쪽 옆얼굴: 남쪽 얼굴은 눈 둘레가 연보라 피부인데, 옆얼굴은 같은 밝은 회색이 잿빛 사다리로 가서 두건과 같은 색이었다.
# 보라 눈에 8방향으로 닿은 밝은 잿빛(L* >= FACE_L, 그림 위쪽 절반)을 같은 밝기의 피부 사다리 색으로
FACE_L = 55


def side_face(frame):
    out = frame.copy()
    op = frame[..., 3] > 0
    ys = np.nonzero(op.any(axis=1))[0]
    half = ys.min() + (ys.max() - ys.min() + 1) // 2
    ash = {hx(c) for c in RAMPS["ash"]}
    n = 0
    h, w = op.shape
    for y, x in zip(*np.nonzero(op)):
        c = col(frame, x, y)
        if y >= half or c not in ash or lstar(c) < FACE_L:
            continue
        if any(0 <= y + dy < h and 0 <= x + dx < w and frame[y + dy, x + dx, 3] and col(frame, x + dx, y + dy) in VIOLET
               for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx):
            out[y, x, :3] = nearest("skin", lstar(c))
            n += 1
    return out, n


# 칸 왼쪽 끝(x=0)에서 잘린 프레임: (오른쪽으로 옮길 값, x=0에 닿은 줄마다 왼쪽으로 늘일 길이). 늘인 픽셀은 그 줄 x=0의 색
# (외곽선 색이면 x=1의 색). 사망 동 6번은 시체로 남는 마지막 프레임이라 머리 뒤가 9줄 곧은 벽으로 보였다
CUT_LEFT = {
    ("death", "east", 5): (3, [1, 2, 1]),
    ("death", "east", 6): (4, [1, 2, 2, 3, 3, 2, 2, 1]),
    ("hurt", "east", 2): (1, [0, 1, 0]),
}


def extend_left(frame, shift, depth, log, tag):
    rows = [y for y in range(frame.shape[0]) if frame[y, 0, 3]]
    if len(rows) != len(depth):
        raise SystemExit(f"{tag}: {len(rows)} rows touch x=0 {rows}, table has {len(depth)}")
    if (frame[:, frame.shape[1] - shift:, 3] > 0).any():
        raise SystemExit(f"{tag}: moving right by {shift} cuts the right side")
    out = np.zeros_like(frame)
    out[:, shift:] = frame[:, :frame.shape[1] - shift]
    for y, d in zip(rows, depth):
        c = frame[y, 0] if col(frame, 0, y) != OUT or not frame[y, 1, 3] else frame[y, 1]
        if d:
            out[y, shift - d:shift] = c
    log.append(f"{tag}: moved right {shift}, rows {rows[0]}-{rows[-1]} at the cut extended by {depth}")
    return out


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
        c = col(cell, x, y)
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


def fix_teeth(cell, before):
    """잘린 두건 윗줄에서 생기는 빗살: 더한 외곽선 픽셀 중 왼쪽·오른쪽·위가 투명하고, 바로 아래 픽셀이 밝은 색이며
    그 아래 픽셀의 좌우가 외곽선인 것. 그 픽셀을 떼고 아래 픽셀을 외곽선으로 (윗줄이 매끈한 외곽선 한 줄이 된다)"""
    out = cell.copy()
    op = cell[..., 3] > 0
    h, w = op.shape
    n = 0
    for y, x in zip(*np.nonzero(op & ~before)):
        if col(cell, x, y) != OUT or not (1 <= x < w - 1 and 1 <= y < h - 1):
            continue
        if op[y, x - 1] or op[y, x + 1] or op[y - 1, x]:
            continue
        below = col(cell, x, y + 1)
        if not op[y + 1, x] or below == OUT:
            continue
        if col(cell, x - 1, y + 1) == OUT and col(cell, x + 1, y + 1) == OUT and op[y + 1, x - 1] and op[y + 1, x + 1]:
            out[y, x] = 0
            out[y + 1, x, :3] = OUT
            n += 1
    return out, n


HOOD_ROWS = 13      # 뒷모습 두건: 그림 꼭대기에서 이 줄 수까지


def fix_north_dot(cell):
    """뒷모습 두건(그림 꼭대기에서 HOOD_ROWS줄) 안의 외딴 외곽선 픽셀(8방향 이웃이 모두 외곽선이 아닌 불투명, 보라에
    닿지 않음)을 이웃의 가장 흔한 색으로. 대각선으로 이어진 두건 솔기·가장자리 홈은 남는다"""
    op = cell[..., 3] > 0
    ys = np.nonzero(op.any(axis=1))[0]
    limit = ys.min() + HOOD_ROWS
    h, w = op.shape
    mask = np.zeros(op.shape, bool)
    for y, x in zip(*np.nonzero(op)):
        if y >= limit or col(cell, x, y) != OUT or not (0 < x < w - 1 and 0 < y < h - 1):
            continue
        nb = [(x + dx, y + dy) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dx or dy]
        if all(op[yy, xx] and col(cell, xx, yy) != OUT and col(cell, xx, yy) not in VIOLET for xx, yy in nb):
            mask[y, x] = True
    if not mask.any():
        return cell, []
    return fill_from_neighbours(cell, mask, {OUT}), [(int(x), int(y)) for y, x in zip(*np.nonzero(mask))]


# 공격 남쪽(b판) 6·7번은 v3가 눈을 외곽선·피부색으로 다시 그려 보라 눈이 꺼진다. 얼굴은 5번과 같고 한 줄 아래다
# (코·두건 줄이 dy=+1에서 겹침). 5번의 보라 눈 픽셀(64칸 좌표 x 28~29·34~35, y 30~31)을 한 줄 내려 덮는다.
# 원본 프레임 번호 기준 (남쪽은 ATTACK_ORDER가 없어 열 = 원본 프레임)
ATTACK_SOUTH_EYES = {"src": 5, "box": (28, 30, 36, 32), "to": {6: (0, 1), 7: (0, 1)}}


def fix_attack_south_eyes(frames, log):
    src = frames[ATTACK_SOUTH_EYES["src"]]
    x0, y0, x1, y1 = ATTACK_SOUTH_EYES["box"]
    pts = [(x, y) for y in range(y0, y1) for x in range(x0, x1)
           if src[y, x, 3] and col(src, x, y) in VIOLET]
    for idx, (dx, dy) in ATTACK_SOUTH_EYES["to"].items():
        for x, y in pts:
            frames[idx][y + dy, x + dx] = src[y, x]
        log.append(f"attack south {idx}: {len(pts)} eye px copied from frame {ATTACK_SOUTH_EYES['src']}")


def load(name):
    return np.asarray(Image.open(os.path.join(PIX, name)).convert("RGBA")).copy()


def cells_of(sheet, cw, ch, rows, cols):
    return [[sheet[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw].copy() for c in range(cols)] for r in range(rows)]


def clean(frame, row, log, tag, anim, idx=None):
    """색, 떨어진 점, 칼·작은 흠, 얼굴 밖 보라, 뒷모습 눈빛, 옆얼굴 (발 맞춤 전, 원본 좌표)"""
    d = DIRS[row]
    f = recolour(frame)
    f = drop_specks(f, log, tag)
    boxes = KNIFE.get((anim, d), {}).get(idx)
    if boxes:
        f, n = remove_knife(f, boxes)
        log.append(f"{tag}: knife {n}px removed")
    if anim == "walk" and d == "south":
        f = fix_walk_south(f, idx, log)
    bits = BITS.get((anim, d), {}).get(idx)
    if bits:
        f, done = fix_bits(f, bits)
        if done:
            log.append(f"{tag}: bits {dict(done)}")
    if anim in TEMPLATES:
        f, n = violet_off_face(f, d)
        if n:
            log.append(f"{tag}: {n} violet px off the face -> robe")
    if d == "north" and anim in TEMPLATES:
        f = fix_north_eyes(f, log, tag)
    if d == "east" and anim != "rotations":
        f, n = side_face(f)
        if n:
            log.append(f"{tag}: side face {n} px -> skin")
    return f


def bottom(f):
    return int(np.nonzero((f[..., 3] > 0).any(axis=1))[0].max())


def bottom_row(frames):
    return max(bottom(f) for f in frames)


def shift_frame(frame, dy, dx, size):
    """frame(원본 크기)을 (dx, dy)만큼 옮겨 size 칸에. 칸 밖으로 나가는 불투명 픽셀이 있으면 멈춘다"""
    out = np.zeros((size, size, 4), np.uint8)
    ys, xs = np.nonzero(frame[..., 3] > 0)
    if (ys + dy).min() < 0 or (ys + dy).max() >= size or (xs + dx).min() < 0 or (xs + dx).max() >= size:
        raise SystemExit(f"shift ({dx}, {dy}) leaves the {size} cell")
    out[ys + dy, xs + dx] = frame[ys, xs]
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


def finish_cell(cell, stats, anim, d, log, tag):
    """외곽선 + 빗살 + (북) 외딴 점"""
    floor = GROUND + (cell.shape[0] - CELL) // 2      # 32칸 31, 64칸 47
    before = cell[..., 3] > 0
    out, recol, added = outline(cell, floor)
    out, teeth = fix_teeth(out, before)
    s = stats.setdefault(anim, [0, 0, 0])
    s[0] += recol
    s[1] += added
    s[2] += teeth
    if teeth:
        log.append(f"{tag}: {teeth} outline teeth flattened")
    if d == "north":
        out, dots = fix_north_dot(out)
        if dots:
            log.append(f"{tag}: lone outline px inside the hood {dots}")
    return out


def main():
    log = []
    stats = {}
    shifts = {}
    lifted = {}
    sheets = {}
    raw_walk = cells_of(load("heretic_v01_walk.png"), CELL, CELL, 3, 6)

    # --- 32칸 템플릿 동작
    for anim, n in TEMPLATES.items():
        raw = cells_of(load(f"heretic_v01_{anim}.png"), CELL, CELL, 3, n)
        rows = []
        shifts[anim] = []
        for r, d in enumerate(DIRS):
            frames = []
            for i, f in enumerate(raw[r]):
                tag = f"{anim} {d} {i}"
                g = clean(f, r, log, tag, anim, i)
                cut = CUT_LEFT.get((anim, d, i))
                if cut:
                    g = extend_left(g, cut[0], cut[1], log, tag)
                frames.append(g)
            dx = EAST_DX if d == "east" and anim in ("walk", "idle") else 0
            if anim in ACTIONS:
                dy = GROUND - bottom(frames[0])
                dys = [min(dy, GROUND - bottom(f)) for f in frames]
                for i, v in enumerate(dys):
                    if v != dy:
                        lifted.setdefault(anim, []).append(f"{d} {i} {v - dy:+d}")
            else:
                dy = GROUND - bottom_row(frames)
                dys = [dy] * len(frames)
            shifts[anim].append(dy)
            rows.append([finish_cell(shift_frame(f, v, dx, CELL), stats, anim, d, log, f"{anim} {d} {i}")
                         for i, (f, v) in enumerate(zip(frames, dys))])
        sheets[anim] = rows

    # --- 64칸 공격 (첫 열 = 시작 그림 = 걷기 첫 프레임)
    rows = []
    for r, d in enumerate(DIRS):
        strip = load(f"heretic_v01_attack_{ATTACK_PICK[d]}_{d}.png")
        w = strip.shape[1] // ATTACK_FRAMES
        raw = [strip[:, i * w:(i + 1) * w].copy() for i in range(ATTACK_FRAMES)]
        sx, sy = locate(raw[0], raw_walk[r][0])
        dx = EAST_DX if d == "east" else 0
        ox, oy = 16 + dx - sx, 16 + shifts["walk"][r] - sy
        # 시작 그림 열과 끝 그림(= 시작 그림, 동·북. END_SAME px 이하로 다름)인 열 = 손질한 걷기 첫 프레임 (시작 그림이
        # 걷기 첫 프레임과 픽셀까지 같다는 것은 locate가 확인). 걷기 쪽 손질(두건 점, 칼 자루)이 공격 쪽 손질과 다르므로
        # 그대로 옮겨 놓는다
        ref = np.zeros((ACT, ACT, 4), np.uint8)
        ref[16:48, 16:48] = sheets["walk"][r][0]
        frames = []
        for i, f in enumerate(raw):
            ndiff = int(np.any(f != raw[0], axis=2).sum())
            if i == 0 or ndiff <= END_SAME:
                frames.append(ref.copy())
                if i:
                    log.append(f"attack {d} {i}: {ndiff} px from the start picture -> cleaned walk frame 0")
                continue
            g = clean(f, r, log, f"attack {d} {i}", "attack", i)
            ys, xs = np.nonzero(g[..., 3] > 0)
            if (ys + oy).min() < 0 or (ys + oy).max() >= ACT or (xs + ox).min() < 0 or (xs + ox).max() >= ACT:
                raise SystemExit(f"attack {d} {i} leaves the 64 cell")
            cell = np.zeros((ACT, ACT, 4), np.uint8)
            cell[ys + oy, xs + ox] = g[ys, xs]
            frames.append(finish_cell(cell, stats, "attack", d, log, f"attack {d} {i}"))
        if d == "south" and ATTACK_PICK[d] == "b":
            fix_attack_south_eyes(frames, log)
        order = ATTACK_ORDER.get(d, list(range(ATTACK_FRAMES)))
        frames = [frames[i].copy() for i in order]
        log.append(f"attack {d}: pick {ATTACK_PICK[d]}, start frame at ({sx}, {sy}) in the v3 canvas, "
                   f"walk shift +{shifts['walk'][r]}, x {dx:+d}, columns from raw frames {order}")
        rows.append(frames)
    sheets["attack"] = rows

    # --- 회전 (남·동·북 + 서 = 동 반전)
    rot = cells_of(load("chibi_heretic_v01_rotations.png"), CELL, CELL, 1, 4)[0]
    rot3 = [clean(rot[i], i, log, f"rotation {DIRS[i]}", "rotations") for i in range(3)]
    dy = GROUND - bottom_row(rot3)
    rot3 = [finish_cell(shift_frame(f, dy, EAST_DX if i == 1 else 0, CELL), stats, "rotations", DIRS[i], log,
                        f"rotation {DIRS[i]}") for i, f in enumerate(rot3)]
    rotations = rot3 + [rot3[1][:, ::-1].copy()]
    shifts["rotations"] = dy

    for anim in ("walk", "idle", "hurt", "death"):
        save(sheet_from(sheets[anim], CELL), f"heretic_v02_{anim}.png")
    save(sheet_from(sheets["attack"], ACT), "heretic_v02_attack.png")
    save(sheet_from([rotations], CELL), "heretic_v02_rotations.png")

    previews(sheets)
    report(log, stats, shifts, lifted, sheets)
    mockups(sheets)


def previews(sheets):
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
            c = (60, 110, 200, 255) if who == "base" else (150, 80, 200, 255)
            big[(pad + top) * 4 - 3:(pad + top) * 4 - 1, xx:xx + 6] = c
    gap = np.zeros((8, big.shape[1], 4), np.uint8)
    gap[:] = bg
    top_row = np.zeros((one.shape[0], big.shape[1], 4), np.uint8)
    top_row[:] = bg
    top_row[:, :one.shape[1]] = one
    save(np.concatenate([top_row, gap, big]), "heretic_v02_scale_check.png")
    previews.heights = heights


def centroid_x(f):
    return float(np.nonzero(f[..., 3] > 0)[1].mean())


def report(log, stats, shifts, lifted, sheets):
    for line in log:
        print(line)
    print("pivot shifts (south, east, north):", {k: v for k, v in shifts.items()})
    print("frames lifted to stay in the cell:", lifted)
    for anim, (recol, added, teeth) in stats.items():
        print(f"outline {anim}: {recol} edge px recoloured, {added} outline px added outside, {teeth} teeth")
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
        fill = op & np.any(arr[..., :3] != OUT, axis=2)
        Ls = [lstar(tuple(int(v) for v in p[:3])) for p in arr[fill]]
        print(f"heretic_v02_{name}.png {arr.shape[1]}x{arr.shape[0]}: {len(cs)} colours, "
              f"dark colours with B > R+5: {len(cold_dark)}, silhouette edge px {int(edge.sum())} "
              f"(not outline colour {not_out}), fill L* mean {np.mean(Ls):.1f}")
    for d, who, top, bot, h in previews.heights:
        print(f"idle frame 0 {d} {who}: top y{top} feet y{bot} height {h}px")
    # 동쪽 줄 무게중심 (서 = 반전 축 15.5)과 프레임마다 발 줄
    for anim in ("walk", "idle", "hurt", "death"):
        cx = [round(centroid_x(f), 1) for f in sheets[anim][1]]
        feet = {d: [bottom(f) for f in sheets[anim][r]] for r, d in enumerate(DIRS)}
        print(f"{anim}: east centroid x {cx}, feet rows {feet}")
    feet = {d: [bottom(f) for f in sheets["attack"][r]] for r, d in enumerate(DIRS)}
    print(f"attack: feet/lowest rows {feet}, east col 0 centroid x {centroid_x(sheets['attack'][1][0][16:48, 16:48]):.1f}")
    bone = {hx(c) for c in RAMPS["bone"]}
    for anim in ("walk", "idle", "hurt", "death"):
        cnt = {d: [sum(1 for p in f.reshape(-1, 4) if p[3] and tuple(int(v) for v in p[:3]) in bone)
                   for f in sheets[anim][r]] for r, d in enumerate(DIRS)}
        print(f"{anim}: bone px per frame {cnt}")


# =====================================================================================
# 목업 (04-env 4단계 판을 같은 코드로 다시 그리고 이단을 얹는다)
# =====================================================================================
def rgba_img(a):
    return Image.fromarray(a.astype(np.uint8))


def sprite(sheets, anim, d, i):
    """(이미지, 발 기준 왼쪽 위까지의 거리). 서 = 동 반전. 발(원점)은 32칸 (16, 32), 64칸 (32, 48)"""
    row = 1 if d == "W" else {"S": 0, "E": 1, "N": 2}[d]
    f = sheets[anim][row][i]
    if d == "W":
        f = f[:, ::-1]
    size = f.shape[0]
    pad = (size - CELL) // 2
    return rgba_img(f), (16 + pad, 32 + pad)


# (판, 동작, 방향, 프레임, 발 x, 발 y). 저녁 지상은 오염 잿빛 땅(x >= 400쯤, 제단 빛 밖). 공격하는 이단은 아처(372, 168,
# 동쪽을 봄) 쪽으로 서쪽을 보며 베는 프레임(동 4열 = 원본 2, 칼을 앞으로 뻗음). 던전은 약초사(196, 222) 쪽으로 걸어옴
MOCK_EVE = [("attack", "W", 4, 398, 170), ("walk", "S", 1, 436, 128)]
MOCK_DUNGEON = [("walk", "W", 2, 240, 246)]


def mockups(sheets):
    sys.path.insert(0, HERE)
    import stage4_mockup as sm      # noqa: E402  (4단계 판: 바닥, 소품, 캐릭터, 저녁 어둡게)
    import stage4_fix6 as f6        # noqa: E402  (v06 저녁 / v07 던전과 같은 소품 바꿈)

    class HereticScene(sm.Scene5):
        extra = []

        def render(self, ground):
            for k, (anim, d, i, fx, fy) in enumerate(HereticScene.extra):
                im, (ox, oy) = sprite(sheets, anim, d, i)
                self.items.append((fy, 900 + k, im, (fx - ox, fy - oy), None))
            return super().render(ground)

    saved = {}
    old = sm.Scene5, sm.finish
    sm.SWAP.clear()
    sm.SWAP.update(f6.BOARD_SWAP)
    try:
        sm.Scene5 = HereticScene
        sm.finish = lambda img, name: saved.__setitem__(name, img)
        # 저녁 지상: stage4_mockup.surface5의 저녁 쪽과 같은 계산 (v06 저녁 판)
        HereticScene.extra = MOCK_EVE
        base, emis, lights = sm.surface5_scene(True)
        h, w = base.height, base.width
        edge_px = np.array([sm.ASH_EDGE[min(len(sm.ASH_EDGE) - 1, int(y // 16))] * 16 for y in range(h)], float)
        xx = np.arange(w)[None, :].astype(float)
        ash_amt = np.clip((xx - (edge_px[:, None] - 12)) / 20.0, 0, 1)
        eve = sm.darken(base, emis, lights, ash_amt).crop((0, 0, sm.SW, sm.SH))
        # 던전: stage4_mockup.dungeon6 (v07 판). 오른쪽 방 판은 x 160부터라 발 x는 방 판 좌표
        HereticScene.extra = MOCK_DUNGEON
        sm.dungeon6("dungeon")
        dun = saved["dungeon"]
    finally:
        sm.Scene5, sm.finish = old
        sm.SWAP.clear()
    for img, name in ((eve, "heretic_v02_mockup"), (dun, "heretic_v02_mockup_dungeon")):
        img = img.convert("RGB")
        img.save(os.path.join(PIX, f"{name}_1x.png"))
        img.resize((img.width * 3, img.height * 3), Image.NEAREST).save(os.path.join(PIX, f"{name}.png"))
        print(f"wrote {name}.png (3x) and {name}_1x.png {img.size}")


if __name__ == "__main__":
    main()

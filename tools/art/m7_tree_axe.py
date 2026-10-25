# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow==11.3.0", "numpy==2.3.3"]
# ///
"""M7 그림: 나무 1종·그루터기·도끼질 몸 동작 (2026-10-25). 생성 결과(raw)에서 손질판·미리보기를 만든다. 생성 없음.

기록: assets/concept/04-env/prompts.md "M7 나무·그루터기", assets/concept/03-pixel/prompts.md "PixelLab 14차".
실행 (어디서 돌려도 된다. 경로는 이 파일 기준. 다시 돌리면 같은 파일):
    uv run -q --python 3.14.6 --script tools/art/m7_tree_axe.py all
    또는 uv run -q --python 3.14.6 --with pillow==11.3.0 --with numpy==2.3.3 python -I tools/art/m7_tree_axe.py all
    (--python 3.14.6을 빼면 SSH·샌드박스 셸에서 uv가 3.14 바로가기를 못 읽을 수 있다, os error 448)

  tree     04-env tree_v01_b.png (raw) -> tree_v02.png (64x80), 그 줄기 밑동을 잘라 stump_v01.png (같은 64x80 캔버스, 같은 자리)
  axe      03-pixel base_body_v01_axe_<판>_<방향>.png (raw, v3 7장 가로 줄) -> base_body_v02_axe.png
           (64칸 7열, 줄 남·동·북, 첫 열 = 시작 그림 = 걷기 첫 프레임, 발 줄 y=47. 낫·곡괭이 시트와 같은 배치.
           열 1~6은 COLUMNS 표의 raw 프레임: 세 방향 모두 4열에서 내리친다. 14차 검토)
  preview  03-pixel base_body_v02_axe_preview.gif (줄 남·동·북·서(동 반전), 칸 도끼 | 낫, 3배, 130ms)
           04-env tree_v02_board.png (1배·3배 낮·저녁, 후보 셋, 도끼 시트와 낫 시트 2배)
  mockup   04-env stage4_tree_mockup_v01_day.png / _eve.png (3배) + _1x (480x270, 4단계 목업 코드로 바닥·제단·빛)
  check    손질 규칙 검사 (색 수, 밝기, 차가운 어두운 색, 외곽선, 반투명, 시트 배치)
  all      위 모두
"""
import colorsys
import os
import random
import sys
from collections import Counter

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import stage4_mockup as m  # noqa: E402  (4단계 목업의 바닥·빛·제단 코드를 그대로 쓴다)

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ENV = os.path.join(ROOT, "assets", "concept", "04-env")
PIX = os.path.join(ROOT, "assets", "concept", "03-pixel")
OUT = (0x1A, 0x17, 0x14)          # 오브젝트 외곽선 (brief §5.7 손질 규칙)
BODY_OUT = (0, 0, 0)              # 기본 몸 시트의 외곽선 (5차 "single color black outline")


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def lstar(c):
    def f(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    y = 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2])
    return 116 * (y ** (1 / 3) if y > 0.008856 else 7.787 * y + 16 / 116) - 16


def load(path):
    return np.asarray(Image.open(path).convert("RGBA")).copy()


def save(arr, path):
    Image.fromarray(arr.astype(np.uint8)).save(path)
    print("wrote", os.path.relpath(path, ROOT).replace("\\", "/"), arr.shape[1], "x", arr.shape[0])


def col(a, x, y):
    return tuple(int(v) for v in a[y, x, :3])


def colours(a):
    return Counter(tuple(int(v) for v in p[:3]) for p in a.reshape(-1, 4) if p[3])


# =====================================================================================
# 나무 (tree_v01_b -> tree_v02) 와 그루터기 (stump_v01)
# =====================================================================================
TREE_PICK = "b"        # 후보 a·b·c 중 b (줄기·뿌리가 가장 또렷하고 덩어리 진 수관. 04-env/prompts.md 판정)

# 수관 초록 7단 (어둠 -> 밝음). 생활 쪽 풀(#80bd5a, 색상 97°)과 같은 쪽 색상이고 병든 올리브(#6f8f3a, 83°)보다
# 확실히 초록 쪽(밝은 셋 95~99°, 어두운 셋 102~112°)이다. 수관 몸통(L5)은 풀보다 어둡게(밝기 137 대 160) 해서
# 풀밭 위에서 덩어리로 갈린다. 어두운 초록은 R >= B (차가운 색 아님, brief §6 측정)
LEAF = [hx(c) for c in ("#1f331c", "#2a4723", "#375d2b", "#477633", "#5a8f3e", "#6ea448", "#98d072")]
# 껍질 6단: 04-env 통나무 아이템(item_log_v02)의 껍질 색을 그대로 쓴다(벤 나무 -> 통나무가 같은 나무로 읽히게)
BARK = [hx(c) for c in ("#3e241a", "#492312", "#5b2e15", "#794725", "#8c5a2c", "#a96e43")]
# 그루터기 나이테 면: 통나무 아이템·널판(item_planks_a_v03)의 나뭇결 색
GRAIN = {"L": hx("#d79149"), "M": hx("#bc8440"), "R": hx("#a05f22"), "E": hx("#8c4a22")}

# raw 색 -> (묶음, 단). 묶음 "dark" = 보랏빛·청록 어두운 색: 실루엣 가장자리면 외곽선, 안쪽이면 수관 L0 / 껍질 B0
TREE_MAP = {
    "#1a2f2a": ("dark", "leaf"), "#1b322c": ("dark", "leaf"), "#22372e": ("dark", "leaf"),
    "#1c1327": ("dark", "bark"), "#251a24": ("dark", "bark"), "#2c1e27": ("dark", "bark"), "#20242b": ("dark", "bark"),
    "#304730": ("leaf", 1), "#385134": ("leaf", 1),
    "#435e3b": ("leaf", 2), "#47643b": ("leaf", 2),
    "#4d6a3c": ("leaf", 3), "#56743e": ("leaf", 3),
    "#638241": ("leaf", 4), "#698a41": ("leaf", 4), "#729142": ("leaf", 4), "#7f9a44": ("leaf", 4),
    "#91a643": ("leaf", 5), "#9aac44": ("leaf", 5), "#9db043": ("leaf", 5),
    "#cdd87b": ("leaf", 6),
    "#4e3636": ("bark", 1), "#5d3e3a": ("bark", 1),
    "#674740": ("bark", 2), "#6f4844": ("bark", 2),
    "#775148": ("bark", 3), "#85544a": ("bark", 3),
    "#8d5d52": ("bark", 4),
    "#ad7362": ("bark", 5),
}
TREE_FLOOR = 72        # 뿌리가 땅에 닿는 줄. 이 아래(가운데 곧은뿌리 끝 y 73~74, 오른쪽 뿌리 끝 y 73)는 지우고 이 줄에서 닫는다
STUMP_CUT = 59         # 그루터기 나이테 면의 맨 윗줄
DARK_L = 30


def edge_mask(a):
    op = a[..., 3] > 0
    h, w = op.shape
    pad = np.zeros((h + 2, w + 2), bool)
    pad[1:-1, 1:-1] = op
    nb = ~pad[:-2, 1:-1] | ~pad[2:, 1:-1] | ~pad[1:-1, :-2] | ~pad[1:-1, 2:]
    return op & nb


def outline(a, out, floor=None, only=None):
    """실루엣 가장자리를 1px 외곽선으로 닫는다 (heretic.py와 같은 규칙). 가장자리 픽셀이 어두우면(L* < DARK_L) 그 자리를,
    밝으면 바깥 투명 이웃에 외곽선을 더한다. floor 줄 아래와 캔버스 밖으로는 더하지 않고 그 자리를 외곽선으로.
    only: 이 마스크의 픽셀만 본다 (도끼 시트에서 도구 픽셀만)"""
    res = a.copy()
    op = a[..., 3] > 0
    h, w = op.shape
    add, recol = set(), []
    for y, x in zip(*np.nonzero(op)):
        if only is not None and not only[y, x]:
            continue
        c = col(a, x, y)
        if c == out:
            continue
        outside, border = [], False
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            xx, yy = x + dx, y + dy
            if not (0 <= xx < w and 0 <= yy < h) or (floor is not None and yy > floor and not op[yy, xx]):
                border = True
            elif not op[yy, xx]:
                outside.append((xx, yy))
        if not outside and not border:
            continue
        if lstar(c) < DARK_L or border:
            recol.append((x, y))
        else:
            add.update(outside)
    for x, y in recol:
        res[y, x, :3] = out
    for x, y in add:
        res[y, x] = (*out, 255)
    return res, len(recol), len(add)


def tree():
    raw = load(os.path.join(ENV, f"tree_v01_{TREE_PICK}.png"))
    a = raw.copy()
    a[TREE_FLOOR + 1:] = 0
    edge = edge_mask(a)
    unknown = set()
    for y, x in zip(*np.nonzero(a[..., 3] > 0)):
        key = "#%02x%02x%02x" % col(a, x, y)
        if key not in TREE_MAP:
            unknown.add(key)
            continue
        fam, v = TREE_MAP[key]
        if fam == "dark":
            c = OUT if edge[y, x] else (LEAF[0] if v == "leaf" else BARK[0])
        elif fam == "leaf":
            c = LEAF[v]
        else:
            c = BARK[v]
        a[y, x, :3] = c
    if unknown:
        raise SystemExit(f"tree: unmapped raw colours {sorted(unknown)}")
    a, recol, added = outline(a, OUT, floor=TREE_FLOOR)
    print(f"tree: raw {len(colours(raw))} colours -> {len(colours(a))}; outline {recol} edge px recoloured, "
          f"{added} px added; rows below {TREE_FLOOR} removed ({int((raw[TREE_FLOOR + 1:, :, 3] > 0).sum())} px)")
    save(a, os.path.join(ENV, "tree_v02.png"))
    stump(a)
    return a


# 그루터기 나이테 면 (낮은 탑다운이라 위에서 본 납작한 타원). 줄기 폭(외곽선 포함)에 맞춘 판.
# O 외곽선, L 밝은 나뭇결, M 중간, R 나이테, E 잘린 가장자리(형성층 띠), . 투명, - 그대로(나무의 껍질)
STUMP_CAP = [
    "..OOOO..",
    ".OLLLLO.",
    "OLMRRMLO",
    "OELLLLEO",
    "-EEEEEE-",
]


def stump(tree_img):
    """나무 손질판에서 STUMP_CUT 아래 줄기·뿌리를 그대로 남기고, 그 위에 나이테 면을 얹는다. 캔버스와 줄기 자리는 나무와 같다
    (게임에서 나무 그림을 그루터기 그림으로 바꾸기만 하면 된다)"""
    s = tree_img.copy()
    top = STUMP_CUT
    # 판의 폭 = 나이테 면 아랫줄(-로 시작하는 줄)이 덮을 줄기 폭. 줄기는 그 줄에서 외곽선까지 잰다
    row = top + len(STUMP_CAP) - 1
    xs = np.nonzero(s[row, :, 3] > 0)[0]
    # 그 줄의 가장 긴 연속 구간 = 줄기
    runs, start = [], xs[0]
    for i in range(1, len(xs) + 1):
        if i == len(xs) or xs[i] != xs[i - 1] + 1:
            runs.append((start, xs[i - 1]))
            if i < len(xs):
                start = xs[i]
    x0, x1 = max(runs, key=lambda r: r[1] - r[0])
    w = len(STUMP_CAP[0])
    cx = (x0 + x1 + 1) / 2
    left = int(round(cx - w / 2))
    s[:top] = 0
    for j, line in enumerate(STUMP_CAP):
        y = top + j
        for i, ch in enumerate(line):
            x = left + i
            if ch == "-":
                continue
            if ch == ".":
                s[y, x] = 0
            else:
                s[y, x] = (*(OUT if ch == "O" else GRAIN[ch]), 255)
        # 판 밖 같은 줄의 나무 픽셀(줄기 옆 껍질)은 지운다: 나이테 면 위로 껍질이 삐져나오지 않게
        if j < len(STUMP_CAP) - 1:
            s[y, :left] = 0
            s[y, left + w:] = 0
    s, recol, added = outline(s, OUT, floor=TREE_FLOOR)
    ys, xs2 = np.nonzero(s[..., 3] > 0)
    print(f"stump: trunk at the cap's last row x {x0}-{x1}, cap left {left}, box x {xs2.min()}-{xs2.max()} "
          f"y {ys.min()}-{ys.max()}, {len(colours(s))} colours, outline +{added} / {recol} recoloured")
    save(s, os.path.join(ENV, "stump_v01.png"))
    return s


# =====================================================================================
# 도끼질 몸 동작 (base_body_v01_axe_<판>_<방향> -> base_body_v02_axe)
# =====================================================================================
DIRS = ("south", "east", "north")
AXE_PICK = {"south": "a", "east": "b", "north": "b"}   # 03-pixel/prompts.md 14차 판정 (북 c·d 다시 뽑기는 버림)
FRAMES = 7             # 시작 그림 + 6
# 시트 열 1~6에 놓을 raw 프레임 번호 (14차 검토). 세 방향 모두 4열(프레임 번호 3, 곡괭이·괭이의 맞는 프레임 3과 같음)에서
# 내리친다. 남: raw 1은 시작 그림과 거의 같고 도끼가 없어(도끼가 0.1초 늦게 나타남) 빼고, 어깨 위로 든 raw 2를 두 번(들어 올려
# 잡음). 동: 머리 뒤로 수평으로 든 raw 2를 두 번(잡음) 두어 허리 높이 내리침(raw 3)을 4열로. 끝 그림(= 시작 그림)인 raw 6은 빠진다.
# 북: 그대로(4열 = 오른쪽 아래로 내리침)
COLUMNS = {"south": (2, 2, 3, 4, 5, 6), "east": (1, 2, 2, 3, 4, 5), "north": (1, 2, 3, 4, 5, 6)}
HIT_COLUMN = 4
CELL, ACT = 32, 64
FLOOR = 47
WALK_SHIFT = (4, 3, 4)  # 걷기 v01 -> v02 발 맞춤 (03-pixel/prompts.md "발 맞춤"). 64칸 동작은 같은 값
END_SAME = 8           # 시작 그림과 이 픽셀 수 이하로 다른 열은 시작 그림으로 (끝 그림 = 시작 그림인 판)
SPECK = 3
# 도끼 쇠: v3가 칠한 푸르스름하거나 무채색인 회색을 04-env 철(광석 철·모루 v02: #34302d #5e5953 #a39d92)
# 사다리에 밝기(HLS L)로 맞춘다. 반짝임은 생활 쪽 아이템 하이라이트 규칙(밝기 215 이하)에 맞춘 #ddd6c6
IRON = [hx(c) for c in ("#34302d", "#5e5953", "#807a71", "#a39d92", "#c4bdae", "#ddd6c6")]
IRON_L = [colorsys.rgb_to_hls(*[v / 255 for v in c])[1] for c in IRON]
# 북쪽(b판) 날은 v3가 크림빛으로 칠해 회색 조건(채도)에 걸리지 않는다. 남·동과 같은 쇠로 보이게 같은 밝기의 철 색으로
METAL_EXTRA = {hx("#e4d5b7"): hx("#ddd6c6"), hx("#c4bba2"): hx("#c4bdae")}
EYE_HI = hx("#f1e4e8")  # 기본 몸 걷기 남·동 눈 반짝임


def locate(big, small):
    H, W = big.shape[:2]
    h, w = small.shape[:2]
    m_ = small[..., 3] > 0
    for y in range(H - h + 1):
        for x in range(W - w + 1):
            win = big[y:y + h, x:x + w]
            if np.array_equal(win[..., 3] > 0, m_) and np.array_equal(win[..., :3][m_], small[..., :3][m_]):
                return x, y
    raise SystemExit("start frame not found in v3 frame 0")


def is_metal(c, body):
    if c in body:
        return False
    hi, lo = max(c), min(c)
    _, l, _ = colorsys.rgb_to_hls(*[v / 255 for v in c])
    return hi - lo <= 24 and l > 0.15


def components(op):
    h, w = op.shape
    seen = np.zeros_like(op)
    out = []
    for y, x in zip(*np.nonzero(op)):
        if seen[y, x]:
            continue
        stack, comp = [(y, x)], []
        seen[y, x] = True
        while stack:
            cy, cx = stack.pop()
            comp.append((cy, cx))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = cy + dy, cx + dx
                    if 0 <= yy < h and 0 <= xx < w and op[yy, xx] and not seen[yy, xx]:
                        seen[yy, xx] = True
                        stack.append((yy, xx))
        out.append(comp)
    return out


def body_feet(cell):
    """몸의 발 줄: 도구(쇠 사다리 색)와 그에 붙은 외곽선을 뺀 픽셀의 맨 아래 줄. 손잡이 나무는 몸 색과 섞여 빼지 않는다
    (발보다 아래로 내려간 손잡이가 없어서 잴 수 있다)"""
    op = cell[..., 3] > 0
    iron = np.zeros_like(op)
    for y, x in zip(*np.nonzero(op)):
        iron[y, x] = col(cell, x, y) in IRON
    near = np.zeros_like(op)
    near[1:] |= iron[:-1]
    near[:-1] |= iron[1:]
    near[:, 1:] |= iron[:, :-1]
    near[:, :-1] |= iron[:, 1:]
    near[1:, 1:] |= iron[:-1, :-1]
    near[1:, :-1] |= iron[:-1, 1:]
    near[:-1, 1:] |= iron[1:, :-1]
    near[:-1, :-1] |= iron[1:, 1:]
    body = op & ~iron
    for y, x in zip(*np.nonzero(body & near)):
        if lstar(col(cell, x, y)) < DARK_L:      # 쇠에 붙은 어두운 픽셀 = 날의 외곽선 (북 b판은 검정이 아닌 짙은 갈색)
            body[y, x] = False
    return int(np.nonzero(body.any(axis=1))[0].max())


def axe():
    walk1 = load(os.path.join(PIX, "base_body_v01_walk.png"))
    walk2 = load(os.path.join(PIX, "base_body_v02_walk.png"))
    body = set(colours(walk1))
    metal_map = {}
    rows = []
    for r, d in enumerate(DIRS):
        strip = load(os.path.join(PIX, f"base_body_v01_axe_{AXE_PICK[d]}_{d}.png"))
        fw = strip.shape[1] // FRAMES
        raw = [strip[:, i * fw:(i + 1) * fw].copy() for i in range(FRAMES)]
        sx, sy = locate(raw[0], walk1[r * CELL:(r + 1) * CELL, 0:CELL])
        ox, oy = 16 - sx, 16 + WALK_SHIFT[r] - sy
        start = np.zeros((ACT, ACT, 4), np.uint8)
        start[16:48, 16:48] = walk2[r * CELL:(r + 1) * CELL, 0:CELL]
        frames = []
        for i, f in enumerate(raw):
            ys, xs = np.nonzero(f[..., 3] > 0)
            if (ys + oy).min() < 0 or (ys + oy).max() >= ACT or (xs + ox).min() < 0 or (xs + ox).max() >= ACT:
                raise SystemExit(f"axe {d} {i} leaves the 64 cell")
            cell = np.zeros((ACT, ACT, 4), np.uint8)
            cell[ys + oy, xs + ox] = f[ys, xs]
            if i == 0:
                if not np.array_equal(cell, start):
                    raise SystemExit(f"axe {d}: start column differs from walk v02 frame 0")
                frames.append(start.copy())
                continue
            nd = int(np.any(f != raw[0], axis=2).sum())
            if nd <= END_SAME:
                frames.append(start.copy())
                print(f"axe {d} {i}: {nd} px from the start picture -> start picture")
                continue
            # 떨어진 점
            for comp in components(cell[..., 3] > 0):
                if len(comp) <= SPECK:
                    for cy, cx in comp:
                        cell[cy, cx] = 0
                    print(f"axe {d} {i}: speck {len(comp)} px at {comp[0][::-1]} removed")
            # 쇠 색. 눈의 흰 반짝임도 v3가 차가운 흰색(#f0f6f7 등)으로 칠해 쇠 조건에 걸린다: 주변 8칸에 다른 쇠 후보가 없는
            # 외딴 밝은 픽셀(L > 0.85)은 쇠가 아니라 눈 반짝임으로 보고 기본 몸의 눈 반짝임 색(EYE_HI)으로
            cand = np.zeros((ACT, ACT), bool)
            for y, x in zip(*np.nonzero(cell[..., 3] > 0)):
                c = col(cell, x, y)
                cand[y, x] = c in METAL_EXTRA or is_metal(c, body)
            tool = np.zeros((ACT, ACT), bool)
            n = eyes = 0
            for y, x in zip(*np.nonzero(cell[..., 3] > 0)):
                c = col(cell, x, y)
                lone = cand[y, x] and not cand[max(0, y - 1):y + 2, max(0, x - 1):x + 2].sum() - 1
                if lone and colorsys.rgb_to_hls(*[v / 255 for v in c])[1] > 0.85:
                    cell[y, x, :3] = EYE_HI
                    eyes += 1
                elif c in METAL_EXTRA:
                    metal_map.setdefault(c, METAL_EXTRA[c])
                    cell[y, x, :3] = METAL_EXTRA[c]
                    tool[y, x] = True
                    n += 1
                elif is_metal(c, body):
                    l = colorsys.rgb_to_hls(*[v / 255 for v in c])[1]
                    t = IRON[int(np.argmin([abs(l - v) for v in IRON_L]))]
                    metal_map.setdefault(c, t)
                    cell[y, x, :3] = t
                    tool[y, x] = True
                    n += 1
                elif c not in body:
                    tool[y, x] = True       # 손잡이 나무 등 기본 몸에 없는 색
            cell, recol, added = outline(cell, BODY_OUT, floor=FLOOR, only=tool)
            # 발 줄 아래의 몸 외곽선: 위 칸도 외곽선이고 쇠에 닿지 않으면 두 겹 외곽선이라 지운다(남 raw 5 왼다리 덩어리 밑 1px)
            iron = np.zeros((ACT, ACT), bool)
            for y, x in zip(*np.nonzero(cell[..., 3] > 0)):
                iron[y, x] = col(cell, x, y) in IRON
            thick = 0
            for y in range(FLOOR + 1, ACT):
                for x in range(ACT):
                    if (cell[y, x, 3] and col(cell, x, y) == BODY_OUT and cell[y - 1, x, 3]
                            and col(cell, x, y - 1) == BODY_OUT and not iron[max(0, y - 1):y + 2, max(0, x - 1):x + 2].any()):
                        cell[y, x] = 0
                        thick += 1
            if thick:
                print(f"axe {d} {i}: {thick} doubled outline px below the feet line removed")
            feet = body_feet(cell)
            print(f"axe {d} {i}: {n} metal px -> iron ramp, {eyes} eye glint px -> body eye glint, "
                  f"outline +{added} / {recol} recoloured, body feet row {feet}")
            if feet != FLOOR:
                raise SystemExit(f"axe {d} {i}: body feet on row {feet}, not {FLOOR}")
            frames.append(cell)
        rows.append([frames[0]] + [frames[k] for k in COLUMNS[d]])
        print(f"axe {d}: sheet columns 1-6 = raw {COLUMNS[d]}")
        print(f"axe {d}: pick {AXE_PICK[d]}, start picture at ({sx}, {sy}) in the v3 canvas ({fw}x{strip.shape[0]}), "
              f"cell offset ({ox}, {oy})")
    for c, t in sorted(metal_map.items()):
        print("  metal #%02x%02x%02x -> #%02x%02x%02x" % (c + t))
    sheet = np.zeros((ACT * 3, ACT * FRAMES, 4), np.uint8)
    for r, frames in enumerate(rows):
        for i, f in enumerate(frames):
            sheet[r * ACT:(r + 1) * ACT, i * ACT:(i + 1) * ACT] = f
    save(sheet, os.path.join(PIX, "base_body_v02_axe.png"))
    return sheet


# =====================================================================================
# 미리보기
# =====================================================================================
GRASS_BG = hx("#80bd5a")


def cells(sheet, size=ACT):
    rows = sheet.shape[0] // size
    n = sheet.shape[1] // size
    return [[sheet[r * size:(r + 1) * size, c * size:(c + 1) * size] for c in range(n)] for r in range(rows)]


def preview_gif(axe_sheet):
    sick = load(os.path.join(PIX, "base_body_v02_sickle.png"))
    sets = [cells(axe_sheet), cells(sick)]
    k = 3
    gif = []
    for t in range(6):
        canvas = np.zeros((4 * ACT, 2 * ACT, 4), np.uint8)
        canvas[:] = (*GRASS_BG, 255)
        for c, s in enumerate(sets):
            for r in range(4):
                f = s[1 if r == 3 else r][1 + t]
                if r == 3:
                    f = f[:, ::-1]
                blk = canvas[r * ACT:(r + 1) * ACT, c * ACT:(c + 1) * ACT]
                msk = f[..., 3] > 0
                blk[msk] = f[msk]
        im = Image.fromarray(canvas).convert("RGB").resize((canvas.shape[1] * k, canvas.shape[0] * k), Image.NEAREST)
        gif.append(im.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    path = os.path.join(PIX, "base_body_v02_axe_preview.gif")
    gif[0].save(path, save_all=True, append_images=gif[1:], duration=130, loop=0, disposal=1, optimize=False)
    print("wrote", os.path.relpath(path, ROOT).replace("\\", "/"))


def grass(w, h, seed):
    rnd = random.Random(seed)
    g = [m.load(n) for n in m.GRASS]
    im = Image.new("RGBA", (w, h))
    for y in range(0, h, 16):
        for x in range(0, w, 16):
            m.paste(im, g[0] if rnd.random() < 0.55 else rnd.choice(g[1:]), (x, y))
    return im


def put(dst, arr, x, y):
    m.paste(dst, Image.fromarray(arr), (x, y))


def tree_origin(tile_x, tile_y, img):
    """나무·그루터기 그림의 왼쪽 위 (월드 px): 줄기 가운데(그림 x 32)를 칸 가운데에, 그림의 맨 아래 불투명 줄을 칸 아래 변 줄에"""
    return tile_x * 16 + 8 - TREE_TRUNK_X, (tile_y + 1) * 16 - 1 - TREE_BOTTOM_ROW


TREE_TRUNK_X = 32      # 줄기 가운데 (tree_v02 줄기 외곽선 포함 x 30~36(y 53~62), 밑동 x 29~36(y 63~64). 그림 x 32를 칸 가운데 x 8에)
TREE_BOTTOM_ROW = TREE_FLOOR


def char_origin(foot_x, foot_y, size=ACT):
    """캐릭터 칸의 왼쪽 위: 발 점(칸 (32, 48) 또는 32칸 (16, 32))을 (foot_x, foot_y)에 (game/ RigData.FRAME_ORIGIN과 같은 규칙)"""
    return (foot_x - 32, foot_y - 48) if size == ACT else (foot_x - 16, foot_y - 32)


STRIP_H = 120          # 나무 줄의 땅줄 y 95, 북쪽 도끼질 캐릭터의 발 y 111 (도끼 끝 y 115)


def strip_scene(tree_img, stump_img, axe_sheet, idle):
    """240xSTRIP_H 풀밭: 나무 + 동쪽을 보고 도끼질 중인 캐릭터(왼쪽 칸), 그루터기 + 남쪽을 보는 idle 캐릭터,
    나무 + 바로 아래 칸에서 북쪽을 보고 도끼질하는 캐릭터"""
    im = grass(240, STRIP_H, 7)
    ax = cells(axe_sheet)
    items = []   # (foot_y, x, y, arr)
    # 칸 좌표 (16px): 땅줄 = 칸 5의 아래 변 (y 95)
    ty = 5
    for tx, img in ((3, tree_img), (8, stump_img), (12, tree_img)):
        x, y = tree_origin(tx, ty, img)
        items.append(((ty + 1) * 16, 0, x, y, img))
    fx, fy = 2 * 16 + 8, (ty + 1) * 16          # 나무(3, 5) 서쪽 칸에서 동쪽을 봄, 허리 높이로 내리친 4열
    items.append((fy, 1, *char_origin(fx, fy), ax[1][HIT_COLUMN]))
    fx2 = 9 * 16 + 8                              # 그루터기 동쪽 칸, 남쪽을 보는 idle
    items.append((fy, 1, *char_origin(fx2, fy, CELL), idle))
    fx3 = 12 * 16 + 8                             # 나무(12, 5) 바로 아래 칸에서 북쪽을 봄, 도끼를 내리친 4열
    items.append((fy + 16, 1, *char_origin(fx3, fy + 16), ax[2][HIT_COLUMN]))
    for _, _, x, y, a in sorted(items, key=lambda t: (t[0], t[1])):
        put(im, a, x, y)
    return im


def evening(im, lights):
    return m.darken(im, Image.new("RGBA", im.size), lights)


def board(tree_img, stump_img, axe_sheet):
    idle = load(os.path.join(PIX, "base_body_v02_idle.png"))[0:CELL, 0:CELL]
    day = strip_scene(tree_img, stump_img, axe_sheet, idle)
    # 저녁: 왼쪽 나무만 제단 빛 안(빛 가운데 (40, 70), 안 50px, 밖 90px), 나머지는 빛 밖 어둠 3단 (4단계 목업과 같은 값)
    eve = evening(day.copy(), [(40, 70, 50, 90)])
    # 후보 셋 raw + 손질판 + 그루터기 (1배, 풀밭)
    cand = grass(5 * 64 + 16, STRIP_H, 11)
    for i, name in enumerate(("tree_v01_a.png", "tree_v01_b.png", "tree_v01_c.png")):
        a = load(os.path.join(ENV, name))
        ys = np.nonzero((a[..., 3] > 0).any(axis=1))[0]
        put(cand, a, 8 + i * 64 + (64 - a.shape[1]) // 2, 92 - ys.max())
    put(cand, tree_img, 8 + 3 * 64, 92 - TREE_BOTTOM_ROW)
    put(cand, stump_img, 8 + 4 * 64, 92 - TREE_BOTTOM_ROW)
    sick = load(os.path.join(PIX, "base_body_v02_sickle.png"))
    sheets = []
    for sh in (axe_sheet, sick):
        bg = np.zeros_like(sh)
        bg[:] = (*GRASS_BG, 255)
        msk = sh[..., 3] > 0
        bg[msk] = sh[msk]
        for r in range(3):
            bg[r * ACT + FLOOR + 1, :, :3] = (200, 60, 50)     # 발 줄 아래 한 줄 (발은 y 47)
            bg[r * ACT + FLOOR + 1, :, 3] = 255
        sheets.append(Image.fromarray(bg))
    pad = 8
    k = 3
    W = max(2 * 240 + cand.width + 4 * pad, 240 * k + 2 * pad, 2 * sheets[0].width + 2 * pad)
    H = pad + STRIP_H + pad + STRIP_H * k + pad + STRIP_H * k + pad + 2 * sheets[0].height + pad + 2 * sheets[1].height + pad
    out = Image.new("RGBA", (W, H), (60, 56, 50, 255))
    y = pad
    out.paste(day, (pad, y))
    out.paste(eve, (2 * pad + 240, y))
    out.paste(cand, (3 * pad + 480, y))
    y += STRIP_H + pad
    out.paste(m.up(day, k), (pad, y))
    y += STRIP_H * k + pad
    out.paste(m.up(eve, k), (pad, y))
    y += STRIP_H * k + pad
    out.paste(m.up(sheets[0], 2), (pad, y))
    y += 2 * sheets[0].height + pad
    out.paste(m.up(sheets[1], 2), (pad, y))
    path = os.path.join(ENV, "tree_v02_board.png")
    out.convert("RGB").save(path)
    print("wrote", os.path.relpath(path, ROOT).replace("\\", "/"), out.size)


# =====================================================================================
# 480x270 목업 (4단계 목업의 바닥·제단·저녁 빛 코드)
# =====================================================================================
TREES = [(13, 3), (18, 2), (23, 4), (27, 2), (16, 13), (25, 13), (3, 13), (8, 15)]
STUMPS = [(21, 7), (28, 8), (11, 12)]


def mockup(tree_img, stump_img, axe_sheet):
    cols, rows = 30, 17
    V = m.vgrid(cols, rows)
    m.vrect(V, 0, 9, 30, 11, "P")      # 큰길
    m.vrect(V, 8, 6, 9, 9, "P")        # 제단 앞으로
    ground, _ = m.surface_ground(V, set(), 20261025)
    base = ground.crop((0, 0, 480, 270))
    emis = Image.new("RGBA", base.size)
    ax = cells(axe_sheet)
    walk = cells(load(os.path.join(PIX, "base_body_v02_walk.png")), CELL)
    idle = cells(load(os.path.join(PIX, "base_body_v02_idle.png")), CELL)
    items = []
    # 제단 (3x3 칸 (7..9, 3..5), altar_v04 48x57: 맨 아래 불투명 줄이 칸 아래 변)
    alt, alt_em = m.altar_lit()
    a_np = np.asarray(alt)
    abot = int(np.nonzero((a_np[..., 3] > 0).any(axis=1))[0].max())
    ax0, ay0 = 7 * 16 + 24 - alt.width // 2, 6 * 16 - 1 - abot
    items.append((6 * 16, 0, ax0, ay0, np.asarray(alt), np.asarray(alt_em)))
    for tx, ty in TREES:
        x, y = tree_origin(tx, ty, tree_img)
        items.append(((ty + 1) * 16, 0, x, y, tree_img, None))
    for tx, ty in STUMPS:
        x, y = tree_origin(tx, ty, stump_img)
        items.append(((ty + 1) * 16, 0, x, y, stump_img, None))
    # 나무 (13, 3) 서쪽 칸에서 동쪽을 보고 도끼질 (4열 = 허리 높이로 내리침)
    fy = 4 * 16
    items.append((fy, 1, *char_origin(12 * 16 + 8, fy), ax[1][HIT_COLUMN], None))
    # 나무 (23, 4) 동쪽 칸에서 서쪽을 보고 도끼를 든 순간 (동 2열 좌우 반전)
    fy = 5 * 16
    items.append((fy, 1, *char_origin(24 * 16 + 8, fy), ax[1][2][:, ::-1].copy(), None))
    # 나무 (16, 13) 아래 칸에서 북쪽을 보고 내리침 (북 4열)
    fy = 15 * 16
    items.append((fy, 1, *char_origin(16 * 16 + 8, fy), ax[2][HIT_COLUMN], None))
    # 그루터기 (21, 7) 옆에서 남쪽을 보는 idle, 길을 걷는 캐릭터
    items.append((8 * 16, 1, *char_origin(22 * 16 + 8, 8 * 16, CELL), idle[0][0], None))
    items.append((11 * 16 - 4, 1, *char_origin(5 * 16, 11 * 16 - 4, CELL), walk[1][2], None))
    for _, _, x, y, a, e in sorted(items, key=lambda t: (t[0], t[1])):
        put(base, a, x, y)
        if e is not None:
            put(emis, e, x, y)
            put(base, e, x, y)
    day = base
    eve = m.darken(base.copy(), emis, [(ax0 + 24, ay0 + 30, 100, 150)])
    for name, img in (("stage4_tree_mockup_v01_day", day), ("stage4_tree_mockup_v01_eve", eve)):
        img = img.convert("RGB")
        img.save(os.path.join(ENV, f"{name}_1x.png"))
        m.up(img, m.K).save(os.path.join(ENV, f"{name}.png"))
        print("wrote", f"assets/concept/04-env/{name}.png (+_1x)")


# =====================================================================================
# 검사
# =====================================================================================
def check():
    ok = True
    for name in ("tree_v02.png", "stump_v01.png"):
        a = load(os.path.join(ENV, name))
        cs = colours(a)
        alpha = set(np.unique(a[..., 3]).tolist())
        cool = [c for c in cs if sum(c) < 200 and c[2] > c[0] + 5]
        hi = max(luma(c) for c in cs)
        edge = edge_mask(a)
        e_out = sum(1 for y, x in zip(*np.nonzero(edge)) if col(a, x, y) == OUT)
        ys, xs = np.nonzero(a[..., 3] > 0)
        print(f"{name}: {a.shape[1]}x{a.shape[0]}, {len(cs)} colours, alpha {sorted(alpha)}, max luma {hi:.1f}, "
              f"cool darks {len(cool)}, edge px outlined {e_out}/{int(edge.sum())}, box x {xs.min()}-{xs.max()} "
              f"y {ys.min()}-{ys.max()} ({xs.max() - xs.min() + 1}x{ys.max() - ys.min() + 1})")
        ok &= len(cs) <= 24 and alpha <= {0, 255} and hi <= 215 and not cool and e_out == int(edge.sum())
    for name in ("tree_v02.png",):
        a = load(os.path.join(ENV, name))
        greens = [c for c in colours(a) if c[1] > c[0] and c[1] > c[2]]
        hues = sorted(round(colorsys.rgb_to_hls(*[v / 255 for v in c])[0] * 360, 1) for c in greens)
        print(f"{name}: crown hues {hues} (sickly olive #6f8f3a = 82.6, grass #80bd5a = 97.0)")
    sh = load(os.path.join(PIX, "base_body_v02_axe.png"))
    sk = load(os.path.join(PIX, "base_body_v02_sickle.png"))
    walk2 = load(os.path.join(PIX, "base_body_v02_walk.png"))
    same = all(np.array_equal(sh[r * ACT + 16:r * ACT + 48, 16:48], walk2[r * CELL:(r + 1) * CELL, 0:CELL]) and
               not sh[r * ACT:(r + 1) * ACT, 0:ACT][..., 3].sum() - walk2[r * CELL:(r + 1) * CELL, 0:CELL][..., 3].sum()
               for r in range(3))
    feet, low, has_iron = [], [], []
    for r in range(3):
        for c in range(0, FRAMES):
            blk = sh[r * ACT:(r + 1) * ACT, c * ACT:(c + 1) * ACT]
            ys = np.nonzero((blk[..., 3] > 0).any(axis=1))[0]
            feet.append(body_feet(blk))
            low.append(int(ys.max()))
            has_iron.append(any(col(blk, x, y) in IRON for y, x in zip(*np.nonzero(blk[..., 3] > 0))))
    cs = colours(sh)
    hi_iron = max(luma(c) for c in IRON)
    bluegrey = [c for c in cs if max(c) - min(c) <= 24 and c[2] > c[0] + 3 and sum(c) > 120]
    alpha = set(np.unique(sh[..., 3]).tolist())
    # 도끼가 없는 재생 열. 마지막 열은 시작 그림(끝 그림 = 시작 그림, 12차 요령)이면 도끼가 없어도 된다
    no_axe = []
    for i, h in enumerate(has_iron):
        r, c = divmod(i, FRAMES)
        if h or c == 0:
            continue
        if c == FRAMES - 1 and np.array_equal(sh[r * ACT:(r + 1) * ACT, c * ACT:(c + 1) * ACT], sh[r * ACT:(r + 1) * ACT, 0:ACT]):
            continue
        no_axe.append(f"{'SEN'[r]}{c}")
    print(f"base_body_v02_axe.png: {sh.shape[1]}x{sh.shape[0]} (sickle {sk.shape[1]}x{sk.shape[0]}), start column = walk "
          f"v02 frame 0: {same}, body feet row per frame (columns 0-6, rows S E N) {feet}, lowest opaque row {low}, "
          f"played columns without the axe {no_axe}, {len(cs)} colours, alpha {sorted(alpha)}, "
          f"blue-grey colours {bluegrey}, iron max luma {hi_iron:.1f}")
    ok &= (sh.shape == sk.shape and same and not bluegrey and all(f == FLOOR for f in feet) and alpha <= {0, 255}
           and not no_axe)
    print("check:", "OK" if ok else "FAILED")
    return ok


def main(what):
    if what in ("tree", "all", "preview", "mockup"):
        t = tree() if what in ("tree", "all") else load(os.path.join(ENV, "tree_v02.png"))
        s = load(os.path.join(ENV, "stump_v01.png"))
    if what in ("axe", "all", "preview", "mockup"):
        a = axe() if what in ("axe", "all") else load(os.path.join(PIX, "base_body_v02_axe.png"))
    if what in ("preview", "all"):
        preview_gif(a)
        board(t, s, a)
    if what in ("mockup", "all"):
        mockup(t, s, a)
    if what in ("check", "all"):
        if not check():
            raise SystemExit(1)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "all")

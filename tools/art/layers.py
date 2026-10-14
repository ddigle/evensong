# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow>=10", "numpy>=1.26"]
# ///
"""3단계 레이어 시험 도구 (brief §5.6 ○ 레이어 구조). 기본 몸 + 파츠 + 표식 장비를 겹친다.

실행: uv run tools/art/layers.py ... (고정 버전은 layers.py.lock)

사용:
  uv run tools/art/layers.py diff 기본.png 입힌.png --out 레이어.png [--tol 0] [--ymin 0]
      두 프레임에서 RGBA가 다른 픽셀만 남긴 레이어. 입힌 쪽이 투명해진 픽셀(지운 픽셀)은 따로 센다.
      바뀐 픽셀 수·영역을 출력한다. 장비 밖에서 바뀐 픽셀이 많으면 몸이 흔들린 것이다
  uv run tools/art/layers.py segment 기본.png 입힌.png --out 레이어.png [--thr 45] [--ymin 0]
      몸이 다시 그려져 diff가 안 될 때: 기본 프레임에 없는 색(가장 가까운 색과 RGB 차 합 > thr)과
      그에 닿은 몸 밖의 어두운 외곽선만 남긴다. 장비 색이 몸 색과 다를 때만 쓸 만하다 (쇠 방패 o, 나무 활 x)
  uv run tools/art/layers.py split 시트.png --out-dir 폴더 --cell 32 [--prefix f]
      가로 한 줄 시트를 cell 크기 프레임으로 자른다
  uv run tools/art/layers.py halo --out 후광.png
      성직자 후광(떠 있는 표식). 낮은 탑다운에서 본 빛 고리 하나로 모든 방향에 쓴다
  uv run tools/art/layers.py bow --out-dir 폴더
      아처 표식(등에 맨 큰 활)을 남·동·북 한 장씩 손으로 그린다. 남·동은 몸 뒤, 북은 몸 앞 레이어
  uv run tools/art/layers.py headtop 프레임.png...
      프레임마다 머리 꼭대기(불투명 픽셀이 처음 나오는 줄)와 좌우 가운데. 떠 있는 표식의 기준점
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def rgba(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(int)


def diff(base, edited, out, tol, ymin=0):
    a, b = rgba(base), rgba(edited)
    if a.shape != b.shape:
        raise SystemExit(f"size differs: {a.shape} vs {b.shape}")
    vis_a, vis_b = a[..., 3] > 0, b[..., 3] > 0
    d = np.abs(a - b).sum(axis=2) > tol
    changed = d & vis_b                      # 새로 그렸거나 색이 바뀐 픽셀
    erased = d & vis_a & ~vis_b              # 입힌 쪽에서 사라진 픽셀
    layer = np.zeros_like(b)
    layer[changed] = b[changed]
    layer[:ymin] = 0
    Image.fromarray(layer.astype(np.uint8)).save(out)
    ys, xs = np.nonzero(changed)
    box = f"x {xs.min()}-{xs.max()} y {ys.min()}-{ys.max()}" if len(xs) else "-"
    print(f"{Path(edited).name}: changed {changed.sum()} (on body {(changed & vis_a).sum()}, "
          f"new {(changed & ~vis_a).sum()}), erased {erased.sum()}, box {box}")


def segment(base, edited, out, thr, ymin):
    a, b = rgba(base), rgba(edited)
    pal = np.unique(a[a[..., 3] > 0][:, :3], axis=0)
    vis = b[..., 3] > 0
    rgb = b[..., :3]
    dist = np.abs(rgb[:, :, None, :] - pal[None, None, :, :]).sum(-1).min(axis=2)
    item = vis & (dist > thr)
    near = np.zeros_like(item)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            near |= np.roll(np.roll(item, dy, 0), dx, 1)
    outline = vis & (rgb.sum(-1) < 150) & near & ~(a[..., 3] > 0)
    m = item | outline
    m[:ymin] = False
    layer = np.zeros_like(b)
    layer[m] = b[m]
    Image.fromarray(layer.astype(np.uint8)).save(out)
    print(f"{Path(edited).name}: item {item.sum()}, outline {outline.sum()}")


def split(sheet, out_dir, cell, prefix):
    im = Image.open(sheet).convert("RGBA")
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    for i in range(im.width // cell):
        im.crop((i * cell, 0, (i + 1) * cell, cell)).save(Path(out_dir) / f"{prefix}{i}.png")
    print("frames", im.width // cell)


# 빛 고리: 가운데가 비고 위쪽 테가 얇은 타원 (낮은 탑다운이라 앞쪽 테가 더 두껍게 보인다)
HALO = [
    "...hhhhhh...",
    ".hg......gh.",
    "hg........gh",
    ".gG......Gg.",
    "...gGGGGg...",
]
HALO_C = {"h": (255, 240, 178, 255), "g": (246, 204, 96, 255), "G": (214, 156, 58, 255)}


def halo(out):
    im = Image.new("RGBA", (len(HALO[0]), len(HALO)))
    for y, row in enumerate(HALO):
        for x, ch in enumerate(row):
            if ch in HALO_C:
                im.putpixel((x, y), HALO_C[ch])
    im.save(out)
    print("saved", out, im.size)


# 등에 맨 큰 활 (아처 표식). 32 프레임 좌표, 2등신 기본 몸의 걷기 프레임(키 약 28px) 기준.
# 방향마다 (위 끝, 아래 끝, 휘는 쪽 조절점). 남·동은 몸 뒤, 북은 몸 앞에 그린다
BOW = {"south": ((8, 3), (25, 23), (4, 20)), "east": ((10, 3), (7, 26), (1, 13)),
       "north": ((25, 3), (8, 24), (30, 19))}
BOW_STRING = {"south": True, "east": True, "north": False}   # 북쪽은 시위가 등에 붙어 안 보인다
BOW_C = {"wood": (150, 98, 54, 255), "lit": (196, 140, 82, 255), "line": (44, 28, 20, 255),
         "string": (232, 222, 196, 255)}


def _curve(p0, p1, c, n=80):
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1]
        pts.append((round(x), round(y)))
    return list(dict.fromkeys(pts))


def bow(out_dir):
    for d, (p0, p1, c) in BOW.items():
        im = Image.new("RGBA", (32, 32))
        wood = set(_curve(p0, p1, c))
        line = {(x + dx, y + dy) for x, y in wood for dx in (-1, 0, 1) for dy in (-1, 0, 1)} - wood
        string = set(_curve(p0, p1, ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2))) - wood - line
        if not BOW_STRING[d]:
            string = set()
        for (x, y) in string:
            if 0 <= x < 32 and 0 <= y < 32:
                im.putpixel((x, y), BOW_C["string"])
        for (x, y) in line:
            if 0 <= x < 32 and 0 <= y < 32:
                im.putpixel((x, y), BOW_C["line"])
        for i, (x, y) in enumerate(sorted(wood, key=lambda p: p[1])):
            if 0 <= x < 32 and 0 <= y < 32:
                im.putpixel((x, y), BOW_C["lit"] if i % 5 == 0 else BOW_C["wood"])
        p = Path(out_dir) / f"bow_{d}.png"
        im.save(p)
        print("saved", p)


def headtop(paths):
    for p in paths:
        a = rgba(p)[..., 3] > 0
        ys, xs = np.nonzero(a)
        top = ys.min()
        row = np.nonzero(a[top:top + 4].any(axis=0))[0]
        print(f"{Path(p).name}: top {top} cx {(row.min() + row.max()) / 2:.1f}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("diff"); s.add_argument("base"); s.add_argument("edited"); s.add_argument("--out", required=True)
    s.add_argument("--tol", type=int, default=0); s.add_argument("--ymin", type=int, default=0)
    s = sub.add_parser("segment"); s.add_argument("base"); s.add_argument("edited"); s.add_argument("--out", required=True)
    s.add_argument("--thr", type=int, default=45); s.add_argument("--ymin", type=int, default=0)
    s = sub.add_parser("split"); s.add_argument("sheet"); s.add_argument("--out-dir", required=True)
    s.add_argument("--cell", type=int, default=32); s.add_argument("--prefix", default="f")
    s = sub.add_parser("halo"); s.add_argument("--out", required=True)
    s = sub.add_parser("headtop"); s.add_argument("paths", nargs="+")
    s = sub.add_parser("bow"); s.add_argument("--out-dir", required=True)
    a = ap.parse_args()
    if a.cmd == "diff":
        diff(a.base, a.edited, a.out, a.tol, a.ymin)
    elif a.cmd == "segment":
        segment(a.base, a.edited, a.out, a.thr, a.ymin)
    elif a.cmd == "split":
        split(a.sheet, a.out_dir, a.cell, a.prefix)
    elif a.cmd == "halo":
        halo(a.out)
    elif a.cmd == "bow":
        bow(a.out_dir)
    else:
        headtop(a.paths)

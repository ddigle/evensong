# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow>=10", "numpy>=1.26"]
# ///
"""컨셉아트 검수 도구. 브리프 §6의 측정 기준과 2단계 시트 비교에 쓴다.

실행: uv run tools/art/arttool.py ... (의존성은 맨 위 script 블록, 고정 버전은 arttool.py.lock. 환경은 uv가 만든다)

사용:
  uv run tools/art/arttool.py measure 이미지...
      356x200 bilinear 축소 후 dark = R+G+B<200, cool = dark 중 B>R+5, purple = B>G+40 이고 R>G+20.
      브리프 §6 ○ 기준: dark 중 cool 30% 미만, 전체 대비 purple 1% 미만
  uv run tools/art/arttool.py grid --out sheet.jpg [--cols 2] 이미지...
      후보 비교 시트. 각 칸 위에 A, B, C... 와 파일명을 붙인다
  uv run tools/art/arttool.py front 시트.png --out 정면.png
      정면·3/4 두 시점 시트에서 왼쪽(정면) 그림만 잘라낸다 (스프라이트 도구 입력용)
  uv run tools/art/arttool.py lineup --out lineup.png [--unit 6] [--upscale 1] 시트.png:이름:키 ...
      시트마다 정면을 잘라 키(px) 비율로 맞춰 한 줄로 세운다.
      게임 크기 확인은 --unit 0.4375 --upscale 6 (인간 64 → 28px, 6배 확대)
  uv run tools/art/arttool.py ref 시트.png --out 입력.png [--canvas 48] [--height 30] [--sole 42]
      3단계 PixelLab image_to_pixelart 입력. 정면을 정사각 캔버스에 놓아, canvas px로 줄였을 때
      키가 height px이고 발바닥이 y=sole이 되게 한다. 1536px로 저장
  uv run tools/art/arttool.py cutout 스프라이트.png --out 투명.png [--tol 24]
      테두리에서 이어진 배경(왼쪽 위 색과 RGB 차 합 tol 이하)을 투명으로
  uv run tools/art/arttool.py regrey 스프라이트.png --out 수정.png x0,y0,x1,y1 ...
      사각형(양 끝 포함) 안의 주황 계열 픽셀을 같은 밝기의 회색으로 (명암 단계는 유지)
"""
import argparse
import colorsys
import os
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFont

BG = (26, 23, 20)
GOLD = (244, 201, 93)


def _font(size):
    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def measure(paths):
    for p in paths:
        im = Image.open(p).convert("RGB")
        a = np.asarray(im.resize((356, 200), Image.BILINEAR)).astype(int)
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        dark = (r + g + b) < 200
        cool = (b > r + 5) & dark
        purple = (b > g + 40) & (r > g + 20)
        cool_pct = cool.sum() / max(dark.sum(), 1) * 100
        verdict = "OK" if cool_pct < 30 and purple.mean() * 100 < 1 else "CHECK"
        print(f"{os.path.basename(p):40s} {im.width}x{im.height} cool_in_dark={cool_pct:.0f}% "
              f"purple={purple.mean() * 100:.2f}% {verdict}")


def grid(paths, out, cols):
    w, h, pad, bar = 1200, 900, 16, 44
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w + (cols + 1) * pad, rows * (h + bar) + (rows + 1) * pad), BG)
    d, font = ImageDraw.Draw(sheet), _font(30)
    for i, p in enumerate(paths):
        im = Image.open(p).convert("RGB")
        im = im.resize((w, int(im.height * w / im.width)), Image.LANCZOS).crop((0, 0, w, h))
        x, y = pad + (i % cols) * (w + pad), pad + (i // cols) * (h + bar + pad)
        d.text((x + 6, y + 6), f"{chr(65 + i)}  {os.path.basename(p)}", fill=GOLD, font=font)
        sheet.paste(im, (x, y + bar))
    sheet.save(out, quality=88)
    print("saved", out, sheet.size)


def front_view(path, margin=0):
    im = Image.open(path).convert("RGB")
    half = im.crop((0, 0, im.width // 2, im.height))
    a = np.asarray(half).astype(int)
    corners = np.concatenate([a[:60, :60].reshape(-1, 3), a[:60, -60:].reshape(-1, 3)])
    mask = np.abs(a - np.median(corners, axis=0)).sum(axis=2) > 45
    rows, cols = np.where(mask.sum(axis=1) > 8)[0], np.where(mask.sum(axis=0) > 8)[0]
    if not len(rows) or not len(cols):
        sys.exit(f"{path}: 그림을 찾지 못했다")
    y0, y1, x0, x1 = rows.min(), rows.max(), cols.min(), cols.max()
    return half.crop((max(0, x0 - margin), max(0, y0 - margin),
                      min(half.width, x1 + 1 + margin), min(half.height, y1 + 1 + margin)))


def lineup(specs, out, unit, upscale):
    figs = []
    for spec in specs:
        path, label, height = spec.rsplit(":", 2)
        f = front_view(path)
        th = int(int(height) * unit)
        g = f.resize((max(1, round(f.width * th / f.height)), th), Image.LANCZOS)
        if upscale > 1:
            g = g.resize((g.width * upscale, g.height * upscale), Image.NEAREST)
        figs.append((g, label))
    pad, bar, gap = 30, 50, 40
    top = max(g.height for g, _ in figs)
    sheet = Image.new("RGB", (sum(g.width for g, _ in figs) + gap * (len(figs) - 1) + 2 * pad,
                              top + 2 * pad + bar), (40, 33, 33))
    d, font, x = ImageDraw.Draw(sheet), _font(22), pad
    for g, label in figs:
        sheet.paste(g, (x, pad + top - g.height))
        d.text((x + g.width // 2 - len(label) * 6, pad + top + 12), label, fill=GOLD, font=font)
        x += g.width + gap
    sheet.save(out)
    print("saved", out, sheet.size)


def sprite_ref(path, out, canvas, height, sole):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(int)
    bg = np.median(np.concatenate([a[:20, :20].reshape(-1, 3), a[-20:, -20:].reshape(-1, 3)]), axis=0)
    mask = np.abs(a - bg).sum(axis=2) > 40
    mask[:, im.width // 2:] = False
    ys, xs = np.where(mask)
    top, bottom, left, right = ys.min(), ys.max(), xs.min(), xs.max()
    scale = height / (bottom - top + 1)
    side = round(canvas / scale)
    ox, oy = round((left + right) / 2 - side / 2), round(bottom - sole / scale)
    board = Image.new("RGB", (side, side), tuple(int(v) for v in bg))
    fig = im.crop((left, top, right + 1, bottom + 1))
    board.paste(fig, (left - ox, top - oy), Image.fromarray((mask[top:bottom + 1, left:right + 1] * 255).astype("uint8")))
    board.resize((1536, 1536), Image.LANCZOS).save(out)
    print("saved", out, f"figure {right - left + 1}x{bottom - top + 1}, canvas {side}px -> 1536")


def cutout(path, out, tol):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    bg = px[0, 0]
    seen = set()
    q = deque([(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)])
    while q:
        x, y = q.popleft()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h) or sum(abs(px[x, y][i] - bg[i]) for i in range(3)) > tol:
            continue
        seen.add((x, y))
        px[x, y] = (0, 0, 0, 0)
        q.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    im.save(out)
    print("saved", out, "bbox", im.getchannel("A").getbbox())


def regrey(path, out, rects):
    im = Image.open(path).convert("RGBA")
    px, n = im.load(), 0
    for r in rects:
        x0, y0, x1, y1 = map(int, r.split(","))
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                c = px[x, y]
                hue, s, v = colorsys.rgb_to_hsv(*(t / 255 for t in c[:3]))
                if c[3] and 10 <= hue * 360 <= 45 and s >= 0.35 and v >= 0.35:
                    lum = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
                    px[x, y] = (round(lum), round(lum * 0.94), round(lum * 0.94), 255)
                    n += 1
    im.save(out)
    print("saved", out, "recoloured", n)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("measure")
    m.add_argument("images", nargs="+")
    g = sub.add_parser("grid")
    g.add_argument("--out", required=True)
    g.add_argument("--cols", type=int, default=2)
    g.add_argument("images", nargs="+")
    f = sub.add_parser("front")
    f.add_argument("sheet")
    f.add_argument("--out", required=True)
    f.add_argument("--margin", type=int, default=60)
    l = sub.add_parser("lineup")
    l.add_argument("--out", required=True)
    l.add_argument("--unit", type=float, default=6.0)
    l.add_argument("--upscale", type=int, default=1)
    l.add_argument("specs", nargs="+", help="시트.png:이름:키(px)")
    r = sub.add_parser("ref")
    r.add_argument("sheet")
    r.add_argument("--out", required=True)
    r.add_argument("--canvas", type=int, default=48)
    r.add_argument("--height", type=int, default=30)
    r.add_argument("--sole", type=int, default=42)
    c = sub.add_parser("cutout")
    c.add_argument("image")
    c.add_argument("--out", required=True)
    c.add_argument("--tol", type=int, default=24)
    rg = sub.add_parser("regrey")
    rg.add_argument("image")
    rg.add_argument("--out", required=True)
    rg.add_argument("rects", nargs="+", help="x0,y0,x1,y1")
    a = ap.parse_args()
    if a.cmd == "measure":
        measure(a.images)
    elif a.cmd == "grid":
        grid(a.images, a.out, a.cols)
    elif a.cmd == "front":
        front_view(a.sheet, a.margin).save(a.out)
        print("saved", a.out)
    elif a.cmd == "ref":
        sprite_ref(a.sheet, a.out, a.canvas, a.height, a.sole)
    elif a.cmd == "cutout":
        cutout(a.image, a.out, a.tol)
    elif a.cmd == "regrey":
        regrey(a.image, a.out, a.rects)
    else:
        lineup(a.specs, a.out, a.unit, a.upscale)


if __name__ == "__main__":
    main()

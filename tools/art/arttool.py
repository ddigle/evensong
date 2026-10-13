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
"""
import argparse
import os
import sys

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
    a = ap.parse_args()
    if a.cmd == "measure":
        measure(a.images)
    elif a.cmd == "grid":
        grid(a.images, a.out, a.cols)
    elif a.cmd == "front":
        front_view(a.sheet, a.margin).save(a.out)
        print("saved", a.out)
    else:
        lineup(a.specs, a.out, a.unit, a.upscale)


if __name__ == "__main__":
    main()

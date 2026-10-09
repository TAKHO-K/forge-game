"""BOSS-NIGHT-2 3 지진파 균열 텍스처(client/BossGroundMarks - 판 1장 = 균열 여러 줄 · 파트 수 줄이기).

사용: python roblox/tools/fx/ground_crack_png.py → roblox/art/fx/ground_crack_v1.png (512 · 투명 배경)
  회색 갈라짐(보스별 색조 = Decal.Color3가 곱한다 - 어둡게) + 가운데 옅은 밝은 선(아주 약한 번개빛) + 작은 파편. 시드 고정(다시 만들어도 같은 그림).
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "art", "fx", "ground_crack_v1.png")
S = 512
rng = random.Random(20261009)


def jagged(x, y, ang, length, steps):
    pts = [(x, y)]
    for _ in range(steps):
        ang += rng.uniform(-0.55, 0.55)
        seg = length / steps * rng.uniform(0.7, 1.3)
        x += math.cos(ang) * seg
        y += math.sin(ang) * seg
        pts.append((x, y))
    return pts


def main():
    crack = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dc, dg = ImageDraw.Draw(crack), ImageDraw.Draw(glow)
    cx = cy = S / 2
    lines = []
    for i in range(5):  # 큰 줄 5 + 가지
        ang = i / 5 * 2 * math.pi + rng.uniform(-0.4, 0.4)
        start = (cx + math.cos(ang) * 20, cy + math.sin(ang) * 20)
        main_line = jagged(start[0], start[1], ang, rng.uniform(170, 230), 9)
        lines.append((main_line, 12))
        for _ in range(2):
            k = rng.randint(2, 6)
            bx, by = main_line[k]
            lines.append((jagged(bx, by, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.1), rng.uniform(50, 110), 5), 6))
    for pts, w in lines:
        dc.line(pts, fill=(70, 70, 76, 235), width=w, joint="curve")
        dg.line(pts, fill=(225, 238, 255, 70), width=max(2, w // 4), joint="curve")
    for _ in range(26):  # 파편
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(30, 230)
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        s = rng.uniform(5, 13)
        poly = [(x + math.cos(t) * s * rng.uniform(0.6, 1.2), y + math.sin(t) * s * rng.uniform(0.6, 1.2)) for t in (0, 2.1, 4.2)]
        dc.polygon(poly, fill=(82, 80, 88, 220))
    crack = crack.filter(ImageFilter.GaussianBlur(0.8))
    glow = glow.filter(ImageFilter.GaussianBlur(1.6))
    out = Image.alpha_composite(crack, glow)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print("saved", os.path.normpath(OUT), out.size)


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
# QUEUE-ALL9C 2-3 메인 메뉴 배경 카툰 후처리(시스템 python + Pillow · numpy - compose.py와 같은 도구, 설치 없음).
# 원본 = roblox/art/ui/raw/menu_<장소>.jpg(Studio 캡처 · HUD · 이름표 · 내 캐릭터 숨김) → roblox/art/ui/menu_<장소>.png(폭 1024 이하).
# 처리: 부드럽게(잔결 지우기) → 색 단계 줄이기 → 채도 약간 올림 → 부드러운 외곽선(밝기 경계를 흐려 곱하기).
# 사용: python roblox/tools/blender/cartoon_menu_bg.py  (원본 전부) → 그다음 upload.py ui/menu_*.png
import glob
import os

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))  # roblox/
RAW = os.path.join(ROOT, "art", "ui", "raw")
OUT = os.path.join(ROOT, "art", "ui")

MAX_WIDTH = 1024
COLORS = 40  # 적응 팔레트 색 수(색 단계 줄이기 - 채널 균등 단계는 하늘에 띠가 생겨 안 씀)
FLAT_MIX = 0.7  # 단계 줄인 색 비율(나머지 = 부드럽게 한 원본 - 하늘 그라데이션 띠 완화)
SATURATION = 1.15
EDGE_STRENGTH = 0.75  # 외곽선 진하기(0 ~ 1)
EDGE_THRESHOLD = 14  # 밝기 차이가 이보다 작으면 선 없음(풀 무늬 같은 잔결)
EDGE_INK = 28.0  # 선 색 밝기


def cartoon(src):
    im = Image.open(src).convert("RGB")
    if im.width > MAX_WIDTH:
        im = im.resize((MAX_WIDTH, round(im.height * MAX_WIDTH / im.width)), Image.LANCZOS)
    smooth = im.filter(ImageFilter.MedianFilter(7)).filter(ImageFilter.MedianFilter(5))
    flat = smooth.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    a = np.asarray(flat).astype(np.float32) * FLAT_MIX + np.asarray(smooth).astype(np.float32) * (1 - FLAT_MIX)
    flat = ImageEnhance.Color(Image.fromarray(a.astype(np.uint8))).enhance(SATURATION)
    gray = smooth.convert("L").filter(ImageFilter.GaussianBlur(0.8))
    edges = np.asarray(gray.filter(ImageFilter.FIND_EDGES)).astype(np.float32)
    edges = np.clip((edges - EDGE_THRESHOLD) * 6.0, 0, 255)
    edge_img = Image.fromarray(edges.astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
    e = np.asarray(edge_img).astype(np.float32)[..., None] / 255.0 * EDGE_STRENGTH
    out = np.asarray(flat).astype(np.float32) * (1.0 - e) + EDGE_INK * e
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def main():
    for src in sorted(glob.glob(os.path.join(RAW, "menu_*.jpg"))):
        name = os.path.splitext(os.path.basename(src))[0]
        dst = os.path.join(OUT, name + ".png")
        img = cartoon(src)
        img.save(dst, optimize=True)
        print("O %s -> %s %dx%d" % (os.path.basename(src), os.path.relpath(dst, ROOT), img.width, img.height))


if __name__ == "__main__":
    main()

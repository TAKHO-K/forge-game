# -*- coding: utf-8 -*-
"""QUEUE-ALL6 E3 아이콘 후처리(시스템 python + Pillow): Blender 512 렌더(ICON_STYLE=v31 - 왼쪽 위 주광 · 그림자 · 하이라이트) → 게임 아이콘 256.

  ① 물체 경계로 자르고 칸의 88% 안에 맞춤(긴 변 = 256 × 0.88) · 가운데
  ② 밝기 · 대비 살짝 올림(어두운 칸 바탕에서 묻히지 않게)
  ③ 굵은 외곽선(알파 팽창 · 짙은 남색) + 그 바깥 얇은 밝은 테(테두리 빛 rim)
  ④ 뒤에 등급색 은은한 둥근 빛(알파 ≤ 0.28 - 드랍 빛기둥 · 실루엣 규칙과 다른 "칸 안 배경"만)
  파일 이름 끝 _<등급>.png 로 등급을 읽는다(없으면 빛 없음). 색 = shared/data/ItemVisualData.gradeVisuals.

사용: python roblox/tools/blender/icon_post.py <폴더> [<폴더> …]   (같은 자리에 덮어씀 - 원본 512는 Blender가 다시 만든다)
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

SIZE = 256
FILL = 0.88
OUTLINE = (20, 22, 32)
RIM = (235, 240, 250)
GRADE = {"normal": (230, 230, 230), "rare": (77, 166, 255), "epic": (166, 77, 255), "legendary": (255, 153, 51), "relic": (255, 215, 0),
         "ancient": (224, 57, 62), "primordial": (255, 60, 200), "transcendent": (214, 176, 62)}


def grade_of(name):
    base = os.path.splitext(name)[0]
    for g in GRADE:
        if base.endswith("_" + g):
            return g
    return None


RAW = os.path.join(os.environ.get("TEMP", "."), "icon_raw512")  # 512 렌더 원본 보관(후처리만 다시 할 때 재렌더 없이 - 저장소 밖)


def process(path):
    im = Image.open(path).convert("RGBA")
    raw = os.path.join(RAW, os.path.basename(os.path.dirname(path)), os.path.basename(path))
    if im.size[0] == 512:
        os.makedirs(os.path.dirname(raw), exist_ok=True)
        im.save(raw)
    elif os.path.exists(raw):
        im = Image.open(raw).convert("RGBA")  # 원본이 있으면 그것으로 다시
    else:  # 이미 후처리한 256 · 원본 없음 = 건너뜀
        return False
    box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if not box:
        return False
    obj = im.crop(box)
    k = SIZE * FILL / max(obj.size)
    obj = obj.resize((max(1, round(obj.size[0] * k)), max(1, round(obj.size[1] * k))), Image.LANCZOS)
    rgb = obj.convert("RGB")
    rgb = rgb.point(lambda v: int(255 * (v / 255) ** 0.85))  # 감마(중간 밝기만 올림 - 흰색은 흰색 · 태초 흰 몸 규칙 유지)
    rgb = ImageEnhance.Color(rgb).enhance(1.15)  # 스튜디오 조명이 깎은 채도(초월 금 · 등급 장식 색)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.06)
    obj = Image.merge("RGBA", (*rgb.split(), obj.getchannel("A")))
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ox, oy = (SIZE - obj.size[0]) // 2, (SIZE - obj.size[1]) // 2
    alpha = Image.new("L", (SIZE, SIZE), 0)
    alpha.paste(obj.getchannel("A"), (ox, oy))
    # ④ 등급 뒤 빛(둥근 · 가장자리로 사라짐)
    g = grade_of(os.path.basename(path))
    if g:
        glow = Image.new("L", (SIZE, SIZE), 0)
        d = ImageDraw.Draw(glow)
        d.ellipse((SIZE * 0.1, SIZE * 0.1, SIZE * 0.9, SIZE * 0.9), fill=int(255 * 0.28))
        glow = glow.filter(ImageFilter.GaussianBlur(SIZE * 0.09))
        canvas.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", (SIZE, SIZE), GRADE[g]).split(), glow)))
    # ③ 밝은 테(바깥 9px) → 짙은 외곽선(6px) → 물체
    rim = alpha.filter(ImageFilter.MaxFilter(19))
    rim = ImageChops.subtract(rim, alpha.filter(ImageFilter.MaxFilter(13))).point(lambda a: int(a * 0.35))
    canvas.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", (SIZE, SIZE), RIM).split(), rim)))
    line = alpha.filter(ImageFilter.MaxFilter(13))
    canvas.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", (SIZE, SIZE), OUTLINE).split(), line)))
    canvas.alpha_composite(obj, (ox, oy))
    canvas.save(path)
    return True


def main():
    n = 0
    for folder in sys.argv[1:]:
        for name in sorted(os.listdir(folder)):
            if name.lower().endswith(".png") and not name.startswith("_"):
                n += 1 if process(os.path.join(folder, name)) else 0
    print("[icon_post] %d개" % n)


if __name__ == "__main__":
    main()

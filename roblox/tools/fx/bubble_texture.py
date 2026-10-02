"""QUEUE-ALL8 E1 젤리 활강 거품 입자 그림(128² · 투명 바탕) → roblox/art/fx/jelly_bubble.png.

사용: python roblox/tools/fx/bubble_texture.py   (Pillow만 - 이미 설치됨)
  진한 민트 몸 + 얇은 진한 청록 테두리 + 왼쪽 위 흰 하이라이트 - 풀(초록) · 눈(흰) · 모래(노랑) 위에서 테두리가 윤곽을 잡는다.
  쓰는 곳 = shared/data/ArtV1CosmeticData jelly.glide.particleTexture(입자 Color는 흰색 - 그림 색 그대로).
"""
import os

from PIL import Image, ImageDraw, ImageFilter

N = 128
SS = 4  # 크게 그려 줄여 가장자리를 매끈하게
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "fx", "jelly_bubble.png"))
BODY = (64, 186, 136, 215)
RIM = (16, 84, 66, 255)
SHINE = (255, 255, 255, 235)


def main():
    S = N * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = 6 * SS
    rim = 7 * SS
    d.ellipse([pad, pad, S - pad, S - pad], fill=RIM)
    d.ellipse([pad + rim, pad + rim, S - pad - rim, S - pad - rim], fill=BODY)
    # 아래쪽 살짝 진하게(둥근 느낌)
    shade = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shade).ellipse([pad + rim, S * 0.45, S - pad - rim, S - pad - rim], fill=(30, 140, 100, 90))
    img = Image.alpha_composite(img, shade.filter(ImageFilter.GaussianBlur(10 * SS)))
    d = ImageDraw.Draw(img)
    d.ellipse([S * 0.27, S * 0.22, S * 0.45, S * 0.38], fill=SHINE)
    d.ellipse([S * 0.50, S * 0.27, S * 0.56, S * 0.33], fill=SHINE)
    img = img.resize((N, N), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("저장", OUT)


if __name__ == "__main__":
    main()

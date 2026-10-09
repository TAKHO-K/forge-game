"""직업 선택 전설 그림: 초록 배경 제거 + 서 있는 자세 1:1 꽉 맞춤 크롭 + 얼굴 256.

기준(class-warrior/archer.png) 분석 결과:
  ref 1536x1024 의 왼쪽 '서 있는 자세' 인물을 배율 1.0 그대로, 여백 0(알파 경계 상자에 꽉 맞춤)으로 자른 것.
  warrior = ref (39,115)-(698,915) -> 660x801 · archer = ref (98,156)-(681,933) -> 585x778.
얼굴 = class-*.png 안의 정사각형(faceRect)을 256으로 LANCZOS 축소.
"""
import os
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(r"C:\Users\xkrgh\vibe\game")
REF = ROOT / "docs/art/ref"
LEG = ROOT / "roblox/art/ui/legends"
OUT = Path(os.environ.get("LEGEND_OUT", "."))  # 결과 · 확인용 시트를 쓸 곳(검수 뒤 class-/face-*.png만 roblox/art/ui/legends로 복사)

G_CORE = 120      # 이 이상 초록도(G - max(R,B))면 확실한 배경 후보
A_BG = 180        # 초록도 이 이상 = 알파 0
A_FG = 25         # 초록도 이 이하 = 알파 1 (가장자리 띠 안에서만)
MIN_BG_COMP = 1   # 키 초록 덩어리는 크기와 무관하게 배경(틈 사이로 비친 키 포함)
G_MIX = 35        # 띠 밖이라도 초록도 이 이상이면 키 섞임으로 보고 알파 추정
G_CAP = 15        # 모든 픽셀 G <= max(R,B) + G_CAP
BAND = 2          # 배경에서 이 픽셀 안쪽까지만 반투명/despill 대상


def key_out(rgb, g_cap=None):
    """rgb uint8 HxWx3 -> RGBA uint8 (배경 투명, 가장자리 despill)."""
    f = rgb.astype(np.float32)
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    gness = g - np.maximum(r, b)

    # 1) 확실한 배경: 강한 키 초록의 큰 연결 성분만 (안쪽의 어두운 초록 디테일은 초록도가 낮아 제외됨)
    core = (gness >= G_CORE) & (g >= 180)
    lab, n = ndi.label(core)
    sizes = ndi.sum(core, lab, range(1, n + 1))
    keep = np.zeros(n + 1, bool)
    keep[1:] = sizes >= MIN_BG_COMP
    bg = keep[lab]

    # 2) 가장자리 띠: 배경에서 BAND px 안 → 초록도로 알파 추정 (C = aF + (1-a)K)
    band = ndi.binary_dilation(bg, iterations=BAND) | (gness > G_MIX)  # 안쪽 틈으로 비친 키 초록 섞인 픽셀도
    a = np.ones(gness.shape, np.float32)
    a_est = np.clip((A_BG - gness) / (A_BG - A_FG), 0, 1)
    a[band] = a_est[band]
    a[bg & (gness >= A_BG)] = 0
    # 반투명 가장자리 부드럽게: 띠 안에서만 살짝 블러와 섞음
    a_blur = ndi.gaussian_filter(a, 0.7)
    a[band] = np.minimum(a[band], 0.5 * a[band] + 0.5 * a_blur[band])

    # 3) despill: 띠 + 1px 에서 G를 max(R,B)로 누름
    sp = ndi.binary_dilation(band, iterations=1)
    g2 = g.copy()
    g2[sp] = np.minimum(g[sp], np.maximum(r[sp], b[sp]))
    g2 = np.minimum(g2, np.maximum(r, b) + (G_CAP if g_cap is None else g_cap))  # 전체: 남은 초록 기 약하게 (어두운 초록 디테일은 초록도가 낮아 영향 없음)
    out = np.dstack([r, g2, b, a * 255]).round().clip(0, 255).astype(np.uint8)
    out[out[..., 3] == 0, :3] = 0
    return out


def standing_bbox(rgba, gap=15):
    """서 있는 자세(왼쪽 큰 덩어리) 무리의 경계 상자. 반짝이·액션 자세는 gap px 넘게 떨어져 있어 빠짐."""
    fg = rgba[..., 3] > 64
    grp = ndi.binary_dilation(fg, iterations=gap)
    lab, n = ndi.label(grp)
    objs = ndi.find_objects(lab)
    sizes = ndi.sum(fg, lab, range(1, n + 1))
    big = [i for i in range(n) if sizes[i] > 20000]
    left = min(big, key=lambda i: objs[i][1].start)
    m = fg & (lab == left + 1)
    ys, xs = np.where(m)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1, m


# 디자인에 초록이 없는 직업은 남은 초록 기를 전부 누른다(망토·머리카락에 번진 올리브 점)
NO_GREEN = {"rogue", "healer"}


def make_class(name):
    rgb = np.array(Image.open(REF / f"class_legend_{name}_v1.png").convert("RGB"))
    rgba = key_out(rgb, 0 if name in NO_GREEN else None)
    x0, y0, x1, y1, m = standing_bbox(rgba)
    rgba[~ndi.binary_dilation(m, iterations=2)] = 0  # 무리 밖(반짝이 등) 제거
    return Image.fromarray(rgba[y0:y1, x0:x1]), (x0, y0, x1, y1)


# 얼굴 정사각형 (class-*.png 좌표 x, y, 크기). warrior/archer는 UiIconData 값.
FACE = {
    "warrior": (173, 13, 314),
    "archer": (165, 5, 266),
    "rogue": (190, 25, 315),   # 눈 중심 ≈ (0.58, 0.57) · 머리 위 살짝 잘림 (archer 구도)
    "healer": (130, 20, 320),  # 눈 중심 ≈ (0.5, 0.55) · 모자 꼭대기 살짝 잘림
}


def make_face(img, rect):
    x, y, s = rect
    return img.crop((x, y, x + s, y + s)).resize((256, 256), Image.LANCZOS)


def on_bg(img, color):
    bg = Image.new("RGBA", img.size, color + (255,))
    bg.alpha_composite(img)
    return bg


def contact_sheet(classes, faces, path, H=420, pad=16):
    rows = []
    for color in [(18, 22, 30), (236, 236, 228)]:
        ims = [on_bg(c.resize((round(c.width * H / c.height), H), Image.LANCZOS), color) for c in classes]
        fs = [on_bg(f, color) for f in faces]
        w1 = sum(i.width for i in ims) + pad * (len(ims) + 1)
        w2 = sum(i.width for i in fs) + pad * (len(fs) + 1)
        W = max(w1, w2)
        row = Image.new("RGBA", (W, H + 256 + pad * 3), color + (255,))
        x = pad
        for i in ims:
            row.paste(i, (x, pad)); x += i.width + pad
        x = pad
        for i in fs:
            row.paste(i, (x, H + pad * 2)); x += i.width + pad
        rows.append(row)
    W = max(r.width for r in rows)
    sheet = Image.new("RGBA", (W, sum(r.height for r in rows)), (0, 0, 0, 255))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y)); y += r.height
    sheet.save(path)


def edge_zoom(img, path, scale=3):
    """가장자리 확인용: 어두운/밝은 배경 합성을 위아래로."""
    a = on_bg(img, (10, 10, 10)); b = on_bg(img, (250, 250, 250))
    s = Image.new("RGBA", (img.width, img.height * 2))
    s.paste(a, (0, 0)); s.paste(b, (0, img.height))
    s.save(path)


if __name__ == "__main__":
    # 검증: 같은 방법으로 warrior/archer를 만들어 기준과 경계 상자·알파 비교
    for n in ["warrior", "archer"]:
        im, box = make_class(n)
        ref = np.array(Image.open(LEG / f"class-{n}.png"))
        mine = np.array(im)
        print(n, "box", box, "size", im.size, "ref", ref.shape[1::-1])
        if mine.shape == ref.shape:
            A, B = mine[..., 3] > 127, ref[..., 3] > 127
            print("  alpha IoU", round((A & B).sum() / (A | B).sum(), 4))

    if len(sys.argv) >= 7:  # 얼굴 사각 덮어쓰기: rx ry rs hx hy hs
        FACE["rogue"] = tuple(int(v) for v in sys.argv[1:4])
        FACE["healer"] = tuple(int(v) for v in sys.argv[4:7])

    classes, faces = [], []
    for n in ["warrior", "archer", "rogue", "healer"]:
        if n in ("warrior", "archer"):
            c = Image.open(LEG / f"class-{n}.png").convert("RGBA")
            f = Image.open(LEG / f"face-{n}.png").convert("RGBA")
        else:
            c, box = make_class(n)
            c.save(OUT / f"class-{n}.png")
            edge_zoom(c, OUT / f"_edge-{n}.png")
            print(n, "box", box, "size", c.size)
            f = make_face(c, FACE[n])
            f.save(OUT / f"face-{n}.png")
            print("  faceRect", FACE[n])
        classes.append(c); faces.append(f)
    contact_sheet(classes, faces, OUT / "contact_sheet.png")

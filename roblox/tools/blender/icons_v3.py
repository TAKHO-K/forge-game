# -*- coding: utf-8 -*-
"""QUEUE-ALL9C 2-5 장비 아이콘 v3 - 명령 한 줄로 전체 재생성(시스템 python + Pillow · Blender = bl.sh · 업로드 = opencloud/upload.py).

사용: python roblox/tools/blender/icons_v3.py [--set all | check16] [--upload] [--sheets]   ·   --crests [--upload] = 세트 문장 6개만
  --set all      = 4직업 × 3부위 × 8등급 + 무기 4 × 8 = 128장(ALL9E 새 메시에서 이 줄 그대로 다시 실행)
  --set check16  = 확인용 16장: 검사 갑옷 · 장갑 · 신발 · 무기 × 일반 · 전설 · 태초 · 초월
  --upload       = roblox/art/icons/gear_v3/*.png(이번 묶음) → upload.py(Decal) → asset-ids.json · ArtAssetIds(이미지 id는 Studio에서 읽어 --images)
  --sheets       = 틀 ⑥을 씌운 비교 시트(부위별 4×4 · 등급별 4×4) → docs/art/ref/compare/ (GPT ⑥ 시안과 나란히)
순서: ① Blender 512 렌더(make_icons_v3.py - 부위별 고정 각도 · 등급 색) ② 후처리 256: 알파 경계 상자로 자르고 긴 변 = 80%(여백 10%) · 가운데 ·
      굵은 외곽선 ③ (선택) 업로드 ④ (선택) 시트. 칸 틀(테두리 · 바탕 · 세트 배지 · 등급 마름모)은 굽지 않는다 = 게임 UI(client/ui/kit/IconFrame)가 그린다.
"""
import json
import os
import re
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))  # roblox/
REPO = os.path.dirname(ROOT)
OUT = os.path.join(ROOT, "art", "icons", "gear_v3")
RAW = os.path.join(os.environ.get("TEMP", "."), "icons_v3_raw512")
IVD = os.path.join(ROOT, "src", "shared", "data", "ItemVisualData.lua")
COMPARE = os.path.join(REPO, "docs", "art", "ref", "compare")
GPT6 = os.path.join(REPO, "docs", "art", "ref", "ChatGPT Image 2026년 10월 3일 오후 07_49_44.png")
FONT = "C:/Windows/Fonts/malgunbd.ttf"

CLASSES = ["greatsword", "dualblade", "bow", "healer"]
KINDS = ["armor", "gloves", "shoes", "weapon"]
GRADES = ["normal", "rare", "epic", "legendary", "relic", "ancient", "primordial", "transcendent"]
SIZE, FIT = 256, 0.80  # 여백 10%(사방)
OUTLINE = (20, 22, 32)
RIM, RIM_ALPHA = (225, 232, 245), 0.55
CELL_BG = (24, 26, 36)  # 칸 바탕(짙은 남) - 등급 어두운 색은 조금만 섞는다(GPT ⑥: 바탕은 거의 같은 남색 · 등급은 테두리가 말한다)
SETS = {"tier1": ((104, 140, 84), "평원"), "tier2": ((122, 96, 180), "수정"), "tier3": ((52, 150, 150), "수몰"),
        "tier4": ((214, 176, 62), "모래"), "tier5": ((130, 190, 240), "폭풍"), "tier6": ((130, 190, 230), "빙하")}  # 배지 색 = ArtImportData.armorSetColors(sub · accent)


def items_for(which):
    if which == "check16":
        return [(k, "greatsword", g) for k in KINDS for g in ("normal", "legendary", "primordial", "transcendent")]
    out = [(k, c, g) for k in ("armor", "gloves", "shoes") for c in CLASSES for g in GRADES]
    return out + [("weapon", c, g) for c in CLASSES for g in GRADES]


def name_of(kind, cls, grade):
    return "%s_%s_%s.png" % (kind, cls, grade)


def grade_colors():
    src = open(IVD, encoding="utf-8").read()
    out = {}
    for g in GRADES:
        m = re.search(r"\n\t\t" + g + r" = \{(.*?)\n\t\t\},", src, re.S)
        body = m.group(1) if m else ""
        def rgb(key):
            k = re.search(r"\b" + key + r" = Color3\.fromRGB\((\d+), (\d+), (\d+)\)", body)
            return tuple(int(x) for x in k.groups()) if k else (128, 128, 128)
        out[g] = {"main": rgb("color"), "light": rgb("light"), "dark": rgb("dark"), "border": rgb("border") if "border =" in body else rgb("color")}
    return out


def render(items):
    os.makedirs(RAW, exist_ok=True)
    arg = ",".join("%s:%s:%s" % it for it in items)
    cmd = ["bash", os.path.join(HERE, "bl.sh"), os.path.join(HERE, "make_icons_v3.py"), "--items", arg, "--out", RAW]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    done = r.stdout.count("[icons_v3] ") - 1
    if r.returncode != 0 or "끝" not in r.stdout:
        print(r.stdout[-2000:], r.stderr[-2000:])
        sys.exit("Blender 렌더 실패")
    print("O 렌더 %d장" % done)


def post(path_in, path_out):
    im = Image.open(path_in).convert("RGBA")
    box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    im = im.crop(box)
    w, h = im.size
    s = SIZE * FIT / max(w, h)
    im = im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((SIZE - im.width) // 2, (SIZE - im.height) // 2))
    a = canvas.getchannel("A")
    grown = a.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(0.6))
    rim = a.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(0.8)).point(lambda v: int(v * RIM_ALPHA))
    out = Image.new("RGBA", canvas.size, RIM + (0,))  # 맨 바깥 = 밝은 테(검은 초월 · 어두운 바탕에서도 모양이 읽히게)
    out.putalpha(rim)
    line = Image.new("RGBA", canvas.size, OUTLINE + (0,))
    line.putalpha(grown)
    out.alpha_composite(line)
    out.alpha_composite(canvas)
    out.save(path_out, optimize=True)


# ── 틀 ⑥(비교 시트용 - 게임은 client/ui/kit/IconFrame이 같은 규칙으로 그린다) ──
def crest(draw, cx, cy, r, zone):
    color, _ = SETS[zone]
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(28, 30, 38), outline=color, width=max(2, r // 5))
    k = r * 0.55
    if zone == "tier1":  # 이삭
        draw.line((cx, cy + k, cx, cy - k), fill=color, width=max(2, r // 6))
        for i in range(3):
            y = cy - k * 0.6 + i * k * 0.5
            draw.line((cx, y + k * 0.25, cx - k * 0.5, y), fill=color, width=max(2, r // 7))
            draw.line((cx, y + k * 0.25, cx + k * 0.5, y), fill=color, width=max(2, r // 7))
    elif zone == "tier2":  # 수정
        draw.polygon([(cx, cy - k), (cx + k * 0.5, cy), (cx, cy + k), (cx - k * 0.5, cy)], fill=color)
    elif zone == "tier3":  # 물결
        for i in range(2):
            draw.arc((cx - k, cy - k * 0.6 + i * k * 0.6, cx + k, cy + k * 0.4 + i * k * 0.6), 200, 340, fill=color, width=max(2, r // 6))
    elif zone == "tier4":  # 해
        draw.ellipse((cx - k * 0.45, cy - k * 0.45, cx + k * 0.45, cy + k * 0.45), fill=color)
    elif zone == "tier5":  # 번개
        draw.polygon([(cx + k * 0.2, cy - k), (cx - k * 0.4, cy + k * 0.1), (cx, cy + k * 0.1), (cx - k * 0.2, cy + k), (cx + k * 0.45, cy - k * 0.15), (cx + k * 0.05, cy - k * 0.15)], fill=color)
    else:  # 눈꽃
        for i in range(3):
            import math
            a = math.pi / 3 * i
            draw.line((cx - k * math.cos(a), cy - k * math.sin(a), cx + k * math.cos(a), cy + k * math.sin(a)), fill=color, width=max(2, r // 6))


def framed(icon_path, grade, zone, colors, size=256):
    c = colors[grade]
    cell = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(cell)
    rad = size // 10
    d.rounded_rectangle((0, 0, size - 1, size - 1), rad, fill=c["border"])  # 바깥 테두리 = 등급(초월 = 금)
    b = max(4, size // 28)
    d.rounded_rectangle((b, b, size - 1 - b, size - 1 - b), rad - b // 2, fill=c["light"])
    b2 = b + max(2, size // 64)
    bg_dark = tuple(int(CELL_BG[i] * 0.82 + c["dark"][i] * 0.18) for i in range(3))  # 바탕 = 칸 남색 82% + 등급 어두운 색 18%
    d.rounded_rectangle((b2, b2, size - 1 - b2, size - 1 - b2), rad - b2 // 2, fill=bg_dark)
    if os.path.exists(icon_path):
        ic = Image.open(icon_path).convert("RGBA").resize((size - b2 * 2, size - b2 * 2), Image.LANCZOS)
        cell.alpha_composite(ic, (b2, b2))
    r = size // 9
    crest(d, b2 + r + 4, b2 + r + 4, r, zone)  # 좌상단 = 세트 문장
    m = size // 14
    cx, cy = size - b2 - m - 6, b2 + m + 6  # 우상단 = 등급 마름모
    d.polygon([(cx, cy - m), (cx + m, cy), (cx, cy + m), (cx - m, cy)], fill=c["border"], outline=c["light"])
    return cell


def sheets(colors):
    os.makedirs(COMPARE, exist_ok=True)
    font = ImageFont.truetype(FONT, 22)
    cs = 220
    def grid(title, rows, path):
        W = 4 * cs + 5 * 14
        H = 60 + 4 * cs + 5 * 14
        sheet = Image.new("RGBA", (W, H), (238, 240, 244, 255))
        d = ImageDraw.Draw(sheet)
        d.text((14, 16), title, font=font, fill=(30, 30, 40))
        for ri, row in enumerate(rows):
            for ci, (kind, cls, grade, zone) in enumerate(row):
                cell = framed(os.path.join(OUT, name_of(kind, cls, grade)), grade, zone, colors, cs)
                sheet.alpha_composite(cell, (14 + ci * (cs + 14), 60 + ri * (cs + 14)))
        if os.path.exists(GPT6):  # GPT ⑥ 시안과 나란히
            ref = Image.open(GPT6).convert("RGBA")
            ref = ref.resize((round(ref.width * H / ref.height), H), Image.LANCZOS)
            both = Image.new("RGBA", (W + ref.width + 20, H), (255, 255, 255, 255))
            both.alpha_composite(sheet, (0, 0))
            both.alpha_composite(ref, (W + 20, 0))
            sheet = both
        sheet.convert("RGB").save(path, optimize=True)
        print("O 시트", os.path.relpath(path, REPO))
    zones = ["tier1", "tier2", "tier3", "tier4"]
    g4 = ["normal", "legendary", "primordial", "transcendent"]
    # 부위별 4×4: 행 = 갑옷 · 장갑 · 신발 · 무기 · 열 = 등급 4(같은 부위 = 같은 각도 · 크기 확인)
    grid("아이콘 v3 · 부위별 4×4(행 = 갑옷 · 장갑 · 신발 · 무기 / 열 = 일반 · 전설 · 태초 · 초월) · 틀 ⑥",
         [[(k, "greatsword", g, zones[i]) for i, g in enumerate(g4)] for k in KINDS], os.path.join(COMPARE, "icons-v3-by-part.png"))
    # 등급별 4×4: 행 = 등급 · 열 = 부위(같은 등급 = 같은 틀 색 확인)
    grid("아이콘 v3 · 등급별 4×4(행 = 일반 · 전설 · 태초 · 초월 / 열 = 갑옷 · 장갑 · 신발 · 무기) · 틀 ⑥",
         [[(k, "greatsword", g, zones[i]) for i, k in enumerate(KINDS)] for g in g4], os.path.join(COMPARE, "icons-v3-by-grade.png"))


def crests():
    """세트 문장 6개(칸 좌상단 배지 - 게임 UI가 ArtAssetIds["icons/ui/set_<구역>"]로 읽는다) → roblox/art/icons/ui/set_<구역>.png 128 투명"""
    out = []
    for zone in SETS:
        im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        crest(ImageDraw.Draw(im), 256, 256, 240, zone)
        path = os.path.join(ROOT, "art", "icons", "ui", "set_%s.png" % zone)
        im.resize((128, 128), Image.LANCZOS).save(path, optimize=True)
        out.append("icons/ui/set_%s.png" % zone)
    print("O 세트 문장 %d" % len(out))
    return out


def main():
    args = sys.argv[1:]
    if "--crests" in args:  # 세트 문장만(한 번 - 새 세트가 생길 때)
        files = crests()
        if "--upload" in args:
            subprocess.run([sys.executable, os.path.join(ROOT, "tools", "opencloud", "upload.py")] + files)
        return
    which = args[args.index("--set") + 1] if "--set" in args else "check16"
    items = items_for(which)
    render(items)
    os.makedirs(OUT, exist_ok=True)
    for it in items:
        post(os.path.join(RAW, name_of(*it)), os.path.join(OUT, name_of(*it)))
    print("O 후처리 %d장 → %s" % (len(items), os.path.relpath(OUT, REPO)))
    if "--upload" in args:
        files = ["icons/gear_v3/" + name_of(*it) for it in items]
        r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "opencloud", "upload.py")] + files)
        if r.returncode != 0:
            sys.exit("업로드 실패")
    if "--sheets" in args:
        sheets(grade_colors())


if __name__ == "__main__":
    main()

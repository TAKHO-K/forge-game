# -*- coding: utf-8 -*-
# A2-N1 모음 이미지(시스템 python): 메타(삼각형) + 렌더 PNG → Claude outputs/ART-night/*.png. 라벨 값은 매번 메타에서 다시 읽는다.
# 사용: python sheets.py <이름> [...]   이름 = greatsword | weapons
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
from compose import compose  # noqa: E402

NIGHT = os.path.join(ROOT, "Claude outputs", "ART-night")
ART = os.path.join(ROOT, "roblox", "art")
GRADES = ["normal", "rare", "epic", "legendary", "relic", "ancient", "primordial", "transcendent"]
KO = {"normal": "일반", "rare": "희귀", "epic": "영웅", "legendary": "전설", "relic": "유물", "ancient": "고대", "primordial": "태초", "transcendent": "초월"}
WKO = {"greatsword": "대검", "dualblade": "쌍검", "bow": "활", "healer": "지팡이"}


def meta(kind, name):
    path = os.path.join(ART, kind, "%s.meta.json" % name)
    return json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}


def weapon_img(w, g, view):
    folder = "greatsword" if w == "greatsword" else "weapons"
    return os.path.join(NIGHT, folder, "%s_%s_%s.png" % (w, g, view))


def greatsword():
    m = meta("weapons", "greatsword").get("looks", {})
    items = [(weapon_img("greatsword", g, "game_front"), "%s %s△" % (KO[g], m.get(g, {}).get("totalTris", "?"))) for g in GRADES]
    items += [(weapon_img("greatsword", g, "sil_front"), KO[g] + " 실루엣") for g in GRADES]
    items += [(weapon_img("greatsword", g, "game_34"), KO[g] + " 45도") for g in GRADES]
    compose(os.path.join(NIGHT, "greatsword-ladder.png"), items, cols=8, title="대검 8등급 사다리 (A2-N1)", cell=230)


def weapons():
    """4무기 × 8등급(없는 칸은 회색) - weapons-ladder.png"""
    items = []
    for w in WKO:
        m = meta("weapons", w).get("looks", {})
        for g in GRADES:
            t = m.get(g, {}).get("totalTris")
            items.append((weapon_img(w, g, "game_front") if t else "", "%s %s %s" % (WKO[w], KO[g], ("%d△" % t) if t else "-")))
    compose(os.path.join(NIGHT, "weapons-ladder.png"), items, cols=8, title="무기 4종 × 8등급 (A2-N1)", cell=200)


def icons():
    """아이콘 512 → 256(LANCZOS · 투명 유지) + 모음 icons.png(체크 무늬 위 · 등급 테두리 색 예시)"""
    from PIL import Image, ImageDraw
    rows = []
    for kind in ("weapons", "armor"):
        folder = os.path.join(ART, "icons", kind)
        if not os.path.isdir(folder):
            continue
        for fn in sorted(os.listdir(folder)):
            if not fn.endswith(".png"):
                continue
            path = os.path.join(folder, fn)
            im = Image.open(path).convert("RGBA")
            if im.size != (256, 256):  # 갓 렌더한 512만: 256으로 줄이고 흰 40% 림 2px(어두운 UI 배경에서 짙은 물체가 묻히지 않게 - 한 번만)
                im = im.resize((256, 256), Image.LANCZOS)
                from PIL import ImageFilter
                a = im.getchannel("A").point(lambda v: 255 if v > 24 else 0)
                rim = a.filter(ImageFilter.MaxFilter(5))
                layer = Image.new("RGBA", im.size, (255, 255, 255, 0))
                layer.putalpha(rim.point(lambda v: 102 if v else 0))
                layer.alpha_composite(im)
                im = layer
                im.save(path)
            rows.append((kind, fn[:-4], im))
    GC = {"normal": (230, 230, 230), "rare": (77, 166, 255), "epic": (166, 77, 255), "legendary": (255, 153, 51), "relic": (255, 215, 0), "ancient": (224, 57, 62), "primordial": (255, 60, 200), "transcendent": (214, 176, 62)}
    items = []
    tmp = os.path.join(NIGHT, "icons")
    os.makedirs(tmp, exist_ok=True)
    for kind, name, im in rows:
        grade = name.rsplit("_", 1)[1]
        cell = Image.new("RGBA", (256, 256), (58, 56, 72, 255))
        d = ImageDraw.Draw(cell)
        d.rectangle((3, 3, 252, 252), outline=GC.get(grade, (200, 200, 200)) + (255,), width=6)  # UI 테두리 예시(아이콘 파일에는 없음)
        cell.alpha_composite(im)
        out = os.path.join(tmp, "%s__%s.png" % (kind, name))
        cell.convert("RGB").save(out)
        items.append((out, name))
    compose(os.path.join(NIGHT, "icons.png"), items, cols=8, title="아이콘 256×256 투명(칸 테두리 = UI 등급색 예시 · 파일에는 물체만)", cell=160)


if __name__ == "__main__":
    for n in sys.argv[1:]:
        globals()[n]()

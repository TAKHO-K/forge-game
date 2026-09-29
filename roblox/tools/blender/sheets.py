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


if __name__ == "__main__":
    for n in sys.argv[1:]:
        globals()[n]()

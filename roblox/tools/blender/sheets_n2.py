# -*- coding: utf-8 -*-
# A2-N2 모음 이미지(시스템 python): 렌더 PNG(Claude outputs/ART-N2/…) + 메타 → Claude outputs/ART-N2/*.png. 이전 = ART-night(A2-N1) 렌더.
# 사용: python sheets_n2.py bosses pets weapons hammer armor
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
from compose import compose  # noqa: E402

N2 = os.path.join(ROOT, "Claude outputs", "ART-N2")
NIGHT = os.path.join(ROOT, "Claude outputs", "ART-night")
ART = os.path.join(ROOT, "roblox", "art")
GRADES = ["normal", "rare", "epic", "legendary", "relic", "ancient", "primordial", "transcendent"]
KO = {"normal": "일반", "rare": "희귀", "epic": "영웅", "legendary": "전설", "relic": "유물", "ancient": "고대", "primordial": "태초", "transcendent": "초월"}


def meta(kind, name):
    p = os.path.join(ART, kind, "%s.meta.json" % name)
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else {}


BOSS = {"section_guardian": ("구간 수호자", 8.0), "frost_giant": ("서리 거인", 8.0), "abyssal_lord": ("심해 군주", 8.0), "crystal_queen": ("수정 여왕", 8.2),
        "storm_lord": ("폭풍 군주", 8.2), "scorpion_queen": ("전갈 여왕", 8.0)}


def bosses():
    items = []
    for b, (ko, sc) in BOSS.items():
        m = meta("bosses", b)
        items += [(os.path.join(NIGHT, "bosses", "%s_game_front.png" % b), "%s 이전(A2-N1)|티어 색" % ko),
                  (os.path.join(N2, "bosses", "%s_game_front.png" % b), "%s A2-N2 %.1f|%d△ · 파트 %d/%d" % (ko, sc, m.get("totalTris", 0), m.get("partCount", 0), m.get("partCap", 0))),
                  (os.path.join(N2, "bosses", "%s_game_34.png" % b), "45도"), (os.path.join(N2, "bosses", "%s_sil_front.png" % b), "실루엣")]
    compose(os.path.join(N2, "bosses-v2.png"), items, cols=4, title="보스 6종 v2 - 종 테마 색 · 상한 40(전갈 48) · 외곽선 껍데기 10 균형", cell=300)


def pets():
    items = []
    GK = {"normal": "보통", "good": "좋은", "rare": "희귀"}
    for body, ko in (("dog", "강아지"), ("cat", "고양이"), ("dragon", "새끼 용")):
        m = meta("pets", body).get("looks", {})
        for g in ("normal", "good", "rare"):
            items.append((os.path.join(N2, "pets", "%s_%s_game_34.png" % (body, g)), "%s %s %d△" % (ko, GK[g], m.get(g, {}).get("totalTris", 0))))
            items.append((os.path.join(N2, "pets", "%s_%s_game_front.png" % (body, g)), "정면"))
    compose(os.path.join(N2, "pets-v2.png"), items, cols=6, title="펫 3 × 알 등급 3 v2 - 좋은 = 장식 · 희귀 = 장식 + 보석 · 무늬 · 왕관", cell=240)


def weapons():
    items = []
    WKO = {"dualblade": "쌍검", "bow": "활", "healer": "지팡이"}
    for w, ko in WKO.items():
        m = meta("weapons", w).get("looks", {})
        for g in GRADES:
            items.append((os.path.join(N2, "weapons", "%s_%s_game_front.png" % (w, g)), "%s %s %d△" % (ko, KO[g], m.get(g, {}).get("totalTris", 0))))
        for g in ("normal", "rare", "epic"):
            items.append((os.path.join(NIGHT, "weapons", "%s_%s_game_front.png" % (w, g)), "이전 %s" % KO[g]))
        items += [("", "")] * 5
    compose(os.path.join(N2, "weapons-ladder-v2.png"), items, cols=8, title="쌍검 · 활 · 지팡이 8등급 v2 - 희귀 · 영웅 실루엣 요소(아래 줄 = 이전 일반 · 희귀 · 영웅)", cell=200)


def hammer():
    m = meta("weapons", "paladin").get("looks", {})
    items = [(os.path.join(N2, "weapons", "paladin_%s_game_front.png" % g), "%s %d△ · 파트 %d" % (KO[g], m.get(g, {}).get("totalTris", 0), m.get(g, {}).get("partCount", 0))) for g in GRADES]
    items += [(os.path.join(N2, "weapons", "paladin_%s_game_34.png" % g), "45도") for g in GRADES]
    items += [(os.path.join(ART, "icons", "weapons", "paladin_%s.png" % g), "아이콘") for g in GRADES]
    compose(os.path.join(N2, "hammer-ladder.png"), items, cols=8, title="성기사 뿅망치 8등급(게임 연결 없음)", cell=210)


def armor():
    m = meta("armor", "armor_wear").get("tris", {})
    items = []
    for z, ko in (("tier1", "석조"), ("tier2", "수정"), ("tier3", "수몰"), ("tier4", "모래"), ("tier5", "폭풍"), ("tier6", "빙하")):
        for sl, sko in (("armor", "갑옷"), ("gloves", "장갑"), ("shoes", "신발")):
            for g in ("normal", "legendary", "transcendent"):
                key = "%s_%s_%s" % (sl, z, g)
                items.append((os.path.join(N2, "armor", "%s_game_%s.png" % (key, "front" if sl == "armor" else "34")), "%s %s %s|%d△ · 파트 %d" % (ko, sko, KO[g], m.get(key, {}).get("tris", 0), m.get(key, {}).get("parts", 0))))
    compose(os.path.join(N2, "armor-v2.png"), items, cols=9, title="방어구 착용형 v2 - R15 기준 체형(회색)에 붙은 조각 · 일반 / 전설 / 초월", cell=190)
    icons = []
    for z in ("tier1", "tier2", "tier3", "tier4", "tier5", "tier6"):
        for sl in ("armor", "gloves", "shoes"):
            for g in ("normal", "legendary", "transcendent"):
                icons.append((os.path.join(ART, "icons", "armor", "%s_%s_%s.png" % (sl, z, g)), "%s %s %s" % (sl, z, KO[g])))
    compose(os.path.join(N2, "armor-icons-v2.png"), icons, cols=9, title="방어구 아이콘 v2(144 중 54)", cell=150)


if __name__ == "__main__":
    for n in sys.argv[1:]:
        globals()[n]()

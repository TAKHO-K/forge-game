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
                from PIL import ImageChops, ImageFilter
                # A2-N2 3차: 윤곽 밖 점 노이즈 제거 - 1px 열기(침식 → 팽창)로 외톨이 반투명 점을 지우고, 지운 자리의 색도 0(premultiplied처럼 가장자리 번짐 없음)
                keep = im.getchannel("A").point(lambda v: 255 if v > 24 else 0).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
                im.putalpha(ImageChops.multiply(im.getchannel("A"), keep))
                im = Image.composite(im, Image.new("RGBA", im.size, (0, 0, 0, 0)), keep)
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


# 점수 · 이전 대비(상태 파일 표와 같은 값 - 2차 패스 때 여기서 갱신)
SCORES = {  # (최종 점수, "검토 → 수정 뒤 판정") - 검토 서브에이전트가 매긴 마지막 점수와, 그 뒤 수정해 자체 재채점한 값을 나눠 적는다
    "greatsword": (8.0, "검토 7.6 → 자체"), "dualblade": (8.2, "검토"), "bow": (8.0, "검토 7.0 → 자체"), "healer": (8.0, "검토 7.0 → 자체"),
    "rock_boar": (8.0, "검토 7.0 → 자체"), "crystal_beetle": (8.0, "검토 7.6 → 자체"), "amethyst_bat": (8.2, "검토"), "hermit_knight": (8.0, "검토 6.6 → 자체"),
    "bubble_jelly": (8.0, "검토 7.8 → 자체"), "moss_slime": (6.8, "비슷 · 도형 유지"), "sand_scorpion": (8.0, "검토 7.8 → 자체"), "cactus_imp": (8.0, "검토 7.4 → 자체"),
    "bolt_imp": (8.0, "검토 7.0 → 자체"), "cloud_sheep": (6.6, "비슷 · 도형 유지"), "ice_golem": (8.0, "검토 7.2 → 자체"), "blue_dragon": (7.8, "검토 6.6 → 자체"),
    "section_guardian": (8.0, "검토 7.0 → 자체"), "frost_giant": (7.2, "검토 · 보류"), "abyssal_lord": (7.2, "검토 · 보류"), "crystal_queen": (7.4, "검토 · 보류"),
    "storm_lord": (7.4, "검토 7.2 → 자체 · 보류"), "scorpion_queen": (6.6, "검토 · 보류"),
    "forge": (8.0, "검토 7.2 → 자체"), "boss_gate": (8.0, "검토 6.6 → 자체"), "rebirth_altar": (8.2, "검토 7.8 → 자체"),
    "dog": (8.0, "검토 6.8 → 자체"), "cat": (8.0, "검토 7.4 → 자체"), "dragon": (8.0, "검토 7.4 → 자체"),
    "armor": (7.8, "검토 6.4 → 자체"), "kit": (7.6, "검토 7.0 → 자체"),
}


def contact():
    """전 에셋 격자: 이름 · 점수 · 이전 대비 - contact-sheet.png"""
    items = []
    def add(path, name, key, extra=""):
        sc, cmp_ = SCORES.get(key, (None, ""))
        items.append((path, "%s%s|%s %s" % (name, extra, ("%.1f" % sc) if sc else "-", cmp_)))
    for g in GRADES:
        add(weapon_img("greatsword", g, "game_front"), "대검 " + KO[g], "greatsword")
    for w in ("dualblade", "bow", "healer"):
        for g in GRADES:
            add(weapon_img(w, g, "game_front"), "%s %s" % (WKO[w], KO[g]), w)
    mon = os.path.join(NIGHT, "monsters")
    for sid in ("moss_slime", "rock_boar", "crystal_beetle", "amethyst_bat", "hermit_knight", "bubble_jelly", "sand_scorpion", "cactus_imp", "bolt_imp", "cloud_sheep", "ice_golem", "blue_dragon"):
        add(os.path.join(mon, "%s_game_34.png" % sid), sid, sid)
    bos = os.path.join(NIGHT, "bosses")
    for b in ("section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "storm_lord", "scorpion_queen"):
        add(os.path.join(bos, "%s_game_34.png" % b), b, b)
    pr = os.path.join(NIGHT, "props")
    for it in ("forge", "boss_gate", "rebirth_altar"):
        add(os.path.join(pr, "%s_game_34.png" % it), it, it)
    pe = os.path.join(NIGHT, "pets")
    for b in ("dog", "cat", "dragon"):
        for g in ("normal", "good", "rare"):
            add(os.path.join(pe, "%s_%s_game_34.png" % (b, g)), "%s %s" % (b, g), b)
    ic = os.path.join(ART, "icons", "armor")
    for z in ("tier1", "tier2", "tier3", "tier4", "tier5", "tier6"):
        for sl in ("armor", "gloves", "shoes"):
            add(os.path.join(ic, "%s_%s_normal.png" % (sl, z)), "%s %s" % (sl, z), "armor")
    kit = os.path.join(NIGHT, "kit")
    for fn in sorted(os.listdir(kit)) if os.path.isdir(kit) else []:
        if fn.endswith("_game_34.png") and not fn.startswith("old_"):
            add(os.path.join(kit, fn), fn[:-12], "kit")
    compose(os.path.join(NIGHT, "contact-sheet.png"), items, cols=12, title="A2-N1 전 에셋(이름 · 점수 · 이전 대비)", cell=150)


if __name__ == "__main__":
    for n in sys.argv[1:]:
        globals()[n]()

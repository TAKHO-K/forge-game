# QUEUE-ALL9C 2-2 등급 색 검사: ① ART-REF v2 2절 표(docs/design/gear-art-v3.md) hex = ItemVisualData 값(메인 · 밝은 · 어두운)
#   ② 글자색(text)이 어두운 패널 · 칸 위 대비 4.5:1 이상 ③ 옛 등급 색(웹 v1 · G1-1 자홍 · 옛 초월 금)이 src에 남았는지(3D · 허브 장식은 ALL9E - 목록만)
# 사용: python roblox/tools/check_grade_colors.py  → 끝 줄 "결과: 통과|실패"
import io, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "roblox", "src")
DOC = os.path.join(ROOT, "docs", "design", "gear-art-v3.md")
IVD = os.path.join(SRC, "shared", "data", "ItemVisualData.lua")
UIC = os.path.join(SRC, "shared", "data", "UIColors.lua")
NAMES = {"일반": "normal", "희귀": "rare", "영웅": "epic", "전설": "legendary", "유물": "relic", "고대": "ancient", "태초": "primordial", "초월": "transcendent"}

fail = []


def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def lum(rgb):
    r, g, b = rgb
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def contrast(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def hex2rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


doc = io.open(DOC, encoding="utf-8").read()
want = {}
for line in doc.splitlines():
    m = re.match(r"^\| (일반|희귀|영웅|전설|유물|고대|태초|초월) \| (#[0-9A-Fa-f]{6}) \| (#[0-9A-Fa-f]{6}) \| (?:강조 |균열 )?(#[0-9A-Fa-f]{6}) \|", line)
    if m:
        want[NAMES[m.group(1)]] = tuple(hex2rgb(x) for x in m.group(2, 3, 4))
if len(want) != 8:
    fail.append("문서 2절 표 8줄 못 읽음(%d)" % len(want))

src = io.open(IVD, encoding="utf-8").read()
have = {}
for g in NAMES.values():
    m = re.search(r"\n\t\t" + g + r" = \{(.*?)\n\t\t\},", src, re.S)
    if not m:
        fail.append("ItemVisualData %s 없음" % g)
        continue
    body = m.group(1)
    def get(key):
        mm = re.search(r"\b" + key + r" = Color3\.fromRGB\((\d+), (\d+), (\d+)\)", body)
        return tuple(int(x) for x in mm.groups()) if mm else None
    have[g] = {k: get(k) for k in ("color", "light", "dark", "text", "border", "textStroke")}

for g, (m_, l_, d_) in want.items():
    h = have.get(g, {})
    dark = h.get("dark")
    ok = h.get("color") == m_ and h.get("light") == l_ and dark == d_
    print("[색] %-12s 메인 %s 밝은 %s 어두운/강조 %s %s" % (g, h.get("color"), h.get("light"), dark, "O" if ok else "X(문서 %s %s %s)" % (m_, l_, d_)))
    if not ok:
        fail.append("%s hex 불일치" % g)

uic = io.open(UIC, encoding="utf-8").read()
bgs = {}
for key in ("panel", "slot"):
    mm = re.search(r"\n\t" + key + r" = Color3\.fromRGB\((\d+), (\d+), (\d+)\)", uic)
    bgs[key] = tuple(int(x) for x in mm.groups())
for g, h in have.items():
    t = h.get("text") or h.get("color")
    c = min(contrast(t, bgs["panel"]), contrast(t, bgs["slot"]))
    ok = c >= 4.5
    print("[대비] %-12s 글자 %s · 패널/칸 최소 %.2f:1 %s" % (g, t, c, "O" if ok else "X"))
    if not ok:
        fail.append("%s 글자 대비 %.2f" % (g, c))
if not (have.get("primordial", {}).get("textStroke")):
    fail.append("태초 자홍 외곽선(textStroke) 없음")

OLD = {(230, 230, 230): "옛 일반", (77, 166, 255): "옛 희귀", (166, 77, 255): "옛 영웅", (255, 153, 51): "옛 전설", (255, 215, 0): "옛 유물(금)", (224, 57, 62): "옛 고대(빨강)", (255, 60, 200): "옛 태초 자홍", (214, 176, 62): "옛 초월 금"}
UI_DIRS = ("client" + os.sep + "panels", "client" + os.sep + "hud", "client" + os.sep + "ui")
left = []
for dp, _, fs in os.walk(SRC):
    for f in fs:
        if not f.endswith(".lua"):
            continue
        p = os.path.join(dp, f)
        rel = os.path.relpath(p, SRC)
        for i, line in enumerate(io.open(p, encoding="utf-8", errors="replace"), 1):
            if "옛" in line:
                continue
            for rgb, name in OLD.items():
                if "fromRGB(%d, %d, %d)" % rgb in line or "C(%d, %d, %d)" % rgb in line or "{ %d, %d, %d }" % rgb in line:
                    left.append((rel, i, name))
ui_left = [x for x in left if x[0].startswith(UI_DIRS)]
print("[옛 색 남음] 전체 %d곳(3D · 허브 장식 · 연출 = ALL9E 대상) · UI 폴더 %d곳" % (len(left), len(ui_left)))
for rel, i, name in left:
    print("   %s:%d %s" % (rel, i, name))
if ui_left:
    fail.append("UI 폴더에 옛 등급 색 %d곳" % len(ui_left))

print("결과: " + ("통과" if not fail else "실패 - " + " · ".join(fail)))
sys.exit(0 if not fail else 1)

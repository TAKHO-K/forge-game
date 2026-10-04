# QUEUE-ALL9C 2-2 등급 색 검사: ① ART-REF v2 2절 표(docs/design/gear-art-v3.md) hex = ItemVisualData 값(메인 · 밝은 · 어두운)
#   ② 글자색(text)이 어두운 패널 · 칸 위 대비 4.5:1 이상 ④ 메인 메뉴 글자 대비(QUEUE-N1004 A-2) ③ 옛 등급 색(웹 v1 · G1-1 자홍 · 옛 초월 금)이 src에 남았는지(3D · 허브 장식은 ALL9E - 목록만)
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

# ④ QUEUE-N1004 A-2 메인 메뉴 글자 대비(4.5:1 이상): MainMenu.client.lua에서 글자색 · 바탕색 토큰을 읽어 계산한다(코드를 바꾸면 검사도 따라간다).
#   바탕이 반투명이면 가장 나쁜 경우(뒤 배경 그림 = 흰색)에 얹은 실효색으로 잰다. 배경 그림 위에 바로 놓인 글자(로고 · 대기 글 · 설정 안내 줄)는 캡처 측정 항목(목록만).
MENU = os.path.join(SRC, "client", "MainMenu.client.lua")
menu = io.open(MENU, encoding="utf-8").read()
colors = {}
for mm in re.finditer(r"\n\t(\w+) = Color3\.fromRGB\((\d+), (\d+), (\d+)\)", uic):
    colors[mm.group(1)] = tuple(int(x) for x in mm.groups()[1:])
slot_alpha = 1 - float(re.search(r"slotTransparency = ([\d.]+)", uic).group(1))


def over(fg, alpha, back):
    return tuple(fg[i] * alpha + back[i] * (1 - alpha) for i in range(3))


WHITE = (255, 255, 255)
card_bg = re.search(r'continueCard\.BackgroundColor3 = Theme\.color\("(\w+)"\)', menu).group(1)
panel_tr = float(re.search(r'local function panelBox.*?BackgroundTransparency = ([\d.]+)', menu, re.S).group(1))
load_tr = float(re.search(r'loadingBack\.BackgroundTransparency = ([\d.]+)', menu).group(1))
panel_bg = over(colors["panel"], 1 - panel_tr, WHITE)
bg_of = {
    "continueCard": (colors[card_bg], "이어하기 카드(%s)" % card_bg),
    "row": (panel_bg, "설정 줄(panel α%.2f · 뒤 흰색)" % (1 - panel_tr)),
    "newsBox": (panel_bg, "소식 상자(panel α%.2f · 뒤 흰색)" % (1 - panel_tr)),
    "loading": (over(colors["panel"], 1 - load_tr, WHITE), "로딩 받침(panel α%.2f · 뒤 흰색)" % (1 - load_tr)),
}
pairs = [(mm.group(1), mm.group(2)) for mm in re.finditer(r'Theme\.label\((\w+), [^\n]*?"(\w+)"\)', menu)]
# 메뉴 버튼(Button secondary = slot α · 뒤 흰색) · 설정 작은 버튼(slot 불투명 · panelBox 위) - 글자 textPrimary
if 'kind = "secondary"' in menu:
    bg_of["menuButton"] = (over(colors["slot"], slot_alpha, WHITE), "메뉴 버튼(slot α%.2f · 뒤 흰색)" % slot_alpha)
    pairs.append(("menuButton", "textPrimary"))
mm = re.search(r'b\.BackgroundColor3 = Theme\.color\("(\w+)"\)\n\tb\.TextColor3 = Theme\.color\("(\w+)"\)', menu)
if mm:
    bg_of["smallButton"] = (colors[mm.group(1)], "설정 작은 버튼(%s)" % mm.group(1))
    pairs.append(("smallButton", mm.group(2)))
measured = []
for parent, fg in pairs:
    if parent not in bg_of:
        measured.append("%s(%s)" % (parent, fg))
        continue
    bg, what = bg_of[parent]
    c = contrast(colors[fg], bg)
    ok = c >= 4.5
    print("[메뉴 대비] %-40s 글자 %-13s %.2f:1 %s" % (what, fg, c, "O" if ok else "X"))
    if not ok:
        fail.append("메뉴 %s 글자 %s 대비 %.2f" % (what, fg, c))
print("[메뉴 대비] 배경 그림 위 글자(캡처 측정 항목): " + " · ".join(sorted(set(measured))))

# ⑤ QUEUE-ALL10 0-6(결정 6) 버튼 글자 대비(4.5:1 이상)
#   (가) 버튼 부품 ui/kit/Button.lua look()의 종류 × 상태 전부(fill · text 토큰을 코드에서 읽는다 - 반투명 slot은 뒤 흰색 최악 실효색)
#   (나) 부품 밖 직접 만든 글자 객체: 밝은 채움(ember · success)을 BackgroundColor3로 쓰는 줄 ±12줄 안 같은 객체의 TextColor3 토큰으로 잰다(글자 없는 막대 · 밑줄은 TextColor3가 없어 건너뜀)
BTN = os.path.join(SRC, "client", "ui", "kit", "Button.lua")
btn = io.open(BTN, encoding="utf-8").read()
btn_rows = 0
for mm in re.finditer(r"fill = colors\.(\w+), fillTransparency = ([\w.]+), text = colors\.(\w+)", btn):
    fill, tr, fg = mm.group(1), mm.group(2), mm.group(3)
    alpha = slot_alpha if tr.endswith("slotTransparency") else 1 - float(tr)
    bg = over(colors[fill], alpha, WHITE) if alpha < 1 else colors[fill]
    c = contrast(colors[fg], bg)
    btn_rows += 1
    ok = c >= 4.5
    print("[버튼 대비] 부품 %-10s 위 %-13s %.2f:1 %s" % (fill, fg, c, "O" if ok else "X"))
    if not ok:
        fail.append("버튼 부품 %s/%s 대비 %.2f" % (fill, fg, c))
if btn_rows < 6:
    fail.append("버튼 부품 look() 줄 못 읽음(%d)" % btn_rows)
BRIGHT = ("ember", "success")
direct = 0
for dp, _, fs in os.walk(os.path.join(SRC, "client")):
    for f in fs:
        if not f.endswith(".lua") or f == "Button.lua":
            continue
        p = os.path.join(dp, f)
        lines = io.open(p, encoding="utf-8", errors="replace").read().split("\n")
        for i, line in enumerate(lines):
            mm = re.match(r"\s*([\w.]+)\.BackgroundColor3 = .*?(?:UIColors|Theme\.colors|colors)\.(ember|success)\b|\s*([\w.]+)\.BackgroundColor3 = .*?Theme\.color\(\"(ember|success)\"\)", line)
            if not mm:
                continue
            obj = mm.group(1) or mm.group(3)
            fill = mm.group(2) or mm.group(4)
            fg = None
            for j in range(max(0, i - 12), min(len(lines), i + 13)):
                tm = re.match(r"\s*" + re.escape(obj) + r"\.TextColor3 = (.*)", lines[j])
                if tm:
                    expr = tm.group(1)
                    t2 = re.search(r"(?:UIColors|Theme\.colors|colors)\.(\w+)|Theme\.color\(\"(\w+)\"\)", expr)
                    if "Color3.new(0, 0, 0)" in expr:
                        fg = (0, 0, 0)
                    elif "Color3.new(1, 1, 1)" in expr:
                        fg = WHITE
                    elif t2:
                        name = t2.group(1) or t2.group(2)
                        # 조건식(on and A or B)이면 채움이 켜진 쪽 = 첫 토큰
                        fg = colors.get(name)
                    break
            if fg is None:
                continue
            direct += 1
            c = contrast(fg, colors[fill])
            rel = os.path.relpath(p, SRC)
            ok = c >= 4.5
            print("[버튼 대비] %s:%d %s 위 글자 %.2f:1 %s" % (rel, i + 1, fill, c, "O" if ok else "X"))
            if not ok:
                fail.append("%s:%d %s 위 글자 대비 %.2f" % (rel, i + 1, fill, c))
print("[버튼 대비] 부품 %d줄 · 직접 만든 글자 객체 %d곳" % (btn_rows, direct))

print("결과: " + ("통과" if not fail else "실패 - " + " · ".join(fail)))
sys.exit(0 if not fail else 1)

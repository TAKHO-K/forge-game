# QUEUE-UI2 UI2-4 HUD v5 소스 검사(Studio 없이): 환생 진입 경로가 하나도 안 없어짐 · 메뉴 항목 창 = PanelRegistry에 있음 · 키 칩 = 게임 키(“키” 글자 없음) · 옛 메뉴 = 스위치로만 끔
# 실행: python hud_v5_static.py → [HUDSRC] … O/X · 끝 n/m
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
SRC = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "src"))


def read(rel):
    with open(os.path.join(SRC, rel), encoding="utf-8") as f:
        return f.read()


passed = total = 0


def check(label, ok, detail=""):
    global passed, total
    total += 1
    passed += 1 if ok else 0
    print("[HUDSRC] %s %s %s" % (label, detail, "O" if ok else "X"))


hud = read("shared/data/HudData.lua")
reg = read("client/ui/PanelRegistry.lua")
menu = read("client/hud/HudMenuV2.client.lua")
old = read("client/hud/MenuBar.client.lua")

# 1. 메뉴 창 항목 = PanelRegistry id
panels = re.findall(r'panel = "(\w+)"', hud)
reg_ids = set(re.findall(r'\{ id = "(\w+)"', reg))
missing = [p for p in panels if p not in reg_ids]
check("메뉴 창 항목 = PanelRegistry에 있는 창", not missing and len(panels) >= 10, ",".join(missing) + " n=%d" % len(panels))

# 2. 환생 진입 경로(메뉴에서 빠져도 남아 있어야 함): 마을 제단 프롬프트 · 제단 클라 · 서버 요청 · 강화 창 [환생] 탭
rebirth_paths = {
    "제단 프롬프트(server/HuntingGround RebirthAltarPrompt)": ("server/HuntingGround.server.lua", "RebirthAltarPrompt"),
    "제단 클라(client/RebirthAltar → RebirthRequest)": ("client/RebirthAltar.client.lua", "RebirthRequest"),
    "서버 환생 처리(server/RebirthAccess)": ("server/RebirthAccess.lua", "function"),
    "강화 창 [환생] 탭(RebirthView)": ("client/panels/Enhance/init.lua", "RebirthView"),
}
for label, (rel, needle) in rebirth_paths.items():
    ok = os.path.exists(os.path.join(SRC, rel)) and needle in read(rel)
    check("환생 경로: " + label, ok)
check("환생은 HUD 메뉴 항목이 아님(제단 = 창 아님 - 02 v5 메뉴 규칙)", "rebirth" not in hud.split("items = {")[1].split("pc = {")[0])

# 3. 키 칩 = PanelRegistry 키(코드에 "키" 글자 칩 없음)
check("키 칩 = PanelRegistry.hotkeyOf · actionKey", "PanelRegistry.hotkeyOf" in menu and 'actionKey("hubReturn")' in menu)
check('키 칩에 고정 글자 "키" 없음', '"키"' not in menu)

# 4. 옛 메뉴 = 스위치로만 끔(파일 그대로)
check("옛 왼쪽 메뉴(hud/MenuBar) = HudData.menuV5 스위치로만 끔", "HudData).menuV5" in old and "return" in old.split("menuV5")[1][:80])

# 5. 빨강(warning) = 알림 점만(HUD 메뉴 안 warning 쓰는 곳 = AlertDot)
uses = [m.start() for m in re.finditer(r'"warning"', menu)]
near = [menu[max(0, u - 200):u] for u in uses]
check("HUD 메뉴 빨강 = 알림 점만", all("Dot" in n or "dot" in n for n in near) and len(uses) >= 1, "n=%d" % len(uses))

print("[HUDSRC] 끝 %d/%d" % (passed, total))

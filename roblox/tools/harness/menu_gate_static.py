# 메인 메뉴 버그(10-05) 소스 검사: 메뉴 건너뛰기가 테스트 플래그(MenuGate) 하나뿐인가 · 접속 자동 스폰을 껐는가.
# 실행: python menu_gate_static.py → [MENUSRC] … O/X · 끝 n/m
import io, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src")

def read(rel):
    return io.open(os.path.join(SRC, rel), encoding="utf-8").read()

def code(text):  # 주석 줄 · 줄 끝 주석 빼기(설명 글에 옛 이름이 나와도 괜찮다)
    return "\n".join(re.sub(r"--.*$", "", line) for line in text.splitlines())

menu = code(read("client/MainMenu.client.lua"))
slot = code(read("server/SlotServer.server.lua"))
switch = code(read("server/SlotSwitch.lua"))
ok_n = total = 0

def check(label, ok):
    global ok_n, total
    total += 1
    ok_n += ok
    print("[MENUSRC] %s %s" % (label, "O" if ok else "X"))

reads = [l for l in menu.splitlines() if "\"SkipMainMenu\"" in l]
check("메뉴가 옛 저장값 SkipMainMenu를 읽지 않음(옵션 스위치 skipMenuOption 끔 = 숨은 토글 값에서도 무시 · 옛 계정 켬이어도 메뉴 표시)", all("Data.skipMenuOption == true and" in l for l in reads))
check("메뉴가 검증 무장(VerifyArmedUntil)만으로 건너뛰지 않음", "VerifyArmedUntil" not in menu)
check("옛 DevSkipMainMenu(남아 있으면 계속 건너뜀) 안 읽음", "DevSkipMainMenu" not in menu)
check("건너뛰기 = MenuGate.shouldSkip 한 곳 · enter(\"continue\", true) 호출 1곳", menu.count("MenuGate.shouldSkip") == 1 and menu.count("enter(\"continue\", true)") == 1)
check("서버: 접속 자동 스폰 끔(CharacterAutoLoads = false) · 접속 = holdAtJoin", "CharacterAutoLoads = false" in slot and "SlotSwitch.holdAtJoin(player)" in slot)
check("서버: 쓰러짐 뒤 부활을 직접(메뉴에 있으면 안 함)", "humanoid.Died" in slot and "InMainMenu" in slot and "LoadCharacter" in slot)
check("입장 원격 enterWorld가 스위치 검사 앞(칸 저장 끔이어도 입장 가능)", slot.index("\"enterWorld\"") < slot.index("SlotSaveData.enabled"))
check("메뉴 입장(enter)이 enterWorld를 부름", "InvokeServer(\"enterWorld\")" in menu)
check("자동 이어하기 없음: 칸 play는 클라 onPlay(카드 두 번)에서만", menu.count("InvokeServer(\"play\"") == 1)
win = code(read("client/ui/SlotWindow.lua"))
check("이어하기 창: 시작 = 같은 카드 두 번(armed) · 미리 선택(selected)만으로 시작 안 함", "if self.armed == slot then" in win and "if self.selected == slot then" not in win)
print("[MENUSRC] 끝 %d/%d" % (ok_n, total))

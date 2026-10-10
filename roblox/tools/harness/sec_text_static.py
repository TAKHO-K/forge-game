# SEC-FIX-1 10: 압박 문구 · 기간 한정 판매 정적 검사. 실행: python sec_text_static.py (옛 = ECON_SRC=<옛 src> → X) · 끝 줄 "[SECTEXT] 끝 n/m"
#   ① 화면 문구(TextData*.lua 값 - ko · en)에 기간 한정 판매 · 남은 기간 압박 표현 0 ② 할로윈 = 기간 한정 아님(seasonMonth 없음) · 출시 때 숨김(공개 단계 2)
import io, os, re, sys, glob

H = os.path.dirname(os.path.abspath(__file__))
SRC = os.environ.get("ECON_SRC", os.path.join(H, "..", "..", "src"))
passed = total = 0


def check(label, ok, detail=""):
    global passed, total
    total += 1
    passed += 1 if ok else 0
    print("[SECTEXT] %s %s %s" % (label, detail, "O" if ok else "X"))


def read(p):
    return io.open(p, encoding="utf-8", errors="ignore").read() if os.path.exists(p) else ""


PRESSURE = re.compile(r"한정 판매|월 한정|\d+월 한정|October only|On sale in month|지금만|놓치|마지막 기회|Last chance|Don't miss|Only now")
VAL = re.compile(r'\]\s*=\s*"([^"]*)"')
hits = []
for p in sorted(glob.glob(os.path.join(SRC, "shared", "data", "TextData*.lua"))):
    for i, line in enumerate(read(p).split("\n"), 1):
        for v in VAL.findall(line):
            if PRESSURE.search(v):
                hits.append("%s:%d" % (os.path.basename(p), i))
check("화면 문구(ko · en)에 기간 한정 판매 · 압박 표현 0", not hits, " · ".join(hits[:6]))
cos = read(os.path.join(SRC, "shared", "data", "CosmeticSlotData.lua"))
m = re.search(r'\{ id = "halloween"[^\n]*', cos)
check("할로윈 = 기간 한정 아님(seasonMonth 없음 - 주석 앞 코드만)", m is not None and "seasonMonth" not in m.group(0).split("--")[0])
mon = read(os.path.join(SRC, "shared", "data", "MonetizationData.lua"))
rel = re.search(r"release = \{(.*?)\n\t\}", mon, re.S)
check("할로윈 = 출시 때 숨김(공개 단계 2)", rel is not None and re.search(r"theme_halloween = 2\b", rel.group(1)) is not None and re.search(r"theme_halloween = 1\b", rel.group(1)) is None)
print("[SECTEXT] 끝 %d/%d" % (passed, total))
sys.exit(0 if passed == total else 1)

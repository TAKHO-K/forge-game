# SEC-FIX-1 4: 클라에 복제되는 폴더(src/shared = ReplicatedStorage · src/client · src/first)에 비밀이 없는가(정적 검사).
#   실행: python sec_secret_static.py  (옛 코드 확인 = ECON_SRC=<옛 src> python sec_secret_static.py → X가 나와야 재현) · 끝 줄 "[SECRET] 끝 n/m"
#   비밀 = 교환 코드 문자열(공지 전 hidden · inactive 포함 전부 - 코드 표는 server/SocialCodeData 한 곳) · 서버 전용 설정 모듈 이름.
#   코드 값 자체는 출력하지 않는다(개수 · 파일만).
import io, os, re, sys

H = os.path.dirname(os.path.abspath(__file__))
SRC = os.environ.get("ECON_SRC", os.path.join(H, "..", "..", "src"))
REPLICATED = ["shared", "client", "first"]
passed = total = 0


def check(label, ok, detail=""):
    global passed, total
    total += 1
    passed += 1 if ok else 0
    print("[SECRET] %s %s %s" % (label, detail, "O" if ok else "X"))


def files(sub):
    for root, _, names in os.walk(os.path.join(SRC, sub)):
        for n in names:
            if n.endswith(".lua"):
                yield os.path.join(root, n)


def read(p):
    return io.open(p, encoding="utf-8", errors="ignore").read()


# 코드 목록 = 서버 표 + (옛 자리) shared 표 - 둘 다 모아 복제 폴더에서 찾는다
code_re = re.compile(r'\bcode\s*=\s*"([A-Z0-9]{3,24})"')
codes = set()
for p in [os.path.join(SRC, "server", "SocialCodeData.lua"), os.path.join(SRC, "shared", "data", "SocialRewardData.lua")]:
    if os.path.exists(p):
        codes |= set(code_re.findall(read(p)))
check("코드 표 읽힘(서버 표 또는 옛 자리)", len(codes) >= 1, "코드 %d개" % len(codes))
check("코드 표 = 서버 전용 모듈(server/SocialCodeData)", os.path.exists(os.path.join(SRC, "server", "SocialCodeData.lua")))

leaks = {}
table_in_replicated = []
for sub in REPLICATED:
    for p in files(sub):
        s = read(p)
        rel = os.path.relpath(p, SRC).replace("\\", "/")
        for c in codes:
            if re.search(r'(?<![A-Z0-9])' + c + r'(?![A-Z0-9])', s):
                leaks.setdefault(rel, 0)
                leaks[rel] += 1
        if code_re.search(s):
            table_in_replicated.append(rel)
check("복제 폴더(shared · client · first)에 코드 문자열 0", not leaks, " · ".join("%s(%d)" % kv for kv in sorted(leaks.items())))
check("복제 폴더에 코드 표 모양(code = \"…\") 0", not table_in_replicated, " · ".join(table_in_replicated))
client_uses = [os.path.relpath(p, SRC) for sub in ("client", "first") for p in files(sub) if re.search(r"\bSD\.codes\b|SocialRewardData\.codes\b", read(p))]
check("클라가 코드 표를 직접 읽지 않음(게시판 = 서버 BoardCodes)", not client_uses, " · ".join(client_uses))
# 서버 전용 설정 모듈(OpsConfig · SocialCodeData)이 shared에 사본으로 생기지 않았나
dup = [n for n in ("OpsConfig.lua", "SocialCodeData.lua", "SecurityOpsConfig.lua", "NestPickupData.lua") for sub in REPLICATED for p in files(sub) if os.path.basename(p) == n]
check("서버 전용 설정 모듈 사본이 복제 폴더에 없음", not dup, " · ".join(dup))
# 4b: 탐지 기준값(SecurityOpsConfig) · 운영 계정 UserId · 둥지 줍기 기준 = 서버 전용
check("4b 탐지 기준값 모듈 = 서버(server/SecurityOpsConfig)", os.path.exists(os.path.join(SRC, "server", "SecurityOpsConfig.lua")) and not os.path.exists(os.path.join(SRC, "shared", "data", "SecurityOpsConfig.lua")))
ops = read(os.path.join(SRC, "server", "OpsConfig.lua")) if os.path.exists(os.path.join(SRC, "server", "OpsConfig.lua")) else ""
op_ids = set(re.findall(r"\b(\d{6,12})\b", ops))
id_leaks = sorted({os.path.relpath(p, SRC).replace("\\", "/") for sub in REPLICATED for p in files(sub) for i in op_ids if re.search(r"(?<!\d)" + i + r"(?!\d)", read(p))})
check("4b 운영 계정 UserId가 복제 폴더에 없음", bool(op_ids) and not id_leaks, "계정 %d개 · %s" % (len(op_ids), " · ".join(id_leaks)))
nest = read(os.path.join(SRC, "shared", "data", "NestData.lua"))
check("4b 둥지 줍기 검증 기준(maxSpeedStuds) = 서버(server/NestPickupData)", "maxSpeedStuds" not in nest and os.path.exists(os.path.join(SRC, "server", "NestPickupData.lua")))
print("[SECRET] 끝 %d/%d" % (passed, total))
sys.exit(0 if passed == total else 1)

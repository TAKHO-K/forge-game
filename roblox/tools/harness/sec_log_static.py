# SEC-FIX-1 9(AUDIT1 #12): 로그 단계 스위치 정적 검사. 실행: python sec_log_static.py (옛 코드 = ECON_SRC=<옛 src> → X) · 끝 줄 "[SECLOG] 끝 n/m"
#   ① 로거(shared/Log) · 단계 표(shared/data/LogConfig) 있음 · 라이브 = WARN · Studio = DEBUG(검증 로그 그대로)
#   ② 라이브 서버 파일(검증 · 시뮬 · 개발 도구 제외)에서 print를 쓰는 파일은 전부 첫 print보다 앞에 `local print = …Shared.Log).info` 가림 줄
import io, os, re, sys

H = os.path.dirname(os.path.abspath(__file__))
SRC = os.environ.get("ECON_SRC", os.path.join(H, "..", "..", "src"))
SKIP = re.compile(r"Verify|^DevTools|EconSim|C1Sim|PerfProbe|MeshImportDev|MapGenSample|A1Prototypes|TerrainBakeRun|Sim|Probe|Dump|Bake")
PRINT = re.compile(r"(?<![\w.:])print\(")
SHADOW = re.compile(r"^local print = require\(game:GetService\(\"ReplicatedStorage\"\)\.Shared\.Log\)\.info", re.M)
passed = total = 0


def check(label, ok, detail=""):
    global passed, total
    total += 1
    passed += 1 if ok else 0
    print("[SECLOG] %s %s %s" % (label, detail, "O" if ok else "X"))


def read(p):
    return io.open(p, encoding="utf-8", errors="ignore").read() if os.path.exists(p) else ""


log, cfg = read(os.path.join(SRC, "shared", "Log.lua")), read(os.path.join(SRC, "shared", "data", "LogConfig.lua"))
check("로거 shared/Log · 단계 표 shared/data/LogConfig 있음", bool(log) and bool(cfg))
check("라이브 = WARN · Studio = DEBUG", re.search(r'liveLevel\s*=\s*"WARN"', cfg) is not None and re.search(r'studioLevel\s*=\s*"DEBUG"', cfg) is not None)
check("로거 단계 = DEBUG < INFO < WARN < OFF · info = INFO 이상일 때만 print", "DEBUG = 1, INFO = 2, WARN = 3, OFF = 4" in log and re.search(r"function Log\.info\(\.\.\.\)\s*if current <= LEVELS\.INFO then", log) is not None)

srv = os.path.join(SRC, "server")
files, missing, lines = 0, [], 0
for n in sorted(os.listdir(srv)):
    if not n.endswith(".lua") or SKIP.search(n):
        continue
    s = read(os.path.join(srv, n))
    m = PRINT.search(s)
    if not m:
        continue
    files += 1
    lines += len(PRINT.findall(s))
    sh = SHADOW.search(s)
    if not sh or sh.start() > m.start():
        missing.append(n)
check("라이브 서버 파일 print 전부 INFO로 가림(첫 print보다 앞)", files > 0 and not missing, "파일 %d · print %d줄 · 빠짐 %d %s" % (files, lines, len(missing), " ".join(missing[:8])))
print("[SECLOG] 끝 %d/%d" % (passed, total))
sys.exit(0 if passed == total else 1)

"""QUEUE-ALL6R 4: 회귀 끝 Studio 로그(출력 창) 오류 · 경고를 종류별로 묶어 센다.
자동 검증이 O로 통과해도 조용히 나는 에러(QUEUE-ALL6 I: HurtEdge nil 곱하기 · 감사 기록 UTF-8 거절)를 잡기 위한 것.

사용:
  python roblox/tools/studio_log_errors.py                 # 가장 최근 Studio 로그 · 마지막 Play(마지막 "자동 검증 모드" 줄 또는 "플레이어 입장" 줄)부터
  python roblox/tools/studio_log_errors.py --from-line 30763
  python roblox/tools/studio_log_errors.py --all           # 로그 전체
출력: 개수 · 수준(Error/Warning) · 출처(게임 = 우리 스크립트 · 엔진 = Studio/로블록스) · 대표 문장(숫자는 #로 묶음)
"""
import argparse, collections, glob, io, os, re, sys

LEVELS = ("Error", "Warning")
GAME_HINTS = ("ServerScriptService", "PlayerScripts", "ReplicatedStorage", "StarterPlayer", "Workspace.", "[forge-game]", "[DevTools]", "[Text]", "[SaveSystem]")
START_MARKERS = ("[DevTools] 자동 검증 모드", "[forge-game] 플레이어 입장")


def newest_log():
    base = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "logs")
    files = glob.glob(os.path.join(base, "*Studio*_last.log"))
    return max(files, key=os.path.getmtime) if files else None


def normalize(text):
    text = re.sub(r"Players\.[^.\s]+\.", "Players.<나>.", text)
    text = re.sub(r"\d+(\.\d+)?", "#", text)
    return text.strip()[:220]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log")
    ap.add_argument("--from-line", type=int)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--engine", action="store_true", help="엔진 경고도 종류별로(기본 = 합계 한 줄)")
    a = ap.parse_args()
    path = a.log or newest_log()
    if not path:
        print("Studio 로그 없음")
        return 1
    lines = io.open(path, encoding="utf-8", errors="replace").read().splitlines()
    start = 0
    if a.from_line is not None:
        start = a.from_line
    elif not a.all:
        for i in range(len(lines) - 1, -1, -1):
            if any(m in lines[i] for m in START_MARKERS):
                start = i
                break
    groups = collections.Counter()
    sample = {}
    for line in lines[start:]:
        parts = line.split(",", 4)
        if len(parts) < 5:
            continue
        body = parts[4]
        level = body.split(" ", 1)[0]
        if level not in LEVELS:
            continue
        msg = body.split("] ", 1)[1] if "] " in body else body
        if msg.startswith("Stack ") or msg.startswith("Script '"):
            continue
        origin = "게임" if any(h in msg for h in GAME_HINTS) and not msg.startswith("Drain:") else "엔진"
        key = (level, origin, normalize(msg))
        groups[key] += 1
        sample.setdefault(key, msg.strip()[:220])
    print(f"로그 {os.path.basename(path)} · {start + 1}번째 줄부터 {len(lines) - start}줄 · 종류 {len(groups)} · 합 {sum(groups.values())}")
    print("| 개수 | 수준 | 출처 | 문장(대표) |")
    print("|---|---|---|---|")
    hidden = 0
    for (level, origin, _), count in sorted(groups.items(), key=lambda kv: (kv[0][1] != "게임", kv[0][0] != "Error", -kv[1])):
        if origin == "엔진" and level == "Warning" and not a.engine:
            hidden += count
            continue
        text = sample[(level, origin, _)].replace("|", "/")
        print(f"| {count} | {level} | {origin} | {text} |")
    if hidden:
        print(f"| {hidden} | Warning | 엔진 | (Studio · 플러그인 경고 합계 - --engine으로 종류별) |")
    return 0


if __name__ == "__main__":
    sys.exit(main())

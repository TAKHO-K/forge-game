import re, os, sys
# QUEUE-B1: 저장소 기준 상대 경로(옛 = 원래 폴더 절대 경로 - worktree의 새 모듈을 못 찾았다)
SRC = os.environ.get("DEPS_SRC", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "server"))
seen = set()
stack = sys.argv[1].split(",")
while stack:
    n = stack.pop()
    if n in seen:
        continue
    p = os.path.join(SRC, n + ".lua")
    if not os.path.exists(p):
        continue
    seen.add(n)
    src = open(p, encoding="utf-8", errors="ignore").read()
    for m in re.findall(r"require\(script\.Parent\.(\w+)\)", src):
        stack.append(m)
print(",".join(sorted(seen)))

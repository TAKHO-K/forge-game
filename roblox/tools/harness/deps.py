import re, os, sys
SRC = r"C:\Users\xkrgh\vibe\game\roblox\src\server"
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

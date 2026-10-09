"""BOSS-NIGHT-2 D: require 경로 검사(정적 · Studio 없이).

luau 하네스(build_run.py)는 모듈을 이름으로 묶어서 `require(ReplicatedStorage.Shared.BossRigSpec)`처럼 경로가 틀린 require도
통과한다(실제 = Shared.data.BossRigSpec). Studio에선 그 모듈을 쓰는 서버 모듈이 줄줄이 로드 실패한다(BOSS-NIGHT-2 3 BossOrigin).
→ roblox/src의 모든 require를 Rojo 매핑(default.project.json)대로 실제 파일로 풀어 본다.

푸는 것: ReplicatedStorage.Shared.… · RS.Shared.… · Shared.… · game:GetService("ReplicatedStorage").Shared.… · script(.Parent)*.…
  (:WaitForChild("X") · :FindFirstChild("X")는 .X로 본다). 변수로 시작하는 경로(client.panels.X 등)는 건너뛴다(개수만 출력).
판정: 끝 이름 = ModuleScript(<이름>.lua 또는 <이름>/init.lua)여야 O. 폴더 · .server/.client 스크립트 · 없는 이름 = X.
사용: python require_path_test.py  → "[REQ] 끝 n/m" (X 줄 = 파일:줄 · 원문 · 이유)
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "..", "..", "src"))
ROOTS = {"Shared": os.path.join(SRC, "shared")}  # ReplicatedStorage.Shared = src/shared

REQ = re.compile(r"require\(\s*([^()]*(?:\([^()]*\)[^()]*)*)\)")
CALL = re.compile(r':(?:WaitForChild|FindFirstChild)\(\s*"([^"]+)"[^)]*\)')


def kind(dirpath, name):
    """dirpath 안의 이름 name이 무엇인지: module · script · folder · None."""
    base = os.path.join(dirpath, name)
    if os.path.isfile(base + ".lua") or os.path.isfile(base + ".luau"):
        return "module"
    if os.path.isdir(base):
        for init in ("init.lua", "init.luau"):
            if os.path.isfile(os.path.join(base, init)):
                return "module"
        if os.path.isfile(os.path.join(base, "init.server.lua")) or os.path.isfile(os.path.join(base, "init.client.lua")):
            return "script"
        return "folder"
    if os.path.isfile(base + ".server.lua") or os.path.isfile(base + ".client.lua"):
        return "script"
    return None


def script_dir(path):
    """이 파일의 'script' 인스턴스가 자식을 가지는 폴더(init = 그 폴더) · 그 부모 폴더."""
    d, f = os.path.split(path)
    if f.split(".")[0] == "init":
        return d, os.path.dirname(d)
    return None, d  # 보통 파일 = 자식 없음


def resolve(expr, path):
    e = CALL.sub(lambda m: "." + m.group(1), expr.replace(" ", ""))
    e = re.sub(r'^game:GetService\("ReplicatedStorage"\)', "ReplicatedStorage", e)
    parts = e.split(".")
    if parts[0] in ("ReplicatedStorage", "RS") and len(parts) > 1 and parts[1] == "Shared":
        cur, rest = ROOTS["Shared"], parts[2:]
    elif parts[0] == "Shared":
        cur, rest = ROOTS["Shared"], parts[1:]
    elif parts[0] == "script":
        own, parent = script_dir(path)
        i = 1
        cur = own
        if i < len(parts) and parts[i] == "Parent":
            cur = parent
            i += 1
            while i < len(parts) and parts[i] == "Parent":
                cur = os.path.dirname(cur)
                i += 1
        rest = parts[i:]
        if cur is None:
            return "X", "script 자식(파일 모듈은 자식이 없음)"
        if not os.path.normpath(cur).startswith(SRC):
            return None, "src 밖"
    else:
        return None, "변수 경로"
    if not rest or not all(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", p) for p in rest):
        return None, "동적 이름"
    for p in rest[:-1]:
        k = kind(cur, p)
        if k not in ("folder", "module"):
            return "X", "중간 이름 없음: %s" % p
        cur = os.path.join(cur, p)
    k = kind(cur, rest[-1])
    if k == "module":
        return "O", ""
    return "X", "끝 이름 = %s" % (k or "없음")


def main():
    ok = total = skipped = 0
    bad = []
    for dp, _, files in os.walk(SRC):
        for f in files:
            if not f.endswith((".lua", ".luau")):
                continue
            p = os.path.join(dp, f)
            with open(p, encoding="utf-8") as fh:
                for n, line in enumerate(fh, 1):
                    code = line.split("--", 1)[0]
                    for m in REQ.finditer(code):
                        st, why = resolve(m.group(1), p)
                        if st is None:
                            skipped += 1
                            continue
                        total += 1
                        if st == "O":
                            ok += 1
                        else:
                            bad.append("%s:%d require(%s) - %s" % (os.path.relpath(p, SRC).replace("\\", "/"), n, m.group(1).strip(), why))
    for b in bad:
        print("[REQ] X " + b)
    print("[REQ] 끝 %d/%d · 건너뜀(변수 · 동적) %d" % (ok, total, skipped))
    return 0 if ok == total else 1


if __name__ == "__main__":
    sys.exit(main())

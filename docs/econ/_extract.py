# Studio 로그에서 경제 시뮬(/gg econ · 자동 검증 P0(가)) 결과를 docs/econ/로 옮긴다.
# 쓰는 법: python docs/econ/_extract.py [로그 파일] [--stem 이름]  (로그 생략하면 %LOCALAPPDATA%\Roblox\logs의 가장 최근 *Studio* 로그)
#   --stem을 주면 파일 이름 앞부분을 E1-<what-if> 대신 그 이름으로 쓴다(P2: P2-before · P2-after). 로컬 하네스 출력 파일도 로그처럼 읽는다.
# 로그의 [ECON] BEGIN ~ [ECON] END 구간 중 run 이름(what-if-프로필)마다 가장 마지막 것을 골라
#   E1-<what-if>.md(프로필이 all이 아니면 E1-<what-if>-<프로필>.md) + E1-<what-if>[-<프로필>]-<표>.csv 로 쓴다.
# Studio 서버는 저장소 파일을 직접 못 쓰므로 이 스크립트가 옮기는 역할만 한다(계산은 전부 Studio의 EconSim).
import glob
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def latest_log():
    base = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "logs")
    files = glob.glob(os.path.join(base, "*Studio*.log"))
    if not files:
        sys.exit("Studio 로그 파일을 못 찾았다: " + base)
    return max(files, key=os.path.getmtime)


def payload(line, marker):
    index = line.find(marker)
    if index < 0:
        return None
    text = line[index + len(marker):]
    return text[1:] if text.startswith(" ") else text


def main():
    args = sys.argv[1:]
    stem_override = None
    if "--stem" in args:
        at = args.index("--stem")
        stem_override = args[at + 1]
        del args[at:at + 2]
    path = args[0] if args else latest_log()
    lines = io.open(path, encoding="utf-8", errors="replace").read().splitlines()
    runs = {}
    current = None
    for line in lines:
        begin = payload(line, "[ECON] BEGIN")
        if begin is not None:
            match = re.search(r"run=(\S+) whatif=(\S+) profiles=(\S+)", begin)
            current = {"run": match.group(1), "whatif": match.group(2), "profiles": match.group(3), "md": [], "csv": {}}
            continue
        if current is None:
            continue
        if payload(line, "[ECON] END") is not None:
            runs[current["run"]] = current
            current = None
            continue
        md = payload(line, "[ECONMD]")
        if md is not None:
            current["md"].append(md.rstrip())
            continue
        match = re.search(r"\[ECONCSV:(\w+)\] ?(.*)$", line)
        if match:
            current["csv"].setdefault(match.group(1), []).append(match.group(2).rstrip())
    if not runs:
        sys.exit("로그에 완료된 [ECON] 실행이 없다: " + path)
    for run in runs.values():
        stem = stem_override or ("E1-" + run["whatif"] + ("" if run["profiles"] == "all" else "-" + run["profiles"]))
        with io.open(os.path.join(HERE, stem + ".md"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(run["md"]).rstrip() + "\n")
        for name, rows in run["csv"].items():
            with io.open(os.path.join(HERE, stem + "-" + name + ".csv"), "w", encoding="utf-8-sig", newline="\n") as f:
                f.write("\n".join(rows) + "\n")
        print("%s: md %d줄 · csv %s" % (stem, len(run["md"]), ", ".join("%s(%d)" % (k, len(v)) for k, v in run["csv"].items())))


if __name__ == "__main__":
    main()

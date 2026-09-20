# 세션 파일(S*.md) 끝의 공통 규칙 블록을 COMMON.md의 내용으로 갱신한다.
# 쓰는 법: python docs/sonnet/_build.py
import glob
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
BEGIN = "<!-- COMMON:BEGIN - 이 아래는 COMMON.md의 사본이다. 직접 고치지 말고 _build.py를 돌린다 -->"
END = "<!-- COMMON:END -->"

with open(os.path.join(HERE, "COMMON.md"), encoding="utf-8") as f:
    common = f.read().strip()
# 세션 파일 안에서는 제목을 한 단계 내린다(# → ##)
common = re.sub(r"^(#+) ", lambda m: "#" + m.group(1) + " ", common, flags=re.M)
# COMMON.md 첫머리의 안내 인용문은 사본에 넣지 않는다
common = re.sub(r"^> 이 블록은.*\n\n?", "", common, flags=re.M)

count = 0
for path in sorted(glob.glob(os.path.join(HERE, "S[0-9][0-9]*-*.md"))):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if BEGIN in text:
        body = text.split(BEGIN)[0]
    elif "<!-- COMMON -->" in text:
        body = text.split("<!-- COMMON -->")[0]
    else:
        body = text.rstrip() + "\n\n"
    out = body.rstrip() + "\n\n---\n\n" + BEGIN + "\n\n" + common + "\n\n" + END + "\n"
    # 구분선이 빌드할 때마다 쌓이지 않게
    out = re.sub(r"(\n---\n)+\n" + re.escape(BEGIN), "\n---\n\n" + BEGIN, out)
    if out == text:
        continue
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(out)
    count += 1
print(f"{count}개 세션 파일 갱신")

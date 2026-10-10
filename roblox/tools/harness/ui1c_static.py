# UI-1c 정적 검사(코드 글 읽기): 매머드 이름 = 데이터 한 곳 · 보스 바 기여 알약 = 서버 Attribute 읽기만.
#   실행: python ui1c_static.py  (끝 줄 = "[UI1C] 끝 n/m") · 검사 수를 바꾸면 run_all.sh EXP[ui1c_static]도 같이.
import os
import re

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'src')
passed, total = 0, 0


def read(rel):
    with open(os.path.join(SRC, rel), encoding='utf-8') as f:
        return f.read()


def check(label, ok, detail=''):
    global passed, total
    total += 1
    if ok:
        passed += 1
    print('[UI1C] %s %s %s' % (label, detail, 'O' if ok else 'X'))


def code_part(line):
    # 줄에서 주석(-- 문자열 밖)을 뗀 코드 부분
    q = None
    i = 0
    while i < len(line):
        c = line[i]
        if q:
            if c == '\\':
                i += 2
                continue
            if c == q:
                q = None
        elif c in '"\'':
            q = c
        elif line.startswith('--', i):
            return line[:i]
        i += 1
    return line


def lua_files():
    for root, _, files in os.walk(SRC):
        for fn in files:
            if fn.endswith('.lua'):
                p = os.path.join(root, fn)
                yield os.path.relpath(p, SRC).replace('\\', '/'), open(p, encoding='utf-8').read()


# 2단계: 매머드 이름(사용자 확정 10-10) = BossData displayName 한 곳 · 옛 이름 문자열 0(주석 · 번역 표 옛 키 제외)
boss = read('shared/data/BossData.lua')
check('BossData frost_giant 이름 = "빙하 매머드"', re.search(r'id = "frost_giant", displayName = "빙하 매머드"', boss) is not None)
check('영어 이름 = Glacier Mammoth', '["빙하 매머드"] = "Glacier Mammoth"' in read('shared/data/TextData_names.lua'))
old = []
for rel, text in lua_files():
    if rel.endswith('TextData_names.lua'):
        continue
    for n, line in enumerate(text.splitlines(), 1):
        c = code_part(line)
        if '서리 거인' in c or '빙하 엄니' in c or '서리 매머드' in c:
            old.append('%s:%d' % (rel, n))
check('옛 이름(서리 거인 · 빙하 엄니 · 서리 매머드) 코드 문자열 0', not old, ','.join(old[:5]))
# 2단계: 기여 알약 = 서버 MonsterState가 Attribute를 걸고 화면은 읽기만(판 번호 대조)
ms = read('server/MonsterState.lua')
check('서버: BossContributionPct + 판 번호 BossContributionEnc', 'SetAttribute("BossContributionPct"' in ms and 'SetAttribute("BossContributionEnc"' in ms)
bb = read('client/hud/BossBar.client.lua')
check('보스 바: 판 번호가 내 BossEncounterId와 같을 때만 알약', re.search(r'GetAttribute\("BossContributionEnc"\) == player:GetAttribute\("BossEncounterId"\)', bb) is not None)
check('보스 바: BREAK 게이지 안 그림(데이터 없음)', 'BreakGauge' not in bb)
print('[UI1C] 끝 %d/%d' % (passed, total))

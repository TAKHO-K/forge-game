# UI-1 정적 검사(코드 글 읽기): 전투력 = 한 함수(서버 PlayerProfile.getCombatPower → Attribute CombatPower) · HUD · 캐릭터 · 보스 관문 · 가방 전투력이 같은 값을 읽는가.
#   실행: python ui1_static.py  (끝 줄 = "[UI1S] 끝 n/m")
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
    print('[UI1S] %s %s %s' % (label, detail, 'O' if ok else 'X'))


sync = read('server/CombatPowerSync.server.lua')
check('서버: Attribute CombatPower = PlayerProfile.getCombatPower', 'PlayerProfile.getCombatPower' in sync and 'SetAttribute("CombatPower"' in sync)
check('HUD 칩 = Attribute CombatPower', 'GetAttribute("CombatPower")' in read('client/CombatPowerHud.client.lua'))
check('캐릭터 창 전투력 줄 = Attribute CombatPower', re.search(r'\{\s*"character\.power",\s*"CombatPower",\s*"power"', read('client/panels/Character.lua')) is not None)
check('표시 = CombatFormula.display 한 곳(HUD · 캐릭터 · 관문 - 같은 숫자)', all('CombatFormula.display' in read(f) or 'CF.display' in read(f) for f in ['client/CombatPowerHud.client.lua', 'client/panels/Character.lua', 'client/panels/BossGateWindow.lua']))
check('보스 관문 창 내 전투력 = Attribute CombatPower', 'GetAttribute("CombatPower")' in read('client/panels/BossGateWindow.lua'))
item = read('server/ItemPowerServer.server.lua') + read('server/PlayerProfile.lua')
check('가방 장비 전투력(4단계) = 같은 함수로 잼(combatPowerWith → getCombatPower)', re.search(r'function PlayerProfile\.combatPowerWith[\s\S]{0,800}getCombatPower', item) is not None)
dup = []
for root, _, files in os.walk(os.path.join(SRC, 'client')):
    for fn in files:
        if fn.endswith('.lua'):
            t = open(os.path.join(root, fn), encoding='utf-8').read()
            if 'offensePowerOf' in t:
                dup.append(fn)
check('클라가 전투력을 따로 계산하지 않음(offensePowerOf 0곳)', not dup, ','.join(dup))
print('[UI1S] 끝 %d/%d' % (passed, total))

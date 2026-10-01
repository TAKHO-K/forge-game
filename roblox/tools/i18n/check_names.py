# QUEUE-ALL6 A4: 데이터 이름 사전(shared/data/TextData_names.lua) 검사.
#   실행: python roblox/tools/i18n/check_names.py
#   실패(종료 코드 1) = 사전에 겹친 원문 · 화면에 나오는 데이터 이름(아래 FIELDS)이 사전에 없음 · 영어 이름 40자 넘침({자리} 제외).
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.normpath(os.path.join(HERE, '..', '..', 'src', 'shared', 'data'))

# 파일 → 화면에 이름으로 나오는 필드(원문이 한글일 때만 본다). '*' = 그 파일의 모든 한글 문자열.
FIELDS = {
    'QuestData': {'name'}, 'ArmorData': {'displayName'}, 'MonsterData': {'displayName'}, 'MonsterSpeciesData': {'displayName'},
    'EggData': '*', 'PetData': '*', 'TitleData': {'name'}, 'SkillData': {'name'}, 'UltimateData': {'name'}, 'TrainingData': {'name'},
    'OptionData': {'displayName'}, 'EnhanceMaterialData': {'displayName'}, 'ClassData': {'displayName', 'weaponName'}, 'MilestoneData': {'name'},
    'CosmeticSlotData': {'name'}, 'SkillVariantData': {'name'}, 'MonsterPrefixData': {'displayName'}, 'NestData': {'name'},
    'BossData': {'displayName', 'title', 'line', 'sub', 'damageLabel', 'label', '?', 'partyShareLabel'},
    'WorldMapData': {'displayName', 'name', 'label', 'explore', 'line'}, 'CodexData': '*', 'MonsterCodexData': {'label', 'hint', 'where'},
    'CommunityGoalData': '*', 'WeeklyChallengeData': '*', 'RiftData': '*', 'TranscendentData': {'phantom', 'frenzy', 'soar', 'full', 'banner', 'off'},
    'GemData': '*', 'PrimordialData': {'fallbackName'}, 'MonetizationData': '*',
}
HAN = re.compile(r'[가-힣]')
STR = re.compile(r'"((?:[^"\\]|\\.)*)"')
DICT = re.compile(r'\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"')


def load_dict():
    seen, dup = {}, []
    for no, line in enumerate(io.open(os.path.join(DATA, 'TextData_names.lua'), encoding='utf-8'), 1):
        code = line.split('--', 1)[0] if not line.lstrip().startswith('["') else line
        for k, v in DICT.findall(code):
            if k in seen:
                dup.append('%d: %s (먼저 %d)' % (no, k, seen[k][1]))
            seen[k] = (v, no)
    return seen, dup


def main():
    d, dup = load_dict()
    missing, long = [], []
    for f, fields in FIELDS.items():
        p = os.path.join(DATA, f + '.lua')
        for no, line in enumerate(io.open(p, encoding='utf-8'), 1):
            code = line.split('--', 1)[0]
            for m in STR.finditer(code):
                s = m.group(1)
                if not HAN.search(s):
                    continue
                pre = code[:m.start()]
                fm = re.search(r'([A-Za-z_][A-Za-z0-9_]*)\s*=\s*[\{]?\s*$', pre)
                field = fm.group(1) if fm else '?'
                if fields != '*' and field not in fields:
                    continue
                if f == 'SetData' or s.startswith(' '):
                    continue
                if s not in d:
                    missing.append('%s:%d %s=%s' % (f, no, field, s))
    for k, (v, no) in d.items():
        plain = re.sub(r'\{[A-Za-z0-9_]+\}|%[0-9.]*[dsf%]', '', v)
        if len(plain) > 40 and len(k) <= 20:  # 이름(짧은 원문)만 - 힌트 · 기믹 설명 문장은 칸이 여러 줄
            long.append('%d: %s (%d자)' % (no, v, len(plain)))
    print('사전 원문 %d개 · 겹침 %d · 빠진 이름 %d · 40자 넘침 %d' % (len(d), len(dup), len(missing), len(long)))
    for x in dup + missing + long:
        print('  ' + x)
    ok = not dup and not missing
    print('결과: ' + ('통과' if ok else '실패'))
    sys.exit(0 if ok else 1)


main()

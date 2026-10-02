# QUEUE-ALL4 E: TextData ko/en 키 짝 검사.
#   실행: python roblox/tools/i18n/check_textdata.py   (저장소 어디서든 - 이 파일 위치 기준으로 roblox/src를 찾는다)
#   실패(종료 코드 1) = ko에 있는데 en 없는 키 · en에만 있는 키 · 같은 언어에 겹친 키 · {자리} 이름이 ko와 다른 en ·
#                      Text.get/getFor/format에 글자 그대로 쓴 키가 TextData에 없음 · 키 앞부분("a.b." .. x)에 맞는 키가 하나도 없음.
#   QUEUE-ALL8 A3 실패 = 화면에 나가는 글(TextData ko · en 값 · TextData_names 원문 · 번역 · 데이터 표의 label · displayName · name)에 개발용 문구(DEV_BANNED).
#   참고(실패 아님) = en 40자 넘는 문장 수 · 키를 변수로 넘기는 호출 수(검사 못 함).
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, '..', '..', 'src'))
DATA = os.path.join(SRC, 'shared', 'data')

ENTRY = re.compile(r'\["([^"]+)"\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*,')
KEYLINE = re.compile(r'\["([^"]+)"\]\s*=')
SECTION = re.compile(r'^\t(ko|en) = \{')
PLACE = re.compile(r'\{([A-Za-z0-9_]+)\}')
# QUEUE-ALL8 A3: 개발용 문구(출시 차단) - 아직 안 여는 기능 = "곧 열려요" / "Coming soon" 하나로
DEV_BANNED = re.compile(r'\(준비|준비\)|준비 중|된다\)|가방에서도 된다|TODO|임시|테스트|모의|\(dev|placeholder|\(soon\)|also in your bag|\(mock|\(test|\(wip|\(펫 단계', re.I)
DATA_LABEL = re.compile(r'\b(?:label|displayName|name)\s*=\s*"((?:[^"\\]|\\.)*)"')
DATA_LABEL_FILES = ('WorldMapData.lua', 'WorldConfig.lua', 'HubArtData.lua', 'HubServiceData.lua', 'PetData.lua', 'ShopData.lua', 'MonetizationData.lua', 'SeasonPassData.lua')


def dev_text(tables):
    rows = []
    for lang in ('ko', 'en'):
        for k, (v, where) in tables[lang].items():
            if DEV_BANNED.search(v):
                rows.append('%s %s: %s (%s)' % (lang, k, v, where))
    names = os.path.join(DATA, 'TextData_names.lua')
    for no, line in enumerate(io.open(names, encoding='utf-8'), 1):
        code = line.split('--')[0] if line.lstrip().startswith('--') else line
        for a, b in ENTRY.findall(code):
            for t in (a, b):
                if DEV_BANNED.search(t):
                    rows.append('names: %s (TextData_names.lua:%d)' % (t, no))
    for name in DATA_LABEL_FILES:
        path = os.path.join(DATA, name)
        if not os.path.exists(path):
            continue
        for no, line in enumerate(io.open(path, encoding='utf-8'), 1):
            code = re.sub(r'--.*$', '', line)
            for t in DATA_LABEL.findall(code):
                if DEV_BANNED.search(t):
                    rows.append('data: %s (%s:%d)' % (t, name, no))
    return rows


def load_tables():
    tables = {'ko': {}, 'en': {}}
    errors = []
    for name in sorted(os.listdir(DATA)):
        if not (name.startswith('TextData') and name.endswith('.lua')):
            continue
        if name == 'TextData_names.lua':  # QUEUE-ALL6 A4 데이터 이름 사전(원문 키 - check_names.py가 따로 본다)
            continue
        path = os.path.join(DATA, name)
        if name == 'TextData.lua':
            lang = 'ko'
        elif name == 'TextData_en.lua':
            lang = 'en'
        else:
            lang = None  # 분할 파일 = ko · en 절
        for no, line in enumerate(io.open(path, encoding='utf-8'), 1):
            if name not in ('TextData.lua', 'TextData_en.lua'):
                m = SECTION.match(line)
                if m:
                    lang = m.group(1)
                    continue
            code = line.split('--')[0] if line.lstrip().startswith('--') else line
            found = KEYLINE.findall(code)
            if not found:
                continue
            entries = ENTRY.findall(code)
            if len(entries) != len(found):
                errors.append('%s:%d 읽을 수 없는 줄("키" = "문장", 꼴이어야 함)' % (name, no))
                continue
            if lang is None:
                errors.append('%s:%d ko/en 절 밖의 키' % (name, no))
                continue
            for key, value in entries:
                if key in tables[lang]:
                    errors.append('%s:%d 겹친 키(%s): %s (먼저 = %s)' % (name, no, lang, key, tables[lang][key][1]))
                tables[lang][key] = (value, '%s:%d' % (name, no))
    return tables, errors


def first_args(text, start):
    # text[start]은 '(' 바로 뒤. 위쪽 단계의 인자들을 문자열로 돌려준다(괄호 · 문자열 안 쉼표 무시).
    depth, i, args, cur = 0, start, [], start
    quote = None
    while i < len(text):
        c = text[i]
        if quote:
            if c == '\\':
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in '"\'':
            quote = c
        elif c in '({[':
            depth += 1
        elif c in ')}]':
            if depth == 0:
                args.append(text[cur:i])
                return args
            depth -= 1
        elif c == ',' and depth == 0:
            args.append(text[cur:i])
            cur = i + 1
        i += 1
    args.append(text[cur:])
    return args


CALL = re.compile(r'\bText\.(get|getFor|format)\(')


def top_literals(arg):
    # 인자 식의 맨 위 단계 문자열만: (값, 뒤에 .. 이 붙나). 앞에 .. 이 붙은 것(뒷조각)과 안쪽 괄호(GetAttribute("x") 등)는 뺀다.
    out, depth, i = [], 0, 0
    while i < len(arg):
        c = arg[i]
        if c in '"\'':
            j = i + 1
            while j < len(arg) and arg[j] != c:
                j += 2 if arg[j] == '\\' else 1
            if depth == 0 and not arg[:i].rstrip().endswith(('..', '==', '~=')):
                out.append((arg[i + 1:j], arg[j + 1:].lstrip().startswith('..')))
            i = j + 1
            continue
        if c in '({[':
            depth += 1
        elif c in ')}]':
            depth -= 1
        i += 1
    return out


def scan_calls(keys):
    missing, prefix_missing, dynamic, used = [], [], 0, set()
    for dp, _, fs in os.walk(SRC):
        for f in fs:
            if not f.endswith('.lua'):
                continue
            path = os.path.join(dp, f)
            rel = os.path.relpath(path, SRC).replace(os.sep, '/')
            text = io.open(path, encoding='utf-8').read()
            for m in CALL.finditer(text):
                line_no = text.count('\n', 0, m.start()) + 1
                line = text[text.rfind('\n', 0, m.start()) + 1:m.start()]
                if line.lstrip().startswith('--'):
                    continue
                args = first_args(text, m.end())
                index = 0 if m.group(1) == 'get' else 1
                if index >= len(args):
                    continue
                arg = args[index]
                lits = top_literals(arg)
                if not lits:
                    dynamic += 1
                    continue
                for value, concat in lits:
                    if concat:
                        if not any(k.startswith(value) for k in keys):
                            prefix_missing.append('%s:%d 앞부분 "%s"에 맞는 키 없음' % (rel, line_no, value))
                        else:
                            used.update(k for k in keys if k.startswith(value))
                    elif value in keys:
                        used.add(value)
                    elif value == '':
                        continue
                    else:
                        missing.append('%s:%d 없는 키 "%s"' % (rel, line_no, value))
    return missing, prefix_missing, dynamic, used


def main():
    tables, errors = load_tables()
    ko, en = tables['ko'], tables['en']
    no_en = sorted(k for k in ko if k not in en)
    no_ko = sorted(k for k in en if k not in ko)
    place = []
    for k in ko:
        if k in en and set(PLACE.findall(ko[k][0])) != set(PLACE.findall(en[k][0])):
            place.append('%s: ko %s / en %s (%s)' % (k, sorted(set(PLACE.findall(ko[k][0]))), sorted(set(PLACE.findall(en[k][0]))), en[k][1]))
    long_en = [k for k in en if len(PLACE.sub('', en[k][0])) > 40]
    missing, prefix_missing, dynamic, used = scan_calls(set(ko))

    def show(title, rows):
        print('%s: %d' % (title, len(rows)))
        for r in rows[:40]:
            print('  ' + r)
        if len(rows) > 40:
            print('  ... 외 %d' % (len(rows) - 40))

    print('ko 키 %d · en 키 %d' % (len(ko), len(en)))
    show('읽기 오류 · 겹친 키', errors)
    show('ko에 있는데 en 없는 키', no_en)
    show('en에만 있는 키', no_ko)
    show('{자리} 이름이 다른 키', place)
    show('Text.get에 쓰였는데 TextData에 없는 키', missing)
    show('키 앞부분에 맞는 키 없음', prefix_missing)
    dev = dev_text(tables)
    show('개발용 문구(ALL8 A3)', dev)
    print('참고: en 40자 넘는 문장(자리 제외) %d · 키를 변수로 넘기는 호출 %d(검사 못 함) · 코드에서 글자 그대로 찾은 키 %d' % (len(long_en), dynamic, len(used)))
    failed = errors or no_en or no_ko or place or missing or prefix_missing or dev
    print('결과: %s' % ('실패' if failed else '통과'))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())

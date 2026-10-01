# 용어집(고정 번역 · 한/영) - QUEUE-10h Q15

> 번역 표(Creator Hub)에 먼저 고정으로 넣을 게임 고유 용어. 코드 · 데이터 · 문서 · UI가 같은 한국어 단어를 쓴다(이름 규칙 §7-6).

| 한국어 | 영어(고정) | 뜻 · 쓰는 곳 |
|---|---|---|
| 환생 | Rebirth | 레벨 조건을 채우면 레벨 1로 돌아가고 무기 등급 · 보석 칸이 오른다 |
| 태초 | Primordial | 장비 등급(초월 아래 최상위) · 세계 번호가 붙는다 · 같은 서버 알림 |
| 초월 | Transcendent | 최상위 장비 등급 · 전 서버 알림 · 명예의 전당 · 부위 고정 특수 옵션 |
| 고대 · 유물 · 전설 · 영웅 · 희귀 · 일반 | Ancient · Relic · Legendary · Epic · Rare · Common | 장비 등급(아래로) |
| 토벌 | Raid | 이미 깬 보스를 다시 잡는 반복전(잔류 없음 · 전투 시간 공정성) |
| 영혼 | Spirit | 보스전 사망 뒤 관전 상태(반투명 · 공격 불가) |
| 성역 | Sanctuary | 치유사 궁극기(끝날 때 부활) |
| 구원의 기도 | Prayer of Salvation | 치유사 R(영혼 부활) |
| 강화 · 강화석 · 방지권 | Enhance · Enhance Stone · Protection Ticket | 무기 강화 |
| 보석 · 재련 · 보석 가루 | Gem · Refine · Gem Dust | 무기 보석 칸 |
| 계승 | Inherit | 장비 옵션 · 레벨 넘기기 |
| 품질 | Quality | 장비 · 보석 옵션 수치가 그 등급의 무작위 폭(최소 ~ 최대)에서 어디쯤인가(0 ~ 100%). 옛 표기 "굴림" · "굴림 위치"(A2-N4에서 통일 - 확률표의 "서버 굴림" = 추첨 자체는 그대로) |
| 스킬 변형 | Skill Variant | 장비에 붙는 ±5% 맞교환 옵션(넓게 Wide · 재빠르게 Swift · 묵직하게 Heavy · 멀리 Far) |
| 수련 · 직업 능력 | Training · Class Ability | 골드로 올리는 계정 · 직업 성장 |
| 둥지 · 알 · 부화 · 펫 | Nest · Egg · Hatch · Pet | 알 등급 보통 Normal · 좋은 Good · 희귀 Rare |
| 반짝이 몬스터 · 반짝 조각 | Sparkle Monster · Sparkle Shard | 드문 변종 · 재화 |
| 구간 수호자 · 수정 여왕 · 심해 군주 · 전갈 여왕 · 폭풍 군주 · 서리 거인 | Section Guardian · Crystal Queen · Abyssal Lord · Scorpion Queen · Storm Lord · Frost Giant | 보스 이름 |
| 푸른 드래곤 | Blue Dragon | T6 잡몹 |
| 검사 · 도적 · 궁수 · 치유사 · (준비 중) 성기사 | Swordsman · Rogue · Archer · Healer · Paladin | 직업(역할형 - 사용자 확정 10-01). 키 `class.name.<id>`(greatsword · dualblade · bow · healer · paladin). 무기는 대검 Greatsword · 쌍검 Dual Blades · 활 Bow · 뿅망치 Squeaky Hammer |
| 누구나 · 딜러 · 치유사(파티 게시판 역할) | Anyone · DPS · Healer | `party.board.role1` ~ `3` |
| 궁극기 | Ultimate | T 칸 |
| 견습 | Apprentice | 튜토리얼 모드 |
| 이정표 | Guide | 첫 5분 안내(Q12) |
| 7일 출석 | 7-Day Check-in | 새 계정 출석 |
| 환생 무료권 | Free Rebirth Ticket | 출석 2일차(쓰임 결정 대기) |

## QUEUE-ALL5 F에서 정한 용어(QUEUE-ALL4 미정분)

| 한국어 | 영어(고정) | 뜻 · 쓰는 곳 · 결정 이유 |
|---|---|---|
| 분해 · 일괄 분해 · 자동 분해 | Salvage · Salvage All · Auto salvage | 장비 · 보석을 가루 · 보석으로 바꾸기. 옛 en에 "Dismantle"(보석 가공)과 "Salvage"(가방)가 섞여 있었다 → Salvage로 통일(짧고 게임에서 흔한 말 - "Dismantle All"은 버튼 칸 0.92로 빠듯했다) |
| 변환권 · 변환 · 리롤 | Reroll Ticket · Reroll · Reroll | 고대 · 태초 옵션 다시 굴리기. ko의 "변환"과 "리롤"은 같은 동작이라 en은 Reroll 하나("Convert" 안 씀). 등급 붙은 줄은 "{grade} Reroll Ticket", 좁은 칸은 "{grade} Ticket" 허용 |
| 불씨 | Ember | 강화 실패 게이지(가득 차면 다음 강화 확정 성공). 용어라 문장 중간에서도 대문자 Ember. "gauge" 표기 금지 |
| 홈(보석 홈 · 보석 칸) | Socket | 무기 보석 자리. "Gem slot" 표기 금지(가방 "Slots"와 겹친다). 칸 이름 = "Socket {slot}" |
| 기믹 · 보스 기믹 | Mechanic · Boss Mechanics | 보스 전멸 패턴과 해법. "Gimmick"(영어에서 깎아내리는 말) · "wipe move"(어려운 말) 안 씀 |
| 펫 결과 등급 일반 · 고급 · 희귀 · 영웅 | Common · Uncommon · Rare · Epic | 부화 결과 등급(`EggData.hatchGradeNames` 키 uncommon과 같다) |
| 알 등급 보통 · 좋은 · 희귀 | Normal · Good · Rare | 알 자체 등급. 펫 "고급"을 Uncommon으로 바꿔 "Good" 겹침을 없앴다 |
| 강화대 | Forge | 강화하는 곳("Enhance station" · 소문자 "forge" 섞임 → Forge) |
| 하락 방지권 · 초기화 방지권(좁은 칸 줄임) | Drop Guard · Reset Guard | 보상 띠(`hud.band.*`)처럼 한 줄 칸 전용 줄임. 상점 · 보상 목록 · 설명은 정식 이름 Drop/Reset Protection Ticket 유지 |
| 받음(보상 받은 표시) | Claimed | 버튼 · 상태 글은 Claimed. 보상 띠(`hud.band.*Claimed`)는 칸이 좁아 "✓"만 쓴다. 성장 보상 `ui.milestone.got*`은 횟수 표기라 Got 유지 |
| 도전(보상 띠 버튼) | Fight | 88px 버튼에서 "Challenge"가 폰 글씨로 넘쳐 Fight(견습 `scene.tutorial.challenge` "Fight Boss"와 같은 말). 주간 도전 탭 · 기록은 Challenge 그대로 |
| 길 안내 · 위치 안내 · 여기로 안내 | Guide · Show Way · Show Way | 버튼은 "Show Way", 길 안내 토글은 "Guide" |
| 자동 이동(지도 걷기) | Auto Walk | 지도 자동 걷기. 스테이지 자동 이동(`autoStage.*`)은 다른 기능이라 "Auto move" 그대로 |
| 치명 확률 · 치명 피해 | Crit / Crit Rate · Crit DMG | "Dmg" · "%p" 표기 금지(en은 %p 대신 %) |

> 확정(QUEUE-STUDIO 0-1 · 사용자 10-01): 직업 영어 이름 = Swordsman · Rogue · Archer · Healer(다음 직업 Paladin과 같은 역할형). 화면은 `Text.get("class.name." .. classId)`로 읽는다(ko 값 = `ClassData.displayName`과 같게 유지 - 서버 로그 · 개발 도구는 displayName 그대로). 보스 · 구역 · 등급 · 수련 이름은 여전히 데이터의 한국어 `displayName`이라 영어를 켜도 한국어로 나온다(남은 일).

## QUEUE-ALL6 A4 - 데이터 이름 고정 번역(전체 표 = `roblox/src/shared/data/TextData_names.lua`)

> 데이터 파일은 한국어 원문 그대로 두고 화면에서 `Text.name(원문)`으로 바꾼다(사전 = 원문 → 영어 · 458개 · 검사 `python roblox/tools/i18n/check_names.py`). 아래는 자주 보이는 고정 용어만.

| 한국어 | 영어(고정) | 비고 |
|---|---|---|
| 석조 평원 · 수정 동굴 · 수몰 사원 · 모래 유적 · 폭풍 첨탑 · 빙하 동굴 | Stone Plains · Crystal Cave · Sunken Temple · Sand Ruins · Storm Spire · Glacier Cave | 구역(세트 = "… Set" · 알 = "… Egg" · 입구 = "… Gate" · 사냥터 = "… Hunt") |
| 큰 나무 마을 · 대장간 거리 · 시장 · 커뮤니티 광장 · 포탈 광장 | Big Tree Village · Forge Street · Market · Community Plaza · Portal Plaza | 허브 |
| 갑옷 · 장갑 · 신발 · 무기 | Armor · Gloves · Shoes · Weapon | 장비 칸 |
| 위력 · 신속 · 치명 · 건강 · 방어 · 성장 · 재생 · 흡혈 | Might · Haste · Crit · Vitality · Guard · Growth · Regen · Lifesteal | 옵션 · 세트 축 |
| 관통돌진 · 회전베기 · 강궁 · 백스텝샷 · 그림자분신 · 난무 · 치유 · 딜링모드 | Piercing Dash · Spin Slash · Power Shot · Backstep Shot · Shadow Clone · Blade Flurry · Heal · Battle Mode | 스킬 |
| 파괴의 화신 · 천궁의 폭우 · 죽음의 계약 · 생명의 성역 | Avatar of Ruin · Sky Arrow Storm · Death Pact · Sanctuary of Life | 궁극기 |
| 초월자 · 태초의 선택 · 주간 챔피언 · 모두의 영웅 | Transcender · Primordial Chosen · Weekly Champion · Everyone's Hero | 칭호(도감 줄 칭호 틀 "%s 수집가" = "%s Collector" 등) |
| 하락 방지권 · 초기화 방지권 | Drop Protection Ticket · Reset Protection Ticket | 좁은 칸 줄임 = Drop/Reset Guard(위 표) |
| 별빛 · 불씨 · 서리꽃 · 말랑 젤리 | Starlight · Ember · Frost Bloom · Squishy Jelly | 꾸미기 테마 |

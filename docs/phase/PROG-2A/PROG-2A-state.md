# PROG-2A 상태(10-11 · 중단 지점 - 사용 한도)

지시 = `claude-design-handoff/CC-PROG-2A-prompt.md` · 설계 + 시뮬만(게임 데이터 · 코드 변경 0).

## 끝난 것
- 1절 현황 조사(에이전트 3건) 핵심:
  - **골드로 개별 스킬 레벨을 올리는 시스템은 없음**(SaveSystem · PlayerProfile에 필드 없음) → "스킬 강화 제거" = 경제 영향 0 · 저장 이관 없음. 스킬 수치 경로는 보석 옵션 `skill_<직업>_<칸>` · 장비 스킬 변형뿐.
  - 환생: 최대 5 · 필요 레벨 25/50/75/100/125(CharacterLevelConfig.lua:138) · 환생권(F6) 지급 = 출석 2일(QuestData.lua:44) · 사용처 0.
  - 수련: 공격 0.1% · 체력 0.4% · 방어 0.2% × 50단계(스테이지 ÷ 20) · 가격 = tier1 골드 × 32 × 1.08^L × 1.001^(s−1). 고급 수련 51 ~ 100 = 단계당 공격 +1%(초월 무기 뒤 · All10Data advancedTraining).
  - 직업 능력(옛) = 직업마다 3종 × 25 ~ 50단계(공격 버킷 최대 1.875% + 진화 +30단계) - TrainingData.classAbilities.
  - 펫: 판매 없음 · 놓아주기 = 보상 0 · 합성 없음 · 이벤트 펫 없음 · 펫 상한 60 · 알 상한 40. 나무 정상 하루 1회 = 미구현(WorldMapData.lua:212 자리).
  - 골드 2^53 상한 · clamp 없음(changeGold = NaN/inf/음수만 막음).
  - BossSim 현재(BOSS-NIGHT-3): 처치 p50 58 ~ 100초 · 처음 전멸 29 ~ 50% · 아는 7 ~ 29%(하한 미달).
- EconSim 러너(`sim/p2run.py`) · 분석(`sim/p2an.py`) · 시나리오 라이브러리(`sim/p2lib.lua` - 메모리 안에서만 덮어씀) · 시나리오 11개(`sim/scen/`).
- 기준선 재현 = 문서 값과 같음: 상위 1% 25,300 = **2,154.5h**(하한 2,150 · 여유 0.2%) · 일반 4,256h · 캐주얼 6,871h · 2^53 도달 상위 1% 1,066h(s22,525) · 2^50 863h(s21,240).
- 분당 마리분 U(s): 캐주얼 30 ~ 80 · 일반 45 ~ 130 · 상위 90 ~ 300 → 일반 1마리분 ≈ 1초. 10만 골드 = 스테이지 1,000에서 일반 약 1.7h · 초월(약 8,500)에서 약 10초 → 직업 능력 가격은 GoldCost 연동(scaled) 추천 후보.

## 남은 것
1. 상위 1% 시나리오 11개 결과 읽기(스크래치패드 out/ - 세션이 바뀌면 다시 돌림: `LUAU=... OUT_DIR=... EXTRA_SERVER=$(python deps.py PlayerProfile,PartyState) python p2run.py top <시나리오> scen/<시나리오>.lua` → `python p2an.py <out> <시나리오> top`).
2. 일반 · 캐주얼 · P90로 핵심 시나리오(full · tAc) 재실행 · 고정점 보정 필요 여부.
3. BossSim 설계 사본(기믹 실패 = 보스 HP 5% 회복 · HP 배율 · 피해 배율 · 기믹 여유) - 원본 BossDifficultySim.lua를 python 치환으로 사본 생성(바꿀 줄: maxHp · damage dealt · 기믹 실패 damage · hitChance 기믹 · limit 400) → 6보스 × 처음/아는 × 근/원.
4. 펫 합성 확률 표(같은 종 3 · 9% / 1% · 실패안 2개 이상 · 알 시간당 2 / 6개 가정) · 신규 7일 표 · 나무 α · 장비 고정치 + % 표.
5. `docs/design/PROG-2-spec.md` 작성(1 ~ 5절 · 결정표) · 커밋 · push.

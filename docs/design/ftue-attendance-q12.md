# 첫 5분 이정표 + 7일 출석 (QUEUE-10h Q12 · 2026-09-29)

> 한 시스템(§7-6): 이정표 · 출석 = 퀘스트 상태(`profile.quests.guide` · `.attendance` - SAVE v53) · 규칙 `shared/Quest.lua` · 지급 `QuestService.grant` 한 곳 · 데이터 `QuestData.ftue` · `.attendance`.

## 1. 첫 5분 이정표(보상 없음 - 보상은 메인 퀘스트)
| # | 단계 | 이벤트(서버 입구) | 퍼널 |
|---|---|---|---|
| 1 | 공격해 쓰러뜨리기 | kill(CombatResolution) | ftue_fight |
| 2 | 첫 드랍 줍기 | pickup(ItemDropServer tryPickup) | ftue_drop |
| 3 | 장착 | equip(ItemEquip) | ftue_equip |
| 4 | 스킬 Q · E · R + 안내 카드 1장 | skill(SkillServer sendResult - 틱 제외) | ftue_skill |
| 5 | 첫 강화 | enhance(EnhanceService) | ftue_enhance |
| 6 | 첫 보석 | gem(GemEquip · GemCraftRequest) | ftue_gem |
| 7 | 궁극기 맛보기(이 단계에 들어서면 게이지 가득 1회) | ult(SkillServer T) | ftue_ult |
| 8 | 첫 보스(스테이지 5) | bossClear(CombatResolution) | ftue_boss |
- 화면: 단계가 바뀔 때 TC 토스트 1줄(스킬 단계는 카드 1줄 더) · 퀘스트 창 맨 위 "지금 할 일". 상시 HUD 띠 없음(ScreenMap 자리 규칙). 상점 노출 없음.
- 스테이지 30 전멸기 설명 = 서리 거인 첫 만남 카드(BR1-2) 이미 있음 - 확인만.
- 동선(사냥터 길 · 대장간 위치 안내)은 H1 배치 뒤 조정.
- 퍼널 = `QuestService.funnel` → Q15 `Telemetry.funnel`(없으면 로그 `[Q12][퍼널]`).

## 2. 7일 출석(새 계정만 - 옛 계정은 v53 이관에서 없음)
| 일차 | 보상 |
|---|---|
| 1 | 펫 알 1(퀘스트 알과 같은 경로 - 가방 가득이면 수령 거절) |
| 2 | 환생 무료권 1(`quests.currencies.rebirthTicket` - 자리) |
| 3 | 골드 200마리분 · 강화석 5 |
| 4 | 반짝 조각 2 |
| 5 | 골드 300마리분 · 강화석 10 |
| 6 | 펫 알 1 |
| 7 | 골드 500마리분 · 반짝 조각 5 |
- 센다 = 서버 UTC 날짜가 바뀐 뒤 첫 활동(Quest.roll) 한 칸 · 빠진 날은 다음 칸(누적) · 7칸에서 멈춤.
- 성장 곡선: 무료권은 쓰는 곳이 없어 영향 0 · 골드 합 1,000마리분(GoldCost "quest") = 일간 퀘스트 이틀치 미만 → EconSim 재측정 불필요(성장 예산 표 불변).

## 3. 결정 필요
1. **환생 무료권의 쓰임** - 지금 환생은 레벨 조건만 있고 비용이 없다. 안: (가) 환생 요구 레벨 −10% 1회 (나) 되찾기(reclaim) 가속 (다) P4c 유료 환생 상품과 짝(수익화 - 손대지 말 것 목록). 추천 = (가)(곡선 영향은 EconSim으로 재측정 필요).
2. 견습(튜토리얼) 중에는 퀘스트 받기가 거절된다(Q6 리뷰 4) → 1일차 알은 견습을 마친 뒤 받는다.
3. 메인 퀘스트 해금 문구 "E 스킬(환생 1) · R(환생 2) · T(환생 3)"는 실제 코드와 다르다(Q · E · R · T 모두 처음부터 열림 - 잠긴 칸 2개는 미래 자리) → 문구 정정 또는 실제 잠금 도입.

# 10시간 대기열 보고서 (QUEUE-10h · 2026-09-29)

> 지시서 = `QUEUE-10h-prompt.md`(Q0 ~ Q7) + `QUEUE-10h-extra-prompt.md`(Q8 ~ Q15) · 진행 상태 = `QUEUE-10h-state.md` · 시각 = 이 PC 시계(한국 시간).
> 검증 = `server/QueueVerify.lua`(블록 `Q0(가)` - 항목마다 절 추가 · 로컬 하네스 + Studio) · Play A ~ D 각 1회(재Play 없음).

## 1. 항목별 결과 (앞 대기열 Q0 ~ Q7 · 06:17 ~ 07:30)

| 항목 | 결과 | 커밋 | 실소요 |
|---|---|---|---|
| Q0 준비 · COMMON §7-6 | O | 14911d9 · d8ff32e | 약 2분 |
| Q0 결정 1 · 2 · 알림 감사 | O - 개수 = killUnits × 티어 보정 · 태초 2/3/3 · 첫 클리어 0.1% · 태초 명예의 전당 · 칭호 제거 | d699bb9 | 약 9분 |
| Q1 푸른 드래곤 | O - 종 · 리그 14 · 모양 공격 3종 · 포효 · 추적 상한 · 지점 88 · 아트 자료 | bbc2c4a | 약 11분 |
| Q2 일반 몹 드랍표 | O - 문서 · 판매가 0 버그 · 공정성 로그 | 2572e7b | 약 5분 |
| Q3 보스 드랍표 | O - 문서 · 수정 여왕 강화석 60% 수정 | ddac156 | 약 1분 |
| 리뷰 1 · 2 반영 + 판매가 스위치 | O - 큰 몸 도달 공용 · 넉백 공통 입구 등 | 1348f50 | 약 4분 |
| Q4 장비 점검 · Play A | O - 계승 잠금 · 초월 계승 금지 · 계승비 · 판매 불가 표시 | 698eaea | 약 10분 |
| Q5 BR2 · Play B | O - 세트(스위치 끔) · SAVE v49 · 토벌 입장 | 2dc3f61 · 8661cd9 | 약 8분 |
| 리뷰 3 반영(치명 1) + Q6 · Play C | O - 토벌 시간 공정성 · 수련 · 능력 · 퀘스트 · SAVE v50 · 골드 예산 | 99aba72 · b5f26d7 · e23d564 · 34cc8e5 | 약 20분 |
| Q7 U1(일부) · Play D · 리뷰 4 반영 | △ - 퀘스트 창 · CP · 알림 분리 · 툴팁 · 성기사 칸 · 폰 버튼 실측 · 순위 목업 3안(나머지 = 남은 일) | 00e5451 · 4d3c04f | 약 8분 |

재사용한 공통 입구(§7-6): 드랍 등록 · 알림(`CombatResolution.grantKillReward` · `PrimordialRegistry.onRolled` · `DropNoticeData.announceScope`) · 등급표(`DropTable`) · 넉백(`BossPatterns.launchPlayer` - 보스와 공용) · 도달 판정(`Reach.withinModel`) · 옵션 합산(`Option.sumAxisBonus` extra - 세트 · 수련) · 영구 버킷(마일스톤) · 가격(`GoldCost`) · 둥지 알(`PlayerProfile.addEgg`) · 창(`Panel.create` · `UIManager` · `PanelRegistry`).

## 2. 이름 규칙 확인표

| 대상 | 기존 규칙 | 이번에 정한 이름 |
|---|---|---|
| `docs/art/ref` 파일 | `NN_영문소문자_T범위.png`(00 ~ 07 구역 · 10 ~ 18 주제) | `19_monsters_T6_blue_dragon.md` + art-spec §0 · §3 줄 |
| 종 ID · 표시 이름 | snake_case · 한글 | `blue_dragon` · 푸른 드래곤 |
| 리그 파트 | 파스칼 + `_L/R` · 번호 마디 · 관절 Body = RootJoint · Head = Neck | Body · Neck1 · Head · Jaw · Eyes · Wing_L/R · Tail1~3 · Leg_FL/FR/BL/BR |
| 매핑표 | `monster-body-draft.md` 표 | "푸른 드래곤(T6) `blue_dragon`" · 눈토끼 줄 = retired |
| docs/design 문서 | kebab-case 영문 | `field-drop-tables.md` · `boss-drop-tables.md` · `equipment-audit.md` · `gold-budget-g3.md` |
| docs/phase | `<이름>-prompt/state/report.md` | `QUEUE-10h-*` |
| 데이터 모듈 | `<이름>Data.lua` · 순수 모듈 = 파스칼 | `SetData` · `SetBonus` · `TrainingData` · `Training` · `QuestData` · `Quest` · `MobAttackShape` |
| 세트 이름 | 구역 테마 이름(WorldMapData.zones[].theme) | "수호자의 석조 평원 세트" · 세대 = "잿빛 …" |

## 3. 알림 감사표(출처별 · Q0-6 + Play A 실측)

| 출처 | 태초 | 고대 | 초월 |
|---|---|---|---|
| 일반 몹 · 반짝이 · 세대 변이 스테이지 | 같은 서버 배너("[이 서버]") + 채팅 줄 + 30초 빛기둥 + 본인 연출 | 같은 서버 알림 + 본인 빛기둥 | 전 서버(MessagingService) + "[전 서버]" 흑금 배너 · 무지개 + 명예의 전당 + 칭호 "초월자" |
| 보스 첫 클리어 · 재도전 · 토벌 | 같음(출처 무관) | 같음 | 같음 |
| 상자 · 견습 · 상점 · 분해 | 장비 없음 / 알림 경로 밖 | - | - |
| 제거한 것 | 태초 명예의 전당 기록 · "태초의 선택" 새 지급(이미 가진 칭호 유지) | - | - |
| Play A 실측 | 태초 토픽 수신 0 · `범위=server` | - | 초월 토픽 수신 1 · `범위=global` |

## 4. 결정 필요(큰 것 먼저 · 추천)

1. **후반 골드 싱크 부족**: 후반 골드 1e20 ~ 1e22가 남아 사용처 비율 목표(강화 45 · 수련 25 …)는 구조적으로 불가. 추천 = 수련 최대 단계를 환생 · 마일스톤마다 늘리되 단계당 아주 작게 + 상점 · 부화 골드(`gold-budget-g3.md` §4).
2. **캐주얼 1,000 = 27.5 ~ 28.5h(목표 31 ~ 38.5)** - 이번 변경 전부터(M2 등급표). 수련으로는 늦출 수 없다. 추천 = 초반(T1 ~ T3) 영웅 · 전설 칸을 낮추거나 초반 강화 비용 곡선 조정(경제 큰 결정).
3. **세트 스위치(기본 끔)**: 2부위 최대 체력 +5% · 3부위 최종 피해 +5% · 세대 ×(1 + 0.1 × 세대). 추천 = 켬 + 세대 배율 상한(예: ×1.5) 후 EconSim 재측정.
4. **토벌 시간 공정성**(리뷰 치명 대응): 고대 · 태초 · 초월 × min(1, 전투 초 ÷ 120). 추천 = 유지 + 보스별 쿨다운은 알파 계측 뒤.
5. **초월 고유 효과 상속**: 초월 장갑 치명 피해가 태초보다 0.4 낮다(역전). 추천 = 초월도 태초 고유 효과를 가진다.
6. **옵션 상한**: 초월 3부위 + 태초 보석 5가 상한(2.55 · 7.65 · 10.2)을 넘는다. 추천 = 초월 기준으로 올림 + EconSim.
7. **판매가**: 현행 표 역산 ÷ 등급 수 · 고대 300 · 태초 1,000마리분 상한(스위치 `sellPriceMode`). 보스 · 반짝이 기준 티어 = 1(가장 비쌈) - 추천 = 유지.
8. **순위 창 최종안**: A(탭 + 표) · B(시상대 카드) · C(내 주변 + 시즌 보상) - `Claude outputs/QUEUE-10h/playD-leaderboard-mockups.png`. 추천 = A + C의 내 주변 줄.
9. **고대 보스 출처 6.8%**: 조정안 1(잡몹 ÷ 10 + 반짝이 0.02% → 약 42%) · 2(+ 첫 클리어 1.0% → 약 65%) - `field-drop-tables.md` §5.
10. 파티 토벌(지금 솔로만) · 관문 발판 토벌 = 깬 보스 스테이지에서만.
11. `docs/art/ref`는 .gitignore - 아트 자료 md가 푸시 안 됨. 추천 = `!docs/art/ref/*.md` 예외.
12. 드래곤 공격 배율 · 크기(키 11.4 · 길이 23.9) · 얼음 골렘 무리 3 ~ 4로 복귀 - 체감 확인.
13. 수련 · 능력 최대 효과 = 공격 +5.6% · 체력 +5.6%(상위 1% 이산 흔들림).
14. GearTab 옵션 합계가 세트 · 수련 축을 안 보여 줌 · 딜 부위 배율(C5-1) 툴팁 미표시(U1).

## 5. 남은 일

- Q7 U1 미구현: 단축키 칩 정리(N · L · K · H) · HUD 그림 아이콘 전면 · 장비창 각인 · 각성 · 세트 3부위 표시 · 보석 홈 5 · 체력바 비선형 · 기믹 3컷 카드 · 도감 · 칭호 · 파티원 위치 + 근처 이동 · 환생 보상표 · Shift Lock / 공중 대시 / 3타 표시 정리 · 카툰 폰트.
- 옛 검증 블록 기대값 갱신 필요: D1 · LootRule [4] [9] · G1_2 · P2 E2 · P25c · M1_2 · M1_4 · M1_3T(지점 88) · BalanceDecision · DropNotice · G1_1.
- 퀘스트 재화(반짝 조각 · 시즌 패스 경험치)는 `quests.currencies`에만 쌓임(쓰는 곳 = 패스 · 상점 단계).
- EconSim이 퀘스트 골드를 수입에 안 넣음(규모 작음).

## 6. 사용자 확인 목록(체감 · 미관)

| 확인 | 방법 |
|---|---|
| 푸른 드래곤 실루엣 · 크기 · 공격 3종 전조가 읽히는가 | `/gg tp tier6` · `/gg m2 windup blue_dragon` · `/gg m2 lineup` |
| 드래곤 쓰러짐(비폭력) 연출 | `/gg m2 spawn blue_dragon 14 1` → `/gg killtest` |
| 태초 "[이 서버]" · 초월 "[전 서버]" 배너 구분 | `/gg drop force primordial armor boss` · `/gg drop force transcendent gloves` |
| 퀘스트 · 수련 창(J) 읽힘 · 폰 크기 | J |
| CP 표시 · 오를 때 연출 | `/gg gear transcendent 46 gloves` |
| 성기사 Coming Soon 칸 | [직업 변경] |
| 토벌 입장 체감 | `/gg raid section_guardian` |

## 7. 다음 Play 목록

| 항목 | 방법 | 기대 |
|---|---|---|
| 메뉴바 × 대시 겹침 수정 | 폰 창 + ForceTouchLayout → 메뉴바 · DashHolder 좌표 | 겹침 0 |
| 쓰러짐 연출 캡처 | 처치 직전부터 연속 캡처 | 비폭력 연출 |
| R 3종(쌍검 · 활 · 치유사) | 직업마다 `/gg level` · 환생 맞춘 뒤 R | K2 로그 |
| G-1 ~ 3 · 비상 공중 초기화 | BUNDLE-6h 보고서 §다음 Play | 로그 |
| 보스 선택 창 보상 띠 | 보스 칸 클릭 | 태초 0.1% 표시 |
| 옛 검증 블록 기대값 갱신 뒤 회귀 | 마일스톤 Play | |

(추가 대기열 Q8 ~ Q15는 아래에 이어서 적는다.)

# QUEUE-ALL9C 블록 1 기록

> 사용자 10-02 후기 원문: 저장소(docs/phase · docs/design)에서 "10-02" · "후기"로 찾았으나 없음 → 지시문 그대로 진행.

## 1-1 A1 말투 통일

- 기준: 시스템(서버 응답 · 오류 · 실패 · 막힘 · 결과 · 요청 제한) · 확인 창(확인 · 포기 · 투표 · 일괄 판매) · 알림 = **합쇼체**(서술 "~니다" · 질문 "~니까 / ~시겠습니까?"). 요청형 "~하세요 · ~해 주세요"는 허용(게임 UI 관례 - "~하십시오"는 딱딱해서). 튜토리얼 · NPC · 안내(help · guide · scene · gimmick · hub · 지도 · 설정 힌트)는 해요체 가능.
- 검사: `check_textdata.py`에 "시스템 · 확인 창 · 알림 해요체(ALL9C 1-1 A1)" 추가 - 키 규칙 `SYS_KEY`(srv · err · fail · blocked · confirm · toast · notice · alert · result · rateLimited · giveup · vote · gear.bulk …) × 해요체 끝맺음(요 · 죠 - "세요"(요청형) · "필요"(명사) 제외). 예외 표 `TONE_EXCEPT`:

| 키 | 이유 |
|---|---|
| gimmick.section_guardian.fail · gimmick.frost_giant.fail | 보스 기믹 실패 안내(짧은 구호 - 튜토리얼 성격) |
| hub.service.noticeBoard.intro | 마을 게시판 NPC 소개 |

- 고친 문구 29줄(ko만 - en은 원래 평서): board.done · cos.emote.fail.(no_partner · not_ready · too_far) · desc.awaken.(alreadyMax · noGold · notFound · notPrimordial) · **gear.bulk.confirm**("…골드를 받습니다. 판매는 되돌릴 수 없습니다." - 일괄 판매 확인 창 문어체 정리) · gear.bulk.changed · gear.bulk.excludeNote · gear.confirm.unlock1 · unlock2("푸시겠습니까?") · giveup.body · giveup.bodyParty · vote.giveup.body · vote.retry.body("~시겠습니까?") · season.bonusCapped · shop.reason.notReady · shop.notReady("곧 열립니다") · srv.codex.eggFull · srv.hof.empty · srv.raid.soloOnly · srv.weekly.blocked.(casting_already · combat · failed · in_boss · tutorial) · combat.stealLockHint.
- 옛 ALL9A 2-3 규칙("확인 창 = ~해요")과 방향이 반대 - 이번 A1이 우선. 문어체 금지(~한다 · ~없다)는 그대로 둠.

## 1-2 C1 캐릭터 창 상세 능력치

- 구조: 줄 목록 = `shared/data/StatSheetData.lua`(rows · sources) · 값 = 서버 `PlayerProfile.getStatSheet`(전투와 같은 함수 - `getStatSummary` · `PlayerCombat.getAttackParts` · `getCritBonus` · 경험치 배율 식) → Remote `StatSheetFetch`(RequestGate) → 캐릭터 창은 받은 줄을 목록 순서대로 그리기만 함. 줄 추가 = 데이터 한 줄 + 서버 `STAT_BUILDERS[id]` 하나(화면 코드 그대로).
- 실제 있는 스탯만: 공격력 · 공격 속도(상한 적용 배율) · 치명 확률 · 치명 피해 · 최대 체력 · 방어력 · 이동 속도(상한 적용) · 경험치 획득. **골드 획득 배율은 게임에 없어 뺌.** 출처 = 기본 · 장비 · 강화 · 수련(이정표 포함 영구 버킷) · 보석 · 버프(파티 경험치 · 복귀 부스트). 도감 = 지금 능력치를 주지 않아 줄에 안 나옴(출처 칸만 준비).
- 옵션 축 출처 나누기: 장비 → 보석 → 세트(장비로) → 수련 순으로 더해 본 차이(상한이 있으면 먼저 온 출처가 먼저 참 · 몫 합 = 상한 안 합계). 공격력은 곱 줄(×) + 더하기 줄(+%)이 섞여 출처마다 한 줄로 묶음.
- PC = 줄에 마우스를 올리면 펼침(클릭 = 고정) · 폰 = 누를 때마다 펼침/접힘. 능력치 목록을 스크롤 틀로 바꾸고 스크롤 막대 자리를 따로 비움(숫자가 막대에 가려 잘리던 것).
- 고친 표시 버그: 옛 "이동 속도 +2.1%" 줄 = Attribute `SpeedPercentBonus`(비율 2.11 = +211%)를 % 단위로 착각해 찍던 것 → 상세 칸의 실제 이동 배율(×1.50)로 대체하고 옛 줄 제거.
- 하네스 `stat_sheet_test` 9/9(맨몸 · 장비 + 보석 + +22 + 수련: 합계 = getStatSummary · 출처 합 = 합계 · 줄/출처 = 데이터).
- Play(PC): C → 상세 능력치 공격력에 마우스 → "기본 162 · 장비 ×1.08 · +397.0% · 강화 ×3.90" = 3,411(전투력 계산과 같은 값) · 캡처 `captures/1-2_character_detail_hover_pc.jpg`.

## 1-3 E1 · E2 퀘스트

- E2: 탭 "메인 · 일일 · 주간"을 **"퀘스트" 한 탭의 세 구역**(메인 → 일일 → 주간)으로 묶음(남은 탭 = 전 서버 협동 · 주간 도전). 구역 머리 = 이름 + "완료 n/전체". 주간 구역 = 머리를 눌러 접기/펼치기(▼/▶ - 받을 것이 있으면 처음부터 펼침). 옛 탭 id로 여는 곳(오늘의 목표 "daily")은 그 구역 머리로 스크롤.
- E1: 진행 막대 + 숫자(기존) + **메인 카드 단계 점**(지난 = 초록 · 지금 = 금 · 남은 = 테두리 색 · 40칸까지 - 초반 여정 32칸) · 받을 수 있는 줄 = 금 테두리 + 밝은 바탕 · 각 구역 안 순서 = 받을 수 있음 → 진행 중 → 받음.
- 같이 고친 기존 결함: 퀘스트 줄의 보상 칸(130px)이 받기 버튼과 30px 겹쳐 보상 개수(×n)가 버튼 밑에 가려지던 것 → 줄 안 배치를 34px 왼쪽으로.
- Play(PC): J → 메인 카드 금 테두리 + 단계 점 · 일일 "완료 0/3" · 접속 보상 받기 클릭 → 골드 2,788 → 3,288 · 그 줄이 일일 구역 맨 아래로(순서 4 → 8) / 주간 머리 클릭 → ▶ 0줄 → ▼ 5줄 · 보상 ×100 · ×20 보임. 캡처 `captures/1-3_quests_*.jpg`.

## 1-4 H + L1 파티

- 흩어져 있던 입구: HUD [파티] 버튼 · P · 더보기(…) 안 "파티" · 파티 창 안 [모집 게시판] 버튼 → 따로 뜨는 모집 게시판 창.
- 지금: **입구 = HUD [파티] 버튼 · P 하나 → 파티 창 탭 [내 파티 · 파티 찾기]**. 모집 게시판은 독립 창을 없애고 [파티 찾기] 탭 안에 그대로 지음(`PartyBoard.mount` · `PartyBoard.open()` = 파티 창 그 탭). 친구 초대 = 제목줄 오른쪽 금색 버튼(그대로). 더보기에서 파티 뺌(`PanelRegistry` - 단축키 P 그대로).
- 그대로 둔 것: 파티 요청 배너(수락 · 거절 - 상황 알림) · "파티원에게 이동"(지도 이동 버튼 - 파티일 때만) · 견습 단계의 친구 부르기 강조.
- Play(PC): P → [내 파티] 탭 · [파티 찾기] 클릭 → 역할 · 인원 칩 · 모집 올리기 · "지금 이 서버에 올라온 모집이 없습니다" / 더보기 안 = 설정만. 캡처 `captures/1-4_party_*.jpg`.

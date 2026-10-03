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

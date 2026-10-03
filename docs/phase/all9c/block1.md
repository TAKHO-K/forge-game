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

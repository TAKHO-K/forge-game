# G1-4 보고 - 보스맵 잔류 · 다음 / 다시 도전 / 마을 · 90초 자동 이동

지시 = 사용자 프롬프트(G1 C 앞부분, COMMON.md §7). 기준선 = `4473c26`. PRD = 20.127. 저장 구조 변경 없음. G1-5와 같은 Play 3회를 썼다(`docs/phase/G1-5-report.md` ③).

## ① 합격 기준

| 항목 | 결과 | 근거(`[G1-4][나]` 실제 처치 경로 - MonsterState.applyDamage → CombatResolution.resolveHit) |
|---|---|---|
| 클리어해도 보스맵에 남는다 | O | `처치 뒤: 잔류 true · 보스 모델 nil · 아레나 안 true · 슬롯 1 유지 · 남은 90초` |
| [다시 도전] = 보스 재생성(같은 슬롯 · 기록 시간 새로) | O | `다시 도전: true(retry) · 보스 true · HP 100% · 같은 슬롯 true · 잔류 false · 기록 시간 새로 true` |
| [마을] | O | `마을: 보스전 nil · 스테이지 5(그대로)` |
| [다음 스테이지] | O | `다음: 보스전 nil · 스테이지 6` |
| 90초 무입력 → 다음 스테이지 | O | `90초 무입력: 0.4초 뒤 보스전 nil · 스테이지 6(자동 다음)` |
| 파티 재도전 = 재투표 | O(코드 · 리뷰) | 리더만 신청 → `PartyVote` kind "retry"(대상 = 그 보스전에 남은 멤버) → 통과 시 재생성. 다중 클라 실측은 못 함 |
| 리더보드는 첫 돌파만 · 전멸 뒤 재도전 시간 초기화 유지 | O | 재도전은 bestBossCleared가 이미 그 스테이지라 기록 대상 아님(LeaderboardRules 그대로) · 재생성 · 전멸 리셋 모두 startedAt 새로 |
| 가방 가득 보스 장비 | O | `잔류 중 떨어뜨림 nil · 마을로 돌아가는 순간 1개` |
| 선택 창(폰 포함 버튼 44) | O(스크린샷) | "보스 처치!" 창 - [다음 스테이지] · [재도전 투표](파티원이면 비활성 + "파티 리더만 신청합니다") · [마을] · 남은 초. 이유 줄이 창 밖으로 잘려 높이 190 → 214 |

## ② 구조

- `BossEncounter.enterLinger` - 보스 모델만 치우고(encounter.model = nil · lingering = true · lingerUntil) 멤버 · 슬롯 · 아레나는 남긴다. `endEncounter` · `leaveFor` · `resetFor`가 모델 없음을 견딘다. `retryLinger` = 같은 인스턴스 데이터로 같은 슬롯에 재생성.
- `server/BossLinger`(+ `BossLingerServer.server.lua`) - Remote `BossLinger`(창 열기 · 닫기) · `BossLingerChoice`(next · retry · town) · 1초마다 90초 검사 · 가방 가득 드랍 맡기(`BossEncounter.onMemberReturned`).
- `client/panels/BossLinger` + `BossLingerClient.client.lua` - window 창(문구 = TextData).
- 잔류 중 스테이지 선택 창으로 옮기면 그 사람만 잔류에서 빠진다(StageServer).
- 검증 모드에서는 서버 전체 잔류를 끈다(`BossEncounter.debugLingerOff` - 처치 직후 복귀를 전제로 한 옛 검증 블록 수십 개) · G1-4(나)만 켠다. 수동 Play는 잔류가 켜진 실제 동작.

## ③ 가정 · 결정 로그

| # | 결정 | 이유 |
|---|---|---|
| 1 | 선택은 사람마다(파티원도 [다음] · [마을]로 자기만 빠짐) · 재도전만 리더 + 재투표 | "파티는 재투표"(사용자) · 다음 · 마을은 개인 이동 |
| 2 | [다음] = 그 사람의 보스 스테이지 + 1(이동 규칙 그대로) - 기록이 안 올라 못 가면(기여 10% 미만 파티원) 마을 + 안내 | 규칙 우회 없음 |
| 3 | [마을] = 스테이지는 보스 스테이지 그대로 | 옛 처치 뒤 복귀와 같음 |
| 4 | "90초 무입력" = 90초 안에 아무것도 안 고름 | 선택 외 입력은 서버가 모른다 |
| 5 | 재도전 쿨 없음 | [계산] 보스 HP · 골드 · 경험치 = tier1 잡몹 ×20 → HP당 보상이 tier1 사냥과 같고, 장비는 재도전 1개 vs 같은 HP의 tier1 20마리 × 0.25 = 5개 - 재도전이 사냥보다 시간당 가치가 높지 않다 |

## ④ 보고 · 미결

- 다른 서버 합류 대기자는 잔류 · 재도전 동안에도 "보스전 중"으로 기다린다(PartyCrossServer bossActive - 잔류 시작에 끝 신호를 안 보냄). 최대 90초 + 재도전.
- 포기 투표가 진행 중일 때 보스가 죽으면 그 투표가 끝날 때까지 재도전 투표가 "진행 중" 거절(안내 없음).
- `/gg party killsim` · `status`(개발 명령)는 잔류 중 보스 모델이 없어 끊기거나 0/0.
- 사람이 확인할 것: 잔류 창 문구 · 90초가 적당한가 · 파티 재도전 투표 흐름(다중 클라).

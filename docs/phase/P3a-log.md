# P3a 로그 - 리더보드 서버(L1) · 파티원 진도 갱신 · 원형 보스맵(4인 · 6종) · 보스 장판 판정 버그

자율 진행 단계(COMMON.md §7). 지시 원문 = 사용자 프롬프트 + 도중 추가 지시 4건(아래 0-추가).

## 0-추가. 도중에 받은 사용자 지시(원문 요지)

1. 보스전 맵을 지금보다 크고 웅장하게 - 최대 4인 입장을 고려한 4인 전용 맵(6종) + 앞으로 추가될 보스를 고려한 계획(기존 맵 재사용 또는 신규 맵의 크기). → 처음엔 "계획만", 곧이어 **"4인 보스맵 구현까지 가능하다면 거기까지 완료"**.
2. 성능 기준(C3)에 꼭 맞추지 못하더라도, 전체 디자인 · 맵 분위기 · 보스와의 색감 · 지형지물이 어울리면 된다.
3. 에셋은 카툰 그래픽 쪽으로 만들 예정이고 최종 외형에 테두리 선이 생길 확률이 높다 - 이 분위기를 반영. 지형지물로 인한 맵 오류 · 끼임만 없으면 된다.
4. 지형지물 = 이동 경로 · 충돌은 가능(보스 돌진 시 상호작용 · 기절)하지만 유저가 세 번 정도 때리면 깨지는 구조물. 깨지면 파편 이펙트. 자연스러운 구조물이면 된다.

## 0. 코드 사실(시작 `b0a841c` 기준)

| 항목 | 코드 사실 | 위치 |
|---|---|---|
| 진도 필드 | 직업별 `stageProgress.infinite`(지금) · `infiniteBest`(도달 - 이동 규칙 "최고 + 1까지") · `bestBossCleared`(보스 클리어 - 보스 게이트) | `SaveSystem` 기본값 · `PlayerProfile` |
| "리더만 갱신" | 파티 보스 입장은 리더의 `StageMoveRequest`가 연다 → `setInfiniteStage`가 **리더에게만** 불린다. 파티원의 `infiniteBest`는 보스를 깨도 안 오른다 → 파티원은 보스 스테이지로 못 가고(파티원 금지) 그 다음 스테이지로도 못 간다(최고 + 1) | `StageServer.performMove` |
| 클리어 기록 | 보스 처치 때 후보 전원이 기여 10% 이상이면 전원 `setBossCleared(stage)`(단조 최대) - 한 명이라도 미달이면 아무도 없음(25-3 게이트) | `CombatResolution.handleBossDeath` |
| 보스전 시간 | `encounter.startedAt = os.clock()`(스폰 순간) - 기록 · 표시에 쓰는 곳 없음 | `BossEncounter.spawnEncounter` |
| 아레나 | 정사각형 반폭 96(= 격자 기준 21-3 검증 크기) · 벽 4장 · 바닥 1장(색 30,15,15) · 슬롯 12개(z = −3000부터) · 슬롯당 한 번 짓고 계속 재사용 · 입장점 = 벽에서 10 | `WorldConfig` · `BossEncounter.buildArena` |
| 아레나 크기에 걸린 값 | 원 · 돌진 · 직선 · 분열 · 회오리의 자르기(`clampToZone` · `clipToZone` - AABB) · 파동 최대 반경(반폭 × 1.464) · 스케줄러 자리 비우기 상한(`BossSkillMath.boundSeconds` - 반폭) · 시뮬(`BossSim` - `WorldConfig.bossArena.halfSizeStuds`) · 구역 경계(`ZoneBounds` · MonsterAI 리쉬) · 전역 기믹 빨강 바닥(클라 - `zoneHalfSize` 정사각형) · 모래 무덤 밀기 경계(`BossGimmicks`) | grep `halfSize` |
| 모서리 회피 | S15 측정: 벽 1stud 2/48 · 모서리 1stud **37/48** · 3stud 18/48 실패 | PRD 20.101 [8] · `BossSim.checkDensityWall` |
| 플레이어 피격 표시 | 플레이어가 맞으면 체력바(`Hp` Attribute)만 줄어든다 - 피해 숫자 · 맞은 표시가 없다 | `PlayerHealthBar` · `DamageNumbers`(몬스터 · 치유만) |
| 신규 보호 | `applyFinalDamage`에서 피해에 곱한다(판정은 그대로 · 피해만 줄어든다) - 최고 스테이지 1 = ×0.10 · 5 = ×0.16 | `PlayerDamage.getNewbieMultiplier` |
| 보스전 종료 | `endEncounter`는 `propsClear`만 보낸다 - 떠 있던 예고(원 · 선)를 지우는 `reset`은 안 보낸다 | `BossEncounter.endEncounter` · `BossPatternVisuals` |

## 가정·결정 로그

## 결정 필요

## 공식 문서 인용(B - 요청 한도)

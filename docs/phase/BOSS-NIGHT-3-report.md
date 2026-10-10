# BOSS-NIGHT-3 (BOSS-FEEL) 보고서 (단계마다 갱신)

기준 = handoff `NEXT-PROMPT-QUEUE.md` 정본 값 표 · `31_bosses/CC-DEFS-draft.md`(10-10). `BossFrameworkData.live` 끈 채(실전 = 옛 몸 · 아래 작업 대상 = 새 몸 Studio 시험 경로 + 공통 서버 코드) · 확률/가격/드랍 불변 · 삭제 0 · force-push 금지.

| 단계 | 상태 | 커밋 | 바뀐 파일 | 삭제 |
|---|---|---|---|---|
| 0 현황 통합표 | 끝 | `4251b72d` | 3 | 0 |

## 0단계 — 현황 통합표
표 = `docs/design/boss-bible/BOSS-NIGHT-3/00_inventory.md`(6보스 × 79줄 · 평타 포함) · 덤프 하네스 = `roblox/tools/harness/boss_inventory_dump.luau`.

핵심:
- 73개 패턴 중 **약 30개가 실전에서 거의 안 나옴**(BossSim 600판 평균 < 0.1 · Studio 1판 0) — 스케줄러가 목록 앞 · 먼저 준비된 패턴을 고르고, 굶주림 보정 75초가 전투 길이 58 ~ 100초보다 길어서.
- **대공 잡기 = Studio 6판(3초마다 점프) · BossSim 600판 모두 0회**(실제로 안 나옴).
- 원거리 견제는 6보스 모두 있음(일부만 실제로 나옴) · 거리 좁히기: 수호자(도약 · 돌진은 0회) · 전갈(잠행 찌르기) · 매머드(상아 돌진 드묾) / **수정 여왕 · 나가 · 폭풍 = 없음**.
- 매머드 근접 대응기 발 구르기 = 0회(1단계 6에서 다룸).

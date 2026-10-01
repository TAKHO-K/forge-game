# 영어 넘침 위험 목록 (QUEUE-ALL4 E · 2026-10-01)

> 영어(TextData en)가 한국어보다 넓어져 고정 칸에서 잘리거나 넘칠 만한 자리. **추정치** - 실제 화면 캡처(Studio, 800 × 360 폰 · PC)로 확인한다.
> 글 폭 추정 = 한글 0.92 em · 영문 소문자 0.50 · 대문자 0.64 · 숫자 0.56 · 공백 0.27 (× TextSize). `{자리}`는 양쪽 같은 폭(숫자 4자)으로 쳤다. 칸 너비 = 코드의 `Size` · `width`(버튼은 좌우 여백 약 12 뺌). 폰은 글씨 ×1.15(Theme)라 같은 칸에서 더 빡빡하다.
> 비율 = en 추정 폭 / ko 추정 폭. 칸 대비 = en 추정 폭 / 칸 너비(1 넘으면 넘침 · 0.9 이상은 빠듯함).
> 영어는 아직 꺼져 있다(설정 `language` 기본 "ko") - 이 표는 영어를 켜기 전에 고칠 목록이다.

## 상위(확인 우선)
| 순위 | 파일:줄 | 키 | 칸 너비(px) | 글씨 | ko 글자 · 폭 | en 글자 · 폭 | 비율 | 칸 대비 | 메모 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `client/StageRewardBand.lua` 123 ~ | `hud.band.dropTicket` · `hud.band.resetTicket` · `hud.band.ticketRow` | 띠 폭 − 머리 칸(한 줄) | caption 12 | 8 ~ 9 · 92 ~ 103 | 24 ~ 25 · 165 ~ 171 | 1.7 | 한 줄 전체 약 26자 → 60자 | 방지권 정식 이름(Drop/Reset Protection Ticket)이 길다 - 줄임 표기 결정 필요 |
| 2 | `client/panels/Inventory/ItemConfirm.lua` 76 | `gear.confirm.cancel` | 44 | body 14 | 2 · 26 | 6 · 44 | 1.7 | 1.0 | "Cancel"이 칸에 꽉 참(폰 ×1.15면 넘침) |
| 3 | `client/panels/Inherit.lua` 189 | `forge.inherit.stat.critDmg` · `critRate` | 약 158(600 창 colW + 20) | caption 12 | 17 ~ 19 · 135 ~ 142 | 36 ~ 37 · 199 ~ 210 | 1.5 | 1.3 | 괄호 설명이 길다 - 줄바꿈 또는 괄호 줄이기 |
| 4 | `server/HallOfFame.lua` 49 | `srv.hof.title` | 800(SurfaceGui 전체) | 44 GothamBlack | 15 · 445 | 31 · 676 | 1.5 | 0.85 | GothamBlack은 추정보다 넓다 - 빠듯함(방송 문장이라 지금은 ko로 나감) |
| 5 | `client/StageRewardBand.lua` 300 | `hud.band.codex` | 34 | caption 12 | 2 · 22 | 5 · 32 | 1.5 | 0.94 | "Codex" |
| 6 | `client/panels/GemForge.lua` 134 | `forge.gem.bulk` | 100 | body 14 | 5 · 55 | 13 · 92 | 1.7 | 0.92 | 탭 · 동작 버튼 "Dismantle All" |
| 7 | `client/panels/Inventory/GemSlotRows.lua` 68 · `GemTab.lua` 529 | `gear.gem.reroll` · `inv.act.reroll` | 64 × 17 | caption 12 | 2 ~ 5 · 22 ~ 68 | 6 ~ 8 · 38 ~ 72 | 1.1 ~ 1.7 | 1.1 | "Reroll({count})" 넘침 가능 |
| 8 | `client/hud/SkillTooltip.lua` 166 | `desc.skill.label.finalDmg` · `expected` · `range` | 84(줄 머리 칸) | caption 12(폰 14) | 5 ~ 8 · 47 ~ 66 | 11 ~ 12 · 64 ~ 73 | 1.0 ~ 1.4 | 0.87(폰 1.0) | 폰에서 빠듯 |
| 9 | `client/hud/UltGauge.client.lua` 63 | `hud.ult.full` | T 칸(원 64) | 14 GothamBold | 5 · 51 | 10 · 71 | 1.4 | 1.1 | "T Ultimate" |
| 10 | `client/panels/Inspect.lua` 166 | `ui.inspect.part.*` | 56 | caption 12 | 2 · 22 | 5 ~ 6 · 32 ~ 38 | 1.7 | 0.68 | 보석 칸 `Gem {slot}`은 더 길다 |
| 11 | `client/panels/Enhance/OddsView.lua` 131 | `forge.enhance.gauge` | 48 | caption 12 | 2 · 22 | 5 · 32 | 1.5 | 0.67 | |
| 12 | `client/panels/Party.lua` 468 · 487 | `ui.party.invite` · `ui.party.member` | 72 | caption 12 | 2 ~ 3 · 22 ~ 33 | 6 · 38 | 1.2 ~ 1.7 | 0.53 | |
| 13 | `client/StageRewardBand.lua` 340 · 406 · 357 · 261 | `hud.band.challenge` · `remoteEntry` · `gateGuide` · `gimmickHelp` | 84 ~ 92(버튼) | body 14 | 2 ~ 6 · 26 ~ 68 | 8 ~ 9 · 62 ~ 65 | 1.0 ~ 2.5 | 0.8 ~ 0.9 | 폰 ×1.15면 빠듯 |
| 14 | `client/panels/Inventory/PrimordialActions.lua` 52 | `gear.awaken.free` · `gear.awaken.cost` | 96 × 44(줄바꿈) | header 16 | 3 ~ 6 · 69 | 7 ~ 13 · 99 | 1.4 | 1.0 | 두 줄로 접힘 - 높이 44 안에 드는지 |
| 15 | `client/WorldClient.client.lua` 290 | `scene.world.recallTime` | 84 | body 14 | 3 + 시간 · 61 | 7 + 시간 · 79 | 1.3 | 0.94 | 폰에서 넘침 가능 |
| 16 | `client/panels/Inventory/DetailCard.lua` 218 | `inv.gems.title` | 70 | body 14 | 4 · 42 | 9 · 64 | 1.5 | 0.91 | "Gem Slots" |
| 17 | `client/BossTrapView.lua` 343 | `scene.boss.trap.rescuing` · `stuck` | 236 | 14 GothamBold | 최장 24 | 최장 38 | 1.4 | 1.2 | ko도 이미 넘침 |
| 18 | `client/ui/RewardIcons.lua` 55 | `ui.reward.short.*` | 아이콘 정사각(퀘스트 26) | ArtImage 기본 | 1 ~ 2 | 3 ~ 5 | 1.5 ~ 2.5 | - | 아이콘이 없을 때만 나오는 대체 글자 |
| 19 | `client/panels/GemForge.lua` 236 | `forge.gem.selected` | 104 | body 14 | 3 · 39 | 8 · 58 | 1.5 | 0.63 | |
| 20 | `client/panels/Inventory/GearTab.lua` 203 · 214 | `gear.stats.header` · `gear.stats.maxHpPercent` | 줄 높이 14 ~ 15(가로는 상대) | caption 12 | 2 ~ 6 | 8 ~ 12 | 1.5 ~ 2 | - | "Vitality" |

## 참고 - 줄바꿈 칸이라 넘침보다 높이가 문제인 것
- en 40자 넘는 문장 106개(자리 제외 - `check_textdata.py` 참고 줄). 대부분 도움말 본문(`*.help.short` · `*.help.detail`) · 확률표 머리글 · 확인창 본문 · 초월 툴팁(`transcendent.special.*`) - ko도 40자를 넘는 문장이다. 고정 높이 칸(예: `gear.gem.hint.*` 18px 한 줄 · `GemHeader` 81 · 82줄 caption)은 줄이 늘면 잘린다.
- `client/PrimordialFx.client.lua` 82 `scene.primordial.spectate`(220) · `BossRodsView` 102(340 · 폰 300 · title 20) · `BossEnvironmentView` 353(360 · 22 - ko도 꽉 참) · `ZoneBoundaryWarning` 110(420 · 18)은 이름 인자 길이에 따라 넘칠 수 있다.

## 글리프 확인
- `ui.milestone.*` en의 "≈" - GothamBold에 글리프가 있는지 화면에서 확인(옛 사례: ≋ 없음).

## 다음
- 메인 작업자: 영어로 캡처할 화면 = 가방(장비 · 보석 탭 · 확인창) · 강화대 · 보석 가공 · 계승 · 스테이지 선택 보상 띠 · 스킬 툴팁(폰) · 파티 창 · 살펴보기 · 궁극기 게이지 · 명예의 전당 판(서버 방송이라 지금은 ko).
- 고치는 방법(결정 필요): ① 버튼 칸을 글 길이에 맞추기(AutomaticSize X + 최소 너비) ② en만 줄임 표기(예: "Drop Prot. ×{count}") ③ `TextScaled` + `UITextSizeConstraint`(최소 12 - 실효 12 규칙).

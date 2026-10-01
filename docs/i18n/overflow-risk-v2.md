# 영어 넘침 위험 v2 (QUEUE-ALL5 F · 2026-10-01)

> v1(`overflow-risk.md`, QUEUE-ALL4 E)을 이어받아 **번역 손질 뒤의 en 값**으로 다시 쟀다. 전부 **추정치**다 - 상위 30은 다음 Studio 캡처(PC + 폰 글씨)로 확인한다.
> 전체 키 길이 표(1,374줄) = `docs/i18n/length-all.csv`(키 · ko 글자 · en 글자 · en/ko · 칸 종류 · 칸 px · 글씨 · 첫 사용처).

## 1. 방법

1. **전 키 길이** - `TextData*.lua`의 ko/en 짝을 `check_textdata.py`의 읽기 함수로 읽어, RichText 태그를 빼고 `{자리}`는 숫자형 3자 · 이름형 10자로 채워 글자 수를 셌다(→ `length-all.csv`).
   - en이 ko보다 긴 키 1,257 / 1,374 · 1.5배 이상 772 · 2배 이상 386 · en 40자 넘는 키 152(자리 채운 길이 기준 - 체커의 "40자 넘는 문장 109"는 자리를 뺀 길이).
2. **사용처 찾기** - `roblox/src`에서 키를 글자 그대로 쓰는 줄 + `"접두어." ..`로 만드는 키(예: `gimmick.` · `inv.axis.` · `shop.pass.`)를 모았다. 사용처를 못 찾은 키 28개(변수로 넘기는 키 - 체커의 "키를 변수로 넘기는 호출 50"과 같은 무리).
3. **칸 폭 자동 판정(참고용)** - 사용처 줄에서 글이 들어가는 변수(`x.Text =` · `Theme.label(...)`)를 찾아 같은 파일의 `x.Size` · `x.TextSize` · `TextWrapped` · `TextScaled`를 읽고, 없으면 같은 호출의 `width =`(Button 키트)를 읽었다. 고정 px 칸 61 · 부모 폭 기준(상대) 칸 1,285 · 사용처 없음 28. 상대 칸은 px를 정할 수 없어 자동 순위에서 빠진다 → 아래 "캡처할 화면"으로 덮는다.
4. **상위 후보 손 계산** - v1 상위 20 + 자동 판정 상위 + 고정 칸 UI(띠 · 버튼 · 툴팁 머리 칸 · 트랩 패널 · 기믹 카드 3컷)를 코드에서 직접 읽어 칸 폭을 정했다(아래 표의 파일:줄).
   - 한 줄에 들어가는 글자 = 칸 폭 ÷ (TextSize × 0.55). 굵은 글꼴(GothamBold)은 × 0.6, 한글은 × 0.92 em으로 쳤다. GothamBlack(명예의 전당)은 0.6보다 넓어 실제가 추정보다 빡빡하다.
   - 버튼(Button 키트)은 좌우 여백 12를 뺐다. `Theme.label`은 `TextTruncate = AtEnd`라 넘치면 **"…"로 잘린다**(뒤가 안 보임). 직접 만든 `TextButton`(확인창 · 궁극기 칸)은 잘림 없이 **칸 밖으로 삐져나온다**.
   - 폰 = 글씨 × 1.15(`Theme.mobileTextScale` - caption 12 → 14 · body 14 → 16). 고정 TextSize(14 · 16 · 22 · 44)는 폰에서도 그대로.
5. **위험도** = en 추정 폭 ÷ 칸 폭(PC · 폰 중 큰 값). 1.00 넘음 = 높음(잘림 · 삐짐), 0.90 ~ 1.00 = 중간(빠듯), 그 아래 = 낮음. "ko"는 같은 칸의 한국어 값 - ko도 1을 넘으면 en만의 문제가 아니라 칸 문제다.

## 2. 상위 30 (현재 en 기준 · 위험도 순)

| 순위 | 키 | ko 글자 | en 글자 | 칸 폭 추정(PC / 폰) | 파일:줄 | 위험도(en · ko) | 줄임 | 캡처 방법 |
|---|---|---|---|---|---|---|---|---|
| 1 | `hud.band.gearClaimed` | 38 | 43 | 242 / 234px · caption 12 / 14 | `client/StageRewardBand.lua:114` | **1.41** 높음 · ko 1.54 | 줄임(전 1.81) | 가 |
| 2 | `hud.band.gear` | 33 | 41 | 242 / 234px · caption | `client/StageRewardBand.lua:116` | **1.35** 높음 · ko 1.33 | 줄임(전 1.61) | 가 |
| 3 | `inv.act.reroll` | 7 | 10 | 60px · caption | `client/panels/Inventory/GemTab.lua:529` | **1.28** 높음 · ko 1.16 | - | 자 |
| 4 | `scene.world.recallTime` | 7 | 11 | 84px · body 굵게 14 / 16 | `client/WorldClient.client.lua:344` | **1.26** 높음 · ko 0.92 | - | 아 |
| 5 | `hud.band.ticketRow`(+ `dropTicket` · `resetTicket`) | 27 | 40 | 268 / 260px · caption | `client/StageRewardBand.lua:123 · 144` | **1.18** 높음 · ko 1.06 | 줄임(전 약 1.9 - "Drop Protection Ticket") | 가 |
| 6 | `hud.band.codex` | 2 | 5 | 34px · caption | `client/StageRewardBand.lua:300` | **1.13** 높음 · ko 0.76 | - | 가 |
| 7 | `gear.bulk.dismantle` | 6 | 11 | 96px(108 버튼) · body 굵게 | `client/panels/Inventory/BulkSell.lua:174` | **1.10** 높음 · ko 0.71 | 용어만(Salvage) | 자 |
| 8 | `hud.band.gimmickHelp` | 6 | 9 | 80px(92 버튼) · body 굵게 | `client/StageRewardBand.lua:261` | **1.08** 높음 · ko 1.04 | - | 가 |
| 9 | `forge.gem.bulk` | 5 | 11 | 100px(112 탭 버튼) · body 굵게 | `client/panels/GemForge.lua:134` | **1.06** 높음 · ko 0.68 | 줄임(전 1.25) | 차 |
| 10 | `ui.class.row` | 32 | 44 | 352px · 15 | `client/ClassSelectUI.client.lua:194` | **1.03** 높음 · ko 0.88 | - | 카 |
| 11 | `scene.world.backTime` | 9 | 11 | 104px · body 굵게 | `client/WorldClient.client.lua:332` | **1.02** 높음 · ko 1.03 | - | 아 |
| 12 | `hud.band.remoteEntry` | 5 | 8 | 76px(88 버튼) · body 굵게 | `client/StageRewardBand.lua:406` | **1.01** 높음 · ko 0.90 | - | 가 |
| 13 | `scene.boss.env.padsToCrystal` | 19 | 27 | 356px · GothamBold 22 고정 | `client/BossEnvironmentView.lua:354` | 1.00 중간 · ko 1.00 | 문장만 손봄(길이 같음) | 타 |
| 14 | `gimmick.crystal_queen.do` | 9 | 16 | 154 / 125px · caption | `client/BossIntroDiagram.lua:550` | 0.99 중간 · ko 0.84 | 줄임(전 1.29) | 파 |
| 15 | `gimmick.abyssal_lord.line` | 21 | 40 | 480 / 393px · body 굵게 | `client/BossIntroDiagram.lua:586` | 0.98 중간 · ko 0.70 | 문장 손봄(전 0.95) | 파 |
| 16 | `hud.band.gateGuide` | 5 | 7 | 72px(84 버튼) · body 굵게 | `client/StageRewardBand.lua:357` | 0.93 중간 · ko 0.95 | 줄임(전 1.20) | 가 |
| 17 | `gimmick.section_guardian.do` | 7 | 15 | 154 / 125px · caption | `client/BossIntroDiagram.lua:550` | 0.92 중간 · ko 0.64 | 줄임(전 1.36) | 파 |
| 18 | `attendance.login` | 11 | 20 | 208px(220 버튼) · body 굵게 | `client/panels/Attendance.lua:41` | 0.92 중간 · ko 0.70 | 줄임(전 1.20) | 하 |
| 19 | `desc.skill.label.range` | 8 | 10 | 84px · caption | `client/hud/SkillTooltip.lua:166` | 0.92 중간 · ko 1.04 | 줄임(전 1.10) | 라 |
| 20 | `desc.skill.label.partyBuff` | 5 | 10 | 84px · caption | `client/hud/SkillTooltip.lua:166` | 0.92 중간 · ko 0.71 | - | 라 |
| 21 | `gear.bag.fullToast` | 36 | 37 | 356px · 16 고정 | `client/InventoryUI.client.lua:221` | 0.91 중간 · **ko 1.32** | - | 거 |
| 22 | `forge.inherit.stat.speed` | 10 | 19 | 160px(colW + 20) · caption | `client/panels/Inherit.lua:276` | 0.91 중간 · ko 0.68 | - | 마 |
| 23 | `forge.rebirth.milestones` | 5 | 14 | 136px · 16 | `client/panels/Enhance/RebirthView.lua:59` | 0.91 중간 · ko 0.50 | - | 너 |
| 24 | `scene.boss.trap.rescuing` | 15 | 25 | 236px · GothamBold 14 고정 | `client/BossTrapView.lua:343` | 0.89 낮음 · ko 0.72 | 줄임(전 1.07) | 사 |
| 25 | `scene.boss.trap.stuck` | 16 | 25 | 236px · GothamBold 14 고정 | `client/BossTrapView.lua:343` | 0.89 낮음 · ko 0.78 | - | 사 |
| 26 | `scene.primordial.spectate` | 20 | 25 | 216px · 14 | `client/PrimordialFx.client.lua:82` | 0.89 낮음 · ko 0.95 | 줄임(전 0.96) | 더 |
| 27 | `inv.gems.title` | 4 | 7 | 70px · body | `client/panels/Inventory/DetailCard.lua:218` | 0.88 낮음 · ko 0.76 | 줄임(전 1.13 "Gem Slots" → "Sockets") | 자 |
| 28 | `gimmick.abyssal_lord.do` | 9 | 14 | 154 / 125px · caption | `client/BossIntroDiagram.lua:550` | 0.86 낮음 · ko 0.84 | 줄임(전 1.11) | 파 |
| 29 | `boss.grab.struggle` | 24 | 23 | 236px · GothamBold 14 고정 | `client/BossTrapView.lua:341` | 0.82 낮음 · ko 1.14 | 줄임(전 1.39) | 사 |
| 30 | `desc.skill.label.finalDmg` | 6 | 9 | 84px · caption | `client/hud/SkillTooltip.lua:166` | 0.82 낮음 · ko 0.86 | 줄임(전 1.10) | 라 |

- 예시 인자: 등급 = Legendary(가장 긴 이름) · 레벨 3자리 · 귀환 시간 0:42 · 개수 2 ~ 3자리 · 직업 = Dual Blades · 트랩 종류 = Crystallized.
- 1 · 2 · 5 · 8 · 11 · 21은 **ko도 1 이상**이다 - 글을 줄여서는 안 풀리고 칸(띠 본문 폭 · 버튼 폭 · 토스트 폭)을 손봐야 한다.

### 30위 밖이지만 이번에 줄인 것(캡처 때 같이 확인)
| 키 | 전 → 후 | 위험도 전 → 후 | 파일:줄 | 캡처 |
|---|---|---|---|---|
| `hud.ult.full` | "T Ultimate" → "T MAX" | 1.50 → 0.75 | `client/hud/UltGauge.client.lua:63`(64 × 64 · GothamBold 16 · 잘림 없이 삐짐) | 다 |
| `forge.inherit.stat.critDmg` · `critRate` | 괄호 출처 설명 뺌 → "Crit DMG" · "Crit Rate" | 1.78 · 1.73 → 0.38 · 0.43 | `client/panels/Inherit.lua:276` | 마 |
| `boss.bubble.struggle` | "Stuck in the air - mash jump to escape!" → "Bubble trap! Mash jump!" | 1.39 → 0.82 | `client/BossTrapView.lua:342` | 사 |
| `gear.confirm.cancel` · `gear.confirm.ok` | "Cancel" · "OK" → "No" · "Yes" | 1.31 → 0.44 | `client/panels/Inventory/ItemConfirm.lua:75 · 76`(44 × 44) | 나 |
| `hud.band.challenge` | "Challenge" → "Fight" | 1.14 → 0.63 | `client/StageRewardBand.lua:340` | 가 |
| `srv.hof.title` | "★ Hall of Fame · Transcendent ★" → "★ Hall of Fame ★" | 1.02 → 0.53(GothamBlack이라 실제는 더 넓었다) | `server/HallOfFame.lua:49` | 러 |
| `desc.skill.label.expected` | "Est. Damage" → "Est. DMG" | 1.01 → 0.73 | `client/hud/SkillTooltip.lua:166` | 라 |
| 기믹 카드 3컷 캡션 나머지(`gimmick.*.see/do/fail` 8개) | 모두 16자 이하로 | 최대 1.6("Stand on the matching tile") → 0.9 이하 | `client/BossIntroDiagram.lua:550` | 파 |

## 3. 캡처 방법(기호)

PC 창 + 폰 글씨(`ForceTouchLayout` - 폰 기하 요령은 메모 "Screenshot sync" · "폰 기하 · 클릭 증명")로 각 1장. 영어는 설정 `language = "en"`(또는 `/gg lang en`)으로 켠다.

| 기호 | 화면 · 여는 법 |
|---|---|
| 가 | 구역 선택(N) → 보스 칸 누름(첫 클리어 전 · 뒤 둘 다 - `gearClaimed` · `ticketRowClaimed`는 받은 뒤) → 띠 · 도감 점 · [Fight] [To Gate] [Teleport] [Mechanics] [Show Way] |
| 나 | 가방(B) → 장비 하나 [Salvage] 또는 [Sell] → 확인창 버튼 |
| 다 | 궁극기 게이지 가득(전투로 채움) - 오른쪽 아래 T 칸 |
| 라 | 스킬 버튼 툴팁(PC hover · 폰 길게 누름) - 치유사 R(파티 버프 줄)까지 |
| 마 | 강화대 → 계승 → 착용 장비 + 새 장비 고른 뒤 능력치 비교 표 |
| 사 | 보스 잡기 · 가둠 · 결정화 트랩(서버 execute_luau로 BossPatternEvent FireClient - 메모 "연출 스샷 FireClient") - 자기 패널 제목 |
| 아 | 아트 끔(타일 아님) 상태에서 귀환(B 버튼) 시전 중 · 귀환 뒤 [Return 4:59] |
| 자 | 가방 → 보석 탭(고대 · 태초 보석이 홈에 있을 때 Reroll 버튼) · 상세 카드 Sockets 칸 · 일괄 판매 [Salvage 128] · 태초 장비 [Awaken] |
| 차 | 보석 가공 → [Salvage All] 탭 |
| 카 | 직업 선택 창(첫 접속 · 직업 변경) - Dual Blades 줄 |
| 타 | 수정 여왕 2단계 발판 안내 문구(보스 환경 연출) |
| 파 | 보스 첫 만남 카드(입장 시) + 도움말 → 보스 기믹(폰 667 폭에서 칸이 가장 좁다) |
| 하 | 출석 창 [Claim today's reward] |
| 거 | 가방 가득 찬 채 아이템 줍기 토스트 |
| 너 | 강화대 → 환생 탭 → [Growth Rewards] 버튼 |
| 더 | 초월 알림 수신 → [✦ Watch Transcendent #n] |
| 러 | 허브 명예의 전당 판 - 서버 `Text.get`은 기본 ko라 en으로 보려면 서버 언어를 바꾸거나 화면용 사본으로 촬영 |

## 4. 남은 결정(코드 쪽 - 이번 작업 범위 밖)
- 1 · 2(보상 띠 첫 클리어 줄): ko도 넘친다. 띠 본문을 두 줄로 접거나(`TextWrapped` + 줄 높이) 레벨 범위를 다음 줄로 내리는 것을 권한다.
- 3(`inv.act.reroll` 64px 버튼): "Reroll(12)"를 줄이면 뜻이 사라진다 → 버튼 폭 80으로 넓히거나 숫자를 버튼 밖 배지로.
- 4 · 11(귀환 · 돌아가기 버튼): 아트 켬(기본)이면 타일 아래 시간만 나와 문제 없음 - 아트 끔 대체 화면에서만. 버튼 폭을 글 길이에 맞추기(v1 ① 안).
- 6(`hud.band.codex` 34px): "Codex"는 더 못 줄인다 → 칸 40으로.
- 7 · 9 · 8 · 12(버튼): 버튼 키트에 `UITextSizeConstraint`(최소 12 - 실효 12 규칙)로 폰 글씨만 줄이는 안(v1 ③).
- 21(`gear.bag.fullToast`): ko가 이미 넘친다(1.32) - 토스트 폭이나 줄바꿈.
- 서버가 만든 코드 결과 문장(`RedeemCode`의 `result.message`)은 TextData 키가 아니라 완성 문장이라 영어로 안 바뀐다(`docs/release/codes.md` 참고).

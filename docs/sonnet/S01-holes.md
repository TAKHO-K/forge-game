# S01 — 구멍 막기: 드랍 itemLevel ±2 · 보스 드랍 가방 직행 · 변환권 가격 · /gg 차단 감사

> 의존성: 없음 - **모든 세션보다 먼저.** 규모: 중. 설계 출처: PRD 20.72 [2] · [5] 1단계 / 20.73 [8] 3번 / 20.81 [C-1] · [C-2].
> 왜 먼저인가: 지금 레벨 100이 tier6을 잡으면 itemLevel 420 장비가 나온다(방어 · 체력 10^20배). 이 구멍이 열린 채로 강화를 만들면 모든 검증에 무적 장비가 끼어든다.

## 0. 한 줄 목표

드랍 itemLevel을 "캐릭터 레벨 × tier 보너스"에서 **"기준 스테이지 S + δ(−2 ~ +2)"**로 바꾸고, 같이 열려 있는 구멍 셋(보스 드랍이 아레나 땅에 남는다 · 변환권을 스테이지 1 값에 산다 · 디버그 진입점 전수 미확인)을 닫는다.

## 1. 먼저 읽을 것

- PRD: **0장** · **20.72 [2-0] ~ [2-7] · [5] · [6]**(임의 결정 13 ~ 17) · **20.73 [8]** · **20.81 [A](1) · [C-1] · [C-2]**
- 코드(전부 끝까지 읽는다): `shared/Loot.lua` · `shared/data/MonsterData.lua`(`itemLevelBonus` · `fairnessCheck` · `dropGradeTableByTier`) · `shared/data/ArmorData.lua` · `server/CombatResolution.lua`(`grantKillReward` · `handleBossDeath` 전체) ·
  `server/TutorialState.lua`(`onBossCleared`) · `server/ItemDropServer.server.lua`(`tryPickup`) · `server/ItemDropSpawner.lua` · `server/GemServer.server.lua`(`rerollTicketPrice`) · `server/PlayerProfile.lua`(`addArmorDrop` · `getInfiniteStage` · `infiniteBest`를 읽는 함수들) ·
  `server/BossEncounter.lua`(처치 뒤 멤버를 사냥터로 돌려보내는 경로 - `clearForModel` 부근) · `server/DevTools.server.lua`(첫 30줄의 가드 · `/gg killtest` · `/gg bosskilltest` · 명령 등록부 1970 ~ 2030줄 부근 · 자동 검증 블록의 모양)
- `grep -rn "rollArmorDrop\|rollBossFirstClearDrop\|rollSparkleArmorDrop\|buildFixedArmorDrop\|itemLevelBonus" roblox/src`로 호출부를 전부 찾는다.

## 2. 단계

### 단계 1 — 드랍 규칙 데이터

`shared/data/ArmorData.lua`에 추가(값은 PRD 20.72 [2-1] · [2-2] 그대로):

```lua
-- 28-1 [2-1]: 드랍 itemLevel = max(1, S + δ). 삼각 분포 1:2:3:2:1
itemLevelDelta = { { delta = -2, weight = 1 }, { delta = -1, weight = 2 }, { delta = 0, weight = 3 }, { delta = 1, weight = 2 }, { delta = 2, weight = 1 } },
-- 28-1 [2-2]: 보스 드랍은 −가 없다. 3:2:1
bossItemLevelDelta = { { delta = 0, weight = 3 }, { delta = 1, weight = 2 }, { delta = 2, weight = 1 } },
```

`MonsterData`의 tier 필드 `itemLevelBonus`는 **값(r^(p−1))은 그대로 두고 이름을 `dropCountMultiplier`로** 바꾼다(뜻이 "itemLevel에 곱한다"에서 "기대 드랍 개수에 곱한다"로 바뀐다). `fairnessCheck`의 식도 같은 이름으로 - 수치는 그대로여야 한다(tier1 ~ 6의 `rewardPerTime`이 바뀌기 전과 같은지 로그로 확인).

### 단계 2 — `Loot`

| 함수 | 바꾸는 것 |
|---|---|
| `Loot.rollItemLevel(stage, deltaTable)` (신규) | 가중치 표에서 δ를 뽑아 `math.max(1, stage + δ)` |
| `Loot.rollCount(expected)` (신규 · 공용) | `floor(expected)`개 확정 + 소수부 확률로 1개 더. **S04의 강화석이 같은 함수를 쓴다** |
| `Loot.expectedArmorDropCount(tierIndex, rewardMultiplier)` (신규) | `ArmorData.dropChance × tier.dropCountMultiplier × (rewardMultiplier or 1)`. 기존의 "확률에 보상 배율을 곱하고 1에서 자른다"(`math.min(…, 1)`)를 **대체**한다 - 1을 넘으면 여러 개가 나온다 |
| `Loot.rollArmorDrop(stage, tierIndex, rewardMultiplier, classId)` | **인자에서 캐릭터 레벨을 뺀다.** 반환 = 아이템 **배열**(0개 이상). 개수 = `rollCount(expectedArmorDropCount(...))`, 아이템마다 등급(`dropGradeTableByTier[tierIndex]`) · 부위 · 옵션 · `itemLevel = rollItemLevel(stage, itemLevelDelta)`를 독립으로 굴린다. **tier 곱셈 삭제** |
| `Loot.rollBossFirstClearDrop(bossStage, rebirthCount, classId)` | 캐릭터 레벨 인자 삭제. `itemLevel = rollItemLevel(bossStage, bossItemLevelDelta)`. 등급표 분기는 그대로 |
| `Loot.rollBossRetryDrop(bossStage, classId)` (신규) | **확정 1개**(확률 굴림 없음) · 등급 = `dropGradeTableByTier[1]` · `itemLevel = rollItemLevel(bossStage, bossItemLevelDelta)` · `tierIndex = 1` |
| `Loot.rollSparkleArmorDrop(stage, tierIndex, classId)` | 캐릭터 레벨 인자 삭제. `itemLevel = rollItemLevel(stage, itemLevelDelta)` |
| `Loot.buildFixedArmorDrop(grade, part, stage, tierIndex, classId)` | 캐릭터 레벨 인자 삭제. **`itemLevel = stage`(δ = 0 고정)** |

`dropStage` 필드 · 판매가 식 · 옵션 굴림 · 등급표는 **한 글자도 안 바꾼다.** 파일 위쪽의 옛 설명 주석(`itemLevel = 획득 시점 캐릭터 레벨` …)은 새 규칙으로 고쳐 쓴다.

### 단계 3 — 호출부

- `CombatResolution.grantKillReward`: 기준 스테이지 S는 **이미 있는 `dropStage` 변수**다(보스 = `monsterData.stageNumber`, 그 밖 = `recipientStage` = 받는 사람 자신의 스테이지 - 20.72 [2-4]). 세 호출에서 `newLevel or oldLevel` 인자를 빼고, 잡몹은 돌려받은 **배열의 아이템마다** 스폰한다.
  보스 재도전 분기는 `rollArmorDrop` → `rollBossRetryDrop`.
- `TutorialState.onBossCleared`: `buildFixedArmorDrop(grade, part, TutorialData.monsterStage, stepData.tierIndex, classId)`.
- 그 밖의 호출부(`DevTools` 포함)를 grep으로 전부 맞춘다.

### 단계 4 — 보스 드랍 가방 직행 (20.81 [C-1])

- 대상: **무한 모드 보스의 장비 보상**(첫 클리어 · 재도전). 잡몹 · 반짝이 · 견습 보스는 지금처럼 땅.
- `grantKillReward`의 보스 분기: `PlayerProfile.addArmorDrop(recipient, item)` →
  - 성공: 줍기와 **같은** `ItemPickedUp` RemoteEvent를 같은 payload로 쏜다(`ItemDropServer`가 만든 인스턴스를 `ReplicatedStorage`에서 찾아 쓴다 - 새 이벤트를 만들지 않는다).
  - 실패(가방 가득): **그 사람이 사냥터로 돌아간 뒤** 그 발밑에 `ItemDropSpawner.spawn` + `InventorySync.notifyFull`. 아레나에 떨어뜨리지 않는다. 복귀 텔레포트가 어느 함수에서 언제 일어나는지 `BossEncounter`에서 읽고, 그 뒤에 스폰되도록 순서를 맞춘다
    (예: 보류 목록에 담아 두고 복귀 직후 스폰). 복귀 경로가 여러 개면(처치 · 파티) 전부 지난다.
- 드랍 로그(`[forge-game] 드랍: …`)는 유지하고 끝에 `→ 가방` / `→ 땅(가방 가득)`을 붙인다.

### 단계 5 — 변환권 가격 = 계정 최고 스테이지 (20.73 [8] 3번)

- `PlayerProfile.getAccountBestStage(player)` 신규: **전 직업 `infiniteBest`의 최댓값**(최소 1). 직업별 상태를 어떻게 도는지는 `PlayerProfile`의 기존 코드(직업별 `classState`)를 따른다.
- `GemServer.rerollTicketPrice`: `getInfiniteStage` → `getAccountBestStage`. 배수 `GemData.rerollTicketGoldMultiplier`는 그대로.
- 클라가 가격을 미리 보여 주는 곳이 있으면(grep `rerollTicket`) 같은 기준으로 맞춘다 - 서버가 값을 내려 주는 구조면 서버만 고치면 된다.

### 단계 6 — /gg 프로덕션 차단 감사 (20.81 [C-2])

코드를 고치는 단계가 아니라 **표를 만드는 단계**다. 20.81 [C-2]의 1 ~ 6을 그대로 한다.

- 나열할 것: `Chatted` · `TextChatCommand` · `"/gg` · `debug`로 시작하는 공개 함수 · `*Verify.lua`의 공개 함수 · 저장 차단 해제 도구 · `DevToolsConfig`를 읽는 곳.
- 진입점마다: 정의된 곳 · **부르는 곳 전부** · 부르는 곳이 `DevTools.server.lua`(첫머리 `IsStudio` 가드 뒤)뿐인가 → O / X.
- `*Verify.lua` 모듈 최상위에 부작용(`task.spawn` · 이벤트 연결 · 인스턴스 생성)이 있는가.
- 클라가 쏠 수 있는 RemoteEvent 중 디버그 전용 핸들러가 DevTools 밖에 있는가.
- **X가 나온 곳만** 그 서버 함수의 첫 줄에 `if not RunService:IsStudio() then return end`를 넣는다. 구조는 바꾸지 않는다.
- 결과 표를 PRD 기록에 넣는다(진입점 · 정의 · 호출자 · 판정 · 조치).

## 3. 자동 검증 블록 — `server/LootRuleVerify.lua`(신규) + DevTools가 부른다

**(가) 순수 함수**(서버 시작 때)

| # | 검사 | 기대 |
|---|---|---|
| 1 | `rollItemLevel(100, itemLevelDelta)` 90,000회 | δ 분포 11.1 / 22.2 / 33.3 / 22.2 / 11.1% (각 ±1%p) · 최소 98 · 최대 102 |
| 2 | `rollItemLevel(1, …)` | 1 미만 없음 |
| 3 | 보스 δ 60,000회 | 50 / 33.3 / 16.7% (±1%p) · **음수 0건** |
| 4 | tier1 ~ 6 기대 드랍 수(`rewardMultiplier = 1`) | 0.25 / 0.31 / 0.40 / 0.57 / 0.79 / 1.05 (±0.01) |
| 5 | tier6 · 보상 배율 3 → `rollArmorDrop` 20,000회의 평균 개수 | 3.15 ± 0.05 · 한 번에 3개 또는 4개만 |
| 6 | **tier6 · 스테이지 100 → 나온 아이템 전부의 itemLevel** | **98 ~ 102 (420 같은 값 0건)** |
| 7 | `rollBossRetryDrop` 1,000회 | 전부 1개 · 등급은 tier1 표에 있는 것만 · itemLevel ≥ 보스 스테이지 |
| 8 | `buildFixedArmorDrop` | itemLevel = 넘긴 stage |
| 9 | `fairnessCheck` tier1 ~ 6 `rewardPerTime` | 전부 같은 값(이름만 바뀌었다) |

**(나) 실제 경로**(플레이어 접속 뒤 · 보스 검증 체인의 끝)

| # | 검사 | 기대 |
|---|---|---|
| 10 | 실제 Player의 프로필을 레벨 100 · 스테이지 40으로 두고 tier6 잡몹을 실제 처치 경로(`/gg killtest`가 쓰는 함수)로 30회 | 드랍된 아이템의 itemLevel 전부 **38 ~ 42**(레벨 100이 아니라 스테이지 40을 따른다) |
| 11 | 보스 실제 처치 경로(`bosskilltest`가 쓰는 함수) - 가방에 빈칸 있음 | 장비가 **가방에 바로** 들어온다 · 땅에 드랍 모델 0 · `ItemPickedUp` 발신 1회 |
| 12 | 같은 것 - 가방 가득 | 아레나에 드랍 모델 0 · **복귀한 자리 근처(10stud 안)에 드랍 모델 1** · 가득 알림 1회 |
| 13 | `getAccountBestStage`: 직업 A `infiniteBest` 80 · 직업 B 10 · 지금 스테이지 1 | 80 · 변환권 가격 = 스테이지 80 기준 |
| 14 | 검증이 바꾼 프로필 값 · 가방 · 보스를 전부 되돌렸다 | 고아 보스 모델 0 · 프로필 복원 확인 로그 |

Attribute는 실제 Player에만 쓰인다 - 10 ~ 13은 실제 Player로 한다. 강제로 시작한 것은 한 틱 뒤에 읽는다.

## 4. 합격 기준

| # | 항목 |
|---|---|
| 1 | (가) 9/9 · (나) 5/5 |
| 2 | 기존 검증 회귀 없음: 26-2 41/41 · 26-3 6/6 · 27-1 · 27-3 · 27-4 · 29-2 (가)(나) · 29-3 · 29-4 · 29-5 전부 이전과 같은 수 |
| 3 | 공정성 로그 tier1 ~ 6 동일 |
| 4 | /gg 감사 표에 X 0건(조치 뒤) |
| 5 | 서버 에러 · 경고 0(읽은 구간) |
| 6 | `SAVE_VERSION` 불변 |

**진짜 합격 기준**: ① **(가) 6번 + (나) 10번** - tier6에서도 itemLevel이 기준 스테이지 ±2를 벗어나지 않는다. ② **(나) 11 · 12번** - 보스 드랍이 어떤 경우에도 아레나에 남지 않는다.

## 5. 하지 않는 것

- 세이브에 이미 있는 부풀려진 아이템을 깎지 않는다(S02).
- 강화 · 강화석 · 방지권(S03 ~ S05). `getAccountBestStage`만 여기서 만든다.
- 드랍률 · 등급표 · 판매가 · 옵션 굴림을 건드리지 않는다.
- 착용 제한을 넣지 않는다(20.72 [2-3] - 없음이 결정이다).

---

<!-- COMMON:BEGIN - 이 아래는 COMMON.md의 사본이다. 직접 고치지 말고 _build.py를 돌린다 -->

## 공통 규칙 — 모든 Sonnet 세션에 똑같이 적용된다

### 0. 이 세션의 성격

- 너는 **구현자**다. 설계 판단은 Fable 세션(PRD 20.81)이 끝냈다. 이 파일에 적힌 단계를 그대로 실행한다.
- **판단에 막히면 정하지 말고 멈춘다.** 값 · 규칙 · 범위 중 이 파일과 PRD에 답이 없는 것을 만나면:
  1. 그 단계에서 작업을 멈춘다(그 앞 단계까지는 커밋한다).
  2. PRD의 이번 세션 절 "미결"에 **`미결: (무엇을 정해야 하는가), 왜: (어디서 막혔고 어떤 선택지가 보이는가)`** 형식으로 남긴다.
  3. `docs/sonnet/README.md`의 그 세션 줄 "미결" 칸에 한 줄 적고, 사용자에게 보고한다.
  - "적당한 값"을 골라 계속 가지 않는다. 검증이 실패했을 때 **수치를 만져서 통과시키지 않는다** - 실패 로그와 함께 멈춘다.
  - 이 파일의 지시와 실제 코드가 다르면(함수 이름 · 인자 · 파일 위치) **코드가 맞다.** 이름을 맞춰 진행하되 다른 점을 PRD 기록에 적는다. 구조가 달라 지시를 그대로 못 따르면 위 1 ~ 3.
- 사용자에게 주는 모든 설명 · 보고 · 표는 **한국어**. 코드 식별자 · 경로 · 커밋 메시지 · 로그는 원문 그대로.
- 범위 밖의 것을 고치지 않는다. 눈에 띈 문제는 PRD 기록의 "보고"에 적는다.

### 1. 수정 경로

- 코드는 **`roblox/src/` 아래 파일로만** 고친다. Rojo가 Studio에 반영한다.
- **Studio MCP의 스크립트 편집 · 인스턴스 직접 편집 금지.** MCP는 읽기 · 실행 · 검증 전용이다(Play 시작/정지 · 콘솔 읽기 · 화면 캡처 · 데이터 모델 탐색).
- 고치기 전에 **관련 함수 전체와 그 함수를 부르는 곳을 읽는다.** 일부만 읽고 고치지 않는다.
- 밸런스 수치는 `shared/data/` 안에만. `server/` · `client/`에 숫자를 박지 않는다. 스킬 · 보스 패턴은 데이터의 조각(effects · 플래그) 조합으로 정의한다 - 스킬 · 보스 이름이 들어간 함수를 새로 만들지 않는다.
- 저장 구조를 바꾸면 `SAVE_VERSION`을 올리고 `migrate()`에 처리를 추가한다. 한 세션에 저장 필드가 여러 번 생기면 단계마다 하나씩 올린다.
- **새 저장 필드는 `snapshotForDevTools` 백업 대상에 반드시 넣는다**(영구 규칙 - S20e에서 hints 필드가 이 백업 대상이 아니어서, 수동 Play 종료 때 DevTools 백업 복원이 그 필드만 빼놓고 되돌려 개발 계정 실제 프로필에 플래그가 남았다).
- **수치 계산 결과는 sanitize 출구를 거친다**(영구 규칙 - S21-0 A2, `shared/Sanitize.lua`. 플레이어 스탯 합산·피해 계산·보상 계산처럼 값을 확정하는 마지막 자리에서 `Sanitize.number(value, fallback)`를 거쳐 NaN·inf 오염을 그 자리에서 끊는다 - `math.max(NaN, 0)`은 NaN을 그대로 돌려줘 한 번 섞이면 이후 모든 연산이 계속 NaN으로 남는다).
- **성장률(k)에 기대는 값은 "힘 비율"로 데이터에 둔다**(영구 규칙 - P2.5a에서 k를 1.155 → 1.02로 바꾸자, k에서 유도되던 보스 파티 HP 지수 · 파훼 게이트와 스테이지 번호로 박힌 임계값(재료 해금 50 · 75 · 방지권 · 보스 밀도)이 뜻을 잃었다). "몬스터가 ×몇 배 세지는 지점 · 폭"을 뜻하는 값은 스테이지 수가 아니라 배율(예: `1.155 ^ 49`)로 적고, 스테이지는 `InfiniteStage.stagesForPowerRatio(배율)`로 그 자리에서 계산한다 - k가 바뀌어도 같은 힘 지점을 가리킨다. 스테이지 번호 자체가 뜻인 값(보스 간격 5 · UI 묶음 10 · 견습 스테이지)은 그대로 둔다.
- **새 파티클 · 새 에셋 · 새 색 금지.** 기존 자산 · 로블록스 기본 인스턴스 · `UIColors`만 쓴다.
- 연출 요청은 **판정을 건드리지 않고 겉모습만 바꾸는 쪽부터** 한다(29-3 원칙).
- 그리기(클라 연출)와 판정(서버)을 섞지 않는다. 서버가 판정하고 클라는 그린다.

### 2. 클라 UI

- 새 UI는 PRD 20.81 [D]의 틀을 따른다: 부품은 `client/ui/kit/`, 자리는 `ScreenMap`, 창은 `UIManager`에 등록. (S06 전의 세션은 기존 방식대로 두되 새 파일로 분리한다.)
- **파일 하나에 몰지 않는다.** 최상위 `local` 120개 이하 · 파일 800줄 이하. 인스턴스는 `build()` 함수 안에서 만들고 참조는 `refs` 표 하나로 돌려준다(Luau 레지스터 200 한계).
- **`AutomaticSize`를 중첩하지 않는다.** 고정 크기를 기본으로 한다.
- **글씨 크기는 `TextSize` × 조상 `UIScale` 누적 배율(= 실제 화면 px)로 판정하고, 12 미만은 금지한다**(영구 규칙 - S12b에서 장비창이 명목 `TextSize` 12인데 `UIScale`로 줄어 화면에서는 9px대였다. 명목 숫자만 보는 점검은 이걸 통과시켰다). 계산은 `Theme.effectiveTextSize(inst)`, 목록은 `ui/TextAudit.lua`(`report`) - 창 · 글씨 자체 점검(`SocialSelfCheck` · `RuleCheck` ⑮)과 `PanelFitCheck`의 `[S12][UI][글씨]` 줄이 모두 이 잣대를 쓴다. 새 창은 `UIScale`로 통째로 줄이지 말고 폰 크기에서도 실효 12 이상이 되게 짓는다. 모바일 터치 타깃 44 × 44 이상. hover에 기대는 조작 금지.
- **새 툴팁 · overlay · `ProximityPrompt` 주변 UI는 자체 점검과 별개로 스크린샷을 1회 찍어 글씨가 실제로 보이는지 확인한다**(영구 규칙 - S12b에서 툴팁 글씨가 배경 뒤로 숨는 `ZIndex` 문제가 자체 점검을 전부 통과했다. `ZIndex` 가림은 점검이 못 잡는다). 스크린샷은 자동 검증 뒤의 별도 Play(§5-7)에서 찍는다.
- **새 버튼 · 토글 HUD는 자체 점검과 별개로, 다른 창이 열린 상태에서 실제 클릭 1회로 입력이 막히지 않는지 확인한다**(영구 규칙 - S16에서 메뉴바 자체 점검이 전부 통과했는데 실제 클릭에서 창 딤이 버튼을 덮어 열린 버튼이 안 닫혔다. 자체 점검은 `UIManager`를 직접 불러 입력 층 결함(`DisplayOrder` · 딤)을 못 잡는다). 스크린샷 Play(§5-7)에서 window를 연 채 그 버튼을 `user_mouse_input`으로 눌러 동작하는지 본다(창 `Visible` 변화 · 버튼 `Activated`를 클라 `execute_luau`로 Attribute에 기록해 두고 클릭 뒤에 읽는다). 확인창(overlay)의 딤이 버튼을 덮는 것은 정상이다 - 그 상태는 버튼이 회색인지만 본다.
- **패널은 화면보다 클 수 없다**(영구 규칙 - S11에서 폰 가로 844 × 388에 396 고정 패널이 위 3px · 아래 5px 잘렸다). window · station 패널은 `UIManager`가 열 때 높이를 (화면 높이 − `UIManager.safeMargin` × 2) 이하로 제한하고 위 · 아래 끝을 화면 안으로 민다(`UIManager.fitToScreen` - 등록하지 않고 자기 ScreenGui를 쓰는 패널은 이 함수를 직접 부른다). 넘치는 내용은 **패널 안 `ScrollingFrame`이 스크롤로 받는다** - 제목줄 · 하단 고정 줄(상태줄 · 버튼)은 스크롤 밖에 두고, 본문만 스크롤 안에 넣는다(강화 패널 · 스테이지 선택 패널이 그 구조다). 스크롤 안의 자리는 offset으로 준다(`ScrollingFrame` 자식의 Scale은 캔버스 기준이라 안 쓴다). 새 패널을 만들 때 **모바일 기준 해상도**에서 열어 화면 밖으로 나가는 프레임이 0개인지 확인한다(자체 점검 `ui/PanelFitCheck.client.lua`의 `[S12][UI]` 줄 - 강화 패널처럼 근접해야 지어지는 패널은 그 자리에서 같은 잣대로 잰다).
- **모바일 기준 해상도(영구 규칙 - S20 사전 작업 3): 최소 800 × 360(상단 인셋 `GetGuiInset` 58 반영 → ScreenGui 800 × 302), 너비 최소 667(667 × 375 → ScreenGui 667 × 317).** 새 HUD · 배너 · 창은 이 크기에서 화면 밖 0 · 겹침 없음 · 터치 타깃 44 이상이어야 한다. 842 × 388(→ 842 × 330) · 1024 × 768(→ 1024 × 710)은 참고 해상도로 같이 본다. Studio는 Device Emulator의 사용자 지정 기기를 MCP로 못 만들므로 **순수 함수의 계산값**(예: `RequestBanner.placementFor` · `UIManager.fitToScreen`의 식)을 자체 점검이 800 × 360 · 667 × 375 · 842 × 388 · 1024 × 768로 불러 확인하고, 사용자가 Emulator에 기기를 만들어 주면 `[S06][UI]` · `[S12][UI]` 줄로 실측한다.
- **창의 폰 / PC 판정과 배율(영구 규칙 - S20b): 판정은 화면 크기 기준이다(터치 여부가 아니다 - Studio에서 PC 창을 줄여도 같은 결과). ScreenGui 폭 < 720 또는 높이 < 400이면 폰(1단 · 상단 탭 · 하단 시트), 아니면 PC(2단).** 경계값은 `panels/Inventory/Layout.lua`(`phoneWidthBelow` = 720 · `phoneHeightBelow` = 400) 한 곳이고 새 창이 폰 배치를 가질 때도 같은 값을 쓴다(800 × 360 · 667 × 375 · 842 × 388은 높이 400 미만이라 폰, 1024 × 768 · 1321 × 484 창은 PC). **캔버스 전체를 `UIScale`로 줄이지 않는다** - 배율은 항상 1이라 폰에서도 `UIScale`이 1 아래로 내려가지 않는다(열림 트윈에도 `UIScale`을 쓰지 않는다). 좁으면 배치를 바꾸고 넘치는 본문은 `ScrollingFrame`이 받는다. 폰 배치는 PC 창에서도 **가상 화면을 강제해 실제 인스턴스로 잰다**(`R.debugForceScreen` - 창 · 프레임 크기가 전부 배치 계산에서 나오므로 실제 폰과 같은 크기 · 자리가 된다. 예: `panels/Inventory/InventoryLayoutCheck`).
- **단축키는 자동 입력 테스트만으로 통과 처리하지 않는다 - 사용자 실제 키보드 확인 1회 필수**(영구 규칙 - S19 · S20 사전 작업: MCP `user_keyboard_input`이 I 키를 열었는데 실제 키보드의 I는 안 열렸다. 로블록스 기본 카메라 줌 키 I · O는 수정자 없이 누르면 KeyDown이 `UserInputService` · `ContextActionService`에 도달하지 않는다 - 가상 입력은 그 층을 건너뛴다). 새 단축키를 등록하면 PRD "사람이 확인할 것"에 "영문 · 한글 상태 모두 실제 키보드로 열리고 닫히는가"를 넣고 사용자가 확인하기 전에는 `[x]`로 닫지 않는다. `PanelRegistry.swallowedKeys`(I · O)와 `forbiddenKeys`는 등록 시 error다. 안 열리는 키를 조사할 때는 `DevToolsConfig.inputDiag = true`로 `[InputDiag]` 로거(모든 입력 · 원시 키 상태 · CAS 도달)를 켠다.
- **새로 쓰는 · 고치는 플레이어용 문장은 번역 가능한 형식으로 쓴다**(영구 규칙 - G1-1, 번역 결정 7 나): 원문은 `shared/data/TextData.lua`에 키 하나 = 한 문장 전체 템플릿으로 두고 `shared/Text.get(key, { 이름 = 값 })`로 읽는다. ① 문장 조각을 `..`로 이어붙이지 않는다(조사 · 어순이 언어마다 다르다) ② 인자는 순서(`%s`)가 아니라 이름(`{count}`)으로 ③ 숫자 형식은 호출하는 쪽이 문자열로 만들어 넘긴다 ④ 서버가 클라에 보내는 문장은 완성 문장이 아니라 키 + 인자로 보낸다 ⑤ 이미지 속 글자 금지. 옛 문장은 L(번역) 단계에서 옮긴다 - 그 전이라도 손대는 문장은 옮긴다.
- **새 UI를 놓기 전에 표에 없는 기존 HUD가 있는지 먼저 확인한다**(영구 규칙 - S10에서 가방 버튼 · 직업 변경 버튼 · 가득 참 토스트 · 보스 잡힘 패널이 표에 없어 겹침 검사가 못 보고, 그 위에 피드를 놓았다가 가방 버튼과 겹쳤다). 순서: ① Play에서 PlayerGui의 ScreenGui(DisplayOrder 10 미만)를 훑어 직계 GuiObject 이름을 뽑고(또는 접속 8초 뒤 `[S06][UI][미등록]` 줄을 읽는다) ② `ScreenMap` 슬롯 표에 없는 것은 **먼저 표에 등록**(이름이 기본값 `Frame` · `TextLabel`이면 이름부터 붙인다) ③ 그다음에 새 자리를 정한다. 창(window · station · overlay) · 월드에 붙는 BillboardGui · 로블록스 CoreGui는 표에 안 넣는다(사유는 `ScreenMap.lua` 머리 주석). 새 HUD가 어떤 피드 · 토스트 아래에 놓일 때는 그 슬롯에 `blocksDropFeed` 표시를 한다.

### 3. 검증

- **자동 검증 블록은 서버 스크립트 안에 둔다**(`server/<이름>Verify.lua` 모듈 + `DevTools.server.lua`가 부른다, 또는 `DevTools` 안의 `if RunService:IsStudio() then task.spawn(...)` 블록). 기존 블록(26-2 · 27-1 · 29-x)과 같은 모양:
  `===<세션> 검증 시작(가)===` … 항목마다 `[<세션>][가] … O/X` … `===<세션> 검증 끝(가)=== n/m 통과`.
  - **(가)** = 순수 함수 · 합성 데이터(플레이어 없이 서버 시작 때 돈다).
  - **(나)** = 실제 Player와 실제 경로가 필요한 것(플레이어 접속 뒤). 보스 아레나 · 보스 스폰을 쓰는 (나)는 **기존 보스 검증 체인의 끝에** 붙인다(동시에 돌면 서로의 서버 상태를 오염시킨다). 검증이 만든 것(보스 · 더미 · 프로필 값)은 **검증이 끝날 때 전부 되돌린다** - "검증 뒤 encounter 없는 보스 모델 0"을 마지막 항목으로 찍는다.
- **검증 실행 스위치(영구 규칙).** 서버 시작 때 과거 세션의 검증 블록(보스 패턴 · 강화 등)이 전부 다시 돌면 Play 한 번이 4분 가까이 걸린다(S05 실측 3분 55초). 그래서 블록마다 id(`"S06(가)"` · `"S06(나)"` 꼴 - 기존 블록은 `"29-3(나)"` · `"S05(가)"`)를 주고 `DevTools.server.lua`의 `verifyEnabled(id)`로 감싼다:
  - 새 (가) 블록: `if RunService:IsStudio() and verifyEnabled("<id>") then …`. 새 (나)는 29-1 체인의 단계 표(`{ "<id>", function() … end }`)에 id와 함께 넣는다 - 체인이 단계마다 `verifyEnabled`로 거른다.
  - **세션을 시작할 때** `shared/data/DevToolsConfig.lua`의 `verify.current`를 **이 세션의 블록 id들 + 아래 "동반 실행"으로 고른 옛 블록 id들**로 갈아 끼운다(그 밖의 옛 id는 지운다). 기본값 `verify.regression = false` - 이때는 `current`에 적힌 블록만 돈다.
  - **모든 Play는 `regression = false`로 돈다(영구 규칙).** 세션 마지막에 회귀 전체를 돌리지 않는다. 회귀 전체(`regression = true`)는 **마일스톤에서만** 켠다: **S10 · S15 · S21 종료 시 · Fable 세션으로 넘어가기 전 · 퍼블리시 전**(README 순서표의 "회귀 전체" 표시 줄 + 사용자가 그 시점의 지시에 적은 경우). 마일스톤이 아닌 세션에서 켜야 할 것 같으면 켜지 말고 §0으로 멈춘다. 마일스톤에서 켰다면 그 세션의 **마지막 자동 검증 Play 1회에서만** 켜고, 끝나면 **바로 `false`로 되돌려 커밋한다**(켜 둔 채로 끝내면 다음 세션의 첫 Play가 4분 걸린다).
  - **동반 실행(영구 규칙).** 이 세션이 **고친 모듈을 쓰는 옛 검증 블록**은 현재 세션 블록과 함께 돌린다 - "회귀 전체 없이 회귀를 잡는" 장치다. 예: 강화 코드(`Enhance` · `EnhanceConfig` · `EnhanceMaterialData` · 강화 Remote)를 고쳤으면 S03 강화 블록(`S03(가)` · `S03(나)`)도, 저장 구조를 고쳤으면 저장 이관 블록도. 고르는 법: 이 세션이 바꾼 파일(모듈) 이름을 `server/*Verify.lua` · `DevTools.server.lua`의 검증 블록이 `require`하거나 부르는지 `grep`으로 찾아 그 블록 id를 `current`에 넣는다. 어느 블록이 쓰는지 grep으로 가려지지 않으면 **넓은 쪽으로 포함한다**(시간이 늘 뿐 틀리지 않는다). **어떤 옛 블록을 같이 돌렸는지와 그 이유를 PRD 기록과 마지막 보고에 적는다.** 세션 본문의 합격 기준에 나오는 "회귀 없음"은 "동반 실행한 옛 블록이 이전과 같거나 더 좋다"로 읽는다(회귀 전체가 아니다).
  - 콘솔 첫머리의 `[DevTools] 자동 검증 모드: …` 줄로 이번 Play의 모드와 실제로 돈 블록을 확인한다.
  - **검증 필터(G1-0 - 상설).** 특정 블록만 돌릴 때 `DevToolsConfig.lua`를 임시로 고치지 않는다. `VerifyArmedUntil`을 켤 때 같이 edit 모드에서 `ReplicatedStorage:SetAttribute("VerifyOnly", "P3dF(나), 29-1")`(쉼표 구분)을 주면 그 목록만 돈다(`regression` 무시). Play 뒤 `VerifyArmedUntil`과 함께 `nil`로 끈다.
  - **수동 Play 모드(영구 규칙 - S19b).** 자동 검증은 **기본 꺼짐**이다: 사용자가 Studio에서 그냥 Play를 누르면 검증 블록 · `UiSelfCheck` · 서버 시작 검증 줄이 하나도 안 돈다(`DevToolsConfig`가 `verify.current`를 빈 표로 읽는다). 터미널이 검증할 때만 **Play 직전 edit 모드에서** 켠다: `execute_luau`(Edit) `game:GetService("ReplicatedStorage"):SetAttribute("VerifyArmedUntil", os.time() + 1800)` → Play → 정지 → **바로 끈다**(`SetAttribute("VerifyArmedUntil", nil)`. 잊어도 30분 뒤 저절로 꺼진다). Attribute는 Rojo project에 없어 동기화가 덮어쓰지 않는다(S19b 실측). 켜져 있는 동안 저장은 **검증용 이름**으로 분리된다: 개발 계정 프로필 = `Player_<id>_verify`(첫 읽기 때 비우고 실제 프로필로 시드 · 실제 키는 읽기만), 파티 MemoryStore · 메시징 = `ForgeParty_v1_verify` · `ForgePartyMember_v1_verify` - 검증 도중 Play가 멈춰도 실제 프로필 · 라이브 파티 레코드가 안 바뀐다(견습 오염 사고의 근본 해결). 스크린샷 · 수동 확인 Play는 **켜지 않은 채** 돈다. **새 저장소(DataStore · MemoryStore · MessagingService)를 쓰는 코드를 만들면 같은 `verifyArmed` 분기로 `_verify` 이름을 붙인다.**
- **`execute_luau`로 `shared` 모듈을 `require`하지 않는다**(Capabilities 제약으로 막혀 있다). 검증은 위의 서버 블록으로만.
- **검증 스탠드인의 교훈**(29-4 · 29-5의 X가 전부 여기서 나왔다):
  1. **Attribute는 실제 Player에만 쓰인다.** 스탠드인(더미 · 표)의 상태를 Attribute로 읽지 않는다 - 서버 모듈의 상태 함수로 읽는다. 피해를 받는 스탠드인에는 필요한 스텁이 있는지 먼저 본다.
  2. **스킬을 강제로 시작한 그 틱에는 추적이 돌지 않는다 - 다음 틱부터 돈다.** 강제 시작 직후의 값을 읽지 말고 한 틱 이상 기다린 뒤 읽는다. 만료 시각도 같다(한 틱 일찍 읽으면 X).
- X가 나오면 먼저 **검증 쪽의 원인인지 제품 쪽의 원인인지**를 로그로 가른다. 그럴듯한 설명에서 멈추지 말고 실제 인스턴스 · 실제 코드를 한 번 훑는다(CLAUDE.md).

### 4. 로컬 검사 (Play 전)

- 바뀐 · 새 Luau 파일 전부를 `luau-compile`(스크래치패드의 luau CLI)로 구문 · 레지스터 검사한다. 순수 모듈은 스텁 하네스로 돌려 본다. 긴 python은 히어독이 아니라 파일로 만들어 실행한다.
- `git diff --stat`으로 의도한 파일만 바뀌었는지 본다.

### 5. Play 절차 (사용자를 부르지 않는다)

1. **Play 전에 커밋한다**(검증이 서버 상태를 바꾼다 - 돌아갈 지점을 만든다). 자동 검증 Play면 **edit 모드에서 수동 Play 모드를 켠다**(§3 - `VerifyArmedUntil`).
2. MCP `start_stop_play`로 Play를 시작한다.
3. **검증이 끝날 때까지 기다린다. 그동안 MCP 도구를 하나도 부르지 않는다**(콘솔 읽기 · 화면 캡처 · execute_luau 전부 금지 - Play 중 호출이 검증을 흔든다). 대기는 백그라운드로 Studio 로그 파일(`%LOCALAPPDATA%\Roblox\logs\*Studio*_last.log`)을 폴링해 이번 Play의 마지막 `검증 끝` 줄이 나오면 멈춘다(고정 9분 대기 금지). 걸리는 시간: 현재 세션 블록 + 동반 옛 블록이 돌 때 1분 안팎(동반 블록이 무거우면 더) · **회귀 전체(`regression = true`, 마일스톤 Play만)는 약 4분**. 상한은 회귀 전체 6분 · 그 외 3분.
4. MCP로 Play를 **정지**한다. 자동 검증 Play였다면 **수동 Play 모드를 끈다**(§3).
5. 콘솔을 읽는다: `===… 검증 끝…===` 줄 전부 · 이번 세션의 `[세션]` 줄 · 에러 · 경고. 콘솔 앞부분이 길이 제한으로 잘리면 "읽은 구간"을 보고에 적는다.
6. X가 있으면 고치고(§3) → 커밋 → 2번부터 다시. **Play는 세션당 최대 3회.** 3회째에도 X가 남으면 멈추고 보고한다. **모든 Play는 현재 세션 블록 + 동반 옛 블록만 돌린다**(`regression = false` - 마일스톤 세션의 마지막 자동 검증 Play 1회만 예외, §3).
7. UI 세션의 스크린샷은 자동 검증이 끝난 뒤의 **별도 Play**에서 찍는다(그 Play에서는 MCP를 써도 된다 - 자동 검증 결과를 그 Play에서 읽지 않는다).
- "재미있어 보이는가 · 읽히는가" 같은 체감 판단은 하지 않는다. "사람이 확인할 것" 표로 PRD에 남긴다.

### 6. 끝내기

1. **합격 기준 표**를 채운다(항목 · 결과 O/X · 근거 로그 한 줄). "진짜 합격 기준"이 O가 아니면 이 세션은 끝난 것이 아니다. **`DevToolsConfig.verify.regression`이 `false`인지** 확인한다(마일스톤 세션에서 `true`로 돌렸다면 `false`로 되돌린 커밋이 들어 있어야 한다). `verify.current`에는 이 세션이 돌린 블록 id가 그대로 남겨 둔다(다음 세션이 시작할 때 갈아 끼운다).
2. **PRD 기록**: `PRD-forge-game-roblox.md` 끝에 새 절 `### 20.NN <세션 번호> <제목>`(번호 = 마지막 절 + 1). 내용 = 무엇을 했나 · 구조/변경 파일 · 검증(로컬 · Play 회차별) · 합격 기준 표 · 사람이 확인할 것 · 미결 · 임의 결정(지시에 없어서 스스로 정한 것이 있으면 전부). 이 세션이 닫은 옛 절의 미결에는 한 줄 표시를 붙인다. PRD 전체를 다시 읽지 않는다 - 고친 절의 정합 · 헤더 번호만 확인한다.
3. **커밋**(메시지 = `<세션 번호> <무엇을>: <핵심 결과>` - 기존 로그의 형식) → **`git push origin master`**.
4. `docs/sonnet/README.md`의 그 세션 줄: 완료 칸 `[x]` + 날짜 + 커밋 해시 + Play 결과(n/m) + 미결 한 줄. 이것도 커밋 · 푸시한다.
5. 마지막 보고: 합격 기준 표 · 실행한 명령과 결과 · **동반 실행한 옛 블록과 그 이유** · 미결 · 다음 세션 번호.

### 7. 자율 단계 규칙 (P0부터 - 사용자가 "자율 진행 단계"로 준 지시에 적용)

- 먼저 `docs/sonnet/README.md` · 이 파일 · `docs/stage-scaling-audit.md`(S21a) · 직전 단계의 결과(PRD 절 · `docs/phase/*-report.md`)를 읽는다.
- **끝까지 멈추지 않고 진행한다.** 사소한 판단(이름 · 파일 위치 · 표시 문구 · 구현 방식)은 직접 정하고 `docs/phase/<단계>-log.md`의 "가정·결정 로그"에 한 줄씩 남긴다 - 이 단계에서는 §0의 "판단에 막히면 멈춘다"보다 이 줄이 우선한다.
- 다음은 정하지 않고 멈추지도 않는다 - 같은 로그의 **"결정 필요"**에 모은다: 밸런스 수치 변경 · 게임 규칙 변경 · 세이브 구조의 파괴적 변경 · 되돌리기 어려운 작업.
- **파트마다 따로 커밋한다.** 파트가 실패하면 그 파트만 되돌리고(다른 파트의 커밋은 그대로) 로그에 이유를 남긴 뒤 다음 파트로 간다.
- 끝나면 서브에이전트로 전체 diff를 리뷰한다(그 단계 지시가 정한 관점 + 게임 코드 무변경 여부). 지적은 반영하거나 "결정 필요"에 올리고, 처리 결과를 최종 보고에 적는다.
- 최종 보고는 `docs/phase/<단계>-report.md`에 쓰고 채팅에는 요약을 준다.

#### 7-1. 검증 정책 v2 (M1-0부터 - 사용자 지시 2026-09-25, §3 · §5와 겹치면 이쪽이 우선)

- **자동 검증은 이번 변경이 닿는 블록만** 돈다(`VerifyOnly` 필터 - 이번 블록 + 바꾼 모듈을 직접 쓰는 옛 블록). 전체 회귀는 **마일스톤(알파 직전 · P6)**에서만.
- **Play는 필요한 만큼(최대 3)**. 스크린샷은 **UI · 화면 변경 때만**. 리뷰어(서브에이전트)는 **저장 · 경제 · 판정 · 보안 변경 때만**. EconSim은 **경제 수치 변경 때 해당 프로필만**.
- 단계를 시작할 때 큰 문서 전체(PRD · README) 대신 **`docs/STATE.md`**(현재 상태 1 ~ 2쪽) + 직전 보고서 + 관련 설계 문서만 읽는다. `STATE.md`는 **매 단계 끝에 갱신**한다.
- 옛 X는 재조사하지 않고 목록만 적는다(`STATE.md` "알려진 X").
- 채팅 보고 = **결과 표 1개 + 결정 필요**만(상세는 보고서 파일).

<!-- COMMON:END -->

# S04 — 강화석 2종 + 재료 × 경험치 배수

> 의존성: S03. 규모: 중. 설계 출처: PRD 20.72 [1-5](나) · [2-4] · [2-8] · [5] 3단계 + **20.81 [B-4]**.
> 이 세션부터 세이브에 새 재화가 생긴다.

## 0. 한 줄 목표

스테이지 50+에서 강화석, 75+에서 상급 강화석이 처치 보상으로 나오고(땅이 아니라 즉시 지급), 19 ~ 24강 시도가 골드와 함께 그 재료를 쓴다. 재료의 기대 개수에는 **받는 사람의 경험치 배수**가 곱해진다.

## 1. 먼저 읽을 것

- PRD: 20.72 [1-5](나)(다) · [2-4] · [2-8] · [3] 그림 · **20.81 [B-4]** · S01 · S03이 남긴 절
- 코드: `server/CombatResolution.lua`(`grantKillReward` 전체 - 기여 10% 게이트가 어디서 걸리는지 · 보스 분기) · `shared/Loot.lua`(`rollCount` - S01이 만들었다) · `server/MonsterState.lua`(`getRewardMultiplier` · `getGoldDropFor`) ·
  `shared/data/RareMonsterConfig.lua`(`goldBonusKillEquivalent`) · `shared/data/TreasureChestConfig.lua`(`goldKillEquivalent`) · `shared/data/BossData.lua`(`hpMultiplier`) · 보물상자 보상 지급부(grep `goldKillEquivalent`) ·
  `server/PlayerProfile.lua`(`getExpGainMultiplier` · 계정 공유 필드 `purchases`가 저장되는 방식) · `server/EnhanceServer.server.lua` · `server/SaveSystem.lua` · 골드 획득 팝업의 클라(`GoldHud.client.lua`)

## 2. 단계

### 단계 1 — 데이터 `shared/data/EnhanceMaterialData.lua`(신규)

```lua
return {
	order = { "enhanceStone", "highEnhanceStone" },
	materials = {
		enhanceStone     = { displayName = "강화석",     minStage = 50, dropChancePerKill = 0.25 },
		highEnhanceStone = { displayName = "상급 강화석", minStage = 75, dropChancePerKill = 0.25 },
	},
	-- 시도 1회의 소모(시도하는 순간의 단계 → { 재료 id, 개수 }). 0 ~ 18강은 없음(골드만)
	costByLevel = {
		[19] = { id = "enhanceStone", count = 8 },  [20] = { id = "enhanceStone", count = 10 }, [21] = { id = "enhanceStone", count = 12 },
		[22] = { id = "highEnhanceStone", count = 10 }, [23] = { id = "highEnhanceStone", count = 13 }, [24] = { id = "highEnhanceStone", count = 16 },
	},
}
```

스테이지 75+에서는 **두 재료가 각각 독립으로** 굴려진다(강화석도 같이 나온다 - 20.72 [1-5] 표).

### 단계 2 — 저장: `materials`(계정 공유)

- `saveVersion` +1. 계정 공유 자리에 `materials = { enhanceStone = 0, highEnhanceStone = 0 }`. 계정 공유 필드가 프로필의 어디에 있는지는 `purchases` 등 기존 계정 공유 필드를 따라간다. `isValidProfile`: 둘 다 0 이상의 정수.
- `PlayerProfile.getMaterial(player, id)` · `addMaterial(player, id, n)` · `trySpendMaterial(player, id, n)`. 보유량은 클라가 읽을 수 있게 Attribute 둘(`MaterialEnhanceStone` · `MaterialHighEnhanceStone`)로 동기화한다(골드가 쓰는 방식과 같게).

### 단계 3 — 지급 (`grantKillReward` 안 - 기여 10% 게이트를 자동으로 탄다)

```
기대 개수 E = dropChancePerKill × 마리분 × PlayerProfile.getExpGainMultiplier(받는 사람)
  마리분: 잡몹   = 골드가 쓰는 보상 배율과 같은 값(tier r^p × 접두사)
          보스   = BossData의 hpMultiplier(20)
          반짝이 = 자기 몫 + RareMonsterConfig.goldBonusKillEquivalent(10)
          보물상자 = TreasureChestConfig.goldKillEquivalent(30) - 상자 보상 지급부에서, 때린 사람 각자
조건: 받는 사람의 스테이지(recipientStage) ≥ material.minStage   ← 보스도 "받는 사람의 스테이지"다(20.72 [2-4] 강화석 줄)
개수 = Loot.rollCount(E)
```

- "골드와 같은 배율"이 코드에서 정확히 무엇인지는 `MonsterState.getGoldDropFor`를 읽고 **같은 인자를 쓴다**(스테이지 지수 성장 `k^(S−1)`은 빼고 tier · 접두사 배율만). 골드 식에서 그 배율만 떼어낼 수 없는 구조면 멈춘다.
- 땅에 떨어뜨리지 않는다. 즉시 `addMaterial` + 새 RemoteEvent `MaterialGained(id, count)` → 클라가 골드 팝업과 같은 자리 · 같은 모양으로 "+3 강화석"을 띄운다(새 클라 파일 `client/MaterialHud.client.lua` - 기존 HUD 파일에 넣지 않는다. 색은 `UIColors.textPrimary` · 모양은 골드 팝업 그대로).
- 견습 중에는 스테이지 조건 때문에 자연히 안 나온다 - 별도 분기를 넣지 않는다.

### 단계 4 — 소모 (`EnhanceServer`)

- 시도 전 검사 순서: 최대 단계 → 골드 → **재료**. 부족하면 `insufficient_material`(payload에 id · 필요 · 보유). 골드와 재료를 **둘 다 확인한 뒤** 둘 다 차감한다(하나만 빠지는 경로 0). 차감 ~ 판정 사이 yield 금지.
- 기존 `EnhanceUI`는 거절 사유 문자열 한 줄만 추가한다("강화석이 부족합니다 (8개 필요 · 보유 3개)") - 본격 UI는 S07.

### 단계 5 — DevTools

- `/gg mat <id> <n>`(재료 지급) · `/gg killtest`의 로그에 재료 줄 추가. `/gg` 도움말 목록에 등록.

## 3. 자동 검증 블록 — `server/EnhanceVerify.lua`에 S04 구역

**(가)**

| # | 검사 | 기대 |
|---|---|---|
| 1 | `rollCount(0.25)` 100,000회 평균 | 0.25 ± 0.005 · 값은 0 또는 1 |
| 2 | `rollCount(5.0)` / `rollCount(7.5)` | 항상 5 / 7 또는 8(평균 7.5) |
| 3 | 기대 개수 식: tier1 ~ 6 · 접두사 배율 3 · 경험치 배수 1.0 / 1.2 / 1.5 | 식 그대로(표로 출력) - **경험치 배수 1.5면 1.0의 1.5배** |
| 4 | `costByLevel` 19 ~ 24 | 8 · 10 · 12 · 10 · 13 · 16 |
| 5 | 저장 이관 · `isValidProfile`(음수 · 소수 거절) | O |

**(나)** 실제 Player · 실제 처치 경로

| # | 검사 | 기대 |
|---|---|---|
| 6 | 스테이지 **49**에서 200마리 | 강화석 0 · 상급 0 |
| 7 | 스테이지 **50**에서 400마리(tier1 · 접두사 없음) | 강화석 100 ± 25 · 상급 **0** |
| 8 | 스테이지 **74 / 75** | 74: 상급 0 / 75: 둘 다 나온다 |
| 9 | 경험치 배수 m > 1인 상태(성장 옵션 장비 착용 - m은 `getExpGainMultiplier`가 돌려준 값을 로그로 찍는다)에서 스테이지 50 · 400마리 | 100 × m ± 3σ (m = 1.25면 125 ± 28) |
| 10 | 보스(스테이지 50) 처치 | 강화석 4 ~ 6 |
| 11 | 기여 9% 스탠드인 + 실제 Player 91% | 실제 Player만 받는다(27-1 A-기여도와 같은 구성) |
| 12 | 19강 무기 · 강화석 7개 · 골드 충분 | `insufficient_material` · 골드 **안 빠짐** |
| 13 | 강화석 8개 → 시도 | 8개 · 골드 235,000 빠짐 · 결과 정상 |
| 14 | 프로필 · 보스 원상 복구 | 고아 보스 0 |

9번의 배수를 만드는 법: `getExpGainMultiplier`가 읽는 성장 옵션을 가진 장비를 검증용으로 착용시킨다(26-2 검증이 옵션 장비를 만드는 방식을 따른다). 새 디버그 훅을 제품 코드에 넣지 않는다.

## 4. 합격 기준

| # | 항목 |
|---|---|
| 1 | (가) 5/5 · (나) 9/9 |
| 2 | 기존 검증 회귀 없음(S01 · S03 포함) |
| 3 | 서버 에러 · 경고 0 |

**진짜 합격 기준**: ① **6 ~ 8번** - 경계(49/50 · 74/75)가 정확하다. ② **9번** - 경험치 배수가 재료에 곱해진다(20.81 [B-4] - "친구와 다니면 +25가 늦어진다"를 닫는 줄).

## 5. 하지 않는 것

- 방지권 · 상점(S05) · 강화 UI(S07).
- 드랍률 · 소모량 · 임계 스테이지 조정. 골드 · 장비에는 경험치 배수를 곱하지 않는다(20.81 [B-4]).

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
- **새 파티클 · 새 에셋 · 새 색 금지.** 기존 자산 · 로블록스 기본 인스턴스 · `UIColors`만 쓴다.
- 연출 요청은 **판정을 건드리지 않고 겉모습만 바꾸는 쪽부터** 한다(29-3 원칙).
- 그리기(클라 연출)와 판정(서버)을 섞지 않는다. 서버가 판정하고 클라는 그린다.

### 2. 클라 UI

- 새 UI는 PRD 20.81 [D]의 틀을 따른다: 부품은 `client/ui/kit/`, 자리는 `ScreenMap`, 창은 `UIManager`에 등록. (S06 전의 세션은 기존 방식대로 두되 새 파일로 분리한다.)
- **파일 하나에 몰지 않는다.** 최상위 `local` 120개 이하 · 파일 800줄 이하. 인스턴스는 `build()` 함수 안에서 만들고 참조는 `refs` 표 하나로 돌려준다(Luau 레지스터 200 한계).
- **`AutomaticSize`를 중첩하지 않는다.** 고정 크기를 기본으로 한다.
- 글씨 12 미만 금지. 모바일 터치 타깃 44 × 44 이상. hover에 기대는 조작 금지.

### 3. 검증

- **자동 검증 블록은 서버 스크립트 안에 둔다**(`server/<이름>Verify.lua` 모듈 + `DevTools.server.lua`가 부른다, 또는 `DevTools` 안의 `if RunService:IsStudio() then task.spawn(...)` 블록). 기존 블록(26-2 · 27-1 · 29-x)과 같은 모양:
  `===<세션> 검증 시작(가)===` … 항목마다 `[<세션>][가] … O/X` … `===<세션> 검증 끝(가)=== n/m 통과`.
  - **(가)** = 순수 함수 · 합성 데이터(플레이어 없이 서버 시작 때 돈다).
  - **(나)** = 실제 Player와 실제 경로가 필요한 것(플레이어 접속 뒤). 보스 아레나 · 보스 스폰을 쓰는 (나)는 **기존 보스 검증 체인의 끝에** 붙인다(동시에 돌면 서로의 서버 상태를 오염시킨다). 검증이 만든 것(보스 · 더미 · 프로필 값)은 **검증이 끝날 때 전부 되돌린다** - "검증 뒤 encounter 없는 보스 모델 0"을 마지막 항목으로 찍는다.
- **검증 실행 스위치(영구 규칙).** 서버 시작 때 과거 세션의 검증 블록(보스 패턴 · 강화 등)이 전부 다시 돌면 Play 한 번이 4분 가까이 걸린다(S05 실측 3분 55초). 그래서 블록마다 id(`"S06(가)"` · `"S06(나)"` 꼴 - 기존 블록은 `"29-3(나)"` · `"S05(가)"`)를 주고 `DevTools.server.lua`의 `verifyEnabled(id)`로 감싼다:
  - 새 (가) 블록: `if RunService:IsStudio() and verifyEnabled("<id>") then …`. 새 (나)는 29-1 체인의 단계 표(`{ "<id>", function() … end }`)에 id와 함께 넣는다 - 체인이 단계마다 `verifyEnabled`로 거른다.
  - **세션을 시작할 때** `shared/data/DevToolsConfig.lua`의 `verify.current`를 **이 세션의 블록 id들로 갈아 끼운다**(전 세션의 id는 지운다). 기본값 `verify.regression = false` - 이때는 `current`에 적힌 블록만 돈다.
  - **중간 Play에서는 `regression`을 켜지 않는다.** 과거 블록 전체 회귀는 **세션의 마지막 Play 1회**에서만 `regression = true`로 돌린다(그 Play가 "기존 검증 회귀 없음" 합격 기준의 근거다). 그 Play가 끝나면 **바로 `false`로 되돌려 커밋한다**(켜 둔 채로 끝내면 다음 세션의 첫 Play가 4분 걸린다).
  - 콘솔 첫머리의 `[DevTools] 자동 검증 모드: …` 줄로 이번 Play의 모드를 확인한다. 어느 Play가 회귀 Play였는지는 보고에 적는다.
- **`execute_luau`로 `shared` 모듈을 `require`하지 않는다**(Capabilities 제약으로 막혀 있다). 검증은 위의 서버 블록으로만.
- **검증 스탠드인의 교훈**(29-4 · 29-5의 X가 전부 여기서 나왔다):
  1. **Attribute는 실제 Player에만 쓰인다.** 스탠드인(더미 · 표)의 상태를 Attribute로 읽지 않는다 - 서버 모듈의 상태 함수로 읽는다. 피해를 받는 스탠드인에는 필요한 스텁이 있는지 먼저 본다.
  2. **스킬을 강제로 시작한 그 틱에는 추적이 돌지 않는다 - 다음 틱부터 돈다.** 강제 시작 직후의 값을 읽지 말고 한 틱 이상 기다린 뒤 읽는다. 만료 시각도 같다(한 틱 일찍 읽으면 X).
- X가 나오면 먼저 **검증 쪽의 원인인지 제품 쪽의 원인인지**를 로그로 가른다. 그럴듯한 설명에서 멈추지 말고 실제 인스턴스 · 실제 코드를 한 번 훑는다(CLAUDE.md).

### 4. 로컬 검사 (Play 전)

- 바뀐 · 새 Luau 파일 전부를 `luau-compile`(스크래치패드의 luau CLI)로 구문 · 레지스터 검사한다. 순수 모듈은 스텁 하네스로 돌려 본다. 긴 python은 히어독이 아니라 파일로 만들어 실행한다.
- `git diff --stat`으로 의도한 파일만 바뀌었는지 본다.

### 5. Play 절차 (사용자를 부르지 않는다)

1. **Play 전에 커밋한다**(검증이 서버 상태를 바꾼다 - 돌아갈 지점을 만든다).
2. MCP `start_stop_play`로 Play를 시작한다.
3. **검증이 끝날 때까지 기다린다. 그동안 MCP 도구를 하나도 부르지 않는다**(콘솔 읽기 · 화면 캡처 · execute_luau 전부 금지 - Play 중 호출이 검증을 흔든다). 대기는 백그라운드로 Studio 로그 파일(`%LOCALAPPDATA%\Roblox\logs\*Studio*_last.log`)을 폴링해 이번 Play의 마지막 `검증 끝` 줄이 나오면 멈춘다(고정 9분 대기 금지). 걸리는 시간: 현재 세션 블록만 돌 때 1분 안팎 · **회귀 전체(`regression = true`)는 약 4분**. 상한은 회귀 전체 6분 · 현재 세션 블록만 3분.
4. MCP로 Play를 **정지**한다.
5. 콘솔을 읽는다: `===… 검증 끝…===` 줄 전부 · 이번 세션의 `[세션]` 줄 · 에러 · 경고. 콘솔 앞부분이 길이 제한으로 잘리면 "읽은 구간"을 보고에 적는다.
6. X가 있으면 고치고(§3) → 커밋 → 2번부터 다시. **Play는 세션당 최대 3회.** 3회째에도 X가 남으면 멈추고 보고한다. 이 중 **마지막 자동 검증 Play 1회만 `regression = true`**(§3) - 그 앞의 Play는 전부 현재 세션 블록만 돌린다.
7. UI 세션의 스크린샷은 자동 검증이 끝난 뒤의 **별도 Play**에서 찍는다(그 Play에서는 MCP를 써도 된다 - 자동 검증 결과를 그 Play에서 읽지 않는다).
- "재미있어 보이는가 · 읽히는가" 같은 체감 판단은 하지 않는다. "사람이 확인할 것" 표로 PRD에 남긴다.

### 6. 끝내기

1. **합격 기준 표**를 채운다(항목 · 결과 O/X · 근거 로그 한 줄). "진짜 합격 기준"이 O가 아니면 이 세션은 끝난 것이 아니다. 마지막 Play(`regression = true`)를 돌렸다면 **`DevToolsConfig.verify.regression`을 `false`로 되돌린 커밋이 들어 있는지** 확인한다.
2. **PRD 기록**: `PRD-forge-game-roblox.md` 끝에 새 절 `### 20.NN <세션 번호> <제목>`(번호 = 마지막 절 + 1). 내용 = 무엇을 했나 · 구조/변경 파일 · 검증(로컬 · Play 회차별) · 합격 기준 표 · 사람이 확인할 것 · 미결 · 임의 결정(지시에 없어서 스스로 정한 것이 있으면 전부). 이 세션이 닫은 옛 절의 미결에는 한 줄 표시를 붙인다. PRD 전체를 다시 읽지 않는다 - 고친 절의 정합 · 헤더 번호만 확인한다.
3. **커밋**(메시지 = `<세션 번호> <무엇을>: <핵심 결과>` - 기존 로그의 형식) → **`git push origin master`**.
4. `docs/sonnet/README.md`의 그 세션 줄: 완료 칸 `[x]` + 날짜 + 커밋 해시 + Play 결과(n/m) + 미결 한 줄. 이것도 커밋 · 푸시한다.
5. 마지막 보고: 합격 기준 표 · 실행한 명령과 결과 · 미결 · 다음 세션 번호.

<!-- COMMON:END -->

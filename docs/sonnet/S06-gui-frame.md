# S06 — GUI 공통 틀: kit · UIManager 종류 확장 · ScreenMap · 겹침 검사

> 의존성: 없음(핵심 루프와 독립 - S05보다 앞당겨도 된다). 규모: 대. 설계 출처: **PRD 20.81 [D] 전체**.
> 이 세션은 **틀만** 만든다. 기존 UI는 하나도 옮기지 않는다(옮기는 순서는 20.81 [D-6] - 세션마다 하나).

## 0. 한 줄 목표

앞으로 붙을 모든 UI(강화 · 드랍 피드 · 메뉴바 · 상점 · 펫 · 출석 · 시즌패스)가 공유할 부품(`client/ui/kit/`) · 패널 종류 3종(`window` · `station` · `overlay`) · 화면 지도(`ScreenMap`) · 겹침 자동 검사를 만든다. 기존 화면의 모양과 동작은 **한 픽셀도 안 바뀐다.**

## 1. 먼저 읽을 것

- PRD: **20.81 [D-1] ~ [D-6]** · 20.33(HUD 배치) · 20.52(카툰 기조) · 20.70 [5](`AutomaticSize` 함정) · 20.71 [4](레지스터 200 한계)
- 코드: `client/UIManager.lua` 전체 · `shared/data/UIColors.lua` · `client/HelpTooltip.lua` · `client/HudChip.lua` · `client/PartyHud.client.lua`의 토스트 부분(모양의 기준) · `client/InventoryUI.client.lua`의 `UIManager.register` 호출부(1962줄 부근) ·
  `client/AttackInput.client.lua`의 `UIManager.isInputBlocked` 사용부 · `roblox/default.project.json`(`src/client` → `StarterPlayerScripts` - 하위 폴더의 `.lua`는 ModuleScript, `.client.lua`는 LocalScript가 된다)

## 2. 단계

### 단계 1 — `client/ui/kit/Theme.lua`

- 색: `UIColors`를 그대로 다시 내보낸다(새 색 0). 폰트: `Enum.Font.GothamBold`(지금 HUD의 것) 하나 + 본문용 `Enum.Font.Gotham`.
- `Theme.isMobile` = `UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled`(**이 판정은 여기 한 곳**).
- `Theme.text = { title = 20, header = 16, body = 14, caption = 12, number = 18 }` - `Theme.textSize(name)`이 모바일이면 ×1.15 반올림(23 · 18 · 16 · 14 · 21).
- `Theme.space = { 4, 8, 12, 16 }` · `Theme.corner = { panel = 12, button = 10, chip = 8 }` · `Theme.touchMin = 44` · `Theme.buttonHeight`(PC 32 / 모바일 44) · `Theme.tabHeight`(28 / 40).
- 헬퍼: `Theme.corner(inst, px)` · `Theme.stroke(inst)`(rim 1px) · `Theme.label(parent, text, sizeName, colorName)`.

### 단계 2 — 부품 (파일 하나에 부품 하나 · 전부 `build(props) -> refs` 모양)

| 파일 | 규격(20.81 [D-3] 그대로) |
|---|---|
| `Button.lua` | `kind = "primary" / "secondary" / "danger"` · 상태 `setEnabled(bool, reasonText)`(비활성이면 버튼 **아래에** 이유 한 줄) · `setBusy(bool)` · 눌림 색은 `InputBegan`에서 즉시 · 최소 폭 88 |
| `Toggle.lua` | 켜짐 = `success` 채움 + "✓" / 꺼짐 = `slot` + 빈 칸 · 라벨 포함 전체가 터치 영역 · `setValue` · `onChanged` · `setEnabled(bool, reasonText)` |
| `Tabs.lua` | 선택 = `textPrimary` + `ember` 밑줄 3px · 5개 초과면 `error` |
| `ListRow.lua` | 고정 높이 28 / 40 / 56 · 아이콘 칸 · 2줄 글(말줄임 `TextTruncate`) · 오른쪽 값 또는 버튼 자리 |
| `Gauge.lua` | 높이 10 / 16 / 22 · `setValue(0~1)` 0.15초 트윈 · 숫자 오버레이는 16 이상에서만 |
| `Toast.lua` | 줄(lane) 3개 `TC` · `TR` · `BC`. `Toast.push(lane, { text, colorName, seconds, richParts? })`. `TR`은 최대 3행 · 대기열 8 · 넘치면 `priority`가 낮은 것부터 버린다 · 같은 `groupKey`가 1초 안에 오면 한 행으로 묶는다(20.73 [5-3]의 요구 - S10이 쓴다). 모양 = `panel` + rim + 모서리 10 |
| `HelpToggle.lua` | 20px 원 "?" · 누르면 열리고 다시 누르면 닫힌다 · 내용은 기존 `HelpTooltip`을 감싼다(hover 경로를 쓰지 않는다) |
| `Badge.lua` | 점 8px / 숫자 16px |
| `Confirm.lua` | overlay 확인창: `Confirm.ask({ title, body, primaryText, secondaryText, danger? }) -> 콜백`. `UIManager`에 `kind = "overlay"`로 등록된 창 하나를 재사용 |
| `Panel.lua` | `Panel.create({ id, kind, title, size, hotkey?, help? }) -> refs{ screenGui, frame, content, closeButton }`: 제목줄(제목 · ? · X 44 × 44 터치 영역) + 내용 프레임 + `UIManager.register`까지. window면 딤 포함 · 모바일 크기 규칙 `min(92% W, 720) × min(88% H, 480)` |

모든 부품: 고정 크기 기본 · `AutomaticSize` 중첩 0 · 글씨는 `Theme.textSize`만 · 색은 `Theme` 경유.

### 단계 3 — `UIManager` 확장 (그 자리에서 - 옮기지 않는다)

- `register(id, config)`에 `config.kind`(`"window"` 기본 · `"station"` · `"overlay"`) 추가. **`kind`를 안 준 기존 등록(가방)은 지금과 완전히 같게 동작해야 한다.**
- 규칙(20.81 [D-1]): window를 열면 다른 window · station을 닫는다 / station을 열면 다른 station을 닫고, window가 열려 있으면 **열리지 않는다** / overlay는 맨 위에 1개, `config.parentId`의 패널이 닫히면 같이 닫힌다.
- 모달: window · overlay만 `modal = true`로 친다(station은 걸을 수 있다). `isInputBlocked`는 지금 뜻 그대로.
- DisplayOrder 대역: station 10 ~ 19 · window 100 ~ 149 · overlay 200 ~ 249(`BASE_DISPLAY_ORDER`를 종류별 표로).
- `UIManager.setBossFight(bool)`: true인 동안 window의 딤(`extraVisible` 중 딤으로 표시된 것)을 끈다. 누가 부르는가: 새 `client/ui/BossFightWatcher.client.lua`가 기존 보스전 신호(클라가 보스전 여부를 아는 기존 Attribute/이벤트를 grep - `BossPatternVisuals` · `StageUI`가 쓰는 것)를 듣는다. **그런 신호가 없으면 이 항목만 빼고 미결로 남긴다**(서버에 새 복제 상태를 만드는 것은 이 세션의 범위가 아니다).
- 텔레포트 시 `closeAll`: 기존 `CharacterAdded` 훅 그대로 + 위 보스전 신호가 바뀔 때.
- 단축키 표는 `client/ui/PanelRegistry.lua`로: `{ id, kind, hotkey, menuOrder, iconKey }` 목록. 지금은 가방(`I`) 한 줄만 옮기고, `UIManager`의 hotkey 루프가 이 표를 읽게 한다. 금지 키 목록(W A S D Q E F Space Shift X Backspace Tab + 숫자열)에 든 키를 등록하면 `error`.

### 단계 4 — `client/ui/ScreenMap.lua`

- 구역 상수(20.81 [D-2] 지도): `TL · TC · TR · ML · MR · C · BL · BC · BR · XP` - 각 구역의 앵커 · 여백(가장자리 14px) · 슬롯 표. 모바일의 BL(좌 40% × 하 45%) · BR(우 30% × 하 50%)은 "예약 - 슬롯 없음".
- `ScreenMap.place(frame, zone, slotName)`: 그 슬롯의 `AnchorPoint` · `Position`을 넣는다. 슬롯 표에는 **지금 HUD들이 실제로 쓰는 좌표를 그대로 옮겨 적는다**(코드를 읽어서 - 골드 · 스테이지 칩 · 레벨 배지 · 파티 목록 · 투표 패널 · 스킬 슬롯 · 체력바 · 경험치바 · 토스트 줄 y 64 ~ 210 · 견습 칩). 이 세션에서는 **표만 만들고 기존 HUD는 이 함수를 아직 안 쓴다.**
- 새 슬롯: `TR.dropFeed`(앵커 (1, 0) · 위치 (1, −14, 0, 96) · 300 × 78) · `ML.menuBar`(앵커 (0, 0.5) · x 14) - 20.81 [D-2] 값.

### 단계 5 — 겹침 자동 검사 + 부품 전시장

- `client/ui/UiSelfCheck.client.lua`(Studio에서만 - `RunService:IsStudio()`): 접속 8초 뒤 `PlayerGui`의 보이는 최상위 HUD 프레임(`ScreenMap` 슬롯 표에 이름이 있는 것)의 `AbsolutePosition` · `AbsoluteSize`를 모아 **서로 교차하는 쌍**과 **C 구역(화면 중앙 40% × 50%)을 침범한 것**을 클라 콘솔에 찍는다: `[S06][UI] 겹침 n쌍 · 중앙 침범 m건`. 창(window · station)은 제외.
- `/gg ui gallery`(DevTools → 클라 RemoteEvent): 부품 전부를 한 window 안에 늘어놓은 전시장 패널을 연다(`client/panels/UiGallery/`). 버튼 3종 × 4상태 · 토글 · 탭 · 행 3종 · 게이지 3종 · 토스트 3줄 발사 버튼 · 확인창 · 도움말. **프로덕션에서는 DevTools가 죽어 있어 열 길이 없다.**

## 3. 검증

- **로컬**: 새 파일 전부 `luau-compile` 통과 · 파일마다 최상위 `local` 수를 세어 120 이하임을 표로(세는 스크립트를 스크래치패드에 만든다: `^local ` 줄 수).
- **Play 1(자동)**: 기존 검증 전부 회귀 없음 · 서버/클라 에러 0 · `[S06][UI] 겹침 0쌍 · 중앙 침범 0건`.
- **Play 2(스크린샷 - MCP 사용 가능)**: ① 기본 HUD(S06 전과 같은지 - 세션 시작 때 찍어 둔 "전" 스크린샷과 나란히) ② `I`로 가방 열기 → X · Backspace로 닫기(기존 동작) ③ `/gg ui gallery` PC 화면 ④ 기기 에뮬레이터(폰 가로)에서 같은 전시장 - 글씨 ×1.15 · 버튼 44.

## 4. 합격 기준

| # | 항목 |
|---|---|
| 1 | 가방 창의 열기 · 닫기 · 모달 · 리스폰 정리가 S06 전과 같다(스크린샷 + 클릭) |
| 2 | 종류 규칙: 전시장(window)을 연 채 `I` → 전시장이 닫히고 가방이 열린다 · 확인창(overlay)이 떠 있는 동안 뒤의 버튼이 안 눌린다 · 부모를 닫으면 확인창도 닫힌다 |
| 3 | 겹침 0쌍 · 중앙 침범 0건 |
| 4 | 새 파일 전부 최상위 local ≤ 120 · 800줄 이하 · `AutomaticSize` 중첩 0(grep으로 확인) |
| 5 | 글씨 12 미만 0(새 파일 grep) · 모바일 전시장에서 버튼 높이 ≥ 44 |
| 6 | 기존 자동 검증 회귀 없음 · 에러 · 경고 0 |

**진짜 합격 기준**: ① **1번** - 기존 화면이 안 바뀌었다. ② **2번** - 패널 종류 규칙이 전시장에서 실제로 돈다(다음 세션들이 믿고 쓸 수 있다).

## 5. 쪼개는 선

한 세션에 안 끝나면 **단계 1 ~ 3(Theme · 부품 · UIManager)**에서 커밋하고 끊는다. 단계 4 ~ 5는 이어서.

## 6. 하지 않는 것

- 기존 HUD · 창을 새 부품으로 바꾸지 않는다. `UIManager.lua`를 옮기지 않는다. 메뉴바를 만들지 않는다(S16). 새 색 · 새 아이콘 에셋 0.
- 서버 코드를 고치지 않는다(`/gg ui gallery` 한 줄 제외).

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
  - **세션을 시작할 때** `shared/data/DevToolsConfig.lua`의 `verify.current`를 **이 세션의 블록 id들 + 아래 "동반 실행"으로 고른 옛 블록 id들**로 갈아 끼운다(그 밖의 옛 id는 지운다). 기본값 `verify.regression = false` - 이때는 `current`에 적힌 블록만 돈다.
  - **모든 Play는 `regression = false`로 돈다(영구 규칙).** 세션 마지막에 회귀 전체를 돌리지 않는다. 회귀 전체(`regression = true`)는 **마일스톤에서만** 켠다: **S10 · S15 · S21 종료 시 · Fable 세션으로 넘어가기 전 · 퍼블리시 전**(README 순서표의 "회귀 전체" 표시 줄 + 사용자가 그 시점의 지시에 적은 경우). 마일스톤이 아닌 세션에서 켜야 할 것 같으면 켜지 말고 §0으로 멈춘다. 마일스톤에서 켰다면 그 세션의 **마지막 자동 검증 Play 1회에서만** 켜고, 끝나면 **바로 `false`로 되돌려 커밋한다**(켜 둔 채로 끝내면 다음 세션의 첫 Play가 4분 걸린다).
  - **동반 실행(영구 규칙).** 이 세션이 **고친 모듈을 쓰는 옛 검증 블록**은 현재 세션 블록과 함께 돌린다 - "회귀 전체 없이 회귀를 잡는" 장치다. 예: 강화 코드(`Enhance` · `EnhanceConfig` · `EnhanceMaterialData` · 강화 Remote)를 고쳤으면 S03 강화 블록(`S03(가)` · `S03(나)`)도, 저장 구조를 고쳤으면 저장 이관 블록도. 고르는 법: 이 세션이 바꾼 파일(모듈) 이름을 `server/*Verify.lua` · `DevTools.server.lua`의 검증 블록이 `require`하거나 부르는지 `grep`으로 찾아 그 블록 id를 `current`에 넣는다. 어느 블록이 쓰는지 grep으로 가려지지 않으면 **넓은 쪽으로 포함한다**(시간이 늘 뿐 틀리지 않는다). **어떤 옛 블록을 같이 돌렸는지와 그 이유를 PRD 기록과 마지막 보고에 적는다.** 세션 본문의 합격 기준에 나오는 "회귀 없음"은 "동반 실행한 옛 블록이 이전과 같거나 더 좋다"로 읽는다(회귀 전체가 아니다).
  - 콘솔 첫머리의 `[DevTools] 자동 검증 모드: …` 줄로 이번 Play의 모드와 실제로 돈 블록을 확인한다.
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
3. **검증이 끝날 때까지 기다린다. 그동안 MCP 도구를 하나도 부르지 않는다**(콘솔 읽기 · 화면 캡처 · execute_luau 전부 금지 - Play 중 호출이 검증을 흔든다). 대기는 백그라운드로 Studio 로그 파일(`%LOCALAPPDATA%\Roblox\logs\*Studio*_last.log`)을 폴링해 이번 Play의 마지막 `검증 끝` 줄이 나오면 멈춘다(고정 9분 대기 금지). 걸리는 시간: 현재 세션 블록 + 동반 옛 블록이 돌 때 1분 안팎(동반 블록이 무거우면 더) · **회귀 전체(`regression = true`, 마일스톤 Play만)는 약 4분**. 상한은 회귀 전체 6분 · 그 외 3분.
4. MCP로 Play를 **정지**한다.
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

<!-- COMMON:END -->

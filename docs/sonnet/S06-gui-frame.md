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
- **모든 보고 · 보고서 · 채팅은 한국어로 쓴다**(사용자 지시 2026-09-25 - 표 헤더 · 셀 포함). 코드 식별자 · 경로 · 커밋 메시지 · 로그 원문만 그대로 둔다.

<!-- COMMON:END -->

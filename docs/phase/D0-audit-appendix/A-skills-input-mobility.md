# 조사 (a) 스킬·입력 · (f) 이동기 — 읽기 전용 감사

기준 커밋: c4ed73b(master). 저장소 파일은 수정하지 않았다. Studio MCP는 쓰지 않았다(좌표는 전부 코드 식으로 계산 - 실측 아님).
경로는 `roblox/src/` 기준. `[추정]` = 코드·문서로 확인 못 한 것. `[계산]` = 코드 상수로 계산한 값(스크린샷·Play 실측 아님).

---

## (a) 스킬·입력

### 1. 직업 · 키 · 스킬 표

직업 4종: `shared/data/ClassData.lua:28`(order), 표시 이름은 `displayName`(36행 주석 - 내부 id·저장 값은 그대로).

| 내부 id | 표시 이름 | atk | 공속 | def | 치확/치피 | 사거리 배율 | 근거 |
|---|---|---|---|---|---|---|---|
| greatsword | 검사 | 1.85 | 0.7 | 1.3 | 0.12 / 2.0 | 1.3 | ClassData.lua:38-47 |
| dualblade | 도적 | 0.85 | 1.6 | 0.6 | 0.30 / 2.0 | 1.0 | :48-57 |
| bow | 궁수 | 1.8 | 0.84 | 0.6 | 0.15 / 2.3 | 1.5 | :58-74 |
| healer | 치유사 | 0.66 | 1.25 | 1.0 | 0.12 / 1.8 | 1.5 | :75-87 |

키는 **네 직업 모두 같다**(직업별 키 매핑 없음):
- 평타 = 좌클릭(PC) / 탭(폰) 조준 공격 - `client/AttackInput.client.lua:333-359`(버튼 없음, 18-2에서 제거). 기본 평타 쿨 0.28초 ÷ 공속(`shared/data/CombatConfig.lua:10`).
- Q · E = `client/SkillInput.client.lua:39` `KEY_TO_SLOT = { Q, E }`, 서버는 `server/SkillServer.server.lua:481-484`에서 `slot ~= "Q" and slot ~= "E"`면 무시.
- 대시 = LeftShift(PC) / HUD 대시 버튼(폰) - `client/DashInput.client.lua:49`, `:54-58`.
- 점프 = Space(로블록스 기본). JumpHeight는 코드에서 설정하지 않음 - 기본값 7.2(`shared/data/TerrainConfig.lua:47` 주석, `default.project.json`에 StarterPlayer 점프 설정 없음).

스킬 수치(`shared/data/SkillData.lua`):

| 직업 | 칸 | 이름 | shape | 쿨(초) | 주요 수치 | 줄 |
|---|---|---|---|---|---|---|
| 검사 | Q | 관통돌진 | line | 10 | 계수 7.6 · 18stud/0.25초 · 판정 반경 5 | 16-43 |
| 검사 | E | 회전베기 | circle(채널) | 16 | 누적 계수 8.2 · 3초/3틱 · 이속 ×0.5 · 받는 피해 ×0.5 · 반경 20 | 44-68 |
| 궁수 | Q | 속사 | selfBuff | 18 | 6초 · 공속 min(2.5, 1.0 + 치확×1.5) · 꽂힌 화살 계수 0.08/0.8초/최대 4 | 82-131 |
| 궁수 | E | 백스텝샷 | dash(뒤) | 15 | 12stud/0.2초 · 다음 평타 5발 치확 +30%p · 추가 계수 0.5 · 사거리 ×2 | 132-155 |
| 도적 | Q | 그림자분신 | summon | 14 | 5초(분신 = 확정 치명 창) | 169-178 |
| 도적 | E | 난무 | singleChannel | 20 | 계수 14.46 · 1.0초/6틱 · 사거리 10 · 확정치명 첫 타만 | 179-199 |
| 치유사 | Q | 치유 | heal | 25 | 최대체력 30% · 파티 전원 · 치명 ×2 · 파티 버프 지속 = 쿨 × 1.2 = 30초 · (딜링모드+파티) 쉴드 healRatio 0.6 / 11초 / 쿨 25 | 206-235 |
| 치유사 | E | 딜링모드 | toggle | 0 | 평타 ×1.574 · 투자 기울기(topScale 1.1) · 초당 최대체력 1.2% 소모 | 236-277 |

SkillStats(서버 단일 출처): `server/SkillStats.lua` - `hitCoefficient`(36행, 계수 × (1 + 옵션 `skill_<직업>_<칸>`) ÷ 틱), `cooldown`(44행 - 궁수 E · 치유사 Q만 옵션으로 쿨 변동, 치유사 Q는 쉴드 시전이면 쉴드 쿨), `quickShotMultiplier`(58), `decoyDuration`(64), `crit`(69), `info`(77 - 툴팁 원격용, 90행에서 `PartyConfig.healerBuffFraction` 노출).

**치유사 딜링 모드 전환**: E 키 토글(`SkillData.healer.E.shape = "toggle"`, 쿨 0). 서버 `SkillServer.server.lua:458-478` - `BuffState`의 `"dealingMode"`를 apply/clear로 오간다(만료 없는 영구 버프). 켜진 동안 `server/HealerDealingMode.server.lua`가 매 Heartbeat 최대체력 × 0.012/초 소모(26-50행), 평타 배율은 AttackServer가 `attackMultiplier`를 직접 읽는다(같은 파일 3-5행 주석). 딜링모드 + 파티이면 Q가 회복 대신 쉴드(`HealCast.usesShield`, SkillData.lua:226-229).

**성기사(탱커) 직업: 코드에 없다.** `ClassData.order`는 4종뿐(28행). "탱커 대비 훅" 자리만 있다(값은 비어 있음): `shared/data/BossData.lua:116-121`(`tank.defaultWeightFactor = 1.0`), `server/BossMechanics.lua:119-130`(무게 계수 · 반사 버퍼), `shared/BossScheduler.lua:170`(도발 기록), `shared/BossSkillMath.lua:112`(reflectable), `server/BossPatterns.lua:607 · 1823`(도발 인터럽트 진입점). PRD 20.80 [F](14575행 "탱커 직업은 나중이다") · 20.81 로드맵 27번(14918행) · F4 단계(15235행). "성기사"라는 단어는 코드 · PRD 어디에도 없다.

### 2. 키 사용 전수 · R/T 충돌

`grep KeyCode.` 전수(Verify·Check 포함) 결과 **`KeyCode.R` · `KeyCode.T`는 0건**(유일한 `"T"`는 `shared/NumberFormat.lua:9`의 숫자 단위 "T" - 키 아님). DevTools(`server/DevTools.server.lua`)는 `/gg` 채팅 명령이라 키 바인딩이 없다.

PC 키 배치 전체:

| 키 | 용도 | 근거 |
|---|---|---|
| W A S D | 이동(로블록스 기본) | 금지 키 `client/ui/PanelRegistry.lua:8` |
| Space | 점프(기본) | PanelRegistry.lua:10 · DashConfig 주석 |
| 좌클릭 / 탭 | 평타(조준) | AttackInput.client.lua:338 · 349 |
| 우클릭 | 카메라 회전(기본) · 장비/보석 칸 우클릭 동작 | panels/Inventory/BagTab.lua:242 · GearTab.lua:412 · GemTab.lua:423 |
| Q / E | 스킬 | SkillInput.client.lua:39 |
| LeftShift | 대시 | DashInput.client.lua:49 |
| E(근접 시) | ProximityPrompt - 환생 제단 · 보석상인 | server/HuntingGround.server.lua:202 · 282 |
| F(홀드) | 보스 잡기 기믹 구출 | shared/data/BossData.lua:85 → server/BossTrap.lua:251 |
| B | 가방 창 | PanelRegistry.lua:21 |
| P | 파티 창 | PanelRegistry.lua:22 |
| M | 스테이지 선택 | PanelRegistry.lua:24 |
| X · Backspace | 맨 위 창 닫기 | client/UIManager.lua:28 |
| Esc | 로블록스 메뉴 · 보석 탭 취소 | panels/Inventory/GemTab.lua:623 |
| Tab | 금지 키(로블록스 플레이어 목록) | PanelRegistry.lua:10 |
| 1~0 | 금지 키 - "스킬 슬롯 확장 몫"으로 예약 | PanelRegistry.lua:3 · 12-13 |
| I · O | 엔진(기본 카메라 줌)이 KeyDown을 삼킴 - 등록 불가 | PanelRegistry.lua:16-18 · client/InputDiag.client.lua |
| O · K · J | 예약(상점 · 펫 · 보상 창 - 아직 미등록) | PanelRegistry.lua:25 |

R · T 추가 시 충돌: **게임 코드 안에서는 없음.** 주의점 2개:
1. R · T가 `PanelRegistry.forbiddenKeys`(7-14행)에 없다 - 지금은 다른 세션이 창 단축키로 R/T를 등록할 수 있다. 스킬 키로 쓰면 금지 목록에 넣어야 한다(Q · E처럼).
2. 스킬 슬롯이 Q/E 두 개로 하드코딩된 곳: `SkillInput.client.lua:39 · 45`(`localCooldownUntil = { Q, E }`), `SkillServer.server.lua:482`, `SkillSlots.client.lua:68-74 · 390 · 459 · 535-537`(q/e/dash만 링 루프), `SkillIconData.lua`(q/e만), 옵션 id `skill_<직업>_<칸>`(SkillStats.lua:21). SkillData도 직업당 Q/E 테이블만.
3. [추정] 로블록스 기본 R/T 바인딩은 없다(기본 PlayerModule은 I/O 줌 · 화살표 · Shift Lock만). 별개 기존 문제: Shift Lock(StarterPlayer `EnableMouseLockOption` 기본 true - 코드·project.json에 설정 없음)을 사용자가 켜면 LeftShift 대시와 겹친다 [추정].

### 3. 폰(800 × 360) 터치 배치

**좌표계**: COMMON.md 40행 - 800 × 360은 인셋 58을 빼면 ScreenGui **800 × 302**. 터치 기하는 전부 아래 끝 기준이라 인셋과 무관하게 아래 끝에서 같은 거리다.

**규칙 정의 위치**
- 중앙 금지 구역(C): `client/ui/ScreenMap.lua:48`(zones.C "화면 중앙 40% × 50%에 2D UI 없음") · `:123` `centerFraction = { 0.3, 0.25, 0.7, 0.75 }` · PRD **20.81 [D-2] 화면 영역 고정 지도**(15121행, C 행 15147행 "영구히 없음").
- 우하단 터치 예약(BR 우 30% × 하 50%) · 좌하단(BL 좌 40% × 하 45%): `ScreenMap.lua:49 · 51`(주석) · `:107-110` `mobileReserved`. PRD 20.81 [D-2](15189행 station 행에 같은 수치).
- 800 × 360 기준: COMMON.md 40행(영구 규칙 S20). 터치 타깃 44 이상: COMMON.md 36행 · `client/ui/kit/Theme.lua:21` `touchMin = 44`.

**800 × 302에서의 구역 [계산]**: C = x 240~560 · y 75.5~226.5 / BR = x ≥ 560 · y ≥ 151 / BL = x ≤ 320 · y ≥ 166.1.

**현재 배치 [계산]** (`client/SkillSlots.client.lua`)
- 터치 여부: `TouchEnabled` 또는 Studio + `ForceTouchLayout`(107-112). 뷰포트 짧은 변 360 ≤ 500 → "작은 화면"(95-102): 점프 70px, 오른쪽 95 · 아래 90.
- 점프 버튼(로블록스 TouchGui - SkillSlots가 같은 식을 재계산, 모의 원 418-437): **x 705~775 · y 212~282**.
- 스킬 줄(5칸 = Q · E · 잠김 3): 슬롯 54 · 간격 11(44-45), 앵커 (1,1) · 위치 (1, −16, 1, −106)(410-411) → 폭 314 → **x 470~784 · y 142~196**. 칸별 x: Q 470~524 · E 535~589 · 잠김1 600~654 · 잠김2 665~719 · 잠김3 730~784. 폰에서는 키 알약 숨김(393).
- 대시(이미 있음): 좌측 앵커 (0,1) · (0, 24, 1, −106)(414-416) → **x 24~78 · y 142~196**, 54px.
- 조이스틱: 동적(DynamicThumbstick) - 좌하단 터치 지점에 생김(88-90 주석). 고정 자리 없음. SkillSlotsGui DisplayOrder 5(117)로 TouchGui 위.
- 공격 버튼 없음(탭 조준, AttackInput.client.lua:348-359).

**현재 배치가 이미 규칙과 겹치는 곳 [계산 - 실측 안 됨. 스크린샷 확인 필요]**
| 겹침 | 크기 | 근거 |
|---|---|---|
| Q 칸이 C 구역 안 | Q 전체(54 × 54, x 470~524) · E 25px(x 535~560) | 위 좌표 vs centerFraction |
| 스킬 줄 위 끝이 BR 위 끝(151)보다 위 | 9px(y 142~151) | mobileReserved.BR.top 0.5 |
| 스킬 줄 × 체력바(x 203~597 · y 189~208, `PlayerHealthBar.client.lua:33 · 38` BOTTOM_OFFSET 94) | x 470~597 × y 189~196(7px) | Q · E 아래 끝 |
| 잠김2 · 잠김3 × 가방 버튼(`panels/Inventory/Shell.lua:34-37` - x 694~784 · y 133~169, 숨김 코드 없음) | x 694~784 × y 142~169(27px) | 폰에서도 상시 표시 |
| 대시 × 메뉴바(모바일 48 × 3칸 = 156, 위로 밀어 y 10~166 · x 14~62 - `ScreenMap.mobileMenuBarShiftUp` 117-123) | x 24~62 × y 142~166(38 × 24) | 대시 위 끝 142 < BL 위 끝 166 |
기존 자체 점검(`hud/PartyHudCheck.client.lua:184-205`)은 높이 388 · 414 · 534로 재구성하고 800 × 302는 안 돈다 - 위 겹침은 기존 점검 범위 밖이다. 스킬 줄(CentralRow)과 C 구역을 대조하는 점검은 찾지 못했다.

**R · T · 대시 버튼 자리 후보** (대시는 이미 있으므로 새로 필요한 것은 R · T 두 개)

- **안 1 - 잠긴 칸 재사용(코드 변경 최소)**: R → 잠김1(x 600~654), T → 잠김2(x 665~719). 기하 변화 0. 대신 위 표의 기존 겹침(Q의 C 구역 침범 · 가방 버튼 27px · 체력바 7px)을 그대로 물려받는다. PC도 같은 줄에 키 알약 R · T만 붙이면 된다.
- **안 2 - BR 안 2 × 2(44px) - 모든 규칙 통과 [계산]**: 잠김 3칸을 폰에서 없애고 Q · E · R · T를 점프 왼쪽에 44px 격자로(간격 6).
  - 윗줄 y 180~224: x 603~647 · 653~697 / 아랫줄 y 238~282: x 603~647 · 653~697.
  - BR(x ≥ 560 · y ≥ 151) 안 O · C 구역(x ≤ 560) 밖 O · 체력바(x ≤ 597) 6px 떨어짐 O · 가방 버튼(y ≤ 169) 11px O · 점프(x ≥ 705) 8px O · 경험치바(y ≥ 287) 5px O · 터치 44 = 하한 딱 맞음.
  - 여유가 거의 없다(가로 94px에 44 × 2 + 6). 54px로 키우려면 체력바나 가방 버튼을 폰에서 옮겨야 한다.
- **안 3 - 54px 유지 + L자** : 점프 위 줄(y 152~206)은 가방 버튼(y ≤ 169)과 겹쳐 불가(점프 위 공간 169~212 = 43px < 44). 따라서 54px 4칸은 체력바 또는 가방 버튼 이동 없이는 BR에 안 들어간다 [계산].
- 대시는 지금 자리(좌측)를 유지하는 것이 설계 의도(점프 오른손 + 대시 왼손 동시 입력 - SkillSlots.lua:24-26 · 86-90, PRD 20.44 [3]). 단 메뉴바와 38 × 24 겹침은 별도 과제.

### 4. 치유사 3+1 버프

- 값: `shared/data/PartyConfig.lua:47` `healerBuffFraction = 0.1736`(17.36%). 옛 24-4 식 값 1.29%는 `healerBuffFormulaFraction`(46행, 기록용 - 게임은 안 읽음).
- "딜러 3 + 치유사 1 = 딜러 4의 100 ~ 105%" 규칙: `PartyConfig.lua:40-45`(주석 - 6조합 버프 뺀 속도 0.8526 ~ 0.8941 → 창 [0.17292, 0.17439]의 가운데) · `:65-66` `healerBuffTargetSpeed = { 1.00, 1.05 }`. 검사: `server/P3dVerify.lua:177` · `server/EconSimReport.lua:337`. 문서: PRD **20.121**(19302행 "6조합 3+1 = 딜러4의 100.1 ~ 104.9%") · `docs/phase/P3d-log.md:11` · `docs/phase/P3d-report.md:10`.
- 적용처: `server/HealCast.lua:89`(`1 + healerBuffFraction`), 툴팁 `SkillStats.lua:90`. 지속 = 치유 쿨 25 × 1.2 = 30초(SkillData.lua:225). 여러 치유사여도 버프는 하나(같은 buffId 덮어쓰기 - PartyConfig.lua:45).

---

## (f) 이동기

### 5. 점프로 피하는 보스 패턴

전부 `primitive = "ring"`(퍼지는 파동). 세 개뿐이다.

| 보스 | 스킬 | 파동 | 속도/두께 | 피해 | 줄 |
|---|---|---|---|---|---|
| 구간 수호자 | shockwave(진동파, 줄넘기 "느림·느림·빠름") | 3박, 박자 간격 1.6 · 1.25 | 24 / 4 | 공격 ×2 | BossData.lua:197-213 |
| 심해 군주 | tide(해일 줄넘기 "두 겹 시간차") | 3박 × 2겹, 간격 1.5 · 1.5, 겹 간격 = 4 ÷ 속도 | 30 · 24 · 18 / 4 | 겹당 ×1 | :474-492 |
| 폭풍 군주 | discharge(방전 고리 "천둥 · 메아리") | 2파(36 → 1.3초 뒤 20) | 36 · 20 / 4 | ×1.5 | :704-715 |

공통: 전조 1.2초 · 보스가 hopHeightStuds 4 떠올랐다 찍기 · `airborneClearanceStuds 0.5`.

**판정 방식** (`server/BossPatterns.lua`)
- `updateWaves`(805-846): 파동 반경 = 경과 × 속도. 플레이어가 띠(반경 − 4 ~ 반경) 안이고, **루트 Y − 파동 지면 Y ≤ 8**(`Reach.sameLayer`, TerrainConfig.heightToleranceStuds) 이고, 단상 위가 아니면(`onDais` 750-764) "닿음". 닿아 있는 동안 **한 틱이라도 공중이면 회피**(827-829), 띠가 완전히 지나간 뒤 회피 기록이 없으면 피해(830-835).
- `isAirborne`(104-122): Humanoid 상태가 Jumping/Freefall이면 즉시 공중, 아니면 루트에서 아래로 레이캐스트해 지면 거리 > HipHeight + 루트 반높이 + 0.5면 공중. **높이 하한 조건은 사실상 0.5stud** - 얼마나 높이 떴는지는 안 본다.
- 체공 요구: 한 번 뛰면 체공 중 어느 순간이든 띠 통과(4 ÷ 24 = 0.17초)와 겹치면 된다 → 입력 창 = 0.54 + 0.17 = 0.71초(BossData.lua:197-199).
- 점프 수치: JumpHeight 7.2(엔진 기본 - 코드가 설정 안 함), 체공 0.54초(`BossData.mechanics.dodge.jumpAirSeconds`, 158 · 164행 - 21-3 실측). 검사기: `shared/BossSkillMath.lua:185-208`(첫 점프 ≥ 인지 0.5 · 다시 뛰기 = 박자 간격 ≥ 0.5 + 0.54 × 1.25 = 1.175 · 겹 통과 ≤ 0.54).
- 관련 지형: P3d 단상(climbable, 윗면 3.5) 위에 선 사람은 파동이 밑으로 지나간다 - 단상은 파동 N회에 금 → 붕괴(BossArenaMapData.lua:63-69, BossPatterns.lua:767-802). 범람(심해 군주 기믹)은 판정 순간 단 위(XZ 상자만 봄 - `BossGimmicks.lua:59-71` · `BossPropMath.insideBox` 87-89)여야 한다 - 점프로 단에 올라가야 한다(climbHeight 3.5 > 계단 2).
- 참고: 다른 모든 바닥 판정(원 · 강타 · 직선 · 돌진 · 마무리)은 **발 기준 높이차 ≤ 8**(BossPatterns.lua:497 · 712 · 1045 · 1254 · 1383 · 1693). P3a D에서 "루트 기준은 점프 정점에서 판정이 빠졌다"는 버그를 고쳐 발 기준으로 바꿨다(PRD 20.118, 19187행).

### 6. 현재 이동 관련 구현

| 항목 | 현재 값 | 근거 |
|---|---|---|
| 대시 | **있음**. 16stud / 0.3초(≈53stud/s) · 쿨 8초 · **무적 아님 - 받는 피해 ×0.5**(0.3초) · 방향 = MoveDirection(없으면 바라보는 방향) · 잡힌 중 불가 | `shared/data/DashConfig.lua` · `server/DashServer.server.lua:32-80` |
| 대시 도착점 | 서버 계산(`server/DashEndpoint.lua`) - 벽 Raycast 1stud 앞 정지 · 지면 4stud 표본 추종 · 경사 한계 넘으면 정지 · 심연은 통과. 시작 발밑에 지면이 없으면(공중) 지면 추종 없이 수평 | DashEndpoint.lua:25-66 |
| **공중 대시** | **이미 있음**(21-3). 클라가 트윈 0.3초로 이동 후 속도 0으로 리셋 → 정점 대시 시 체공 0.54 → ≈0.84초. PRD 20.46 [아] | `client/DashInput.client.lua:72-88` · PRD 5380행 |
| 점프 | JumpHeight 7.2(엔진 기본), 체공 0.54초. 공중 평타는 착지 버퍼 0.3초 | TerrainConfig.lua:47 · BossData.lua:164 · CombatConfig.lua:111-115 |
| 이동속도 | 16 × (1 + 신발 + 신속 옵션) × 출처별 배율(회전베기 0.5 등) | `server/PlayerProfile.lua:43 · 1254-1257 · 1335-1342` · `PlayerState.getMoveSpeedMultiplier`(268) |
| 이동속도 상한 | **없음**. 신속 옵션 `cap = nil`(OptionData.lua:52). 태초 신발 +549% ≈ 104stud/s. 미결로 기록됨 | PRD 20.67 [16] 미결 2(10196행) · 20.81 표 6번(14882행) - F2 |
| 서버 이동 검증(속도·텔레포트 검사) | **없음.** 캐릭터 물리는 소유 클라가 하고, 서버는 WalkSpeed만 넣는다. 대시도 도착점만 서버가 정하고 실제 이동은 클라 트윈(서버는 도착 여부를 검사 안 함). "부정 방지"는 리더보드 클리어 시간뿐 | `server/Leaderboard.lua:12 · 238` · `LeaderboardConfig.lua:43` · DashServer.lua 1-5 |
| 위치 강제 보정(검증 아님) | 보스 아레나 이탈 복귀(③, 아래) · 사냥터 심연 복귀(y < −24, 0.25초 폴링) | `server/TerrainServer.server.lua:7-11 · 62-69` · TerrainConfig.lua:61-62 |
| 공중 판정 신뢰 | `isAirborne`이 클라 복제 Humanoid 상태(Jumping/Freefall)를 믿는다 | BossPatterns.lua:113-116 |

**넉백 이탈 방지 3겹**(P3c A5, 규칙 = `shared/data/BossArenaMapData.lua:148-158` 주석, 수치 159-170):
1. **넉백 상한** - 높이 ≤ 7.5 · 수평 ≤ 12(`ArenaContainment.limitLaunch`, `shared/ArenaContainment.lua:17-29`). 불변식: 가장 높은 발판(큰 블록 윗면 3.5) + 7.5 = 11 < 벽 14(`geometry.wallHeightStuds`, 30행).
2. **경계 안쪽 고정** - 넉백 착지점이 벽에서 3stud 안쪽을 넘지 않게 수평 거리를 자른다(같은 함수 `ArenaShape.clip`, 클라 `BossStormView`가 호출).
3. **복귀** - 서버가 0.25초마다 멤버 위치 검사, 원 밖(허용 2) · 바닥 아래 6 이면 본인 스폰 자리로 순간이동 + 0.75초 보호(피해 0 · 넉백 무시). `server/BossArenaContainment.lua:57-102` · `ArenaContainment.isOutside`(31-39). "①②가 지키면 ③은 한 번도 안 돈다 - 로그 0이 정상"(BossArenaContainment.lua:3). 검증 시뮬 `ArenaContainment.simulate`(정점이 벽 윗면 이상이면 overWall) 1,000회.
- 사냥터 외곽: 보이지 않는 장벽 높이 36(`WorldConfig.lua:242-246` · `HuntingGround.server.lua:59-74`).

### 7. 이단점프 · 공중대시 · 지상 대시의 영향

물리 기준 [계산]: 중력 196.2(엔진 기본 [추정 - 코드가 안 바꿈]), 점프 초속 √(2·196.2·7.2) = 53.1 → 오름 0.27초 · 체공 0.54(데이터와 일치).
- 이단점프(정점에서 두 번째 7.2): 발 최고 14.4 · 체공 0.27 + 0.27 + 0.38 = **0.92초** · 발 높이 > 8인 시간 ≈ **0.51초**.
- 정점 공중대시(현행): 체공 0.84초, 높이 7.2 유지(> 8 없음).
- 이단점프 + 정점 공중대시: 체공 ≈1.22초 · 발 > 8 ≈0.81초.

**점프 패턴별 난이도 변화**

| 패턴 | 이단점프(신규) | 공중대시(현행 · 더 강하게 하면) | 지상 대시(현행) |
|---|---|---|---|
| 진동파 3박(간격 1.6 · 1.25) | **쉬워짐** - 입력 창 0.71 → ≈1.09초(+50%). 한 번에 두 박자는 불가(0.92 < 필요 1.25 − 0.17 = 1.08). **이단 + 공중대시면 2·3박을 한 번에 넘음(1.22 ≥ 1.08) → 부분 파훼** | 쉬워짐 - 창 0.71 → 1.01초. 단독으로는 두 박자 불가 | 무관 - 파동 24가 대시 뒤 0.67초 안에 따라잡는다. 파동 쪽으로 대시해 통과하면 지면이라 맞는다(대시 0.3초 안이면 피해 ×0.5만). 단상으로 빨리 올라가는 데는 도움 |
| 해일 2겹 × 3박(간격 1.5, 속도 30/24/18) | 쉬워짐 - 겹 통과(최대 0.44)는 이미 체공 안. 두 박자 연속은 불가(필요 ≥1.30 > 1.22) | 쉬워짐(여유만) | 무관(위와 같음) |
| 방전 고리 2파(36 → 20, 최소 차 1.48) | 쉬워짐 - 두 파 연속 불가(필요 ≥1.37) | 쉬워짐(여유만) | 무관 |
| (참고) 바닥 판정 전부 - 강타 · 낙석 · 대상 원 · 직선 · 돌진 · 마무리 | **파훼 위험** - 발 높이 > 8(`heightToleranceStuds`)인 ≈0.51초(공중대시 곁들이면 0.81초) 동안 발 기준 판정이 빠진다. 제자리 이단점프로 강타 · 돌진(경로 통과 ≈0.13~0.2초)을 무시 → P3a D가 고친 "점프 정점에서 판정이 빠짐"(PRD 20.118)이 재발하고 "보이는 것 = 맞는 것"이 깨진다 | 현행 공중대시는 7.2에서 유지라 무관. 대시 무적을 추가하면 링 통과 · 돌진 통과가 파훼 | 현행(×0.5) 보너스. 회피 부등식은 대시를 가정하지 않는다(BossData.lua:154 · PRD 20.75 [B] 이동속도 행) - 쿨 단축 · 무적 추가는 부등식에 영향 없지만 난이도는 내려간다 |

**서버 검증 · 이탈 방지 3겹 영향**

| 대상 | 이단점프 | 공중대시(현행) | 지상 대시(현행) |
|---|---|---|---|
| 서버 이동 검증 | 지금 없음 → 깨질 것 없음. 나중에 만들면 허용치: 수직 = 지면 + 14.4(+ 단상 3.5 + 넉백 7.5), 수평 = 16 × (1 + 이속 보너스, 상한 없음 → 최대 ≈104) + 대시 53stud/s 순간, 서버 순간이동(복귀 ③ · 심연 · 입장) 예외 | 이미 트윈을 클라가 함 - 검증 도입 시 "수평 16을 0.3초에" + "공중 정지 0.3초(중력 무시)" 허용 필요 | 같음(16stud/0.3초) |
| 공중 판정 `isAirborne` | 클라 상태 신뢰 그대로. 두 번째 점프를 `ChangeState(Jumping)`로 구현하면 서버도 공중으로 읽음 [추정] | 트윈 중 상태 Freefall → 공중으로 읽힘(PRD 20.46 [아] "자동으로 회피로 읽힌다") | - |
| 판정 높이 상한 8(`TerrainConfig.heightToleranceStuds`) | **깨짐** - "점프로 닿는 높이는 같은 층"(TerrainConfig.lua:47-49) 전제가 14.4로 바뀜. 보스 바닥 판정 회피(위 표) + 사냥터 8 ~ 14.4 높이 절벽 위에 올라가 몬스터 어그로 · 판정 밖(서로 못 때림 - `Reach.sameLayer`) [영향 범위는 지형 데이터 확인 필요 - 추정] | 무관(7.2 유지) | 무관 |
| ① 넉백 상한(3.5 + 7.5 = 11 < 벽 14) | **깨짐** - 넉백 중 이단점프 허용 시 3.5 + 7.5 + 7.2 = 18.2. 넉백 없이도 단상 위 이단점프 = 3.5 + 14.4 = 17.9 > 14, 평지에서도 14.4 > 14로 벽 윗면을 넘을 수 있다 | 현행 공중대시: 단상 위 점프 정점 루트 ≈ 3.5 + 7.2 + 3 = 13.7 < 14 → 대시 Raycast가 벽에 막힘(안전, 여유 0.3). 이단점프와 합치면 루트가 벽 위 → Raycast가 벽을 못 맞혀 **벽 밖으로 16stud 대시** | 무관(벽 Raycast가 막음) |
| ② 착지 경계(벽에서 3 안쪽) | 넉백 착지만 자름 - 넉백 중 추가 점프 · 대시 이동은 안 자른다(DashServer는 잡힘만 막고 넉백 중 대시는 막지 않음 - DashServer.lua:36-40) | 넉백 중 공중대시는 이미 ②를 우회 가능(벽 Raycast가 마지막 방어) | 같음 |
| ③ 복귀(0.25초 폴링) | 그물로는 동작(원 밖 2 넘으면 스폰 자리로). 단 "③ 0회" 불변식 · `ArenaContainment.simulate`의 overWall 검사가 깨진다 → 벽 높이 ≥ 약 22(3.5 + 14.4 + 여유) 올리기 · 투명 천장 · 보스전/넉백 중 이단점프 금지 중 하나가 필요 | 무관 | 무관 |
| 공중 탐지 창 `airborneProbeDownStuds 24`(TerrainConfig.lua:50-53) | 루트 = 지면 + 3 + 14.4 = 17.4(단상 위 20.9) < 24 → 유지 | 무관 | 무관 |
| 회피 부등식 검사기(BossSkillMath) | 점프 회피는 체공 0.54 기준 - 이단점프를 기준에 넣지 않으면 검사기는 그대로. 넣으면 "다시 뛰기" 요구가 0.5 + 0.92 × 1.25 = 1.66초로 늘어 지금 박자(1.25 · 1.3 · 1.5)가 전부 불합격 → 기준은 단일 점프로 유지해야 한다 | 대시는 기준 밖(BossData.lua:154) | 같음 |

### 8. PRD 규칙 정의 절

| 규칙 | 정의 절 | 줄 |
|---|---|---|
| 회피 부등식 | **20.75 [B] "사람이 피할 만하다"를 수식으로**(29-2) - 전조 ≥ 인지 + (거리 ÷ 속도) × 여유, 점프 회피(링) 행 포함 | 12781-12791 (절 머리 12704) |
| 보이는 장판 = 실제 판정 | 독립된 정의 절 없음. 원칙으로 쓰인 곳: 20.73 [1-2](11665 "보이는 것 = 맞는 것" - 십자 회전 폐기) · 20.76 A-6(13236 - 끊긴 직선은 예고 띠도 끊김) · 20.80(14414 "보이는 것 = 되는 것") · **20.118 P3a D 장판 판정**(19187 - 발 기준 높이, 코드 BossPatterns.lua:136-139 `debugJudgeHook` "보인 장판 = 판정" 대조) · 20.122 B3(19363) | - |
| 중앙 금지 구역 | **20.81 [D-2] 화면 영역 고정 지도**(C 행 "영구히 없음. 화면 중앙 40% × 50%") · 코드 ScreenMap.lua:48 · 123 | 15121 · 15147 |
| (참고) 터치 예약 BR · BL | 20.81 [D-2] · 15189 · ScreenMap.lua:107-110 | 15189 |

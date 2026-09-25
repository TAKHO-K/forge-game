# 스테이지 선택 UI - 보스 모델 미리보기(ViewportFrame) + 보상 목록 붙이기 조사

조사 범위: `roblox/src/` 읽기 전용(2026-09-25 작업 트리). 줄 번호는 Read 도구 기준. 확인 못 한 것은 **[추정]**으로 적었다. Studio 실측은 안 했다(MCP 사용 금지 조건).

---

## 1. 현재 구조

### 1-1. StageSelectPanel (`client/StageSelectPanel.lua`)
- 종류: UIManager **station**(`"stageSelect"`, 단축키 M, 딤 없음 · 걸을 수 있음) - `StageSelectPanel.lua:674-685`. 가운데 고정 `AnchorPoint 0.5,0.5 / Position 0.5,0.5` - `:164-174`. ScreenGui DisplayOrder 10 - `:155-161`.
- 크기: 폭 `PANEL_WIDTH = 366`, 높이 `PANEL_HEIGHT = 396`(고정) - `:61`, `:66`. 격자 5열 × 2행 = 10칸(`WINDOW_SIZE`) - `:54-56`. 칸 48 높이 - `:65`.
- 세로 배치(패널 기준 px): 제목 0~32 → 본문 ScrollingFrame(`BODY_TOP 32` ~ 아래 `STATUS_RESERVE 36` 전) - `:82-84`, `:226-235`
  - 범례 36~52 - `:238-265`
  - 구간 칩 띠 56~88(`STRIP_TOP 56`, 높이 32) - `:67-71`, `:269-319`
  - 격자 94~202(`GRID_TOP`) - `:71`, `:323-385`
  - **보상 띠** `BAND_TOP = 210` - `:72`, `:450-457`(폭 `PANEL_WIDTH - 32 = 334`)
  - 페이지 줄(◀ 이전 · 최전선 · 다음 ▶) 328~354 - `:388-427`
  - 상태줄(서버 거절 사유) 아래 34 - `:429-439`
- 보스 칸 클릭 동작: 보스 칸(5의 배수)은 **선택만** → 띠가 채워지고 [도전]을 눌러야 `StageMoveRequest` - `:582-605`. 일반 칸은 바로 이동 요청 - `:600-603`. 선택 칸은 테두리 2px 흰색 - `:501-507`.
- 보상 조회: 창에 보이는 보스 칸(최대 5개)을 `BossRewardPreviewRequest`로 묻고(간격 하한 0.3초) 응답을 `preview[stage]`에 캐시 - `:536-579`. 보스 처치 · 직업 변경 때 다시 묻는다 - `:705-707`.
- 폰 높이 처리: 열 때 `UIManager.fitToScreen(panel, screenGui)` - `:663`. 높이를 (화면 높이 − 2 × 8) 이하로 줄이고 본문만 스크롤 - `UIManager.lua:121-164`, `safeMargin = 8` `:32`.

### 1-2. StageRewardBand (`client/StageRewardBand.lua`)
- 고정 크기 부품. 제목 1줄 + 보상 줄 최대 4개(`MAX_ROWS = 4`) + 도감 점 6개 + [도전] 버튼 - `:25`, `:159-309`.
- 높이 계산 `:160-167`: PC = 제목 18 + 줄 14 × 4 + 도감 32 → **112px**, 모바일(글씨 ×1.15 · 버튼 44) = 제목 20 + 16 × 4 + 44 → **134px**.
- 줄 내용(`describe` `:95-155`):
  1. `첫 클리어 | 장비 1개 확정(영웅 이상 · Lv a~b) [직업]` - 등급표 선택은 **클라가 직접** `RebirthCount`로 고른다(`firstClearGradeTable` `:41-46` - `Loot.rollBossFirstClearDrop` `Loot.lua:191-198`의 분기를 복제).
  2. 방지권 `하락 방지권 ×n · 초기화 방지권 ×n [계정]` (`Enhance.getBossGrant`) - `:110-136`
  3. `매번 | 골드·경험치 20마리분 · 장비 1` - `:138`
  4. 강화석 `강화석 ≈5 · 상급 강화석 ≈5` = `dropChancePerKill × hpMultiplier` - `:139-148`
- 등급 확률은 첫 줄 끝 `HelpToggle`(눌러서 열기, hover 아님)에만 - `:196-205`, `:299-305`.
- 받은 줄은 지우지 않고 흐리게 + "✓ 받음" - `:103-107`, `:129-134`.

### 1-3. 서버 조회 경로 두 개
| 경로 | 파일 | 무엇을 돌려주나 | 클라 사용처 |
|---|---|---|---|
| `BossRewardPreviewRequest/Result`(RemoteEvent 쌍) | `server/BossRewardPreview.lua`, `server/BossRewardPreviewServer.server.lua`, 한도 `shared/data/BossRewardPreviewData.lua`(`maxStages 5` · `minIntervalSeconds 0.3`) | 스테이지별 `{ stage, bossId, gearClaimed, dropTicket, resetTicket }` + 도감 - `BossRewardPreview.lua:56-70`. **확률 · 수치는 안 준다**(받음 여부만) | StageSelectPanel만 |
| `DropTableQuery`(RemoteFunction) | `server/DropTableServer.server.lua`, `server/DropTableQuery.lua`, 계산 `shared/DropTable.lua`, 데이터 `shared/data/DropTableData.lua` | **잡몹 tier(1~6)만** 받는다(`DropTableServer.server.lua:18-21` - 인자가 tier 번호가 아니면 nil). 반환 = 태초 확률 · 등급 분포 · 재료 기대 개수 - `DropTableQuery.lua:17-55` | **없음**(grep 결과 클라 호출처 0 - "UI는 P4" 주석 `DropTableServer.server.lua:1`) |

### 1-4. 폰 배치(800 × 360 기기, ScreenGui 800 × 302)
- 302 높이 근거: `ScreenMap.lua:68` 주석("폰 가로(ScreenGui 높이 302)").
- 패널: 폭 366 그대로 → 화면 x 217~583. 높이 396 → `fitToScreen`으로 **286**(302 − 16), y 8~294. 본문 창 = 286 − 32 − 36 = **218px**, 캔버스 328 → 스크롤(`StageSelectPanel.lua:80-84`).
- 중앙 금지 구역 C = 화면 중앙 40% × 50% - `ScreenMap.lua:48`, `:126` → 폰에서 x 240~560, y 75.5~226.5. **단, 창(window · station · overlay)은 이 표에서 빠진다** - `ScreenMap.lua:15`. 즉 지금 스테이지 패널은 이미 C를 덮고 있고 규칙 위반이 아니다. 새 부품이 **패널 밖 별도 HUD**가 되면 C 규칙을 받는다.
- 모바일 터치 예약: BL = 좌 40% × 하 45%(x 0~320, y ≥ 166), BR = 우 30% × 하 50%(x ≥ 560, y ≥ 151) - `ScreenMap.lua:107-110`. 지금 패널(x 217~583, y 8~294)도 이미 두 구역 모서리에 걸친다(station이라 검사 대상 아님 - [추정: UiSelfCheck가 station을 안 잰다는 것은 `ScreenMap.lua:14-15` 문장 기준, 실제 검사 코드는 안 읽음]).
- 좌측 세로 중앙: 메뉴바 x 14~62(모바일 버튼 48) · 파티 목록 x 70~166(모바일 폭 96) - `ScreenMap.lua:76-80`.

### 1-5. 조사 중 발견한 어긋남(이번 과제와 직접 관련)
1. **모바일에서 보상 띠와 페이지 줄이 16px 겹친다 [추정: 계산값, 실측 안 함]**. 본문 좌표로 띠 = 178 ~ 178+134 = 312, 페이지 줄 = 296~322(`StageSelectPanel.lua:389`). PC는 띠 끝 290 < 296이라 안 겹친다. 미리보기를 띠에 넣으면 이 문제가 커진다.
2. **강화석 ≈ 숫자가 실제 기대값과 다를 수 있다**: 띠는 `dropChancePerKill × units`(`StageRewardBand.lua:143`), 실제 지급은 `× 경험치 배수`(파티 보너스 · 성장 옵션)까지 곱한다 - `CombatResolution.lua:99-100` → `Loot.lua:160-161`. DropTableQuery는 배수를 곱한다(`DropTableQuery.lua:38`). → 단일 소스로 통일하면 자연히 고쳐진다.
3. **"매번 … 장비 1"이 첫 클리어 때 2개로 읽힌다**: 실제는 첫 클리어면 `rollBossFirstClearDrop` **하나만**, 아니면 `rollBossRetryDrop` 하나 - `CombatResolution.lua:160-166`. 띠는 첫 클리어 줄 + "매번 장비 1" 줄을 같이 보인다(`StageRewardBand.lua:108`, `:138`).
4. **재도전 장비 등급(tier1 표: 일반 90% · 희귀 10%)은 어디에도 안 보인다** - `Loot.lua:202-205`, 표 `DropTableData.lua:20`. 띠는 "장비 1"뿐.
5. 골드 · 경험치는 "20마리분"(= `hpMultiplier`)이라는 단위만 보이고 실제 골드 숫자는 없다 - `StageRewardBand.lua:138`. 보스 골드 실값은 `BossRules.buildInstanceDataFrom`(`BossRules.lua:211-`)의 data.goldDrop이고 `MonsterState.getGoldDropFor`가 그대로 쓴다(`MonsterState.lua:319-320`).

---

## 2. 보스 모델을 클라에서 만들 수 있는가

### 2-1. 지금 조립 코드
- `server/MonsterSpawner.lua` `buildModel`(`:118-263`) + `buildAttachments`(`:88-110`). 위치는 **ServerScriptService**(`default.project.json` - `"ServerScriptService": { "$path": "src/server" }`) → **클라는 require 못 한다**.
- 또 이 모듈은 서버 전용 모듈을 끌어온다: `MonsterState`, `GroundProbe`(`:16-17`), RemoteEvent 생성(`:37-39`). 그대로 재사용 불가.
- 보스 외형을 정하는 값은 전부 **shared 데이터**에 있다: `BossData.lua` SPECIES의 `bodyColor · headColor · sizeScale · bodyAspect · attachments`(`BossData.lua:362-782`, 예: 서리 거인 `:379-385`), `BossRules.buildInstanceDataFrom`이 그대로 넘긴다(`BossRules.lua:242-250`).
- 보스 한 마리 = 보이는 파트 **4~5개**(몸통 Part · 머리 Ball · 부착물 2~3개(wedge/block/ball) - 종별 부착물 수 2·2·3·3·3·2) + 투명 루트 · Humanoid · BillboardGui · Highlight. 재질은 기본(Plastic) - 보스용 Material 지정 없음(`MonsterSpawner.lua`의 Material 지정은 상자 · 얼음 구출 대상뿐 `:291-313`, `:554`).
- 서버 조립 뒤 외형을 바꾸는 것은 연출용 클라 View들(BossStanceView 등)인데 미리보기에는 불필요 [추정: 각 View 내용은 안 읽음].

### 2-2. 선택지
| 방식 | 내용 | 장점 | 위험 |
|---|---|---|---|
| **A. 공유 빌더 추출(권장)** | `shared/BossLook.lua`(가칭) = "data → 몸통 · 머리 · 부착물 파트를 발 기준 좌표로 만든다" 순수 함수. `MonsterSpawner.buildModel`의 `:121-124`, `:151-188`, `:259`와 `buildAttachments` 전체를 이 함수 호출로 교체. 클라 미리보기도 같은 함수 | 외형 단일 소스(BossData 한 곳) | 서버 모델 트리가 한 개라도 달라지면 **BossGimmick5Verify가 분신과 보스의 `#GetDescendants()`를 대조**(`BossGimmick5Verify.lua:492-495`) · 구출 대상도 같은 경로(`MonsterSpawner.lua:540-546`). 추출 뒤 인스턴스 이름 · 순서 · 개수 그대로 유지 필수. 호출처 17곳(`MonsterSpawner.spawn` grep)은 안 바뀐다 |
| B. 클라 복제 | 클라에 50줄 안팎 복사 | 서버 코드 안 건드림 | 외형 두 벌 - BossData에 부착물 종류(`kind`)가 늘면 한쪽만 고쳐지는 사고. 프로젝트 규칙("단일 출처") 위반 |
| C. 실제 보스 모델 Clone | 클라가 월드의 보스 모델을 복사 | 코드 적음 | 선택 시점에 그 보스가 월드에 없다(보스 아레나 입장 뒤에만 스폰) - 불가 |

### 2-3. ViewportFrame 제약(공식 문서)
- 공식 클래스 설명(creator-docs 원문): "**No shadows or post-processing effects are rendered**", 기본으로 환경 조명 배율 0(재질이 어둡게 보일 수 있음), **Neon · Glass 재질은 낮은 품질**, "**Nested GuiObjects aren't supported**"(→ 보스의 BillboardGui 이름표는 넣지 않는다), Sky 자식을 두면 반사용 큐브맵으로만 쓴다.
  - https://create.roblox.com/docs/reference/engine/classes/ViewportFrame (원문 yaml: https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ViewportFrame.yaml)
  - 사용법 가이드: https://create.roblox.com/docs/ui/viewport-frames
- 조명은 `Ambient` · `LightColor` · `LightDirection` 세 속성뿐(방향광 1개). 구간 수호자 몸통색(60,20,70)처럼 어두운 색은 Ambient를 올려야 형태가 읽힌다 [추정: 실측 필요].
- 파티클 · Light 객체 미표시: 공식 문서에 명시 문장은 못 찾았고, 개발자 포럼 다수가 보고 - https://devforum.roblox.com/t/viewportframes-not-showing-light-objects-in-parts/2686601 · https://devforum.roblox.com/t/particle-emitter-in-viewportframe/3262784 → 보스 외형엔 파티클 · 광원이 없어서 영향 없음(`MonsterSpawner.lua` 보스 경로에 ParticleEmitter/PointLight 없음, PointLight는 상자 `:318`뿐).
- WorldModel: "BaseParts … can be animated and spatially queried … but those parts are **not** simulated" - https://create.roblox.com/docs/reference/engine/classes/WorldModel . 정지 모델 + 회전(모델 PivotTo 또는 카메라 궤도)이면 **WorldModel 불필요**.
- Highlight: 보스 모델의 `AimHighlight`(`MonsterSpawner.lua:251-257`)는 미리보기 사본에 넣지 않는다(빌더가 파트만 만들면 자연히 빠진다). ViewportFrame 안 Highlight 동작은 [추정: 미확인].
- 성능: 파트 5개짜리 정적 장면 1개라 비용은 무시할 수준 [추정]. 회전 애니메이션을 넣으면 패널이 열려 있고 보스 칸이 선택됐을 때만 RenderStepped 연결(닫힐 때 끊기). 카메라는 `model:GetBoundingBox()` 크기로 맞춘다 - 종별 외형 비가 크게 다르다(서리 거인 몸통 높이 3 × 1.35 × 3.3 ≈ 13.4 · 폭 ≈ 6.7 / 전갈 여왕 높이 3 × 0.65 × 2.8 ≈ 5.5 · 폭 ≈ 8.7 - `BossData.lua:381`, `:592`).

### 2-4. 폰에서 들어갈 크기
- 패널 폭 366 안이면 가로 여유 없음(띠 폭 334, 모바일 줄 머리 70 + 본문 ≈ 260). 보상 줄 옆에 붙이면 본문 폭이 ~190으로 줄어 "장비 1개 확정(영웅 이상 · Lv 360~375) [직업]"(14px) 한 줄이 안 들어간다 [추정: 글자 폭 계산 안 함].
- 폰 본문 창이 218px뿐이라, 세로로 넣으면 **72~96px 정사각**이 현실적 상한(격자 108 + 띠 134 이미 캔버스 328을 채움). PC는 112~128px 정도 [추정].

---

## 3. 보상 목록

### 3-1. 지금 어디에 표시되나
| 보상 | 실제 지급 코드 | 데이터 위치 | 지금 표시 |
|---|---|---|---|
| 첫 클리어 장비(환생 0회 = 상향표 · 1회 이상 = tier6 표) | `CombatResolution.lua:160-166` → `Loot.lua:191-198` | `MonsterData.lua:75-76`(tier6 표를 `shiftGradeTableUp` `:64-73`로 계산) - **DropTableData 밖** | 띠 1줄 + 확률은 도움말 토글(클라가 표를 직접 읽음 `StageRewardBand.lua:41-63`) |
| 재도전 장비(tier1 표 일반 90 · 희귀 10) | `Loot.lua:202-205` | `MonsterData.dropGradeTableByTier[1]` = `DropTableData.armorGradeByTier[1]` | **등급 표시 없음**("장비 1"만) |
| 아이템 레벨 범위 | `Loot.rollItemLevel(stage, ArmorData.bossItemLevelDelta)` | ArmorData | 띠 1줄(Lv a~b) |
| 골드 · 경험치 | `CombatResolution.lua:120-136`(보스 = data 값 그대로) | BossRules 계산 | "20마리분"(단위만) |
| 강화석 · 상급 강화석 | `CombatResolution.lua:140-148` → `Loot.rollMaterialDrops` | EnhanceMaterialData | 띠 4줄(경험치 배수 누락 - 1-5의 2) |
| 하락 · 초기화 방지권(계정 첫 클리어) | `CombatResolution.lua:213` → `ProtectionTickets.grantForBoss` | EnhanceConfig(`Enhance.getBossGrant`) | 띠 2줄 + 받음 여부는 서버 응답 |
| 도감 도장 | `CombatResolution.lua:215` | - | 띠 도감 점 |
- 획득 순간 팝업은 `client/MaterialHud.client.lua`(재료 · 방지권) - 미리보기와 별개.

### 3-2. DropTable 단일 소스로 통일하려면
문제: 보스 드랍 등급표가 `DropTableData` 밖(`MonsterData.lua:59-76`)에 있고, `DropTableData.lua:14`가 "보스(첫 처치 · 재도전) … 은 이 굴림을 안 탄다(결정 9A)"라고 적어 두었다. 클라 띠는 이 표를 **직접** 읽어 서버 분기를 복제한다(`StageRewardBand.lua:41-46`).

필요한 추가(굴림 결과는 한 자리도 안 바꾸는 방향):
1. **데이터** `shared/data/DropTableData.lua`에 `boss = { firstClearSourceTier = 6, firstClearShiftForNoRebirth = 1, retryTier = 1 }` 같은 선언만 추가(숫자 대신 표 참조).
2. **계산** `shared/DropTable.lua`에 `DropTable.bossFirstClearGradeTable(rebirthCount)` · `DropTable.bossRetryGradeTable()` 추가(`shiftGradeTableUp`을 MonsterData에서 이동). `MonsterData.bossFirstClearGradeTable` · `bossFirstClearUpgradedGradeTable`은 **별칭으로 남긴다**(이미 `dropGradeTableByTier`가 같은 방식 `MonsterData.lua:45`) - 사용처 4파일(`StageRewardBand.lua`, `LootRuleVerify.lua`, `MonsterData.lua`, `Loot.lua`)이 안 깨진다. `Loot.lua:192-194`, `:203`은 DropTable 함수를 부르게 교체.
3. **조회** `server/DropTableQuery.lua`에 `describeBoss(playerInfo, stage, rebirthCount, expGainMultiplier)` 추가 → `{ bossId, firstClear = { grades, levelRange }, retry = { grades, levelRange }, killUnits, materials(경험치 배수 포함 - Loot.expectedMaterialCount), tickets = Enhance.getBossGrant }`. `forPlayer`처럼 `forPlayerBoss(player, stage)`가 RebirthCount · 경험치 배수를 서버에서 모은다.
4. **입구**: 두 가지 중 하나
   - (가) `DropTableServer.server.lua:18`의 인자 검사를 `{ bossStage = n }` 표도 받게 확장(같은 RemoteFunction · 같은 0.2초 간격).
   - (나) **기존 `BossRewardPreview.build`(`BossRewardPreview.lua:56-70`) 응답의 entry에 `describeBoss` 결과를 붙인다** - 요청 · 캐시 · 재조회 흐름이 이미 패널에 있어 클라 변경이 가장 적다. 응답 크기는 스테이지당 등급 6줄 × 2 + 재료 2개 정도라 5칸이어도 작다 [추정]. **권장은 (나)**: 받음 여부와 수치가 한 응답이라 "받음 여부는 서버, 수치는 클라 계산"으로 갈라진 지금 구조가 하나가 된다.
5. 클라 `StageRewardBand.describe`는 등급표 · 강화석 식을 버리고 응답 값만 문자열로 바꾼다. selfTest([S11][UI] `StageRewardBand.lua:312-368`)의 합성 entry도 새 필드로 갱신.
- 저장 구조 변경 없음(SAVE_VERSION 불필요). 서버 자동 검증은 "describeBoss 확률 = 실제 굴림 표"를 LootRuleVerify 옆에 한 줄 추가하는 정도.

---

## 4. 붙일 위치 제안

전제(사용자 "읽을거리 많으면 스트레스"): 두 안 모두 **기본 노출은 3줄 이하**(첫 클리어 1 · 재도전 1 · 재료/방지권 1), 확률표는 지금처럼 **눌러서 여는 도움말**(`HelpToggle`)에만 둔다.

### 안 1 - 보상 띠 안에 작은 미리보기(패널 한 장 유지)
- 모양: 띠 제목 줄 왼쪽에 정사각 뷰포트(PC 96 · 폰 72), 그 오른쪽에 보스 이름 + 3줄 요약. 도감 점 줄 · [도전]은 그 아래 그대로. 패널 높이 396 → 약 440(PC) [추정].
- 변경 파일: `shared/BossLook.lua`(신규) · `server/MonsterSpawner.lua`(빌더 호출로 교체) · `client/StageRewardBand.lua`(뷰포트 + 줄 재배치) · `client/StageSelectPanel.lua`(PANEL_HEIGHT · 페이지 줄 위치) · `client/ui/StageSelectCheck.client.lua`(겹침 · 글씨 점검) + 서버 API(3-2의 (나): `BossRewardPreview.lua` · `DropTable.lua` · `DropTableData.lua` · `DropTableQuery.lua` · `Loot.lua`).
- 작업량: **중**(단계 2개 - ① 서버 API 통일 + 띠 문자열(소~중) ② 공유 빌더 + 뷰포트(중)).
- 위험: 폰 본문 창이 218px라 스크롤이 더 길어져 **[도전] 버튼이 스크롤 아래로 숨는다**(지금도 1-5의 1처럼 모바일 겹침 의심). 가로 폭 부족으로 보상 줄이 두 줄로 접히거나 잘림. 중앙 금지 구역은 패널(station) 안이라 규칙상 문제 없음.
- 완화: 폰에서는 뷰포트를 빼고 텍스트만(분기 1줄) - 그러면 폰 위험은 지금과 같다.

### 안 2 - 보스 칸을 누르면 오른쪽 상세 카드(PC) / 격자 자리를 대신하는 카드(폰)
- 모양: PC = 패널 오른쪽 + 8px에 폭 ~220 카드(뷰포트 128 · 이름 · 3줄 보상 · [도전]). 패널 + 카드 = 594px, 화면 가운데 기준 좌우로 늘어난다. 띠는 "보스 칸을 눌러 보세요" 한 줄 또는 제거. 폰 = 800폭에서 594를 펼치면 x 103~697로 **파티 목록(x 70~166)과 BR 터치 예약(x ≥ 560, y ≥ 151)을 덮으므로**, 폰에서는 카드를 패널 **안**에 격자 대신 띄우고 "◀ 목록" 버튼으로 돌아가는 분기.
- 변경 파일: 안 1의 파일 + `client/StageBossCard.lua`(신규 부품) + `client/UIManager.lua` 또는 패널에서 카드 가시성 처리(station 하나로 묶어야 M · X 닫기가 같이 먹는다) + `ScreenMap`에는 등록 불필요(창 취급 `ScreenMap.lua:15`) [추정].
- 작업량: **대**(단계 3개 - ① 서버 API ② 공유 빌더 ③ 카드 + 폰 분기 + 점검).
- 위험: PC에서 가운데 전투 시야를 더 넓게 덮는다(station은 딤 없이 걸을 수 있는 창이라 전투 중 열 수 있다). 폰 분기는 선택 상태 · 뒤로가기 · 재조회 흐름이 두 벌이 된다. 정보량은 카드 한 장에 모여 **안 1보다 한 번에 보이는 글이 적다**(격자와 보상이 동시에 안 보임) - 스트레스 측면에선 유리.

### 참고 - 안 0(최소)
뷰포트 없이 3-2의 서버 통일 + 띠 문자열 수정(재도전 등급 1줄 · 강화석 배수 반영 · "매번 장비 1" 문구 정리)만. 작업량 **소**, 1-5의 2 · 3 · 4를 고친다. 안 1 · 2의 첫 단계와 같으므로 먼저 해 두면 버릴 것이 없다.

### 권장 순서
안 0(서버 API 통일) → 공유 빌더 추출(서버 모델 트리 불변 검증 - BossGimmick5Verify 하위 개수 대조가 그대로 통과하는지) → 안 1(PC만 뷰포트, 폰은 텍스트) → 사용자 체감 확인 후 필요하면 안 2.

---

## 출처(외부)
- ViewportFrame 클래스: https://create.roblox.com/docs/reference/engine/classes/ViewportFrame
- ViewportFrame 원문 yaml: https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ViewportFrame.yaml
- ViewportFrame 가이드: https://create.roblox.com/docs/ui/viewport-frames
- WorldModel: https://create.roblox.com/docs/reference/engine/classes/WorldModel
- 포럼(광원 미표시): https://devforum.roblox.com/t/viewportframes-not-showing-light-objects-in-parts/2686601
- 포럼(파티클 미표시): https://devforum.roblox.com/t/particle-emitter-in-viewportframe/3262784

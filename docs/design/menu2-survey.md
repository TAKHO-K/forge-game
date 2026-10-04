# QUEUE-MENU2 사전 조사 — 저장 분리(계정 키 + 캐릭터 키) 기준 자료

조사일: 2026-10-04 · 범위: `roblox/src` 읽기 전용 조사(코드 변경 없음) · 기준 커밋: `b88f8edd`

목표 구조(사용자 확정): **계정 키 1개**(공유 데이터 + 슬롯 목록 + 보관 목록) + **슬롯마다 캐릭터 키 1개**. 캐릭터 1개 = 직업 1개 고정.

- 캐릭터별: 가방 · 골드 · 장비 · 보석 · 강화 · 레벨 · 경험치 · 환생 · 수련(공용/고급/방어) · 계승/초월 · 스테이지 · 메인 퀘스트 · 직업 옵션 · 쿨 · 궁 게이지 · 위치
- 계정 공유(치장 계열): 도감 진행도 · 점수 · 줄 칭호 · 치장 아이템 · 꾸미기 토큰 · 칭호 전체 · +30 증표 · 펫
- 계정 단위(결제/운영): 게임패스/개발자 상품 권리 · 구매 기록(PurchaseId) · 가방 확장 권리 · 시즌 패스 진행 · 시즌 출석판 · 7일 출석 · 일간/주간 퀘스트 · 설정 · HUD 배치 · 우편함(치장만) · 명예의 전당

> 표기: "추정" = 코드에서 직접 확인하지 못한 판단. 줄 번호는 조사 시점 기준.

---

## 0. 요약 — 지금 구조 한 줄

- 저장 = DataStore `ForgeGamePlayerData_v1`(`shared/data/SaveConfig.lua`) 안의 **키 하나** `Player_<UserId>`(`server/SaveSystem.lua:136`). 프로필 표 하나에 계정 값과 직업별 값(`classes[classId]`)이 같이 들어 있다.
- **현재 SAVE 버전 = 73**(`shared/data/SaveConfig.lua` `saveVersion = 73`). `migrate()` = `server/SaveSystem.lua:479`(로컬 함수 · 블록 v1 ~ v73이 1565줄까지) · 공개 `SaveSystem.migrate = migrate`(1694).
- 기본값: `defaultProfile()` = `server/SaveSystem.lua:193-323` · 직업 칸 `defaultClassState()` = `69-122` · 직업 4개를 `ClassData.order`로 미리 만든다(`defaultClasses` 126).
- "지금 직업" = `profile.classId` 포인터 하나. 직업 데이터 진입점 = `activeClassState(profile)`(`server/PlayerProfile.lua:66`).
- 검사 `isValidProfile` = `SaveSystem.lua:1574-1691` · 손상 고침 `repairProfile` = 1742 · 모르는 id 보관 `quarantineUnknownIds` = 1936 · 매 로드 정리 `sanitizeAll10` = 387.

---

## 1. 저장 필드 전체 목록

지금 범위: **계정** = 프로필 최상위(직업 무관 하나) · **직업별** = `classes[classId]` 아래.
제안 분류: **캐릭터별**(캐릭터 키) · **계정 공유**(계정 키 - 치장 계열) · **계정 단위**(계정 키 - 결제/운영/설정) · **결정 필요**.

### 1-1. 최상위(계정) 필드

| 필드 경로 | 내용(한 줄) | 지금 범위 | 제안 분류 | 근거 · 주의 |
|---|---|---|---|---|
| `version` | 저장 스키마 번호(73) | 계정 | 계정 키 · 캐릭터 키 각각 | 키를 나누면 두 키 모두 버전이 필요(또는 계정 키 버전 하나로 둘 다 이관 - 결정 필요) |
| `savedAt` | 마지막 저장 시각(os.time) - 낙관적 동시성 기준 | 계정 | 두 키 각각 | `saveProfile`의 stale 판정 기준(`SaveSystem.lua:2292-2309`). 키마다 따로 있어야 한다 |
| `sessionId` | 약한 세션 잠금 표식(v55, `""` = 놓음) | 계정 | 계정 키(+캐릭터 키 결정 필요) | 3절 참고 |
| `gold` | 골드 | 계정 공유(19-1 설계) | **캐릭터별** | 규칙상 캐릭터별. 지금 골드 비용이 "계정 최고 스테이지" 기준이라 10절 위험 1 |
| `inventorySlots` | 가방 칸 저장값(기본 20 + 마일스톤 칸) | 계정 | **결정 필요** | 마일스톤 해금(`milestoneUnlocks`)이 `+= entry.bagSlots`로 늘린다(`PlayerProfile.lua:849`). 가방은 캐릭터별인데 이 칸의 출처(환생 마일스톤)는 계정 효과로 설계됨 |
| `bulkSellCutoffGrade` | 일괄판매 기준 등급 | 계정 | 계정 단위(설정) | 설정 성격. 캐릭터별로 둘 이유 약함 |
| `inventoryWindowPosition` | 장비창 위치 `{x,y}` 또는 false | 계정 | 계정 단위(HUD 배치) | |
| `inventory` | 가방 장비 배열(옵션 · 잠금 · 출처 · 세트 · 스킬 변형 · 태초 각인 등) | 계정 공유 | **캐릭터별** | 지금은 직업 사이 장비를 넘기는 통로. 분리 후 옮길 길(창고 등) 없음 - 기존 계정 이관 시 어느 캐릭터에 줄지 결정 필요 |
| `gamepasses` | 게임패스 소유 캐시 `{[key]=true}` | 계정 | 계정 단위 | 진실 = Roblox 소유 기록(`MonetizationService.lua:299-316`) |
| `communityGoal` | 주간 합동 목표 `{week, contributed, claimed}` | 계정 | **결정 필요**(추정: 계정 단위) | 보상이 골드 등이면 어느 캐릭터에 지급할지 |
| `redeemedCodes` | 받은 코드 `{코드 = unix초}` | 계정 | 계정 단위 | 계정당 1회 규칙 유지. 지급은 "지금 캐릭터"로 |
| `weeklyChallenge` | 주간 도전 `{week, rewarded, rankClaimedWeek}`(+best) | 계정 | **결정 필요**(추정: 계정 단위) | 순위 저장소 키 = UserId(`WeeklyChallengeService.lua:103`) |
| `codex` | 도감 v2 `{armor, prim, trans, pet, mkill, msparkle, boss, cls, done, claimed, boardDone, boardClaimed, title}` | 계정 | 계정 공유 | `done[칸]` = 완료 순간 **계정 최고 스테이지**(골드 고정) - 9절 |
| `purchases.optionRerollTickets` | 옵션 변환권(고대/태초) 장수 | 계정 | **결정 필요**(추정: 캐릭터별 - 골드로 사는 강화 계열) | 골드 구매품(로벅스 판매 금지) |
| `purchases.protectionTickets` | 방지권(폐지 · v68에서 0장) | 계정 | 계정(죽은 값) | 키만 남김(id 비활성) |
| `purchases.protectionRefund` | 방지권 폐지 환산 기록(v68) | 계정 | 계정 단위(기록) | `noted` 감사 플래그(`PlayerProfile.lua:305-309`) |
| `purchases.protectionClaimedStages` | 보스 계정 첫 클리어 방지권 받은 스테이지 | 계정 | 계정(죽은 값 추정) | 방지권 폐지 후 쓰임 확인 필요 |
| `purchases.bagSources` | 가방 칸 출처 `{starter=true}`(v69) | 계정 | 계정 단위(가방 확장 권리) | 상품 지급(`MonetizationService.lua:94-100`) |
| `purchases.shopViews` | 상점 연 횟수(스타터 노출 조건) | 계정 | 계정 단위 | |
| `purchases.receipts` | 처리한 PurchaseId 최근 N개(v56) | 계정 | 계정 단위 | 중복 지급 방지의 핵심 - 4절 |
| `purchases.log` | 구매 기록(최근 N줄) | 계정 | 계정 단위 | |
| `purchases.bossCodex` | 기여 10% 이상 처치한 보스 종 도장 | 계정 | 계정 공유 | 도감 계열(표시만) |
| `materials` | 강화석 · 상급 강화석 보유량 | 계정 공유 | **결정 필요**(추정: 캐릭터별 - "강화" 계열) | 도감 · 퀘스트 · 출석 · 시즌 무료 줄이 지급. 사용자 목록에 명시 없음 |
| `classId` | 지금 활성 직업 포인터(nil = 미선택) | 계정 | 캐릭터 키의 고정 직업 + 계정 키의 "마지막 슬롯" | 캐릭터 = 직업 고정이면 포인터 → 슬롯 번호로 바뀐다 |
| `classes` | 직업별 상태 표(1-2) | 직업별 | **캐릭터별**(한 캐릭터 = 한 직업 칸) | |
| `tutorial` | 견습 `{completed, step, granted, lendBaseline}` | 계정 | **결정 필요** | 새 캐릭터마다 견습? `granted`(지급 기록)가 계정이면 두 번째 캐릭터는 보상 없음. `lendBaseline` = 대여 복원 원본(무기 · 장비 - 캐릭터 데이터) |
| `hints` | 안내 플래그(gemMerchantUsed · bossIntroSeen · stealLockSeen) | 계정 | 계정 단위 | 본 적 있음 기록 |
| `world.portals` | 입구 캠프로 연 포탈 | 계정 | **결정 필요** | 탐험 진행 - 캐릭터별이면 새 캐릭터는 다시 연다 |
| `world.bossGates` | 관문 등록 보스(원격 입장) | 계정 | **결정 필요** | 위와 같음 |
| `world.nests` | 둥지별 개인 쿨다운 · 줍기 횟수 | 계정 | **결정 필요**(추정: 계정 - 알 · 펫 계열) | 캐릭터별이면 캐릭터 수만큼 알을 더 줍는다(쿨다운 우회) |
| `world.nestDex` | 처음 찾은 비밀 둥지(칭호 · 꾸미기만) | 계정 | 계정 공유 | 도감 둥지 칸이 이 값을 그대로 읽는다(`CodexRules.lua:4`) |
| `peakLevel` | 역대 최고 캐릭터 레벨(직업 · 환생 무관) | 계정(파생 저장) | **결정 필요** | 나무 정거장 개방(`Travel.lua:563`) · 펫 자동 줍기(`PetData.lua:21`) 기준 |
| `titles` | 칭호 `{[id]=true}` | 계정 | 계정 공유 | 줄 칭호 · 전 서버 최초 칭호 포함 |
| `eggs` | 알 가방(부화 대기 알) | 계정 | **결정 필요**(추정: 계정 공유 - 펫 계열) | 퀘스트 · 도감 · 출석 · 상품이 지급 |
| `audit` | 획득 감사 `{lambda, primordialRolls, playSeconds}` | 계정 | 계정 단위(운영) | 속도 봉투 검사 |
| `training.attack/hp/defense` | 공용 수련 단계(0~50) | 계정 | **캐릭터별** | 사용자 규칙 "수련(공용)". 지금은 계정 - 이관 시 각 캐릭터에 복사? |
| `training.advanced` | 고급 수련(50 ~ 100 · v70) | 계정 | **캐릭터별** | 효과는 초월 무기 직업에만 |
| `training.guard` | 방어 수련(0 ~ 30 · v70) | 계정 | **캐릭터별** | 위와 같음 |
| `transcendGems` | 초월 보석 `{list, seq}` - 계정 귀속 · `socket = {classId, slot}` | 계정 | **결정 필요**(추정: 캐릭터별 - "보석") | 무기 칸엔 사본(`transcendGemId`)만. 진실 = 이 목록. 캐릭터별이면 `socket.classId` 의미가 바뀐다 |
| `quests`(아래 1-3) | 퀘스트 · 출석 · 재화 · 메인 사슬 혼합 | 계정 | **쪼개야 함** | 1-3 참고 |
| `checkpoints.found` | 체크포인트 발견 id | 계정 | **결정 필요** | 메인 퀘스트 조건(`getQuestFacts` checkpoints)이 읽는다 |
| `pets` | 펫 `{list, equipped, hatchCount, hatching}` | 계정 | 계정 공유 | 규칙상 펫 = 공유 |
| `settings` | 설정 `{[SettingsData 키]=값}` | 계정 | 계정 단위 | `skipMenu` 포함(6절) · `windowPositions`(HUD 배치) 포함 |
| `comeback.untilAt` | 복귀 부스트 만료 | 계정 | 계정 단위 | 판정 = 마지막 저장 `savedAt`과 비교(`SaveServer.server.lua:69`) - 키가 나뉘면 어느 savedAt인지 |
| `cosmetics` | 치장 `{themes, gliderSkins, equipped, treeStations, items}` | 계정 | 계정 공유 | `treeStations`(나무 정거장 조각 받은 기록)는 진행 성격 - 확인 필요 |
| `quarantine` | 보관 칸 - 모르는 id 값 `{kind, why, value, classId?, at}` | 계정 | 계정 키 + 캐릭터 키 각각 | 캐릭터 값도 여기 들어온다(`classId` 필드) |
| `mailbox` | 선물함 `{gifts, seq, claimedIds}` | 계정 | 계정 단위 | 허용 = 치장 · 꾸미기 토큰만(`MonetizationData.lua:114`) |
| `seasonPass` | `{season, premium, claimedFree, claimedPaid, skipBought, skipTiers, promptSeason}` | 계정 | 계정 단위 | 무료 줄이 골드 · 강화석 · 보석 가루도 준다(`MonetizationService.lua:86-91`) → 지급 대상 = 지금 캐릭터 |
| `gemDust` | 보석 가루 | 계정 공유 | **결정 필요**(추정: 캐릭터별 - "보석") | 분해로 늘고 재련 · 변환권이 쓴다 |
| `milestoneUnlocks` | 환생 후 해금 마일스톤 받은 개수(가방 칸 · 계승 할인) | 계정 | **결정 필요** | 계정 효과로 설계(`SaveSystem.lua:314`). 가방이 캐릭터별이면 의미가 어긋남 |
| `leaderboardTainted` | /gg가 돈 계정 = 순위 제외 | 계정 | 계정 단위(운영) | |
| `autoProcess` | 줍는 순간 자동 처리 `{enabled, maxGrade}` | 계정 | 계정 단위(설정) 추정 | |

### 1-2. 직업별 칸 `classes[classId]`(`SaveSystem.lua:69-122` + 이관으로 추가된 필드)

| 필드 경로 | 내용(한 줄) | 지금 범위 | 제안 분류 | 근거 · 주의 |
|---|---|---|---|---|
| `characterExp` | 누적 경험치(레벨은 파생) | 직업별 | 캐릭터별 | |
| `weapon.id/level/grade` | 무기 · 강화 단계 · 등급(0~7) | 직업별 | 캐릭터별 | |
| `weapon.enhanceGauge` | 강화 천장 게이지 | 직업별 | 캐릭터별 | |
| `weapon.gems[1..5]` | 보석 칸(false = 빈칸) | 직업별 | 캐릭터별 | 초월 보석은 사본(`transcendGemId`) |
| `weapon.slotUnlocked[1..5]` | 보석 칸 해금 | 직업별 | 캐릭터별 | |
| `weapon.transcend` | 초월 강화 `{level, slot, fails}`(v70 · v71) | 직업별 | 캐릭터별 | |
| `weapon.transcendSlots` | 초월 홈(v72) | 직업별 | 캐릭터별 | |
| `equipment.armor/gloves/shoes` | 착용 장비 3부위 | 직업별 | 캐릭터별 | |
| `stageProgress.infinite / infiniteBest / bestBossCleared` | 지금 · 최고 스테이지 · 최고 보스 | 직업별 | 캐릭터별 | 하드 상한 자르기(`clampStageCap` 2269) |
| `stageProgress.bossFirstClearStages` | 보스 확정 보상 받은 스테이지(문자열 키) | 직업별 | 캐릭터별 | |
| `rebirthCount` | 환생 횟수(0~5) | 직업별 | 캐릭터별 | |
| `gemInventory` | 미장착 보석 보관함 | 직업별 | 캐릭터별 | |
| `milestoneLevel` | 받은 마지막 능력치 마일스톤 레벨 | 직업별 | 캐릭터별 | |
| `abilities` | 직업 고유 능력 단계(v50) | 직업별 | 캐릭터별("직업 옵션" 추정) | |
| `reclaimLevel` | 되찾기 기준 레벨(v46) | 직업별 | 캐릭터별 | |
| `showOwnClothes` | 갑옷 착용 중 내 옷 보이기(v73) | 직업별 | 캐릭터별 | 주석에 "MENU2 때 캐릭터 칸 키로 옮긴다"(`SaveSystem.lua:107`) |
| `transcendInherit` | 초월 계승 기록 `{stage, at, …}`(v70) | 직업별 | 캐릭터별 | `sanitizeAll10`이 매 로드 정리 |
| `bossRotation` | 보스 순환(29-5부터 **아무도 안 읽음**) | 직업별 | 캐릭터별(죽은 값) | 이관 때 버려도 됨 - 결정 필요(지우지 않는 원칙) |
| `milestones` | v32 표 - v33에서 지움 | (없음) | - | 이관 코드만 남음 |

### 1-3. `quests`(한 표에 성격이 다른 값이 섞여 있음 - 반드시 쪼갬)

모양 = `shared/Quest.lua:44-47` `Quest.newState`.

| 필드 경로 | 내용 | 제안 분류 | 근거 · 주의 |
|---|---|---|---|
| `quests.day / daily` | 일간 퀘스트 진행 | 계정 단위 | 규칙 "일간/주간 퀘스트". 진행 조건(처치 수 등)은 어느 캐릭터로 해도 센다 |
| `quests.week / weekly` | 주간 퀘스트 진행 | 계정 단위 | |
| `quests.loginDay / chestDay` | 오늘 접속 보상 · 상자 받은 날 | 계정 단위 | 일간 계열 |
| `quests.main / mainN` | 메인 퀘스트 사슬 단계 · 이벤트 수 | **캐릭터별** | 규칙 "메인 퀘스트" |
| `quests.guide` | 첫 5분 이정표(새 계정만) | **결정 필요** | 캐릭터별이면 새 캐릭터마다 이정표 |
| `quests.attendance` | 7일 출석 `{count, lastDay, claimed}` | 계정 단위 | |
| `quests.board` | 시즌 출석판 `{season, count, lastDay, claimed, bonusDay}` | 계정 단위 | |
| `quests.currencies.sparkleShard` | **꾸미기 토큰**(반짝 조각) | 계정 공유 | 치장 구매 재화(`CosmeticService.lua:4`) |
| `quests.currencies.passExp` | **시즌 패스 경험치** | 계정 단위 | 시즌 패스 진행의 실체가 여기 있다(seasonPass 표 밖) |
| `quests.currencies.rebirthTicket` | 환생 무료권(7일 출석 2일차 · 쓰는 곳 없음) | **결정 필요** | `QuestService.lua:200-203` · "자리" 상태 |

### 1-4. 저장 안 되는 값(런타임 · 참고)

- 스킬 쿨 · 궁 게이지 · 대시 충전 · 버프 · 영혼 상태 · 위치 = 저장 안 함(8절).
- 순위 기록 · 전 서버 최초 · 태초 세계 번호 · 감사 기록 · 선물 대기열 = 별도 DataStore(5절).

### 1-5. 사용자 규칙에 이름이 없는 항목(+30 증표)

- "+30 증표"에 해당하는 저장 필드를 찾지 못했다(`titles` · `codex` · `cosmetics` 어디에도 명시 이름 없음). 추정: 전 서버 최초 초월 칭호(`TranscendFirsts` → `titles`) 또는 아직 없는 기능. **사용자 확인 필요**.

---

## 2. 지금 직업별로 따로인 데이터 vs 공용 데이터

저장 위치: 직업별 = `profile.classes[classId]`(19-1 · SAVE v13부터), 진입 = `activeClassState(profile)`(`PlayerProfile.lua:66`). 활성 직업 전환 = `PlayerProfile.setClassId`(959) - 포인터만 바꾸고 Attribute를 다시 맞춘다(`syncActiveClassAttributes` 242).

| 항목 | 지금 | 위치 | 분리 뒤 |
|---|---|---|---|
| 레벨 · 경험치 | 직업별 | `classes[].characterExp` | 그대로 캐릭터별 |
| 스테이지 | 직업별 | `classes[].stageProgress` | 그대로. 단 "계정 최고 스테이지"(전 직업 최대) 파생값을 여러 곳이 쓴다 - 아래 |
| 환생 | 직업별 | `classes[].rebirthCount` | 그대로. 단 이동 해금(`MoveTier` = 전 직업 최대, `PlayerProfile.lua:71-80`) · 퀘스트 사실 `rebirth`(전 직업 최대, 2758-2761)가 계정 파생 |
| 장비(착용) | 직업별 | `classes[].equipment` | 그대로 |
| 장비(가방) | **계정 공유** | `inventory` | 캐릭터별로 바뀜 |
| 보석칸 · 보석 보관함 | 직업별 | `weapon.gems` · `gemInventory` | 그대로 |
| 초월 보석 | **계정** | `transcendGems`(socket에 classId) | 결정 필요 |
| 보석 가루 · 강화 재료 · 변환권 | **계정** | `gemDust` · `materials` · `purchases.optionRerollTickets` | 결정 필요(추정 캐릭터별) |
| 수련 | **계정**(공용 · 고급 · 방어) / 직업별(직업 능력 `abilities`) | `training` · `classes[].abilities` | 전부 캐릭터별(사용자 규칙) |
| 궁 게이지 | 서버 메모리, **직업과 무관**(직업을 바꿔도 이어짐) | `UltimateService.lua:15` | 캐릭터별(어차피 저장 안 함 - 8절) |
| 쿨 | 서버 메모리, **슬롯 번호 기준**(직업 무관) | `SkillServer.server.lua:63-75` | 8절 |
| 퀘스트 | **계정**(메인 사슬까지 전부) | `quests` | 1-3대로 쪼갬 |
| 직업 옵션 | 직업별 `abilities` · 장비의 `skillVariant` | | 그대로(추정: "직업 옵션" = `abilities`) |
| 순위 기록 | 개인 = UserId 하나 · 직업별 = `class_<직업>` 저장소의 UserId 키 · 카드 = `u<id>_<직업>` | `Leaderboard.lua:3-9` | 같은 직업 캐릭터 2개 허용 시 충돌(5절) |
| 골드 | **계정** | `gold` | 캐릭터별 |

### 계정 파생값("계정 최고 …") 사용처 - 분리 뒤 기준 결정 필요

- `accountBestStageOf`(`PlayerProfile.lua:193`, 전 직업 `infiniteBest` 최대) 사용처:
  강화 비용(`EnhanceService.lua:82, 90`) · 보석 판매가(`PlayerProfile.lua:1332`) · 재련 비용(1391) · 각성(2273) · 장비 계승 비용(2295) · 수련 비용(2669) · 스킬 변형 재굴림(2712) · 옵션 변환권 가격(`GemServer.server.lua:75`) · 도감 골드(`CodexService.lua:127`) · 퀘스트 골드(`QuestService.lua:169`) · 방지권 가격(`ProtectionTickets.lua:32`) · 획득 감사(`AcquisitionAudit.lua:324`) · 클라 Attribute `AccountBestStage`.
- `getAccountBestBossCleared`(`PlayerProfile.lua:635`, 구역 개방 기준) · 스타터 팩 노출(`MonetizationService.lua:357`).
- `maxRebirthOf`(이동 기술 해금 `MoveTier`) · `peakLevel`(나무 정거장 · 펫 자동 줍기).

---

## 3. 세션 잠금 방식

### 키 · 저장소

- 저장소: `DataStoreService:GetDataStore(SaveConfig.dataStoreName)` = `ForgeGamePlayerData_v1`(`SaveSystem.lua:134`).
- 실제 키: `Player_<UserId>`(`profileKey` 136).
- Studio 분리(`studioSuffix` 146-154 · `storeKey` 156):
  - 검증 Play(`DevToolsConfig.verifyArmed`) → `Player_<id>_verify`
  - 그 밖 Studio Play(수동) → `Player_<id>_manual`
  - 라이브 → 접미사 없음
  - Studio 첫 읽기(`readStored` 163-183): 그 키를 `RemoveAsync`로 비우고 실제 키를 **읽기만** 해서 시드로 쓴다(`verifySeeded`). `ReplicatedStorage` Attribute `StudioFreshProfile = true`면 빈 프로필(신규 계정 재현).
  - 운영 도구 키 `opsKey`(2200)도 같은 접미사 규칙.

### 잠금(약한 잠금 · v55)

- 서버 표식 `SERVER_SESSION_ID` = 서버 시작 때 GUID(`SaveSystem.lua:29-31` - Studio의 `JobId`가 빈 문자열이라).
- 저장 때 `profile.sessionId` = 이 서버 GUID, 마지막 저장(퇴장 · 종료 · 파티 이동)은 `""`(놓음) - `markReleasing`(2194) + `saveProfile` 2312.
- 로드 때(`loadProfile` 2099-2180): `heldElsewhere(raw, now)`(2187-2191) = 다른 서버 표식이고 놓지 않았고 `savedAt`이 `sessionLockFreshSeconds`(90초) 안이면 `sessionLockPollSeconds`(2초)마다 다시 읽으며 최대 `sessionLockMaxWaitSeconds`(10초) 기다린다. 안 풀려도 **진행**(막지 않음) - 늦게 온 쓰기는 아래 stale 판정이 막는다.

### 쓰기(낙관적 동시성)

- `saveProfile`(2288-2335): `UpdateAsync` 콜백에서 `old.savedAt > baselineSavedAt`이고 내 메아리가 아니면(`ownEcho` = 같은 savedAt + 내 sessionId) `nil` 반환 = 쓰기 취소 → `"stale_session"`.
- 쓰기 직전 `sanitizeForSave`(NaN/inf 되돌림) · `savedAt = os.time()` · `version` · `sessionId`.
- 재시도: `saveRetryCount = 3` · 대기 `{1, 3, 6}`초.
- `stale_session`이면 그 세션 저장 중단 + 안내(`SaveCoordinator.lua` 140 부근 · `saveSuspended`). 일반 에러는 중단하지 않고 다음 주기에 다시.

### 호출 위치

| 시점 | 위치 |
|---|---|
| 로드 | `SaveServer.server.lua:33-95` `loadForPlayer`(PlayerAdded 97) → `SaveSystem.loadProfile` 34 → 실패 시 `defaultProfile` + 저장 중단 안내(56-60) → `PlayerProfile.init` 62 |
| 자동저장 | `SaveServer.server.lua:118-125`(60초 · `SaveCoordinator.saveForPlayer`) |
| 즉시저장 | `ImmediateSave.request`(스로틀 trailing) · `ImmediateSave.flush`(`ImmediateSave.lua:66`) - 강화 · 직업 선택 · 구매 · 도감 등 |
| 퇴장 | `SaveServer.server.lua:105-115`(markReleasing → flush → `PlayerProfile.clear`) |
| 서버 종료 | `SaveServer.server.lua:130-137` `BindToClose` → `ImmediateSave.flushAllForShutdown`(마감 25초) |
| 파티 서버 이동 | `PartyCrossServer.lua:710-712`(markReleasing → flush → 텔레포트) · 텔레포트 데이터 = `{partyCode}`뿐(736) |
| 공통 처리 | `SaveCoordinator.saveForPlayer`(같은 사람 저장 직렬화 `saving[player]` · 동결 `teleportFrozen` · 중단 `saveSuspended`) |
| 운영 복구 | `SaveSystem.opsListVersions/opsRestoreVersion/opsReadCurrent/opsWriteProfile`(2203-2250) · `OpsRollback.lua` · `OpsServer.server.lua:375`(백업 저장소) |

검증 모듈(분리 때 같이 고쳐야 함): `SaveKeyVerify.lua` · `SaveLockVerify.lua` · `SaveAuditVerify.lua` · `S19bVerify.lua` · `S21_0Verify.lua` 등.

---

## 4. 결제 지급

- `MarketplaceService.ProcessReceipt` = **유일한 콜백** `MonetizationService.lua:579-581` → `MonetizationService.processReceipt`(171-265).
  - 프로필 없음(로드 전) → `NotProcessedYet`.
  - 같은 PurchaseId 처리 중(`inFlight`) → `NotProcessedYet` · 이미 기록(`Monetization.hasReceipt(s.purchases, id)`) → `PurchaseGranted`.
  - 기록 `Monetization.recordReceipt(s.purchases, …, receiptKeep)` → 지급 `applyReward`(44-118) → **즉시 저장 성공 확인**(`ImmediateSave.flush`) 뒤에만 `PurchaseGranted`. 실패 = `captureUndo`(125)로 기록 + 지급을 둘 다 되돌림.
  - 이미 전부 가진 상품 · 지난 시즌 유료 줄 · 칸 건너뛰기 상한 초과 → 꾸미기 토큰 환산.
- PurchaseId 기록 저장 위치: `profile.purchases.receipts`(최근 `MonetizationData.receiptKeep`개) · 구매 로그 `profile.purchases.log`.
  - **주의**: 지급 대상(치장 · 시즌 유료 · 가방 출처 · 토큰)은 전부 계정 쪽인데, 시즌 무료 줄 · 토큰 구매에는 골드 · 강화석 · 보석 가루 · 알 지급 분기가 있다(86-91). 영수증 + 지급이 **같은 키 한 번의 저장**이어야 원자성이 유지된다 → 영수증과 결제 지급물은 계정 키에 둬야 함.
- 게임패스: `refreshPasses`(299-316 · 접속 때 `UserOwnsGamePassAsync`, 실패면 캐시 유지) · 구매 완료 `PromptGamePassPurchaseFinished`(582-603 · 소유 재조회 후 반영) · 판정 `MonetizationService.hasPass`(285). 캐시 = `profile.gamepasses`.
- 가방 확장 권리: 패스 `gamepasses.bagExpand`(+20) + 상품 출처 `purchases.bagSources.starter`(+20) → 칸 계산 `InventorySync.capacity`(`InventorySync.lua:40-53`) · 상한 `maxCapacity`(57-60 = 75 + 마일스톤 칸). 기본 = `SaveConfig.bagBaseSlots`(35) − 20 + `inventorySlots`.
- 선물함: `GiftService`(`server/GiftService.lua`) - 오프라인 대기열 DataStore `Gifts_v1` 키 `u<UserId>` → 접속 때 `profile.mailbox`로 옮김. 허용 = 치장 · 꾸미기 토큰만.

---

## 5. 순위 저장소 키 구조

| 저장소 | 종류 | 키 | 값 | 위치 |
|---|---|---|---|---|
| `ForgeLB_v1[_verify]_s<시즌>_personal` | Ordered | `u<UserId>` | 클리어 보스 스테이지 최고 | `Leaderboard.lua:3, 357` |
| `…_s<시즌>_class_<직업>` | Ordered | `u<UserId>` | `encode(스테이지, 시간)` - 클리어 당시 직업 | 5, 358 |
| `…_s<시즌>_party` | Ordered | `LeaderboardRules.partyKey(UserId들)` | encode | 6, 381 |
| `…_s<시즌>_partyDetail` | 일반 | 같은 파티 키 | 멤버(userId · name · classId) · 기록 | 7 |
| `…_s<시즌>_cards` | 일반 | `u<id>_<직업>` / `u<id>` | 무기 공개 카드 | 8, 280-296 |
| `…_s<시즌>_<종류>_hist` | MemoryStore 해시맵 | 구간 번호 | 인원 수("상위 약 n%") | 126-150 |
| `ForgeLB_v1[_verify]_hall` | 일반 | `s<시즌>` | 명예의 전당(끝난 시즌 상위 100) - UpdateAsync 한 번만 | 75-81, 530-575 |

- 설정 = `shared/data/LeaderboardConfig.lua`(`namePrefix = "ForgeLB_v1"` · 시즌 56일 · `firstSeasonDateKst = nil` 미정 · `topN = 100`).
- 쓰기 = `raiseOrdered`(105-124) `UpdateAsync` "더 클 때만". 자격 `eligibility`(226-) = Studio 수동 Play 제외 · 제외 목록 · `leaderboardTainted` · 직업 없음 제외.
- 명예의 전당(허브 석판) = `server/HallOfFame.lua` → 원본 `PrimordialRegistry`(DataStore `PrimordialWorld_v1` · 태초 세계 번호 카운터 + 최근 목록, UpdateAsync) + 초월 최초 줄.
- 전 서버 최초: `server/TranscendFirsts.lua` - DataStore `TranscendFirsts_v1`(`All10Data.lua:53`) · 키 `launchEpoch:단계`(Studio = `test_` 접두사, 34-40) · `tryClaim`(52-) `UpdateAsync` 선점(이미 있으면 nil). 값 = 사람(userId) 기준.
- 주간 도전 순위: Ordered `WeeklyChallenge_v1[접미사]`(`WeeklyChallengeData.lua:8` · 범위 `"w"..주`) 키 `tostring(UserId)`(`WeeklyChallengeService.lua:19, 103`).
- 그 밖 사람별 키 저장소: `AuditTrail`(키 userId) · `AcquisitionAudit`(`u<id>`) · `SocialRewardService` 초대(쌍 키 · `day_<초대자>_<일>`) · `CommunityGoalService`(합계).

**분리 영향**: 순위 키가 전부 `UserId` 기준이라 "캐릭터"를 구분하지 못한다. 같은 직업 캐릭터를 두 개 허용하면 `class_<직업>`의 `u<UserId>` 한 칸을 두 캐릭터가 나눠 쓴다(큰 값만 남음 · 카드 `u<id>_<직업>`이 덮인다).

---

## 6. ALL9C 메인 메뉴 구조

- 가림막: `roblox/src/first/MenuBoot.client.lua`(ReplicatedFirst) - 접속 즉시 `MainMenuGui`(하늘 그라데이션 + 키 아트) · Attribute `BootClock`.
- 메뉴: `roblox/src/client/MainMenu.client.lua`(866줄) · 값 `shared/data/MainMenuData` · 글 `TextData_menu`.
  - 미리 불러오기 단계 `STEP_RUNNERS`(84-) - `profile` 단계 = `ClassId` Attribute가 생길 때까지(= 저장 로드 끝, 85-89).
  - 이어하기 카드 `MenuContinue`(491-529): 직업이 있으면 "이어하기 + 직업 · 레벨 · 스테이지"(`ClassId` · `CharacterLevel` · `InfiniteStage` Attribute), 없으면 "시작".
  - 버튼: 이어하기(823) · `MenuClasses` 직업 선택(826 → `enter("classes")`) · 설정 · 소식. Enter 키 = 이어하기.
  - `enter(mode)`(760-821): 남은 단계 로딩 막대(상한 `loadCapSeconds`) → `MenuTiming` Remote 측정 → 입력 차단 해제 → 페이드. `mode == "classes"`이고 이미 직업이 있으면 `ClassSelectUI`의 BindableEvent `OpenClassSelect`를 쏜다(810-816). 직업이 없으면 `ClassSelectUI`가 `ClassId == ""`일 때 스스로 연다(`ClassSelectUI.client.lua:431-444`).
  - "다음부터 메뉴 건너뛰기": 설정 토글 `SkipMenuToggle`(633-650) → `SettingSave("skipMenu", v)` → 저장 = `profile.settings.skipMenu`(`SettingsData.lua:25` · Attribute `SkipMainMenu`). 시작 때 `SkipMainMenu == true and hasClass()`면 바로 `enter("continue", true)`(853-860).
  - `DevSkipMainMenu`: Studio에서 `ReplicatedStorage` Attribute `DevSkipMainMenu == true` 또는 `VerifyArmedUntil > os.time()`이면 바로 입장(`devSkip` 842-848).
- 직업 선택 창: `client/ClassSelectUI.client.lua` - 왼쪽 카드 목록 + 오른쪽 무대(`client/ClassStage` 전용 마스코트가 변신 연출) · [다시 보기] · [이 직업으로](`PickButton` 353-358). 처음 고르기 = 확인 없이 `ClassSelectRequest`(183-193), 이미 직업이 있으면 확인창 `ClassConfirmPanel`(요약 = `ClassSummaryFetch`).
- 변신 효과: `client/ClassTransform.lua`(아바타 변신) = **스위치로 꺼짐**(`ClassTransformData.enabled = false`, 사용자 10-03 "아바타마다 깨짐") · 지금 어디서도 `require`하지 않는다. 실제 쓰는 연출 = `ClassStage`(무대 마스코트).
- 분리 영향: 메뉴는 지금 "프로필 로드 = ClassId Attribute"에 기대 있다. 슬롯 선택이 들어가면 **계정 키만 먼저 읽고 메뉴에서 슬롯을 고른 뒤 캐릭터 키를 읽는** 흐름이 필요(지금은 `PlayerAdded` 즉시 전부 읽음).

---

## 7. 게임 안 직업 변경 입구 전부

| 입구 | 위치 | 경로 |
|---|---|---|
| 서버 Remote `ClassSelectRequest` | `server/ClassServer.server.lua:20-22, 46-87` | 검증: 요청 제한(`RequestGate` · `RequestLimitConfig.lua:9`) → 존재하는 직업 → 프로필 로드됨 → 같은 직업이면 무시 → **보스전 막기** → `PlayerProfile.setClassId` → 버프 · 꽂힌 화살 · 분신 정리 → `ImmediateSave.request` |
| 직업 선택 창 [이 직업으로] | `client/ClassSelectUI.client.lua:183-193, 353-358` | 위 Remote |
| 캐릭터 창(C) [직업 변경] `ChangeClassButton` | `client/panels/Character.lua:251-261` | `OpenClassSelect` 발사 |
| 메인 메뉴 [직업 선택] | `client/MainMenu.client.lua:810-816, 826` | `OpenClassSelect` 발사 |
| 첫 선택(ClassId 빈 값) | `ClassSelectUI.client.lua:431-436` | 창 자동 열림 |
| 옛 상시 버튼 `ClassReopenButton` | `client/ui/ScreenMap.lua:98`(자리 표만) | 실제 생성 코드 없음(추정: 제거됨) |
| 설정 문구 `settings.classChange` | `TextData.lua:365` | 문구만 남음(사용처 없음) |
| 개발 `/gg class <직업>` | `DevTools.server.lua:1909-1913` → `applyClass`(292-299) | 보스 막기 없음 |
| 개발 `/gg anim <직업> …` | `DevTools.server.lua:1572-1580` | 직업 자동 전환 |
| 개발 `/gg anchor [직업]` | `DevTools.server.lua:833-835` | |
| 개발 검증 블록(직업 없으면 1번 직업) | `DevTools.server.lua:3732, 3924, 4096, 4203` | `setClassId` 직접 |
| 개발 스냅샷 복원 | `PlayerProfile.restoreForDevTools`(2967 · `profile.classId = snapshot.classId` 2972) | |

- 서버 최종 관문 = `PlayerProfile.setClassId`(`PlayerProfile.lua:959-969`) 한 곳(Remote 검증은 `ClassServer`).
- 보스전 직업 변경 막기: `BossEncounter.classChangeBlocked(player)`(`server/BossEncounter.lua:209-211`, `encounterOf[player] ~= nil`) - 호출 = `ClassServer.server.lua:62` · `TranscendService.lua:222`(계승도 막음). 클라 버튼 비활성 = `ClassSelectUI` `BossEncounterId` Attribute(373-375). 보상 쪽 이중 장치: 입장 직업 기록 `recordEntryClasses`(214-) · `firstClearClassOk`(224-) → `CombatResolution.lua:200-204`.
- 분리 뒤: "직업 변경" = "캐릭터 바꾸기"(다른 캐릭터 키 로드)가 된다. 지금처럼 같은 프로필 안 포인터 교체가 아니므로 **저장 → 언로드 → 로드**가 필요하고, 이 입구들은 전부 "메뉴로 돌아가기/캐릭터 선택" 하나로 모아야 한다.

---

## 8. 쿨 · 궁 게이지

| 항목 | 위치 | 기준 시각 | 저장 | 직업 전환 때 |
|---|---|---|---|---|
| 스킬 쿨(Q/E/R 등) | 서버 `lastCastTick[player][slot]`(`SkillServer.server.lua:63-75`) · 판정 `isOnCooldown` · 길이 `SkillStats.cooldown`(723) | `os.clock()` | 안 함(퇴장 때 지움 795-802) | **안 지움** - 슬롯 번호 기준이라 다른 직업의 같은 슬롯에 쿨이 이어진다 |
| 클라 쿨 표시 | `client/SkillSlots.client.lua`(쿨 링 385-) | 클라 시계 | - | |
| 궁 게이지 | 서버 `gauge[player]`(`UltimateService.lua:15`) · Attribute `UltGauge` | 값(시간 아님) · 변신/표식 만료는 `os.clock()` | 안 함(퇴장 때 지움 315-316) | **안 지움**(이어짐). 보스 입장 때 0(306-312) |
| 대시 충전 | `DashServer.server.lua:45-46` | `os.clock()` | 안 함 | |

- 사용자 규칙 "쿨 · 궁 게이지 = 캐릭터별"은 지금 저장이 없으므로, **저장할지(접속 사이 유지) 결정 필요**. 저장한다면 `os.clock()`은 서버마다 다르므로 `os.time()`/`workspace:GetServerTimeNow()` 기준 남은 시간으로 바꿔야 한다.
- 위치: 저장 필드 없음. 첫 캐릭터만 `Travel.placeFirstSpawn`(`SaveServer.server.lua:85-92`, `isFreshProfile` = `savedAt == 0`). 그 밖 재접속 위치 = 기본 스폰(추정 - 별도 위치 저장 코드 없음).

---

## 9. 도감 보상 · 출석 · 일간/주간

- 도감(`server/CodexService.lua` · 규칙 `shared/CodexRules.lua` · 수치 `shared/data/CodexData`):
  - 칸 완료 순간 `codex.done[칸] = PlayerProfile.getAccountBestStage(player)`(127-135) → **계정 최고 스테이지를 그 순간 고정**.
  - [받기] 골드 = `CodexRules.reward`(`CodexRules.lua:164-193`): `goldKills × goldPerKill(done 스테이지)`(`goldPerKill` = `InfiniteStage.getGoldReward(tier1.goldDrop, stage)`, `CodexService.lua:44-46`) → `GoldCost.niceReward`. 그 밖 강화석 · 보석 가루 · 반짝 조각 · 그 구역 알.
  - 점수판: `scoreOf`(73-) → `CodexData.board` 문턱 넘으면 `boardDone[문턱] = 계정 최고 스테이지`(156-162) · 보상 `CodexData.boardReward`.
  - 줄 완성 = 칭호 즉시 + 꾸미기 토큰(`lineTokens`, 141-150).
  - 분리 영향: 도감은 계정 공유인데 보상(골드 · 강화석 · 보석 가루)은 캐릭터 재화 → **받는 캐릭터 = 지금 캐릭터** + 골드 기준 스테이지 = 계정 최고(지금) vs 받는 캐릭터 최고 결정 필요.
- 7일 출석: `QuestData.attendance`(`shared/data/QuestData.lua:40-48`) - 1일 알 · 2일 **환생 무료권**(`quests.currencies.rebirthTicket` - 쓰는 곳 없음, 39줄 "결정 필요") · 3일 골드 200 + 강화석 5 · 4일 조각 2 · 5일 골드 300 + 강화석 10 · 6일 알 · 7일 골드 500 + 조각 5. 진행 = `quests.attendance`(새 계정만 - 옛 계정은 v53에서 nil). 날짜 넘김 `Quest.roll`(`Quest.lua:50-82`).
- 시즌 출석판: `quests.board`(v67) · 칸 = `SeasonBoardData`.
- 일간/주간: `quests.daily` · `quests.weekly`(날짜/주 바뀌면 비움) · 지급 = `QuestService.grant`(161-) - 골드 = `GoldCost.rewardGold(…, getAccountBestStage)`(169), 강화석 · 알 · 조각 · 패스 경험치.

---

## 10. 위험 · 결정 필요 목록(중요한 순)

1. **"계정 최고 스테이지" 기준 가격 · 보상**(2절 사용처 13곳): 골드가 캐릭터별이 되면, 높은 캐릭터가 있는 계정의 새 캐릭터는 강화 · 수련 · 계승 비용을 높은 스테이지 기준으로 내야 한다(돈은 낮은 스테이지 수입). 반대로 도감 · 퀘스트 보상 골드는 새 캐릭터에 과하게 들어간다. → 기준을 **캐릭터 최고 스테이지**로 바꿀지 결정 필요. EconSim 재검증 대상.
2. **기존 계정 이관(한 프로필 → 계정 키 + 직업 수만큼 캐릭터 키)**: 계정 공유였던 `gold` · `inventory` · `materials` · `gemDust` · `training` · `transcendGems` · `optionRerollTickets`를 어느 캐릭터에 줄지(마지막 직업? 레벨 최고? 나눠서?) 결정 필요. 진행 0인 직업 칸(레벨 1 · 스테이지 1)을 캐릭터로 만들지 버릴지도 결정 필요. 이관은 되돌릴 수 없으므로 옛 키를 지우지 않고 남기는 방식 추천(추정).
3. **세션 잠금이 키 2개로 늘어남**: 지금은 키 하나의 `savedAt`/`sessionId` 비교로 원자성을 지킨다. 계정 키와 캐릭터 키를 따로 `UpdateAsync`하면 둘 중 하나만 써지는 경우(골드는 캐릭터, 영수증은 계정)가 생긴다. → 결제 지급물은 반드시 계정 키에만, 캐릭터 재화를 지급하는 결제/보상(시즌 무료 줄 골드 · 도감 골드)은 순서 · 되돌림 규칙 필요. 잠금 표식을 어느 키에 둘지(계정 키 하나에 두고 캐릭터 키는 계정 잠금을 따른다 - 추정 권장) 결정 필요.
4. **직업 변경이 "캐릭터 교체"가 됨**: 지금은 같은 표의 포인터만 바꾸므로 즉시 반영. 분리 뒤엔 현 캐릭터 저장(성공 확인) → 서버 상태 정리(버프 · 화살 · 분신 · 궁 · 쿨 · 파티 · 보스 · 펫 · Attribute 전부) → 새 키 로드 순서가 필요. 7절 입구 전부를 한 경로로 모아야 하고, 개발 명령(`/gg class` 등)과 검증 블록 수십 곳이 `setClassId`를 직접 부른다.
5. **같은 직업 캐릭터 중복 허용 여부**: 허용하면 순위 저장소 `class_<직업>`의 `u<UserId>` · 카드 `u<id>_<직업>` · `codex.cls[직업]` · 입장 직업 비교(`entryClass[uid]`)가 캐릭터를 구분 못 한다. 슬롯 수 · 중복 여부 결정 필요.
6. **`quests` 표 쪼개기**: 메인 사슬(`main`/`mainN`)은 캐릭터별, 일간 · 주간 · 출석 · 출석판 · 패스 경험치 · 꾸미기 토큰은 계정. `guide`(첫 5분 이정표) · `rebirthTicket`(환생 무료권 - 지금 쓰는 곳 없음) 소속 결정 필요.
7. **가방 칸 출처 섞임**: `inventorySlots`에 환생 마일스톤 칸(계정 효과 `milestoneUnlocks`)이 들어 있다. 가방이 캐릭터별이면 마일스톤 칸은 계정 공통 보너스로 각 캐릭터에 줄지, 그 캐릭터의 환생 진행으로 줄지 결정 필요. 게임패스 · 스타터 칸은 계정 권리로 모든 캐릭터에 적용(규칙대로).
8. **견습(`tutorial`) · 탐험 기록(`world.portals/bossGates/nests` · `checkpoints` · `peakLevel` · 이동 해금 `MoveTier`)**: 사용자 규칙에 이름 없음. 캐릭터별이면 새 캐릭터는 다시 연다(진행감 ↑, 반복 ↑), 계정이면 새 캐릭터가 바로 먼 구역 원격 입장 가능. 둥지(`world.nests`)를 캐릭터별로 하면 캐릭터 수만큼 알 수확이 늘어난다(펫 = 계정 공유와 충돌). 결정 필요.
9. **초월 보석(`transcendGems`)**: "계정 귀속" 목록 + 무기 칸 사본 + `socket = {classId, slot}`. 보석 = 캐릭터별 규칙과 충돌. 캐릭터별로 나누면 소켓 참조 이관 필요, 계정 공유로 두면 "보석" 규칙의 예외. 결정 필요.
10. **재화 소속 미정**: `materials`(강화석) · `gemDust`(보석 가루) · `purchases.optionRerollTickets`(변환권) - 규칙 목록에 이름 없음(추정: 강화 · 보석 계열 = 캐릭터별).
11. **쿨 · 궁 게이지 저장 여부**: 지금 저장 안 함 + 직업 전환 때 이어짐(버그성). "캐릭터별"이 저장까지 뜻하는지 결정 필요. 저장하면 시간 기준을 `os.clock` → 서버 공통 시각으로.
12. **위치 저장 신설**: 지금 위치 필드 없음. 규칙 "위치 = 캐릭터별"은 새 필드(구역/좌표/체크포인트) + 보스 아레나 · 균열 · 공중 위치 처리 규칙이 필요.
13. **복귀 부스트 · 신규 판정 기준**: `grantComebackIfAway`(마지막 `savedAt`) · `isFreshProfile`(`savedAt == 0` → 첫 스폰 허브) - 계정 키 기준인지 캐릭터 키 기준인지(새 캐릭터 = 첫 스폰?) 결정 필요.
14. **"+30 증표"**: 저장 필드를 찾지 못함 - 무엇을 가리키는지 사용자 확인 필요(1-5).
15. **DataStore 예산**: 로드 때 GetAsync가 사람당 1 → 2 이상(계정 + 캐릭터 + 메뉴의 슬롯 요약). 저장도 키 수만큼. `LeaderboardConfig.readBudgetReserve`(30) 근거 계산(`docs/design/save-audit-launch.md` §3)을 다시 맞춰야 한다. 메뉴 슬롯 요약(직업 · 레벨 · 스테이지)은 계정 키의 슬롯 목록에 복사해 두면 캐릭터 키를 다 읽지 않아도 된다(추정 권장).
16. **운영 · 검증 도구**: `opsKey` · `OpsRollback` · `OpsServer` 백업 · `PlayerProfile.snapshotForDevTools/restoreForDevTools`(2916-3030) · `SaveKeyVerify` · `SaveLockVerify` · `S19bVerify` · `_verify`/`_manual` 시드 규칙(키마다 `RemoveAsync` + 실제 키 시드)을 키 여러 개에 맞게 바꿔야 한다. Studio 시드에서 실제 계정 키를 읽기만 하는 원칙 유지 필요.
17. **죽은 필드 처리**: `classes[].bossRotation`(29-5부터 안 읽음) · `purchases.protectionTickets/protectionClaimedStages`(방지권 폐지) · `ClassTransform`(꺼짐) - 이관 때 옮길지 버릴지(지우지 않는 원칙 vs 새 키 정리) 결정 필요.

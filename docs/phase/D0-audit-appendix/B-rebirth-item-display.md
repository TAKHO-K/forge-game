# 감사 (b) 환생 · (h) 아이템 표시 — 읽기 전용 조사

- 기준 커밋: c4ed73b (master). 저장소 파일은 수정하지 않았음. Studio MCP는 쓰지 않음.
- 경로 약칭: `S/` = `roblox/src/`. 줄 번호는 조사 시점 기준.
- [추정] = 코드로 확정하지 못한 추론. [계산] = 코드 공식을 손/파이썬으로 옮겨 계산한 값(게임 안 실측 아님).

---

# (b) 환생

## 1. 환생 시 초기화/유지 항목

서버 경로: 클라 `RebirthRequest`(인자 없음) → `S/server/RebirthServer.server.lua:25-48` → `RebirthAccess.attempt`(`S/server/RebirthAccess.lua:109-122`: 위치(강화대·제단 반경)·보스전 중·강화 중 판정) → `PlayerProfile.rebirth`(`S/server/PlayerProfile.lua:709-772`) → 성공 시 `ImmediateSave.request`(RebirthServer:46).

**환생은 직업별이다** — 모든 변경이 `activeClassState(profile)`(= `profile.classes[classId]`)에 대해 일어난다(PlayerProfile.lua:710-711). 다른 직업의 레벨·환생은 그대로.

| 항목 | 환생 시 | 근거 |
|---|---|---|
| 캐릭터 레벨 / 경험치 | **초기화**(characterExp = 0 → Lv.1) | PlayerProfile.lua:726 |
| 환생 횟수 | +1 | PlayerProfile.lua:725 |
| 현재 스테이지(`stageProgress.infinite`) | **1로 초기화** | PlayerProfile.lua:733 (주석 727-732: "PRD에 명시된 문구 없음 - 임의 결정") |
| 최고 도달 스테이지(`infiniteBest`) | **유지** | 같은 주석 731-732 "건드리지 않는다" |
| 최고 클리어 보스(`bestBossCleared`) | **유지**(rebirth가 안 건드림) | rebirth 본문에 없음. 기록 함수 `setBossCleared` PlayerProfile.lua:627-636 |
| 보스 첫 클리어 보상 기록(`bossFirstClearStages`) | 유지 → 재클리어는 "재도전 드랍"만 | rebirth 본문에 없음. 분기 CombatResolution.lua:~158-166 |
| 리더보드 기준 | 유지(bestBossCleared 기반 "다음 보스"만 기록) | §6 참고 |
| 무기 강화 수치(`weapon.level`) | **유지** | rebirth가 weapon.level을 안 건드림(PlayerProfile.lua:709-772) |
| 강화 게이지 | 유지 | 同 |
| 무기 등급(`weapon.grade`) | **상승**: = 환생 횟수(1~5 → 희귀~고대), 5회 + 5칸 채움이면 6(태초) | PlayerProfile.lua:735, 757-761 |
| 보석 홈 | 이번 회차 홈 해금 + 그 홈 상한 등급 보석 1개 **확정 지급**(itemLevel = 환생 순간 레벨 + 167) | PlayerProfile.lua:740-752, 상한표 `GemData.slotGradeCap = {primordial, epic, legendary, relic, ancient}` (shared/data/GemData.lua:22) — **환생 1회에 태초 보석** 지급 |
| 장착 보석(기존 홈) · 보석 가방(`gemInventory`) · 보석 가루 | 유지 | rebirth 본문에 없음 |
| 착용 장비 3부위(`classState.equipment`) | **유지** | 주석 PlayerProfile.lua:764-766 "장비는 환생으로 바뀌지 않지만" |
| 가방(`profile.inventory`, 계정 공유) | 유지 | 同 |
| 골드 · 강화 재료 · 방지권 · 옵션 변환권 | 유지(계정 층) | rebirth 본문에 없음 |
| 마일스톤(`milestoneLevel`, 직업별) | 유지(리셋 없음). 단 사다리는 환생 5회 뒤에만 열림 | `MilestoneData.requiredRebirths = 5`, firstLevel 200 (shared/data/MilestoneData.lua), `Milestone.isEligible` shared/Milestone.lua:15-17 |
| 계정 해금(`milestoneUnlocks`, 가방 칸 등) | 유지 | 同 |
| "스탯" | 별도 스탯 포인트 시스템 없음. 레벨이 곧 공격력 배율(§3) | PlayerCombat.getAttack shared/PlayerCombat.lua:62-70 |

동기화: `syncActiveClassAttributes` · `InventorySync.push` · `GemSync.push`(PlayerProfile.lua:767-769).

## 2. 환생 조건과 보상

- 필요 레벨: `CharacterLevelConfig.rebirth.requiredLevels = { 25, 50, 75, 100, 125 }` (shared/data/CharacterLevelConfig.lua:235), 조회 `CharacterLevel.getRebirthRequiredLevel` (shared/CharacterLevel.lua:182-184). 최대 5회 `GemData.maxRebirthCount = 5` (GemData.lua:8).
- 거절 사유: `no_class` · `max_rebirth` · `level_too_low`(PlayerProfile.lua:712-723), 자리 밖(nil = 조용히 무시) · `boss_fight` · `enhancing`(RebirthAccess.lua:81-96, 109-116).
- 경험치 배율: `expMultipliers = { 1, 2, 3, 4, 5, 6 }` (CharacterLevelConfig.lua:239) — index = 환생 횟수+1, **캐릭터 경험치에만** 곱함(PlayerProfile.addCharacterExp PlayerProfile.lua:413-434, 재료 기대 개수엔 안 곱함).
- 보상 요약: 무기 등급 +1(×1.45 공격력, ItemVisualData.lua:17-20) · 새 홈 + 상한 등급 보석 1개 · 경험치 배율 상승 · (5회 완료 시) 태초 무기(×9.29) + 마일스톤 사다리 자격.
- 레벨당 처치 목표(곡선 모양): `killTargetAnchors` 1:5 · 25:15 · 50:60 · 75:350 · 100:2500 · 125:20000 (CharacterLevelConfig.lua:206-213), 126+ = 150 (216).
- 최신 시뮬(docs/econ/P3c-after.md:189-191) 환생 1~5회 누적 시간: 캐주얼 2.21·4.63·8.52·13.96·20.58h / 일반 0.84·2.10·4.27·7.83·12.40h / 상위 0.35·0.76·1.40·2.38·3.66h.

## 3. 레벨이 전투력에 주는 영향

### 공식
- **레벨은 공격력에만 들어간다.** `PlayerCombat.getAttack = 무기기본 × 등급배율 × 강화배율 × 직업 × CharacterLevel.getWeaponExpMultiplier(레벨) × (1+공격%) × (1+최종피해) × 마일스톤` (shared/PlayerCombat.lua:62-70).
- `getWeaponExpMultiplier(L)` (shared/CharacterLevel.lua:138-156): L ≤ 25 → `1 + 0.06×(L−1)`(최대 2.44), 26~999 → `2.44 × 1.02^(L−25)`, 1000+ 구간별 감속(CharacterLevelConfig.lua:159-167).
- **HP·방어는 레벨과 무관**: 최대체력 = `(playerMaxHp + 갑옷 maxHpBonus(itemLevel)) × (1+옵션) × 마일스톤HP` (PlayerProfile.lua:1288-1292), 방어 = `(기본 + 갑옷 방어(itemLevel)) × 직업 × (1+옵션)` (PlayerCombat.lua:185-189, PlayerDamage.lua:39-49). 장비 수치는 `itemLevel`로만 큼(Loot.lua:254, 267, 281, 292).
- 몬스터 쪽 레벨 보정 없음: 받는 피해 `PlayerDamage.computeHitDamage`(레벨 항 없음), 주는 피해 `MonsterState.applyDamage`의 attackerStage는 잡몹 HP 스케일용(MonsterState.lua:206-264). 유일한 보정은 **신규 보호**(최고 스테이지 ≤ 20에서 받는 피해 ×0.1→1, CombatConfig.lua:136, PlayerCombat.lua:177-183) — 레벨이 아니라 스테이지 기준.

### Lv.1 vs Lv.N 공격력 비(스테이지 환산 = ln(비)/ln 1.02) [계산]

| 레벨 | 공격 배율 | 스테이지 환산 |
|---|---|---|
| 5 | 1.24 | 10.9 |
| 15 | 1.84 | 30.8 |
| 25 | 2.44 | 45.0 |
| 50 | 4.00 | 70.0 |
| 75 | 6.57 | 95.0 |
| 100 | 10.78 | 120.0 |
| 125 | 17.68 | 145.0 |

비교(같은 눈금): 등급 1단계 ×1.45 = 18.8스테이지 · 강화 +10 ×2.88 = 53.5 · +18 ×6.39 = 93.7 · +24 ×11.4 = 122.8 · +30 ×20 = 151.3 · 태초 무기 ×9.29 = 112.6 (EnhanceConfig.lua:96-128, 보고서 docs/econ/P3c-after.md:268 "출처 하나의 크기"와 일치).

**환생 직후 순손실(무기 등급 +1 반영, 보석·마일스톤 제외)** [계산]:

| 환생 | 직전 레벨 | 직후 공격력 ÷ 직전 | 스테이지 환산 |
|---|---|---|---|
| 1회 | 25 | 0.594 | −26.3 |
| 2회 | 50 | 0.362 | −51.3 |
| 3회 | 75 | 0.221 | −76.3 |
| 4회 | 100 | 0.135 | −101.3 |
| 5회(태초 무기) | 125 | 0.119 | −107.5 |

- **스테이지 40 보스 기준**: 시뮬 E3에서 스테이지 50 도달 시점이 캐주얼 Lv12 · 일반 Lv15 · 상위 Lv4, 스테이지 100이 Lv32/44/21 + 환생1 (P3c-after.md:21-23). 즉 스테이지 40 부근 1회차 플레이어는 Lv.~10 전후 [추정]. Lv.1 vs Lv.10 = 1/1.54(처치 시간 ×1.54), 첫 환생(Lv.25→1, 등급 희귀) 직후 스테이지 40에 돌아오면 공격력 ×0.594 → 보스 처치 시간 약 ×1.68 [계산 - 처치 시간 ∝ 1/공격력, simulateCombat 전 피해가 atk 비례(EconSim.lua:142-144 주석)]. **생존은 변화 없음**(레벨이 HP/방어에 안 들어감). 여기에 환생 1회 지급 **태초 보석**(itemLevel 192)이 공격%를 더하므로 실제 순손실은 이보다 작다 [추정 - 보석 몫은 P3c-after.md:245-265 "보석" 칸 4~12스테이지].
- 시뮬 스테이지 환산표에서도 1~100 구간 공격 합 153~185 중 레벨 몫 37~62, 강화 41~46, 장갑 28~53, 등급 19 (P3c-after.md:245,252,259) — 초반엔 레벨이 가장 큰 단일 출처 아님.
- **장비 착용 레벨 제한: 없음.** `Equip.equipBlockReason`은 직업 유무·아이템 존재만 본다(shared/Equip.lua:1-3 주석 "레벨 · 직업 조건은 서버에 없다", 10-19). `PlayerProfile.equipItem`(PlayerProfile.lua:1376-)도 같은 함수 사용.

## 4. 환생 직후 Lv.1이 직전 보스 스테이지에 바로 가는가 → **솔로는 가능(레벨 조건 없음)**

`StageServer.server.lua` 이동 판정(42-78):
1. `targetStage ∈ [1, infiniteBest + 1]` (56-60) — infiniteBest는 환생에서 유지.
2. `safeStageCap` 34,230 (62-67).
3. 보스 게이트: `BossRules.getBossStageBelow(target) ≤ bestBossCleared` (74-78) — bestBossCleared도 유지.
4. **캐릭터 레벨 검사 없음.** 스테이지 선택 패널이 격자에서 임의 스테이지를 고르게 한다(client/StageSelectPanel.lua:2, 608-625).

→ 환생 직후 Lv.1이 `infiniteBest+1`까지(= 다음 미클리어 보스 포함) 곧바로 이동 가능. `infinite = 1` 초기화는 "시작 위치"일 뿐 제약이 아님.

예외 — **파티 보스**: `BossEncounter.checkPartyEntry`(server/BossEncounter.lua:375-405)가 멤버별 `stage ≤ BossRules.partyEntryStageCap(level)` = `recommendedStage(level,0,false) + partyEntryBand()` (shared/BossRules.lua:90-97) 검사. Lv.1 상한 ≈ 1+167+11 = 179 [계산: solveKillOffset ≈ 167(CharacterLevelConfig.lua:173), band = floor(ln(1+0.8/3)/ln1.02) = 11]. 스테이지 40대에서는 막히지 않음.

보스 간격 5 (`STAGE_INTERVAL = 5`, shared/data/BossData.lua:48).

## 5. EconSim 구조와 what-if 설계

### 구조 (server/EconSim.lua)
- 진입: `/gg econ <프로필> <whatIfName>` (DevTools.server.lua:1193-1199) → `EconSimReport.run({profileArg, whatIfName})` (EconSimReport.lua:982-1044) → 프로필마다 `EconSim.runProgress(id, whatIf)` (EconSim.lua:854-890).
- 상태: `newState` (368-401) — `level, exp, rebirth, weaponLevel, weaponGrade, gear, gems, reach(= 설 수 있는 가장 높은 스테이지 = 게임의 infiniteBest/게이트), seconds …`.
- 한 레벨 = `stepLevel` (660-783): `refresh()`에서 `loadoutFor(state)`(403-414, BalanceSim.buildLoadout — **레벨은 여기서 atk로만 반영**) → `fightBosses` → `chooseHunt`. 가방 점검 주기마다 `checkBag`(478-517) · `tryEnhanceWithGold`(519-553). 레벨업 후 마일스톤·환생(749-758).
- **보스 클리어 판정** `fightBosses` (564-599): `state.reach`의 보스를 `BossRules.buildInstanceData`로 만들고 ① `BalanceSim.getSurviveHits(loadout, boss.attack, newbie) ≥ profile.minSurviveHits` ② `killSeconds(loadout, hp/(bossDpsEfficiency×partySize)) ≤ bossKillLimitSeconds`면 클리어 → 시간·골드·경험치 가산, `state.reach += 5`.
- **사냥 선택** `chooseHunt` (606-656): tier마다 `highestStageByKill`(191-207, 목표 초 안 처치) · `highestStageBySurvive`(209-237, 최소 생존 타수) 중 작은 값, 경험치/초 최선.
- **환생** `doRebirth` (462-474): `level=1, exp=0, weaponGrade=rebirth`, 홈 보석 지급. **`state.reach`는 그대로** — 즉 시뮬은 "환생 후 곧바로 자기 장비로 가능한 최고 스테이지에서 사냥"(게임의 자유 이동과 같은 결과, 재등반 시간 0)으로 모형화.
- **what-if 정의**: 데이터 `shared/data/EconSimConfig.lua:149-157` `whatIfs = { baseline={}, g10195={weaponGrowthRate=…}, dealing087, enhanceHalf, noMilestone, milestoneAttack, milestoneSurvival }`. 적용은 `EconSim.withOverrides(whatIf, fn, …)` (EconSim.lua:60-128) — 키마다 `set(표, 키, 값)`으로 **게임 데이터 표를 양보 없는 구간에서만** 바꾸고 되돌림. `runProgress`가 `stepLevel`을 통째로 withOverrides 안에서 부른다(872).
  - **추가 방법**: ① EconSimConfig.whatIfs에 이름 = { 키 = 값 } 추가 ② withOverrides에 `if whatIf.<키> then set(<표>, "<필드>", …) end` 한 줄 ③ 값이 게임 표에 없는 새 개념이면 `EconSimConfig`에 필드를 두고 set(EconSimConfig, …)로 켠다(선례: `partyExpRequiresPresence` 102-104) → 시뮬 코드가 그 필드를 읽음. 보고서 머리에 whatIf 키가 자동 출력(EconSimReport.lua:1029-).
- **환생 누적 시간 지표: 이미 있음.** `run.rebirthAt[k] = state.seconds` (EconSim.lua:757) → 보고서 `writeLevelPace`(EconSimReport.lua:396-454, "환생 1~5회차(시간)" 칸, 446) · `writeP25cMisc`(884-918, CSV `p25c_rebirth` r1~r5 · 환생 5회까지 레벨업 수/평균 간격). 회차당 소요(차분)와 "환생 후 원래 최고 스테이지 복귀 시간"은 없음.

### what-if ① 레벨차 계수(스테이지−레벨 차만큼 주는 피해↓ · 받는 피해↑)
- 게임엔 개념 없음 → `EconSimConfig.levelGap = nil`(기본 끔) 새 필드, withOverrides에 `if whatIf.levelGap then set(EconSimConfig, "levelGap", whatIf.levelGap) end`.
  값 예: `{ refOffset = 0, dealPerStage = 0.01, takePerStage = 0.02, floor = 0.1, cap = 10 }`.
- **기준 정의 주의**: 레벨→스테이지 척도에 이미 +167 오프셋이 있다(`levelStageOffset`, CharacterLevelConfig.lua:169-173, 앵커 장비 Lv.L이 스테이지 L+167을 2.5초에 잡음). 반면 시뮬 E3에선 스테이지 100에 Lv21~44(P3c-after.md:23) → "스테이지 − 레벨"은 초반 +60~+80, 후반 ≈ 0(Lv9984 @ 10000). 원시 차이를 쓰면 초반 전원이 페널티를 받는다. gap = `stage − (level + refOffset)`에 `max(0, gap − freeGap)` 형태를 권함.
- 헬퍼 1개(EconSim 지역 함수) `gapFactors(level, stage)` → `deal = max(floor, 1 − dealPerStage×g)`, `take = 1 + takePerStage×g`. loadout에 이미 `level`이 들어 있음(BalanceSim.lua:128 `level = level`) → 시그니처 변경 없이 `loadout.level` 사용.
- 바꿀 곳:
  - `highestStageByKill` (EconSim.lua:191-207): 지금은 `hpLimit`로 닫힌식 계산. deal이 스테이지 함수가 되므로 조건을 `getMonsterHp(base, s) / deal(s) ≤ hpLimit`로 바꾸고 선형/이분 탐색(단조 증가 유지).
  - `highestStageBySurvive` (209-237): `ok(stage)`의 incomingDamageMultiplier에 `newbie × take(stage)`.
  - `chooseHunt` 처치 시간(617 `EconSim.killSeconds(loadout, getMonsterHp(...)/dpsEfficiency, 600)`): HP를 `/deal(stage)`.
  - `fightBosses` (570-575): 생존 판정 multiplier에 `× take(bossStage)`, `effectiveHp /= deal(bossStage)`.
  - (선택) `tutorialPhase` (789-842) 견습 스테이지는 고정이라 영향 적음.
  - `maxHpPerAtk` 캐시 키(EconSim.lua:156-176)는 레벨 무관이라 그대로 사용 가능(계수는 HP 쪽에 곱함).
- 게임 실구현 시(참고): 주는 피해 = PlayerCombat.getAttack 이후 적용 지점(AttackServer/SkillServer → MonsterState.applyDamage), 받는 피해 = PlayerDamage.computeHitDamage — 두 곳 + BalanceSim 동일 반영 필요. 데이터는 CombatConfig에(규칙: 수치는 data/).

### what-if ② 현재 스테이지 초기화 + 최고 기록 유지(재등반 강제)
- 현 게임은 이미 "현재 스테이지 1 + 최고 유지"지만 **게이트(bestBossCleared)도 유지라 재등반이 필요 없다**. 시뮬도 reach 유지. what-if는 "게이트까지 초기화, 기록만 유지"로 정의해야 의미가 있다.
- `whatIf.rebirthResetsReach = true` → withOverrides에서 EconSimConfig 플래그로 켬(또는 stepLevel이 이미 whatIf를 받으므로 `doRebirth(state, profile, whatIf)`에서 직접 읽어도 됨 — doRebirth 시그니처에 whatIf 있음, 462).
- 바꿀 곳:
  - `newState`(368-401): `bestReach = reach` 필드 추가.
  - `doRebirth`(462-474): `state.bestReach = max(bestReach, reach); state.reach = BossData.stageInterval`.
  - `reach`의 두 의미를 분리: **게이트**(fightBosses 566, chooseHunt maxStage 674 `state.reach - 1`)는 `reach`, **계정 최고 기준 경제**는 `bestReach` — `tryEnhanceWithGold` 비용(524 `Enhance.getCost(level, state.reach)`), 보석 변환권 가격(446), `primordialRateAt`(357-359), `highestStageBySurvive`의 신규 보호(211 maxStage+1 — 게임은 최고 스테이지 기준), `nextMilestoneRecord`(555-562)와 `runProgress` 종료 조건(871 `while state.reach < cap`).
  - `fightBosses`: 재클리어 시 방지권(`Enhance.getBossGrant`, 587-589)은 게임에서 계정 첫 클리어만(ProtectionTickets.grantForBoss) → `bossStage > bestReach`일 때만 지급.
  - 새 지표: `run.reclimbAt[k]` = 환생 k 후 `reach ≥ bestReach`가 되는 누적 초 → EconSimReport `writeP25cMisc`(884-918)에 열 추가.
- 게임 실구현 시 주의: `bestBossCleared`를 리셋하면 `LeaderboardRules.evaluateClear`의 "다음 보스" 조건(LeaderboardRules.lua:19-43)이 다시 통과해 **같은 스테이지 재클리어가 더 빠른 시간으로 직업 보드를 갱신**(encode(stage, 시간), Leaderboard.lua:~272-276 raiseOrdered) — 기록용 최고와 게이트용 최고를 별도 필드로 둬야 함. 저장 구조 변경이므로 SAVE_VERSION + migrate.

### what-if ③ 장비 착용 레벨 제한
- `EconSimConfig.equipLevelLimit = nil`, whatIf `{ equipLevelLimit = { offset = 167 } }` 같은 형태(허용 itemLevel ≤ `CharacterLevel.getStageForLevel(level)` 또는 level + offset).
- 바꿀 곳:
  - `checkBag` 부위 후보 루프(EconSim.lua:482-496): `item.itemLevel > 한도`면 건너뜀.
  - `chooseHunt` gearMode 후보(636-641): 같은 필터.
  - `doRebirth`(462-474): 레벨 1로 떨어질 때 착용 장비가 한도를 넘는 경우 규칙 결정 필요 — (a) 착용 유지(신규만 막음) (b) 효과를 한도 itemLevel로 깎음 (c) 해제. (b)라면 `loadoutFor`(403-414)에서 `gear[part].itemLevel = min(itemLevel, 한도)` 사본 사용.
  - 보석(`checkBag` 498-515, `doRebirth` 470의 지급 보석)도 제한 대상인지 결정 필요.
- 게임 실구현 시: `Equip.equipBlockReason(inventory, index, hasClass)`(shared/Equip.lua:10-19)에 레벨 인자·이유 코드 추가 → PlayerProfile.equipItem(1376-) · 클라 ItemActions 이유 문구.

## 6. 리더보드 기록 규칙 위치
- 진도 판정(보스 클리어 기준): `CombatResolution.handleBossDeath` 내 `LeaderboardRules.evaluateClear`(server/CombatResolution.lua:227-251) — 오르는 조건 = 도전 스테이지 == `bestBossCleared + 5` **그리고** 본인 피해 비율 ≥ 10%(`contributionRewardThreshold` CombatConfig.lua:109). 규칙 본체 shared/LeaderboardRules.lua:10-43. 오르면 `setBossCleared` · `raiseInfiniteBest`(CombatResolution.lua:245-246).
- 기록 쓰기: `Leaderboard.onBossCleared` (server/Leaderboard.lua:231-302) — personal(스테이지) · class_<직업>(encode(스테이지, 시간)) · party(전원 advanced).
- **이론 최소 시간 부정 방지**: `Leaderboard.onBossCleared` 239-256 — 피해 넣은 모든 멤버·기여자의 `memberDpsCap`(Leaderboard.lua:192-202 → LeaderboardRules.memberDpsCap 64-69) 합으로 `minClearSeconds`(LeaderboardRules.lua:71-81) 계산, 서버 측정 시간이 더 짧으면 `too_fast`로 전부 거절. 시간 = `os.clock() - encounter.startedAt`(CombatResolution.lua:272).
- 자격: `eligibility`(Leaderboard.lua:155-181) — 스탠드인·Studio 수동·제외 계정·UserId≤0·`/gg` 오염(`leaderboardTainted`, PlayerProfile.lua:652-670)·직업 없음 제외.
- 시간 인코딩: LeaderboardRules.encode/decode (45-60).

---

# (h) 아이템 표시

## 7. 등급 목록과 색상, 태초가 흰색으로 보이는 원인

등급 순서: `ArmorData.gradeOrder = { normal, rare, epic, legendary, relic, ancient, primordial }` (shared/data/ArmorData.lua:49). 색 단일 출처 `ItemVisualData.gradeVisuals` (shared/data/ItemVisualData.lua:24-84).

| 등급 | id | RGB | statMultiplier |
|---|---|---|---|
| 일반 | normal | (230,230,230) | 1.00 |
| 희귀 | rare | (77,166,255) | 1.45 |
| 영웅 | epic | (166,77,255) | 2.10 |
| 전설 | legendary | (255,153,51) | 3.05 |
| 유물 | relic | (255,215,0) | 4.42 |
| 고대 | ancient | (224,57,62) | 6.41 |
| 태초 | primordial | **(160,255,250)** + `rainbow = true` | 9.29 |

UI 기본 글자색 `textPrimary = (234,238,245)` (shared/data/UIColors.lua:44). 무지개 시퀀스 ItemVisualData.lua:105-113 (Store.lua:133-141에 사본).

**결론**: "키를 모르는" 조회(nil → 기본색 폴백)는 없었다 — 모든 경로가 `gradeVisuals[gradeId]`를 쓰고 primordial 키가 있다. 원인은 두 갈래:
1. **`rainbow`면 일부러 흰색/기본 글자색으로 바꾸는 분기**가 여러 곳에 있고, 그중 상당수는 무지개 그라디언트를 덧씌우지 않는다 → 순백 또는 textPrimary(일반의 230과 거의 같음).
2. 나머지는 `.color` = (160,255,250)을 그대로 쓰는데, 이 색은 **아주 옅은 청록**이라 작은 글자·Neon 재질에서 흰색으로 읽힌다 [추정 - 특히 땅 드랍의 Neon 파트 + PointLight]. PRD 7998-8010 "[4] 등급색 - 태초가 흰색이라 일반과 구분 안 되던 문제"에서 흰색 → 이 청록으로 바꿨지만 1번 분기들은 그대로 남았다.

| 경로(화면) | 코드 | 태초 표시 | 판정 |
|---|---|---|---|
| 가방 칸 테두리 | Inventory/Store.lua:146-160 `applyGradeVisual` | 흰 stroke + 회전 무지개 UIGradient, 발광 흰색 | 정상(무지개) |
| 가방 칸 아이콘 | Inventory/BagTab.lua:179-180 | **Color3(1,1,1) 순백** | **흰색** |
| 보석 가방 칸 | Inventory/GemBag.lua:82, 90 | 테두리 무지개, 등급 글자는 전 등급 textPrimary | 테두리만 구분 |
| 무기 헤더 아이콘(보석 탭) | Inventory/GemHeader.lua:176-182 | **순백** | **흰색** |
| 보석 홈 번호·점·테두리 · 드래그 유령 | Inventory/GemActions.lua:50-56 `gradeColor` → GemSlots.lua:137, 151, 156-158, GemActions.lua:65 | **순백**(무지개 없음). 1번 홈 상한이 태초라 **항상 흰색** | **흰색** |
| 상세 시트 옵션 게이지 채움 | Inventory/DetailSheet.lua:393-394 | textPrimary | **흰색 계열** |
| 판매/분해 확인창 글자 | DetailSheet.lua:758, 767 | textPrimary | **흰색 계열** |
| 상세 시트 이름·아이콘·테두리(가방/착용/무기/보석) | DetailSheet.lua:494-495, 533-534, 566-567, 595-596, 622-623 | (160,255,250) | 옅은 청록(흰색처럼 보일 수 있음) |
| 장비 탭 착용 칸 테두리·아이콘 | Inventory/GearTab.lua:309-316 | (160,255,250) | 옅은 청록 |
| 보석 재련/분해 창 | panels/GemForge.lua:63-66, 251 | textPrimary | **흰색 계열** |
| 계승 창 | panels/Inherit.lua:64-67, 314-316 | textPrimary | **흰색 계열** |
| 보석상인 리롤 행 | panels/GemWorkshop/init.lua:250, 259 | (160,255,250) | 옅은 청록 |
| 툴팁 제목 | ui/kit/ItemTooltip.lua:64-65 | (160,255,250) | 옅은 청록 |
| 장비 보기(Inspect) | panels/Inspect.lua:260-262 (EquipCompare.lua:205-218) | (160,255,250) | 옅은 청록 |
| 드랍 피드(파티 알림) 아이템 글자 | hud/DropFeed.client.lua:51-55 → Toast partHex(ui/kit/Toast.lua:139-146) | (160,255,250) | 옅은 청록 |
| 태초 서버 배너 | DropFeed.client.lua:82-95 (`rainbow = true` → Toast.lua:447-454) | 테두리 무지개, 글자 청록 | 테두리만 구분 |
| 태초 채팅 1줄 | DropFeed.client.lua:32-35, 99 `DisplaySystemMessage` | 색 지정 없음(채팅 기본색) | **흰색** |
| 줍기 토스트 | hud/SystemToasts.client.lua:39-45 | (160,255,250) | 옅은 청록 |
| 땅 드랍 파트·빛·이름표 | server/ItemDropSpawner.lua:30, 47, 52, 71, 154-156 (Material Neon) | (160,255,250) Neon | 흰색에 가깝게 발광 [추정] |
| 강화창 무기 등급명 | panels/Enhance/Controller.lua:77-82 | 이름만, 등급색 미사용 | 색 구분 없음 |
| 일괄판매 최고 등급 점 | Inventory/BulkSell.lua:139-141, 212 | bulkSellMaxGrade = legendary(ArmorData.lua:55)라 태초 해당 없음 | — |

수정 방향(참고): `rainbow`일 때 순백/textPrimary로 바꾸는 6곳(BagTab:180 · GemHeader:181 · GemActions:55 · DetailSheet:394/767 · GemForge:65 · Inherit:66)을 "무지개 UIGradient 부착" 또는 "태초 전용 진한 색"으로 통일, 그리고 (160,255,250)을 채도 높은 색으로 바꾸는 것 — 한 곳(ItemVisualData)만 바꾸면 2번 갈래 전부가 따라온다.

## 8. 무기·방어구 외형
- **무기 외형은 직업별 1종 + 강화 단계 이펙트만.** `WeaponModelData`의 키는 직업(greatsword · dualblade · bow · healer, shared/data/WeaponModelData.lua:37-97)이고 `grade` 참조 없음. `WeaponVisual.lua`도 등급을 읽지 않고 `WeaponEnhanceVisual.apply(current, WeaponLevel)`만 부른다(client/WeaponVisual.lua:15, 218).
- 강화 단계별 누적 이펙트 `EnhanceVisualData.steps` (shared/data/EnhanceVisualData.lua:18-35): +5 빛 · +10 빛 범위·Trail 폭 ×1.25 · +15 금빛·몸체 금색 틴트 · +19 금 파티클 · +20 불씨색 맥동 · +21 파티클 · +22 외곽선(Highlight) · +23 파티클 위험색 · +24 붉은 빛·Trail · +25 무지개 순환 + 머리 위 "+25" 칭호 + 빛기둥 · +26~29 칭호 글자 · +30 = +25 연출. 적용 client/WeaponEnhanceVisual.lua:294-332.
- **무기 등급(희귀~태초)에 따른 외형 변화: 없음**(UI 아이콘 색만 등급색).
- **방어구: 캐릭터에 입혀지지 않음.** 저장소에 Accessory/Shirt/HumanoidDescription 사용 없음(grep 0건). 방어구 외형은 ① 땅 드랍 단일 파트 모양 `ItemVisualData.partShapes`(armor · gloves · shoes · weapon 4종, ItemVisualData.lua:90-95) ② UI 아이콘 `ItemIcons.byPart`(부위별, 등급은 색만).

## 9. 분해 기준과 보상, 기준 상향의 영향
- **장비 분해 기준 = 영웅 이상**: 서버 `DISMANTLE_MIN_GRADE_INDEX = 3` (server/PlayerProfile.lua:785, 판정 801), 클라 표시용 복사본 `isDismantleEligibleGrade … return i >= 3` (client/panels/Inventory/Store.lua:87-98), 확인창 규칙도 이 함수 사용(DetailSheet.lua:665, 818). **core에 하드코딩**(CLAUDE.md "밸런스 수치는 data/에만" 위반 상태).
- 장비 분해 보상 = 가루가 아니라 **같은 등급 보석 1개**(itemLevel · 옵션 그대로 이전, 재굴림 없음) (PlayerProfile.dismantleItem 787-810, 주석 773-784). 골드는 없음.
- 보석 분해 → 가루: `GemCraft.dustYield = max(1, round(dustYield[등급] × Option.levelFactor(itemLevel)))` (shared/GemCraft.lua:27-33), `dustYield = { epic 3, legendary 5, relic 8, ancient 12, primordial 20 }` (GemData.lua:113), levelFactor = 레벨 100에서 1배 · 1에서 0.14배(GemData.lua:109 주석). 일괄 분해 `dismantleGemsUpTo` (PlayerProfile.lua:866-888). 가루 소모: 재련 refineDust `{4,6,10,15,25}`(116) · 변환권 ticketDust `{ancient 6, primordial 10}`(114). 보석 판매 = 가루 가치 × 0.5 골드(120).
- **전설 이상으로 올릴 때 영향** [계산 - DropTableData.armorGradeByTier(shared/data/DropTableData.lua:19-26)]:

| tier | 영웅+ 드랍 중 영웅 비율(개수) | 가루 기준량 가중 영웅 몫 |
|---|---|---|
| 2 | 100% | 100% |
| 3 | 93% | 89% |
| 4 | 75% | 63% |
| 5 | 54% | 42% |
| 6 | 33% | 20% |

  → 저tier(초반)에선 분해 공급이 사실상 끊기고, tier6에서도 개수 ⅓ 감소. 추가로 **2번 홈 상한이 영웅**(GemData.slotGradeCap[2] = epic)이라, 영웅 보석 공급이 사라지면 2번 홈은 환생 지급 보석 1개로 고정(옵션 교체 불가) — 레벨 올리기는 재련(먹이 등급 무관, GemCraft.refineBlockReason 68-80)으로만 가능.
- **EconSim의 분해 모형 위치**: 보석 공급은 `checkBag`의 `local minGem = gradeIndex("epic")` (server/EconSim.lua:499) → `expectedCandidates(tier, total, minGem, …)` (323-355)로 "기대 개수 ≥ 1인 영웅+ 후보"를 홈에 끼움(500-515). **가루 흐름(분해 → 가루 → 재련/변환권)은 시뮬하지 않음** — 변환권은 골드만 차감(446), 가루는 단가표만 출력(EconSimReport.writeCraftCosts 713-757).
- what-if 추가 방법: ① 기준을 데이터로 이동(예: `ArmorData.dismantleMinGrade = "epic"`) 후 PlayerProfile:785 · Store.lua:90 · EconSim.lua:499가 모두 읽게 → ② withOverrides에 `if whatIf.dismantleMinGrade then set(ArmorData, "dismantleMinGrade", …) end`, EconSimConfig.whatIfs에 `dismantleLegendary = { dismantleMinGrade = "legendary" }`. ③ 가루 경제까지 보려면 checkBag에서 홈에 안 쓰인 후보의 dustYield 합을 `state.dust`로 누적하고, tryPlaceGem 변환권 구매에 `GemCraft.ticketDust` 차감 · 재련(현재 모형 없음) 추가가 필요.

## 10. "영웅 이하 자동 분해/판매 필터" 구현 시 손댈 곳
- **가방 삽입의 유일한 관문**: `PlayerProfile.addArmorDrop` (server/PlayerProfile.lua:1357-1368) — 가득(`#inventory >= inventorySlots`)이면 false. 필터는 **용량 검사보다 앞**에 둬야 가득 찬 가방에서도 처리됨.
- 호출 경로 3개:
  1. 땅 드랍 줍기 `ItemDropServer.tryPickup` (server/ItemDropServer.server.lua:27-45) — 가득이면 땅에 남기고 `InventorySync.notifyFull` 1회(ItemDropState.fullNotified).
  2. 보스 드랍 가방 직행 `deliverBossDropToBag` (server/CombatResolution.lua:65-77) → 가득이면 `deferredBossDrops` → 복귀 후 발밑 드랍 `flushDeferredBossDrops` (82-97).
  3. DevTools(209-233) — 검증용.
- 드랍 생성 지점: `grantKillReward` (CombatResolution.lua:~115-200) — 잡몹은 `ItemDropSpawner.spawn`(땅), 보스는 가방 직행. 알림 `DropNotice.publish`가 그 앞(~188). 필터를 "땅에 아예 안 떨어뜨림"으로 하려면 여기서 분기(연출·파티 알림 유지 여부 결정 필요).
- 기존 설정 선례: 일괄판매 기준 `profile.bulkSellCutoffGrade` · `setBulkSellCutoffGrade` · 상한 `ArmorData.bulkSellMaxGrade = "legendary"` (PlayerProfile.lua:1603-1644, 1567-1601; ArmorData.lua:55). 자동 필터 설정도 같은 계정 층 필드로 두되 **저장 구조 변경 → SAVE_VERSION + migrate**(CLAUDE.md 규칙).
- 규칙 충돌 주의: 분해는 영웅 이상만 가능 → "영웅 이하 자동 분해"는 실제로 일반·희귀 = 자동 판매, 영웅 = 자동 분해(보석)로 나뉜다. 분해 기준을 전설로 올리면 영웅도 자동 판매 대상.
- 잠금(`item.locked`)·착용품 제외 규칙은 sellItemsBulkUpTo 주석(PlayerProfile.lua:1556-1566)과 동일하게 — 새로 줍는 아이템은 잠금이 없으므로 줍는 순간 필터는 단순.
- 클라: 설정 UI(Inventory/BulkSell.lua 옆), 줍기 토스트(SystemToasts ItemPickedUp)가 "자동 판매됨"을 구분해 보여줄 경로 필요.

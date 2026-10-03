# 영역 감사: 전투 · 피해 공식 · 서버 판정 (combat)

감사 범위: `roblox/src/server/AttackServer.server.lua`, `SkillServer.server.lua`, `CombatResolution.lua`, `MonsterState.lua`, `PlayerDamage.lua`, `PlayerState.lua`, `MonsterAI.server.lua`(피해 부분), `MonsterSpawner.lua`(despawn · HP 표시), `BossEncounter.lua`(퇴장 · 재접속 · 리셋), `DashServer.server.lua`, `HealCast.lua`, `HealerDealingMode.server.lua`, `PlayerShield.lua`, `RangedLagAssist.lua`, `UltimateService.lua`(cast · onDealt만), `shared/CombatFormula.lua`, `PlayerCombat.lua`, `SkillCombat.lua`, `Reach.lua`, `AimPicker.lua`, `BossRules.lua`, `InfiniteStage.lua`, `MobShare.lua`(applyRatio · eligible), `data/InfiniteStageConfig.lua`, `data/MonsterData.lua`, 하네스 `tools/harness/attack_test.luau` · `multiplayer_test.luau`.
읽기 전용 감사 — 저장소 파일은 하나도 고치지 않았다(`git status` = 기존 `p2play2.log`만).

---

## (1) 즉시 확인(치명)

**치명 등급 결함은 찾지 못했다.** 확인한 핵심 항목:

- **처치 보상 이중 지급**: 막혀 있다. 모든 처치 경로(평타 근접 · 원거리 도달 · 환영 추가타 · 스킬 · 덫 · 궁극기)가 `CombatResolution.resolveHit`(CombatResolution.lua:463)를 지나고, 여기서 `MonsterState.tryClaimDeath`(MonsterState.lua:715 — 확인과 표시 사이에 양보(yield) 없음)가 첫 번째 사망 판정만 통과시킨다. 같은 프레임에 두 타격이 동시에 죽여도 두 번째는 CombatResolution.lua:475에서 돌아간다. `ImmediateSave.request`가 더는 양보하지 않으므로(ImmediateSave.lua:44-46 `task.spawn`) 보상 루프 도중 끼어들 틈도 없다.
- **보스 보상: 나갔다 다시 들어오기**: 이중 지급 경로가 없다. 기여는 퇴장 때 `carried[userId]`로 맡겨지고(MonsterState.lua:553-556), `takeCarriedContribution`이 한 번 꺼내면 지운다(546). 재접속(BossEncounter.lua:872-892)은 같은 서버의 파티 보스전에서만 되고, 옛 Player의 기여를 새 Player로 옮긴 뒤 옛 항목은 지운다(885-887). 전멸 리셋 뒤에는 `resetGen`이 달라져 옛 기여가 무효가 된다(MonsterState.lua:187, 548).
- **클라가 보낸 피해 · 대상**: 믿지 않는다. 평타 · 스킬 모두 클라는 의사와 조준점만 보내고, 사거리 · 대상 · 쿨다운 · 피해는 서버가 계산한다. 조준점은 NaN이나 먼 값을 거른다(AttackServer.lua:329, SkillServer.lua:532, UltimateService.lua:167).
- **NaN · inf**: 플레이어가 받는 피해는 출구마다 `Sanitize`를 거친다(PlayerDamage.lua:50, 182). 몬스터가 받는 피해 쪽에는 출구 검사가 없지만, 지금 입력(공격력 `Sanitize` · 배율 함수들)으로는 NaN이 생기는 경로를 찾지 못했다 → 아래 (2)에 낮음으로 적었다.
- **큰 수**: 설계 최대 스테이지 25,300(`hardMaxStage`, InfiniteStageConfig.lua:79)에서 잡몹 HP ≈ 80 × 1.02^25299 × 1.35 ≈ 10^220이다. 2^53을 훨씬 넘지만 1e308 안이다. 잡몹은 비율 HP(0~1)라 절대값 정밀도와 무관하고, 보스는 `hp -= damage`의 상대 정밀도(약 1e-16)만 쓴다. 골드는 1.001^S라 작다(≈ 1e11). 넘침 · NaN 위험은 없다.

치명은 아니지만 먼저 볼 것 3가지(자세한 내용은 (2)):
1. **덫 · 활 궁극기로 구역 밖에서 안전하게 사냥 가능**(중간) — 19-4 "구역 밖 공격 차단"을 우회한다.
2. **보물상자 · 막힌 타격으로 궁극기 충전과 흡혈 가능**(중간~낮음).
3. **보스 HP를 곱하는 곳이 BossRules 밖에 있음**(단일 소스 위반, 다음 리팩터 입력) — BossEncounter.lua:383 등.

---

## (2) 버그 표

| 심각도 | 파일:줄 | 재현 | 영향 | 고치는 방법 | 예상 시간 |
|---|---|---|---|---|---|
| 중간 | SkillServer.server.lua:531-557, 566 (`castHunterTrap` · 덫 Heartbeat `filterSameZone(trap.position, …)`) | 활 직업으로 구역 담장 바깥(구역 판정 밖)에 서서, 안쪽 40 stud 안 지점에 R(사냥꾼의 덫)을 설치한다. 조준점의 높이(Y)는 검사하지 않고, 시야(벽)도 검사하지 않는다. 몹이 덫을 밟으면 피해 · 속박이 들어가고, 그 피해가 처치를 내면 보상도 받는다. | 몹이 쫓아올 수 없는 자리에서 쌓는 기여 · 처치. AttackServer.lua:355-361이 막으려던 "입구에 서서 안쪽을 쏘는" 행위가 그대로 열린다. 쿨다운이 20초라 피해량은 제한적이다. | 설치 순간 `ZoneBounds.isInside(rootPart.Position, 덫 자리의 zoneKey)`와 시전자 → 조준점 Raycast를 검사한다. 발동 순간에도 시전자 위치로 `filterSameZone(시전자 위치, …)`를 한 번 더 적용한다. | 1시간 |
| 중간 | UltimateService.lua:167, 215, 224 (`hitsInCircle(center, …, candidates(center))`) + SkillServer.server.lua:150-152 | 활 궁극기(화살비)를 구역 밖에서 조준점만 구역 안(최대 70 stud, UltimateData.lua:31)으로 찍는다. 구역 필터가 시전자가 아니라 조준점 기준이다. | 위와 같다(구역 밖 안전 사냥, 벽 너머). 지속 틱마다 시전자 위치를 다시 검사하지 않는다. | 구역 필터 기준을 시전자 위치로 바꾸고(`candidates(rootPart.Position)`과 교집합), 조준점까지 시야 Raycast를 추가한다. | 1시간 |
| 중간 | MonsterState.lua:401-409 (상자는 무시된 타격도 `false, damage` 반환) + AttackServer.lua:480-482 · SkillServer.lua:108-113 (`applyLifesteal` · `UltimateService.onDealt`) | 보물상자를 연타한다(상자 유효 피격 간격 안의 타격). 상자는 횟수만 세고 그 타격은 버리지만, 반환값 `dealt`가 넘긴 피해 그대로라 흡혈과 궁극기 충전(대검 · 치유사 = 피해 비례)이 정상 몹을 칠 때처럼 들어간다. | 상자 앞에서 안전하게 궁극기를 충전하고 체력을 회복한다. 흡혈은 초당 상한(PlayerState.tryLifesteal)이 있어 영향이 작다. | 상자 분기의 반환을 `false, 0`(또는 유효 피격일 때만 상징값)으로 바꾼다. 데미지 숫자 표시가 필요하면 표시용 값을 따로 돌려준다. | 30분 |
| 낮음 | UltimateService.lua:63-73 (`onDealt` 쌍검 · 활 = `perHit`, `dealt` 무관) | 막힌 몹(스틸 불가 — 피해 0) · 보호막 보스(`taken = 0`) · 진입 연출 중 보스 · 구출 대상을 쌍검 · 활로 친다. | 피해 0 타격으로도 궁극기 게이지가 찬다. | `onDealt` 앞에서 `dealt > 0`일 때만 충전하도록 호출부 3곳(AttackServer 482 · 610, SkillServer 112)이나 `onDealt` 안을 고친다. | 20분 |
| 낮음 | CombatResolution.lua:299, 437 (`target.PrimaryPart.Position`) | 처치 순간 모델의 PrimaryPart가 없으면(파트 소실 등) `tryClaimDeath` 뒤에 에러가 난다. | 이미 claimed 상태라 `despawn`이 영영 안 불린다. 잡몹은 그 슬롯이 다시 생기지 않고, 보스는 encounter가 끝나지 않는다. 보상 루프 중간 에러(`grantKillReward` 내부)도 같은 결과다(뒤 기여자는 보상을 못 받는다). | 위치는 `PrimaryPart and … or model:GetPivot().Position`으로 받는다. 보상 루프는 기여자마다 `pcall`로 감싸고 `despawn`은 항상 실행한다. | 30분 |
| 낮음 | CombatResolution.lua:193, 230 (`DropTable.gainOnly` 전역 플래그) | `Loot.roll*`이 에러를 내면 230줄(`gainOnly = false`)이 실행되지 않는다. | 그 뒤 다른 플레이어의 굴림도 "첫 환생 전 = 이득만" 규칙으로 굴러간다(전역 상태 누수). | 인자로 넘기거나 `pcall` 뒤 항상 되돌린다. | 20분 |
| 낮음 | MonsterAI.server.lua:463, 473 (`PlayerState.getHp(member) > 0`) | 보스 멤버의 PlayerState 항목이 없으면 nil 비교 에러가 난다(다른 곳은 `or 0`을 쓴다 — 447, 497). | Heartbeat 루프에 `pcall`이 없어(567) 그 프레임의 나머지 몹 처리가 끊긴다. 지금은 퇴장 핸들러가 같은 프레임에 멤버를 빼므로 재현 경로를 찾지 못했다 → **확인 필요**. | `(PlayerState.getHp(member) or 0) > 0`으로 통일한다. | 10분 |
| 낮음 | PlayerState.lua:249 + BossEnvironment.lua:480 · DevTools.server.lua:3303 | 0배 출처(`"bossRocket"` · `"devGod"`)를 `setIncomingDamageMultiplierUntil(…, 0, …)`로 건다 → 하한 `incomingDamageMultiplierFloor = 0.25`(CombatConfig.lua:105)에 막혀 0.25배가 된다. | 로켓은 PlayerDamage.lua:64의 `isRocketing` 면역이 따로 있어 실제 피해는 없다(죽은 코드). `/gg god`은 메모리에 적힌 대로 고스테이지에서 한 방에 죽는다. 설계 주석(CombatConfig.lua:104 "완전 무적은 setInvulnerableUntil")과 어긋난다. | 두 곳 모두 `PlayerState.setInvulnerableUntil`로 바꾼다. | 20분 |
| 낮음 | MonsterState.lua:305-424 (몬스터 피해 출구에 `Sanitize` 없음) | 지금은 재현 경로가 없다. 앞으로 새 배율이 NaN을 내면 `hpRatio`/`hp`가 NaN이 된다. | NaN 몹은 `<= 0`이 영원히 거짓이라 죽지 않는다. HP바도 NaN이 된다. 플레이어 쪽(PlayerDamage.lua:182)과 대칭이 아니다. | `applyDamage` 맨 앞에서 `damage = Sanitize.number(damage, 0)`을 적용하고, 음수도 0으로 자른다. | 10분 |
| 낮음 | SkillServer.server.lua:164-168 (`castLineAttack` — 바라보는 방향이 0이면 그냥 return) + 744 (`markCast`가 먼저) | 수평 바라봄이 없는 순간 Q를 쓰면 쿨다운만 쓰이고, 결과 이벤트가 안 가 클라 슬롯이 어긋난다. | 드문 경우다. 쿨다운만 버려진다. | 방향 검사를 `markCast` 앞으로 옮기거나 `reject`를 보낸다. | 10분 |
| 낮음 | AttackServer.server.lua:271-300, 358-361 | 구역 밖에서 공격하면 쿨다운 · 콤보 증가 · 남의 화면 모션 중계(306)가 먼저 일어나고 그다음에 차단된다. | 차단된 공격도 모션이 남에게 보이고 콤보가 쌓인다(3타 강공격 자리를 미리 소모할 수 있다). | 대상 선정 직후로 구역 검사를 앞당긴다(모션 중계 전). | 20분 |
| 낮음 | DashServer.server.lua:35-53 | 영혼(SoulService) 상태에서 대시 요청을 보낸다. 평타 · 스킬은 `rejectAction`으로 막지만(AttackServer 200, SkillServer 675) 대시는 검사가 없다. | 관전 중에도 대시 · 대시 피해 감소가 걸린다. 영혼은 피해를 안 받으니 실질 영향은 작다 → **확인 필요**(설계 의도). | `SoulService.rejectAction(player, "대시")`를 추가한다. | 10분 |
| 낮음 | AttackServer.lua:343 · SkillServer.lua:306 · AimPicker.lua:36 (`rootPart.Position` = 클라 소유 물리) | 위치 조작(순간이동 → 타격 → 복귀를 0.25초 폴링 사이에)을 한다. 사거리 검사는 복제된 루트 위치만 믿는다. | HeightGuard의 수평 검사(HeightGuard.lua:404, 폴링 0.25초)가 있지만, 공격 판정이 그 상태를 보지 않는다. 일반적인 로블록스 신뢰 모델의 한계다 → **확인 필요**. | 공격 판정에서 "직전 HeightGuard 표본과의 거리"가 상한을 넘으면 그 요청을 거부한다(선택). | 2시간 |
| 낮음 | tools/harness/attack_test.luau:1-94 | 이름은 "공격 하네스"인데, 실제로는 판매 · 퀘스트 · 펫 · 설정 · 낙하 신고 원격만 시험한다. | AttackRequest · SkillRequest(잘못된 인자 · 연타 · NaN 조준점 · 구역 밖) 회귀 시험이 없다. | `handleAttack`/`handleSkill` 입력 퍼징 항목을 추가한다(NaN · 2000 stud 밖 · 숫자 아닌 seq · 연타 빈도). | 2시간 |

---

## (3) 몬스터 · 보스 체력/공격/방어 계산 위치 전수 표

기본식은 `InfiniteStage`(shared/InfiniteStage.lua)에만 있고, 성장 배수는 `growthRate^(stage-1)`(InfiniteStage.lua:10-12)다. 잡몹은 구간 배율(`trashHpBand` · `trashAttackBand`)이 더 붙고, 보스는 붙지 않는다.

### 3-A. 기본 함수(단일 소스)
| 파일:줄 | 무엇 | 누가 부름 |
|---|---|---|
| shared/InfiniteStage.lua:10 | `getMultiplier(stage)` = k^(S−1) | 아래 전부 |
| shared/InfiniteStage.lua:35 | `getMonsterHp` = base × k^(S−1) (구간 배율 없음) | BossRules:267, BalanceSim:760, EconSimTables:250, DevTools:2789, C1Sim:523 |
| shared/InfiniteStage.lua:60 | `getTrashHp` = getMonsterHp × `interpBand(trashHpBand)` | MonsterState:421, CombatFormula:171 · 177, EconSim:334, EconSimTables:31, BalanceSim:214, DevTools:1646, PerfProbe:193 · 367 |
| shared/InfiniteStage.lua:64 | `getMonsterAttack` = base × k^(S−1) | BossRules:268, EconSimTables:242 |
| shared/InfiniteStage.lua:69 | `getTrashAttack` = getMonsterAttack × `interpBand(trashAttackBand)` | MonsterState:622, CombatFormula:182, BalanceSim:207, EconSim:362 · 363 |
| shared/data/MonsterData.lua:145-176 | tier별 스테이지 1 기준값 hp · attack · hpUnscaled · killUnits(= BASE × r^p 등) | 위 모든 함수의 base |

### 3-B. 실제 게임(서버 판정)
| 파일:줄 | 무엇 | 누가 부름 |
|---|---|---|
| server/MonsterState.lua:419-423 | **잡몹 유효 최대 HP** = getTrashHp(data.hp, 기준 스테이지) × 접두사 hpMultiplier → 피해 비율 | `applyDamage` ← AttackServer · SkillServer · StuckArrowState · 덫 · 궁극기 |
| server/MonsterState.lua:614-623 | **잡몹 공격** = getTrashAttack(data.attack, stage) / 보스 = data.attack 그대로 | MonsterAI:296 · 369 · 500 · 553 · 628 |
| server/MonsterState.lua:584-593 | 잡몹 공격 스테이지 = 기준 스테이지(없으면 맞는 사람) | MonsterAI:295 · 368 · 552 |
| shared/BossRules.lua:266-272, 288 | **보스 HP** = getMonsterHp(tier1.hpUnscaled, S) × boss.hpMultiplier × hpMultiplierExtra × 파티 인원 N^p · **보스 공격** = getMonsterAttack × attackMultiplier × interpBand(attackEase) | `buildInstanceData`(180) ← BossEncounter:458 · 475 · 491 · 586, DevTools:2143 · 3261, EconSim:952, EconSimReport:873, BossDifficultySim:117, 검증 다수 |
| shared/BossRules.lua:41-45 | 파티 인원 HP 배수 N^hpExponent | BossRules:288 · 290 |
| **server/BossEncounter.lua:379-384** | **보스 HP × repeatHpMultiplier**(2회차 이상 구간 수호자) — BossRules 밖 | spawnEncounter |
| **shared/WeeklyChallenge.lua:18-43** | 주간 도전 변형 — `mods` 경로의 숫자 필드(HP 포함 가능)에 곱함 | BossEncounter:497 |
| shared/BossRules.lua:248-263 | 초반 완화 — 보스 평타 · 스킬 피해 배율 × k | buildInstanceData |
| server/BossEncounter.lua:839 → MonsterState.lua:182-189 | 전멸 리셋 = hp ← maxHp | resetFor |

### 3-C. 플레이어 쪽 방어 · 받는 피해(몬스터 "방어"는 없다 — 몬스터 쪽 감소는 레벨차 · 전투 공식 배율)
| 파일:줄 | 무엇 | 누가 부름 |
|---|---|---|
| shared/PlayerCombat.lua:221-225 | 플레이어 방어 = (기본 + 장비) × 직업 × (1 + 보석%) | PlayerDamage:46 · 146, BalanceSim |
| server/PlayerDamage.lua:41-51 | 감소식 D/(D + α·A) | applyHit, MonsterAI:560 · 629(눈금) |
| server/PlayerDamage.lua:133-148 | 전투 공식 받는 배율(방어를 **한 번 더** 계산 — 146) | applyHit, MonsterAI 눈금 |
| shared/CombatFormula.lua:170-184 | 권장 전투력 · 권장 방어(그 몹 HP · 공격 기반) | MonsterState:363(주는 피해 배율), AutoStage:78 · 90, StageSelectPanel:532(클라), ZoneBoundaryWarning:114(클라), DevTools:1608 |
| server/MonsterState.lua:357-368 | 몬스터가 받는 피해 배율 = 레벨차 × 전투 공식(dealMultiplier) × 장비 뒤처짐 | applyDamage |

### 3-D. 시뮬 · 표시 · 도구(게임 식을 다시 조립하는 곳)
| 파일:줄 | 무엇 | 비고 |
|---|---|---|
| server/EconSim.lua:334 | 잡몹 HP | 같은 함수 |
| server/EconSim.lua:345 | `log(hpLimit/baseHp)/log(k)` — HP 식의 **역함수를 손으로** 계산 | 구간 배율을 무시한다(상한 검사용) |
| server/EconSim.lua:362-363, 957 | 생존 타수 = 공격 × 신규 보호 × 레벨차 × takeMultiplier | PlayerDamage.applyHit 연쇄를 다시 조립한다 |
| server/EconSimTables.lua:242, 250 | 앵커 = 구간 배율 **전** HP · 공격(의도 — 233 주석) | |
| shared/BalanceSim.lua:205-215, 759-760 | getMonsterAttack(구간 배율 포함) · measurePoint HP(구간 배율 **없음**) | 한 함수 안에서 공격은 구간 배율을 포함하고 HP는 빼서 비대칭이다 — 주석상 의도(756-757)지만 혼동 위험 |
| server/PerfProbe.lua:193, 367 | 잡몹 유효 최대 HP = getTrashHp × 접두사 | **MonsterState:421 복사** |
| server/DevTools.server.lua:1646, 2789 | t1 잡몹 HP · 보스용 trashHp | BossRules:267 복사 |
| server/MonsterAI.server.lua:560-561, 628-630 | 체력바 눈금 = computeHitDamage × 배율 × 신규 보호 × 레벨차 × 전투 공식 | **PlayerDamage.applyHit 연쇄를 손으로 복사**(받는 피해 출처 배율은 빠짐) |
| client/StageSelectPanel.lua:532, client/ZoneBoundaryWarning.client.lua:114 | 권장 전투력 표시(displayRecommendedPower → getTrashHp) | 공유 함수라 일치 |

---

## (4) 설계와 어긋난 코드

1. **"보스 수치는 BossRules 한 곳"**(BossRules.lua:1-3) · **"HP는 InfiniteStage 한 곳"**(InfiniteStage.lua:1-3)과 어긋남 — BossEncounter.lua:383 `data.hp *= repeatScale`, WeeklyChallenge.apply(HP 경로 변형). 그래서 미리보기 · EconSim · BossDifficultySim(`buildInstanceData`만 부른다)은 2회차 보스 HP를 모른다.
2. **완전 무적은 플래그로**(CombatConfig.lua:104)라는 설계와 달리 0배 출처를 배율로 거는 곳 — BossEnvironment.lua:480, DevTools.server.lua:3303(하한 0.25에 막힌다).
3. **19-4 구역 밖 공격 차단**(AttackServer.lua:355-357 "행위 자체를 막는 장치")과 달리 덫 · 활 궁극기는 시전자 위치를 보지 않는다((2) 1 · 2행).
4. **CLAUDE.md "스킬은 effects 배열의 조각 조합 · 스킬 전용 함수 금지"** — SkillServer는 `shape` 분기마다 전용 함수를 둔다(castShadowMark 507, castHunterTrap 531, castWarcry 598, castPrayer 622 등 12종). 이 규칙이 웹판 기준인지 로블록스에도 적용되는지 **확인 필요**.
5. **CLAUDE.md "밸런스 수치는 data/에만"** — 코어에 남은 숫자: AttackServer.lua:61 `MOTION_SEND_STUDS = 220`, 117 `AIR_FX_SEND_STUDS = 120`, 329 조준점 상한 `2000`, 185 넉백 레이 높이 `±1.5`, MonsterState.lua:76 `0.5`, SkillServer.lua:336 `0.5`. 대부분 표시 · 검증용이라 밸런스 영향은 작다.
6. **오래된 주석** — MonsterState.lua:519-521 "보스는 애초에 기록하지 않는다 · AttackServer의 사망 처리"(지금은 보스도 기록하고 처리는 CombatResolution이 한다). MonsterState.lua:287-294의 `applyDamage` 설명이 `setShielded` 위에 붙어 있다. SkillServer.lua:806의 로드 로그는 K2 스킬을 빠뜨렸다.
7. **PlayerDamage.lua:34-35 "체력바 눈금과 실제 피격이 같은 계산"** — 실제로는 MonsterAI가 연쇄를 복사해 쓴다((3)-D). 받는 피해 출처 배율(대시 · 회전베기)은 눈금에 빠져 있다(의도일 수 있음 → **확인 필요**).

---

## (5) 단일 소스 위반 · 중복 구현

| 무엇 | 위치 | 비고 |
|---|---|---|
| "몬스터 한 대 맞히기" 연쇄(applyDamage → HP바 → 흡혈 → 궁극기 충전 → 결과 이벤트 → DamageFeed → resolveHit) | AttackServer.lua:467-498(근접) · 598-622(원거리) · 438-462(환영) · SkillServer.lua:88-115(`strikeTarget`) | 4벌이고 호출 순서도 서로 다르다(strikeTarget은 DamageFeed가 HP바보다 먼저, resolveHit이 onDealt보다 먼저). (2)의 `dealt > 0` 충전 수정도 4곳을 고쳐야 한다. `CombatResolution.applyHit(player, target, damage, opts)` 하나로 합칠 후보. |
| 최종 피해 배율(힐러 버프 × 궁극기 × 포효) | AttackServer.lua:415-417, 434 · SkillServer.lua:98-100 | 새 버프가 생기면 3곳을 고쳐야 한다 → `PlayerCombat`/서버 헬퍼 `finalDamageMultiplier(player)` 하나로. |
| 로그 보간 | CombatFormula.lua:124-144 `interpLog` ≈ InfiniteStage.lua:40-57 `interpBand` | 동작이 같다(끝값 처리만 표기가 다름). |
| 잡몹 유효 최대 HP(getTrashHp × 접두사) | MonsterState.lua:419-421 · PerfProbe.lua:193 · 367 | `MonsterState.getEffectiveMaxHp(model, stage)`로 노출할 후보. |
| 보스 trashHp | BossRules.lua:267 · DevTools.server.lua:2789 | |
| 보스 HP 추가 배수 | BossRules.lua:288 · BossEncounter.lua:383 · WeeklyChallenge.lua:18 | (4)-1 |
| 받는 피해 연쇄 | PlayerDamage.lua:161-203 · MonsterAI.server.lua:560-561 · 628-630 · EconSim.lua:362-363 · 957 | |
| 방어력 계산 | PlayerDamage.lua:46 · 146(같은 타격에서 두 번) | 결과를 넘겨 한 번만 계산한다. |
| Raycast 제외 목록(몹 + 모든 캐릭터) | AttackServer.lua:173-181 · 505-516 | |
| 구역 필터 | AttackServer.lua:358 · 536(ZoneBounds 직접) · SkillServer.lua:131-139(`filterSameZone`) | 기준점이 시전자/조준점으로 섞여 있다((2) 1 · 2행의 원인). |
| HP 성장 역함수 | EconSim.lua:345 · InfiniteStage.lua:16 `stagesForPowerRatio` | 기존 함수를 재사용할 수 있다. |

---

## (6) 정리 후보 (저장 필드 · 데이터 id · 에셋 · DataStore는 제외)

- `BossEnvironment.lua:480`의 `"bossRocket"` 0배 출처 — `isRocketing` 면역(PlayerDamage.lua:64)과 중복이고 하한 때문에 효과도 다르다. 무적 플래그로 바꾸거나 한쪽만 남긴다(동작을 바꾸므로 Play 검증 필요).
- `CombatFormula.interpLog` → `InfiniteStage.interpBand` 재사용.
- 위 (5)의 "한 대 맞히기" 4벌 → 공통 함수 하나(리팩터 1순위 — 버그 수정 지점이 4곳에서 1곳으로 준다).
- 최종 피해 배율 3곳 → 헬퍼 하나.
- MonsterAI 눈금 계산 2곳(560 · 629) → `PlayerDamage.previewHitDamage(player, attack, mult, stage)` 하나(applyHit와 같은 연쇄를 공유).
- `attack_test.luau`의 이름이나 범위 조정(공격 원격 시험을 추가하거나 이름을 바꾼다).
- 오래된 주석 3곳((4)-6).

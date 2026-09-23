# P2.5a 로그 - 성장 모델 재설계(스테이지당 2%) · 강화 30강 · 등급 배율 · 골드 축소 · 성능 기준선

자율 진행 단계(COMMON.md §7). 사용자 확정 결정: R1 k = 1.02 · R2 설계 최대 스테이지(상위 1% 약 2,190시간 · 전 수치 < 1e250) · R3 등급 1단계 ×1.45 · R4 강화 최대 +30 · R5 강화 1회 = 최종 데미지 +3.5%(합연산 버킷) + 공격력 곱연산 · 골드 획득 축소 · 레벨업 가속 · P2 결정 5 ~ 10.

## A. 코드 사실 확인(변경 전, `9494604` 기준)

| 항목 | 코드 사실 | 위치 |
|---|---|---|
| 몬스터 성장 | HP · 공격 · 골드 · 경험치 = tier 기본값 × k^(s−1), k = 1.155 하나. tier 기본값 = tier1(HP 80 · 공격 8 · 골드 6) × r(t)^p(p = 2, 공격은 r^1). 1 ~ 100에 꺾이는 구간 없음 | `InfiniteStage` · `InfiniteStageConfig.growthRate` · `MonsterData` |
| 보스 성장 | 보스 = 그 스테이지 tier1 잡몹 × 보스 배율(HP · 공격 · 골드 · 경험치) × 파티 N^p, p = 1 − 5·ln k / ln 4(k에서 유도 - k = 1.155에서 0.48). 5스테이지마다(`BossData.stageInterval`) | `BossRules.buildInstanceDataFrom` · `partyHpExponent` |
| 무기 성장 | 공격력 = 무기 27.1 × 등급 배율 × 강화 배율(1 + 계수) × 직업 atk × **캐릭터 레벨** 계수 × (1 + 공격력% 합). 레벨 계수 = 1 + 0.06(L−1)(1 ~ 25, 25에서 2.44) · 그 뒤 2.44 × g^(L−25), g = 1.15. 무기에는 itemLevel이 없다(레벨이 곧 무기 성장) | `PlayerCombat.getAttack` · `CharacterLevel.getWeaponExpMultiplier` |
| 방어구 성장 | 갑옷 방어 = 5 × 갑옷 등급 배율 × 아이템 계수(itemLevel) · 최대체력 = 300 × 아이템 계수. 아이템 계수 = 1 + 0.06(L−1)(≤ 25) · 2.44 × **k**^(L−25). 장갑 공격력% · 신발 속도%는 계수를 25에서 동결(등급 배율 × 0.15 × 2.44) | `Loot.getArmorDefense` · `getMaxHpBonus` · `getGlovesAttackPercent` · `CharacterLevel.getItemLevelMultiplier(Frozen)` |
| 방어구 "+2 사다리" | 드랍 itemLevel = 받는 사람의 **지금 스테이지** + δ(−2 ~ +2, 1:2:3:2:1). 방어구는 "잡은 스테이지 + 최대 2"로만 오르므로, 생존이 사냥 스테이지를 막으면 점검마다 최대 2칸씩만 올라간다(P0 진단) | `Loot.rollArmorDrop` · `ArmorData.itemLevelDelta` |
| 경험치 곡선 · 상한 | L→L+1 = round(K(L) × E(L)), E(L) = tier1 경험치(스테이지 L) = floor(80 × 0.025 × k^(L−1)), K = 목표 처치(1:5 · 25:10 · 50:15 · 75:20 · 125:25 선형, 이후 25). **레벨 상한 없음**(코드에 상한 상수 없음) | `CharacterLevel` · `CharacterLevelConfig.killTargetAnchors` |
| 환생 | 필요 레벨 표 25 · 50 · 65 · 80 · 90(`CharacterLevelConfig.rebirth.requiredLevels`), 최대 5회. 초기화 = 경험치 · 지금 스테이지. 보상 = 무기 등급 = 회차 · 보석 칸 개방 + 칸 상한 등급 보석 1개(itemLevel = **25 × 회차**, 캐릭터 레벨 아님) · 5회 + 5칸 = 무기 태초 | `PlayerProfile.rebirth` |
| 강화 | 최대 +25(`EnhanceConfig.maxLevel`). 배율 = 1 + 계수표(+25 = ×16.5, +20 = ×8.5). 비용 = 골드표(+24→25 6.24e8) × GoldCost(계정 최고, 기준 100 뒤 k^(s−100)) + 19강부터 강화석 · 22강부터 상급 강화석. 성공률 92 · 78 · 62 · 48 · 38 · 28 · 18 · 12%. 실패 = 0 ~ 18 유지 · 19 ~ 21 하락(바닥 18) · 22 ~ 24 하락 + 초기화(12). 천장 = 게이지(실패마다 성공률 × 500‰, 1000에서 확정) | `Enhance` · `EnhanceConfig` · `EnhanceMaterialData` |
| 등급 배율 | 등급 7종(일반 ~ 태초). 무기 · 장갑 · 신발 · 옵션 = `ItemVisualData.statMultiplier` 1.0 · 1.4 · 2.0 · 3.0 · 4.5 · 8.0 · 15.0. 갑옷 = `ArmorData.defenseGradeMultiplier` 1.184 · 2.397 · 3.903 · 5.866 · 8.347 · 11.25 · 15.0(이 표가 tier 공정성 r(t)의 입력) | `ItemVisualData` · `ArmorData` · `MonsterData` |
| 등급별 옵션 개수 | 일반 · 희귀 = 0 · 영웅 ~ 태초 = 1개(`Option.rollFor` 한 줄). 옵션 값 = 기본값 × (등급 배율 ÷ 태초 배율) × levelFactor(itemLevel) × 롤 | `Option` · `OptionData.minGradeIndex` |
| 일반 몹 드랍 itemLevel | **사냥 중인 스테이지**(받는 사람 자신의 지금 스테이지 = `TutorialState.getMonsterStage` → `PlayerProfile.getInfiniteStage`) ± 2. 최고 스테이지가 아니다. 태초만 편차 없이 사냥 스테이지 | `CombatResolution.grantKillReward` |
| 보스 드랍 | 첫 클리어 = tier6 표(환생 0회면 1단계 위로 민 표) · 재도전 = tier1 표 확정 1개. itemLevel = 보스 스테이지 + 0 / +1 / +2(3:2:1) | `Loot.rollBossFirstClearDrop` · `rollBossRetryDrop` |
| 보석 레벨 출처 | 분해 보석 = 장비 itemLevel 그대로(태초 = 사냥 스테이지 = 몬스터 레벨). 환생 지급 보석 = 25 × 회차(캐릭터 레벨과 무관한 고정값). **척도 불일치**: 태초는 스테이지 척도, 환생 보석은 "옛 필요 레벨" 척도 | `PlayerProfile.dismantleItem` · `rebirth` |
| 스테이지 전환 · 몬스터 생성 | 잡몹은 구역 격자에 상시 존재하고(HuntingGround) 수치는 **공격한 사람의 스테이지**로 매번 계산한다 - 일반 스테이지 전환은 인스턴스를 하나도 만들지 않는다. 보스 스테이지 진입만 보스 모델 + 아레나를 만들고, 나가면 파괴한다. 잡몹은 처치마다 모델 파괴 → `respawnDelaySeconds` 뒤 새로 생성(재사용 없음) | `StageServer` · `MonsterSpawner.despawn` · `BossEncounter` |

## 가정·결정 로그

1. [A] 위 표는 코드를 직접 읽어 확인했다(grep + 함수 전체 읽기). 드랍 itemLevel은 이미 "사냥 중인 스테이지 ± 2"라 C7의 드랍 기준 변경은 필요 없다.

## 결정 필요

(파트 진행 중 채운다)

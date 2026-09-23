# P2.5c 로그 - 수치 조정(천장 경사 · 신규 보호 · 환생 25단위 · 구매력 · 보석 비중 · 보스 드랍 · 태초 · 임계값 · 마일스톤)

자율 진행 단계(COMMON.md §7). 사용자 확정 결정 1 ~ 10 · B1 · B2(지시 원문 = 사용자 프롬프트). 값 탐색은 로컬 하네스(스크래치패드 `mk_econ.py` - EconSim · EconSimReport를 게임 모듈 그대로 돌린다, 전체 3프로필 약 30초), Studio Play는 검증에만.

## 0. 코드 사실(시작 `01da7ec` 기준)

| 항목 | 코드 사실 | 위치 |
|---|---|---|
| 천장 | 무기 성장 g = k(1.02) · 레벨 20,000부터 1.01(`weaponGrowthLate` 한 단). 진행 = 방어구 생존 사다리(드랍 itemLevel = 사냥 스테이지 + 최대 2) → g < k 구간에서만 처치가 막는다 | `CharacterLevelConfig` · `CharacterLevel.getWeaponExpMultiplier` |
| 변경 전 곡선 | 상위 1% 스테이지 10,000 = 100.8시간 · 20,000 = 202.4 · 설계 최대 21,230 = **214.9시간**(마일스톤 ×1.03/50레벨이 천장을 없앴다 - P0(가) 9 X) | `docs/econ/P25c-before.md`(하네스 = P25b-after와 이정표 일치) |
| 초반 생존 | 받는 피해 = 공격 × (1 − D/(D + αA)) × 배율(대시 · 채널링 · 잡힘) - 스테이지에 따른 보정 없음. 캐주얼 스테이지 10 = 1.0시간 | `PlayerDamage.applyFinalDamage` · `BalanceSim.getSurviveHits` |
| 환생 | 필요 레벨 78 · 155 · 202 · 248 · 279 · 경험치 배수 = (1 + 성장 옵션) × (1 + 파티) - 환생 회차 배수 없음(25-1에서 없앴다) | `CharacterLevelConfig.rebirth` · `PlayerProfile.getExpGainMultiplier` |
| 경험치 곡선 | L → L+1 = K(L) × 스테이지 L + 167의 tier1 경험치, K = 5(1) · 10(25) · 15(50) · 20(75) · 25(125) 선형 | `CharacterLevel` |
| 강화 비용 | 1회 = `EnhanceConfig.goldCost[단계+1]` × 1.001^(계정 최고 − 1). +20→21 = 766,000 · 이후 ×1.1/단계 | `Enhance.getCost` · `GoldCost` |
| 보석 등급 몫 | 옵션 값 = 기본값 × (등급 배율 ÷ 태초 배율) × levelFactor × roll - 등급 배율 = 장비와 같은 1.45^(순서 − 1) | `Option.valueOf` · `ItemVisualData.gradeStep` |
| 보스 드랍 | itemLevel = 보스 스테이지 + {0, 1, 2}(3 : 2 : 1) | `ArmorData.bossItemLevelDelta` |
| 태초 tier | dragonOverTier 1.30 · 1.20 · 1.08 · **0.85 · 0.64** · 1(tier4 · 5가 드래곤보다 확률이 높다) | `DropTableData.primordial` |
| 스테이지 번호 임계값 | 재료 해금 50 · 75 / 방지권 첫 클리어 50부터 25칸마다 · 초기화 100부터 / 보스 밀도 25부터 25칸마다(+1 ~ +3) | `EnhanceMaterialData` · `EnhanceConfig.protection.bossGrant` · `BossData.mechanics.stageDensity` |
| 마일스톤 | 환생 1회 이상 · 회차마다 50레벨 = 공격력 ×k^1.5(곱) · 100레벨마다 해금(가방 · 계승 할인 · 예약 3) · 기록 = `classes[*].milestones[회차] = 받은 마지막 50 배수` | `Milestone` · `MilestoneData` · `PlayerProfile.claimMilestones` · SAVE_VERSION 32 |

## 가정·결정 로그

1. [0 · 규칙] COMMON.md §1에 "성장률(k)에 기대는 값은 힘 비율로 데이터에 둔다" 추가(`_build.py`로 세션 파일 27개 갱신). 도우미 = `InfiniteStage.stagesForPowerRatio(배율)`(이번 단계에서 만든다).
2. [0 · 기준선] 변경 전 = 하네스로 `01da7ec` 코드를 돌린 `/gg econ all baseline`(`docs/econ/P25c-before.md`). Studio P25b-after와 이정표가 같다(상위 1% 설계 최대 214.9시간 · 일반 830.8시간).

3. [H · 임계값 방식] 옛 스테이지 번호 임계값은 숫자를 바꿔 적지 않고 **힘 비율로 계산**한다: `InfiniteStage.fromLegacyStage(옛 번호, 반올림 단위)` = 1 + ln(1.155^(옛 − 1)) ÷ ln k · 폭은 `fromLegacySpan`(1.155^폭). 옛 k 1.155는 `InfiniteStageConfig.legacyGrowthRate` 한 곳(게임 성장률 아님). 보스 스테이지에 걸리는 값(방지권 · 밀도)은 보스 간격 5의 배수로 반올림(안 그러면 보스 스테이지와 안 겹친다), 재료 해금은 정수.
4. [H · 목록] 재료 해금 강화석 50 → **358** · 상급 75 → **539** / 방지권 첫 클리어 50 → **360** · 25칸 → **180칸** · 초기화 100 → **720**(설계 최대까지 지급 116회 - 옛 번호 그대로면 약 850) / 보스 밀도 시작 25 → **175** · 25칸 → **180칸**(+1 = 355 · +2 = 535 · +3 = 715). 변경하지 않은 것: 보스 간격 5 · 보스 로테이션 36마리(180스테이지 주기 - 배치 순서) · 스테이지 선택 10칸 묶음(UI) · 견습 스테이지 1 · 보스 스킬 범위 배율(신발 itemLevel 25 동결에서 나온다 - itemLevel = 스테이지라 새 k에서도 "그 스테이지 장비의 속도"와 맞는다) · 파티 입장 밴드 · 보스 파티 지수 · 파훼 게이트(P2.5a가 이미 힘 비율 - 결정 8 유지) · 태초 감쇠 70칸(P2.5a가 이미 환산).
5. [F · 보스 드랍] `ArmorData.bossItemLevelDelta` = 0 · fromLegacySpan(1) · fromLegacySpan(2) = **+0 · +7 · +15**(3 : 2 : 1 - 사용자 확정값과 힘 비율 계산이 같다). 스테이지 선택 패널의 보상 줄(`StageRewardBand`)은 이 표에서 Lv 범위를 만들어 따로 고칠 곳이 없다.
6. [G · 태초 tier] `dragonOverTier` tier4 · 5 = 1/0.94 · 1/0.97(드래곤의 ×0.94 · ×0.97). tier3(×0.926) < tier4 < tier5 < 드래곤(×1) 순서. "약간의 지배"는 E5 표로 보고.

## 결정 필요

(없음 - 진행하며 채운다)

# 초월 계승 기초 자료(ALL10 준비 · 읽기 · 측정만)

> QUEUE-ALL9C 0-12(2026-10-03). 소모처 비교 문서는 만들지 않는다(사용자 결정 완료). 숫자 = `docs/design/econ-baseline-pre-all10.md`와 같은 측정(원자료 `docs/phase/all9c/baseline-raw.txt`). 경로는 `roblox/src/` 기준.

## (a) 태초 무기 +30 도달(불씨 · 초기화 · 방지 규칙 포함)

| 프로필 | 시각 | 그때 최고 스테이지 | 도감 몫 끔이면 |
|---|---|---|---|
| 캐주얼(1h/일) | 693.0h | 10,370 | 796.4h · s10,835 |
| 일반(3h/일) | 424.7h | 9,885 | 485.3h · s10,315 |
| 상위 1%(12h/일) | 192.3h | 8,410 | 220.4h · s8,580 |
| 운 나쁜 P90 | 620.0h | 11,090 | 717.4h · s11,740 |

+30 도달 때 네 프로필 모두 환생 5 · 무기 등급 6(태초). 상위 1% 시드 20개 분포: 130 ~ 865h(중앙 약 334h) - 기본 시드는 빠른 쪽.

## (b) 누적 골드 수입

| 프로필 | +30 → 15,000 (켬 / 끔) | 15,000 → 25,300 (켬 / 끔) |
|---|---|---|
| 캐주얼 | 2.56e12 / 2.27e12 | 4.07e17 / 3.67e17 |
| 일반 | 3.24e12 / 2.67e12 | 5.47e17 / 4.72e17 |
| 상위 1% | 7.61e12 / 6.00e12 | 1.44e18 / 1.11e18 |
| 운 나쁜 P90 | 6.25e12 / 5.70e12 | 1.26e18 / 1.12e18 |

15,000 → 25,300 구간이 +30 → 15,000보다 약 5만 ~ 20만 배 크다(골드 성장률 1.001^스테이지 · 처치 속도 증가).

## (c) 몬스터 · 보스 수치

- 잡몹: HP = 기본 × 1.02^(s−1) × `trashHpBand`(로그 보간 · `shared/InfiniteStage.lua:60` · 띠 = `shared/data/InfiniteStageConfig.lua:23`) · 공격 = 기본 × 1.02^(s−1) × `trashAttackBand`(`InfiniteStage.lua:69` · `InfiniteStageConfig.lua:27`) · 골드 = 1.001^(s−1)(`InfiniteStageConfig.lua:31`). tier1 기본 HP 80 · 공격 8 · 골드 6(`shared/data/MonsterData.lua:134`) · tier HP 비 `MonsterData.lua:89` · 서버 사용 `server/MonsterState.lua:421 · 622`.
- 보스: HP = 잡몹 HP(띠 없음) × hpMultiplier(60 ÷ 1.72) × 추가 × 인원^0.93(`shared/BossRules.lua:266-288` · `shared/data/BossData.lua:154 · 267`) · 공격 = 잡몹 공격 × attackMultiplier × `attackEase`(`shared/data/BossCurveData.lua:19`).
- **기준 빌드**: `shared/data/BalanceAnchorConfig.lua:9-26`(생존 7타 · tier1 처치 1.72초 · 활 · 레벨 100 · 일반 3부위 itemLevel = 레벨 · +0) → `shared/BalanceSim.lua:738 buildAnchorLoadout` · `:791 solveKillOffset`. 방어 상수 `damageReductionAlpha` = 이 빌드로 역산(`shared/data/CombatConfig.lua:57-76`). 2차 기준 "대표 전력" = `shared/data/CombatFormulaData.lua:18-26`.
- **몹 방어 개념: 없음**(몹 데이터에 방어 칸 없음 · 방어는 플레이어만 `shared/PlayerCombat.lua getDefense`). 대신 잡몹 피해에 전투력 비 배율 `CombatFormula.dealMultiplier`(`shared/CombatFormula.lua:77-79 · 121-126` · `server/MonsterState.lua:363` · 보스 제외)와 장비 뒤처짐 `gearLag`(`CombatFormulaData.lua:59`).
- **몹 정보 UI**: HP · 공격 숫자를 보여 주는 화면은 없음(체력바 = 서버 `HpBarFill` 비율 · 보스바 = `BossHpRatio` Attribute). 클라가 계산하는 수치(권장 전투력 `client/StageSelectPanel.lua:532` · 도감 골드 `client/panels/CodexV2/Info.lua:222`)는 서버와 같은 shared 함수.

## (d) 수련 1 ~ 50 · 직업 특성

- 공용 수련(`shared/data/TrainingData.lua:18-20` · 계산 `shared/Training.lua`): 공격 +0.1%/단계(최대 +5%) · 체력 +0.4%(+20%) · 방어 +0.2%(+10% - defensePercent 축) · 최대 50단계 · 상한 = 계정 최고 스테이지 ÷ 20 · 비용 = tier1 골드 × 32마리 × 1.08^단계 × GoldCost(스테이지).
- 직업 능력(`TrainingData.lua:23-44`) 직업마다 3개: 대검 gs_might · gs_iron · gs_guard / 쌍검 db_might · db_iron · db_swift / 활 bow_might · bow_iron · bow_swift / 치유사 hl_might · hl_iron · hl_grace. 숙련 · 체력 계열 +0.0375%/단계 · 최대 50 / 직업 축(방어 0.15% · 속도 0.075% · 치유 0.15%) 최대 25 · 비용 60마리분 × 1.01^단계 · 상한 = 스테이지 ÷ 10.
- 공격 계열은 마일스톤과 **같은 영구 버킷에 합연산**(`PlayerProfile.getMilestoneMultiplier` → `PlayerCombat.getAttackParts`의 permanent 줄).
- **"직업 특성 진화" 시스템은 없음**. 이름이 비슷한 "각성"(`shared/Awaken.lua`)은 태초 · 초월 장비 itemLevel을 계정 최고 스테이지로 올리는 기능(초월 무료).

## (e) 무기 · 계승

- 무기 데이터 = `starter_sword` 하나(`shared/data/WeaponData.lua:17-40` · baseAttack 27.1). 등급 · 강화 · 보석은 저장 `classes[직업].weapon`. 등급 배율 = `ItemVisualData.gradeVisuals.statMultiplier`.
- 태초 무기 = 환생 회차가 무기 등급(`server/PlayerProfile.lua:1073`) · 환생 5 + 보석 5칸 = 등급 6(`:1097-1099` · `shared/data/ArmorData.lua:70`) - 칸이 열릴 때 보석이 자동 지급돼 사실상 항상 충족. 강화 단계는 환생 때 유지.
- **초월 무기 데이터 없음**(`maxWeaponGradeIndex = 6` · 초월 특수 옵션은 방어구 3부위만 `shared/data/TranscendentData.lua:26`). **에셋 자리는 있음**: 모델 `weapons/<직업>_transcendent`(`shared/data/ArtAssetIds.lua:693 · 701 · 709 · 717 · 725`) · 아이콘(`:504 · 512 · 520 · 528 · 536`) - 지금 코드는 안 씀.
- 계승(`shared/Inherit.lua` · `server/ItemInherit.lua`): 방어구 3부위만 · 옵션 세트 1개(종류 + 굴림 위치)를 옮기고 수치는 B 등급 · 레벨로 다시 계산 · A는 분해와 같이 환급 · 비용 = tier1 골드 × `InheritConfig.goldKillEquivalent[B 등급]`(일반 20부터 ×2 · 태초 1,280 · 초월 2,560) × (1 − 마일스톤 할인 10%) · 결과가 태초 · 초월이면 자동 잠금. **초월은 B(받는 쪽)만 가능 - A(재료)가 초월이면 거절**(`Inherit.lua:91-92`) · `TranscendentData.lua:19` 주석 "계승 가능"과 읽는 방향이 다름(주의).

## (f) 보석

- 등급: 영웅 · 전설 · 유물 · 고대 · 태초(`shared/data/GemData.lua:102-105` · 분해 하한 = 영웅). **태초 보석 있음**(1번 칸 상한 = 태초 · 환생 1회 확정 지급 `GemData.lua:23` · `shared/Gem.lua:55-58`). **초월 보석 없음**(초월 장비 분해 불가).
- 유저당 보유 추정: 무기 5칸이 환생 1 ~ 5회에 하나씩 확정 지급(칸 상한 태초 · 영웅 · 전설 · 유물 · 고대 순) - 환생 5 계정은 최소 5개 장착 + 영웅 이상 장비 분해분이 가방에.
- 홈: 5칸(`Gem.lua:14`) · 칸 i = 환생 i회에 열림(`GemData.lua:31`) · 칸 상한 `{태초, 영웅, 전설, 유물, 고대}` · 상한 이하 아무 칸 · 칸 번호 = 무기 위 "시각적 존재감" 순서(주석만).
- **보석 3D 광원 없음** · 칸 위치별 빛 차이 없음(강화 빛은 홈을 피해 붙임 `client/WeaponEnhanceVisual.lua:5-6`). 등급 표시는 2D UI 테두리 · 발광 프레임뿐(`client/panels/Inventory/GemBag.lua:70-83` · `GemSlots.lua:137 · 156`).
- 추출: 해제 기능 없음 - 장착은 항상 무료 "교체", 빠진 보석은 레벨 · 옵션 그대로 가방으로(`server/GemEquip.lua:2` · `PlayerProfile.lua:1321-1352`). 가방 보석만 분해(가루) · 판매 · 재련 · 옵션 리롤(고대 · 태초 · 변환권 40마리분).

## (g) 0-4 표와 연결 - 시간당 수입 1e15

| 프로필 | 시간당 수입 1e15 넘는 곳 | 보유 2^53 돌파 |
|---|---|---|
| 캐주얼 | 3,412h · s25,375 | 2,132h · s22,275 |
| 일반 | 2,260h · s24,835 | 1,464h · s21,970 |
| 상위 1% | 1,709h · s23,980 | 1,113h · s21,435 |
| 운 나쁜 P90 | 1,956h · s23,970 | 1,360h · s21,425 |

## 이 자료로 본 위험(결정 필요로 올림)

1. **폭주 선순환**: 초월 강화 · 고급 수련 비용이 지금처럼 GoldCost(스테이지)로 수입과 같이 크면 "더 강해짐 → 더 높은 스테이지 → 수입 ×1.001^s → 비용도 같은 비율"이라 흡수는 일정하지만, 강해지는 속도가 스테이지 진행을 앞당기면 수입이 먼저 뛰어 잉여가 다시 생긴다(지금 +30 뒤 잉여 = 같은 모양).
2. **곱셈 중첩**: 공격력은 무기 · 등급 · 강화 · 레벨 · 딜 부위 · 공격% · 최종 피해 · 영구 버킷의 곱(`PlayerCombat.getAttackParts`). 초월 강화를 새 곱 줄로 넣으면 기존 +30(×20)에 다시 곱해져 몹 HP 1.02^s 곡선을 크게 앞지를 수 있다 - 새 줄을 곱으로 둘지 기존 버킷(최종 피해 합연산 · 영구 버킷)에 더할지 먼저 정해야 한다.
3. **2^53**: 상위 1%는 1,113h(약 93일)에 보유가 2^53을 넘고, 25,300 근처에선 단일 비용(1.4e16)도 넘는다 - 숫자 압축 · 보유 상한을 ALL10 곡선과 같이 정해야 한다.
4. **운 편차**: 같은 상위 1%도 +30이 130 ~ 865h(6.7배). 초월 계승을 +30 조건으로 걸면 진입 시점 편차가 그대로 커진다.
5. **일정**: 초월 무기 데이터 · 계승 경로 · 보석 광원이 전부 없어(에셋 자리만 있음) ALL10 구현량이 크다.
6. 몹 방어 개념이 없어 "고스테이지 몹 방어 재설계"는 새 축 도입(서버 피해 식 · BalanceSim · 기준 빌드 역산까지 같이 바뀜).

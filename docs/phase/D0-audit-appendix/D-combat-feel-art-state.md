# 감사 (e) 전투 체감 · 아트 현황 - 읽기 전용 조사

범위: `roblox/src/` 코드, `PRD-forge-game-roblox.md`(grep), `docs/phase/P3d-report.md`, `docs/perf/baseline.md`. 저장소 파일 수정 없음 · Studio MCP 안 씀.
표기: 경로는 `roblox/src/` 기준(PRD·docs는 저장소 루트 기준). 계산값은 코드 식에 데이터를 넣어 직접 계산한 값. 확인 못 한 것은 **[추정]**.

---

## 1. 보스 피격 판정 크기 vs 외형

### 판정 방식 - "크기"가 없다. 중심점 거리만 본다
- 평타 대상 선정 = `shared/AimPicker.lua:31-37` - `model.PrimaryPart.Position`(보스 루트 **중심**)과 플레이어 루트의 **수평(XZ) 거리 ≤ 사거리**이면 후보. 몸 크기·파트 크기는 전혀 안 본다.
- 거리 판정의 단일 출처 = `shared/Reach.lua:1-7, 24-26`(수평 거리 + 높이차 상한 8).
- 스킬 판정도 같다: `shared/SkillCombat.lua:44-51`(원 = 루트 중심 거리), `:18-35`(선분).
- MonsterSpawner 주석이 직접 못 박음: 부착물은 "히트박스·어그로·리쉬(전부 루트 위치 기준, 파트 크기 무관)에 영향이 없다" - `server/MonsterSpawner.lua:85-87`. 몸통 충돌도 꺼져 있다 - `:160-170`(`body.CanCollide = false`, "피격 판정은 전부 거리 기반").
- 원거리(활·치유사)는 발사 시점 대상 확정 + 도달 시점에 대상이 발사 때 자리에서 `hitToleranceStuds = 6` 넘게 움직였으면 빗나감 - `shared/data/ProjectileConfig.lua:23`, `server/AttackServer.server.lua:285-300`.

### 사거리(플레이어 쪽 "판정 반경")
| 직업 | 식 | 사거리(스터드) | 근거 |
|---|---|---|---|
| 검사(greatsword) | 10 × 1.3 | 13 | `shared/data/CombatConfig.lua:7`, `shared/data/ClassData.lua:46` |
| 도적(dualblade) | 10 × 1.0 | 10 | `ClassData.lua:56` |
| 궁수(bow) | 10 × 1.5 | 15 | `ClassData.lua:73` |
| 치유사(healer) | 10 × 1.5 | 15 | `ClassData.lua:86` |
- 강화 보너스를 곱하되 상한 = 어그로 25.6 − 1 = 24.6 - `shared/PlayerCombat.lua:140-151`.
- 보스는 플레이어 중심에서 8 스터드 거리에 멈춘다(`chaseStopDistanceStuds = 8`, 6종 공통 - `shared/data/BossData.lua:372, 386, 459, 534, 598, 698`; 사용처 `server/MonsterAI.server.lua:241-243`).

### 보스 외형 크기 (코드 식: `server/MonsterSpawner.lua:144, 153-159, 180`, 부착물 `:100-107`)
- 몸통 = (2.4·aX, 3·aY, 1.2·aZ) × sizeScale, 머리 = 구 1.6 × sizeScale, 루트(투명) = (2,2,1) × sizeScale.
- 데이터: `BossData.lua:367`(수호자 3·(1,1,1)) · `:381`(서리 3.3·(0.85,1.35,0.85)) · `:453`(심해 3·(1.05,0.95,1.15)) · `:528`(수정 3·(1,1.15,1)) · `:592`(전갈 2.8·(1.3,0.65,1.2)) · `:693`(폭풍 3·(0.9,1.2,0.9)), 부착물은 각 줄 바로 아래.

| 보스 | 몸통 반폭 X / 반깊이 Z | 부착물 포함 최대 반폭 X / Z | 높이(몸+머리) | 도적 10 대비(X) | 검사 13 대비 | 궁수·치유사 15 대비 | 멈춘 자리(8)에서 몸 표면까지 틈 |
|---|---|---|---|---|---|---|---|
| 구간 수호자 | 3.60 / 1.80 | 4.35 / 2.40 | 13.8 | 43% | 33% | 29% | 3.65 |
| 서리 거인 | 3.37 / 1.68 | 3.37 / 2.64 | 18.6 | 34% | 26% | 22% | 4.63 |
| 심해 군주 | 3.78 / 2.07 | 5.25 / 4.50 | 13.3 | 52% | 40% | 35% | 2.75 |
| 수정 여왕 | 3.60 / 1.80 | 3.60 / 2.70 | 15.2 | 36% | 28% | 24% | 4.40 |
| 전갈 여왕 | 4.37 / 2.02 | 4.37 / 3.78 | 9.9 | 44% | 34% | 29% | 3.63 |
| 폭풍 군주 | 3.24 / 1.62 | 4.05 / 2.40 | 15.6 | 40% | 31% | 27% | 3.95 |

(%는 "보스의 보이는 반폭 ÷ 그 직업이 보스 중심에서 때릴 수 있는 반경". 부착물 회전은 무시한 근사.)

읽는 법:
- 판정 원은 외형보다 **2~4.5배 크다**. 도적도 보스 표면에서 약 5.6~6.6 스터드(X축) · 7.6~8.4 스터드(Z축) 떨어진 허공을 쳐도 맞는다. 보스가 멈추는 자리(8)에서 몸 표면까지 2.75~4.63 스터드가 비어 있다 → 근접 직업이 "닿지 않았는데 맞는" 체감의 코드 쪽 원인 [체감 판단은 사람 몫].
- Z(앞뒤) 방향은 몸이 얇아서(1.6~2.1) 비율이 더 작다. 그런데 보스는 **회전하지 않는다**: 추격은 `model:PivotTo(CFrame.new(...))`(회전 없음) - `server/MonsterAI.server.lua:194`. 회전은 돌진 헤롱 기울기뿐 - `server/BossPatterns.lua:1288, 1303, 1713`. 그래서 플레이어가 보는 면은 방향에 따라 넓은 면(X) 또는 얇은 면(Z)이 된다.
- 보스 평타 사거리 14(6종 공통 - `BossData.lua:373, 387, 460, 535, 599, 699`)가 도적 10 · 검사 13보다 길다. 보스는 8에서 멈추므로 실전에서는 항상 닿는다.

---

## 2. 보스 "일반 공격" 종류 수와 반복 패턴

### 평타 = 보스마다 정확히 1종, 모션 없음
- 데이터: `basicAttack = { cooldownSeconds, damageMultiplier, rangeStuds }` 한 줄뿐(위 줄 번호). 주기 × 배율은 6종이 같다(1.0×1 · 1.5×1.5 · 0.75×0.75) - `BossData.lua:356-358`.
  - 수호자 · 심해 · 수정 = 1.0초 ×1 / 서리 = 1.5초 ×1.5 / 전갈 · 폭풍 = 0.75초 ×0.75.
- 실행: `server/MonsterAI.server.lua:208-230`(`tryAttack`) - 사거리 안이고 쿨이 지났으면 곧바로 `applyHitToPlayer`. 전조 · 이벤트 · 클라 표시가 없다. 맞은 사람에게 숫자만 뜬다(`server/PlayerDamage.lua:18-21, 68` → `client/PlayerHitFeedback.client.lua:1`).
- 보스 평타는 잡몹 평타와 같은 함수다(`tryBossAttack` - `MonsterAI.server.lua:236-246`: 패턴이 없을 때 "잡몹과 완전히 같은 추격·평타"). 공격 동작이 없어서 **보스가 가만히 붙어 있는데 체력이 1초마다 깎이는** 모양이 된다 [화면 확인은 안 함 - 코드상 그리는 곳이 없음].

### 스킬(패턴) = 보스마다 4~5종, 스케줄러가 고른다
| 보스 | 스킬(primitive · 쿨 · 피해) | 근거 |
|---|---|---|
| 구간 수호자 | heavy(circleBoss 6초 ×3) · shockwave(ring 11초 ×2, 3파동) · meteor(circleTarget 13초 ×2) · charge(15초 최대체력 55%) · cross(line 17초 ×2) | `BossData.lua:186-247` |
| 서리 거인 | slam(signature 9초 ×3) · icefall(12초 ×2) · spike(line 14초 ×2) · roar(기믹 21초 · 실패 55%) | `BossData.lua:379-450` |
| 심해 군주 | sweep(도넛 8초 ×3) · tide(ring signature 13초 ×1) · spout(연발 15초 ×2) · flood(기믹 20초) | `BossData.lua:452-525` |
| 수정 여왕 | burst(9초 ×2) · drop(signature 11초 ×2) · beam(14초 ×2) · split(기믹 20초) | `BossData.lua:527-588` |
| 전갈 여왕 | claw(line 부채 8초 ×3) · sting(12초 ×2) · stab(돌진 2회 signature 14초 · 27.5%) · shell(기믹 18초) | `BossData.lua:590-689` |
| 폭풍 군주 | discharge(ring 9초 ×1.5) · whirl(13초 ×2) · strike(signature 12초 ×2) · overcharge(기믹 30초) | `BossData.lua:691-780` |
(×n = 감소식을 거친 평타 피해의 배율, % = 최대체력 비율)

- 선택 규칙 = `shared/BossScheduler.lua:1-33`, `pick` `:81`: ① 한 번에 하나 ② 전역 쿨(느린 7 · 보통 6 · 빠른 5초, 체력 20% 이하 격노 2.5초 - `BossData.lua:260-268`) ③ 쿨 찬 것 중 ④ 첫 기믹 자리 비우기 ⑤ **직전 스킬 연속 금지** ⑥ 우선순위(normal 0 · signature 50 · gimmick 100 - `BossData.lua:149`) + 굶주림 보너스 1000(`starvationSeconds` 40~45초). 같으면 가장 오래 기다린 것 → `skillOrder` 순.
- 결과: 순서는 거의 결정적이고 쿨로 도는 로테이션이다(난수 없음). 스킬 사이 5~7초는 평타 추격 구간.
- **같은 모양 반복**: 전조 말풍선 그림이 스킬끼리 공유된다(`bubble = "heavy" / "meteor" / "cross" / "shockwave"` - 6종의 원형·낙하·직선 스킬이 같은 그림). 보스 몸의 모션은 ring과 charge 두 종류에만 있다(3절). 그래서 서리 거인 · 수정 여왕은 스킬을 쓸 때도 몸이 움직이지 않고 바닥 표시만 바뀐다.

---

## 3. 몬스터 애니메이션 유무

**Animation · AnimationTrack · Animator · LoadAnimation 사용처 = 0**(`client/ server/ shared/` 전체 grep). 몹 모델에 Humanoid는 있지만 "이름표 전용 더미"라고 적혀 있다 - `server/MonsterSpawner.lua:80-81, 190-194`.

| 상태 | 잡몹 | 보스 |
|---|---|---|
| 대기(idle) | 없음. 흔들림 · 숨쉬기 코드 없음(`math.sin` grep - 몬스터 쪽 해당 없음) | 없음 |
| 이동 | 서버 `PivotTo`로 미끄러지듯 평행 이동, 회전도 없음 - `MonsterAI.server.lua:177-196` | 같음 |
| 평타 | 없음(2절) | 없음 |
| 스킬 | - | **ring(진동파 · 해일 · 방전 고리)**: 서버가 hop(떠올랐다 찍기) + 클라 복제 인형의 늘어남·찌그러짐·팔/꼬리/지팡이 - `client/BossMotionView.lua:1-7, 150-258`, 스타일표 `shared/data/BossFxData.lua:12-18`(수호자 twoFistSlam · 심해 tailSwipe · 폭풍 staffStrike, 기본 hopLand). **charge**: 발 긁기 · 늘어나 달리기 · 잔상(수호자 hoofScrape, 전갈 burrow = 먼지만) - `BossMotionView.lua:318-373`. 호출 = `client/BossPatternVisuals.client.lua:611-626`. 돌진 뒤 헤롱 = 서버 가라앉음 + 25° 기울기 - `server/BossPatterns.lua:1288, 1303`. **서리 거인 · 수정 여왕은 몸 모션 0**(P3d 보고서 `docs/phase/P3d-report.md` ① 표 마지막 줄) |
| 피격 | 몸통·머리를 흰색으로 번쩍(Tween 0.15초) + 머리에 빛 구슬 - `client/HitEffects.lua:79-110`. 넉백은 일부러 뺌(서버가 매 프레임 위치를 덮어씀 - `:70-78`) | 같음(같은 함수) |
| 사망 | 몸 색 버스트 + 몸·머리가 0.35초에 줄며 투명 - `HitEffects.lua:117-135` | 같음 |

- 절차적 방식만 있다: Tween(색 · 크기) + 클라 복제 인형의 CFrame 계산. 인형은 모션 중에만 있고 끝나면 서버 모델을 다시 보인다 - `BossMotionView.lua:1-3, 70-88`.

---

## 4. 플레이어 공격 모션

- **애니메이션 id 없음. 전부 절차적**(코드가 매 프레임 각도를 계산):
  - 곡선 데이터 = `shared/data/AttackMotionData.lua` - 직업별 키프레임(예비 동작 → 타격 → 후속, 이징은 `TweenService:GetValue`로 계산 `:1-24, 188-193`). 검사 0.55초 `:34-72` · 도적 0.32초 `:74-117` · 궁수 시위 당김(`swingAxis = "Draw"`, `releaseT 0.78`) `:123-151` · 치유사 지팡이 내지름(`releaseT 0.55`) `:153-183`.
  - 팔 흔들기 = R15 어깨 관절(Motor6D) 회전 `armSwing` - `client/WeaponVisual.lua:258-309`.
  - 무기 모양 = `shared/data/WeaponModelData.lua`(kind: 검사 `mesh` `:38` · 도적 `mesh_pair` `:49` · 궁수 `bow`(Part 조합) `:67` · 치유사 `specialmesh` `:98`).
- 재생 흐름: `client/AttackInput.client.lua:207-232`(`performAttack` → 서버 요청 `FireServer` 후, 로컬 쿨 예측이 맞으면 `WeaponVisual.playSwing`) → `client/WeaponVisual.lua:482-497`(시작 시각 기록) → `:408-445`(`updateFrame` - `current.kind`로 갈라 `updateMeleeAlike / updateBow / updateStaff` + `updateArms`).
- 투사체: `AttackInput.client.lua:412-430` - 서버 `AttackLaunched`를 받으면 `getReleaseDelay()`만큼 기다렸다 `Projectiles.fire`. 서버도 같은 `releaseT × totalDurationSeconds`로 피해 시점을 계산한다 - `server/AttackServer.server.lua:285-290`. 계산 모형도 이 값을 읽는다 - `shared/BalanceSim.lua:237-238`.

### 궁수·치유사가 근접 거리에서 휘두르기 모션을 보여 줄 수 있는가
- 구조상 가능하다. 판정(서버 `AttackServer` · `AimPicker`)과 표시(`WeaponVisual` · `AttackMotionData`)가 나뉘어 있다.
- 표시만 바꿀 지점: `WeaponVisual.playSwing`(`:482`)과 `updateFrame`의 kind 분기(`:430-445`). 근접이면 "휘두르기 곡선"을 고르게 하려면 AttackMotionData에 `bow.meleeSwing` 같은 두 번째 곡선을 데이터로 추가하고, `AttackInput.performAttack`(`:230-231`)에서 대상과의 거리(클라 `AimTarget`이 이미 대상을 안다)를 보고 어느 곡선인지 넘기면 된다 [추정 - 설계안].
- 주의 3가지:
  1. `releaseT`는 서버 피해 시점 · 계산 모형과 **공유**된다(`AttackServer.server.lua:285-286`, `BalanceSim.lua:237-238`). 근접 곡선이 `totalDurationSeconds`나 `releaseT`를 바꾸면 딜 계산이 달라진다 → 새 곡선은 기존 두 값을 그대로 쓰거나, 서버·모형이 읽지 않는 별도 필드여야 한다.
  2. 투사체는 서버 `AttackLaunched`로 여전히 날아간다(`AttackInput.client.lua:412-430`). 근접 휘두르기로 보이게 하려면 그 거리에서 화살·구슬을 숨길지도 정해야 한다(표시만 바꾸는 일).
  3. 활은 Part 11개로 된 모델이고 `swingAxis = "Draw"`라 회전 스윙 코드(`updateMeleeAlike`)를 그대로 못 쓴다 - 활 파트를 휘두르는 새 갱신 함수가 필요하다 [추정]. 치유사 지팡이는 이미 X축 회전(`AttackMotionData.lua:160`)이라 각도만 키우면 된다.

---

## 5. 보스전 실측 도구 · 기존 측정값

### 시뮬레이터가 계산하는 것
| 도구 | 처치 시간 | 받은 피해 | 전멸 | 근거 |
|---|---|---|---|---|
| `BossSim.run / monteCarlo` | O(가정: 기준 플레이어가 모든 스킬을 피한다. 스킬마다 "회피 비용"만큼 딜 0. 보스 HP = 기준 순딜 60초분 × N^p) | **X**(판정 실패는 기믹 게이트 · 9초 잡힘으로만 셈) | **X** | `shared/BossSim.lua:1-13`, 가정 `BossData.lua:166-177`(`referenceKillSeconds = 60`) |
| `BossSim.checkPairs` | - | 인접 두 스킬을 둘 다 맞았을 때 합계(최대체력 %) - "실수 2회" 검사 | - | `BossSim.lua:582` |
| `BossSim.checkDodge / checkDensity` | 회피 부등식(전조 ≥ 0.5 + 거리/16 × 1.25) | - | - | `BossSim.lua:294, 317`, `BossData.lua:152-165` |
| `EconSim.fightBosses` | O(`HP ÷ (효율 × 인원 × DPS)`, 효율 0.6/0.75/0.9) | X(도전 조건 = 보스 평타를 `minSurviveHits` 번 버티는가) | X(`bossAttemptsPerClear` 2.0/1.5/1.1로 실패 시도를 **가정**) | `server/EconSim.lua:564-592`, `shared/data/EconSimConfig.lua:49-68` |
| `/gg party killsim` | 실제 보스 인스턴스에 봇 DPS(× uptime 0.65)를 0.25초마다 넣어 벽시계로 잰다 | X | X | `server/DevTools.server.lua:2235-2250` |

→ **보스전 "받은 피해 · 전멸"을 계산하는 도구는 없다.** 가까운 것은 치유사 쉴드 모형(`PartyShieldSim`)의 "피격 = 초당 0.25회 × 최대체력 10.26%" 가정 표뿐이다(PRD 17100-17110).

### "레벨 = 스테이지" 실측에 쓸 `/gg` 명령(도움말 `server/DevTools.server.lua:1042-1102`)
| 명령 | 인자 | 하는 일 | 분기 줄 |
|---|---|---|---|
| `/gg level <n>` | 레벨 | 캐릭터 레벨 지정 | 1204 |
| `/gg stage <n>` | 스테이지 | 무한 스테이지 지정(계산용, 이동 안 함) | 1253 |
| `/gg anchor [classId]` | 직업 | 레벨 100 + 일반 itemLevel 100 3부위 + 강화 0 + 스테이지 100 | 1202 |
| `/gg gear <grade> <itemLevel>` · `/gg weapon <n\|등급>` · `/gg enhance <n>` · `/gg class <id>` | - | 장비 · 무기 · 강화 · 직업 | 1208 · 1243 · 1239 · 1248 |
| `/gg boss [stage]` | 스테이지(5의 배수, 기본 5) | 그 스테이지로 옮기고 보스전 시작(파티 리더면 파티 보스) | 1441-1464 |
| `/gg boss force <id>` | 보스 id | 다음 보스 스폰 한 번만 그 종으로 | 1338 |
| `/gg boss table [끝]` | - | 스테이지별 보스 배치표 | 1328 |
| `/gg boss sim <bossId> <인원> <break\|failfirst\|nobreak> [live]` | - | 처치 시간 모형(결정 1회 + 몬테카를로 100회) | 1379-1400 |
| `/gg boss check <bossId>` · `/gg boss density [stage]` | - | 회피 부등식 · 인접 피해 · 밀도 검사 | 1401 · 1421 |
| `/gg pattern <스킬 id>` | - | 지금 보스에게 그 스킬 즉시 | 1465 |
| `/gg bossdmg <비율>` · `/gg bosskilltest` · `/gg bossinfo` | - | HP 깎기 · 즉시 처치 · 인스턴스 정보 | 1475 · 1499 · 1742 |
| `/gg boss gate <on\|off>` · `/gg boss trap [플레이어]` | - | 파훼 게이트 · 잡힘 강제 | 1370 · 1345 |
| `/gg party dummy <n>` · `/gg party table [stage]` · `/gg party killsim [uptime]` | - | 더미 파티원 · 1~4인 예상표 · 봇 실측 | 1932 · 1989 · 2235 |
| `/gg measure [stage]` | - | 생존 타수 · 60초 총딜 · 처치 시간 | 1269 |
| `/gg econ [...]` | - | 경제 시뮬(보스 시간 포함) | 1193 |
| `/gg reset` | - | 원본 프로필 복원 | 2286 |

### 이미 측정된 값
- **6종 처치 시간(모형 · 몬테카를로 100회, 기믹 전부 켬)** - PRD 14465-14481:
  | 보스 | 인원 | 파훼 후(초) | 기준 대비 | 파훼 전(초) | 전÷후 |
  |---|---|---|---|---|---|
  | 구간 수호자 | 1 / 4 | 73.2 / 37.5 | 기준 | - | - |
  | 서리 거인 | 1 / 4 | 72.2 / 35.1 | −1.4% / −6.3% | 188.0 / 72.3 | ×2.60 / ×2.06 |
  | 심해 군주 | 1 / 4 | 77.0 / 36.6 | +5.2% / −2.2% | 206.9 / 92.1 | ×2.69 / ×2.52 |
  | 수정 여왕 | 1 / 4 | 73.9 / 36.1 | +0.9% / −3.5% | 193.7 / 83.8 | ×2.62 / ×2.32 |
  | 전갈 여왕 | 1 / 4 | 74.4 / 35.9 | +1.6% / −4.0% | 147.4 / 65.7 | ×1.98 / ×1.83 |
  | 폭풍 군주 | 1 / 4 | 69.1 / 34.5 | −5.7% / −7.7% | 174.1 / 74.1 | ×2.52 / ×2.15 |
  모형 단위(보스 HP = 순딜 60초분)라 실제 게임 초와 다르다. 관례 환산 계수 ×1.259는 PRD 12138에 있다.
- **봇 실측(`/gg party killsim`, 궁수 L100 · 스테이지 100 · uptime 0.65)** - PRD 8665-8681: 1인 95.5초 · 2인 66.8 · 3인 54.0 · 4인 46.5(예상 91.1/63.5/51.5/44.3). 이 측정은 성장률 k = 1.155 시절 값이다(지금 `shared/data/InfiniteStageConfig.lua:17` `growthRate = 1.02`) [다시 재야 함].
- **받은 피해 관련 기존 서술**: "회복 수단이 없는 솔로는 파훼 전 시간을 다 채우기 전에 두 번째 기믹 실패(≈ 37초)에서 죽는다" - PRD 12103-12107, 12153. 인접 스킬 쌍 최악 97.9%(실수 2회 합 = 돌진 55% + 강타 42.9%) - PRD 12919, 12939, 14485. 치유사 쉴드 모형의 보스전 초당 순 손실 딜러4 대비 67% - PRD 17134.
- **실제 사람이 끝까지 친 보스 처치 시간 = 없음.** B7(실클릭 보스 완주, 목표 90초±10%)은 "Studio MCP가 3D 클릭을 못 넣음"으로 사람 확인 몫으로 남아 있다 - PRD 10274, 10326.

---

## 6. 보스 난이도 수치 정의 위치 · 값

| 항목 | 값 | 위치 |
|---|---|---|
| 보스 HP | 그 스테이지 tier1 잡몹 HP × **20** × 파티 N^p | `BossData.lua:249`, 계산 `shared/BossRules.lua:233` |
| 파티 HP 지수 p | 1 − ln(1.155^5)/ln 4 ≈ **0.480** (4인 HP ×1.946, 처치 시간 ×0.487) | `BossRules.lua:34-41`, `BossData.lua:815`(`intervalPowerRatio`) |
| 보스 공격력 | tier1 잡몹 공격 × **1** | `BossData.lua:250`, `BossRules.lua:217` |
| 잡몹 성장 | k = 1.02/스테이지(HP · 공격) | `InfiniteStageConfig.lua:17` |
| 평타 | 위 2절(주기 0.75~1.5초 · 배율 0.75~1.5 · 사거리 14) | `BossData.lua:373` 등 |
| 패턴 피해 | 평타 ×1~×3 · 돌진/기믹 실패 = 최대체력 **55%**(전갈 잠행 27.5%) | 2절 표, `BossData.lua:56`(`gimmickFailMaxHpFraction`) |
| 파훼 게이트(받는 피해) | ×0.487 | `BossRules.lua:46-48` |
| 전역 쿨 · 격노 | 5/6/7초 · HP 20% 이하 2.5초 · 입장 유예 2초 | `BossData.lua:260-268` |
| 잡힘 자동 해제 | 9초 | `BossData.lua:65` |
| 범위 배율 | 스테이지 25까지 1 → 1.152 | `BossRules.lua:60-66` |
| 밀도(낙하 원 +1~3) | 옛 스테이지 25부터 25마다 | `BossData.lua:145` |
| 목표 클리어 시간 | 모형 기준 = 순딜 60초분(`referenceKillSeconds`) · 6종은 기준 ±10% · 파훼 전 ÷ 후 1.8~2.7배 | `BossData.lua:171`, PRD 14481 |
| 경제 시뮬의 도전 한도 | 캐주얼 120초 · 보통 90초 · 상위 60초 | `EconSimConfig.lua:50, 59, 67` |

---

## 7. 외곽선 현황

| 대상 | 방식 | 개수 | 거리별 끄기 | 근거 |
|---|---|---|---|---|
| 보스 아레나 **기반**(바닥 · 벽 고리 · 테라스 모델) | `Highlight` "CartoonOutline", 채움 투명 1, `DepthMode = Occluded`, 색 `UIColors.metalOuter` | 아레나 슬롯당 1 | 없음 | `server/BossArenaMap.lua:63-73, 118`, 색 `shared/data/BossArenaMapData.lua:327` |
| 보스 아레나 **장식 + 구조물**(dressing 모델 하나로 묶음) | 같음 | 보스전마다 1 | 없음 | `BossArenaMap.lua:877` |
| 몹 · 보스 · 상자 · 구조물(조준 대상) | `Highlight` "AimHighlight"(노랑 255,230,90) - **기본 꺼짐**, 조준한 1마리만 켬 | 몹마다 1(꺼진 채) | 해당 없음 | `server/MonsterSpawner.lua:249-257, 392-397`, `BossArenaMap.lua:749-756`, 켜기 `client/AimTarget.lua:66-86` |
| 플레이어 무기 +22 이상 | `Highlight` "EnhanceOutline"(ember 색) | 무기당 1 | 없음 | `client/WeaponEnhanceVisual.lua:153-170`, 데이터 `shared/data/EnhanceVisualData.lua:25` |
| 사냥터 지형 · 마을 · 몹 몸 · 보스 몸 · 플레이어 몸 | **외곽선 없음** | 0 | - | `ZoneTerrain` · `HuntingGround` grep 결과 Highlight 0 |
- **뒤집힌 헐(inverted hull) 없음** - "outline/inverted/hull" grep에서 아레나 Highlight 말고 없음.
- 설계 메모: "아레나당 모델 2개 = 기반 1 + 장식 1, 한도 31 안: 12슬롯 × 2 = 24" - `BossArenaMapData.lua:7-8`. 한도가 255로 오른 지금은 이 제약 근거가 느슨해졌다(11절).
- 구조물 금 무늬는 외곽선 색 파트(`ObstacleCrack`) - `server/BossArenaLooks.lua:298, 305`.

---

## 8. 맵 현황

### 사냥 구역 - 3×3 격자 중 tier 6칸 (`shared/data/WorldConfig.lua:62-75`)
| 구역 | 몹 | 지형 데이터 | 바닥색 |
|---|---|---|---|
| tier1 | 슬라임 | **있음** "슬라임 초원"(언덕 3 · 웅덩이 3 · 단 · 오두막 · 나무 4 · 바위 · 꽃) `ZoneTerrainData.lua:76-125` | 중립 잔디(90,140,70)와 tier 몸색 45% 섞음 - `server/HuntingGround.server.lua:34-41` |
| tier2 | 고블린 | **있음** "고블린 숲"(개울 · 워터슬라이드 · 버섯 · 천막 · 토템) `ZoneTerrainData.lua:126-250` | 같은 식 |
| tier3~6 | 오크 · 트롤 · 골렘 · 드래곤 | **없음** - 평평한 바닥만(`ZoneTerrain.build`가 `ZoneTerrainData.zones[key]`가 없으면 features 0 - `server/ZoneTerrain.lua:652-654`) | 같은 식 |
| 그 외 | 리스폰 마을(지형 있음 `:251`) · 강화소 · 커뮤니티 광장 | - | `ROLE_FLOOR_COLOR` |
- 재질 표(`surfaces`)는 데이터에 모여 있다(잔디 · 흙 · 바위 · 물 · 마을 등 약 40종, 로블록스 기본 Material + RGB, textureId 칸만 비어 있음) - `ZoneTerrainData.lua:26-74`. 둘레 바위 능선 `:354-367`.

### 보스 맵 6종 + 기본 (`shared/data/BossArenaMapData.lua:184-326`, 반경 140 원형 · 24각 벽 · 높이 14 `:22-30`)
| 보스 | 맵 이름 | 바닥 | 벽 | 테라스 | 줄 |
|---|---|---|---|---|---|
| 구간 수호자 | 공허의 제단 | (40,38,56) | (62,54,84) | (24,22,32) | 186-190 |
| 서리 거인 | 빙하 동굴 | (186,218,234) | (132,184,212) | (92,138,168) | 205-209 |
| 심해 군주 | 수몰 사원 | (46,78,86) | (74,98,94) | (30,52,62) | 224-228 |
| 수정 여왕 | 수정 동굴 | (34,32,50) | (54,48,74) | (22,20,34) | 244-248 |
| 전갈 여왕 | 모래 유적 | (222,198,142) | (196,162,108) | (170,136,88) | 262-266 |
| 폭풍 군주 | 폭풍 첨탑 | (62,68,84) | (86,92,112) | (40,44,56) | 281-285 |
| (테마 없음) | 시련의 원형장 | (44,40,44) | (70,62,66) | (28,24,28) | 301-305 |
- 재질은 전부 `SmoothPlastic`(빛 · 물만 Neon · 반투명). 색 규칙: 바닥은 보스와 대비, 빛나는 무늬 · 장식은 보스 머리색(`glow = "head"`) - `BossArenaMapData.lua:7-11`.
- 보스 몸색 = 잡몹 tier 색 재사용(수호자 · 심해 tier1, 서리 tier2, 폭풍 tier3, 전갈 tier4, 수정 tier6) - `BossData.lua:275-280`.

### 색이 데이터에 모여 있는가
- 맵 · 몹 · 보스 · UI 색은 대부분 데이터 파일에 있다: `BossArenaMapData`(66개), `UIColors`(28), `ItemVisualData`(14), `MonsterData`(6), `ZoneTerrainData`(RGB 표).
- **데이터 밖 색 리터럴**(스타일 바이블로 모을 대상): `client/BossPatternVisuals.client.lua`(14), `server/HuntingGround.server.lua`(12 - 바닥 · 역할 구역색), `client/Projectiles.lua`(6), `server/MonsterSpawner.lua`(6 - 기본 몸색 · 조준 노랑), `client/HitEffects.lua`(3 - `:31-43`), `client/BossMotionView.lua`(흙먼지 · 지팡이 `:21-23`), `client/BossRegrowView.lua`(2) 등(`Color3.fromRGB` 개수 grep).

---

## 9. 몬스터 모델

- **파트 조립 100%.** 몸통(Block) + 머리(Ball) + 투명 루트 + (보스만) 부착물(Wedge/Block/Ball) - `server/MonsterSpawner.lua:88-110, 143-188`. 재질은 지정 없음 = 기본 Plastic [추정: `Material` 대입 줄 없음]. 메시 · 무료 모델 · 에셋 id 없음(몹 · 보스 쪽 `rbxassetid` grep 0).
- 에셋 id를 쓰는 곳은 두 파일뿐: 무기 메시(`shared/data/WeaponModelData.lua:12-21, 39, 50, 99-100` - Creator Store 무료 "Dual Bronze Sword" · "garnet staff" 메시, 활은 무료 에셋 좌표를 Part로 옮김), 스킬 아이콘(`shared/data/SkillIconData.lua:7-20`, 8개).
- 잡몹 = 6 tier(슬라임 · 고블린 · 오크 · 트롤 · 골렘 · 드래곤, `shared/data/MonsterData.lua:108-113`) - **모양은 전부 같은 "상자 + 공"**이고 tier마다 색 · 크기(`sizeScale = r^0.5`, tier6 약 1.5배 - `:147, 175-177`)만 다르다. 이름만 판타지 종족이다.
- 변종: 접두사 3종(연약한 0.8배 · 단단한 1.2배 · 거대한 1.45배 - `shared/data/MonsterPrefixData.lua:33-56`) + 반짝이(클라 발광 · 태그만) + 보물상자(별도 모델 `MonsterSpawner.lua:266-`).
- 보스 6종 = 같은 뼈대에 몸통 비율(`bodyAspect`) · 크기 · 부착물 2~3개로 실루엣만 구분(1절 표).
- "아트 동결" 전제가 곳곳에 적혀 있다: `MonsterSpawner.lua:112-114`, `MonsterData.lua:95-98`, `EnhanceVisualData.lua:2`.

---

## 10. 보스 연출 1차(P3d) "카툰" 작업 요약 (`docs/phase/P3d-report.md` ①②, 코드 `client/BossMotionView.lua` · `shared/data/BossFxData.lua`)
- **찍기 모션(A1)**: ring 스킬을 쓰는 3종만 - 수호자 두 손 내려찍기 · 심해 꼬리 휘두르기 · 폭풍 지팡이 찍기. 전조의 60% 들어 올림(세로 ×1.25) → 25% 꼭대기 멈칫(떨림) → 15% 찍기 → 0.35초 납작(×0.7) 뒤 튀어 돌아옴 - `BossFxData.lua:26-32`. 서리 · 수정 · 전갈은 "그대로"(보고서 ① 표).
- **방식**: 서버 보스 모델을 내 화면에서만 숨기고(`LocalTransparencyModifier`) 같은 모양의 복제 인형을 서버 피벗에 매 프레임 붙여 과장한다. 판정 위치는 서버 그대로 - `BossMotionView.lua:1-3`.
- **풍압(A2)**: 먼지 14 · 바람 줄기 10 · 흰 고리(반경 16) · 45 스터드 안 화면 흔들림(최대 0.35 · 0.22초, Attribute로 끔) - `BossFxData.lua:34-42`.
- **땅 파도(A3)**: 파동 띠 안에 흙 마루 32조각 - `BossPatternVisuals.client.lua:355-369`.
- **돌진(A4)**: 발 긁기 · 앞으로 ×1.28 늘어남 · 속도선 · 잔상 4 · 먼지 꼬리 · 도착 파편.
- 성능: 효과 조각 동시 상한 90 · 풀 120 · 다른 멤버 효과는 0.5배 - `BossFxData.lua:20-24`.
- 같은 P3d에 지형지물 재생성 · 단상 균열 · 이탈 복귀 · 치유사 버프 상향도 들어 있다(연출과 별개).

---

## 11. 로블록스 Highlight 공식 한도 · 성능

- **한도 255 확인.** 공식 공지 "Lights, Camera, More Highlights!"(2025-11-10): "increased the maximum number of Highlight instances you can have in an experience's DataModel to 255. This is live today!" - <https://devforum.roblox.com/t/lights-camera-more-highlights/4061534>
- 공식 문서 Highlighting: "Studio only displays **255 simultaneous Highlight instances on the client-side** at a time." - <https://create.roblox.com/docs/effects/highlighting>
  - (옛 한도 31 요청 스레드: <https://devforum.roblox.com/t/increase-highlight-limit/2628557>)
- 성능 주의(같은 문서 · 공지):
  - 화면의 **첫 번째 Highlight가 비용 대부분**(모바일에서 GPU 최대 약 1ms), 그 뒤 추가분은 대체로 크지 않다.
  - 모바일은 Highlight가 **화면을 많이 덮을수록** 비용이 커진다(다른 플랫폼은 거의 일정).
  - **꺼져 있거나(Enabled=false) 완전히 투명하면 비용 0** - 이 프로젝트의 꺼진 AimHighlight 방식이 여기 맞는다(`BossArenaMap.lua:749` 주석도 같은 전제).
  - 속성 바꾸기는 가볍지만 **인스턴스 추가/삭제는 지오메트리 재구성으로 순간 부하**가 날 수 있다 → 외곽선은 미리 만들어 두고 켜고 끄는 편이 낫다.
  - 공지: "각 강조 대상은 따로 그려져 드로우콜 비용이 있고, 화면에 하나라도 보이면 후처리 비용이 든다."
- 이 프로젝트에 대입: 보스전 화면 기준 드로우콜 6 · 삼각형 7,904(`docs/perf/baseline.md` B1 클라 표 보스전 행)로 여유가 크다. 아레나 외곽선 2개 + 조준 1 + 무기(+22) 최대 4(파티)라 255와 거리가 멀다. 다만 아레나 Highlight는 **벽 고리 전체 · 장식 전체를 덮는 큰 모델**이라 "화면을 많이 덮으면 모바일 비용 증가" 쪽에 해당한다 [추정 - 폰 실기 측정 없음, baseline도 "기기 성능 미반영"이라고 적음].

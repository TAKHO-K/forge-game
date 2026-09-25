# 감사 - 몬스터·보스 리그 구조와 "코드 절차 모션" 도입 비용 (읽기 전용)

범위: `roblox/src/`(경로는 이 기준), `docs/perf/baseline.md`, `docs/phase/P3d-report.md`, `docs/phase/P3d-F-report.md`. 기존 감사 `docs/phase/D0-audit-appendix/D-combat-feel-art-state.md`(이하 "D감사")와 겹치는 내용은 줄 번호만 가리키고 다시 조사하지 않았다. 저장소 수정 없음 · Studio MCP 안 씀.
표기: 확인 못 한 것·엔진 동작 추론은 **[추정]**. 계산값은 코드 상수로 직접 계산.

---

## 1. 모델 구조 (`server/MonsterSpawner.lua`)

### 1-1. 잡몹 · 보스 · 분신 · 얼음(구출 대상) = `buildModel` 하나 (`:118-263`)
| 인스턴스 | 종류 · 크기 | Anchored | CanCollide | 비고 |
|---|---|---|---|---|
| Model | `ModelStreamingMode = Atomic` `:131`, 태그 `Monster`(`:132`) · 반짝이면 `SparkleMonster`(`:139`) | - | - | `PrimaryPart = root` `:261` |
| `HumanoidRootPart` | Part (2,2,1)×sizeScale, 투명 1 | **true** `:147` | false | **판정의 유일한 위치**(D감사 1절: AimPicker · Reach · SkillCombat 전부 PrimaryPart 거리) |
| `Body` | Part Block (2.4·aX, 3·aY, 1.2·aZ)×s | **true** `:160` | false `:172` | 색 = data.bodyColor |
| `Head` | Part Ball 1.6×s | **true** `:181` | false `:182` | 이름표 BillboardGui 부모 `:201-207` |
| 부착물(보스·분신만) | Wedge/Part/Ball 2~3개 `:88-110` | **true** `:101` | false | `CFrame` 절대 좌표로 한 번 배치 |
| `Humanoid` | MaxHealth 100 더미 `:190-195` | - | - | HealthDisplay Off · NameDisplayDistance 0 |
| NameplateGui · NameLabel · HpBar 프레임 4 · UICorner 2 | `:201-247` | - | - | 보스 · 분신은 HP바 없음 `:223` |
| `AimHighlight` | Highlight, 꺼짐 `:251-257` | - | - | 클라 AimTarget이 켬 |

- **연결(용접) = 없음.** Weld · WeldConstraint · Motor6D 어느 것도 안 만든다. 모든 파트가 **각자 Anchored = true**인 독립 파트이고, 한 덩어리로 움직이는 것은 `Model:PivotTo`가 파트 하나하나의 CFrame을 옮기기 때문이다. (프로젝트 전체에서 Weld 계열은 `client/StuckArrows.client.lua:77`(WeldConstraint - 화살을 Head에 붙임)과 `client/WeaponVisual.lua:254-296`(플레이어 어깨 Motor6D/AnimationConstraint)뿐.)
- **Humanoid 용도 = 사실상 없음.** 주석은 "애니메이션·이름표 전용"(`:80-81`)이지만 몬스터 Humanoid를 읽는 코드가 0이다(`FindFirstChildOfClass("Humanoid")` grep - 유일한 사용처 `client/BossRhythmView.lua:97`는 플레이어 루트용). HP는 `MonsterState`, 이름표는 BillboardGui. 이름표 기본 표시를 끄려고 NameDisplayDistance 0으로 둔 더미.
- **AnimationController · Animator = 없음**(D감사 3절: Animation 관련 grep 0).
- 파트 수(baseline 인구조사): 잡몹 파트 3 · 인스턴스 11, 보스 파트 6 · 인스턴스 10(`docs/perf/baseline.md` B3 표).

### 1-2. 보물상자 `buildChestModel` (`:270-402`)
- root(투명, Anchored) + Body(WoodPlanks, Anchored, **CanCollide = true** `:290`) + Trim(Neon) + Head(Neon 공, PointLight · Beam 빛기둥 `:318-342`) + Humanoid 더미 + 이름표 + AimHighlight. 용접 없음. `ModelStreamingMode` **지정 없음**(기본값) - 잡몹과 다르다.
- MonsterAI가 건너뛴다(`server/MonsterAI.server.lua:283-285`) → 한 번도 안 움직인다.

### 1-3. 서버가 위치를 옮기는 방식 (`server/MonsterAI.server.lua`)
- `RunService.Heartbeat`(`:248`) 한 루프가 모든 몬스터를 돈다. `chasing` · `returning` 상태일 때만 `stepToward` → `model:PivotTo(CFrame.new(x, y, z))`(`:194`) - **매 Heartbeat(≈60Hz)**, **회전 없음**(항상 축 정렬). 복귀 도착 · 막힘 순간이동도 PivotTo(`:395, :407`).
- `idle`은 PivotTo를 안 한다. 플레이어 없는 구역의 idle 몹은 스캔도 건너뛴다(`:274-276`).
- 보스 패턴도 서버 PivotTo: hop(떠오름 `server/BossPatterns.lua:850, 889, 905`), 잠행(`:1196-1250`, 파트 Transparency 1로 숨김 `:1177-1184`), 돌진 · 헤롱 기울기(`:1288, 1303, 1713`), 분열 위치(`:1519`), 태세 가라앉음(`:1653`). 전조 때 **Body 색을 서버가 바꾼다** `setBodyColor`(`:130-135`, 호출 `:685, 730, 734, 1812`).
- 네트워크 소유권: `SetNetworkOwner` 호출 0(grep). 파트가 전부 Anchored라 **서버 소유 고정** - 공식 문서 "The server always owns anchored BaseParts and you cannot manually change their ownership."(<https://create.roblox.com/docs/physics/network-ownership>). 복제 = PivotTo가 바꾼 **파트마다의 CFrame 속성 복제**(잡몹 3 · 보스 5~6파트) [추정: 앵커 파트는 물리 보간 없이 속성 복제로 전달 - Stats로 잰 적 없음].
- 스트리밍: 잡몹 모델 Atomic(`:129-131`, "3파트가 따로 스트리밍되지 않게"). 공식: "all of its initial descendants are streamed in together ... streams out only when all its descendant parts qualify"(<https://create.roblox.com/docs/workspace/streaming>). `StreamingTargetRadius` 권장 600은 코드로 못 써서 Studio 수동 적용 대상(`shared/data/WorldConfig.lua:44-52`, `server/HuntingGround.server.lua:324-331`) - **실제 적용 여부는 이 조사로 확인 못 함 [추정]**.

---

## 2. 지금의 "인형(복제)" 모션 (`client/BossMotionView.lua`)

### 구조
- 이벤트 경로: 서버 `BossPatterns.send`가 `BossPatternEvent`를 **파티 멤버에게만** FireClient(`server/BossPatterns.lua:153-161`) → `client/BossPatternVisuals.client.lua:554` OnClientEvent → `shockTelegraph`면 `BossMotionView.slamWindup`(`:613`), 첫 파동이면 `slamImpact`(`:618`), 돌진 전조 `chargeWindup`(`:623`), 돌진 `chargeRun`(`:626`), 초기화 `reset`(`:644, 659`).
- 숨기기: `buildPuppet`(`:90-127`)이 서버 모델의 BasePart 중 루트 · 투명 파트를 뺀 것을 `part:Clone()` → `ClearAllChildren` → Anchored · CanCollide/Query/Touch false로 `Workspace/BossPuppet` 모델에 넣고, 원본은 `LocalTransparencyModifier = 1`(`:111-112`, 복원 `:76-80`). 원본 기준 오프셋 `pivot:ToObjectSpace(part.CFrame)`를 저장(`:108`).
- 움직이기: `RunService.RenderStepped` 하나(`:469-473`)가 `stepCharge` · `stepPuppet`. `applyPose`(`:130-144`)가 **매 프레임 서버 피벗(`model:GetPivot()`)** × 발밑 기준 × (lean, yaw) 회전 × 축별 늘림으로 각 복제 파트의 `CFrame`과 `Size`를 직접 대입. 팔 · 꼬리 · 지팡이 = `extras`(`SLAM.*` `:147-198`)의 place 함수.
- 시간표: 서버가 준 전조 초(`data.seconds`)를 `windupFraction 0.6 · holdFraction 0.25`로 나눔(`:201-225`, `shared/data/BossFxData.lua:26-32`). 끝나면 `recover` 0.35초 뒤 `disposePuppet`로 인형 파괴 + 원본 다시 보임.
- 풀링: 팔 · 꼬리 · 지팡이 · 먼지 조각은 `BossFx.acquirePart/releasePart` 풀(`client/BossFx.lua:67-76`, 상한 `maxActive 90` · `poolKeep 120` - `BossFxData.lua:22-23`). **인형 본체 복제(6개)와 잔상(ghostMax 4 × 파트 수)은 풀링 안 함** - 모션마다 Clone/Destroy(`:101, 294, 85-87`). P3d 보고서도 "잔상 모델 돌진마다 생성(보고)"로 남김(`docs/phase/P3d-report.md:143`).
- 인형은 **전역 1개**(`local puppet` `:59`) - 한 클라가 동시에 한 보스만 과장할 수 있다. 분신(태그 `RescueTarget`)은 `findBoss`가 건너뛴다(`:48`).
- 피격 · 사망(`client/HitEffects.lua`): 인형이 아니라 **서버 파트를 클라에서 로컬로** 건드린다 - 색 번쩍(`:79-92`), 사망 때 Size · Transparency 트윈(`:117-134`). 위치(CFrame)는 "서버가 매 프레임 덮어써서" 일부러 안 건드림(`:71-78`). 호출은 **공격한 본인 클라만**(`AttackInput.client.lua:401-403`, `SkillInput.client.lua:65-67`, `StuckArrows.client.lua:105-107` ← 서버 `attackResult:FireClient(player, ...)` `server/AttackServer.server.lua:245, 310`). 다른 플레이어 화면에는 피격 반응 · 사망 연출이 없다(0.8초 뒤 모델이 그냥 사라짐 - `MonsterSpawner.lua:584-586`).
- 비슷한 선례: `client/SparkleMonsterVisual.client.lua` - 태그 추가 신호로 모델 **밖에** 클라 전용 파트를 만들고 RenderStepped에서 `GetPivot()`을 따라감(`:1-12, 105-111`). "클라 전용 시각 레이어" 방식이 이미 한 번 쓰였다.

### 측정 기록
- **프레임당 CPU 시간 측정 = 없음.** 있는 것은 파트 · 조각 수뿐: 연출 조각 동시 최대 찍기 57 · 돌진 32, 클라 파트 찍기 +209 · 돌진 +177(인형 + 잔상 20) - `docs/phase/P3d-report.md:109-120`. 서버 보스 step 평균 52.3μs(같은 표).
- baseline 클라 렌더 CPU 최대: 사냥 PC 6.84ms · 폰 근사 **13.16ms**(튀는 값) · 보스전 6.44/5.89ms(`docs/perf/baseline.md:283-288`).

---

## 3. 코드 절차 모션 도입안 비교

공통 전제(확인됨): 서버 판정은 **루트(PrimaryPart) 위치만** 본다(D감사 1절). 서버 코드가 Body/Head를 읽는 곳은 색(`BossPatterns.lua:130-135`)과 잠행 투명(`:1177-1184`), 검증(`BossGimmick5Verify.lua:492-495` - 분신 · 보스의 Body 크기 · 색 · **하위 인스턴스 수** 대조)뿐 → 시각 파트의 위치를 클라에서만 바꾸면 판정은 구조상 영향이 없다.

### (A) 인형 방식 확장 - 서버 모델은 그대로, 클라가 보이는 몹마다 복제본을 상시 운용
- 작업: `BossMotionView`의 `buildPuppet/applyPose/disposePuppet`을 "몹마다 1개 · 거리 안에서만" 관리하는 새 모듈로 일반화(전역 `puppet` 1개 → `[model] = puppet` 표), 태그 `Monster` InstanceAdded/Removed 구독, 복제본 풀링(지금은 Clone/Destroy). 상태(대기 · 이동 · 공격 · 피격 · 사망) 곡선은 데이터 파일(`shared/data/…MotionData`, `AttackMotionData`처럼)로.
- 딸려 고칠 곳: `HitEffects` 번쩍 · 사망이 **숨긴 서버 파트**에 적용돼 안 보임 → 인형 파트로 돌려야 함. `AimHighlight`는 모델(숨긴 파트)에 붙어 있음 → 숨긴 파트의 외곽선이 그려지는지 [추정: 안 그려질 가능성] - 인형 쪽 Highlight 필요. `StuckArrows`는 서버 Head에 용접 → 흔들리는 인형 머리와 어긋남. 서버 `setBodyColor`(전조 색) · 잠행 투명을 인형이 매 프레임 따라 복사해야 함. `LocalTransparencyModifier`는 스트림 아웃 → 인 때 사라짐(공식: "local-only changes to instance properties ... can be lost if the instances streams out and later streams back in") → 재적용 필요.
- 장점: 서버 · 저장 · 검증 무변경, 이미 검증된 방식. 늘림/찌그러짐(Size) 가능. 서버 복제 트래픽 **변화 0**.
- 단점: 보이는 몹마다 파트가 2배(서버 원본 + 복제), 위 우회 5곳. 몹이 PivotTo로 옮겨질 때 복제본은 RenderStepped에서 따라가므로 1프레임 지연은 없음(같은 프레임 GetPivot).

### (B) 파트를 Motor6D로 연결 + 클라에서 `Motor6D.Transform`만 조작 (권장 - 잡몹 상시 모션)
- 서버 작업(`MonsterSpawner.buildModel` `:142-259` · `buildChestModel`): root만 Anchored, Body · Head · 부착물은 `Anchored = false` + `Motor6D`(Part0 = root, Part1 = 파트, C0 = 지금 오프셋)로 root에 연결. PivotTo는 그대로(모델 피벗 = root, 어셈블리 통째로 이동). CanCollide는 이미 false라 물리 영향 없음(어셈블리가 앵커라 시뮬레이션 안 함 [추정]).
- 클라 작업(새 `client/MonsterMotion.client.lua` 1개 + 데이터 `shared/data/MonsterMotionData.lua`): 태그 `Monster` 추적 → 카메라 거리 안의 모델만 `RunService.PreSimulation`에서 `motor.Transform = 곡선 CFrame` 대입(대기 숨쉬기 = Body Y 미세 이동 · 기울기, 이동 통통 = pivot 변화량으로 걷는 중 판단 후 사인 bob, 공격 = 앞으로 lean, 피격 = 짧은 뒤로 젖힘, 사망 = 가라앉으며 기울기).
- 공식 근거(<https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Motor6D.yaml>): Transform 태그 **NotReplicated**; "Motor6D transforms are not applied immediately ... but rather as a batch in a parallel job after RunService.PreSimulation ... much more efficient than many immediate updates"; "If the Motor6D is part of an animated model with an Animator, then Motor6D.Transform will usually be overwritten every frame by the Animator" → 지금 Animator가 없으니 덮어쓰기 없음. 나중에 Animation 에셋을 쓰면 AnimationController + Animator(Humanoid 대체 - <https://create.roblox.com/docs/reference/engine/classes/AnimationController>)로 가고 절차 모션은 PreSimulation에서 곱해 얹는다.
- 판정 영향 없음 보장: Transform은 복제 안 됨 → 서버의 Body/Head는 휴식 자세 그대로, 판정은 root만. 검증: 서버에서 클라 모션 중 `Body.CFrame == root.CFrame * C0` 확인 한 줄.
- 복제 트래픽: 추가 0(Transform 비복제). 오히려 이동 몹 1마리당 복제되는 CFrame이 파트 3개 → root 1개로 줄 가능성 [추정 - 결합된 파트의 위치는 클라가 조인트로 계산. PerfProbe에 네트워크 수신 KB/s를 추가해 전후 비교 필요].
- 한계: Transform은 CFrame이라 **크기(늘림 · 찌그러짐)는 못 한다** → 찌그러짐은 클라 로컬 `Size` 트윈으로(서버가 Size를 안 쓰므로 유지됨 - `HitEffects.playDeath`가 이미 이렇게 함). 보스의 과장 찍기 · 돌진은 지금 인형(A) 그대로 두고, 인형 재생 중에는 그 보스의 Transform 모션을 멈춘다.
- 딸려 고칠 곳: `BossMotionView.buildPuppet`의 오프셋이 Transform이 얹힌 자세를 찍으므로 인형 시작 전 Transform을 원점으로(작음). `BossGimmick5Verify`의 하위 인스턴스 수는 분신 · 보스가 같은 `buildModel`을 쓰니 동일하게 늘어 통과 [추정]. 인스턴스 +2(잡몹) · +4~5(보스) → baseline 예산(인스턴스 ≤ 20) 안.

### (C) 클라 전용 시각 모델 - 서버는 투명 루트(+ 이름표 앵커)만
- 서버 작업: `buildModel`에서 Body · 부착물 제거(또는 투명), 모델 Attribute로 외형 키(`MonsterId` · `SizeScale` · `BodyAspect` · 접두사) 전달, `setBodyColor` · 잠행 투명을 Attribute(`BodyTint`, `Hidden`)로 바꿈. 클라 작업: 태그 추적 → 데이터로 시각 모델 조립(모델 **밖**, SparkleMonsterVisual과 같은 방식) → BulkMoveTo로 매 프레임 배치.
- 딸려 고칠 곳(가장 많음): `HitEffects`(Body/Head) · `DamageNumbers:26` · `AimTarget:76`(Head) · `StuckArrows`(Head 용접) · `BossPatternVisuals:187` · `BossGateView:20` · `BossMotionView`(복제 대상) · `AimHighlight` 위치 · `BossGimmick5Verify:492-495` · PerfProbe 인구조사 · 서버 `BossPatterns` 색/투명 7곳.
- 장점: 서버 파트 54×2 = 108개 감소(워크스페이스 파트 1,046 → 약 938 [계산]) · 이동 복제 1파트. 나중에 메시 교체가 클라 한 곳. 크기 과장도 자유.
- 단점: 변경 범위 최대, 스트리밍 들어올 때마다 조립 비용, 서버 없는 "보이는 것 = 클라 추측"이 늘어 버그 추적이 어려움. 지금 단계에서 이득(서버 파트 10% 감소)이 비용보다 작다.

### 요약 비교
| 항목 | (A) 인형 확장 | (B) Motor6D + Transform | (C) 클라 전용 모델 |
|---|---|---|---|
| 서버 파일 변경 | 없음 | `MonsterSpawner` 2함수 | `MonsterSpawner` · `BossPatterns` · 검증 |
| 클라 새 코드 | 모듈 1(인형 풀) + 우회 5곳 | 모듈 1 + 데이터 1 | 모듈 1 + 고칠 곳 약 10 |
| 늘림 · 찌그러짐 | 가능 | 로컬 Size 트윈으로 | 가능 |
| 추가 파트(클라) | 보이는 몹 × 2~5 | 0 | 0(서버 파트가 줄고 클라가 같은 수 생성) |
| 복제 트래픽 | 0 | 0(줄 가능성 [추정]) | 줄어듦 [추정] |
| 판정 영향 | 없음(클라 파트) | 없음(NotReplicated) | 없음(판정 root만) |
| 앞으로 Animation 에셋 | 인형에 Animator 달기 어려움 | **바로 연결**(AnimationController) | 클라 모델에 달면 됨 |

권장: 잡몹 · 상자 · 보스 상시(대기 · 이동 · 평타 · 피격 · 사망) = **(B)**, 보스 스킬 과장 = 지금 **인형 유지**. [판단 - 사람 결정 필요]

---

## 4. 12인 성능 예산

### 매 프레임 갱신할 모델 수(클라 1명 기준)
- 사냥터: 구역 1개 = 3×3 격자 · 간격 64(`WorldConfig.lua:9-18`) → 구역 안 몹은 중심에서 최대 90.5 stud(모서리 64√2). 옆 구역 가장 가까운 몹까지 = 64(여백) + 32(복도) + 64 = 160 stud 이상 떨어짐 [계산]. **거리 컬링 반경 120**이면 보이는 몹 ≤ 9(+ 상자 · 경계에 선 경우 이웃 일부) → 상한 12로 잡으면 충분.
- 보스전: 자기 보스 1 + 분신(29-5). 슬롯 간격 ≈ 2×(140 + 4 + 40) + 100 = 468 stud [계산 - `BossArenaMapData.lua:27-38`]라 컬링 120이면 남의 보스 0. 스트리밍 반경 600이 적용돼 있으면 이웃 아레나 보스가 클라에 **존재는** 하므로 컬링이 꼭 필요.
- 12인 서버 전체 몬스터 수(54 + 보스 12)는 클라 비용과 무관 - 클라는 거리 안 ≤ 12~15개만.

### 프레임당 CPU 예산 제안
| 항목 | 제안 | 근거 |
|---|---|---|
| 몹 모션 전체(PC) | **≤ 0.3ms** | 모델당 곡선 계산 + Transform 2~6개 대입 ≈ 5~15μs [추정] × 15 |
| 몹 모션 전체(폰) | **≤ 1ms** | 폰은 PC의 3~5배 [추정]. 폰 근사 사냥 렌더 CPU가 이미 13.16ms로 튄 적 있음(`baseline.md:286`) - 여기에 1ms 이상 얹지 않음 |
| 컬링 거리 판정 | 0.25초마다 한 번(매 프레임 아님) | 54개 거리 계산은 싸지만 목록만 갱신 |
| 측정 방법 | 모션 루프를 `os.clock()` 합산 → 기존 클라 수집기(`PerfScene`)에 "motionMs 평균 · p95" 추가 | 지금 모션 CPU 기록 없음 |
- 파트 수 변화: (B) 0, 인스턴스 +2/몹(54 × 2 = 108 서버 인스턴스, 한 번만 복제) · +4~5/보스. (A) 보이는 몹마다 클라 파트 +2(잡몹) ~ +5(보스) → 최대 약 +30. (C) 서버 파트 −108.
- baseline 대조: 서버 Heartbeat 사냥 0.42 ~ 0.68ms(`baseline.md:276, 323`) - (B)는 서버 매 프레임 비용 변화 없음(PivotTo 그대로, 파트 연결만 바뀜). 클라 삼각형 57,600 · 드로우콜 75 - (B)는 변화 0, (A)는 복제 파트만큼 소폭 증가.
- 참고 문서: Motor6D.Transform 타이밍(위 링크), `WorldRoot:BulkMoveTo` - "a very fast way to move large numbers of parts, as you don't have to pay the cost of separate property sets"(<https://create.roblox.com/docs/reference/engine/classes/WorldRoot#BulkMoveTo>) - (A)/(C)의 클라 파트 이동에 쓸 것. `PivotTo`는 공식 문서에 성능 언급 없음(<https://create.roblox.com/docs/reference/engine/classes/PVInstance>). LocalTransparencyModifier(<https://create.roblox.com/docs/reference/engine/classes/BasePart#LocalTransparencyModifier>).

---

## 5. 서버 이벤트가 필요한가

| 모션 | 클라가 지금 알 수 있는가 | 추가 트래픽 없이 쓸 신호 | 이벤트를 새로 쓰면 |
|---|---|---|---|
| 대기 · 이동 | 예 - 피벗 변화량(움직임 여부) | 없음 필요 | - |
| 잡몹 · 보스 **평타** | **아니오** - `tryAttack`(`MonsterAI.server.lua:208-230`)은 이벤트 없이 `applyHitToPlayer`만 | ① 맞은 사람: 이미 오는 `PlayerHitFeedback`(`server/PlayerDamage.lua:20-22, 66`, 인자 = 피해 · 흡수)에 **때린 모델을 인자로 추가** → 이벤트 수 +0. ② 구경꾼: 플레이어 `Hp` Attribute(`PlayerDamage.syncHud` `:25-28` - 모두에게 복제) 감소를 가장 가까운 추격 몹에 돌리는 추측 [추정 - 여러 마리 · 보스 패턴 · 쉴드와 섞이면 틀림] | 새 `MonsterAttack` RemoteEvent를 "그 몹 반경 R 안 플레이어"에게: 몹 공격 주기 1.0초(`shared/data/MonsterData.lua:173`). 솔로가 3마리 상대 = 3/초, 4인 파티 같은 구역 = 파티 몹 전부 ≈ 12/초. baseline 사냥 수신 6.5/초 + 12 = 18.5/초 → 예산 20/초(`baseline.md:313`)에 거의 닿음 → **Heartbeat마다 모아 0.1초 묶음 1회**(≤ 10/초)로 보내야 함 |
| 피격(움찔) | 공격자만(`attackResult`) | 잡몹: `HpBarFill.Size` 복제 변화(`MonsterSpawner.lua:456`) · 보스: `BossHpRatio` Attribute(`:446`) 변화를 구독 → 모든 근처 클라가 추가 트래픽 0으로 앎. **분신은 둘 다 없음**(`:223`) → 분신만 안 움찔하면 진짜가 들킨다 - 분신 onHit 때 같은 신호(예: Attribute 1개)를 줘야 함 | - |
| 사망 | 공격자만 즉시, 나머지는 0.8초 뒤 파괴로만 | `CollectionService:GetInstanceRemovedSignal("Monster")` + "컬링 반경 안이었다"면 사망으로 보고 로컬 사본으로 연출(스트림 아웃과 구분 필요 - 스트림 아웃은 먼 곳에서만 일어나므로 반경 조건으로 구분 [추정]). 0.8초 늦음 | 모델 Attribute `DiedAt`(서버 `despawn` 한 줄 - `MonsterSpawner.lua:575-581`) - 처치 1회당 1번, 모델이 스트리밍된 모든 클라에 복제. 12명 × 처치 0.8/초(baseline 사냥 12처치/15초) ≈ 서버 전체 10/초, 클라당 ≤ 10/초(속성 1개라 작음) |
| 보스 스킬 | 예 - `BossPatternEvent`(파티 멤버만) | 이미 있음 | - |

- 시각 맞춤: 새 이벤트 · Attribute에 시각을 싣는다면 `Workspace:GetServerTimeNow()`(서버 · 클라 공통 시계)를 쓴다 - 보스 패턴도 서버 시각을 쓴다(`BossPatterns` `serverNow()`).
- 권장 최소안: 평타 = `PlayerHitFeedback`에 모델 인자 추가(맞은 사람 화면만, +0 이벤트) · 피격 = HP바/Attribute 구독(+0) · 사망 = `DiedAt` Attribute 1개. 구경꾼 평타 모션은 필요성을 사람이 먼저 판단(파티 사냥에서만 보임).

---

## 6. 먼저 알아둘 함정
1. (B)에서 몹에 **Animator가 생기는 순간**(누가 `Humanoid:LoadAnimation`을 부르면) Transform이 매 프레임 덮어써진다 - 지금 Humanoid는 쓰이지 않는 더미라 AnimationController로 바꾸거나 지워도 되는지 결정할 것(코드상 읽는 곳 0).
2. 분신(29-5)은 "보스와 겉모습이 완전히 같아야" 하는 기믹이다(`MonsterSpawner.lua:222`, 검증 `BossGimmick5Verify.lua:492-495`). 대기 · 피격 모션을 보스에만 주고 분신에 안 주면 진짜가 드러난다 → 모션 모듈은 `isDecoy`/`RescueTarget` 분신을 보스와 똑같이 다뤄야 하고, 얼음 덩어리(같은 태그)는 빼야 한다(구분 Attribute 필요 [추정]).
3. 서버 회전이 없다(모든 PivotTo가 `CFrame.new(pos)`). "몸 내밀기 · 휘두르기"는 방향이 필요하므로 클라가 대상 방향(맞은 사람 = 자기, 구경꾼 = 가장 가까운 플레이어 [추정])으로 yaw를 Transform에 넣어야 한다. 서버 PivotTo에 yaw를 넣으면 쉽지만 판정 무관이어도 서버 변경이 된다.
4. 보스 인형 재생 중(찍기 · 돌진)에는 (B)의 Transform 모션을 멈춰야 이중 모션이 안 난다(인형이 원본을 숨기므로 보이진 않지만 인형 오프셋 캡처에 섞임).

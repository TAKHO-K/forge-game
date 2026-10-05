# GUARDIAN-V3 보고서 — 구간 수호자 사용자 시험 피드백 반영

원본 지시 = GUARDIAN-V3(10-05) · 바이블 = `BIBLE-v1.md` §5 · §7 · **§11(이번 결정 수치)** · 기반 = `GUARDIAN-V2-report.md`.
**실전 교체 스위치(`BossFrameworkData.live`)는 비어 있다** — 아래 전부 Studio `/gg boss frame on`(새 몸)일 때만 뜬다. 옛 몸 · 다른 5보스 · BossData 원본 변화 0.
파일 · 에셋 · DataStore 삭제 0 · 패키지 설치 0 · 저장 구조 = 필드 추가만(v74 → v75).

## 1. 무엇이 바뀌었나

| 항목 | 내용 | 파일 |
|---|---|---|
| 공통 장치 | `BossFrameworkData.v3.section_guardian`(데이터 노브 전부) · `BossFramework.applyV3`(몸 가장자리 장치 뒤 · 인스턴스 사본 · 실전 스폰 `BossEncounter.spawnEncounter`와 모형 `BossDifficultySim`이 같은 함수) | `shared/data/BossFrameworkData.lua` · `shared/BossFramework.lua` |
| 1 근접 바닥 표시 제거 | 서버가 사건에 `noFloor`를 실어 보냄 → 클라가 평타 쓸기 · 강공격 · 원 안 내려찍기 · 강화 평타의 바닥 그림을 건너뜀(판정 · 시각 그대로). 근접 원형 구역 파랑 원도 끔(`BossInnerCircleHidden`). 예비 동작 +0.12초 · 예비 내내 손 수정 보라 발광(`BossMotion` glow · `BossAnimator.applyGlow`) | `server/BossPatterns.lua` · `BossHandlersBR1.lua` · `MonsterAI.server.lua` · `client/BossPatternVisuals.client.lua` · `BossInnerCircleView.lua` · `BossAnimator.client.lua` · `shared/BossMotion.lua` |
| 1 남기는 표시 | 돌진 경로 균열선(폭 = 몸 폭 · 판정 반폭도 같음) · 도약 착지 균열 원 · 지진파 균열 링 - 연보라 채움 + 보라 Neon 균열선 · 파트 풀 | `client/BossQuakeView.lua`(새) · `shared/data/BossFxData.lua`(`guardianQuake`) |
| 2 바나나 | 반응 스킬(스케줄러 규칙 ⑧ - 전역 쿨 무시 · 일반 후보 제외 · 끝나도 전역 쿨 · 직전 스킬 그대로) · 기존 투사체 조각 재사용(`leadFraction` · 체력 구간 `overrides` · 빗나감 `onMiss`) · 새 조건 `targetBeyondFor` · 클라 풀 · 손에 든 바나나 발광 · 교체 슬롯 `GuardianBanana` | `shared/BossScheduler.lua` · `server/BossPatterns.lua` · `BossHandlersBR1.lua` · `client/BossBananaView.lua`(새) · `BossBR1View.lua` · `tools/blender/guardian_banana.py`(새) · `art/fx/guardian_banana.*`(새 · 업로드 75948236745182) |
| 3 도약 | 새 일반 프리미티브 `leap`(보스 이름 분기 없음) · 결과 조각 `noteMiss` · `clearMisses` · 조건 `missesWithin` · 비행 중 MonsterAI가 높이차로 대상을 놓치지 않게(`BossPatterns.isLeaping`) | `server/BossLeap.lua`(새) · `server/MonsterAI.server.lua` |
| 4 이속 | 기본 × 1.3 · 대상 25 stud 밖 질주 × 1.5(`sprintBeyondStuds` · `sprintMultiplier`) | `server/MonsterAI.server.lua` |
| 5 지진파 | 땅 파동 = 앞면 돌판 16 + 바닥 균열 8 · 공중 파동 = 수정 조각 24 · 링당 ≤ 24 · 동시 링 ≤ 5 · 풀(옛 띠 · 둔덕 · 구덩이 안 그림) | `client/BossQuakeView.lua` |
| 6 크기 | `rig.scale` 1.5 → 2.0 · 카메라 1.3 → 1.73 · 강화 평타 접촉 팔꿈치 86 → 96 | `shared/data/BossRigV2Data.lua` · `BossClipSetData.lua` |
| 6 첫 보스 도움 | 전멸마다 받는 피해 −10%(최대 −30%) · 첫 클리어 전까지 · 저장 `hints.bossAssist`(v75) | `server/BossFirstAssist.lua`(새) · `BossEncounter.lua` · `CombatResolution.lua` · `PlayerProfile.lua` · `SaveSystem.lua` · `shared/data/SaveConfig.lua` |
| 6 BossSim | 반응 스킬(바나나 · 도약) · 원거리/근접 "30 stud 밖 구간" 가정 · 첫 보스 도움 옵션 · V2 비교 옵션(`noV3`) | `shared/BossDifficultySim.lua` · `tools/harness/guardian_v3_sim.luau`(새) |
| 동작 | 바나나 던지기 · 도약(웅크림 → 공중 → 두 주먹 착지) 전용 동작 2 | `shared/data/BossClipSetData.lua` |

빨간 별 에셋: `extras/vfx/ImpactStar`(ArtAssetIds 등록 · `art/extras/vfx/ImpactStar.fbx`)는 **원래 코드 어디에서도 참조하지 않았다**. 사용자가 본 "빨간 별"은 코드로 그리는 평타 쓸기 궤적(`BossBR1View.swingTrail` - 빨간 방사 칼날 31개)이었다 → 새 몸 수호자에서 그 그리기만 끊었다(함수 · 에셋 파일 그대로 · 다른 보스는 그대로 씀).

## 2. 바뀐 수치(스테이지 15 인스턴스 · 새 몸만)

| 값 | V2 | V3 | 비고 |
|---|---|---|---|
| 크기 배율 `rig.scale` | 1.5 | **2.0** | K 0.40 그대로(균일 배율 - K를 바꾸면 메시 재굽기 · 재업로드) |
| 서 있는 키(직립 머리 꼭대기 · FK) | 22.4 | **29.8 stud** | Studio 실측(× 1.92 시험 때 28.7 ~ 29.0) · 너클 자세 머리 27.0 · 등 수정 꼭대기 30.0 |
| 몸 가장자리 반폭 · 늘어난 몫 | 10.4 · +2.22 | **13.88 · +5.69** | §5 규칙 비례 |
| 강공격 원 · 전조 | 17.3 · 2.0초 | **20.8 · 2.12초** | 바닥 표시 없음 |
| 원 안 내려찍기 원 · 전조 | 14.2 · 1.3초 | **17.7 · 1.42초** | 바닥 표시 없음 |
| 강화 평타 부채 · 대상 거리 · 전조 | 17.3 · 16.2 · 1.3초 | **20.8 · 19.7 · 1.42초** | 바닥 표시 없음 |
| 평타 예비 신호 | 0.25초 | **0.37초** | 쓸기 궤적 없음 · 휘두를 손 발광 |
| 근접 원형 구역 · 반사 결계 · 추격 정지 | 14.2 · 9.2 · 10.2 | **17.7 · 12.7 · 13.7** | 파랑 원 그림 끔(판정 그대로) |
| BodyRadius(플레이어 공격 도달) | 3.30 | **6.77** | |
| 카메라 줌 | 44.2(× 1.3) | **58.8(× 1.73)** | |
| 돌진 경로 반폭(판정 · 그림) | 4.3 | **13.88** | = 몸 반폭(V2 막힌 점 4 해결) |
| 이동 속도 · 질주 | 8 | **10.4 · 25 stud 밖 15.6** | 걷기 16 |
| 바나나 | - | 30 stud 밖 1.5초 · 쿨 3 · 예비 0.45 · 110 stud/s · 리드 50% · 최대 체력 7% · 광폭 3갈래 14° | 반지름 2 · 수명 1.6초 |
| 도약 | - | 빗나감 2회/12초 · 준비 0.9(고정 0.3) · 비행 0.8 · 꼭대기 22 · 최대 60 · 반경 25.9 · 넉백 4/16 · 공격력 × 1.5 × 0.62 | 고정 뒤 걸어서 회피 필요 1.02초 ≤ 1.10초 |
| 피해 계수 `bodyEdge.damageScale` | 0.80 | **0.62** | 스킬 multiplier · 평타 · 도약(바나나 7%는 그대로) |
| 체력 `bodyEdge.hpScale` | 1.0 | **0.85** | 처치 69 → 58초 |
| 첫 보스 도움 | - | 전멸 1회 −10% · 최대 −30% · 첫 클리어 뒤 끝 | 멤버별 · 전 피해 |
| 저장 | v74 | **v75** `hints.bossAssist = { [보스] = { fails, cleared } }` | 옛 세이브 = 빈 표 |

## 3. BossSim(`BossDifficultySim` · 600판 · 솔로 · 전체 = `guardian_v3/s6_bosssim.txt` · 실행 `tools/harness/guardian_v3_sim.luau`)

| 조건 | V2(피해 0.80 · 체력 1.0) 전멸 | V3 첫 값(0.80 · 1.0 · 원거리 30 밖 0.7 가정) | **V3 최종(0.62 · 0.85)** 전멸 · 받은 피해 · 처치 |
|---|---|---|---|
| st100 원거리 · 처음 | 64.8% | 89.3% | **45.3%** · 87.1% · 58.2초 |
| st100 근접 · 처음 | 65.8% | 70.7% | **42.2%** · 84.6% · 58.2초 |
| st500 원거리 · 처음 | 67.2% | 89.5% | **44.5%** · 87.4% · 58.2초 |
| st500 근접 · 처음 | 66.5% | 69.5% | **42.3%** · 83.9% · 58.2초 |
| st100 원거리 · 아는 보스 | 48.2% | 64.0% | 27.0% · 72.2% |
| st100 근접 · 아는 보스 | 41.8% | 45.7% | 23.5% · 69.5% |
| st500 원거리 · 아는 보스 | 49.5% | 61.8% | 24.8% · 71.5% |
| st500 근접 · 아는 보스 | 43.7% | 44.8% | 21.0% · 69.8% |

- **첫 조우 목표 ≤ 50%: 근접 · 원거리 모두 충족**(42 ~ 45%).
- V3 몫(받은 피해 중): 원거리 처음 = 바나나 10.2% · 도약 1.3%(한 판 바나나 3.3회 · 도약 0.2회) · 근접 처음 = 바나나 5.1% · 도약 0%.
- 첫 보스 도움(처음 · st100): 원거리 전멸 0회 45.3% → 1회 34.8% → 2회 22.0% → 3회 10.5% · 근접 42.2% → 31.8% → 18.5% → 8.3%.
- 가정을 바꾼 근거: 첫 실행(원거리가 30 stud 밖 70%)은 원거리 처음 89%. 원거리 공격 사거리 = 활 15(10 × 1.5) + 새 몸 피격 반경 약 6.8 → 보스 중심 약 21 stud 안에서 때려야 한다 → 30 밖은 피하기 · 물러남 동안만이라 0.25로 고쳤다(보스 질주 15.6이 따라붙음).
- 크기 2.0으로 바꾼 뒤 다시 돌린 값 = 1.92 때와 같다(반경과 서 있는 거리가 같이 늘어 회피 여유 그대로 - V2와 같은 구조).
- 조정 탐색 = `guardian_v3/s6_balance_sweep.txt`(체력 0.80 · 0.85 · 0.90 × 피해 0.60 · 0.65 · 0.70 × 스테이지 100 · 500). 처음 ≤ 50%(여유 ±2%p)를 지키는 가장 높은 피해 쪽을 골랐다.

## 4. 예산 · 자동 검사

| 항목 | 값 | 상한 | 판정 |
|---|---|---|---|
| 보스 삼각형(외곽선 제외) · 부위 최대 | 28,613 · 4,975(V2와 같은 메시 - 크기만 바뀜) | ≤ 30,000 · ≤ 5,000 | O |
| 외곽선 삼각형 · 껍데기 | 7,690 · 12 | ≤ 8,000 · ≤ 12 | O |
| 보이는 MeshPart · 관절 | 44 · 28 | ≤ 90 · ≤ 60 | O |
| Neon · 아틀라스 | 9 · 1 | ≤ 10 · ≤ 3 | O |
| 새 연출 파트(클라 · 풀) | 지진파 링당 ≤ 24 · 동시 링 ≤ 5(≤ 120) - Studio 실측 최대 72 · 바나나 풀 ≤ 12(실측 2) · 바나나 메시 130삼각형 · Highlight +3(손 발광) | - | 생성/파괴 반복 없음 |

| 하네스 | 결과 |
|---|---|
| `boss_framework_test.luau` | **40/40**(V2 28 + V3 12: 다른 5보스 · 옛 몸 변화 0 · 바닥 표시 끔 · 예비 +0.12 · 돌진 폭 = 몸 폭 · 이속 · 바나나 · 도약 + 걸어서 회피 · 전 스킬 회피 부등식 실패 0 · 스케줄러 ⑧ · 첫 보스 도움 · live 비어 있음 · 직립 키 29.8) · `guardian_v3/s6_harness_frame.txt` |
| `boss_timing_dump.luau`(6보스 전조 · 피해 시각 · 회피 부등식) | 변경 전 소스 대비 **diff 0** |
| `boss_motion_test.luau`(옛 6보스 모션) | 변경 전 대비 **diff 0** · 튐 0 |
| `run_all.sh`(로컬 하네스 25종 · 저장 이관 v75 포함) | 전부 통과, 단 `enhance_g` 24/25 - **변경 전 소스에서도 같은 항목 실패**(강화 상태 저장 왕복 "무기 없음" - 기존 문제 · 이번 변경과 무관) |

Studio Play(수동 · 무장 안 함 · 개발 계정 스테이지 15):
- 스폰 로그: `몸 가장자리 +5.69 · 피해 × 0.62 · 체력 × 0.85` · `V3: 몸 반폭 13.88 · 이속 10.4(질주 25 stud 밖 × 1.5) · 반응 스킬 leap,banana · 돌진 반폭 13.88` · 모델 `BossInnerCircleHidden = true` · `BossPrepSeconds = 0.37`.
- 반응 스킬 자연 발동(보스에서 42 stud 거리로 원을 돌며 이동 · 32초): 바나나 6회 · 도약 2회 · 바나나 뒤 강화 평타가 6.01초 뒤 = 전역 쿨 그대로 · 도약 1.72초(0.9 + 0.8) · 원을 돌면 도약 피해 0회.
- **Studio에서 찾아 고친 것**: 도약 비행 중 보스가 높이 뜨면 MonsterAI "같은 지면 층" 검사가 대상을 놓쳐 패턴을 끊었다(첫 시험 1.05초에 끝 · 착지 판정 없음) → 비행 중 예외(`BossPatterns.isLeaping`). 연보라 Neon 균열선이 흰색으로 날아감 → 균열선 보라 Neon (160,90,255) · 채움 비발광. 바나나가 낙석과 같은 "?" 말풍선 → 말풍선 뺌.
- 스크립트 오류 0(로그 grep).

## 5. 정지 캡처(`docs/design/boss-bible/guardian_v3/` · 영상 없음)

| 파일 | 내용 |
|---|---|
| `s1_heavy_windup_no_floor.jpg` | 강공격 예비(두 주먹 머리 위 · 보라 발광) - 바닥 빨간 원 없음 |
| `s2_charge_crack_path.jpg` | 돌진 전조 - 몸 폭 연보라 띠 + 가장자리 균열선(이 장은 균열선 색 바꾸기 전) |
| `s3_quake_air_shards.jpg` · `s3_quake_ground_slabs.jpg` | 지진파 공중 파동(수정 조각 링) · 땅 파동(돌판 링 + 바닥 균열)(균열선 색 바꾸기 전) |
| `s4_banana_mesh.jpg` | 임시 자수정 바나나 메시(노랑 Neon + 보라 빛 · 보스 곁에 세워 둔 정지 진열) |
| `s5_leap_crack_circle.jpg` · `s5_leap_airborne.jpg` | 도약 착지 균열 원(보라 균열선 · 연보라 채움) · 공중의 보스 |
| `s6_*.txt` | BossSim 최종 · 조정 전 · 탐색 표 · 하네스 출력 |

## 6. 미검증 항목 · 결정 필요

1. **성능 측정 안 함**: 4인 PC fps · 폰 설정 fps · 서버 Heartbeat는 이번에 재지 않았다(메시 · 관절 수는 V2와 같고 새 연출은 풀 · 링당 ≤ 24라 영향은 작다고 보지만 수치 없음).
2. **바나나 비행 장면 미촬영**: 110 stud/s라 연속 캡처(0.3초 간격)에 안 잡혔다 - 메시는 정지 진열로만 확인. 손에 든 바나나 발광(0.45초) · 꼬리 트레일 · 3갈래(광폭)는 눈으로 확인 안 함.
3. **도약 비행 매끄러움**: 서버가 PivotTo로 포물선을 옮긴다(복제 보간 없음) - 끊겨 보일 수 있다(사용자 검수).
4. **첫 보스 도움 실전 미확인**: 전멸 → 기록 + 1 → 배율 적용 경로는 하네스(배율 함수 · 저장 이관 v75)만 확인. Studio에서 실제 전멸 · 재접속 저장은 안 해 봤다.
5. **파티(2 ~ 4인)**: 바나나 · 도약은 조준 대상 한 명 기준 - 다인 Play 미확인(MCP 다중 클라 불가).
6. **변신 뒤 직립 캡처 없음**(키는 FK · Studio 수치로 확인).
7. **결정 필요 - 아는 보스 난이도**: 처음 ≤ 50%를 맞추니 아는 보스 전멸 21 ~ 27% · 받은 피해 70 ~ 72%로 §1-1 목표(30 ~ 50% · 80 ~ 150%) 하한 아래다. 근접은 아는 보스가 처음보다 약 20%p 낮아 두 목표를 동시에 못 맞춘다. 2회차 체력 × 1.3(`repeatHpMultiplier`)이 실전에는 이미 있어 아는 보스가 조금 더 어려워진다(모형에는 없음).
8. **결정 필요 - 근접 원형 구역 파랑 원**: "근접 바닥 표시 전부 제거"로 읽어 파랑 원(평타 안 맞는 안쪽)까지 껐다. 되돌리려면 `v3.section_guardian.hideFloor.innerRing = false`.
9. **도약 회피 여유 0.08초**: 지시 수치(고정 0.3 · 비행 0.8 · 반경 몸 + 12) 그대로면 걸어서 겨우 피한다(대시면 여유). 빠듯하면 `lockSeconds` 0.4로.
10. **K 대신 scale**: 지시는 "K를 30 stud로"였지만 K와 scale은 둘 다 균일 배율이라 결과가 같고, K를 바꾸면 KIT 재굽기 · 재업로드가 필요해 `rig.scale`로 맞췄다.
11. 바나나 메시 = 임시(Blender 6각 단면 각진 면 · 130삼각형). Meshy 메시가 오면 `BossFrameworkData.meshSlots.GuardianBanana` 값만 바꾼다.

## 7. Studio에서 직접 확인하는 순서(사용자 검수)

준비: Edit 모드에서 `game:GetService("ReplicatedStorage"):SetAttribute("TestSkipMainMenuUntil", os.time() + 3600)` → Play → 출력 `[ArtAssetLoader] 메시 캐시 …`(약 50초)까지 기다린다.

1. `/gg boss frame on` → `/gg boss pattern section_guardian heavy` → `/gg god on`(명령 사이 몇 초 띄우기). 보스 쪽으로 약 20 stud 걸어가면 반응 - 바닥 원 없이 두 주먹이 보라로 빛나며 일어서는지.
2. 같은 방법으로 `innerSmash` · `swipe`(바닥 표시 없음 · 손 발광) · `charge`(몸 폭 균열선) · `shockwave`(돌판 링 · 수정 조각 링 · 바닥 균열).
3. `/gg boss pattern off` → 보스에서 30 stud 넘게 떨어져 1.5초 → 바나나(손에 든 바나나가 빛난 뒤 던짐) · 옆으로 계속 움직여 두 번 피하면 도약(착지 균열 원이 따라오다 멈춤 → 뛰어오름 → 착지 넉백).
4. 광폭 3갈래: 실전 중 `/gg bossdmg 0.55` 뒤 멀리 떨어져 바나나.
5. 크기: 변신 뒤(`/gg bossdmg 0.55`) 직립 키 약 30 · 카메라 거리.
6. 비교: `/gg boss frame off` → 다음 스폰부터 옛 수호자(빨간 바닥 전조 그대로).

검수 통과 뒤 실전 교체: `BossFrameworkData.live.section_guardian = "v2"`(별도 지시).

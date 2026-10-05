# BOSS-FRAMEWORK 보고서 (단계별로 채움)

원본 지시 = BOSS-FRAMEWORK(10-05) · 바이블 = `BIBLE-v1.md` · 덤프 = `BOSS-DUMP.md`.
바꾸지 않는 것: BossData 스킬 수치 · 페이즈 · 기믹 · 서버 이동 · BossSim 목표(바이블 §1-1).

## 0. 측정 기준표 (변경 전 · master `c6d38fa3`)

### 0-1. 메시(Blender 원본 `roblox/art/bosses/<보스>.blend` · 도구 `roblox/tools/blender/boss_measure.py`)

| 보스 | 보이는 MeshPart | 외곽선 껍데기 | Neon | 삼각형(외곽선 제외) | 외곽선 삼각형 | 가장 큰 부위(장식 포함) | 예산 초과 |
|---|---|---|---|---|---|---|---|
| 구간 수호자 | 69 | 10 | 9 | 3,026 | 1,486 | 오른 어깨 갑옷 571 | 없음 |
| 서리 거인 | 61 | 10 | 2 | 2,892 | 1,676 | 몸통 612 | 없음 |
| 심해 군주 | 69 | 10 | 7 | 3,662 | 1,698 | 몸통 1,344 | 없음 |
| 수정 여왕 | 62 | 10 | 7 | 2,280 | 836 | 머리 316 | 없음 |
| 전갈 여왕 | 74 | 0 | 6 | 3,414 | 0 | 몸통 296 | 없음 |
| 폭풍 군주 | 61 | 10 | 9 | 2,544 | 814 | 지팡이 보주 350 | 없음 |

- 예산(바이블 §1-4): 삼각형 ≤ 30,000 · 부위 ≤ 5,000 · 외곽선 ≤ 8,000 · MeshPart ≤ 90 · 외곽선 ≤ 12 · Neon ≤ 10 → 지금은 삼각형 예산의 8 ~ 12%만 쓴다(새 몸은 여유가 크다).
- 부위별 전체 = `roblox/art/bosses/_measure/boss_tris.md` · `.json`.

### 0-2. 실행 비용 (Studio Play · 스테이지 15 · 4인 가정 = 내 캐릭터 복제 3(`FakeParty`) · 보스별 무거운 패턴 되풀이 · 측정 10초)

| 보스(되풀이 패턴) | PC fps · p95 ms | 폰 설정 강제 fps · p95 ms | 보스 모션 μs/프레임(PC · 폰) | 서버 Heartbeat 평균 · p95 ms(4인) |
|---|---|---|---|---|
| 구간 수호자(강공격) | 60.0 · 18.1 | 59.3 · 18.2 | 140 · 121 | 1.34 · 1.56 |
| 서리 거인(포효) | 60.0 · 19.6 | 57.2 · 19.6 | 132 · 134 | 0.84 · 1.00 |
| 심해 군주(소용돌이) | 60.0 · 18.2 | 60.0 · 18.2 | 135 · 140 | 1.01 · 1.24 |
| 수정 여왕(오르골) | 60.0 · 18.2 | 60.0 · 18.1 | 167 · 137 | 1.02 · 1.24 |
| 전갈 여왕(잠행 찌르기) | 60.0 · 18.1 | 60.0 · 18.0 | 100 · 173 | 0.90 · 1.10 |
| 폭풍 군주(낙뢰) | 60.0 · 17.9 | 60.0 · 18.1 | 168 · 122 | 0.74 · 0.90 |

- 측정기 = `client/A2M1Probe`(`PerfProbeStart` · `FakeParty` · `A2M1ForcePhone` + `GraphicsMode = lite`) · 서버 = `/gg perf boss 4`(`server/PerfProbe.runBoss` - 나 + 더미 3 · 12초).
- 전갈 · 폭풍은 첫 측정 때 Studio 창이 초점을 잃어 15fps로 묶였다(GPU 시간 0) → 창을 앞으로 가져와 다시 잰 값. 모션 μs는 Play마다 ±30% 흔들린다(같은 보스 128 ~ 229) - 비교는 같은 Play 안 값으로.
- **폰 기기 fps는 Studio에서 못 잰다**(PC 성능). 폰 값 = 폰 설정(세밀 LOD · lite) 강제 + PC 측정 - 대리 지표.
- 합격선(바이블 §1-4): PC 60fps · 폰 저사양 ≥ 30fps · 보스 모션 ≤ 지금 × 1.5(수호자 기준 140 → 210μs) · 서버 Heartbeat 변화 없음.

## 1. 무엇이 생겼나 (단계별)

| 단계 | 내용 | 파일 |
|---|---|---|
| 1 리그 체계 | 뼈대 생성기(이족 · 네 발 · 뱀 하체 · 날개 · 사슬(꼬리 · 코 · 망토) · 여섯 다리) · 새 몸 = 리그 키 `<보스>_v2`(모델 Attribute `BossRigKey` - `BossRig` = 보스 id 그대로라 카메라 · 데이터 조회 불변) · 검사(관절 ≤ 60 · 판정 사본 Body · Head(+1) · 부피 옛 몸 ±20% · 이름 · 사슬) | `shared/BossSkeleton.lua` · `shared/data/BossRigV2Data.lua` · `shared/BossFramework.lua` · `BossRigSpec`(등록 · `rigOf`) |
| 2 동작 체계 | 보스별 동작 세트(변신 전 / 후) · 보행 주기 knuckle · quad · serpent · hover · hexapod · biped(이동 속도 연동 - 위상 = 이동 거리 ÷ 보폭) · 세트 기본 자세 · 루트 높이 오프셋 · 접지 부위 · 빠짐 검사(스킬표 전부 · 필수 동작 · 변신 · 번쩍 · 소리 · 접촉 = 판정 시각 · 타격 정지 0.05 ~ 0.08) | `shared/data/BossClipSetData.lua` · `shared/BossClipSet.lua` · `shared/BossMotion.lua`(새 몸 분기) |
| 3 2차 움직임 | 마디별 감쇠 스프링(첫 마디 = 몸 가속 · 방향 전환 · 다음 마디 = 앞 마디를 늦게) · 종류별 값(tail · wing · cape · trunk · fur · crystal · cloth) · 폰 · lite = 절반 갱신 | `client/BossSpring.lua` · `BossFrameworkData.springs` |
| 4 50% 변신 | 겉모습 격노 순간 → 진행 중 스킬 · 환경이 끝나면(최대 3초) 변신 동작 1회 → `switchAt`에 세트 교체 · 변신 중 새 스킬 · 환경이 오면 변신 층을 거둠 · 전멸 리셋 = 되돌림 · 늦게 온 사람 = 바로 변신 뒤 · 서버 잡기 FK도 체력으로 같은 세트 | `BossAnimator` · `BossMotion` · `BossAirGrab` |
| 5 번쩍임 | 스킬마다 때리는 부위 표 → 판정 시각 직전 0.15초 흰 테(Highlight 흰 외곽 + 옅은 흰 채움 · 위험색 없음) · 새 몸은 옛 무기 번쩍 대신 | `BossClipSetData.flash` · `BossAnimator.applyRim` |
| 6 소리 자리 | 6보스 × 포효 · 걷기 · 변신 · 스킬별 전조 시작 / 접촉 - 전부 빈 자리(채우면 재생) | `shared/data/BossSoundData.lua` |
| 7 범용 KIT | Blender 스크립트 1개(아래 사용법) · 업로드 = 기존 `upload.py`(추가만) · 메타 → `MeshMeta/<키>.lua`(텍스처 부위 포함) · `ArtMeshKit`가 아틀라스 TextureID를 입힘 | `tools/blender/boss_kit.py` · `meta_to_luau.py` · `shared/ArtMeshKit.lua` |
| 8 수호자 시험 | 지금 메시 59조각을 한 덩어리로 합친 가짜 원본 → KIT 재조립(부위 30) → 업로드 → 실전 스폰에 끼움 · 너클 대기 · 걷기 · 50% 일어서기(가슴 치기 2 · 등 수정 폭발) · 강공격(뒷다리로 일어서 두 주먹 내려찍기) | `BossClipSetData.section_guardian_v2` · `art/bosses/section_guardian_v2.*` |

- **실전은 아직 옛 몸**: `BossFrameworkData.live = {}`. 새 몸은 Studio에서 `/gg boss frame on`(또는 workspace `BossFrameworkTrial = true`)일 때만 뜬다(라이브 서버는 이 속성을 무시).

## 2. 체계 사용법(다음 보스를 만들 때)

1. **뼈대**: `BossRigV2Data`에 `<보스>_v2`를 생성기로 정의(`BossSkeleton.biped/quadruped/serpent/wings/chain/hexapod` + `add`) · `status = "draft"` → 하네스 `boss_framework_test`가 관절 · 판정 사본 · 부피 · 접지를 검사.
2. **그림 → 3D**(Meshy · 설계 담당) → `python rig_dump.py <보스>_v2`(리그 JSON) → `bash bl.sh boss_kit.py --rig rigs/<보스>_v2.rig.json --glb 몸.glb [--part 날개.glb=WingF_L1 …] [--yaw 180] --render <폴더>`.
   - 결과 = `art/bosses/<보스>_v2.fbx` · `.meta.json` · `.blend` · `_atlas1.png`(원본 텍스처면 1024로 줄인 원본 ≤ 3장) · 콘솔에 예산 줄(초과 항목 이름).
3. 업로드: `python roblox/tools/opencloud/upload.py bosses/<보스>_v2.fbx bosses/<보스>_v2_atlas1.png` → Studio Edit에서 `InsertService:LoadAsset(<Decal id>)`의 Decal.Texture 숫자 → `upload.py --images <json>` → `python meta_to_luau.py <보스>_v2`.
4. **동작 세트**: `BossClipSetData`에 `forms.before/after`(gait · stance · skills 전부 · motions) · `transform` · `flash`(스킬 전부) · 전용 `clips` → 하네스 빠짐 검사 · 튐 · 접촉 = 판정 · 비용.
5. Studio: `/gg boss frame on` → `/gg boss pattern <보스> <스킬>` 또는 `/gg boss anim <보스> all`(새 몸 전시는 `after:<동작>` · `transform`도 됨) → `/gg boss frame`(검사 출력).
6. 검수 통과 뒤에만 `BossFrameworkData.live[<보스>] = "v2"`.

검사 명령(오프라인 · Studio 없이):
```
LUAU=<luau.exe> PRELUDE=motion_prelude.luau ECON_RES=res_frame.txt python build_run.py boss_framework_test.luau   # 리그 · 빠짐 · 접지 · 튐 · 번쩍 · 변신 · 비용
LUAU=<luau.exe> PRELUDE=motion_prelude.luau ECON_RES=bm.txt python build_run.py boss_motion_test.luau            # 옛 몸 6종 회귀(전후 diff 0)
LUAU=<luau.exe> PRELUDE=motion_prelude.luau ECON_RES=t.txt python build_run.py boss_timing_dump.luau             # 서버 시간표(ECON_SRC=변경 전 사본과 diff)
```

## 3. 수호자 시험 결과 (크레딧 0)

### 3-1. KIT 재조립(가짜 원본 = 지금 메시 59조각 · 3,026 삼각형을 한 덩어리 GLB로)

| 항목 | 값 | 예산 |
|---|---|---|
| 부위(리그 v2 관절 = 부위) | 30(빈 부위 1 = 입 - 지금 그림에 따로 된 입이 없음 · 작은 숨김 상자로 끼움) | 관절 ≤ 60 |
| 보이는 MeshPart | 50(부위 30 + Neon 조각 8 + 외곽선 12) | ≤ 90 |
| 삼각형 / 외곽선 | 3,795 / 2,424 | ≤ 30,000 / ≤ 8,000 |
| Neon | 10(조각 8 + 리그 Neon 부위 눈 · 룬) | ≤ 10 |
| 텍스처 | 팔레트 아틀라스 1024 × 1장(색 9칸) | ≤ 3장 |
| 관절 겹침 복사 면 · 막은 면 | 432 · 86 | - |
| 실행 시간 | 약 7초(Blender 백그라운드) | - |
| 업로드(추가만) | 모델 `bosses/section_guardian_v2` 88197704447095 · 아틀라스 Decal 110428015021521(이미지 107503596647838) - 둘 다 Approved | 삭제 0 |

- 렌더: `framework/kit_render/section_guardian_v2_game_{34,front,side}.png`.
- Studio 실전 스폰: 부위 30/30 교체 · 관절 30 · 텍스처 27부위 · 판정 사본 `Body_Query` · `Head_Query`(부피 옛 몸 × 1.00 · BodyRadius 같음).

### 3-2. 전/후 하네스(판정 · 전조 · 피해 시각 동일)

| 검사 | 결과 |
|---|---|
| 서버 시간표(6보스 65스킬 전조 · 모양 · 피해 · 쿨 · 조건 · 묶음 길이 · 회피 부등식) 변경 전 src ↔ 지금 | diff 0 (`boss_timing_dump.luau`) |
| 옛 몸 6종 모션(대기 · 걷기 · 달리기 · 잡기 · 평타 · 스킬 전부 · 등장 · 피격 · 기절 · 사망) | diff 0 · 튐 0 (`boss_motion_test.luau`) |
| 옛 리그 6종 관절 표 | diff 0 (덤프 대조) |
| 수호자 v2: 빠짐 검사 66줄 · 접촉 − 판정 = 0.000(스킬 전부 · 전/후) · 튐 0 · 번쩍 창(판정 −0.20 꺼짐 · −0.05 켜짐 · +0.01 꺼짐) · 변신 교체 · 너클 자세 손/발 높이 차 0.11 | 24/24 O (`boss_framework_test.luau`) |
| 서버 코드 변경 | 스폰(리그 고르기) · 잡기 FK(리그 · 세트 고르기) · DevTools 명령만 - BossPatterns · BossData · 스케줄러 0줄 |

### 3-3. 성능(같은 조건 - 4인 가정 · 스테이지 15 · 강공격 되풀이)

| | PC fps · p95 | 폰 설정 fps · p95 | 보스 모션 μs(PC · 폰) | 서버 Heartbeat 평균 · p95(4인) |
|---|---|---|---|---|
| 옛 몸(기준) | 60.0 · 18.1 | 59.3 · 18.2 | 140 · 121 | 1.34 · 1.56(첫 측정 - 같은 Play 다른 보스 0.74 ~ 1.02) |
| 새 몸 KIT(시험) | 60.0 · 18.1 | 59.8 · 18.8 | 144 · 153 | 0.71 · 0.90(같은 Play 다른 보스 0.56 ~ 0.65) |

- 모션 비용 × 1.03(PC) · × 1.26(폰 설정) - 합격선 × 1.5 안. 오프라인(같은 기계 · luau CLI) 옛 192μs → 새 218μs(× 1.14).
- 폰 기기 실측은 여전히 없음(Studio = PC) - 폰 값은 대리 지표.

### 3-4. 캡처 · 영상(`docs/design/boss-bible/framework/`)

| 파일 | 내용 |
|---|---|
| `guardian_v2_fight.gif` · `guardian_v2_fight_sheet.jpg` | **실전 경로**: 바닥 전조(원 r14) 동안 뒷다리로 일어서 두 주먹 → 판정 순간 내려찍기 + 주먹 흰 테 → 체력 45% → 변신(가슴 치기 · 수정 폭발) → 지반 붕괴 전조 · 직립 세트 |
| `guardian_v2_anim_sheet.jpg` | 전시 리그 17동작 한 장(등장 · 너클 대기 · 걷기 · 달리기 · 강공격 · 돌진 · 변신 · 직립 대기 · 걷기 · 달리기 · 강공격 · 돌진 · 강화 평타 · 잡기 · 기절 · 피격 · 처치) |
| `guardian_v2_anim_{knuckle,heavy_before,transform,upright,heavy_after,intro}.gif` | 동작별 영상(6.7fps) |

## 4. 막힌 점 · 알려진 한계 · 결정 필요

1. **검수 필요(설계 담당)**: 실전 교체는 아직 안 함(`live` 비어 있음). 너클 자세 각(허리 −75° · 어깨 75°)과 변신 동작 길이(2.7초)는 체감 판단이 필요하다.
2. **빌린 동작**: 수호자 v2의 전용 동작은 강공격 · 변신 2개뿐이고 나머지 스킬(진동파 · 낙석 · 돌진 · 십자 · 쌍권 · 광구 · 대지 가르기 · 평타 · 잡기)은 옛 직립 동작을 빌린다(빠짐 검사 표에 "빌림"으로 나옴). 너클 자세에서 빌린 동작은 잠깐 일어섰다 돌아간다 - 보스별 전용 동작 제작이 다음 일.
3. **변신이 잘리는 경우**: 변신 중(2.7초) 새 스킬 · 환경이 오면 변신 층을 거둔다(가독성 우선). 패턴 단독 되풀이(2초 간격)에서는 실제로 잘렸다. 실전(전역 쿨 6초 · 환경 = 50% 뒤 3초)에서는 거의 안 잘리지만 스킬 진행 중 50%를 넘기면 최대 3초 기다린 뒤라 환경과 겹칠 수 있다.
4. **입 부위 비어 있음**: 지금 그림의 입이 따로 된 조각이 아니라 턱 · 머리에 섞여 있어 `Jaw` 표정이 안 움직인다. Meshy 원본에서는 입 · 턱을 따로 만들면 된다.
5. **KIT 자르기 = 리그 상자 기준**: 그림과 리그 상자가 어긋나면(지금 그림의 눈 · 입이 옛 리그 상자보다 0.34 · 0.7 낮았음) 엉뚱한 부위로 간다 → 리그 v2를 만들 때 그림 정면 · 옆 사진 위에 상자를 맞춰 정의해야 한다(이번엔 v2 리그의 눈 · 입 자리를 그림에 맞춤).
6. **자른 면 막기**: `holes_fill`이 허리 쪽에 작은 어두운 삼각형을 몇 개 만든다(렌더에서 보임 · 게임 거리에서는 거의 안 보임). Meshy 원본(닫힌 메시)에서 다시 확인 필요.
7. **텍스처 + Color**: TextureID를 입힌 부위는 Color를 흰색으로 둔다 → 옛 "분노 색조"는 Neon · Glass 조각에만 남는다(텍스처 부위는 색조 없음).
8. **측정 환경**: Studio 창이 초점을 잃으면 15fps로 묶여 fps 측정이 무효가 된다 - 측정 때 창을 앞으로 가져왔다(그동안 사용자 화면이 Studio로 바뀜).
9. **소리**: 자리만 있고 음원 0(규칙대로 비워 둠).
10. **나머지 4보스 뼈대**: `draft`(매머드 37 · 나가 32 · 나비 여왕 39 · 폭풍 기사 34관절) - 생성기 · 예산 검사만 통과, 동작 세트 · 메시 없음.

## 5. Studio에서 직접 확인하는 순서(사용자 검수 - 10-05 지시: 보기 좋은지 판단은 사용자 · Claude Code는 자동 검사 + 정지 캡처만)

준비(Edit 모드 · 한 번): 명령 모음 `/gg`는 개발 계정 채팅으로 친다. Play 시작 뒤 메시 캐시 로딩(출력 창 `[ArtAssetLoader] 메시 캐시 …/…`, 약 55초)을 기다린다.

1. `/gg boss frame on` — 새 몸 시험 스위치(다음 보스 스폰부터 수호자 = v2 · 이 Play만).
2. `/gg boss frame` — 출력 창 `[BossFrame]` 줄: 리그 검사 O · 빠짐 검사 66줄(전용 / 빌림 구분).
3. **전시(판정 없음 · 내 앞)**: `/gg boss anim section_guardian all` — 등장 → 너클 대기 · 걷기 · 달리기 → 강공격 · 돌진 → 변신 → 직립 대기 · 걷기 · 달리기 → 강공격 · 돌진 → 평타 · 잡기 · 기절 · 피격 · 처치.
   - 한 동작만: `/gg boss anim section_guardian <동작> <반복>`(예 `heavy 3` · `transform 3` · `after:walk 2` · `walk 2`). 끄기 `/gg boss anim off`.
4. **실전(전조 · 흰 테 · 변신 · 지반 붕괴)**: `/gg boss pattern section_guardian heavy` → 보스 앞 약 20 stud까지 걸어감(보스는 약 25 안에서 반응) → 강공격 전조 동안 일어서 두 주먹 → 판정 순간 주먹 흰 테 확인 → `/gg bossdmg 0.55`(체력 45%) → 진행 중 스킬이 끝나면 변신 → 3초 뒤 지반 붕괴 · 직립 강공격. 끄기 `/gg boss pattern off`.
   - 다른 스킬: `/gg boss pattern section_guardian <스킬 id>`(shockwave · meteor · charge · cross · swipe · grab · mirror · innerSmash · fists · orbs · earthSplit) - 빌린 동작이 너클 자세에서 어떻게 보이는지.
5. 옛 몸과 비교: `/gg boss frame off` → 다음 스폰부터 옛 수호자.
6. (선택) 성능 숫자: 클라 콘솔에서 `game.Players.LocalPlayer:SetAttribute("FakeParty", 3)` → `SetAttribute("PerfProbeStart", "이름|10")` → 출력 `[ArenaPerf]` 줄(fps · p95 · bossAnimUs). **Studio 창이 앞에 있어야 fps가 맞다**(뒤에 있으면 15fps로 묶임).

검수 정지 캡처(자동 생성 - 보는 용도만): `framework/kit_render/section_guardian_v2_game_{front,34,side}.png`(KIT 결과 정면 · 3/4 · 옆) · `framework/guardian_v2_anim_sheet.jpg`(17동작 핵심 자세) · `framework/guardian_v2_fight_sheet.jpg`(실전 9장). 이전에 만든 GIF는 참고로 남겨 둔다(이후 영상 녹화 · 판독은 하지 않음).

## 6. 다음(이번 범위 밖 · 결정 필요)

- 바이블 §5 **크기 × 1.5 + 판정 · 근접 반경 · 추격 거리 = 몸 가장자리 기준 + BossSim 재실행**은 서버 판정 · 밸런스를 바꾸는 일이라 이번 기반 작업에 넣지 않았다(지금 판정 · 시간표 전후 diff 0 유지). 새 몸 리그의 크기는 데이터(`BossData` sizeScale × bodyScale)로 따로 정해져 있어 기반은 그대로 쓸 수 있다.

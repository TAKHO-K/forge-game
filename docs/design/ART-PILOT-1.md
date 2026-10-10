> 상태: 2026-10-11 · ART-PILOT-1 진행 중 · 게임 데이터 · 코드 · 본 place 변경 0 · 입력 = `claude-design-handoff/50_art-pilot/v1/`

# ART-PILOT-1 — 3D 파이프라인 시범 2종 (대장장이 NPC · rock_boar)

## 크레딧 장부 (상한 80)

| 시각 | 무엇 | 크레딧 | 누계 | 남은 예상(상한 기준) |
|---|---|---|---|---|
| 10-11 | C. 기본 몸 실측(Studio 메모리 리그 · 붙이지 않고 지움) | 0 | 0 | 80 |
| 10-11 | 대장장이 멀티뷰 → 3D(웹 앱 · Meshy 7.1 높은 디테일 · 2K · A포즈 · 이미지 향상 · 비공개 라이선스) | 35 | 35 | 45 |
| 10-11 | rock_boar 멀티뷰 → 3D(같은 설정 · 포즈 끔) | 35 | 70 | 10 |
| 10-11 | 리메시(대장장이 10K · rock_boar 3K) · rock_boar 사족 리깅 + 걷기 · 대장장이 이족 리깅 + 걷기 · 달리기 · 무거운 망치 휘두르기(웹 앱) | 0 | 70 | 10 |
| 10-11 | Open Cloud 업로드 5개(Model 3 · Decal 2 · 게임 소유자 = 같은 사용자 소유) | 0 | 70 | 10 |

원장 = `claude-design-handoff/50_art-pilot/v1/meshy-ledger.md`(설계 담당이 웹 앱에서 직접 작업 · 시작 잔액 202 → 132). **웹 앱 단가 = 생성 35뿐**(리메시 · 리깅 · 프리셋 애니 0). API는 쓰지 않음(이 PC에 Node.js 없음).

## 진행 기록

| 항목 | 상태 | 결과 · 파일 |
|---|---|---|
| A1 Avatar Setup | **건너뜀**(사용자 결정 10-11) | 통메시라 눈 2 · 입 부품 3 · 수염 분리 조건 불충족 → 실패 가능성 높음 |
| A2 파일 검사 | 끝 | Mixamo 뼈 42(이름 없는 Meshy 보조 뼈 `Bone_018/019/029/030` 포함) · 10,253 삼각형 · 망치 휘두르기 45프레임 24fps(1.9초) · 걷기 26프레임 · **FBX에 쓸모없는 Icosphere(80 삼각형 · 2 stud) 1개 섞임 → 넣은 뒤 지워야 함** · 텍스처 색 2K + 노멀 2K + 금속/거칠기 4K |
| B1 파일 검사 | 끝 | 사족 뼈 27(Hips · tail 4 · 다리 4 × 4 · chest · head · 귀 2) · 3,111 삼각형 · 걷기 31프레임 30fps · 아마추어 배율 0.01(cm) |
| B2 부위 자르기 | 끝 | `roblox/tools/blender/art_pilot_cut.py`(실행 1.1초) → `roblox/art/pilot/art_pilot_1/rock_boar_b2.{fbx,blend,meta.json}` · 12부위 1,516 삼각형(예산 1,500) |
| 업로드 | 끝 | `roblox/tools/opencloud/pilot_upload.py`(결과 = `roblox/art/pilot/art_pilot_1/pilot-asset-ids.json` · 게임 `asset-ids.json` · `ArtAssetIds.lua` 안 건드림) · 5개 모두 Approved |
| 애니 변환 | 끝 | `roblox/tools/blender/art_pilot_anim.py` → `*.anim.json`(프레임별 뼈 월드 변화량 - Studio에서 KeyframeSequence 임시 등록으로 재생 예정) |
| B1-라이트 준비 | 끝 | 같은 리깅 멧돼지(boar_b1 모델 재사용) + 색 1장 1024(`b1_lite/rock_boar_b1lite_albedo_1024.png` · 노멀 · 금속 · 거칠기 없음). 공정 비교용으로 B1 원본 노멀 2K · 금속 4K · 거칠기 4K도 업로드(B1 = 4장) |
| Studio 넣기 · 재생 · 성능 | **대기** | PROG-2B-1(Studio 사용 7단계) 끝난 뒤 · `Workspace._ArtPilot` 하나 · 끝나면 제거 · 그동안 저장/퍼블리시 금지 · 스크립트 `roblox/tools/art_pilot/01_load.luau` |

### B2 부위 자르기 결과 (rock_boar · Meshy 3,111 → 1,516)

| 부위 | 삼각형(원본 → 감량) | 관절(원점) | 지금 리그 관절 | 메모 |
|---|---|---|---|---|
| Body | 722 → 348 | (0, −0.1, 0) | (0, −0.1, 0) | 배 밑면 포함 |
| Head | 760 → 366 | (0, 0.02, −0.82) | 몸 앞 (0, −0.05, −1.5) | 코 · 귀 포함(코 분홍 = 단색이라 사라짐) |
| Eyes | 21 → 21 | (0, 0.02, −2.14) | | |
| Tusk_L · R | 30 → 13 · 22 → 22 | (±0.32, −0.23, −2.13) | | |
| Moss | 147 → 70 | 가운데 | | |
| Shell(새) | 299 → 144 | 가운데 | 없음 | 등 바위 혹 |
| Tail(새) | 238 → 114 | (0, 0.07, 1.76) | 없음 | |
| Leg_FL · FR · BL · BR | 211 ~ 226 → 101 ~ 108 | x −0.23 / 0.25 / −0.51 / 0.34 · z −0.51 / −0.51 / 1.43 / 1.43 | x ±0.6 · z ±1.0 | **Meshy 다리 좌우 비대칭**(뒤 왼쪽 x −0.51 ↔ 오른쪽 0.34) |

- 배율: Meshy 키 1.07 m → 2.65 stud(× 2.48) · 결과 길이 4.70 · 폭 1.96(지금 리그 약 4.1 × 1.8 · 경계 비 1.15 - 검사 0.8 ~ 1.25 안).
- 부위 정하기 = 위치(목 · 꼬리 = 몸 폭 단면 · 다리 = 높이 30% 아래 · 등 = 몸 위 80% 분위) + 텍스처 색(이끼 = 초록 · 엄니 = 크림 · 눈 = 검정). 처음 판에서 ① 배 밑면이 다리로 들어감 → 아래 향한 면은 몸통 ② 회색 볼이 엄니로 들어감 → 빨강 > 파랑만 엄니. 두 번 고쳐 통과(부위 색 렌더로 확인).
- 잃는 것: 단색 부위라 코 분홍 · 발굽 어두운 색 · 이끼 얼룩 모양이 사라짐(같은 부위 안 무늬 = 텍스처 필요) · 지금 리그 파트 ≤ 10 규칙보다 2개 많음(Shell · Tail) · 관절 자리가 지금 표와 다름(머리 목 −0.82 ↔ −1.5 · 다리 간격) → 쓰려면 `MonsterRigSpec` 값 변경 필요(이번엔 안 바꿈).

## C. 로블록스 기본 R15 몸 실측 (크레딧 0)

측정: Studio Edit에서 `Players:CreateHumanoidModelFromDescription(desc, R15)`로 리그를 만들어 읽고 바로 `Destroy`(workspace에 붙이지 않음 → place 변경 0). 몸 파트 id = 0(기본 블록 몸 · 메시 7430071xxx).

**표 1 — 게임 기준 몸**(`ArtStyleV1Data.standardBody.scales` = 높이 · 폭 · 깊이 · 머리 1 · ProportionScale 0 · BodyTypeScale 0. 지금 `enabled = false`라 실제 플레이어는 자기 아바타 몸이지만 방어구 맞춤 기준은 이 값)

| 부위 | 폭 X | 높이 Y | 깊이 Z | 중심(뿌리 기준 y) |
|---|---|---|---|---|
| 머리 Head | 1.196 | 1.203 | 1.198 | 1.586 |
| 윗몸통 UpperTorso | 2.000 | 1.600 | 1.000 | 0.200 |
| 아랫몸통 LowerTorso | 2.000 | 0.400 | 1.000 | −0.800 |
| 위팔 Upper Arm(좌우 같음) | 1.000 | 1.169 | 1.000 | 0.369 (x ±1.5) |
| 아래팔 Lower Arm | 1.000 | 1.052 | 1.000 | −0.224 |
| 손 Hand | 1.000 | 0.300 | 1.000 | −0.850 |
| 넓적다리 Upper Leg | 1.000 | 1.217 | 1.000 | −1.421 (x ±0.5) |
| 정강이 Lower Leg | 1.000 | 1.193 | 1.000 | −2.201 |
| 발 Foot | 1.000 | 0.300 | 1.000 | −2.850 |
| 뿌리 HumanoidRootPart | 2 | 2 | 1 | 0 · HipHeight 2 |
| 전체 경계 | 4.000 | 5.188 | 1.198 | |

윗몸통 붙는 점(UpperTorso 기준): 목 (0, 0.8, 0) · 어깨 (±1.0, 0.563, 0) · 칼라 (±1.0, 0.8, 0) · 허리 (0, −0.8, 0) · 몸 앞/뒤 (0, −0.2, ∓0.5). 아랫몸통: 허리 (0, 0.2, 0) · 엉덩이 (±0.5, −0.2, 0) · 허리 앞/뒤/가운데 (0, −0.2, ∓0.5 / 0).

**표 2 — 참고: 빈 `HumanoidDescription` 기본값**(BodyTypeScale 0.3 · ProportionScale 1 · 표준 설정을 안 켰을 때 새 아바타가 받는 값)

| 부위 | 폭 X | 높이 Y | 깊이 Z |
|---|---|---|---|
| 머리 | 1.159 | 1.182 | 1.161 |
| 윗몸통 | 1.943 | 1.698 | 1.004 |
| 아랫몸통 | 1.991 | 0.401 | 1.004 |
| 위팔 / 아래팔 / 손 | 1.001 / 1.001 / 0.984 | 1.242 / 1.118 / 0.316 | 1.002 / 1.002 / 1.028 |
| 넓적다리 / 정강이 / 발 | 0.993 / 0.993 / 1.009 | 1.363 / 1.301 / 0.312 | 0.973 / 0.973 / 1.001 |
| 어깨 붙는 점 | ±0.972, 0.598 | HipHeight 2.192 | 전체 4.001 × 5.183 × 1.161 |

→ Claude Design 방어구 그림의 가정값 **UpperTorso 2 × 1.6 × 1 · LowerTorso 2 × 0.4 × 1은 표 1과 정확히 같음 = 다시 찍을 필요 없음.** 표 2(아바타 기본)와는 윗몸통 높이 +6% · 폭 −3% 차이(맞춤 껍데기가 몸 맞춤 Layered 방식이면 흡수됨).

## 성능 비교 계획 (Studio 허락 뒤)

4종 = **B1**(스킨 메시 + 텍스처 4장) · **B1-라이트**(같은 스킨 메시 + 색 1장 1024) · **B2**(부위 12 · 단색 · Motor6D) · **지금 몬스터**(`monsters/rock_boar` 10부위 · 단색). 같은 조건 = 30 · 120마리 · 렌더 품질 1 · 같은 자리 · 같은 카메라 · Studio 창 초점(초점 없으면 15 ~ 26fps로 떨어짐 - 메모리 opencloud 함정).
- 움직임: B1 · B1-라이트 = Animator + 걷기 KeyframeSequence 임시 등록 · B2 · 지금 = Motor6D.Transform 사인 걷기(지금 게임과 같은 방식 - `MonsterRigAnimator`).
- 잴 것: fps(RenderStepped 6초 평균 · p95 프레임) · `Stats:GetMemoryUsageMbForTag`(GraphicsTexture · GraphicsMeshParts · Animation) · 전체 메모리.
- 한계: 실제 폰이 아니라 PC Studio 품질 1 대용값. 비율(4종 사이 차이)로 판단.
- 확인할 것: **Roblox 텍스처 상한**. 영어 문서는 1024 × 1024 상한, 번역 문서는 4096이라 서로 다름 → 업로드한 2K · 4K가 실제 몇 픽셀로 쓰이는지 GraphicsTexture 메모리 차이로 확인([texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications)). 1024 상한이면 B1 ↔ B1-라이트 차이 = 장 수(4 ↔ 1)뿐.

## 실서비스 애니 업로드 경로 (조사만 · 업로드 안 함)

| 길 | 사람 손 | 근거 · 위험 |
|---|---|---|
| ① Open Cloud Assets API · assetType **Animation** · `.rbxm/.rbxmx`(KeyframeSequence 1개) | 0 | 공식 지원 형식 표에 Animation = .rbxm · .rbxmx([usage guide](https://create.roblox.com/docs/cloud/guides/usage-assets)) · 2025 확장 공지([DevForum](https://devforum.roblox.com/t/open-cloud-upload-support-for-more-asset-types/4022082)). **FBX 애니는 Animation으로 못 올림**(FBX = Model만). 경고: "Studio 밖에서 고친 rbxm은 안 올라가거나 동작 안 할 수 있음" · 제3자 도구(asphalt)는 애니 업로드에 쿠키 인증을 요구한다고 적어 **API 키만으로 되는지 미확인** → 키 권한(asset:write)으로 시험 1회 필요 |
| ② Studio에서 KeyframeSequence를 스크립트로 만들고(임시 재생과 같은 것) → 사람이 탐색기에서 우클릭 **Save to File** → `.rbxm` → ① 업로드 | 애니당 2(우클릭 · 저장 대화상자) | "Studio가 만든 rbxm"이라 ①의 경고를 피함 · KeyframeSequence는 Studio 안에서 만들어져 뼈 이름 · 축이 이미 Roblox 기준 |
| ③ Python으로 KeyframeSequence `.rbxmx`(XML) 직접 생성 → ① | 0 | Pose CFrame 값은 Studio에서 한 번 덤프 필요 · ①의 "밖에서 만든 파일" 경고에 해당 → 시험 필요 |
| ④ Studio Animation Editor: 리그 선택 → Animation Editor → … → Import → From FBX Animation → 파일 → … → Publish to Roblox → 소유자(게임 소유자 계정) → Submit | 애니당 약 7 | 가장 확실(공식 화면 경로) · 리그(AnimationController/Humanoid 붙은 모델)가 Workspace에 있어야 함 |

추천: 실서비스 = ②(사람 2단계 · 확실) → ① 시험이 통과하면 ③로 0단계 자동화. 펫 25 · 몬스터 12 × 애니 3 ~ 4개면 ④는 약 250 ~ 350번 클릭이라 피함.

> 상태: 2026-10-11 · ART-INVENTORY-1 결과 · 읽기 전용 조사(게임 데이터 · 코드 · place 변경 0 · Meshy 크레딧 사용 0)
> 경로는 모두 `roblox/` 기준. 줄 번호 = 이 커밋 시점.

# ART-INVENTORY-1 — 3D 교체 대상 전수 (Meshy 크레딧 계산용)

## 0. 요약

| 종류 | 지금 있는 것 | 교체 대상(제안) | 지금 형태 | 분류 |
|---|---|---|---|---|
| 몬스터 | 종 13(활성 12 · 은퇴 1) · 변형 = 모델 같음 | **12** | 메시 10 + 블록 2(moss_slime · cloud_sheep 메시 일부러 안 씀) | 부위로 나눠야 함(Motor6D 부위 = 관절) |
| 펫 | 종 24 · 몸 틀 **3**(강아지 9 · 고양이 9 · 새끼 용 6) × 겉모습 3 = 메시 9 | **9**(지금 구조) 또는 **24**(종마다 모델 - 사용자 결정) | 메시 9(전부 승인) | 부위로 나눠야 함(이름 붙은 부위만 움직임 · 관절 0) |
| NPC | 메시 5 + 블록 1(보석상인) + 없음 1(부화장지기) | **7** | 메시 5 · 블록 1 | 부위로 나눠야 함(관절 축 3개 회전) |
| 마을 건물 | 건물 종류 6(집 A ×3 · 집 B ×2 포함 배치 9) | **6** | 메시(FBX) | 메시 1개로 됨(판정 상자 따로 있음) |
| 마을 소구조물 | 게시판 · 재련 화로 · 보석 가공대 · 강화대 · 환생 제단 · 명예의 전당 판 · 광장 자리 | **5 ~ 8** | 메시 5 · 블록(판 · 광장 기둥) | 메시 1개로 됨 |
| 큰 나무 | 메시 조각 6(단위 메시를 늘려 씀) | **0 권장** | 메시 | Meshy 부적합(아래 4-3) |
| 방어구 | look3 메시 96(직업 4 × 부위 3 × 등급 8) + LOD 60 + 옛 세대 90 | **24** | 메시 + SurfaceAppearance | 부위로 나눠야 함(R15 부위마다 조각 · 용접) |
| 포탈 | 원판 6 | **0**(사용자 10-11 결정) | 코드 파트 | 해당 없음 |

- **지금 코드에서 리깅(본 · 스킨)을 쓰는 곳 = 0.** 몬스터 = 부위마다 Motor6D, 펫 · NPC = 이름 붙은 파트를 클라가 직접 CFrame, 방어구 = R15 부위에 WeldConstraint. 그래서 "리깅 필요" 칸은 지금 구조를 유지하면 비어 있다(5절).
- **가장 큰 파이프라인 차이:** 지금 몬스터 · 펫 · NPC · 건물 메시는 전부 **텍스처 없는 단색 부위**(파트 이름 = 색 역할)다. 몬스터 가져오기 검사가 SurfaceAppearance · Decal · Texture를 금지한다(`src/shared/data/MeshImportCheckData.lua:47`). Meshy 결과물은 텍스처 1장 + 메시 1개가 기본이라 ① 부위 분할 ② 텍스처 허용 규칙(또는 색 굽기 → 단색 부위) 결정이 먼저 필요하다.
- **사용자 기억과 다른 점 4개:** ① 알 후보 2종은 고정 쌍이 아니라 구역 풀 4종 중 무작위 2종 ② 이벤트 전설 펫 = 코드에 없음(설계 문서만) ③ 부화장지기 = 코드에 없음(자리만 `soon`) ④ "작업대"라는 별도 구조물 없음(보석 가공대 · 강화대 둘 중 하나).

---

## 1. 몬스터

### 1-1. 구조(모든 종 공통)
- 구역 6 × 종 2. 스폰 풀 = `src/shared/data/WorldMapData.lua:234`(석조 평원) · `:246`(수정 동굴) · `:258`(수몰 사원) · `:270`(모래 유적) · `:283`(폭풍 첨탑) · `:295`(빙하 동굴).
- 종 정의 = `src/shared/data/MonsterSpeciesData.lua:19-71` · 리그 = `src/shared/data/MonsterRigSpec.lua` · 조립 = `src/shared/BossRig.lua:62-127`.
- 수치는 티어, 겉모습은 종(`src/shared/data/MonsterData.lua:206-238`). 티어 크기 배율 S = r^0.5(`MonsterData.lua:159`): T1 1.000 · T2 1.051 · T3 1.138 · T4 1.287 · T5 1.466 · T6 1.672.
- 형태: 보이지 않는 HumanoidRootPart(2×2×1×S) + 부위 Part/WedgePart/공 Part(SmoothPlastic · 일부 Neon · 단색) · **부위마다 Motor6D 1개 → 관절 수 = 부위 수** + Hitbox 관절 1. 부위 상한 10(드래곤 14) `MonsterRigSpec.lua:181-185`.
- 메시 교체: `src/server/MonsterSpawner.lua:260-300` — `ArtMeshKit.get("monsters/<id>")`가 있으면 같은 이름 부위 자리에 MeshPart를 끼운다(관절 · 색 역할 · Hitbox 유지). 로드 전이면 블록으로 나왔다가 나중에 교체(`:273` lateSwap). 스위치 `ArtStyleV1` 기본 켜짐(`src/shared/data/ArtStyleV1Data.lua:41`).
- 메시 자산 10개 승인(`src/shared/data/ArtAssetIds.lua:760-769`) · 건너뜀 `src/shared/data/ArtImportData.lua:20 monsterSkip = { moss_slime, cloud_sheep }`(FBX는 있음).
- 가져오기 규칙(`MeshImportCheckData.lua`): 삼각형 예산 몬스터 1,500(`:21`) · 관절 위치 오차 ≤ 0.15 stud(`:17`) · 전체 경계 = 리그 대비 0.8 ~ 1.25배(`:27`) · 기본 히트박스 2.4×4.6×1.6×S(`:35`).
- 동작:
  - 예비 동작 · 경계 자세(전 종) = `src/client/MonsterRigAnimator.client.lua` 가 PreSimulation에서 `Motor6D.Transform`(`:95`) · 160 stud 밖 생략(`:12`).
  - 대기 · 걷기 = 사인 절차 모션(`src/client/ArtV1View.client.lua:96-105` · 값 `ArtStyleV1Data.lua:56-61`) — **ArtV1 리그(= moss_slime)만**. 나머지는 서버 `PivotTo` 이동 · 회전뿐(`src/server/MonsterAI.server.lua:205-259`) → **대기/걷기 모션 없음**.
  - 키프레임 애니메이션 · AnimationController 없음.

### 1-2. 종별 표
상자 = 리그 순방향 계산(조사 중 계산값 · 데이터에 저장된 값 아님) · 삼각형 = `src/shared/MeshMeta/<id>.lua`.

| id | 이름 | 종 줄 | 리그 줄 | 구역 · 비중 | 지금 형태 | 부위(= 관절) | 상자 S=1 → 실제(stud) | 삼각형 |
|---|---|---|---|---|---|---|---|---|
| moss_slime | 이끼 슬라임 | :20 | :21 | T1 · 0.65 | 아트 견본 블록 리그 10부위(`ArtStyleV1Data.lua:25-38`) · 메시 건너뜀 | 4(Body 공 · Head · Eye_L/R) / 아트 리그 10 | 2.6×2.3×2.6 | 906(미업로드) |
| rock_boar | 바위 멧돼지 | :23 | :29 | T1 · 0.35 | 메시 | 10(Body · Head · Eyes · Tusk_L/R · Moss · Leg×4) | 1.8×2.4×4.2 | 1,012 |
| crystal_beetle | 수정 딱정벌레 | :26 | :42 | T2 · 0.75 | 메시 | 8(Body · Head · Eyes(Neon) · Leg_L/R · Shell1~3) | 2.0×3.35×3.4 → 2.1×3.5×3.5 | 1,196 |
| amethyst_bat | 자수정 박쥐 | :29 | :55 | T2 · 0.25 | 메시(떠 있음) | 7(Body 공 · Head · Ear_L/R · Eyes · Wing_L/R) | 5.6×2.3×1.45 → 5.9×2.4×1.5 | 1,064 |
| hermit_knight | 소라게 기사 | :32 | :65 | T3 · 0.6 | 메시 | 8(Body · Head · Eyes · Shell 공 · Claw_L/R · Leg_L/R) | 4.05×2.95×2.85 → 4.6×3.4×3.2 | 842 |
| bubble_jelly | 물방울 해파리 | :35 | :78 | T3 · 0.4 | 메시(떠 있음) | 7(Body 공 · Head · Eyes · Tentacle1~4) | 2.2×3.45×2.2 → 2.5×3.9×2.5 | 914 |
| sand_scorpion | 모래 전갈 | :38 | :89 | T4 · 0.5 | 메시 · 아트 스위치 재색(`ArtStyleV1Data.lua:51`) | 10(Body · Head · Eyes · Claw_L/R · Leg_L/R · Tail1~3 사슬) | 2.2×3.1×4.3 → 2.8×4.0×5.5 | 1,226 |
| cactus_imp | 선인장 꼬마 | :41 | :103 | T4 · 0.5 | 메시 · 재색 | 6(Body · Head · Flower · Eyes · Arm_L/R) | 2.2×3.3×1.3 → 2.8×4.2×1.6 | 916 |
| bolt_imp | 번개 임프 | :44 | :113 | T5 · 0.5 | 메시 | 10(Body · Head · Eyes · Horn_L/R(Neon) · Arm_L/R · Leg_L/R · Tail) | 1.8×3.3×1.8 → 2.6×4.9×2.6 | 892 |
| cloud_sheep | 구름 양 | :47 | :127 | T5 · 0.5 | **블록만**(메시 건너뜀) | 8(Body 공 · Wool 공 · Head · Eyes · Leg×4) | 2.4×3.0×3.7 → 3.5×4.4×5.5 | 1,246(미업로드) |
| ice_golem | 얼음 골렘 | :50 | :139 | T6 · 0.65 | 메시 · 재색 | 9(Body · Head · Eyes · Arm_L/R · Fist_L/R(팔의 자식) · Leg_L/R) | 4.3×3.7×1.4 → 7.2×6.2×2.3 | 668 |
| blue_dragon | 푸른 드래곤 | :57 | :164 | T6 · 0.35 | 메시 · 전용 히트박스 3.4×5.0×6.4(`:61`) · 모양 공격 3 + 포효 자세(`:60-70`) | 14(Body · Leg×4 · Neck1 · Head · Jaw · Eyes(Neon) · Wing_L/R · Tail1~3) | 10.6×6.8×14.3 → **17.7×11.4×23.9** | 1,436(예산 96%) |
| snow_rabbit | 눈토끼(은퇴) | :53 | :152 | 없음(`retiredBy="blue_dragon"`) | 블록만 · FBX 없음 | 6 | 1.4×2.5×2.0 | — |

이름(영) = `src/shared/data/TextData_names.lua:111-113` · 도감 출현 문구 = `src/shared/data/MonsterCodexData.lua:20-34`.

### 1-3. 변형(전부 **모델 따로 필요 없음**)
스폰 순서 `MonsterSpawner.lua:61-77`: 보물상자 0.1% → 반짝이 0.1% → 접두사 10%(반짝이와 접두사는 겹치지 않음).
- **반짝이(황금 몬스터)** — 모델 그대로 · 서버는 태그 `SparkleMonster`만(`MonsterSpawner.lua:192` · 확률 `src/shared/data/RareMonsterConfig.lua:24`). 무지개 빛 · 파티클 · 60 stud 빛기둥은 모델 **밖** 따로 만든 파트가 피벗을 따라감(`src/client/SparkleMonsterVisual.client.lua:31-82, 111-124`) — 메시 교체에 영향 없도록 일부러 밖에 둔 것(`RareMonsterConfig.lua:51-56`).
- **접두사**(`src/shared/data/MonsterPrefixData.lua`) — 같은 모델 크기만: 연약한 ×0.8(4% · `:33-40`) · 단단한 ×1.2(4% · `:41-48`) · 거대한 ×1.45(2% · `:49-56`) · 적용 `MonsterSpawner.lua:171`. 거대한 드래곤 ≈ 25.7×16.5×34.7 stud → **메시 크기 상자 최대치 기준**.
- 정예 · 챔피언 = 없음 · 그 밖 희귀 몬스터 = 없음(웹판 재료 몬스터 미이식 `RareMonsterConfig.lua:14-19`).
- 겉모습만 바뀌는 것: 세대 색조(`src/client/GenerationView.client.lua` · 17,000 스테이지 이상) · 아트 스위치 재색(전갈 · 꼬마 · 골렘) · 보물상자 = 몬스터 대신 블록 상자(`MonsterSpawner.lua:~371-440`).

---

## 2. 펫

### 2-1. 알 구조
- 구역 6 · 구역마다 종 풀 **4종**(`src/shared/data/EggData.lua:9-14`).
- 알 등급 3: 보통 알 / 반짝 알 / 신비한 알(`EggData.lua:27, 29`) → 알 종류 18.
- 알 하나 = 후보 2종 50:50(`EggData.lua:25-26`) — **풀 4종 중 무작위 2종**(`src/server/NestServer.lua:140-146`). 고정 쌍 아님. 부화 때 종 결정(`src/shared/Pet.lua:62-89`).
- 부화 결과 등급 4: 일반 / 희귀 / 영웅 / 전설(`EggData.lua:54, 56` · 확률 `:57-61`). 메시 겉모습 대응 = common→normal · uncommon→good · rare·epic→rare(`ArtImportData.lua:30`).
- **이벤트 전설 펫 = 코드에 없음.** 설계만 `docs/design/PROG-2-spec.md:203, 235, 403`(같은 문서 `:69` "합성 · 이벤트 펫 없음"). 시즌 패스 · 보드는 일반 알 보상뿐(`src/shared/data/SeasonPassData.lua:59` · `SeasonBoardData.lua:16`).

### 2-2. 종 24 = 몸 틀 3 + 구역 색
몸 = `src/shared/data/PetData.lua:28-33` · 이름 = `EggData.lua:18-23` · 구역 색 = 보스 관문 색(`src/client/NestView.client.lua:20-28` → `BossData.lua`) · 무늬 색 = 같은 색 × 0.55.

| 구역 | 종(몸) | 같은 구역 안에서 **완전히 같은 겉모습** |
|---|---|---|
| tier1 석조 평원 | 돌 거북(dog) · 이끼 토끼(cat) · 조약돌 두더지(dog) · 폐허 올빼미(dragon) | 돌 거북 = 조약돌 두더지 |
| tier2 수정 동굴 | 수정 박쥐(dragon) · 프리즘 도마뱀(dog) · 반짝 달팽이(cat) · 석영 여우(cat) | 반짝 달팽이 = 석영 여우 |
| tier3 수몰 사원 | 산호 수달(dog) · 소라 게(cat) · 물결 개구리(dog) · 연꽃 물고기(dragon) | 산호 수달 = 물결 개구리 |
| tier4 모래 유적 | 사막 여우(cat) · 선인장 고슴도치(dog) · 쇠똥구리(cat) · 햇빛 도마뱀붙이(dragon) | 사막 여우 = 쇠똥구리 |
| tier5 폭풍 첨탑 | 불꽃 족제비(cat) · 구름 양(dog) · 천둥 매(dragon) · 돌풍 다람쥐(cat) | 불꽃 족제비 = 돌풍 다람쥐 |
| tier6 빙하 동굴 | 서리 펭귄(dog) · 눈 올빼미(dragon) · 얼음 물범(dog) · 오로라 여우(cat) | 서리 펭귄 = 얼음 물범 |

- 같은 메시 + 색만 다른 묶음 = **강아지 9종 · 고양이 9종 · 새끼 용 6종**. 같은 구역 안 완전 동일 쌍 6개 → 눈으로 구별되는 조합 18.
- 몸 틀은 자리 표시(`EggData.lua:16` "모형 · 기능 · 이름 확정은 펫 단계") — 거북 · 게 · 물고기가 강아지/고양이 몸인 상태.
- 영어 이름 빠짐: 구름 양(cloudSheep) `TextData_names.lua:121`에 없음(참고 · 이번 범위 밖).

### 2-3. 형태 · 부위 · 동작
- 서버는 Attribute 4개만(`src/server/PetService.lua:24-27`) · 클라마다 직접 만든다(`src/client/PetView.client.lua`).
- 메시 경로 `PetView:54-82`: 캐시 모델 `pets/<body>_<look>` 복제 · 고정(Anchored) · 파트 이름으로 색(base/accent/eye) · `Deco` 고정 대비색(`ArtImportData.lua:31-35`) · rare = PointLight(`:36-37`). 블록 대체 `PetView:83-98`. 왕관 치장 5파트 `PetView:99-122`.
- 메시 자산 9개 승인 `ArtAssetIds.lua:770-778` · 원본 `art/pets/*.fbx` · `art/pets/{dog,cat,dragon}.meta.json` · 생성 `tools/blender/make_pets.py`.
- **관절 0** — 모든 파트 고정 · 매 RenderStepped `cf * offset`(`PetView:221-231`). 움직이는 파트 이름 = **Head · Wing_L · Wing_R · Crown_\***(`PetView:224-228`) → 새 메시도 이 이름 유지 필요.
- 동작(`PetView:184-233` · 값 `PetData.lua:37`): 따라오기 = 지수 보간 + 지면 광선 · 걷기 깡충(강아지 · 고양이 `|sin(12t)|·0.18`) · 날기(용 2.4 stud · ±0.25 흔들림 · 날개 Z `sin(10t)·0.5` rad) · 대기 = 머리만 `sin(2t)·0.04` · 기쁨 = 줍기 때 점프 + 한 바퀴.

| 몸 | 리그 줄 | 부위 | 상자(stud) | 삼각형 normal / good / rare(예산 800) |
|---|---|---|---|---|
| dog 강아지 | `PetData.lua:40-49` | 8(Body · Head · Ear_L/R · Leg_F/B(다리 두 개를 막대 하나로) · Tail · Eyes) | 0.70×1.32×1.73 | 586 / 687 / 779 |
| cat 고양이 | `:51-58` | 8(귀 = 쐐기 · 꼬리 위로) | 0.60×1.43×1.53 | 484 / 635 / 767 |
| dragon 새끼 용 | `:61-67`(날기 `:70`) | 7(Body · Head · Horn · Wing_L/R · Tail · Eyes) | 2.30×1.10×2.04 | 502 / 639 / 771 |

- good/rare = 고정 `Deco` 파트 추가(목걸이 · 리본 · 스카프 / rare 왕관 뿔 + 보석) · 강아지 · 고양이는 Tail을 Leg_B에 합쳐 8 유지.
- 설계 규칙: 파트 ≤ 8 · 키 약 1.3 stud(`PetData.lua:26`).
- 모델이 바뀌면 도감 아이콘 96장(24종 × 부화 등급 4, `art/icons/codex/pet_<id>_<grade>.png`)도 다시 찍어야 한다.

---

## 3. NPC

### 3-1. HubArtData 관절 흔들기 = **메시를 부위로 나눠야 한다**
- 방식: 부위 묶음이 고정 축(피벗)을 중심으로 `offset + amp × sin(2πt / period)`도 회전(`src/shared/data/HubArtData.lua:3-4`). Motor6D · Bone · AnimationController 없음.
- 서버 `src/server/HubArt.lua:39-63`이 캐시 FBX의 파트를 이름 그대로 복제(고정 · 충돌 끔) · `:366-388`에서 Atomic 스트리밍 · WorldPivot = 바닥.
- 클라 `src/client/HubNpcView.client.lua:25-41` 이 쉬는 자세를 한 번 저장하고, `:81-97`에서 150 stud 안 NPC만 매 프레임
  - `:90` `rot = pivot * angles(axis, offset + amp*sin(...)) * pivot:Inverse()`
  - `:92` `part.CFrame = frame * rot * local`
- 피벗(전 NPC 같음) = `src/shared/data/HubArtMeta.lua:12-16` `ArmL {-1.32,3.55,0} · ArmR {1.32,3.55,0} · Head {0,3.95,0}`(생성기 `tools/blender/make_hub.py:315` 하드코딩).
- **새 메시 조건:** 파트 이름 `Head · Face · Hat · Plume`(머리 묶음, `HubArtData.lua:5`) · `ArmL · ArmR · ToolL · ToolR`가 따로 있어야 하고, 피벗 좌표를 HubArtMeta에 맞춰야 한다. 묶음 파트를 하나도 못 찾으면 그 NPC 전체 모션이 조용히 꺼진다(`HubNpcView:35-36`). 다리 관절 없음(Legs 한 파트).

### 3-2. NPC 표 (메시 NPC 충돌 없음 · 자산 `ArtAssetIds.lua:860-864` · 예산 1,500)

| id | 이름 | 데이터 | 지금 형태 | 부위(HubArtMeta 줄) | 관절 | 대기 동작 | 상자(stud) | 삼각형 |
|---|---|---|---|---|---|---|---|---|
| smith | 대장장이 | `HubArtData.lua:14-17` | 메시 | 9(Apron · ArmL/R · Face · Hat · Head · Legs · ToolR · Torso) `:15` | 축 3 | 오른팔+망치 X 25±35° 1.1초 · 머리 끄덕 | 3.42×5.95×1.75 | 382 |
| merchant | 상인 | `:18-21` | 메시 | 8(Bag 포함) `:14` | 축 3 | 오른팔 Z 30±18 · 머리 좌우 ±12 | 3.35×6.51×2.6 | 426 |
| tailor | 재봉사 | `:22-25` | 메시 | 9(Tape · ToolR 포함) `:16` | 축 3 | 오른팔+가위 X 35±10 0.55초 | 3.3×5.88×1.67 | 366 |
| knight | 도전 기사 | `:26-29` | 메시 | 10(Plume · ToolL · ToolR 포함) `:13` | 축 3 | 머리 좌우 ±18 · 왼팔+방패 X 8±3(왼팔 축 쓰는 유일) | 4.24×6.86×1.92 | 422 |
| keeper | 게시판지기 | `:30-33` | 메시 | 8 `:12` | 축 3 | 오른팔 X 40±8 · 머리 ±5 | 3.67×5.83×1.8 | 362 |
| GemMerchant | 보석상인 | HubArtData에 **없음** · `src/server/HuntingGround.server.lua:120-208` | **블록 4**(Stall 6×2×3 충돌 · Body · Head 공 · Gem Neon) | — | 0 | 없음 | 높이 약 6 | — |
| (없음) | 부화장지기 | **코드에 없음** · 제안만 `docs/design/handoff/30_hub-art/v1/spec.md:158-177` · 자리 `hatchery` `WorldMapData.lua:79`(`soon`) | — | — | — | (제안: 알 쓰다듬기) | — | — |

---

## 4. 마을 건물 · 구조물

### 4-1. 판정 파트와 겉모습 파트 = **나뉘어 있다**
- 건물마다 `src/shared/WorldMapLayout.lua:1347-1350` 이 보이지 않는 판정 상자 `Facility_<id>`(w × d × 벽 높이 · 바닥 아래 2 stud 묻힘 `:450-453`)를 만들고, HubArt가 겉모습 메시를 올린 뒤 상자만 투명(`HubArt.lua:350` "충돌 상자는 그대로"). 지붕 · 굴뚝 판정 없음.
- 캐시 메시 파트는 전부 충돌 · 터치 · 조준 끔(`src/shared/ArtMeshKit.lua:24-41`).
- 20.48 stud 넘는 FBX는 통째 축소 → `restoreScale`로 되돌림(`HubArt.lua:25-36`) — 새 건물 메시도 같은 함정.
- 지금 건물 메시 = 단색 부위(Wall · Roof · Tiles · Window(Neon) …) 10~16개, 텍스처 없음(`HubArtMeta.lua:6` 대장간 예).

### 4-2. 표 (자산 `ArtAssetIds.lua:790-796`)

| 구조물 | 데이터 | 지금 형태 | 겉모습 상자(stud) | 판정 | 삼각형 / 예산 |
|---|---|---|---|---|---|
| 대장간 hub_forge | `HubArtMeta.lua:6` · 배치 `WorldMapData.lua:70` | 메시 16부위 + 굴뚝 연기(`HubArt.lua:90-109`) | 31.2×27×25.4 | 투명 상자 28×20×14.4 | 718 / 3,000 |
| 상점 hub_shop | `:10` · `:74` | 메시 | 29.2×26.7×23.4 | 26×18×15.4 | 690 / 3,000 |
| 명예의 전당 hub_hall | `:7` · `:77` | 메시 | 34×26.51×26 | 30×22×18 | 1,232 / 3,500 |
| 재봉집 hub_tailor | `:11` · `:74` | 메시 | 23.2×20.7×20.71 | 20×16×11.9 | 606 / 2,500 |
| 집 A hub_house_a(배치 3) | `:8` | 메시 | 23.2×19.7×19.6 | 20×16×11.4 | 446 / 2,500 |
| 집 B hub_house_b(배치 2) | `:9` | 메시 | 25.2×21.2×19.6 | 22×16×12.4 | 518 / 2,500 |
| 마을 게시판 hub_board | `HubArtData.lua:36` · `HubArtMeta.lua:5` | 메시(Board · Papers · Posts · Roof) + 공지 SurfaceGui(`src/client/UpdateBoard.client.lua:229`) | 9×8.3×3 | 없음(자리 기둥 충돌 끔 `HubArt.lua:384-385`) | 142 / 800 |
| 재련 화로 prop_refine_furnace | `HubArtData.lua:37` · `WorldMapData.lua:72` | 메시(Body · Crucible · Glow Neon · Mouth) | 3×5.2×2.75 | 없음 | 148 / 300 |
| 보석 가공대 prop_gem_bench | `HubArtData.lua:38` · `:72` | 메시(Bench · Gems · Lens) | 4×4.38×2.2 | 없음 | 224 / 300 |
| 강화대(작업대 후보) EnhanceStation | `src/server/EnhanceStation.server.lua:12-57` | 3겹: 서버 블록(판정) → 클라 블록 모델 `ArtV1Models.forge()`(`src/shared/ArtV1Models.lua:114-148` · 배율 1.7) → 메시 `props/forge`(`ArtAssetIds.lua:788`) | 약 4×4 바닥 × 1.7 | 서버 Base 4×3×4 · AnvilTop 3×1×2 | 1,538 / 3,000(20부위) |
| 환생 제단 RebirthAltar | `HuntingGround.server.lua:56-115` | 코드 Base 5×2×5(판정) + Orb → 메시 `props/rebirth_altar`로 겉 입힘(`ArtMeshKit.lua:186-221` · `ArtAssetIds.lua:882`) | 약 6×5×6 | Base 그대로 | 932 / 1,500 |
| 명예의 전당 석판 · 게시판 | `src/server/HallOfFame.lua:17, 82-115` · `src/server/HallBoard.server.lua:37-50` | 파트(Slab 16×12×1 · Board 24×16 · SurfaceGui) | — | 기본 충돌 | — |
| 광장 4자리 | `WorldMapData.lua:79-81`(부화장 `soon` · 파티 게시판 · 순위판 · 명예의 전당) | 회색 기둥 `Spot_<id>`(`WorldMapLayout.lua:1351-1356`) · 아트 없음 · 부화장 = 자물쇠 + "곧 열려요"(`src/server/WorldMap.lua:116-139`) | 6×5(+2 묻힘)×2 | 기둥 자체 충돌 | — |
| 큰 나무 | 코드 `WorldMapLayout.buildTree` `:822+` · 메시 `HubArt.dressTree` `HubArt.lua:276-325` · `src/shared/data/TreeArtMeta.lua:3-8` | 코드 줄기 · 뿌리 · 잎(판정) 투명 + 메시 6종: trunk_base 149.5×34×132.1(1,236) · trunk_section 단위 2×1×2(388 · 줄기마다 늘려 씀) · root 125×29.5×22(172 ×6 각도) · branch · stem · deck 단위 메시(156 / 108 / 148) | 반지름 48 · 높이 800(`WorldMapData.lua:92`) | 코드 파트 판정 유지 | 표 왼쪽 |

- 그 밖 마을 소품(가판 · 상자 · 수레 · 통 · 화분 · 모루 석상 · 표지 · 깃발 · 벤치 · 우물 · 꽃 · 등불 · 울타리 · 덤불 · 작은 나무): 배치 `src/shared/data/HubPropsData.lua:8-55` · 메시 `HubArtMeta.lua:17-33` 전부 68 ~ 278 삼각형 · 울타리 · 우물만 투명 판정(`HubPropsData.lua:59`). **이번 Meshy 범위 밖 권장**(이미 낮은 폴리 · 수가 많음).

### 4-3. 큰 나무를 Meshy에서 빼는 이유
줄기 · 가지 · 데크는 **단위 메시 하나를 코스 파트 크기로 늘려 쓴다**(`HubArt.lua:296-319`). 통짜 생성 메시는 이 늘림 방식과 맞지 않고, 높이 800 stud 규모는 생성 해상도 밖이다. 껍질 · 판자 텍스처(`HubPropsData.lua:66-79`) 교체가 더 싸다.

---

## 5. 방어구

### 5-1. 등급 · 부위
- 등급 8 = 일반 · 희귀 · 영웅 · 전설 · 유물 · 고대 · 태초 · 초월(`src/shared/data/ArmorData.lua:69` · 이름 `:96-149`) · 등급 색 `src/shared/data/ItemVisualData.lua:26-120`.
- 부위 3 = armor · gloves · shoes(`src/shared/data/EquipSlots.lua:18`).

### 5-2. 지금 형태 = **직업별 메시**(사용자 10-11 "직업 차이 없음"과 다름)
`ArtAssetIds.lua:10-261` armor 모델 252개(전부 승인):

| 세대 | 키 | 개수 | 지금 쓰임 |
|---|---|---|---|
| A2-N3 구역 | `armor/<slot>_tier1..6_<normal\|legendary\|transcendent>` | 54 | 직업 없을 때 대체 |
| QUEUE-ALL1 v3 | `armor/<slot>_<class>_<3 looks>` | 36 | 옛 경로 |
| LOOK2 단계 | `armor/<slot>_<class>_s1..s5` | 60 | **LOD**(70 stud 밖 · 그래픽 ≤ 3 · 폰) `GearV3Data.lua:52-62` |
| **LOOK3(현행)** | `armor/look3_<slot>_<class>_<grade>` | **96**(직업 4 × 3 × 8) | 기본 겉모습 `ArtAssetIds.lua:116-211` |
| 세트 문장 | `armor/emblem_<6 세트>` | 6 | 몸통에 붙는 문장 |

- 키 생성 `src/shared/GearV3.lua:121` `("look3_%s_%s_%s"):format(slot, classId, grade)` · 직업 선택 `src/client/ArmorWearView.client.lua:179-183` · 직업 바뀌면 다시 입힘(`:354`).
- **장갑 · 신발은 지금도 사실상 직업 무관** — 생성기 `tools/blender/make_gear_look3.py:454-531` 가 cls를 받지만 안 씀 · 삼각형 수 · 텍스처 md5 4직업 동일. 몸통만 직업별로 다르다(`:318-450`).
- 직업 고정 지점(24개로 줄일 때 고칠 곳): `GearV3.look3Key` · `ArmorWearView.client.lua:179-200, 354` · `GearV3Data.baseLayer`(직업별 셔츠/바지 색 `:48`) · 생성기 CLASSES 반복(`make_gear_look3.py:28, 798-803`) · LOD 60개도 직업별.

### 5-3. R15에 붙이는 방식 = 클라 MeshPart 조각 + WeldConstraint
- `ArmorWearView.client.lua:1-4` · 용접 `weldPiece` `:82-92`(Massless · 충돌/조준/터치/그림자 끔 · Part0 = R15 부위) · 부모 `workspace.ArmorWear`(`:13-15`) · R15만(`:312-315`). Accessory · WrapLayer 안 씀(결정 근거 `docs/art/armor-wear-spec.md:20-33`).
- 몸 맞춤: 축마다 R15 실측 ÷ 기준 체형(`src/shared/MeshMeta/armor_wear.lua:4-20`) · 범위 `fitClamp {0.6, 1.6}`(`GearV3Data.lua:60`).
- 관절 = AnimationConstraint(Motor6D 없음) — 조각이 부위에 강체로 붙어 같이 움직임(스킨 없음 · `armor-wear-spec.md:29`).

| 부위 | 조각 → R15 파트 |
|---|---|
| armor | `Main` → UpperTorso(가슴 · 깃 · 허리띠 · **어깨 갑옷** · 망토) · `Tasset` → LowerTorso · `Emblem` → UpperTorso |
| gloves | `Glove_L/R` → Left/RightHand · `Bracer_L/R` → Left/RightLowerArm |
| shoes | `Boot_L/R` → Left/RightFoot · `Greave_L/R` → Left/RightLowerLeg |

- 한 벌 = MeshPart 11 · 어깨 갑옷이 UpperTorso에 붙어 팔 들면 박힘(알려진 비용 · 사용자 승인 `docs/design/gear-art-v3.md:118, 148`).

### 5-4. 삼각형 · 텍스처
부위 합(`MeshMeta/armor_wear.lua:1742+`):

| 부위 | 일반 | 전설 | 태초 | 초월 |
|---|---|---|---|---|
| 몸통(대검) | 1,662 | 3,276 | 4,384 | 4,276 |
| 몸통(쌍검) | 1,782 | 2,900 | 3,996 | 3,888 |
| 몸통(활) | 1,362 | 2,242 | 3,026 | 3,010 |
| 몸통(치유사) | 1,594 | 2,676 | 4,016 | 3,908 |
| 장갑(전 직업 같음) | 1,152 | 1,416 | 1,720 | 1,752 |
| 신발(전 직업 같음) | 992 | 1,264 | 1,656 | 1,728 |

- 한 벌 최대 약 7.9k(대검 태초).
- 예산(현행 LOOK3) `GearV3Data.lua:61`: 부위 일반 ~ 영웅 2,500 · 전설 ~ 고대 4,000 · **태초 · 초월 6,000** · 한 벌 15,000 · 조각 ≤ 4/부위 · 16/벌 · **텍스처 최대 1024**(생성기 몸통 1024 · 장갑 · 신발 512 `make_gear_look3.py:40-42`). 옛 LOOK2 예산 `:64`는 대체됨.
- 텍스처 방식: 조각마다 SurfaceAppearance 1개(`src/shared/GearV3Look3.rbxmx` 템플릿 96 · ColorMap에 빛 · 선 · AO 구움 · 천 부분 알파 0 → 세트 색이 비침 · 68개 발광 마스크) · 노멀/금속/거칠기 맵 없음(`GearV3.lua:124-128` · `ArmorWearView.client.lua:110-128`). 파일 `art/textures/gear_v3/look3/` 170장.
- 성능 메모: 한 벌 텍스처 최대 7.9 MB(압축 전) · 16명 최악 약 126 MB(`gear-art-v3.md:121`).
- 방어구는 몬스터 가져오기 검사(`MeshImportCheckData`)의 대상이 아니다(armor 항목 없음).

---

## 6. 포탈 (3D 제외 · 지금 형태만)
- 허브: 구역마다 원판 `HubPortal` 6개 — 실린더 0.4 × 12 × 12(`portalRadius = 6` `WorldMapData.lua:373`) · 색 barrier {120,190,255} · SmoothPlastic · 충돌 켬 · Attribute `Portal` · `PortalSide="hub"`(`WorldMapLayout.lua:1410-1415`) · 반지름 38 고리(`:188-193`) · 포탈 광장 반지름 46(`:1339`).
- 이름표: 클라 `PortalSignsLocal` 빌보드(`src/client/WorldClient.client.lua:95-128`).
- 진입: 서버 거리 폴링(Touched 아님 · `src/server/Travel.lua:652-660, 749-760`).
- 캠프 쪽: 파트 없음 · 좌표만(`WorldMapLayout.lua:194-196`).

---

## 7. 분류

| 분류 | 대상 | 이유 |
|---|---|---|
| **메시 1개로 됨** | 건물 6 · 게시판 · 재련 화로 · 보석 가공대 · 환생 제단 · 광장 자리 겉모습 · 보석상인 가판대 | 움직이지 않음 · 판정은 따로 있는 상자/기둥이 맡음. 단, 지금 파이프라인은 색 역할별 단색 부위라 텍스처 1장 메시를 쓰려면 규칙 결정 필요(8절 ①) |
| **부위로 나눠야 함(강체 분할 · 리깅 X)** | 몬스터 12 · NPC 7 · 펫 몸 3(또는 24) · 방어구 24 | 몬스터 = 리그 부위 이름 · 관절 위치 ±0.15(가져오기 검사) · NPC = Head/Face/Hat/Plume · ArmL/R · ToolL/R 이름 + 피벗 · 펫 = Head · Wing_L/R · 방어구 = R15 부위마다 조각(한 부위 ≤ 4조각) |
| **리깅 필요(본 · 스킨)** | **지금 구조 기준 0** | 스킨 메시를 받는 코드가 없다. 몬스터 걷기 · NPC 다리 · 펫 다리를 "진짜로" 움직이고 싶을 때만 생김 → 그때는 애니메이터 · 가져오기 검사 · 메시 교체 코드 새 작업(이번 크레딧 계산에서 제외 권장) |

**강체 분할 작업량**(Meshy 결과를 Blender에서 잘라 이름 붙이는 수): 몬스터 부위 합 = 4+10+8+7+8+7+10+6+10+8+9+14 = **101 조각** · NPC 약 9 × 7 = **약 63** · 펫 몸 3 × 8 = **24**(종별 24 모델이면 약 190) · 방어구 24 × 2 ~ 4 = **약 88**(armor 3 · gloves 4 · shoes 4 기준).

## 8. 같은 메시 재사용 묶음(색만 다름)

| 묶음 | 지금 | 재사용 가능 |
|---|---|---|
| 몬스터 변형(반짝이 · 접두사 3 · 세대 색조 · 재색) | 모델 같음 | **추가 생성 0** |
| 펫 | 강아지 9 · 고양이 9 · 용 6종이 몸 하나씩 공유 · 구역 색만 다름 | 지금 구조 유지 시 **몸 3 × 겉모습 3 = 9** |
| 펫 겉모습 good/rare | Deco 파트만 추가 | 몸 3개 + Deco 6개로 쪼개면 생성 수 더 줄일 수 있음 |
| 집 | 집 A 3채 · 집 B 2채 | **2** |
| NPC | 피벗 · 키 거의 같음(높이 5.8 ~ 6.9) | 몸 한 벌 + 머리/도구 바꿔 끼우기 가능(생성 수 7 → 몸 1 ~ 2 + 소품) |
| 방어구 장갑 · 신발 | 4직업이 이미 같은 메시 | 등급 8 × 2 = 16(직업 반복 32개 중복 제거) |
| 방어구 등급 | 등급 색 = 판금 에나멜만(`gear-art-v3.md:94-102`) | 모양을 등급 묶음(일반~영웅 / 전설~고대 / 태초 · 초월)으로 3단만 생성 + 등급 색 · 텍스처로 8단 표시 → 생성 **24 → 9**(사용자 결정) |

## 9. 성능 예산 제안(종류별 삼각형 상한)
기존 데이터에 있는 값은 그대로 두고, 없는 값만 제안한다. Meshy 출력은 보통 수만 삼각형이라 **생성 뒤 이 상한으로 리메시** 전제.

| 종류 | 상한(제안) | 근거 | 텍스처(제안) |
|---|---|---|---|
| 몬스터(일반) | **1,500** | 기존 `MeshImportCheckData.lua:21` | 512² 1장 |
| 몬스터(푸른 드래곤 · 거대) | 1,500 유지 또는 **2,500**(예외) | 지금 1,436로 96% · 화면 최대 34 stud | 1024² |
| 펫 | **800** | 기존 `art/pets` 예산 · 16명 × 1마리 동시 | 256² |
| NPC | **1,500** | 기존 HubArtMeta budget | 512² |
| 건물 | 2,500 / 3,000 / 3,500 | 기존 HubArtMeta(집 · 재봉집 / 대장간 · 상점 / 전당) | 1024² |
| 소구조물(게시판 · 화로 · 가공대) | 800 / 300 / 300 → **800**로 올림 제안 | 화로 · 가공대 300은 생성 메시엔 너무 빡빡 | 512² |
| 환생 제단 · 강화대 | 1,500 / 3,000 | 기존 | 512² |
| 방어구 | 부위 2,500 / 4,000 / 6,000 · 한 벌 15,000 | 기존 `GearV3Data.lua:61` | 몸통 1024 · 장갑 · 신발 512 |

화면 동시 합계 어림(참고): 16명 × 방어구 최대 7.9k ≈ 126k + 펫 16 × 0.8k ≈ 13k + 몬스터 20마리 × 1.5k ≈ 30k → 약 17만 삼각형(무기 · 보스 · 지형 제외).

## 10. 작업 순서 제안
1. **파이프라인 시범 1개 — rock_boar**(T1 · 10부위 · 이미 메시가 있어 전후 비교 쉬움). Meshy 생성 → 리메시 1,500 → 부위 10개로 자르기 → 관절 ±0.15 · 경계 0.8 ~ 1.25 검사 통과. 이 단계에서 ① 텍스처 허용(SurfaceAppearance 금지 규칙 `MeshImportCheckData.lua:47` 바꿀지) 또는 색 굽기 → 단색 부위 ② 1개당 실제 크레딧 · 손질 시간을 잰다 → 나머지 계산의 단가.
2. **몬스터 나머지 11**(가장 많이 보이고, 변형 추가 생성 0). moss_slime · cloud_sheep는 지금 블록이라 효과가 가장 큼.
3. **방어구 24(또는 9)** — 먼저 직업 키를 없애는 코드 단계(별도 작업) 뒤에. 장갑 · 신발부터(이미 직업 무관).
4. **NPC 7** — 피벗 이름 규칙이 단순해 시범 1개 뒤 일괄. 보석상인 · 부화장지기는 새로 HubArtData 항목이 필요(데이터 추가).
5. **건물 6 + 소구조물** — 판정이 따로라 위험이 가장 낮음. 20.48 stud 축소 함정만 확인.
6. **펫** — 몸 3 유지 / 종 24 개별 결정 뒤(24면 도감 아이콘 96장 재촬영 포함).
7. 포탈 · 큰 나무 · 마을 소품 = 제외.

### 크레딧 계산용 생성 개수(최소 ~ 최대)
| 종류 | 최소 | 최대 |
|---|---|---|
| 몬스터 | 12 | 12 |
| 펫 | 3(몸만 · Deco 따로 6) | 24 |
| NPC | 2(몸 공유) | 7 |
| 건물 | 6 | 6 |
| 소구조물 | 4(게시판 · 화로 · 가공대 · 제단) | 8(+ 강화대 · 보석상인 가판 · 광장 자리 2) |
| 방어구 | 9(등급 3단 모양) | 24 |
| **합계** | **36** | **81** |
재시도(한 번에 맘에 드는 결과가 안 나오는 경우) 배수는 1단계 시범에서 잰 값을 곱한다.

## 11. 사용자 결정이 필요한 것
1. 펫 = 몸 3개 유지 vs 종 24개 개별 모델.
2. 방어구 = 등급 8단 모양 24개 vs 모양 3단 + 색 8단(9개).
3. 생성 메시 텍스처 = SurfaceAppearance 허용(가져오기 규칙 변경) vs 색 굽기 후 단색 부위(지금 방식 유지).
4. 이벤트 전설 펫 · 부화장지기는 아직 기능이 없음 — 이번 3D 계산에 넣을지.
5. "작업대" = 보석 가공대 · 강화대 중 무엇인지(둘 다 표에 넣음).

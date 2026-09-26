# 에셋 파이프라인 - 카툰 교체 대비 구조 (M1-4 · 2026-09-26)

> A1(스타일 잠금)에서 그대로 쓴다. 목표: **라이브러리 모델 하나를 카툰 모델로 바꾸면 맵 전체가 바뀐다.** 맵 코드에는 소품의 모양이 없고 "이름 · 위치 · 회전 · 크기"만 있다.

## 1. 소품(Props)

| 무엇 | 어디 |
|---|---|
| 틀(모양 · 크기 · 충돌 계약) | `roblox/src/shared/data/PropData.lua` `templates` |
| 배치 도우미(순수) | `roblox/src/shared/PropKit.lua` - `PropKit.place(list, 모델경로, 이름, cf, 배율)` |
| 라이브러리 · 복제(서버) | `roblox/src/server/PropLibrary.lua` → 런타임 `ReplicatedStorage.Assets.Props.<이름>` |
| 배치 데이터 | 구조물 · 채우기 · 외곽 · 신전 코드가 `PropKit.place`로 목록에 넣는다(`WorldStructures` · `WorldMapLayout` · `data/PropScatterData`) |
| 교체 모델 자리 | `ReplicatedStorage.Shared.PropModels.<이름>`(Rojo 파일 `roblox/src/shared/PropModels/<이름>.rbxm`) - `PropData.overrideFolders` |

### 1-1. 이름 규칙

`<테마>_<종류>[_<변형>]`

- 테마 = `T1` ~ `T6`(구역) · `Hub` · `Common`(여러 구역 공용) · `Gate`(관문 장식).
- 종류 = 영어 PascalCase 명사(`RockPillar` · `CrystalSpike` · `Shipwreck`). 변형 = `A` · `B` 또는 뜻(`Broken`).
- 예: `T1_RuinPillar` · `T1_RuinPillarBroken` · `T4_Cactus` · `Common_Ladder` · `Common_LeafClump`.

### 1-2. 모델 규칙(틀 · 교체 모델 공통)

| 규칙 | 값 |
|---|---|
| 피벗 | **바닥 가운데**(땅에 닿는 면 = y 0) · 교체 모델은 `WorldPivot`을 이 자리에 둔다(라이브러리가 피벗을 원점으로 옮긴다) |
| 방향 | −Z = 앞(사다리는 −Z 쪽에서 오른다 · 문은 −Z로 열린다) · +Y = 위 |
| 크기 | 틀 크기가 기준 1. 배치 배율은 축마다(`scale = 숫자` 또는 `{x, y, z}` - 틀 로컬 축). 교체 모델도 **틀의 경계 상자 · 충돌 발자국 안**에 들어간다 |
| 충돌 | 틀에서 `col = false`인 도형 = 장식(쿼리 · 터치 · 그림자 끔). 교체 모델도 충돌 파트 = 틀의 충돌 도형 자리(밟는 높이 · 막는 면이 같게). 판정 · 검사(빈 공간 · 둥지 보호 부피 침범 · 캡슐)는 **틀 도형**을 읽는다 |
| 표시 Attribute | `Climbable`(사다리 - 서버 높이 검사가 "오르는 중 = 서 있음"으로 인정) · `Cactus` 등 틀의 `a` 표를 교체 모델의 같은 역할 파트에 그대로 단다 |
| 재질 | 가능하면 지형과 같은 기본 재질 이름(`TerrainGenData.materialColors`) - §2 변형이 소품에도 같이 먹는다 |
| 크기 예산 | 소품 하나 파트 ≤ 8 · 메시 삼각형 ≤ 1,500(style-bible §12) |

### 1-3. 카툰 모델로 바꾸는 절차

1. Studio에서 새 모델을 만든다(MeshPart 등) → 이름 = 틀 이름(예: `T1_RockPillar`) · 피벗 = 바닥 가운데 · 앞 = −Z.
2. 틀 경계(`PropKit.bounds`)와 겹쳐 보고 충돌 파트 자리를 맞춘다(틀 표시 Attribute도 옮긴다).
3. 모델을 `.rbxm`으로 저장해 `roblox/src/shared/PropModels/<이름>.rbxm`에 둔다(Rojo가 `ReplicatedStorage.Shared.PropModels`로 동기화) → git 커밋.
4. Play: 부팅 로그 `소품 라이브러리 N종(교체 모델 k)`의 k가 늘었는지 확인 · 라이브러리 모델 Attribute `PropSource = "custom"`.
5. 교체 모델이 발자국을 바꿨다면(더 크거나 모양이 다름) 틀(`PropData`)도 같이 고치고 검증 M1-4(가)(빈 공간 · 보호 부피 침범 · 필수 길)를 다시 돌린다.

### 1-4. 옮기지 못한 것(파트 그대로) - 이유

| 대상 | 파일 | 이유 |
|---|---|---|
| 둥지 오르기 발판 · 바위 · 사당 · 탑 · 절벽 굴 · 숨은 방 | `WorldStructureKits` | 크기가 이동 기준표(오름 · 간격)에서 계산된다 - 틀 하나로 못 묶는다. A1에서 "밟는 판 = 파트 유지 + 겉모습만 덮는 장식 소품"으로 |
| 나무 점프맵 요소 · 정거장 · 줄기 · 뿌리 · 잎 | `WorldMapLayout.buildTree` | 같은 이유(설계 정점 · 발사 허가) + 계절 칠하기(`SeasonRole`) |
| 허브 건물 · 시설 · 등불 · 봉인 입구 소품 | `WorldMapLayout.buildHub` · `buildSealed` | 한 번씩만 쓰는 모양(재사용 없음) - A1 허브 단계에서 |
| 보스 관문 공통 틀 | `shared/BossGateKit` | 발판 · 프롬프트 · 문양 · 빛기둥 Attribute가 서버 · 클라 판정과 묶여 있다. 장식만 `Gate_*` 소품 |
| 흔들다리 · 수중 신전 · 천둥 신전 · 계곡 기슭 계단 | `WorldStructures` | 크기 = 데이터 계산 · 흔들림(클라) · 보호 부피 |
| 피라미드 · 옛 M1 지형(탑 · 굴 · 폭포 · 기둥) | `WorldMapLayout.buildFeature` · `buildLandmark` | 그레이박스(M1-3 알려진 것) - 옛 지형은 A1에서 지형 · 소품으로 다시 |

## 2. 지형 재질 - MaterialVariant 자리

- 로블록스 재질 덮어쓰기(`MaterialService:SetBaseMaterialOverride`)는 **기본 재질 하나당 place 전체**다. 그래서 "구역별 재질"은 구역마다 다른 기본 재질을 쓰는 구조(M1-3 `TerrainGenData.palette`)로 가른다.
- 이름 규칙: `Terrain_<기본 재질>`(예: `Terrain_Slate`). MaterialService 아래(폴더 깊이 무관)에 그 이름 · 같은 `BaseMaterial`의 MaterialVariant를 넣으면 서버 부팅 때 덮어쓰기를 켠다(`TerrainBake.applyVariants` · 로그 `지형 재질 변형 자리 N · 켠 것 k`). 지금은 없다(기본 재질).
- 소품 · 구조물 파트도 같은 기본 재질을 쓰면 같이 바뀐다(예: 폐허 `Limestone`).

| 기본 재질 | 쓰는 곳 | 여러 구역 공유 |
|---|---|---|
| Grass | T1 바닥 · T3 바닥2 · 허브 | T1 · T3 · 허브 |
| LeafyGrass | T1 바닥2 · T3 바닥 · 선인장 · 잎 | T1 · T3 · T4(선인장) |
| Rock | T1 · T3 비탈 · 절벽 · 모든 구역 급경사 | 공통 |
| Mud | T1 · T3 물 바닥 | T1 · T3 |
| Limestone | T1 대지 · 폐허 | T1 |
| Slate · Pavement | T2 바닥 | T2 |
| Basalt | T2 비탈 · 절벽 · T5 바닥2 | T2 · T5 |
| Sand · Sandstone | T4 | T4 |
| Ground · Cobblestone | T5 | T5 |
| Snow | T6 바닥 · 모든 구역 눈선 위 | 공통 |
| Ice · Glacier | T6 | T6 |

- 공유 재질을 구역마다 다르게 하고 싶으면 A1에서 그 구역 palette의 기본 재질을 안 쓰는 다른 재질로 바꾼다(예: T3 바닥 `LeafyGrass` → `Ground`) → 해당 구역 `TerrainGenData.version`을 올리고 다시 굽기.

## 3. 폴더 구조(런타임)

```
ReplicatedStorage
├─ Shared                 (Rojo - 코드 · 데이터)
│  └─ PropModels          (Rojo - 교체 모델 .rbxm · 없어도 된다)
└─ Assets                 (서버가 부팅 때 만든다)
   └─ Props
      ├─ T1_RuinPillar    (Model · PropSource = template | custom)
      └─ …
Workspace.Ground.<구조물 모델>.<소품 Model(Attribute Prop = 이름)>
MaterialService.<Terrain_<재질>>  (A1에서 넣는다)
```

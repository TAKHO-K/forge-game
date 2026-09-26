# 카툰 파이프라인 (A1 · 2026-09-27)

> 카툰 스타일을 **데이터 한 곳 + 적용기 하나**로 켜고 끈다. 새 에셋도 이 규칙으로 들어온다. 기준 = `docs/art/ref/art-spec.md` + `style-bible.md` v2. 결과 · 근거 = `docs/phase/A1-report.md`.

## 1. 구성

| 파일 | 역할 |
|---|---|
| `shared/data/CartoonStyleData.lua` | 프로필(`base` = 지금 place 값 · `cartoon` = A1 후보) · 관리 속성 목록(`managed`) · 구역 팔레트 · 구역 색조 · 외곽선 풀 · VFX 예산 · 등급 표현 · 거리별 성능 수치. **색 · 수치는 여기만** |
| `shared/CartoonStyle.lua` | 서버 적용기 `apply(프로필)` · 검증용 `snapshotManaged` · `expected` · `snapshotUnmanaged` · `diff` |
| `shared/CartoonFlatVariants.model.json` | 텍스처 없는 MaterialVariant 17개(재질마다 `CartoonFlat_<재질>`) - Rojo 플러그인이 `BaseMaterial`을 쓴다 |
| `client/OutlinePool.lua` · `client/CartoonClient.client.lua` | 클라 외곽선 풀(조준 외곽선 포함) · 구역 색조 |
| `server/HuntingGround.server.lua` | 부팅 때 `CartoonStyleData.active` 적용(지금 `"base"`) |
| DevTools | `/gg style base \| cartoon`(즉시 전환 · A/B) · `/gg a1 build \| pose \| curl \| squash \| grass \| clear`(A1 시제품) |
| 검증 | `A1(나)`(`server/A1Verify`) - 멱등 · base 복귀 · 관리 밖 변화 0 · 몬스터별 Highlight 0 |

- 기본 프로필을 바꾸려면 `CartoonStyleData.active = "cartoon"` 한 줄(A1 승인 뒤).

## 2. `CartoonStyle.apply(프로필)` - 관리 속성 목록

`apply`는 아래 속성**만** 바꾼다. 여기 없는 속성(시간 · 안개 · 하늘 · 피사계 심도 · 관리 밖 재질 덮어쓰기 · 소품 색 · 재질 · 지형 복셀 …)은 절대 건드리지 않는다(검증 = `snapshotUnmanaged` 차이 0). 두 번 불러도 결과가 같다(멱등).

| 분류 | 대상 | 속성 |
|---|---|---|
| 조명 | `Lighting` | Ambient · OutdoorAmbient · Brightness · ExposureCompensation · EnvironmentDiffuseScale · EnvironmentSpecularScale · ShadowSoftness · ColorShift_Top · ColorShift_Bottom |
| 효과 | `Lighting` 자식(이름 · 클래스로 찾음) | Atmosphere(Density · Offset · Color · Decay · Glare · Haze) · Bloom(Enabled · Intensity · Size · Threshold) · SunRays(Enabled · Intensity · Spread) · `CartoonColorCorrection`(없으면 만든다 · Enabled · Brightness · Contrast · Saturation · TintColor) |
| 물 | `Terrain` | WaterColor · WaterTransparency · WaterReflectance · WaterWaveSize |
| 재질 색 | `Terrain:SetMaterialColor` | 17재질(Grass · LeafyGrass · Rock · Mud · Limestone · Slate · Pavement · Basalt · Sand · Sandstone · Ground · Cobblestone · Snow · Ice · Glacier · Salt · Asphalt) - base = `TerrainGenData.materialColors`(단일 출처) |
| 재질 덮어쓰기 | `MaterialService` | 위 17재질의 BaseMaterialOverride - cartoon = `CartoonFlat_<재질>`(폴더 `MaterialService.CartoonStyle` - 없으면 `Shared.CartoonFlatVariants`를 복제해 옮김) · base = `Terrain_<재질>` 변형이 있으면 그것(TerrainBake 자리) · 없으면 `""` |
| 맵 파트 색 | `Workspace.Ground.Hub` 안 이름 | HubFloor · PortalPlaza · DistrictFloor 의 Color - base = `WorldMapData.colors`(safe · blockLight · road) |
| 소품 그림자 | Attribute `Prop`이 있는 모델의 BasePart | CastShadow(가장 긴 변 ≤ `props.smallMaxSize`면 cartoon에서 끔 · 원래 값 = Attribute `CSBaseCastShadow`에 한 번 적어 둠) |
| 표시 | `Workspace` Attribute | `CartoonStyle` = 지금 프로필(클라 외곽선 · 색조가 읽는다) |

## 3. 알아 둘 제약(A1 실측)

1. **텍스처 없는 MaterialVariant = 평면 로우폴리 면 음영**이 되고 `MaterialColors` 색이 그대로 먹는다(텍스처 0장 · 메모리 거의 0). 카툰 지형의 핵심 방법.
2. **게임 스크립트는 `MaterialVariant.BaseMaterial`을 쓸 수 없다**(Plugin 권한). 변형은 Rojo 모델 파일(플러그인이 씀)이나 place에 미리 있어야 한다 → `CartoonFlatVariants.model.json`. 새 재질을 추가하면 이 파일에 한 줄(Enum 값은 Studio에서 `Enum.Material.X.Value`로 확인 - 추측 금지).
3. `MaterialColors` · 덮어쓰기는 **재질마다 place 전체**다. 구역마다 다른 색 = 구역마다 다른 재질(평면 변형에선 재질 이름이 겉모습과 무관 → 남는 재질 Brick · Concrete · CrackedLava · WoodPlanks로 가를 수 있다 - 다시 굽기 + place 저장).
4. `Terrain.Decoration`(실사 잔디)은 스크립트 · 플러그인 모두 읽기 · 쓰기 불가 - Studio 속성 창에서만.
5. `Lighting.Technology`는 스크립트가 못 읽는다. 이 place = 통합 조명(`LightingStyle` Soft · `PrioritizeLightingQuality` 켬 · 파일 원래 기술 = ShadowMap(3)).
6. Highlight는 `Enabled = false`여도 동시 255 슬롯을 차지한다(사용자 전제) → 대상마다 미리 붙이지 않는다(§4).
7. `Motor6D.Transform`(애니메이션 채널)은 복제되지 않는다 - 서버에서 자세를 걸면 서버 물리만 바뀐다. 모션은 클라(Animator · 절차 모션)에서.

## 4. 외곽선 풀(`OutlinePool`)

- 후보 = 플레이어 캐릭터 · 태그 `Monster`(보스 = Attribute `BossName` · `ArenaObstacle` 제외) · 태그 `OutlineTarget`(관문 · NPC · 둥지 - 붙이는 쪽이 태그만 단다).
- 우선순위 → 거리 순으로 상위 `outline.maxActive`(80)개에만 풀의 Highlight를 옮겨 단다(Adornee 교체). 남는 것은 `spare`(4)개만 두고 지운다(슬롯 반환). 대상당 1개.
- 조준 외곽선 = 같은 풀의 우선순위 0(색만 조준색 · 강공격 준비 색) - `AimTarget`이 `OutlinePool.setAim`을 부른다. 몬스터 · 상자 · 아레나 장애물에 꺼진 `AimHighlight`를 붙이지 않는다.
- base 프로필 = 조준 외곽선만(옛 동작과 같다) · cartoon = 어두운 외곽선(`#1E1B2E`)도.
- 슬롯 예산: 풀 80 + 무기 강화 외곽선(사람당 1 · ≤ 20) + 보스 아레나 외곽선 2 = 최대 약 102(255의 40%).

## 5. 새 에셋 추가 절차

1. **색**: 에셋 색은 `CartoonStyleData.palette[구역]`(기본 · 강조 · 그늘)에서 고른다. 위험색(장판 주황빨강) · 등급 색은 환경에 쓰지 않는다(style-bible §4-1).
2. **재질**: 지형과 이어져야 하는 파트 = 지형 재질 이름(17재질) - cartoon에서 자동으로 평면이 된다. 그 밖 = SmoothPlastic(질감 없음).
3. **3톤**: 파트는 조명으로(스펙큘러 0 · 환경광 높음 - cartoon 조명이 윗면 밝게 · 옆면 기본 · 그늘 어둡게를 만든다). 메시는 색 3개(기본 · ×1.18 · ×0.72)만.
4. **외곽선**: 캐릭터 · 몬스터 · 보스 · 상호작용 대상만 - 모델에 태그(`Monster` 또는 `OutlineTarget`)만 단다. Highlight를 직접 만들지 않는다.
5. **소품**: 라이브러리 틀(`PropData`) 이름 규칙 · 교체 모델 절차 = `asset-pipeline.md` §1. 가장 긴 변 ≤ 6이면 cartoon에서 그림자가 꺼진다(자동).
6. **몬스터 · 보스 리그**: 파트 + Motor6D(관절 이름 = art-spec 3 · 4장) · 긴 특수 부위(꼬리 · 촉수)는 Bone 체인 + 부착점(Attachment). A1 보고서 리그 게이트 표.
7. **확인**: `/gg style cartoon` ↔ `base`로 같은 자리 비교 · `A1(나)` 검증 · 렌더 통계(`Stats.SceneDrawcallCount` · `SceneTriangleCount`).

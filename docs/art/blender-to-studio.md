# Blender → Studio 교체 절차 (B3 · 2026-09-30)

> 리그 규격(`MonsterRigSpec` · `BossRigSpec`)에 맞춘 카툰 메시를 Blender에서 만들어 Studio로 가져오고, 검사기로 O/X를 본 뒤 리그 파트 자리에 1:1로 끼워 미리 보는 절차.
> 기준 = `docs/art/ref/art-spec.md`(3 · 4장 관절 · 1-2 3톤) · `style-bible.md` §0-2 · §12(삼각형 예산) · `cartoon-pipeline.md` §5 · `asset-pipeline.md` §1(교체 모델 자리 방식) · `docs/design/monster-body-draft.md`(카툰 교체 방법).
> **Blender 쪽 스크립트 · FBX 설정 · 3D Importer 동작은 미실행 · 미검증**이다(작성 환경에 Blender · Studio 없음). 검사기 순수 부분은 로컬 하네스로 확인했다(§9).

## 1. 구성

| 파일 | 역할 |
|---|---|
| `roblox/tools/blender/rig_dump.py` · `rig_dump.luau` | 리그 규격 → JSON(`roblox/tools/blender/rigs/<리그 id>.rig.json`) - 검사기와 같은 FK(`MeshImportCheck.expected`) · 스폰과 같은 색(`BossRigSpec.colorOf`). luau CLI만 필요 |
| `roblox/tools/blender/make_rig_mesh.py` | Blender 템플릿: JSON → 파트 오브젝트(이름 · 원점 = 관절) · 팔레트 재질 · `TriCount` 커스텀 속성 · 메타 Luau · FBX 내보내기 |
| `roblox/tools/blender/README.md` | 스크립트 사용 설명 · 첫 실행 확인 목록 |
| `roblox/src/shared/data/MeshImportCheckData.lua` | 검사 · 교체 수치(허용 오차 · 예산 · 비율 · 허용 재질 · 폴더 이름). **수치는 여기만** |
| `roblox/src/shared/MeshImportCheck.lua` | 검사기(순수 `check` + Studio용 `describe`) · 기준 자세 FK(`expected`) |
| `roblox/src/shared/MeshSwap.lua` | 교체 도우미(같은 이름 리그 파트에 1:1로 끼우고 관절 다시 걸기) |
| `roblox/src/server/MeshImportDev.lua` | `/gg mesh` 명령 본체(DevTools의 분기 한 줄이 부른다 - 개발자 판정 = DevTools `isAllowed` · Studio 전용) |
| `roblox/tools/harness/mesh_import_test.luau` | 로컬 하네스(가짜 모델 기술자로 항목별 O/X) |

## 2. 폴더 · 이름 규칙

기존 규칙(`asset-pipeline.md` §1 소품 `PropModels/<이름>` · §4-2 무기 `WeaponModels/<직업>`)과 같은 모양으로 정했다.

| 무엇 | 이름 · 자리 |
|---|---|
| 리그 id | 규격 표의 키 그대로 - 잡몹 = 종 id(`moss_slime` · `rock_boar` … = `MonsterSpeciesData` 키) · 보스 = 보스 id(`section_guardian` · `scorpion_queen` …) |
| 파트(오브젝트) 이름 | 규격 관절의 `part` 이름 그대로(`Body` · `Head` · `Eye_L` · `Tail1` …) - 대소문자 · 밑줄까지 같게. 관절(Motor6D) 이름은 스크립트가 알아서 둔다(`Body` = `RootJoint` · `Head` = `Neck` · 나머지 = 파트 이름) |
| 기준 루트 | `HumanoidRootPart`(원점의 작은 상자 - 가져온 모델의 기준 프레임. 검사 · 교체에서 리그 파트로 세지 않는다) |
| Blender 원본 · FBX | `roblox/art/rigs/<리그 id>.blend` · `roblox/art/rigs/<리그 id>.fbx`(Rojo 동기화 밖 - git에 원본 보관) |
| 리그 JSON | `roblox/tools/blender/rigs/<리그 id>.rig.json`(생성물 - 규격이 바뀌면 `rig_dump.py`로 다시) |
| 삼각형 메타 | `roblox/src/shared/MeshMeta/<리그 id>.lua`(생성물 - Rojo → `ReplicatedStorage.Shared.MeshMeta.<리그 id>`) |
| Studio 모델 이름 | `<리그 id>`(FBX 파일 이름이 그대로 모델 이름이 된다) |
| 교체 모델 자리(예약) | 잡몹 `roblox/src/shared/MonsterModels/<리그 id>.rbxm` · 보스 `roblox/src/shared/BossModels/<리그 id>.rbxm`(Rojo → `ReplicatedStorage.Shared.MonsterModels` · `BossModels`). 지금은 `/gg mesh`가 경로 생략 때 찾는 곳이고, 스폰 연결은 §8 |
| 재질 이름(Blender) | `<리그 id>_<파트>`(예: `moss_slime_Body`) |

## 3. Blender 스크립트 실행

1. 리그 JSON이 없거나 규격이 바뀌었으면 만든다(Blender 불필요):
   `LUAU=<luau.exe> python roblox/tools/blender/rig_dump.py moss_slime` → `rigs/moss_slime.rig.json`(이끼 슬라임은 저장소에 들어 있다).
2. 새로 만들기(파트 도형 + 재질 + 메타 + FBX + `.blend` 저장):
   `blender --background --python roblox/tools/blender/make_rig_mesh.py -- --rig roblox/tools/blender/rigs/moss_slime.rig.json`
3. Blender에서 `roblox/art/rigs/moss_slime.blend`를 열고 **Edit 모드에서만** 모양을 다듬는다. 오브젝트 이름 · 원점(피벗) · 오브젝트 회전 · 배율은 건드리지 않는다(원점 = 관절 자리가 약속). 색을 바꾸려면 재질 색을 `CartoonStyleData.palette` · 종 색 · 3톤(×1.18 · ×0.72) 안에서만.
4. 다듬은 뒤 다시 내보내기(도형은 그대로 · 삼각형 수 · 메타 · FBX만 새로):
   `blender roblox/art/rigs/moss_slime.blend --background --python roblox/tools/blender/make_rig_mesh.py -- --rig roblox/tools/blender/rigs/moss_slime.rig.json --export-only`
5. 콘솔 `[make_rig_mesh] … 삼각형 합 N(예산 1500)`을 본다. 예산을 넘으면 경고 줄이 나온다(검사 ③-2 X).

만드는 도형(시작점): 공 = 아이코스피어 2단계(80삼각형) · 상자 = 모서리 1단 깎은 상자(44삼각형) · 쐐기 = Roblox WedgePart 모양. 이끼 슬라임 4파트 = 80 + 44 × 3 = 212삼각형(예산 1,500).

## 4. FBX 내보내기 설정(스크립트가 그대로 쓴다)

| 설정 | 값 | 이유 |
|---|---|---|
| 선택만 · 종류 | `use_selection` · `MESH`만 | 리그 파트 + 기준 루트만 나간다(카메라 · 빛 제외) |
| 축 | `axis_forward = -Z` · `axis_up = Y` | Roblox = +Y 위 · −Z 앞. 스크립트가 Blender(x, y, z) = Roblox(X, −Z, Y)로 놓았으므로 모델 앞은 Blender +Y 쪽이다 |
| 변환 적용 | `bake_space_transform = True`(Apply Transform) | 축 바꾸기를 메시에 구워 가져온 파트의 회전이 0이 되게 |
| 배율 | `global_scale 1.0` · `apply_unit_scale True` · `FBX_SCALE_NONE` | 1 Blender 단위 = 1 stud 의도. Studio 쪽 단위는 §5-3 |
| 법선 | `mesh_smooth_type = FACE` · 면 `use_smooth = False` | 평면 음영(카툰 3톤은 조명이 만든다) |
| 커스텀 속성 | `use_custom_props = True` | 오브젝트 `TriCount` → 가져오기가 Attribute로 옮겨 주면 그걸 먼저 읽는다(미검증) |
| 뼈 · 애니메이션 · 텍스처 | 잎 뼈 없음 · 애니메이션 굽기 없음 · 텍스처 안 넣음 | 관절은 Studio에서 Motor6D(교체 도우미)가 맡는다 · 텍스처 0장 규칙 |

**삼각형 수를 어떻게 받나(결정)**: Studio 게임 스크립트는 MeshPart의 삼각형 수를 읽을 속성이 없다(`EditableMesh`로 읽으려면 에셋 권한 · 메모리 비용이 들고 업로드 전 메시에는 쓸 수 없다). 그래서 **Blender가 센 값**을 두 길로 넘긴다: ① 오브젝트 커스텀 속성 `TriCount`(3D Importer가 Attribute로 옮겨 주면 파트 Attribute `TriCount`) ② 메타 Luau(`Shared.MeshMeta.<모델 이름>` - Rojo로 확실히 들어온다). 검사기는 ① → ② 순서로 읽고, 둘 다 없으면 ③-1 X(모름을 통과로 치지 않는다). Studio에서 메시를 바꿨으면 파트에 Attribute `TriCount`를 손으로 적는다.

## 5. Studio 가져오기(3D Importer)

1. Rojo가 켜져 있는지 확인(메타 `Shared.MeshMeta.<리그 id>`가 Studio에 들어와 있어야 ③이 통과).
2. Studio → 홈(또는 파일) → **Import 3D** → `roblox/art/rigs/<리그 id>.fbx`.
3. 가져오기 설정: 단위(Scale Unit / File Dimensions) = **Stud** · "Anchored" 켬(가져온 원본이 떨어지지 않게) · 리그 · 스킨 관련 옵션 끔(뼈 없음) · "Import Only As Model" 켬 · 텍스처 · SurfaceAppearance 만들기 끔.
4. 결과: `Workspace.<리그 id>` Model 안에 MeshPart `HumanoidRootPart` · `Body` · `Head` …(이름 = Blender 오브젝트 이름).
5. 저장해 두려면 그 Model을 `.rbxm`으로 내보내 §2의 교체 모델 자리에 둔다(Rojo가 동기화) → git 커밋.

## 6. 검사기 실행

Play(수동 Play - 검증 켜지 않아도 된다) 중 채팅:

```
/gg mesh check moss_slime Workspace.moss_slime
/gg mesh check moss_slime                      (경로 생략 = Shared.MonsterModels.moss_slime → Workspace.moss_slime 순서)
```

- 출력 창에 항목마다 `[MeshCheck] <번호> <항목> - <자세히> O/X` 줄 + `[MeshCheck] 결과 n/14 통과`. 자주 나오는 원인은 `[MeshCheck] 힌트:` 줄로 따로 찍힌다.
- 가져온 모델은 Edit 모드에서 Workspace에 넣어 두면 Play 때 복제되어 같은 경로로 찾는다.

## 7. 교체 명령

```
/gg mesh swap moss_slime Workspace.moss_slime [배율]
/gg mesh clear
```

- 내 앞 12 stud(`MeshImportCheckData.swap.previewDistance`)에 기준 자세 리그(`BossRig.build` - 스폰과 같은 조립)를 `Workspace.MeshPreview.<리그 id>`로 세우고, 가져온 모델의 같은 이름 메시를 1:1로 끼운다. 검사 결과도 같이 찍는다(X여도 미리보기는 만든다).
- 끼우는 방식(`shared/MeshSwap`): 가져온 파트의 자리 = 기준 루트 기준 자리 그대로(× 배율) → 옛 파트의 Motor6D · 부착점(`Rig_*`)을 새 메시로 옮기고 **관절 C0 · C1은 규격 관절 프레임으로 다시 계산**(메시 피벗이 가져오기에서 어긋나도 관절은 규격 자리에서 돈다) → 물리 속성(충돌 · 터치 끔 · 조준 쿼리 = 옛 파트 그대로 · Massless) · 색(= 리그 색 역할 · `swap.recolor`)을 옮긴다.
- 가져온 모델에 없는 파트는 옛 도형 파트를 그대로 둔다(반쯤 만든 모델도 미리보기 가능). 결과 줄 `[MeshSwap] … 끼움 k/n · 관절 다시 걸기 m`.
- 모션 확인은 기존 전시 명령(`/gg boss anim` 등)이 자기 리그를 새로 짓기 때문에 이 미리보기에는 안 걸린다 - 지금은 정지 자세 확인까지다.

## 8. 실패 시 대처

| 증상 | 원인 | 대처 |
|---|---|---|
| ①-1 빠짐 · ①-2 남음 | 오브젝트 이름이 규격과 다름(`Body.001` · 대소문자) · 파트를 합치거나 나눔 | Blender 오브젝트 이름을 규격 `part` 이름으로. 한 파트 = 오브젝트 1개(합치기 금지 - 관절마다 따로 움직인다) |
| ①-0 X | 기준 루트를 지웠거나 FBX 선택에서 빠짐 | 스크립트를 `--export-only`로 다시(루트가 없으면 새로 만든다) |
| ② 전부 X · 좌우(`_L` · `_R`)가 서로 바뀐 자리 | 축 설정 · 거울 | FBX 축 = §4 그대로 · Blender에서 오브젝트를 뒤집지 않았는지(배율 −1) |
| ② X + 힌트 "피벗을 옮겼다" | 3D Importer가 파트 피벗을 경계 가운데로 둠(Blender 원점이 안 옮겨짐) | 그 파트에 Attachment `Joint`를 관절 자리에 넣는다(검사기가 피벗보다 먼저 읽는다) 또는 Studio 피벗 편집으로 관절 자리에. 교체는 규격 관절로 다시 거니 동작에는 영향 없음 - 규칙 확인용 |
| ② 일부만 X | Blender에서 원점을 옮김(Set Origin) · 오브젝트를 옮김 | 원점 · 위치를 되돌리거나 스크립트를 새로 만들기로 다시 돌려 모양만 옮겨 온다 |
| ③-1 X | Attribute · 메타 둘 다 없음 | Rojo 동기화 확인(`Shared.MeshMeta.<리그 id>`) · 모델 이름 = 메타 파일 이름인지 · 아니면 파트 Attribute `TriCount` 손으로 |
| ③-2 X | 예산 초과(몬스터 1,500 · 보스 6,000) | Decimate(평면 음영이라 줄여도 티가 덜 난다) · 공 = 아이코스피어 1단계 |
| ④-1 X + 힌트 "단위" | 단위 배율(×100 · ×0.01 · ×3.57 · ×0.28) | 가져오기 단위 = Stud · Blender 장면 단위 배율 1.0 |
| ④-1 X(힌트 없음) | 모양이 규격보다 많이 크거나 작음 | 규격 크기 ±20%(0.8 ~ 1.25) 안으로. 크게 바꿔야 하면 규격 · 판정 상자부터 바꾸는 결정 필요(아트만으로 바꾸지 않는다) |
| ④-2 X | 잡몹: 겉모습이 판정 상자(`Hitbox`)에서 벗어남 · 보스: 조준 파트(`Body` · `Head`) 크기가 ±20% 밖 | 보이는 곳 = 맞는 곳이 되게 모양을 옮긴다 |
| ④-3 X | 파트 하나가 규격의 ½ 미만 · 2배 초과 | 그 파트 크기 조정(가는 부위 최소 두께 0.4 - art-spec 1-5) |
| ⑤ X | 팔레트 밖 색 · 가져오기가 색을 안 옮김(전부 회색 `#A3A2A5`) | 재질 색을 팔레트 · 종 색 · 3톤으로. 회색이면 가져오기 설정 확인 - 교체 명령은 리그 색으로 다시 칠하므로 미리보기는 정상 |
| ⑥-1 X | MeshPart가 아님(Part · UnionOperation) | FBX로 다시 가져오기 |
| ⑥-2 · ⑥-3 X | 투명 · 재질(Neon 등 - 규격이 정한 파트만 예외) | Transparency 0 · SmoothPlastic |
| ⑥-4 X | 텍스처 · SurfaceAppearance · Decal | 가져오기에서 텍스처 끔 · 생긴 것은 지운다(텍스처 0장 규칙) |
| `모델 없음` | 경로 오타 · Edit에서 넣은 모델이 Play에 없음 | 경로는 점으로(`Workspace.moss_slime`) · 모델 이름 = 리그 id |

**스폰 연결(다음 단계 - 이번 범위 밖)**: `docs/design/monster-body-draft.md` 3번대로 `shared/BossRig.build`의 파트 만들기 한 곳에서 "`Shared.MonsterModels` · `BossModels`에 같은 이름 모델이 있고 검사 O면 `MeshSwap.swap`"을 부르면 스폰 전체가 바뀐다(판정 = 루트 · `Hitbox` · query 파트라 겉모습만 바뀐다). 모션 · 조준 · 피격 번쩍임 확인 Play가 필요하다.

## 9. 검사 항목 표

| 번호 | 항목 | 통과 기준(수치 = `MeshImportCheckData`) |
|---|---|---|
| ①-0 | 기준 루트 | `HumanoidRootPart` BasePart가 있다(없으면 모델 피벗 기준으로 잰다 - X) |
| ①-1 | 빠진 리그 파트 없음 | 규격 파트 이름이 전부 있다 |
| ①-2 | 남는 · 중복 파트 없음 | 규격에 없는 이름 · 같은 이름 두 개가 없다(`HumanoidRootPart` · `Hitbox`는 셈에서 뺌) |
| ② | 관절 자리 | 측정 관절(Attachment `Joint` → 없으면 파트 피벗)과 규격 기준 자세 관절의 거리 ≤ 0.15 stud × 배율 |
| ③-1 | 삼각형 수 알려짐 | 파트 Attribute `TriCount` 또는 메타 `parts[이름].tris` |
| ③-2 | 삼각형 합 | 몬스터 ≤ 1,500 · 보스 ≤ 6,000(style-bible §12 제안값 · 무기 800 · 소품 1,500은 표에만) |
| ④-1 | 전체 크기 | 가져온 전체 경계 ÷ 규격 전체 경계 = 축마다 0.8 ~ 1.25 |
| ④-2 | 판정 | 잡몹: 겉모습 경계 중 판정 상자와 겹치는 비율 ≥ 규격 모양의 비율 − 0.15(판정 상자 = 종 `hitbox` · 없으면 2.4 × 4.6 × 1.6 @ y 0.8) · 보스: 규격 `query` 파트 크기 ÷ 규격 = 축마다 0.8 ~ 1.25 |
| ④-3 | 파트 크기 | 파트 가장 긴 변 ÷ 규격 파트 가장 긴 변 = 0.5 ~ 2.0 |
| ⑤ | 팔레트 | 색이 허용 색(구역 팔레트 `CartoonStyleData.palette` - 종 티어 · 보스 구역 · 외곽선색 · 리그 색 역할 6가지) × 3톤(1 · 1.18 · 0.72) 중 하나와 채널마다 ≤ 6 |
| ⑥-1 | 클래스 | MeshPart |
| ⑥-2 | 투명 | Transparency ≤ 0 |
| ⑥-3 | 재질 | SmoothPlastic(규격 관절에 `material`이 적힌 파트는 그 재질도) |
| ⑥-4 | 텍스처 없음 | `TextureID` 빈 값 · 자식 SurfaceAppearance · Decal · Texture 없음 |

무기는 기존 `WeaponRigCheck`(부팅 때 · `asset-pipeline.md` §4-2)이 맡는다 - 이 검사기는 몬스터 · 보스 리그만.

로컬 하네스(Studio 없이 - `roblox/tools/harness`에서):
`LUAU=<luau.exe> PRELUDE=server_prelude.luau ECON_RES=res_mesh.txt python build_run.py mesh_import_test.luau` → `%TEMP%/res_mesh.txt` 끝 줄 `[MESH] 결과 n/n 통과`(2026-09-30 = 34/34).

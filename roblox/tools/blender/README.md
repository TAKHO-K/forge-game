# Blender 도구 (B3) - **미실행 · 미검증**

> 작성 환경에 Blender가 없어 `make_rig_mesh.py`는 한 번도 돌리지 않았다. 순수 좌표 계산(Roblox ↔ Blender 축 · 기준 자세 회전)만 Blender 밖에서 같은 식으로 흉내 내 규격 경계와 대조했다(이끼 슬라임 · 모래 전갈 · 푸른 드래곤 · 구간 수호자 - 어긋남 0). 전체 절차 = `docs/art/blender-to-studio.md`.

## 파일

| 파일 | 역할 |
|---|---|
| `rig_dump.py` · `rig_dump.luau` | 리그 규격(`MonsterRigSpec` · `BossRigSpec`) → `rigs/<리그 id>.rig.json`. luau CLI만 필요(`../harness/build_run.py`를 그대로 씀) |
| `rigs/moss_slime.rig.json` | 이끼 슬라임(T1 · 4파트) 예시 입력 - 생성물(손으로 고치지 않는다) |
| `make_rig_mesh.py` | Blender 템플릿: 파트 오브젝트(이름 = 리그 파트 · 원점 = 관절) · 팔레트 재질 · `TriCount` 커스텀 속성 · 메타 Luau(`roblox/src/shared/MeshMeta/<리그 id>.lua`) · FBX(`roblox/art/rigs/<리그 id>.fbx`) |

## 사용

```
# 1) 리그 JSON(규격이 바뀌었을 때만)
LUAU=<luau.exe 경로> python rig_dump.py moss_slime

# 2) 새로 만들기 → roblox/art/rigs/moss_slime.blend · .fbx + roblox/src/shared/MeshMeta/moss_slime.lua
blender --background --python make_rig_mesh.py -- --rig rigs/moss_slime.rig.json

# 3) Blender에서 .blend를 열어 Edit 모드로만 다듬은 뒤 다시 내보내기(도형 유지)
blender ../../art/rigs/moss_slime.blend --background --python make_rig_mesh.py -- --rig rigs/moss_slime.rig.json --export-only
```

- 인자: `--rig <json>` · `--fbx-dir <폴더>`(기본 `roblox/art/rigs`) · `--meta-dir <폴더>`(기본 `roblox/src/shared/MeshMeta`) · `--export-only`.
- Blender 안에서 돌릴 때는 Scripting 탭에서 이 파일을 열고 맨 위 `CONFIG["rig"]`를 고친 뒤 Run Script.
- 지키는 것: 오브젝트 이름 · 원점 · 오브젝트 회전 · 배율은 그대로(모양은 Edit 모드에서만). 한 파트 = 오브젝트 1개. 색은 재질 색으로만(텍스처 금지).

## 첫 실행 확인 목록(미검증 항목)

1. Blender 버전(3.6 · 4.x)에서 `bmesh.ops.create_icosphere(radius=)` · `bmesh.ops.bevel(affect=)` · Principled 입력 이름(`Specular IOR Level` / `Specular`)이 맞는가 - 틀리면 콘솔 오류 줄.
2. 이끼 슬라임 결과가 앞(Blender +Y)을 보고 눈(`Eye_L` · `Eye_R`)이 앞쪽 아래에 있는가 · 콘솔 `삼각형 합 212(예산 1500)`.
3. FBX를 Studio 3D Importer(단위 Stud)로 가져와 `/gg mesh check moss_slime Workspace.moss_slime`이 14/14인가. 특히 ②(피벗이 Blender 원점으로 남는가) · ③-1(커스텀 속성이 Attribute로 오는가 - 안 와도 메타로 통과) · ④-1(단위) · ⑤(재질 색이 MeshPart.Color로 오는가).
4. 결과가 다르면 `docs/art/blender-to-studio.md` §8 표로 원인을 가르고, 설정을 고쳤으면 이 목록과 문서 §4를 실측값으로 갱신한다.

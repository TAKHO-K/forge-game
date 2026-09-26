# 스트리밍 설정 - 현재 place 값 / 의도 값 (M1-2 · 2026-09-26)

## 1. 원인: `default.project.json`의 Workspace 스트리밍 속성이 place에 안 들어간 이유

| 확인 | 결과 |
|---|---|
| Studio Edit에서 Lua로 읽기 · 쓰기(`execute_luau`) | `StreamingEnabled`만 읽힌다(`true`). `StreamingMinRadius` · `StreamingTargetRadius` · `StreamingIntegrityMode` · `StreamOutBehavior`는 **"is not a valid member of Workspace"** - 스크립트 접근 불가(NotScriptable) 속성이다 |
| Rojo 7.7.0 `rojo serve`(실시간 동기화) | Rojo Studio 플러그인은 속성을 **Lua로** 쓴다 → NotScriptable 속성은 실시간 동기화로 **쓸 수 없다**(조용히 건너뜀). 그래서 place가 로블록스 기본값(최소 64 · 목표 1,024)으로 남았다 |
| `rojo build`(파일로 굽기) | 결과 `.rbxlx`에 `StreamingMinRadius 128` · `StreamingTargetRadius 1024` · `StreamOutBehavior 2`(Opportunistic) · `StreamingEnabled true`가 **들어간다**(M1-2에서 실측) - 파일로 구운 place를 열면 적용된다 |
| MCP `inspect_instance Workspace` | 속성 목록이 비어 나온다 - MCP로도 못 읽는다 |
| 런타임(서버 · 클라 스크립트) | 같은 이유로 못 읽는다 → "시작할 때 값을 확인하고 다르면 경고"는 **불가능**. 읽을 수 있는 `StreamingEnabled`만 M1-2(가)가 확인한다 |

- 결론: 이 프로젝트는 `rojo serve`로 기존 place에 코드를 넣는 방식이라 **스트리밍 값은 place에만 있는 설정**이다. `default.project.json`의 `$properties`는 `rojo build` 경로의 기록으로만 남긴다(지우지 않는다 - 나중에 빌드 배포로 바꾸면 그대로 먹는다).
- 대안(바꿀 때마다): Studio 속성창에서 직접 바꾸고 place 저장 → 이 표의 "현재 place 값"을 고친다. 실행 중 변경은 안 된다(스크립트가 못 쓰는 속성).

## 2. 값 표

| 속성 | 현재 place 값 | 의도 값 | 근거 · 비고 |
|---|---|---|---|
| `Workspace.StreamingEnabled` | `true`(Lua로 읽음 · M1-2(가)) | `true` | 맵 반지름 3,000 - 전부 보내면 폰 메모리가 버틴다는 보장이 없다 |
| `Workspace.StreamingMinRadius` | **128**(사용자가 64 → 128로 바꾸고 저장 · 2026-09-26) | 128 | 발밑 반경 - 순간이동 뒤 `RequestStreamAroundAsync`(3초 상한)와 같이 쓴다 |
| `Workspace.StreamingTargetRadius` | 1,024(사용자 확인 - 로블록스 기본값과 같다) | 1,024 | 구역 원(반경 850) 하나 + 여유. 먼 풍경(나무 · 빛기둥 · 랜드마크)은 Persistent로 따로 보인다 |
| `Workspace.StreamingIntegrityMode` | **확인 필요**(스크립트 · MCP로 못 읽는다 - 속성창) | `MinimumRadiusPause` 추천 | 최소 반경이 안 불러와졌으면 잠깐 멈춘다 - 포탈 · 귀환 뒤 불러오기 전 바닥 관통 방지(지금은 `RequestStreamAroundAsync`로만 막는다). 기본값(`Default`)이면 멈추지 않는다 |
| `Workspace.StreamOutBehavior` | **확인 필요**(속성창) | `Opportunistic` | 목표 반경 밖을 적극적으로 내보낸다(폰 메모리) - `default.project.json`에 적은 값 |
| `Workspace.ModelStreamingBehavior`(있다면) | 확인 필요 | `Default` | 이 프로젝트는 모델별 `ModelStreamingMode`만 쓴다 |

모델별 `ModelStreamingMode`(런타임에 코드가 정한다 - place 설정 아님 · `server/WorldMap.lua modelAt`):

| 모델 | 모드 | 이유 |
|---|---|---|
| `Ground.BigTree`(줄기 · 뿌리 · 잎) | `Persistent` | 어디서나 보이는 랜드마크. **부모에 붙이기 전에** 정해야 먹는다(M1 실측) |
| `Ground.GatePillars`(관문 빛기둥 6) | `Persistent` | 보스 관문 방향 표지 |
| `Ground.Landmark_tier1 ~ 6` | `Persistent` | 구역 실루엣 |
| 그 밖(`TreeCourse` · `Hub` · `Zone_*` · `Floor*` · `Sealed*` · 몬스터 등) | `Default`(파트 단위) | 가까이 가면 들어온다 |

## 3. place에만 있는 설정(Rojo · git에 없다 - 바꾸면 여기와 STATE.md를 같이 고친다)

- Workspace 스트리밍 4종(위 표) · `Workspace.Gravity` 196.2(기본) · `StarterPlayer.CharacterJumpHeight` 7.2(`movement-metrics.md` §0) · 아바타 관절 업그레이드(AnimationConstraint).
- **지형(Terrain 복셀 · 재질 색 · 물 모양)** - M1-3부터. 굽기 절차 · 버전 = 아래 §4.
- Lighting `Atmosphere`는 place에 있지만 밀도는 서버 부팅 때 코드가 덮어쓴다(`WorldMapData.atmosphere` - git 기록).
- 먼 나무 저해상도 대체(imposter) 결과 = `docs/phase/M1-2b-report.md` ②.

## 4. 지형(Terrain) - M1-3 굽기 절차 · 지형 버전 (place 전용)

Rojo는 Terrain 복셀을 동기화하지 않는다(프로젝트 `Workspace`는 `$ignoreUnknownInstances` · 파일 형식에 복셀이 없다 - M1-3 실측: 굽기 전 Studio Terrain 셀 0). 그래서 **생성기(식 + 수치)만 git**에 두고 결과는 place에 굽는다.

| 무엇 | 어디 |
|---|---|
| 모양 식(결정적 - 고정 시드 · 자체 잡음) | `shared/TerrainShape.lua` |
| 수치(능선 · 설산 · 봉우리 · 강 · 바다 · 호수 · 사구 · 굴 · 재질 색 · 버전) | `shared/data/TerrainGenData.lua` |
| 둥지 · 구조물 마스크(받침 · 흙더미 · 보호 부피 - 비밀 둥지 먼저) | `shared/WorldStructures.lua` · `data/NestData.lua` |
| 굽기 | `server/TerrainBake.lua` · edit 실행기 `server/TerrainBakeRun.lua` |

**굽기 절차**(Studio edit 모드 명령줄 - Play 중이 아니다):

1. Rojo 연결 확인(소스가 최신인지).
2. 구역마다 한 줄씩(한 구역 40 ~ 70초): `require(game.ServerScriptService.TerrainBakeRun)("hub")` → `"tier1"` … `"tier6"`. 전부 = `("all")`(5분 넘게 걸려 명령줄이 멈춘 것처럼 보인다 - 구역별 권장).
   - edit 모드의 `require`는 Studio를 닫을 때까지 옛 모듈을 캐시한다 → `TerrainBakeRun`이 부를 때마다 소스를 새로 불러온다(loadstring). `TerrainBake`를 직접 require하면 옛 코드가 돌 수 있다.
3. 확인: `require(game.ServerScriptService.TerrainBakeRun)("check")` - 둥지 입구 → 둥지 캐릭터 캡슐 통과(edit 모드엔 맵 파트가 없어 지형만 본다 - 파트까지는 Play의 `/gg terrain check` · 검증 M1-3T(나)) · 지형 표식.
4. **place 저장**(파일 → 저장 / 게시). 저장하지 않으면 Studio를 닫을 때 지형이 사라진다.

**지형 버전 표식**: 굽기가 `Workspace.Terrain` Attribute를 남긴다 - `TerrainVersion_<구역>`(= `TerrainGenData.version[구역]`) · `TerrainSig_<구역>`(표본 400점 높이 해시 - 버전 숫자를 안 올리고 데이터를 바꾼 경우도 잡는다) · `TerrainBakedAt_<구역>`. 서버 시작 때 `TerrainBake.checkVersion`이 비교해 다르면 **경고 로그만** 남긴다(런타임 생성 금지).
- 모양(데이터 · 식 · 둥지 자리)을 바꾸면: 해당 구역 `version`을 올리고 → 그 구역만 다시 굽기 → 저장.

| 구역 | 지형 버전 | 마지막 굽기 | 비고 |
|---|---|---|---|
| hub · tier1 ~ tier6 | 1 | 2026-09-26(M1-3) | 표면 = 평지 0.6(점유율 → 표면 식 실측: 표면 = 칸 바닥 + 2 + 4 × 점유율) |
| hub · tier1 · tier2 · tier4 · tier5 · tier6 | 2 | 2026-09-26(M1-4) | 커브길 재질 띠 · 외곽 테마 경계 · Basalt 색 · 해안 모래 · 빙벽 재질 |
| tier3 | 3 | 2026-09-26(M1-4) | 곶 좁게(바다가 트이게) |

- 재질 색(Terrain:SetMaterialColor) · 물 색 · 투명도 · 물결도 굽기가 place에 쓴다(`TerrainGenData.materialColors` · `water`).

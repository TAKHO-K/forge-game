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
- Lighting `Atmosphere`는 place에 있지만 밀도는 서버 부팅 때 코드가 덮어쓴다(`WorldMapData.atmosphere` - git 기록).
- 먼 나무 저해상도 대체(imposter) 결과 = `docs/phase/M1-2b-report.md` ②.

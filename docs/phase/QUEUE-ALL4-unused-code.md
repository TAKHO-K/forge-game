# 쓰지 않는 옛 코드 후보 (QUEUE-ALL4 G · 제안만 - 삭제 금지)

> 방법 = `.server/.client` 제외 ModuleScript 전부의 이름 참조 수(`grep -w`, 주석 제외) · *Verify.lua ↔ DevTools.server.lua require 대조 · 데이터 최상위 키 `.key` 참조 검색 + 직접 열어 확인. 지울 때 주의: DevTools 맨 위 `local X = require(...)`가 남으면 서버 시작 때 DevTools 전체가 에러로 멈춘다.

## 1. 어디서도 require되지 않는 모듈
| 경로 | 근거 | 대체한 것 | 지우면 위험 | 확실도 |
|---|---|---|---|---|
| `server/TeleportPad.lua` | 참조 0(주석만 - "포탈 패드는 더 이상 짓지 않는다") | M1 큰 세계(WorldMap · Travel) | 거의 없음 | 높음 |
| `client/A1UiMockups.lua` | 참조 0 · A1 목업 | 실제 UI(ui/kit · panels) | 없음 | 높음 |
| `server/GuideVerify.lua` | 참조 0 · 수동 execute_luau 도구 | 없음 | 길 안내 경로 검사기를 잃음 - **남길 것** | 낮음 |
| `server/TerrainBakeRun.lua` | 참조 0 · Edit 명령줄 도구 | 없음 | 지형 굽기 실행 경로를 잃음 - **남길 것** | 낮음 |

## 2. 스위치가 꺼진 채 대체된 기능 · 목업 · 시제품
| 경로 | 근거 | 대체한 것 | 같이 정리할 곳 | 확실도 |
|---|---|---|---|---|
| `client/panels/Inventory/CodexTab.lua` + `SetData.codex`(enabled = false) | 켜는 길 = `/gg set codex on`뿐 | 도감 v2(`panels/Codex.lua` · `CodexV2/*`) | InventoryUI 35 · 60 ~ 62줄 · Shell 412 · 485 · 539 ~ 544줄 · DevTools `/gg set codex` · TextData `codex.summary` · `codex.reward` · `codex.tab` | 높음 |
| `server/A1Prototypes.lua` + `shared/data/A1PrototypeData.lua` | `/gg a1`만 사용 · "게임 로직과 무관" | ArtV1 · MeshMeta · BossRig | DevTools `/gg a1` 블록 | 높음 |
| `server/ZoneTerrain.lua` + `shared/data/ZoneTerrainData.lua` | 옛 3×3 지형 · `/gg terrain rules` 시험만 | M1 WorldMapLayout · TerrainBake | DevTools 85 ~ 86줄 require · `/gg terrain` 일부 | 중간 |
| `client/KeyframeCompare.lua` | W3a 비교 실험 · WeaponVisual 개발 클립 `kf`만 | 코드 모션 | WeaponVisual `kf` 분기 | 중간 |
| `client/InputDiag.client.lua` + UIManager `inputDiag` 통로 | 임시 진단 로거(I 키 조사 끝) | - | UIManager 443 ~ 447줄 | 중간 |
| `client/panels/UiGallery/*` + `ui/UiGalleryBoot.client.lua` | `/gg ui gallery · check`로만 | - | 지금도 쓰는 개발 도구 - **남길 것** | 낮음 |
- 참고: ArtV1 계열 · DamageFeed는 승인 전 새 기능(기본 끔) - 옛 코드 아님.

## 3. 검증 모듈
- GuideVerify 하나를 빼면 *Verify.lua는 전부 DevTools 체인 · `verifyEnabled` 블록에 연결 - 후보 아님.
- `DevToolsConfig.lua` 51 ~ 57줄 주석의 BossSkillVerify · BossGimmickVerify · BossGimmick4Verify · BossGimmick5Verify = 파일이 이미 없음(주석만 정리).

## 4. 아무 코드도 읽지 않는 데이터 키
| 키 | 근거 | 확실도 |
|---|---|---|
| `SoundSheetData.legacyEvents` | 참조 0 · "훅 옮길 때 참고" | 높음 |
| `GemData.axisDisplayNames` | 참조 0 · OptionData가 대체 | 높음 |
| `ArtImportData.armorScaleClamp` | 참조 0 · 실측 맞춤이 대체 | 높음 |
| `WorldConfig.zoneEdge` · `mapBoundary` · `zoneSize` · `pxPerStud` | 참조 0 · 옛 3×3 · 웹 환산 | 중간 |
| `EquipSlots.statType` · `ProjectileConfig.piercing` | 참조 0(웹에서 옮김 · 앞으로 쓸 자리) | 중간 |
| 기타 값만 있는 키: `PrimordialData.bannerQueueMax` · `TranscendentData.specialNames` · `EnhanceConfig.totalMultiplierAtMax` · `MonsterSpeciesData.hostileAggro` · `AuditConfig.boardStore` · `SoundData.spatialMaxDistance` · `WorldMapData.floorTileStuds` · `MonsterCodexData.firstMetField` · `killsField` · `SocialRewardData.groupRewardEnabled` · `PetData.hatchery` · `EconSimConfig.optionRollTiers` | 참조 0(주석만) · 문서용 · 앞으로 쓸 자리 가능 | 낮음 |

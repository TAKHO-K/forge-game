# A2-N3 상태 (재개 명령 = "A2-N3 이어서")

> Blender 에셋 Open Cloud 일괄 가져오기 + 보스 9점 도전 마무리. 보고서 = `docs/phase/A2-N3-report.md` · 산출물 = `Claude outputs/A2-N3/`.

## 단계

| 단계 | 내용 | 상태 | 커밋 |
|---|---|---|---|
| 0 | 사전 확인 | O(아래) | - |
| 1 | 업로드 도구 `roblox/tools/opencloud/` | O | 19fa52e |
| 2 | 로더(InsertService → 캐시) · ArtStyleV1 뒤 | O | 19fa52e |
| 3 | 세로 절단 4개 | O(아래) | 07e9a7c |
| 4 | 일괄 가져오기 1 ~ 16 | 대기 | |
| 5 | 방어구 착용 표시 | 대기 | |
| 6 | 보스 결정 ① ② ③ | 대기 | |
| 7 | 조명 · 보석 탭 버그 | 대기 | |
| 8 | 보스 재채점 · 성능 | 대기 | |
| 9 | 보고서 · STATE · 푸시 | 대기 | |

## 0. 사전 확인 (2026-09-30)
1. Studio = `HoddyForge의 장소: 08302026_1 (placeId: 106413438976597)` · AutoRecovery 아님 · GameId 10764436044 · DataStore GetAsync 성공 - O
2. Studio Source 길이 = 저장소(LF) 5/5 일치: DevTools 288870 · MeshSwap 7014 · MeshImportCheck 20205 · BossAnimator 39269 · MeshImportDev 5519 · rojo 34872 ESTABLISHED - O
3. `ROBLOX_ASSETS_KEY` = SET(사용자 · 프로세스) - O
4. CreatorType = User · CreatorId = 11595243049 - O(키 소유 일치는 첫 업로드 성공으로 확인)

## 가정 · 결정 로그
- 업로드 도구 언어 = Python 3.14 표준 라이브러리(node 없음 · 설치 금지 준수).
- Open Cloud FBX = cm(×100) · 앞뒤 반대(Y180) · PivotOffset도 cm → 로더가 정규화(ArtImportData.unitScale · yawDegrees).
- Decal의 이미지 id = Studio LoadAsset(decal).Decal.Texture → `upload.py --images`로 asset-ids.json `imageId`에 기록(ImageLabel은 Decal id로 안 뜬다).
- 보스 조준 파트(Body · Head query)는 메시로 바꾸지 않고 옛 상자를 투명 `<이름>_Query`로 남김(판정 불변) · 메시는 CanQuery 끔.
- 보스 껍데기(_Outline) 메시가 있으면 모델 Attribute MeshOutline → 외곽선 풀이 어두운 Highlight 안 담(조준 외곽선 유지).

## 3. 세로 절단 결과 (Play 4회 - 수동 · 검증 무장 없음)
| 항목 | 결과 | 근거 |
|---|---|---|
| 업로드 4/4 | O | greatsword_legendary 139020931783711 · rock_boar 87912718220821 · section_guardian 73336907208395 · 아이콘 Decal 112639992572700(이미지 94841319929838) - 전부 Approved |
| 로드 | O | `[ArtAssetLoader] 메시 캐시 3/3 · 0.5초` |
| 메타 정렬 | O | `[MeshSwap] 메타 정렬: 파트 10 · 가장 큰 어긋남 0.000 stud O` · 멧돼지 끼움 10/10 · 보스 28/28 |
| 이름 | O | .001 접미사 0 · ①-1 10/10 · 28/28 |
| 크기 | O | 단위 힌트 없음 · 관절 오차 최대 0.000(PivotOffset 정규화 뒤) · 전체 비율 x 1.52는 엄니(A2-N1 디자인) - 판정 Hitbox 그대로 |
| 삼각형 | O | 멧돼지 1012 ≤ 1500 · 보스 메타 4512 ≤ 9000(A2-M1 예산) · 대검 전설 610 ≤ 800 |
| 재질 | O | SmoothPlastic · 네온 = 메타 neon · 텍스처 0 |
| 무기 규격 | O | WeaponRigCheck 경고 0 - 손잡이 · 가드 · 보석 네온(캡처) |
| 아이콘 | O(크기는 4단계) | 장비창 무기 칸 ArtIcon IsLoaded true · 22px로 작음 |
| 끔 = 지금 게임 | O | ArtStyleV1Force=false Play: 캐시 없음 · ArtMesh 몹 0/9 · 무기 = `Weapon_Blade` 1개(옛 SpecialMesh) · 캡처 rock_boar-off |
| 알려진 것 | - | 보스 코드 장식은 메시 교체 때 지움(용접 끊김 방지) → 4단계 ③ 합치기 전까지 장식 없음 · 옛 MeshMeta(A2-N2) → 보스 메타 재생성 필요 |

## 에셋 진행
(업로드 상태의 원본 = `roblox/art/asset-ids.json`)

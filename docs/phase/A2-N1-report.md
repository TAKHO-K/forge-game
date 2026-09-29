# A2-N1 보고 - Blender 에셋 대량 제작(렌더만 갈래) (2026-09-30)

> 지시 = 사용자 채팅(A2-N1 이어서 + 확장 · [바로 실행] · [속도 우선 모드] · COMMON §0 · §7-1 ~ §7-6). 상태 파일 = `docs/phase/A2-N1-state.md` · 설계서 = `docs/art/asset-design-n1.md`.
> 갈래 = **렌더만**(환경 변수 `ROBLOX_ASSETS_KEY` 없음 - 사용자 · 프로세스 모두 확인, 값은 읽지 않음). 게임 코드 · 데이터 수정 0(git diff = `roblox/tools/blender/` · `roblox/art/` · `docs/`만).
> 모음 이미지 = `Claude outputs/ART-night/`(커밋 안 함 - 기존 관례): `contact-sheet.png` · `weapons-ladder.png` · `greatsword-ladder.png` · `monsters.png` · `bosses.png` · `props.png` · `props-kit.png` · `pets.png` · `armor.png` · `icons.png`.

## 0. 결과 요약

| 순서 | 대상 | 결과 | 점수(자체 · 검토 뒤) | 이전 대비 |
|---|---|---|---|---|
| 1 | ★대검 8등급 사다리 | 완료 | 8.0 | 확실히 나음(A2-S2 Blender · 도형 조립) |
| 2 · 9 | 쌍검 · 활 · 지팡이 × 8등급(4무기 사다리 완성) | 완료 | 8.2 · 8.0 · 8.0 | 확실히 나음(WeaponModelData 치수 재현 도형) |
| 3 · 6 | 몬스터 T1 ~ T6 + 푸른 드래곤(12종) | 10종 완료 · 2종 보류 | 8.0 ~ 8.2 · 슬라임 6.8 · 양 6.6 | 확실히 나음 10 · **슬라임 · 양 = 비슷 → 도형 유지** |
| 4 | 강화대 · 보스 관문 공통 틀 · 환생 제단 | 완료 | 8.0 · 8.0 · 8.2 | 확실히 나음(관문 · 강화대는 1차 "비슷" → 3회 수정) |
| 5 · 8 | 보스 6종 | 수호자 완료 · 5종 보류 | 8.0 · 7.2 · 7.2 · 7.4 · 7.2 · 6.6 | 확실히 나음 6(보류 사유 §3) |
| 7 | 펫 3종 × 알 등급 3 | 완료 | 8.0 × 3 | 확실히 나음 |
| 10 | 무기 아이콘 32 | 완료 | 8.0 | - |
| 11 | 방어구 세트(구역 6 × 3부위) + 아이콘 144 | 완료 | 8.0(검토 6.4 → 수정) | 새 에셋 |
| 12 | 구역 소품 키트 33(기존 틀 26 + 새 후보 7) | 완료 | (2차 패스 표) | (2차 패스 표) |
| 13 | 게임 안 Play · 성능 측정 | **생략** | - | 렌더만 갈래(가져오기 불가) |
| 2차 | 가장 약한 10 · 스타일 불일치 | (아래 §2) | | |

## 1. 에셋 표

(§1-1 ~ §1-6 = 2차 패스 뒤 최종 값으로 채움)

## 2. 2차 패스

(검토 서브에이전트가 contact-sheet에서 고른 약한 10 → 수정 결과)

## 3. 보류 · 사유

| 에셋 | 사유 | 다음 |
|---|---|---|
| 이끼 슬라임 · 구름 양 | Blender 판이 "비슷"(규칙상 불합격) - 도형 조립(A2-S 샘플)이 더 단순하게 읽힘 | 도형 유지(교체 안 함) |
| 서리 거인 · 심해 군주 · 폭풍 군주 · 수정 여왕 · 전갈 여왕 | 도형 대비 확실히 나음이지만 6.6 ~ 7.4. 주원인 = BossData 몸 색이 **티어 색**(서리 · 심해 · 폭풍 셋 다 초록) → 얼음 · 심해 인상이 형태로만 남음 · 파트 상한 30 때문에 외곽선 껍데기 0 ~ 3개 · 전갈 여왕은 **리그부터 48파트**(상한 30 초과) | 결정 필요 1 · 2 |

## 4. 가져오기 목록(렌더만 갈래 - 키 발급 또는 3D 가져오기 창 뒤 순서대로)

공통 설정(`docs/art/blender-to-studio.md` §5 · `3d-pipeline.md` ①): 단위 **Stud** · **Anchored 켬** · **Import Only As Model 켬** · 리그 · 스킨 · 텍스처 끔 · FBX 축 = −Z 앞 / Y 위(이미 구움 - 가져온 파트 회전 0). 색은 데이터가 칠한다(메시 재질 색 = 렌더용).

| 순서 | 파일 | 넣을 자리 · 이름 | 가져온 뒤 할 일 |
|---|---|---|---|
| 1 | `roblox/art/weapons/greatsword_<등급>.fbx`(8) | `ReplicatedStorage.Shared.WeaponModels.greatsword`(등급별 모델을 고르는 코드는 아직 없음 - 지금은 한 벌) | 부착점 = `greatsword.meta.json` `attachments`(Grip 원점 · Tip · Support)를 `Blade`에 Attachment로 · PrimaryPart = Blade · 부팅 `WeaponRigCheck` 경고 확인 |
| 2 | `dualblade_<등급>.fbx`(8) | `WeaponModels.dualblade` 자식 `BladeRight` · `BladeLeft`(같은 모델 복제) | Grip · Tip(meta) |
| 3 | `bow_<등급>.fbx`(8) | `WeaponModels.bow` | **`String` 파트 삭제**(게임이 시위를 코드로 그림 - 렌더 · 아이콘 전용) · Grip · Tip · StringNock(meta) |
| 4 | `healer_<등급>.fbx`(8) | `WeaponModels.healer` | Grip · Tip · Support(meta) · 머리 = +Y 그대로 |
| 5 | `roblox/art/monsters/<종>.fbx`(10종 - 슬라임 · 양 제외) | 몬스터 교체 폴더(`/gg mesh check <종>` · `/gg mesh swap`) | 파트 이름 = 리그 · 원점 = 관절 · **메시는 휴식 자세 월드 방향으로 구움(회전 0)** → 교체 도구가 관절(C0/C1)을 다시 거는지 첫 1종에서 확인(회전 있는 파트: 멧돼지 엄니 · 전갈 꼬리 · 드래곤 목 · 날개 · 꼬리) |
| 6 | `roblox/art/props/forge.fbx` | `ArtV1Models.forge`의 파트 20개 자리(같은 이름) | 원점 = 코드 파트 자리(배율 1.7 전) · `ScaleTo`는 그대로 · 불빛 · 연기 · 불씨는 코드 |
| 7 | `boss_gate.fbx` | `BossGateKit.frame` 돌 부분(이름 `_1 · _2 · _L · _R` = 같은 코드 이름 여럿 - meta `codeName`) | 빛 테 · 문양 · 막 · 발판 · 프롬프트는 코드 파트 그대로 · 색 = 보스 색 스민 돌(코드) |
| 8 | `rebirth_altar.fbx` | `HuntingGround.createRebirthAltar`(Base · Orb 이름 유지 - Orb에 프롬프트 · 이름표) + `Ring`(새 장식) | Orb = Neon 유지 |
| 9 | `roblox/art/bosses/section_guardian.fbx` | 보스 리그 교체(파트 = BossRigSpec part 이름 · `<파트>_Outline` = 같은 뼈에 용접) | 외곽선 껍데기가 있으면 그 보스 Highlight 끔(art-direction §4) · 5종 보류는 색 결정 뒤 |
| 10 | `roblox/art/pets/<몸 틀>_<등급>.fbx`(9) | `PetData.rigs` 파트 자리(이름 · 중심 = pos) | 색 = 구역 색(코드) · 알 등급 = 부화 결과 등급(보통 · 좋은 · 희귀)과 맞추는 코드는 없음 - 결정 필요 |
| 11 | `roblox/art/icons/weapons/*.png`(32) · `icons/armor/*.png`(144) | Open Cloud 이미지(Decal) 업로드 → 장비창(U1) 아이콘 표 | 파일명 = `<직업>_<등급>` · `<슬롯>_<구역 키>_<등급>` · 256 × 256 투명 · 테두리 색은 UI |
| 12 | `roblox/art/props/kit/<틀 이름>.fbx`(33) | `Shared.PropModels.<틀 이름>`(PropData `overrideFolders` - 같은 이름이면 틀 대신 사용) | 발자국 = 틀과 같은 상자 · 충돌 파트 이름 그대로(`col = false` 파트는 CanCollide 끔) · 새 후보 7은 PropData.templates 추가 뒤 |
| 13 | `roblox/art/armor/<슬롯>_<구역>_<등급>.fbx`(54) | 착용 모델 없음 - 보관만 | 착용 시스템이 생기면 |

- EditableMesh 미리보기(`greatsword_<look>.preview.luau` - A2-S2)는 옛 형태 그대로다(이번 형태로 다시 뽑지 않음).

## 5. 결정 필요(3개 이내)

(아래)
